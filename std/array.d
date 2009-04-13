// Written in the D programming language

module std.array;

import std.c.stdio;
import core.memory;
import std.contracts;
import std.traits;
import std.string;
import std.algorithm;
import std.encoding;
import std.typecons;
version(unittest) private import std.stdio;

/*
Returns an array consisting of $(D elements).

Example:

----
auto a = array(1, 2, 3);
assert(is(typeof(a) == int[]));
assert(a == [ 1, 2, 3 ]);
auto b = array(1, 2.2, 3);
assert(is(typeof(b) == double[]));
assert(b == [ 1.0, 2.2, 3 ]);
----
 */
// CommonType!(Ts)[] array(Ts...)(Ts elements)
// {
//     alias CommonType!(Ts) E;
//     alias typeof(return) R;
//     // 1. Allocate untyped memory
//     auto result = cast(E*) enforce(std.gc.malloc(elements.length * R.sizeof),
//             text("Out of memory while allocating an array of ",
//                     elements.length, " objects of type ", E.stringof));
//     // 2. Initialize the memory
//     size_t constructedElements = 0;
//     scope(failure)
//     {
//         // Deconstruct only what was constructed
//         foreach_reverse (i; 0 .. constructedElements)
//         {
//             try
//             {
//                 //result[i].~E();
//             }
//             catch (Exception e)
//             {
//             }
//         }
//         // free the entire array
//         std.gc.realloc(result, 0);
//     }
//     foreach (src; elements)
//     {
//         static if (is(typeof(new(result + constructedElements) E(src))))
//         {
//             new(result + constructedElements) E(src);
//         }
//         else
//         {
//             result[constructedElements] = src;
//         }
//         ++constructedElements;
//     }
//     // 3. Success constructing all elements, type the array and return it
//     setTypeInfo(typeid(E), result);
//     return result[0 .. constructedElements];
// }

// unittest
// {
//     auto a = array(1, 2, 3, 4, 5);
//     writeln(a);
//     assert(a == [ 1, 2, 3, 4, 5 ]);

//     struct S { int x; string toString() { return .toString(x); } }
//     auto b = array(S(1), S(2));
//     writeln(b);

//     class C
//     {
//         int x;
//         this(int y) { x = y; }
//         string toString() { return .toString(x); }
//     }
//     auto c = array(new C(1), new C(2));
//     writeln(c);

//     auto d = array(1, 2.2, 3);
//     assert(is(typeof(d) == double[]));
//     writeln(d);
// }

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

bool empty(T)(in T[] a) { return !a.length; }

unittest
{
    auto a = [ 1, 2, 3 ];
    assert(!a.empty);
    assert(a[3 .. $].empty);
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

void popFront(T)(ref T[] a)
{
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

void popBack(T)(ref T[] a) { assert(a.length); a = a[0 .. $ - 1]; }

unittest
{
    //@@@BUG 2608@@@
    //auto a = [ 1, 2, 3 ];
    int[] a = [ 1, 2, 3 ];
    a.popBack;
    assert(a == [ 1, 2 ]);
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
ref typeof(A[0]) front(A)(A a) if (is(typeof(A[0])))
{
    assert(a.length, "Attempting to fetch the front of an empty array");
    return a[0];
}

/// Ditto
void front(T)(T[] a, T v) { assert(a.length); a[0] = v; }

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
    assert(a.front == 1);
}
----
*/
ref T back(T)(T[] a) { assert(a.length); return a[a.length - 1]; }

/**
Implements the range interface primitive $(D put) for built-in
arrays. Due to the fact that nonmember functions can be called with
the first argument using the dot notation, $(D array.put(e)) is
equivalent to $(D put(array, e)).

Example:
----
void main()
{
    int[] a = [ 1, 2, 3 ];
    int[] b = a;
    a.put(5);
    assert(a == [ 2, 3 ]);
    assert(b == [ 5, 2, 3 ]);
}
----
*/
void put(T, E)(ref T[] a, E e) { assert(a.length); a[0] = e; a = a[1 .. $]; }

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
assert(isEmpty(overlap(a, b)));
----
*/
T[] overlap(T)(T[] r1, T[] r2)
{
    auto b = max(r1.ptr, r2.ptr);
    auto e = min(&(r1.ptr[r1.length - 1]) + 1, &(r2.ptr[r2.length - 1]) + 1);
    return b < e ? b[0 .. e - b] : null;
}

unittest
{
    int[] a = [ 10, 11, 12, 13, 14 ];
    int[] b = a[1 .. 3];
    a[1] = 100;
    assert(overlap(a, b) == [ 100, 12 ]);
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
    // invariant
    //     size_t delta = toInsert.length,
    //     size_t oldLength = array.length,
    //     size_t newLength = oldLength + delta;
    invariant
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
//     invariant newLength = array.length - (to - from);
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
void replace(T, Range)(ref T[] array, size_t from, size_t to,
        Range stuff)
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
        //invariant stuffEnd = from + stuff.length;
        auto stuffEnd = from + stuff.length;
        array[from .. stuffEnd] = stuff;
        remove(array, tuple(stuffEnd, to));
    }
    else
    {
        // replacement increases length
        // @@@TODO@@@: optimize this
        invariant replaceLen = to - from;
        array[from .. to] = stuff[0 .. replaceLen];
        insert(array, to, stuff[replaceLen .. $]);
    }
}

unittest
{
    int[] a = [1, 4, 5];
    replace(a, 1u, 2u, [2, 3, 4]);
    assert(a == [1, 2, 3, 4, 5]);
}

/**
Implements an output range that appends data to an array. This is
recommended over $(D a ~= data) because it is more efficient.

Example:
----
auto arr = new char[0];
auto app = appender(&arr);
string b = "abcdefg";
foreach (char c; b) app.put(c);
assert(app.data == "abcdefg");

int[] a = [ 1, 2 ];
auto app2 = appender(&a);
app2.put(3);
app2.put([ 4, 5, 6 ]);
assert(app2.data == [ 1, 2, 3, 4, 5, 6 ]);
----
 */

struct Appender(A : T[], T)
{
private:
    T[] * pArray;
    size_t _capacity;

public:
/**
Initialize an $(D Appender) with a pointer to an existing array. The
$(D Appender) object will append to this array. If $(D null) is passed
(or the default constructor gets called), the $(D Appender) object
will allocate and use a new array.
 */
    this(T[] * p)
    {
        pArray = p;
        if (!pArray) pArray = (new typeof(*pArray)[1]).ptr;
        _capacity = GC.sizeOf(pArray.ptr) / T.sizeof;
        //_capacity = .capacity(pArray.ptr) / T.sizeof;
    }

/**
Returns the managed array.
 */ 
    T[] data()
    {
        return pArray ? *pArray : null;
    }

/**
Returns the capacity of the array (the maximum number of elements the
managed array can accommodate before triggering a reallocation).
 */ 
    size_t capacity() const { return _capacity; }

    static if (is(const(T) : T))
    {
/**
An alias for the accepted type to be appended.
 */     
        alias const(T) AcceptedElementType;
    }
    else
    {
        alias T AcceptedElementType;
    }
    
/**
Appends one item to the managed array.
 */ 
    void put(AcceptedElementType item)
    {
        if (!pArray) pArray = (new typeof(*pArray)[1]).ptr;
        if (pArray.length < _capacity)
        {
            // Should do in-place construction here
            pArray.ptr[pArray.length] = item;
            *pArray = pArray.ptr[0 .. pArray.length + 1];
        }
        else
        {
            // Time to reallocate, do it and cache capacity
            *pArray ~= item;
            //_capacity = .capacity(pArray.ptr) / T.sizeof;
            _capacity = GC.sizeOf(pArray.ptr) / T.sizeof;
        }
    }

/**
Appends another array to the managed array.
 */ 
    void put(AcceptedElementType[] items)
    {
        for (; !items.empty(); items.popFront()) {
            put(items.front());
        }
    }

    static if (is(Unqual!(T) == wchar) || is(Unqual!(T) == dchar))
    {
/**
In case the managed array has type $(D char[]), $(D wchar[]), or $(D
dchar[]), all other character widths and arrays thereof are also
accepted.
 */
        void put(in char c) { encode!(T)((&c)[0 .. 1], this); }
/// Ditto
        void put(in char[] cs)
        {
            encode!(T)(cs, this);
        }
    }
    static if (is(Unqual!(T) == char) || is(Unqual!(T) == dchar))
    {
/// Ditto
        void put(in wchar dc) { assert(false); }
/// Ditto
        void put(in wchar[] dcs)
        {
            encode!(T)(dcs, this);
        }
    }
    static if (is(Unqual!(T) == char) || is(Unqual!(T) == wchar))
    {
/// Ditto
        void put(in dchar dc) { std.utf.encode(*pArray, dc); }
/// Ditto
        void put(in dchar[] wcs)
        {
            encode!(T)(wcs, this);
        }
    }

/**
Clears the managed array.
*/
    void clear()
    {
        if (!pArray) return;
        pArray.length = 0;
        //_capacity = .capacity(pArray.ptr) / T.sizeof;
        _capacity = GC.sizeOf(pArray.ptr) / T.sizeof;
    }
}

/**
Convenience function that returns an $(D Appender!(T)) object
initialized with $(D t).
 */ 
Appender!(E[]) appender(A : E[], E)(A * array = null)
{
    return Appender!(E[])(array);
}

unittest
{
    auto arr = new char[0];
    auto app = appender(&arr);
    string b = "abcdefg";
    foreach (char c; b) app.put(c);
    assert(app.data == "abcdefg");

    int[] a = [ 1, 2 ];
    auto app2 = appender(&a);
    app2.put(3);
    app2.put([ 4, 5, 6 ]);
    assert(app2.data == [ 1, 2, 3, 4, 5, 6 ]);
}

