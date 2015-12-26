/**
Helper functions for working with $(I C strings).

This module is intended to provide fast, safe and garbage free
way to work with $(I C strings).

Example:
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
import std.range;

version(unittest)
@property inout(C)[] asArray(C)(inout C* cstr) pure nothrow @nogc @trusted
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
Creates temporary 0-terminated $(I C string) with copy of passed text.

Params:
    To = character type of returned C string
    str = string or input range to be converted

Returns:

The value returned is implicitly convertible to $(D const To*) and
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

auto tempCString(To = char, From)(From str)
    if (isSomeChar!To && (isInputRange!From || isSomeString!From) &&
        isSomeChar!(ElementEncodingType!From))
{

    alias CF = Unqual!(ElementEncodingType!From);

    enum To* useStack = () @trusted { return cast(To*)size_t.max; }();

    static struct Res
    {
    @trusted:
    nothrow @nogc:

        @disable this();
        @disable this(this);
        alias ptr this;

        @property inout(To)* buffPtr() inout pure
        {
            return _ptr == useStack ? _buff.ptr : _ptr;
        }

        @property const(To)* ptr() const pure
        {
            return buffPtr;
        }

        ~this()
        {
            if (_ptr != useStack)
            {
                import core.stdc.stdlib : free;
                free(_ptr);
            }
        }

    private:
        To* _ptr;
        version (unittest)
        {
            enum buffLength = 16 / To.sizeof;   // smaller size to trigger reallocations
        }
        else
        {
            enum buffLength = 256 / To.sizeof;   // production size
        }

        To[256 / To.sizeof] _buff;  // the 'small string optimization'

        static Res trustedVoidInit() { Res res = void; return res; }
    }

    Res res = Res.trustedVoidInit();     // expensive to fill _buff[]

    // Note: res._ptr can't point to res._buff as structs are movable.

    To[] p = res._buff[0 .. Res.buffLength];
    size_t i;

    static To[] trustedRealloc(To[] buf, size_t i, To* resptr, size_t strLength)
        @trusted @nogc nothrow
    {
        pragma(inline, false);  // because it's rarely called

        import core.exception   : onOutOfMemoryError;
        import core.stdc.string : memcpy;
        import core.stdc.stdlib : malloc, realloc;

        auto ptr = buf.ptr;
        auto len = buf.length;
        if (len >= size_t.max / (2 * To.sizeof))
            onOutOfMemoryError();
        size_t newlen = len * 3 / 2;
        if (ptr == resptr)
        {
            if (newlen <= strLength)
                newlen = strLength + 1; // +1 for terminating 0
            ptr = cast(To*)malloc(newlen * To.sizeof);
            if (!ptr)
                onOutOfMemoryError();
            memcpy(ptr, resptr, i * To.sizeof);
        }
        else
        {
            ptr = cast(To*)realloc(ptr, newlen * To.sizeof);
            if (!ptr)
                onOutOfMemoryError();
        }
        return ptr[0 .. newlen];
    }

    size_t strLength;
    static if (hasLength!From)
    {
        strLength = str.length;
    }
    import std.utf : byUTF;
    static if (isSomeString!From)
    {
        auto r = cast(const(CF)[])str;  // because inout(CF) causes problems with byUTF
        if (r is null)  // Bugzilla 14980
        {
            res._ptr = null;
            return res;
        }
    }
    else
        alias r = str;
    foreach (const c; byUTF!(Unqual!To)(r))
    {
        if (i + 1 == p.length)
        {
            p = trustedRealloc(p, i, res._buff.ptr, strLength);
        }
        p[i++] = c;
    }
    p[i] = 0;
    res._ptr = (p.ptr == res._buff.ptr) ? useStack : p.ptr;
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

@safe nothrow @nogc unittest
{
    assert("abc".tempCString().asArray == "abc");
    assert("abc"d.tempCString().ptr.asArray == "abc");
    assert("abc".tempCString!wchar().buffPtr.asArray == "abc"w);

    import std.utf : byChar, byWchar;
    char[300] abc = 'a';
    assert(tempCString(abc[].byChar).buffPtr.asArray == abc);
    assert(tempCString(abc[].byWchar).buffPtr.asArray == abc);
}

// Bugzilla 14980
nothrow @nogc unittest
{
    const(char[]) str = null;
    auto res = tempCString(str);
    const char* ptr = res;
    assert(ptr is null);
}

version(Windows)
    alias tempCStringW = tempCString!(wchar, const(char)[]);
