module std2xalpha.range.primitives;

/*
@@@TODO@@@ Publicly imported names across modules should copy or link those
names' respective documentation. Here, we reuse empty and isInputRange because
we don't change their meaning in std2x.
*/
import v1 = std.range.primitives;

alias theCanon = v1.canon!"std2xalpha";

alias isInputRange = theCanon.isInputRange;
alias put = theCanon.put;
//alias isNativeOutputRange = theCanon.isNativeOutputRange;
alias isOutputRange = theCanon.isOutputRange;
alias isForwardRange = theCanon.isForwardRange;
alias isBidirectionalRange = theCanon.isBidirectionalRange;
//alias isRandomAccessRange = theCanon.isRandomAccessRange;
alias hasMobileElements = theCanon.hasMobileElements;
//alias ElementType = theCanon.ElementType;
alias ElementEncodingType = theCanon.ElementEncodingType;
alias hasSwappableElements = theCanon.hasSwappableElements;
alias hasAssignableElements = theCanon.hasAssignableElements;
alias hasLvalueElements = theCanon.hasLvalueElements;
//alias hasLength = theCanon.hasLength;
alias isInfinite = theCanon.isInfinite;
alias hasSlicing = theCanon.hasSlicing;
alias walkLength = theCanon.walkLength;
alias popFrontN = theCanon.popFrontN;
alias popBackN = theCanon.popBackN;
alias popFrontExactly = theCanon.popFrontExactly;
alias popBackExactly = theCanon.popBackExactly;
alias moveFront = theCanon.moveFront;
alias moveBack = theCanon.moveBack;
alias moveAt = theCanon.moveAt;
alias empty = theCanon.empty;
alias save = theCanon.save;
// alias popFront = theCanon.popFront;
// alias popBack = theCanon.popBack;
alias autodecodeStrings = theCanon.autodecodeStrings;
// alias front = theCanon.front;
// alias back = theCanon.back;
alias ImplementLength = theCanon.ImplementLength;

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
@@@TODO@@@ This function redefines `back` for std2x, meaning its documentation
will override the documentation of `back` found in std. The difference is of
course that the new `back` does not autodecode.
*/
@property ref inout(T) back(T)(return scope inout(T)[] a) @safe pure nothrow @nogc
if (!is(T[] == void[]))
{
    assert(a.length, "Attempting to fetch the back of an empty array of " ~ T.stringof);
    return a[$ - 1];
}

///
unittest
{
    string s = "ä"; // 0xC3 0xA4 in UTF8
    assert(s.back == 0xA4);
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

///
unittest
{
    // Standard arrays: returns the type of the elements of the array
    static assert(is(ElementType!(int[]) == int));
    static assert(is(ElementType!(immutable(int)[]) == immutable int));
    // Accessing .front retrieves the undecoded char
    static assert(is(ElementType!(char[])  == char));
    static assert(is(ElementType!(dchar[]) == dchar));
    // Ditto
    static assert(is(ElementType!(string) == immutable char));
    static assert(is(ElementType!(dstring) == immutable(dchar)));
}

/**
@@@TODO@@@ This alias redefines `isRandomAccessRange` for std2x. The difference is of
course that the new `isRandomAccessRange` does not support autodecoding, so string
types are random access ranges.
*/
enum bool isRandomAccessRange(R) =
    is(typeof(imported!"std2xalpha.traits".lvalueOf!R[1]) == ElementType!R)
    && isForwardRange!R
    && (isBidirectionalRange!R || isInfinite!R)
    && (hasLength!R || isInfinite!R)
    && (isInfinite!R || !is(typeof(imported!"std2xalpha.traits".lvalueOf!R[$ - 1]))
        || is(typeof(imported!"std2xalpha.traits".lvalueOf!R[$ - 1]) == ElementType!R))
;

///
@safe unittest
{
    static assert(isForwardRange!string);
    static assert(isBidirectionalRange!string);
    static assert(isRandomAccessRange!string);
}

/**
@@@TODO@@@ This redefines `hasLength` for std2x. The difference is of
course that the new `hasLength` does not support autodecoding, so string
types do have length, as they should.
*/
enum bool hasLength(R) = is(typeof(((R* r) => r.length)(null)) == size_t);

///
@safe unittest
{
    static assert(hasLength!string);
    static assert(hasLength!wstring);
}
