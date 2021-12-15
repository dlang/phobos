module std2xalpha.range.primitives;

version = std_use_public_import;

/**
@@@TODO@@@ Publicly imported names across modules should copy or link those
names' respective documentation. Here, we reuse empty and isInputRange because
we don't change their meaning in std2x.
*/
version (std_use_public_import)
{
    public import std.range.primitives;
}
else
{
    import v1 = std.range.primitives;
    alias isInputRange = v1.isInputRange;
    alias put = v1.put;
    alias isOutputRange = v1.isOutputRange;
    alias isForwardRange = v1.isForwardRange;
    alias isBidirectionalRange = v1.isBidirectionalRange;
    alias isRandomAccessRange = v1.isRandomAccessRange;
    alias hasMobileElements = v1.hasMobileElements;
    alias ElementEncodingType = v1.ElementEncodingType;
    alias hasSwappableElements = v1.hasSwappableElements;
    alias hasAssignableElements = v1.hasAssignableElements;
    alias hasLvalueElements = v1.hasLvalueElements;
    alias hasLength = v1.hasLength;
    alias isInfinite = v1.isInfinite;
    alias hasSlicing = v1.hasSlicing;
    alias walkLength = v1.walkLength;
    alias popFrontN = v1.popFrontN;
    alias popBackN = v1.popBackN;
    alias popFrontExactly = v1.popFrontExactly;
    alias popBackExactly = v1.popBackExactly;
    alias moveFront = v1.moveFront;
    alias moveBack = v1.moveBack;
    alias moveAt = v1.moveAt;
    alias empty = v1.empty;
    alias save = v1.save;
    alias autodecodeStrings = v1.autodecodeStrings;
    alias back = v1.back;
    alias ImplementLength = v1.ImplementLength;
}

/**
@@@TODO@@@ This function redefines `front` for std2x, meaning its documentation
will override the documentation of `front` found in std. The difference is of
course that the new `front` does not autodecode.
*/
@property ref inout(T) front(T)(return scope inout(T)[] a) @safe pure nothrow @nogc
if (!is(T[] == void[]))
{
    assert(a.length, "Attempting to fetch the front of an empty array of " ~ T.stringof);
    return a[0];
}

///
unittest
{
    string s = "ä"; // 0xC3 0xA4 in UTF8
    assert(s.front == 0xC3);
}

/**
@@@TODO@@@ This function redefines `popFront` for std2x, meaning its documentation
will override the documentation of `popFront` found in std. The difference is of
course that the new `popFront` does not autodecode.
*/
void popFront(T)(scope ref inout(T)[] a) @safe pure nothrow @nogc
if (!is(T[] == void[]))
{
    assert(a.length, "Attempting to popFront() from an empty array of " ~ T.stringof);
    a = a[1 .. $];
}

///
unittest
{
    string s = "ä"; // 0xC3 0xA4
    s.popFront;
    assert(s.length == 1);
    assert(s[0] == 0xA4);
    assert(s.front == 0xA4);
}

/**
@@@TODO@@@ This function redefines `popBack` for std2x, meaning its documentation
will override the documentation of `popBack` found in std. The difference is of
course that the new `popBack` does not autodecode.
*/
void popBack(T)(scope ref inout(T)[] a) @safe pure nothrow @nogc
if (!is(T[] == void[]))
{
    assert(a.length, "Attempting to popBack() from an empty array of " ~ T.stringof);
    a = a[0 .. $ - 1];
}

///
unittest
{
    string s = "ä"; // 0xC3 0xA4
    s.popBack;
    assert(s.length == 1);
    assert(s[0] == 0xC3);
    assert(s.front == 0xC3);
}

/**
@@@TODO@@@ This alias redefines `ElementType` for std2x, meaning its documentation
will override the documentation of `ElementType` found in std. The difference is of
course that the new `ElementType` does not support autodecoding, so it's the same as
`ElementEncodingType`.
*/
alias ElementType(R) = ElementEncodingType!R;
