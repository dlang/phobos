// Written in the D programming language.
/**
Functions and types that manipulate built-in arrays.

Copyright: Copyright Andrei Alexandrescu 2008- and Jonathan M Davis 2011-.

License:   $(WEB boost.org/LICENSE_1_0.txt, Boost License 1.0).

Authors:   $(WEB erdani.org, Andrei Alexandrescu) and Jonathan M Davis

Source: $(PHOBOSSRC std/_array.d)
*/
module std.array;

import core.memory, core.bitop;
import std.algorithm, std.conv, std.ctype, std.encoding, std.exception,
    std.range, std.string, std.traits, std.typecons, std.utf;
import std.c.string : memcpy;
version(unittest) import core.exception, std.stdio, std.typetuple;

/**
Returns a newly-allocated dynamic array consisting of a copy of the
input range, static array, dynamic array, or class or struct with an
$(D opApply) function $(D r).  Note that narrow strings are handled as
a special case in an overload.

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
                emplace!E(result.ptr + i, e);
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
}

/**
Convert a narrow string to an array type that fully supports random access.
This is handled as a special case and always returns a $(D dchar[]),
$(D const(dchar)[]), or $(D immutable(dchar)[]) depending on the constness of
the input.
*/
ElementType!String[] array(String)(String str) if (isNarrowString!String)
{
    return to!(typeof(return))(str);
}

unittest
{
    static struct TestArray { int x; string toString() { return .to!string(x); } }

    static struct OpAssign
    {
        uint num;
        this(uint num) { this.num = num; }

        // Templating opAssign to make sure the bugs with opAssign being
        // templated are fixed.
        void opAssign(T)(T rhs) { this.num = rhs.num; }
    }

    static struct OpApply
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

/**
Implements the range interface primitive $(D empty) for built-in
arrays. Due to the fact that nonmember functions can be called with
the first argument using the dot notation, $(D array.empty) is
equivalent to $(D empty(array)).

Example:
----
auto a = [ 1, 2, 3 ];
assert(!a.empty);
assert(a[3 .. $].empty);
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
equivalent to $(D save(array)). The function does not duplicate the
content of the array, it simply returns its argument.

Example:
----
auto a = [ 1, 2, 3 ];
auto b = a.save;
assert(b is a);
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
equivalent to $(D popFront(array)). For $(GLOSSARY narrow strings),
$(D popFront) automaticaly advances to the next $(GLOSSARY code
point).

Example:
----
int[] a = [ 1, 2, 3 ];
a.popFront();
assert(a == [ 2, 3 ]);
----
*/

void popFront(A)(ref A a)
if (!isNarrowString!A && isDynamicArray!A && isMutable!A && !is(A == void[]))
{
    assert(a.length, "Attempting to popFront() past the end of an array of "
            ~ typeof(a[0]).stringof);
    a = a[1 .. $];
}

unittest
{
    auto a = [ 1, 2, 3 ];
    a.popFront();
    assert(a == [ 2, 3 ]);
    static assert(!__traits(compiles, popFront!(immutable int[])));
    static assert(!__traits(compiles, popFront!(void[])));
}

// Specialization for narrow strings. The necessity of
// !isStaticArray!A suggests a compiler @@@BUG@@@.
void popFront(A)(ref A a)
if (isNarrowString!A && isMutable!A && !isStaticArray!A)
{
    assert(a.length, "Attempting to popFront() past the end of an array of "
            ~ typeof(a[0]).stringof);
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
equivalent to $(D popBack(array)). For $(GLOSSARY narrow strings), $(D
popFront) automaticaly eliminates the last $(GLOSSARY code point).


Example:
----
int[] a = [ 1, 2, 3 ];
a.popBack();
assert(a == [ 1, 2 ]);
----
*/

void popBack(A)(ref A a)
if (isDynamicArray!A && !isNarrowString!A && isMutable!A && !is(A == void[]))
{
    assert(a.length);
    a = a[0 .. $ - 1];
}

unittest
{
    auto a = [ 1, 2, 3 ];
    a.popBack();
    assert(a == [ 1, 2 ]);
    static assert(!__traits(compiles, popBack!(immutable int[])));
    static assert(!__traits(compiles, popBack!(void[])));
}

// Specialization for arrays of char
@trusted void popBack(A)(ref A a)
if (is(A : const(char)[]) && isMutable!A)
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
        throw new UtfException("Invalid UTF character at end of string");
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

// Specialization for arrays of wchar
@trusted void popBack(A)(ref A a)
if (is(A : const(wchar)[]) && isMutable!A)
{
    assert(a.length);
    if (a.length <= 1) // this is technically == but costs nothing and is safer
    {
        a = a[0 .. 0];
        return;
    }
    // We can go commando from here on, we're safe; length is > 1
    immutable c = a.ptr[a.length - 2];
    a = a.ptr[0 .. a.length - 1 - (c >= 0xD800 && c <= 0xDBFF)];
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
equivalent to $(D front(array)). For $(GLOSSARY narrow strings), $(D
front) automaticaly returns the first $(GLOSSARY code point) as a $(D
dchar).


Example:
----
int[] a = [ 1, 2, 3 ];
assert(a.front == 1);
----
*/
ref T front(T)(T[] a)
if (!isNarrowString!(T[]) && !is(T[] == void[]))
{
    assert(a.length, "Attempting to fetch the front of an empty array");
    return a[0];
}

dchar front(A)(A a) if (isNarrowString!A)
{
    assert(a.length, "Attempting to fetch the front of an empty array");
    size_t i = 0;
    return decode(a, i);
}

unittest
{
    auto a = [ 1, 2 ];
    a.front = 4;
    assert(a.front == 4);
    assert(a == [ 4, 2 ]);
}

/**
Implements the range interface primitive $(D back) for built-in
arrays. Due to the fact that nonmember functions can be called with
the first argument using the dot notation, $(D array.back) is
equivalent to $(D back(array)). For $(GLOSSARY narrow strings), $(D
back) automaticaly returns the last $(GLOSSARY code point) as a $(D
dchar).

Example:
----
int[] a = [ 1, 2, 3 ];
assert(a.back == 3);
----
*/
ref T back(T)(T[] a) if (!isNarrowString!(T[]))
{
    assert(a.length, "Attempting to fetch the back of an empty array");
    return a[$ - 1];
}

unittest
{
    int[] a = [ 1, 2, 3 ];
    assert(a.back == 3);
    a.back += 4;
    assert(a.back == 7);
}

// Specialization for strings
dchar back(A)(A a)
if (isDynamicArray!A && isNarrowString!A)
{
    auto n = a.length;
    const p = a.ptr + n;
    if (n >= 1 && (p[-1] & 0b1100_0000) != 0b1000_0000)
    {
        --n;
    }
    else if (n >= 2 && (p[-2] & 0b1100_0000) != 0b1000_0000)
    {
        n -= 2;
    }
    else if (n >= 3 && (p[-3] & 0b1100_0000) != 0b1000_0000)
    {
        n -= 3;
    }
    else if (n >= 4 && (p[-4] & 0b1100_0000) != 0b1000_0000)
    {
        n -= 4;
    }
    else
    {
        throw new UtfException(a.length
                ? "Invalid UTF character at end of string"
                : "Attempting to fetch the back of an empty array");
    }
    return decode(a, n);
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
    static T* max(T* a, T* b) nothrow { return a > b ? a : b; }
    static T* min(T* a, T* b) nothrow { return a < b ? a : b; }
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

/+
Commented out until the insert which is scheduled for deprecation is removed.
I'd love to just remove it in favor of insertInPlace, but then code would then
use this version of insert and silently break. So, it's here so that it can
be used once insert has not only been deprecated but removed, but until then,
it's commented out.

/++
    Creates a new array which is a copy of $(D array) with $(D stuff) (which
    must be an input range or a single item) inserted at position $(D pos).

    Examples:
--------------------
int[] a = [ 1, 2, 3, 4 ];
auto b = a.insert(2, [ 1, 2 ]);
assert(a == [ 1, 2, 3, 4 ]);
assert(b == [ 1, 2, 1, 2, 3, 4 ]);
--------------------
 +/
T[] insert(T, Range)(T[] array, size_t pos, Range stuff)
    if(isInputRange!Range &&
       (is(ElementType!Range : T) ||
        isSomeString!(T[]) && is(ElementType!Range : dchar)))
{
    static if(hasLength!Range && is(ElementEncodingType!Range : T))
    {
        auto retval = new Unqual!(T)[](array.length + stuff.length);
        retval[0 .. pos] = array[0 .. pos];
        copy(stuff, retval[pos .. pos + stuff.length]);
        retval[pos + stuff.length .. $] = array[pos .. $];
        return cast(T[])retval;
    }
    else
    {
        auto app = appender!(T[])();
        app.put(array[0 .. pos]);
        app.put(stuff);
        app.put(array[pos .. $]);
        return app.data;
    }
}

/++ Ditto +/
T[] insert(T)(T[] array, size_t pos, T stuff)
{
    auto retval = new T[](array.length + 1);
    retval[0 .. pos] = array[0 .. pos];
    retval[pos] = stuff;
    retval[pos + 1 .. $] = array[pos .. $];
    return retval;
}

//Verify Example.
unittest
{
    int[] a = [ 1, 2, 3, 4 ];
    auto b = a.insert(2, [ 1, 2 ]);
    assert(a == [ 1, 2, 3, 4 ]);
    assert(b == [ 1, 2, 1, 2, 3, 4 ]);
}

unittest
{
    auto a = [1, 2, 3, 4];
    assert(a.insert(0, [6, 7]) == [6, 7, 1, 2, 3, 4]);
    assert(a.insert(2, [6, 7]) == [1, 2, 6, 7, 3, 4]);
    assert(a.insert(a.length, [6, 7]) == [1, 2, 3, 4, 6, 7]);

    assert(a.insert(0, filter!"true"([6, 7])) == [6, 7, 1, 2, 3, 4]);
    assert(a.insert(2, filter!"true"([6, 7])) == [1, 2, 6, 7, 3, 4]);
    assert(a.insert(a.length, filter!"true"([6, 7])) == [1, 2, 3, 4, 6, 7]);

    assert(a.insert(0, 22) == [22, 1, 2, 3, 4]);
    assert(a.insert(2, 22) == [1, 2, 22, 3, 4]);
    assert(a.insert(a.length, 22) == [1, 2, 3, 4, 22]);
    assert(a == [1, 2, 3, 4]);

    auto testStr(T, U)(string file = __FILE__, size_t line = __LINE__)
    {

        auto l = to!T("hello");
        auto r = to!U(" world");

        enforce(insert(l, 0, r) == " worldhello",
                new AssertError("testStr failure 1", file, line));
        enforce(insert(l, 3, r) == "hel worldlo",
                new AssertError("testStr failure 2", file, line));
        enforce(insert(l, l.length, r) == "hello world",
                new AssertError("testStr failure 3", file, line));
        enforce(insert(l, 0, filter!"true"(r)) == " worldhello",
                new AssertError("testStr failure 4", file, line));
        enforce(insert(l, 3, filter!"true"(r)) == "hel worldlo",
                new AssertError("testStr failure 5", file, line));
        enforce(insert(l, l.length, filter!"true"(r)) == "hello world",
                new AssertError("testStr failure 6", file, line));
    }

    testStr!(string, string)();
    testStr!(string, wstring)();
    testStr!(string, dstring)();
    testStr!(wstring, string)();
    testStr!(wstring, wstring)();
    testStr!(wstring, dstring)();
    testStr!(dstring, string)();
    testStr!(dstring, wstring)();
    testStr!(dstring, dstring)();
}
+/

/++
    Inserts $(D stuff) (which must be an input range or a single item) in
    $(D array) at position $(D pos).

Example:
---
int[] a = [ 1, 2, 3, 4 ];
a.insertInPlace(2, [ 1, 2 ]);
assert(a == [ 1, 2, 1, 2, 3, 4 ]);
---
 +/
void insertInPlace(T, Range)(ref T[] array, size_t pos, Range stuff)
    if(isInputRange!Range &&
       (is(ElementType!Range : T) ||
        isSomeString!(T[]) && is(ElementType!Range : dchar)))
{
    static if(hasLength!Range &&
              is(ElementEncodingType!Range : T) &&
              !is(T == const T) &&
              !is(T == immutable T))
    {
        immutable
            delta = stuff.length,
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
        copy(stuff, array[pos .. pos + stuff.length]);
    }
    else
    {
        auto app = appender!(T[])();
        app.put(array[0 .. pos]);
        app.put(stuff);
        app.put(array[pos .. $]);
        array = app.data;
    }
}

/++ Ditto +/
void insertInPlace(T)(ref T[] array, size_t pos, T stuff)
{
    insertInPlace(array, pos, (&stuff)[0 .. 1]);
}

//Verify Example.
unittest
{
    int[] a = ([1, 4, 5]).dup;
    insertInPlace(a, 1u, [2, 3]);
    assert(a == [1, 2, 3, 4, 5]);
    insertInPlace(a, 1u, 99);
    assert(a == [1, 99, 2, 3, 4, 5]);
}

unittest
{
    bool test(T, U, V)(T orig, size_t pos, U toInsert, V result,
               string file = __FILE__, size_t line = __LINE__)
    {
        {
            static if(is(T == typeof(T.dup)))
                auto a = orig.dup;
            else
                auto a = orig.idup;

            a.insertInPlace(pos, toInsert);
            if(!std.algorithm.equal(a, result))
                return false;
        }

        static if(isInputRange!U)
        {
            orig.insertInPlace(pos, filter!"true"(toInsert));
            return std.algorithm.equal(orig, result);
        }
        else
            return true;
    }


    assert(test([1, 2, 3, 4], 0, [6, 7], [6, 7, 1, 2, 3, 4]));
    assert(test([1, 2, 3, 4], 2, [8, 9], [1, 2, 8, 9, 3, 4]));
    assert(test([1, 2, 3, 4], 4, [10, 11], [1, 2, 3, 4, 10, 11]));

    assert(test([1, 2, 3, 4], 0, 22, [22, 1, 2, 3, 4]));
    assert(test([1, 2, 3, 4], 2, 23, [1, 2, 23, 3, 4]));
    assert(test([1, 2, 3, 4], 4, 24, [1, 2, 3, 4, 24]));

    auto testStr(T, U)(string file = __FILE__, size_t line = __LINE__)
    {

        auto l = to!T("hello");
        auto r = to!U(" world");

        enforce(test(l, 0, r, " worldhello"),
                new AssertError("testStr failure 1", file, line));
        enforce(test(l, 3, r, "hel worldlo"),
                new AssertError("testStr failure 2", file, line));
        enforce(test(l, l.length, r, "hello world"),
                new AssertError("testStr failure 3", file, line));
    }

    testStr!(string, string)();
    testStr!(string, wstring)();
    testStr!(string, dstring)();
    testStr!(wstring, string)();
    testStr!(wstring, wstring)();
    testStr!(wstring, dstring)();
    testStr!(dstring, string)();
    testStr!(dstring, wstring)();
    testStr!(dstring, dstring)();
}

/++
    $(RED Scheduled for deprecation. Use $(XREF array, insertInPlace) instead.)

    Same as $(XREF array, insertInPlace).
  +/
void insert(T, Range)(ref T[] array, size_t pos, Range stuff)
if (isInputRange!Range && is(ElementEncodingType!Range : T))
{
    pragma(msg, "std.array.insert has been scheduled for deprecation. " ~
                "Use insertInPlace instead.");
    insertInPlace(array, pos, stuff);
}

/// Ditto
void insert(T)(ref T[] array, size_t pos, T stuff)
{
    pragma(msg, "std.array.insert has been scheduled for deprecation. " ~
                "Use insertInPlace instead.");
    insertInPlace(array, pos, stuff);
}

/++
    Returns whether the $(D front)s of $(D lhs) and $(D rhs) both refer to the
    same place in memory, making one of the arrays a slice of the other which
    starts at index $(D 0).
  +/
pure bool sameHead(T)(in T[] lhs, in T[] rhs)
{
    return lhs.ptr == rhs.ptr;
}

/********************************************
Returns an array that consists of $(D s) (which must be an input
range) repeated $(D n) times. This function allocates, fills, and
returns a new array. For a lazy version, refer to $(XREF range, repeat).
 */
S replicate(S)(S s, size_t n) if (isDynamicArray!S)
{
    // Optimization for return join(std.range.repeat(s, n));
    if (n == 0)
        return S.init;
    if (n == 1)
        return s;
    auto r = new Unqual!(typeof(s[0]))[n * s.length];
    if (s.length == 1)
        r[] = s[0];
    else
    {
        immutable len = s.length, nlen = n * len;
        for (size_t i = 0; i < nlen; i += len)
        {
            r[i .. i + len] = s[];
        }
    }
    return cast(S) r;
}

ElementType!S[] replicate(S)(S s, size_t n)
if (isInputRange!S && !isDynamicArray!S)
{
    return join(std.range.repeat(s, n));
}

unittest
{
    debug(std_array) printf("array.repeat.unittest\n");

    foreach (S; TypeTuple!(string, wstring, dstring, char[], wchar[], dchar[]))
    {
        S s;

        s = replicate(to!S("1234"), 0);
        assert(s is null);
        s = replicate(to!S("1234"), 1);
        assert(cmp(s, "1234") == 0);
        s = replicate(to!S("1234"), 2);
        assert(cmp(s, "12341234") == 0);
        s = replicate(to!S("1"), 4);
        assert(cmp(s, "1111") == 0);
        s = replicate(cast(S) null, 4);
        assert(s is null);
    }

    int[] a = [ 1, 2, 3 ];
    assert(replicate(a, 3) == [1, 2, 3, 1, 2, 3, 1, 2, 3]);
}

/**************************************
Split the string $(D s) into an array of words, using whitespace as
delimiter. Runs of whitespace are merged together (no empty words are produced).
 */
S[] split(S)(S s) if (isSomeString!S)
{
    size_t istart;
    bool inword = false;
    S[] result;

    foreach (i; 0 .. s.length)
    {
        switch (s[i])
        {
        case ' ': case '\t': case '\f': case '\r': case '\n': case '\v':
            if (inword)
            {
                result ~= s[istart .. i];
                inword = false;
            }
            break;
        default:
            if (!inword)
            {
                istart = i;
                inword = true;
            }
            break;
        }
    }
    if (inword)
        result ~= s[istart .. $];
    return result;
}

unittest
{
    foreach (S; TypeTuple!(string, wstring, dstring))
    {
        debug(string) printf("string.split1\n");
        S s = " \t\npeter paul\tjerry \n";
        assert(equal(split(s), [ to!S("peter"), to!S("paul"), to!S("jerry") ]));
    }
}

/**
Splits a string by whitespace.

Example:

----
auto a = " a     bcd   ef gh ";
assert(equal(splitter(a), ["", "a", "bcd", "ef", "gh"][]));
----
 */
auto splitter(String)(String s) if (isSomeString!String)
{
    return std.algorithm.splitter!isspace(s);
}

unittest
{
    auto a = " a     bcd   ef gh ";
    assert(equal(splitter(a), ["", "a", "bcd", "ef", "gh"][]));
    a = "";
    assert(splitter(a).empty);
}

/**************************************
 * Splits $(D s) into an array, using $(D delim) as the delimiter.
 */
Unqual!(S1)[] split(S1, S2)(S1 s, S2 delim)
if (isForwardRange!(Unqual!S1) && isForwardRange!S2)
{
    Unqual!S1 us = s;
    auto app = appender!(Unqual!(S1)[])();
    foreach (word; std.algorithm.splitter(us, delim))
    {
        app.put(word);
    }
    return app.data;
}

unittest
{
    debug(std_array) printf("array.split\n");
    foreach (S; TypeTuple!(string, wstring, dstring,
                    immutable(string), immutable(wstring), immutable(dstring),
                    char[], wchar[], dchar[],
                    const(char)[], const(wchar)[], const(dchar)[]))
    {
        S s = to!S(",peter,paul,jerry,");
        int i;

        auto words = split(s, ",");
        assert(words.length == 5, text(words.length));
        i = cmp(words[0], "");
        assert(i == 0);
        i = cmp(words[1], "peter");
        assert(i == 0);
        i = cmp(words[2], "paul");
        assert(i == 0);
        i = cmp(words[3], "jerry");
        assert(i == 0);
        i = cmp(words[4], "");
        assert(i == 0);

        auto s1 = s[0 .. s.length - 1];   // lop off trailing ','
        words = split(s1, ",");
        assert(words.length == 4);
        i = cmp(words[3], "jerry");
        assert(i == 0);

        auto s2 = s1[1 .. s1.length];   // lop off leading ','
        words = split(s2, ",");
        assert(words.length == 3);
        i = cmp(words[0], "peter");
        assert(i == 0);

        auto s3 = to!S(",,peter,,paul,,jerry,,");

        words = split(s3, ",,");
        //printf("words.length = %d\n", words.length);
        assert(words.length == 5);
        i = cmp(words[0], "");
        assert(i == 0);
        i = cmp(words[1], "peter");
        assert(i == 0);
        i = cmp(words[2], "paul");
        assert(i == 0);
        i = cmp(words[3], "jerry");
        assert(i == 0);
        i = cmp(words[4], "");
        assert(i == 0);

        auto s4 = s3[0 .. s3.length - 2];    // lop off trailing ',,'
        words = split(s4, ",,");
        assert(words.length == 4);
        i = cmp(words[3], "jerry");
        assert(i == 0);

        auto s5 = s4[2 .. s4.length];    // lop off leading ',,'
        words = split(s5, ",,");
        assert(words.length == 3);
        i = cmp(words[0], "peter");
        assert(i == 0);
    }
}

/********************************************
 * Concatenate all the ranges in $(D ror) together into one array;
 * use $(D sep) as the separator if present, otherwise none.
 */
ElementEncodingType!(ElementType!RoR)[]
join(RoR, R)(RoR ror, R sep)
if (isInputRange!RoR && isInputRange!(ElementType!RoR) && isForwardRange!R)
{
    if (ror.empty) return typeof(return).init;
    auto iter = joiner(ror, sep);
    static if (isForwardRange!RoR && hasLength!RoR
            && (hasLength!(ElementType!RoR) || isSomeString!(ElementType!RoR))
            && hasLength!R)
    {
        immutable resultLen = reduce!"a + b.length"(cast(size_t) 0, ror.save)
            + sep.length * (ror.length - 1);
        auto result = new ElementEncodingType!(ElementType!RoR)[resultLen];
        copy(iter, result);
        return result;
    }
    else
    {
        return copy(iter, appender!(typeof(return))).data;
    }
}

/// Ditto
ElementEncodingType!(ElementType!RoR)[] join(RoR)(RoR ror)
if (isInputRange!RoR && isInputRange!(ElementType!RoR))
{
    auto iter = joiner(ror);
    static if (hasLength!RoR && hasLength!(ElementType!RoR))
    {
        immutable resultLen = reduce!"a + b.length"(cast(size_t) 0, ror.save);
        auto result = new Unqual!(ElementEncodingType!(ElementType!RoR))[resultLen];
        copy(iter, result);
        return cast(typeof(return)) result;
    }
    else
    {
        return copy(iter, appender!(typeof(return))).data;
    }
}

unittest
{
    debug(std_array) printf("array.join.unittest\n");

    string word1 = "peter";
    string word2 = "paul";
    string word3 = "jerry";
    string[3] words;
    string r;
    int i;

    words[0] = word1;
    words[1] = word2;
    words[2] = word3;
    r = join(words[], ",");
    i = cmp(r, "peter,paul,jerry");
    assert(i == 0, text(i));

    assert(join([[1, 2], [41, 42]], [5, 6]) == [1, 2, 5, 6, 41, 42]);
    assert(join([[1, 2], [41, 42]]) == [1, 2, 41, 42]);
}

/++
    Replace occurrences of $(D from) with $(D to) in $(D subject). Returns a new
    array without changing the contents of $(D subject).
 +/
R1 replace(R1, R2, R3)(R1 subject, R2 from, R3 to)
if (isDynamicArray!R1 && isForwardRange!R2 && isForwardRange!R3
        && (hasLength!R3 || isSomeString!R3))
{
    if (from.empty) return subject;
    auto app = appender!R1();

    for (;;)
    {
        auto balance = std.algorithm.find(subject, from.save);
        if (balance.empty)
        {
            if (app.data.empty) return subject;
            app.put(subject);
            break;
        }
        app.put(subject[0 .. subject.length - balance.length]);
        app.put(to.save);
        subject = balance[from.length .. $];
    }

    return app.data;
}

unittest
{
    debug(string) printf("array.replace.unittest\n");

    alias TypeTuple!(string, wstring, dstring, char[], wchar[], dchar[])
        TestTypes;

    foreach (S; TestTypes)
    {
        auto s = to!S("This is a foo foo list");
        auto from = to!S("foo");
        auto into = to!S("silly");
        S r;
        int i;

        r = replace(s, from, into);
        i = cmp(r, "This is a silly silly list");
        assert(i == 0);

        r = replace(s, to!S(""), into);
        i = cmp(r, "This is a foo foo list");
        assert(i == 0);

        assert(replace(r, to!S("won't find this"), to!S("whatever")) is r);
    }
}

/+
Commented out until the replace which is scheduled for deprecation is removed.
I'd love to just remove it in favor of replaceInPlace, but then code would then
use this version of replaceInPlace and silently break. So, it's here so that it
can be used once replace has not only been deprecated but removed, but
until then, it's commented out.

/++
    Replaces elements from $(D array) with indices ranging from $(D from)
    (inclusive) to $(D to) (exclusive) with the range $(D stuff). Returns a new
    array without changing the contents of $(D subject).

Examples:
--------------------
auto a = [ 1, 2, 3, 4 ];
auto b = a.replace(1, 3, [ 9, 9, 9 ]);
assert(a == [ 1, 2, 3, 4 ]);
assert(b == [ 1, 9, 9, 9, 4 ]);
--------------------
 +/
T[] replace(T, Range)(T[] subject, size_t from, size_t to, Range stuff)
    if(isInputRange!Range &&
       (is(ElementType!Range : T) ||
        isSomeString!(T[]) && is(ElementType!Range : dchar)))
{
    static if(hasLength!Range && is(ElementEncodingType!Range : T))
    {
        assert(from <= to);
        immutable sliceLen = to - from;
        auto retval = new Unqual!(T)[](subject.length - sliceLen + stuff.length);
        retval[0 .. from] = subject[0 .. from];

        if(!stuff.empty)
            copy(stuff, retval[from .. from + stuff.length]);

        retval[from + stuff.length .. $] = subject[to .. $];
        return cast(T[])retval;
    }
    else
    {
        auto app = appender!(T[])();
        app.put(subject[0 .. from]);
        app.put(stuff);
        app.put(subject[to .. $]);
        return app.data;
    }
}

//Verify Examples.
unittest
{
    auto a = [ 1, 2, 3, 4 ];
    auto b = a.replace(1, 3, [ 9, 9, 9 ]);
    assert(a == [ 1, 2, 3, 4 ]);
    assert(b == [ 1, 9, 9, 9, 4 ]);
}

unittest
{
    auto a = [ 1, 2, 3, 4 ];
    assert(replace(a, 0, 0, [5, 6, 7]) == [5, 6, 7, 1, 2, 3, 4]);
    assert(replace(a, 0, 2, cast(int[])[]) == [3, 4]);
    assert(replace(a, 0, 4, [5, 6, 7]) == [5, 6, 7]);
    assert(replace(a, 0, 2, [5, 6, 7]) == [5, 6, 7, 3, 4]);
    assert(replace(a, 2, 4, [5, 6, 7]) == [1, 2, 5, 6, 7]);

    assert(replace(a, 0, 0, filter!"true"([5, 6, 7])) == [5, 6, 7, 1, 2, 3, 4]);
    assert(replace(a, 0, 2, filter!"true"(cast(int[])[])) == [3, 4]);
    assert(replace(a, 0, 4, filter!"true"([5, 6, 7])) == [5, 6, 7]);
    assert(replace(a, 0, 2, filter!"true"([5, 6, 7])) == [5, 6, 7, 3, 4]);
    assert(replace(a, 2, 4, filter!"true"([5, 6, 7])) == [1, 2, 5, 6, 7]);
    assert(a == [ 1, 2, 3, 4 ]);

    auto testStr(T, U)(string file = __FILE__, size_t line = __LINE__)
    {

        auto l = to!T("hello");
        auto r = to!U(" world");

        enforce(replace(l, 0, 0, r) == " worldhello",
                new AssertError("testStr failure 1", file, line));
        enforce(replace(l, 0, 3, r) == " worldlo",
                new AssertError("testStr failure 2", file, line));
        enforce(replace(l, 3, l.length, r) == "hel world",
                new AssertError("testStr failure 3", file, line));
        enforce(replace(l, 0, l.length, r) == " world",
                new AssertError("testStr failure 4", file, line));
        enforce(replace(l, l.length, l.length, r) == "hello world",
                new AssertError("testStr failure 5", file, line));
    }

    testStr!(string, string)();
    testStr!(string, wstring)();
    testStr!(string, dstring)();
    testStr!(wstring, string)();
    testStr!(wstring, wstring)();
    testStr!(wstring, dstring)();
    testStr!(dstring, string)();
    testStr!(dstring, wstring)();
    testStr!(dstring, dstring)();
}
+/

/++
    Replaces elements from $(D array) with indices ranging from $(D from)
    (inclusive) to $(D to) (exclusive) with the range $(D stuff). Expands or
    shrinks the array as needed.

Example:
---
int[] a = [ 1, 2, 3, 4 ];
a.replaceInPlace(1, 3, [ 9, 9, 9 ]);
assert(a == [ 1, 9, 9, 9, 4 ]);
---
 +/
void replaceInPlace(T, Range)(ref T[] array, size_t from, size_t to, Range stuff)
    if(isDynamicArray!Range &&
       is(ElementEncodingType!Range : T) &&
       !is(T == const T) &&
       !is(T == immutable T))
{
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
        insertInPlace(array, to, stuff[replaceLen .. $]);
    }
}

void replaceInPlace(T, Range)(ref T[] array, size_t from, size_t to, Range stuff)
    if(isInputRange!Range &&
       ((!isDynamicArray!Range && is(ElementType!Range : T)) ||
        (isDynamicArray!Range && is(ElementType!Range : T) &&
             (is(T == const T) || is(T == immutable T))) ||
        isSomeString!(T[]) && is(ElementType!Range : dchar)))
{
    auto app = appender!(T[])();
    app.put(array[0 .. from]);
    app.put(stuff);
    app.put(array[to .. $]);
    array = app.data;

    //This simplified version can be used once the old replace has been removed
    //and the new one uncommented out.
    //array = replace(array, from, to stuff);
}

//Verify Examples.
unittest
{
    int[] a = [1, 4, 5];
    replaceInPlace(a, 1u, 2u, [2, 3, 4]);
    assert(a == [1, 2, 3, 4, 5]);
    replaceInPlace(a, 1u, 2u, cast(int[])[]);
    assert(a == [1, 3, 4, 5]);
}

unittest
{
    bool test(T, U, V)(T orig, size_t from, size_t to, U toReplace, V result,
               string file = __FILE__, size_t line = __LINE__)
    {
        {
            static if(is(T == typeof(T.dup)))
                auto a = orig.dup;
            else
                auto a = orig.idup;

            a.replaceInPlace(from, to, toReplace);
            if(!std.algorithm.equal(a, result))
                return false;
        }

        static if(isInputRange!U)
        {
            orig.replaceInPlace(from, to, filter!"true"(toReplace));
            return std.algorithm.equal(orig, result);
        }
        else
            return true;
    }

    assert(test([1, 2, 3, 4], 0, 0, [5, 6, 7], [5, 6, 7, 1, 2, 3, 4]));
    assert(test([1, 2, 3, 4], 0, 2, cast(int[])[], [3, 4]));
    assert(test([1, 2, 3, 4], 0, 4, [5, 6, 7], [5, 6, 7]));
    assert(test([1, 2, 3, 4], 0, 2, [5, 6, 7], [5, 6, 7, 3, 4]));
    assert(test([1, 2, 3, 4], 2, 4, [5, 6, 7], [1, 2, 5, 6, 7]));

    assert(test([1, 2, 3, 4], 0, 0, filter!"true"([5, 6, 7]), [5, 6, 7, 1, 2, 3, 4]));
    assert(test([1, 2, 3, 4], 0, 2, filter!"true"(cast(int[])[]), [3, 4]));
    assert(test([1, 2, 3, 4], 0, 4, filter!"true"([5, 6, 7]), [5, 6, 7]));
    assert(test([1, 2, 3, 4], 0, 2, filter!"true"([5, 6, 7]), [5, 6, 7, 3, 4]));
    assert(test([1, 2, 3, 4], 2, 4, filter!"true"([5, 6, 7]), [1, 2, 5, 6, 7]));

    auto testStr(T, U)(string file = __FILE__, size_t line = __LINE__)
    {

        auto l = to!T("hello");
        auto r = to!U(" world");

        enforce(test(l, 0, 0, r, " worldhello"),
                new AssertError("testStr failure 1", file, line));
        enforce(test(l, 0, 3, r, " worldlo"),
                new AssertError("testStr failure 2", file, line));
        enforce(test(l, 3, l.length, r, "hel world"),
                new AssertError("testStr failure 3", file, line));
        enforce(test(l, 0, l.length, r, " world"),
                new AssertError("testStr failure 4", file, line));
        enforce(test(l, l.length, l.length, r, "hello world"),
                new AssertError("testStr failure 5", file, line));
    }

    testStr!(string, string)();
    testStr!(string, wstring)();
    testStr!(string, dstring)();
    testStr!(wstring, string)();
    testStr!(wstring, wstring)();
    testStr!(wstring, dstring)();
    testStr!(dstring, string)();
    testStr!(dstring, wstring)();
    testStr!(dstring, dstring)();
}

/++
    $(RED Scheduled for deprecation. Use $(XREF array, replaceInPlace) instead.)

    Same as $(XREF array, replaceInPlace).
  +/
void replace(T, Range)(ref T[] array, size_t from, size_t to, Range stuff)
if (isDynamicArray!Range && is(ElementType!Range : T))
{
    pragma(msg, "std.array.replace(T, Range)(ref T[] array, size_t from, " ~
                "size_t to, Range stuff) has been scheduled for deprecation. " ~
                "Use replaceInPlace instead.");
    replaceInPlace(array, from, to, stuff);
}

/++
    Replaces the first occurrence of $(D from) with $(D to) in $(D a). Returns a
    new array without changing the contents of $(D subject).
 +/
R1 replaceFirst(R1, R2, R3)(R1 subject, R2 from, R3 to)
if (isDynamicArray!R1 && isForwardRange!R2 && isInputRange!R3)
{
    if (from.empty) return subject;
    auto balance = std.algorithm.find(subject, from.save);
    if (balance.empty) return subject;
    auto app = appender!R1();
    app.put(subject[0 .. subject.length - balance.length]);
    app.put(to.save);
    subject = balance[from.length .. $];

    return app.data;
}

unittest
{
    debug(string) printf("array.replaceFirst.unittest\n");

    alias TypeTuple!(string, wstring, dstring, char[], wchar[], dchar[])
        TestTypes;

    foreach (S; TestTypes)
    {
        auto s = to!S("This is a foo foo list");
        auto from = to!S("foo");
        auto into = to!S("silly");
        S r;
        int i;

        r = replace(s, from, into);
        i = cmp(r, "This is a silly silly list");
        assert(i == 0);

        r = replace(s, to!S(""), into);
        i = cmp(r, "This is a foo foo list");
        assert(i == 0);

        assert(replace(r, to!S("won't find this"), to!S("whatever")) is r);
    }
}

/++
    Returns an array that is $(D s) with $(D slice) replaced by
    $(D replacement[]).
 +/
T[] replaceSlice(T)(T[] s, in T[] slice, in T[] replacement)
in
{
    // Verify that slice[] really is a slice of s[]
    assert(overlap(s, slice) is slice);
}
body
{
    auto result = new Unqual!(typeof(s[0]))[
        s.length - slice.length + replacement.length];
    immutable so = slice.ptr - s.ptr;
    result[0 .. so] = s[0 .. so];
    result[so .. so + replacement.length] = replacement;
    result[so + replacement.length .. result.length] =
        s[so + slice.length .. s.length];

    return cast(T[]) result;
}

unittest
{
    debug(std_array) printf("array.replaceSlice.unittest\n");

    string s = "hello";
    string slice = s[2 .. 4];

    auto r = replaceSlice(s, slice, "bar");
    int i;
    i = cmp(r, "hebaro");
    assert(i == 0);
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
            immutable len = _data.arr.length;
            immutable growsize = (newCapacity - len) * T.sizeof;
            auto u = GC.extend(_data.arr.ptr, growsize, growsize);
            if(u)
            {
                // extend worked, update the capacity
                _data.capacity = u / T.sizeof;
            }
            else
            {
                // didn't work, must reallocate
                auto bi = GC.qalloc(newCapacity * T.sizeof,
                        (typeid(T[]).next.flags & 1) ? 0 : GC.BlkAttr.NO_SCAN);
                _data.capacity = bi.size / T.sizeof;
                if(len)
                    memcpy(bi.base, _data.arr.ptr, len * T.sizeof);
                _data.arr = (cast(Unqual!(T)*)bi.base)[0..len];
                // leave the old data, for safety reasons
            }
        }
    }

/**
Returns the capacity of the array (the maximum number of elements the
managed array can accommodate before triggering a reallocation).  If any
appending will reallocate, $(D capacity) returns $(D 0).
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

    // ensure we can add nelems elements, resizing as necessary
    private void ensureAddable(size_t nelems)
    {
        if(!_data)
            _data = new Data;
        immutable len = _data.arr.length;
        immutable reqlen = len + nelems;
        if (reqlen > _data.capacity)
        {
            // Time to reallocate.
            // We need to almost duplicate what's in druntime, except we
            // have better access to the capacity field.
            auto newlen = newCapacity(reqlen);
            // first, try extending the current block
            auto u = GC.extend(_data.arr.ptr, nelems * T.sizeof, (newlen - len) * T.sizeof);
            if(u)
            {
                // extend worked, update the capacity
                _data.capacity = u / T.sizeof;
            }
            else
            {
                // didn't work, must reallocate
                auto bi = GC.qalloc(newlen * T.sizeof,
                        (typeid(T[]).next.flags & 1) ? 0 : GC.BlkAttr.NO_SCAN);
                _data.capacity = bi.size / T.sizeof;
                if(len)
                    memcpy(bi.base, _data.arr.ptr, len * T.sizeof);
                _data.arr = (cast(Unqual!(T)*)bi.base)[0..len];
                // leave the old data, for safety reasons
            }
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
            ensureAddable(1);
            immutable len = _data.arr.length;
            _data.arr.ptr[len] = cast(Unqual!T)item;
            _data.arr = _data.arr.ptr[0 .. len + 1];
        }
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
                     !is(Range == Unqual!T[]) &&
                     !is(Range == const(T)[]) &&
                     !is(Range == immutable(T)[])) &&
                    is(typeof(items.length) == size_t))
        {
            // optimization -- if this type is something other than a string,
            // and we are adding exactly one element, call the version for one
            // element.
            static if(!isSomeChar!T)
            {
                if(items.length == 1)
                {
                    put(items.front);
                    return;
                }
            }

            // make sure we have enough space, then add the items
            ensureAddable(items.length);
            immutable len = _data.arr.length;
            immutable newlen = len + items.length;
            _data.arr = _data.arr.ptr[0..newlen];
            static if(is(typeof(_data.arr[] = items)))
            {
                _data.arr.ptr[len..newlen] = items;
            }
            else
            {
                for(size_t i = len; !items.empty; items.popFront(), ++i)
                    _data.arr.ptr[i] = cast(Unqual!T)items.front;
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
will be used by the appender.  $(D RefAppender) assumes that arr is a non-null
value.

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
appending will reallocate, $(D capacity) returns $(D 0).
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

/++
    Convenience function that returns an $(D Appender!(A)) object initialized
    with $(D array).
 +/
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

    // Issue 5663 tests
    {
        Appender!(char[]) app5663i;
        assertNotThrown(app5663i.put("\xE3"));
        assert(app5663i.data == "\xE3");

        Appender!(char[]) app5663c;
        assertNotThrown(app5663c.put(cast(const(char)[])"\xE3"));
        assert(app5663c.data == "\xE3");

        Appender!(char[]) app5663m;
        assertNotThrown(app5663m.put(cast(char[])"\xE3"));
        assert(app5663m.data == "\xE3");
    }
}

/++
    Convenience function that returns a $(D RefAppender!(A)) object initialized
    with $(D array).  Don't use null for the $(D array) pointer, use the other
    version of $(D appender) instead.
 +/
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
