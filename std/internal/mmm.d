/**
This module provides OOM-checked and memory safe interfaces to C's $(D malloc)
and $(D calloc) functions.

Copyright: Jakob Ovrum 2015

License: $(HTTP boost.org/LICENSE_1_0.txt, Boost License 1.0).

Authors: Jakob Ovrum
*/
module std.internal.mmm;

import core.stdc.stdlib : calloc, malloc;
import std.traits : hasElaborateDestructor, hasIndirections;
import std.range.primitives;

private void[] checkedMallocArray(size_t n) nothrow @system @nogc
{
    import core.exception : onOutOfMemoryError;

    if (auto p = malloc(n))
        return p[0 .. n];
    else
    {
        onOutOfMemoryError();
        assert(false);
    }
}

T* checkedMalloc(T)() @system
    if (hasIndirections!T)
{
    return cast(T*)checkedMallocArray(T.sizeof).ptr;
}

T* checkedMalloc(T)() @trusted
    if (!hasIndirections!T)
{
    return cast(T*)checkedMallocArray(T.sizeof).ptr;
}

T* checkedMalloc(T, Args...)(auto ref Args args) // safety inferred
{
    import core.stdc.stdlib : free;
    import std.conv : emplaceRef;

    auto p = () @trusted { return checkedMalloc!T(); }();
    scope(failure) () @trusted { free(p); }();

    emplaceRef(*p, args);
    return p;
}

T[] checkedMallocArray(T)(size_t n) @system
    if (hasIndirections!T)
{
    return cast(T[])checkedMallocArray(T.sizeof * n);
}

T[] checkedMallocArray(T)(size_t n) @trusted
    if (!hasIndirections!T)
{
    return cast(T[])checkedMallocArray(T.sizeof * n);
}

T[] checkedMallocArray(T, Range)(Range range) // safety inferred
    if (isInputRange!Range && hasLength!Range && is(ElementType!Range : T))
{
    import core.stdc.stdlib : free;
    import std.exception : collectException;
    import std.conv : emplaceRef;
    import std.traits : hasElaborateDestructor;

    immutable length = range.length;
    auto arr = () @trusted { return checkedMallocArray!T(length); }();

    size_t i = 0; // Number of constructed elements

    scope(failure)
    {
        static if(hasElaborateDestructor!T)
        {
            for (; i != 0; --i)
            {
                // collectException(destroy(arr[i])); // Issue 12647
                try
                    destroy(arr[i]);
                catch(Exception) {}
            }
        }
        () @trusted { free(arr.ptr); }();
    }

    static if (isForwardRange!Range)
        auto r = range.save;
    else
        alias r = range;

    for(; !r.empty; ++i, r.popFront())
        emplaceRef!T(arr[i], r.front);

    assert(i == length);
    return arr;
}

ElementType!Range[] checkedMallocArray(Range)(Range range)
    if (isInputRange!Range && hasLength!Range)
{
    return checkedMallocArray!(ElementType!Range, Range)(range);
}

T* checkedCalloc(T)() @trusted
{
    import core.exception : onOutOfMemoryError;

    if (auto p = calloc(T.sizeof, 1))
        return cast(T*)p;
    else
    {
        onOutOfMemoryError();
        assert(false);
    }
}

T[] checkedCallocArray(T)(size_t n) @trusted
{
    import core.exception : onOutOfMemoryError;

    if (auto p = calloc(T.sizeof, n))
        return (cast(T*)p)[0 .. n];
    else
    {
        onOutOfMemoryError();
        assert(false);
    }
}

void[] destroyArray(T)(ref T[] array)
    if(hasElaborateDestructor!T)
{
    foreach_reverse(ref e; array)
    {
        try
            destroy(e);
        catch(Exception) {}
    }

    void[] ret = array;
    array = null;
    return ret;
}

void[] destroyArray(T)(ref T[] array)
    if(!hasElaborateDestructor!T)
{
    return array;
}

nothrow @safe @nogc unittest
{
    if (0) // Make sure of @safe-ty without free'ing
    {
        cast(void)checkedMalloc!int();
        cast(void)checkedMallocArray!int(1);
        // checkedMallocArray!(int*)((int*[]).init); // issue 12647

        cast(void)checkedCalloc!(int*)();
        cast(void)checkedCallocArray!(int*)(1);

        int* p = null;
        cast(void)checkedMalloc!(int*)(p);

        static immutable arr = [1];
        cast(void)checkedMallocArray!int(arr);

        static assert(!__traits(compiles, checkedMalloc!(int*)()));
        static assert(!__traits(compiles, checkedMallocArray!(int*)(1)));

        static struct S { this(this) @system {} }
        S s;
        static assert(!__traits(compiles, checkedMalloc!S(s)));
    }
}

nothrow @nogc unittest
{
    import core.stdc.stdlib : free;

    int* i = checkedMalloc!int();
    *i = 42;
    assert(*i == 42);
    free(i);

    int** ii = checkedMalloc!(int*)();
    *ii = null;
    assert(*ii == null);
    free(ii);
    ii = null;

    int twentyFour = 24;
    i = checkedMalloc!int(twentyFour);
    assert(*i == 24);

    i = checkedCalloc!int();
    assert(*i == 0);
    free(i);
    i = null;

    int[] arr = checkedMallocArray!int(2);
    assert(arr.length == 2);
    arr[0] = 42;
    arr[1] = 24;
    assert(arr[0] == 42);
    assert(arr[1] == 24);
    free(arr.ptr);

    static immutable orig = [42, 24];
    arr = checkedMallocArray!int(orig);
    assert(arr[0] == 42);
    assert(arr[1] == 24);
    free(arr.ptr);
    arr = null;

    int*[] arr2 = checkedMallocArray!(int*)(1);
    arr2[0] = null;
    assert(arr2[0] == null);
    free(arr2.ptr);

    arr2 = checkedCallocArray!(int*)(1);
    assert(arr2[0] == null);
    free(arr2.ptr);
    arr2 = null;
}

// Attribute inference fails due to the following issue:
// https://issues.dlang.org/show_bug.cgi?id=12647
nothrow @safe unittest
{
    import core.stdc.stdlib : free;
    import std.exception : assertNotThrown, assertThrown;

    static immutable cheatsheet = [24, 42];
    int[] arr = checkedMallocArray!int(cheatsheet[]);
    assert(arr.length == 2);
    assert(arr[0] == 24);
    assert(arr[1] == 42);
    () @trusted {
        free(arr.ptr);
        arr = null;
    }();

    static struct S
    {
        static int counter = 0;

        this(this) @safe
        {
            if (counter == 2)
                throw new Exception("");
            ++counter;
        }

        ~this() nothrow @safe
        {
            --counter;
        }
    }

    static cheatsheet2 = [S(), S(), S()];
    assertThrown(checkedMallocArray(cheatsheet2[]));
    assert(S.counter == 0);

    auto arr2 = assertNotThrown(checkedMallocArray(cheatsheet2[0 .. 1]));
    assert(S.counter == 1);
    auto destroyed = destroyArray(arr2);
    () @trusted { free(destroyed.ptr); }();
}
