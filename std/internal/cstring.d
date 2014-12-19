/**
Helper functions for working with $(I C strings).

This module is intended to provide fast, safe and garbage free
way to work with $(I C strings).

Examples:
---
version(Posix):

import core.stdc.stdlib: free;
import core.sys.posix.stdlib: setenv;
import std.exception: enforce;

void setEnvironment(in char[] name, in char[] value)
{ enforce(setenv(name.tempCString(), value.tempCString(), 1) != -1); }
---
---
version(Windows):

import core.sys.windows.windows: SetEnvironmentVariableW;
import std.exception: enforce;

void setEnvironment(in char[] name, in char[] value)
{ enforce(SetEnvironmentVariableW(name.tempCStringW(), value.tempCStringW())); }
---

Copyright: Denis Shelomovskij 2013-2014

License: $(HTTP boost.org/LICENSE_1_0.txt, Boost License 1.0).

Authors: Denis Shelomovskij

Macros:
COREREF = $(HTTP dlang.org/phobos/core_$1.html#$2, $(D core.$1.$2))
*/
module std.internal.cstring;


import std.traits;

version(unittest)
@property inout(C)[] asArray(C)(inout C* cstr) pure nothrow @nogc
if(isSomeChar!C)
in { assert(cstr); }
body
{
    size_t length = 0;
    while(cstr[length])
        ++length;
    return cstr[0 .. length];
}

/**
Creates temporary $(I C string) with copy of passed text.

Returned object is implicitly convertible to $(D const To*) and
has two properties: $(D ptr) to access $(I C string) as $(D const To*)
and $(D buffPtr) to access it as $(D To*).

The temporary $(I C string) is valid unless returned object is destroyed.
Thus if returned object is assigned to a variable the temporary is
valid unless the variable goes out of scope. If returned object isn't
assigned to a variable it will be destroyed at the end of creating
primary expression.

Implementation_note:
For small strings tempCString will use stack allocated buffer,
for large strings (approximately 250 characters and more) it will
allocate temporary one using C's $(D malloc).

Note:
This function is intended to be used in function call expression (like
$(D strlen(str.tempCString()))). Incorrect usage of this function may
lead to memory corruption.
See $(RED WARNING) in $(B Examples) section.
*/
auto tempCString(To = char, From)(in From[] str) nothrow @nogc
if(isSomeChar!To && isSomeChar!From)
{
    import core.checkedint : addu;
    import core.exception : onOutOfMemoryError;

    enum useStack = cast(To*) -1;

    static struct Res
    {
    nothrow @nogc:

        @disable this();
        @disable this(this);
        alias ptr this;

        @property inout(To)* buffPtr() inout @safe pure
        { return _ptr == useStack ? _buff.ptr : _ptr; }

        @property const(To)* ptr() const @safe pure
        { return buffPtr; }

        ~this()
        { if(_ptr != useStack) rawFree(_ptr); }

    private:
        To* _ptr;
        To[256] _buff;
    }

    // TODO: Don't stack allocate uninitialized array to
    // not confuse unprecise GC.

    Res res = void;
    if(!str.ptr)
    {
        res._ptr = null;
        return res;
    }

    // Note: res._ptr can't point to res._buff as structs are movable.

    bool overflow = false;
    const totalCount = addu(maxLength!To(str), 1, overflow);
    if(overflow)
        onOutOfMemoryError();
    const needAllocate = totalCount > res._buff.length;
    To[] arr = copyEncoded(str, needAllocate ?
        allocate!To(totalCount)[0 .. $ - 1] : res._buff[0 .. totalCount - 1]);
    *(arr.ptr + arr.length) = '\0';
    res._ptr = needAllocate ? arr.ptr : useStack;
    return res;
}

///
nothrow @nogc unittest
{
    import core.stdc.string;

    string str = "abc";

    // Intended usage
    assert(strlen(str.tempCString()) == 3);

    // Correct usage
    auto tmp = str.tempCString();
    assert(strlen(tmp) == 3); // or `tmp.ptr`, or `tmp.buffPtr`

    // $(RED WARNING): $(RED Incorrect usage)
    auto pInvalid1 = str.tempCString().ptr;
    const char* pInvalid2 = str.tempCString();
    // Both pointers refer to invalid memory here as
    // returned values aren't assigned to a variable and
    // both primary expressions are ended.
}

nothrow @nogc unittest
{
    assert("abc".tempCString().asArray == "abc");
    assert("abc"d.tempCString().ptr.asArray == "abc");
    assert("abc".tempCString!wchar().buffPtr.asArray == "abc"w);
}

// Test for Issue 13367: ensure there is no memory corruption
nothrow @nogc unittest
{
    @property str(C)() { C[300] arr = 'a'; return arr; }
    assert(str!char.tempCString!wchar().asArray == str!wchar);
    assert(str!char.tempCString!dchar().asArray == str!dchar);
}

version(Windows)
    alias tempCStringW = tempCString!(wchar, char);


private:


// Helper UTF functions.
// ----------------------------------------------------------------------------------------------------

/**
Returns maximum possible length of string conversion
to another Unicode Transformation Format result.
*/
size_t maxLength(To, From)(in size_t length) pure nothrow @nogc
if(isSomeChar!To && isSomeChar!From)
{
    static if (To.sizeof >= From.sizeof)
        enum k = 1; // worst case: every code unit represents a character
    else static if (To.sizeof == 1 && From.sizeof == 2)
        enum k = 3; // worst case: every wchar in top of BMP
    else static if (To.sizeof == 1 && From.sizeof == 4)
        enum k = 4; // worst case: every dchar not in BMP
    else static if (To.sizeof == 2 && From.sizeof == 4)
        enum k = 2; // worst case: every dchar not in BMP
    else
        static assert(0);
    return length * k;
}

/// ditto
size_t maxLength(To, From)(in From[] str) pure nothrow @nogc
{ return maxLength!(To, From)(str.length); }

pure nothrow @nogc unittest
{
    assert(maxLength!char("abc") == 3);
    assert(maxLength!dchar("abc") == 3);
    assert(maxLength!char("abc"w) == 9);
    assert(maxLength!char("abc"d) == 12);
    assert(maxLength!wchar("abc"d) == 6);
}


/**
Copies text from $(D source) to $(D buff) performing conversion
to different Unicode Transformation Format if needed.

$(D buff) must be large enough to hold the result.

Returns:
Slice of the provided buffer $(D buff) with the copy of $(D source).
*/
To[] copyEncoded(To, From)(in From[] source, To[] buff) @trusted nothrow @nogc
if(isSomeChar!To && isSomeChar!From)
{
    static if(is(Unqual!To == Unqual!From))
    {
        return buff[0 .. source.length] = source[];
    }
    else
    {
        import std.utf : byChar, byWchar, byDchar;
        alias GenericTuple(Args...) = Args;
        alias byFunc = GenericTuple!(byChar, byWchar, null, byDchar)[To.sizeof - 1];

        To* ptr = buff.ptr;
        const To* last = ptr + buff.length;
        foreach(const c; byFunc(source))
        {
            assert(ptr != last);
            *ptr++ = c;
        }
        return buff[0 .. ptr - buff.ptr];
    }
}

///
pure nothrow @nogc unittest
{
    const str = "abc-ЭЮЯ";
    wchar[100] wsbuff;
    assert(copyEncoded(str, wsbuff) == "abc-ЭЮЯ"w);
}

pure nothrow @nogc unittest
{
    wchar[100] wsbuff;
    assert(copyEncoded("abc-ЭЮЯ"w, wsbuff) == "abc-ЭЮЯ"w);
}

pure unittest
{
    import std.range;
    import std.utf : toUTF16, toUTF32;

    const str = "abc-ЭЮЯ";
    char[100] sbuff;

    {
        wchar[100] wsbuff;
        const strW = toUTF16(str);
        assert(copyEncoded(str, wsbuff[0 .. strW.length]) == strW);
        assert(copyEncoded(strW, sbuff[0 .. str.length]) == str);
    }
    {
        dchar[100] dsbuff;
        const strD = toUTF32(str);
        assert(copyEncoded(str, dsbuff[0 .. walkLength(str)]) == strD);
        assert(copyEncoded(strD, sbuff[0 .. str.length]) == str);
    }
}


// Helper functions for memory allocation & freeing.
// ----------------------------------------------------------------------------------------------------

// WARNING: Alignment is implementation defined in C so the value '4'
// relies on undocumented but common behaviour.
// FIXME: This value should be checked and adjusted on every C runtime.
enum mallocAlignment = 4;

// NOTE: `allocate`/`rawFree` simply wraps C allocation functions for now
// but it may be changed in future so one shouldn't rely on that.

T[] allocate(T)(in size_t count) nothrow @nogc
if(T.alignof <= mallocAlignment)
in { assert(count); }
body
{
    import core.exception : onOutOfMemoryError;
    import core.checkedint: mulu;

    bool overflow = false;
    const buffBytes = mulu(T.sizeof, count, overflow);
    if(overflow)
        onOutOfMemoryError();

    auto ptr = cast(T*) tryRawAllocate(buffBytes);
    if(!ptr)
        onOutOfMemoryError();

    return ptr[0 .. count];
}

void* tryRawAllocate(in size_t count) nothrow @nogc
in { assert(count); }
body
{
    import core.stdc.stdlib: malloc;
    // Workaround snn @@@BUG11646@@@
    version(DigitalMars) version(Win32)
        if(count > 0xD5550000) return null;

    // FIXME: `malloc` must be checked on every C runtime for
    // possible bugs and workarounded if necessary.

    return malloc(count);
}

void rawFree(void* ptr) nothrow @nogc
{
    import core.stdc.stdlib: free;
    free(ptr);
}
