module std.v2alpha.range.primitives;

/**
@@@TODO@@@ Publicly imported names across modules should copy or link those
names' respective documentation. Here, we reuse empty and isInputRange because
we don't change their meaning in v2.
*/
public import std.range.primitives : empty, isInputRange;

/**
@@@TODO@@@ This function redefines `front` for v2, meaning its documentation
will override the documentation of `front` found in v1. The difference is of
course that the new `front` does not autodecode.
*/
@property ref inout(T) front(T)(return scope inout(T)[] a) @safe pure nothrow @nogc
if (!is(T[] == void[]))
{
    assert(a.length, "Attempting to fetch the front of an empty array of " ~ T.stringof);
    return a[0];
}

/**
@@@TODO@@@ This function redefines `popFront` for v2, meaning its documentation
will override the documentation of `popFront` found in v1. The difference is of
course that the new `popFront` does not autodecode.
*/
void popFront(T)(scope ref inout(T)[] a) @safe pure nothrow @nogc
if (!is(T[] == void[]))
{
    assert(a.length, "Attempting to popFront() past the end of an array of " ~ T.stringof);
    a = a[1 .. $];
}
