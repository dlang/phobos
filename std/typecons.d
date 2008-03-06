// Written in the D programming language.

/**
This module implements a variety of type constructors, i.e., templates
that allow construction of new, useful general-purpose types.

Macros:

WIKI = Phobos/StdVariant
 
Synopsis:

----
// value tuples
alias Tuple!(float, "x", float, "y", float, "z") Coord;
Coord c;
c._0 = 1;         // access by index-based name
c.field!(1) = 1;  // access by index
c.z = 1;          // access by given name
alias Tuple!(string, string) DicEntry; // names can be omitted

// enumerated values with conversions to and from strings
mixin(defineEnum!("Openmode", "READ", "WRITE", "READWRITE", "APPEND"));
void foo()
{
    Openmode m = Openmode.READ;
    string s = toString(m);
    assert(s == "READ");
    Openmode m1;
    assert(fromString(s, m1) && m1 == m);
}
----

Author:

$(WEB erdani.org, Andrei Alexandrescu)

*/

/*
 *  Copyright (C) 2004-2006 by Digital Mars, www.digitalmars.com
 *  Written by Andrei Alexandrescu, www.erdani.org
 *
 *  This software is provided 'as-is', without any express or implied
 *  warranty. In no event will the authors be held liable for any damages
 *  arising from the use of this software.
 *
 *  Permission is granted to anyone to use this software for any purpose,
 *  including commercial applications, and to alter it and redistribute it
 *  freely, subject to the following restrictions:
 *
 *  o  The origin of this software must not be misrepresented; you must not
 *     claim that you wrote the original software. If you use this software
 *     in a product, an acknowledgment in the product documentation would be
 *     appreciated but is not required.
 *  o  Altered source versions must be plainly marked as such, and must not
 *     be misrepresented as being the original software.
 *  o  This notice may not be removed or altered from any source
 *     distribution.
 */

module std.typecons;
//private import std.stdio;
private import std.metastrings;
private import std.contracts;
private import std.typetuple;
private import std.conv;
private import std.traits;

private template tupleImpl(uint index, T...)
{
    static if (!T.length)
    {
        enum string result = "";
    }
    else
    {
        enum string indexStr = ToString!(index);
        enum string decl = T[0].stringof~" _"~indexStr~";"
            ~"\ntemplate field(int i : "~indexStr~") { alias _"~indexStr
            ~" field; }\n";
        static if (is(typeof(T[1]) : string))
        {
            enum string result = decl ~ "alias _" ~ ToString!(index) ~ " "
                ~ T[1] ~ ";\n" ~ tupleImpl!(index + 1, T[2 .. $]).result;
        }
        else
        {
            enum string result = decl ~ tupleImpl!(index + 1, T[1 .. $]).result;
        }
    }
}

/**
Tuple of values, for example $(D_PARAM Tuple!(int, string)) is a
record that stores an $(D_PARAM int) and a $(D_PARAM
string). $(D_PARAM Tuple) can be used to bundle values together,
notably when returning multiple values from a function. If $(D_PARAM
obj) is a tuple, the individual members are accessible with the syntax
$(D_PARAM obj.field!(0)) for the first field, $(D_PARAM obj.field!(1))
for the second, and so on. A shortcut notation is $(D_PARAM
obj.)&#95;$(D_PARAM 0), $(D_PARAM obj.)&#95;$(D_PARAM 1) etc.

The choice of zero-based indexing instead of one-base indexing was
motivated by the ability to use value tuples with various compile-time
loop constructs (e.g. type tuple iteration), all of which use
zero-based indexing.

Example:

----
Tuple!(int, int) point;
// assign coordinates
point._0 = 5;
point.field!(1) = 6;
// read coordinates
auto x = point.field!(0);
auto y = point._1;
----

Tuple members can be named. It is legal to mix named and unnamed
members. The method above is still applicable to all fields.

Example:

----
alias Tuple!(int, "index", string, "value") Entry;
Entry e;
e.index = 4;
e.value = "Hello";
assert(e._1 == "Hello");
assert(e.field!(0) == 4);
----

Tuples with named fields are distinct types from tuples with unnamed
fields, i.e. each naming imparts a separate type for the tuple. Two
tuple differing in naming only are still distinct, even though they
might have the same structure.

Example:

----
Tuple!(int, "x", int, "y") point1;
Tuple!(int, int) point2;
assert(!is(typeof(point1) == typeof(point2))); // passes
----
*/
struct Tuple(T...)
{
    mixin(tupleImpl!(0, T).result);
    string toString()
    {
        string result;
        foreach (i, Type; FieldTypeTuple!(Tuple))
        {
            static if (i > 0) result ~= " ";
            static if (is(typeof(to!(string)(*new Type))))
            {
                result ~= mixin("to!(string)(field!("~ToString!(i)~"))");
            }
            else
            {
                result ~= "unprintable("~Type.stringof~")";
            }
        }
        return result;
    }
}

unittest
{
    Tuple!(int, "a", int, "b") nosh;
    nosh.a = 5;
    assert(nosh._0 == 5);
    assert(nosh.field!(0) == 5);
    Tuple!(int, int, "b") nosh1;
    assert(!is(typeof(nosh) == typeof(nosh1)));
}

/**
Returns a $(D Tuple) object instantiated and initialized according to
the arguments.

Example:
----
auto value = tuple(5, 6.7, "hello");
assert(value._0 == 5);
assert(value._1 == 6.7);
assert(value._2 == "hello");
----
*/

Tuple!(T) tuple(T...)(T args)
{
    typeof(return) result;
    foreach (i, U; T)
    {
        // @@@BUG@@@ in the compiler
        // This should work: result.field!(i) = args[i];
        mixin("result.field!("~ToString!(i)~") = args[i];");
    }
    return result;
}

private template enumValuesImpl(string name, BaseType, long index, T...)
{
    static if (name.length)
    {
        enum string enumValuesImpl = "enum "~name~" : "~BaseType.stringof
            ~" { "~enumValuesImpl!("", BaseType, index, T)~"}\n";
    }
    else
    {
        static if (!T.length)
        {
            enum string enumValuesImpl = "";
        }
        else
        {
            static if (T.length == 1
                       || T.length > 1 && is(typeof(T[1]) : string))
            {
                enum string enumValuesImpl =  T[0]~" = "~ToString!(index)~", "
                    ~enumValuesImpl!("", BaseType, index + 1, T[1 .. $]);
            }
            else
            {
                enum string enumValuesImpl = T[0]~" = "~ToString!(T[1])~", "
                    ~enumValuesImpl!("", BaseType, T[1] + 1, T[2 .. $]);
            }
        }
    }
}

private template enumParserImpl(string name, bool first, T...)
{
    static if (first)
    {
        enum string enumParserImpl = "bool fromString(string s, ref "~name~" v) {\n"
            ~enumParserImpl!(name, false, T)
            ~"return false;\n}\n";
    }
    else
    {
        static if (T.length)
            enum string enumParserImpl =
                "if (s == `"~T[0]~"`) return (v = "~name~"."~T[0]~"), true;\n"
                ~enumParserImpl!(name, false, T[1 .. $]);
        else
            enum string enumParserImpl = "";
    }
}

private template enumPrinterImpl(string name, bool first, T...)
{
    static if (first)
    {
        enum string enumPrinterImpl = "string toString("~name~" v) {\n"
            ~enumPrinterImpl!(name, false, T)~"\n}\n";
    }
    else
    {
        static if (T.length)
            enum string enumPrinterImpl =
                "if (v == "~name~"."~T[0]~") return `"~T[0]~"`;\n"
                ~enumPrinterImpl!(name, false, T[1 .. $]);
        else
            enum string enumPrinterImpl = "return null;";
    }
}

private template ValueTuple(T...)
{
    alias T ValueTuple;
}

private template StringsOnly(T...)
{
    static if (T.length == 1)
        static if (is(typeof(T[0]) : string))
            alias ValueTuple!(T[0]) StringsOnly;
        else
            alias ValueTuple!() StringsOnly;
    else
        static if (is(typeof(T[0]) : string))
            alias ValueTuple!(T[0], StringsOnly!(T[1 .. $])) StringsOnly;
        else
            alias ValueTuple!(StringsOnly!(T[1 .. $])) StringsOnly;
}

/**
Defines truly named enumerated values with parsing and stringizing
primitives.

Example:

----
mixin(defineEnum!("Abc", "A", "B", 5, "C"));
----

is equivalent to the following code:

----
enum Abc { A, B = 5, C }
string toString(Abc v) { ... }
Abc fromString(string s) { ... }
----

The $(D_PARAM toString) function generates the unqualified names of the
enumerated values, i.e. "A", "B", and "C". The $(D_PARAM fromString)
function expects one of "A", "B", and "C", and throws an exception in
any other case.

A base type can be specified for the enumeration like this:

----
mixin(defineEnum!("Abc", ubyte, "A", "B", "C", 255));
----

In this case the generated $(D_PARAM enum) will have a $(D_PARAM
ubyte) representation.
*/

template defineEnum(string name, T...)
{
    static if (is(typeof(cast(T[0]) T[0].init)))
        enum string defineEnum =
            enumValuesImpl!(name, T[0], 0, T[1 .. $])
            ~ enumParserImpl!(name, true, StringsOnly!(T[1 .. $]))
            ~ enumPrinterImpl!(name, true, StringsOnly!(T[1 .. $]));
    else
        alias defineEnum!(name, int, T) defineEnum;
}

unittest
{
    mixin(defineEnum!("_24b455e148a38a847d65006bca25f7fe",
                      "A1", 1, "B1", "C1"));
    auto a = _24b455e148a38a847d65006bca25f7fe.A1;
    assert(toString(a) == "A1");
    _24b455e148a38a847d65006bca25f7fe b;
    assert(fromString("B1", b)
           && b == _24b455e148a38a847d65006bca25f7fe.B1);
}

/**
 */
template Rebindable(T : Object)
{
    static if (!is(T X == const(U), U) && !is(T X == invariant(U), U))
    {
        alias T Rebindable;
    }
    else
    {
        struct Rebindable
        {
            private union
            {
                T original;
                U stripped;
            }
            void opAssign(T another)
            {
                stripped = cast(U) another;
            }
            static Rebindable opCall(T initializer)
            {
                Rebindable result;
                result = initializer;
                return result;
            }
            alias original get;
        }
    }
}

unittest
{
    class C {};
    Rebindable!(C) obj0;
    static assert(is(typeof(obj0) == C));

    Rebindable!(const(C)) obj1;
    static assert(is(typeof(obj1.get) == const(C)), typeof(obj1.get).stringof);
    static assert(is(typeof(obj1.stripped) == C));
    obj1 = new C;
    assert(obj1.get !is null);
    obj1 = new const(C);
    assert(obj1.get !is null);

    Rebindable!(invariant(C)) obj2;
    static assert(is(typeof(obj2.get) == invariant(C)));
    static assert(is(typeof(obj2.stripped) == C));
    obj2 = new invariant(C);
    assert(obj1.get !is null);
}
