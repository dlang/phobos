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
import std.range;

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
    if (isSomeChar!To && (isInputRange!From || isSomeString!From))
{
    import core.exception : onOutOfMemoryError;
    import core.stdc.string : memcpy;

    enum useStack = cast(To*) size_t.max;

    alias CF = Unqual!(ElementEncodingType!From);

    static struct Res
    {
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
    }

    Res res = void;     // expensive to fill _buff[]

    // Note: res._ptr can't point to res._buff as structs are movable.

    import std.utf : byUTF;

    To* p      = res._buff.ptr;
    size_t len = res.buffLength;
    size_t i;

    static if (isSomeString!From)
        auto r = cast(const(CF)[])str;
    else
        alias r = str;
    foreach (const c; byUTF!(Unqual!To)(r))
    {
        if (i + 1 == len)
        {
            import core.stdc.stdlib : malloc, realloc;

            if (len >= size_t.max / (2 * To.sizeof))
                onOutOfMemoryError();
            size_t newlen = len * 3 / 2;
            if (p == res._buff.ptr)
            {
                static if (hasLength!From)
                {
                    if (newlen <= str.length)
                        newlen = str.length + 1; // +1 for terminating 0
                }
                p = cast(To*)malloc(newlen * To.sizeof);
                if (!p)
                    onOutOfMemoryError();
                memcpy(p, res._buff.ptr, i * To.sizeof);
            }
            else
            {
                p = cast(To*)realloc(p, newlen * To.sizeof);
                if (!p)
                    onOutOfMemoryError();
            }
            len = newlen;
        }
        p[i++] = c;
    }
    p[i] = 0;
    res._ptr = (p == res._buff.ptr) ? useStack : p;
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

    import std.utf : byChar, byWchar;
    char[300] abc = 'a';
    assert(tempCString(abc[].byChar).buffPtr.asArray == abc);
    assert(tempCString(abc[].byWchar).buffPtr.asArray == abc);
}


version(Windows)
    alias tempCStringW = tempCString!(wchar, const(char)[]);


