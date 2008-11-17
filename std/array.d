// Written in the D programming language

module std.array;

private import std.c.stdio;
private import std.contracts;
private import std.traits;
private import std.string;
private import std.algorithm;
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
Inserts $(D stuff) in $(D container) at position $(D pos).
 */
void insert(T, Range)(ref T[] array, size_t pos, Range stuff)
{
    static if (is(typeof(stuff[0])))
    {
        // presumably an array
        alias stuff toInsert;
        assert(!overlap(array, toInsert));
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
    array = cast(T[]) realloc(array.ptr, newLength * array[0].sizeof);
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

/**
Erases elements from $(D array) with indices ranging from $(D from)
(inclusive) to $(D to) (exclusive).
 */
void erase(T)(ref T[] array, size_t from, size_t to)
{
    invariant newLength = array.length - (to - from);
    foreach (i; to .. array.length)
    {
        move(array[i], array[from++]);
    }
    array.length = newLength;
}

unittest
{
    int[] a = [1, 2, 3, 4, 5];
    erase(a, 1u, 3u);
    assert(a == [1, 4, 5]);
}

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
        erase(array, stuffEnd, to);
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

