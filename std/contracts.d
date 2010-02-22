// Written in the D programming language.

/**
 * This module defines tools for effecting contracts and enforcing
 * predicates (a la $(D_PARAM assert)).
 *
 * Macros:
 *      WIKI = Phobos/StdContracts
 *
 * Synopsis:
 *
 * ----
 * string synopsis()
 * {
 *     FILE* f = enforce(fopen("some/file"));
 *     // f is not null from here on
 *     FILE* g = enforceEx!(WriteException)(fopen("some/other/file", "w"));
 *     // g is not null from here on
 *     Exception e = collectException(write(g, readln(f)));
 *     if (e)
 *     {
 *         ... an exception occurred...
 *     }
 *     char[] line;
 *     enforce(readln(f, line));
 *     return assumeUnique(line);
 * }
 * ----
 *
 * Copyright: Copyright Andrei Alexandrescu 2008 - 2009.
 * License:   <a href="http://www.boost.org/LICENSE_1_0.txt">Boost License 1.0</a>.
 * Authors:   $(WEB erdani.org, Andrei Alexandrescu)
 * Credits:   Brad Roberts came up with the name $(D_PARAM contracts).
 *
 *          Copyright Andrei Alexandrescu 2008 - 2009.
 * Distributed under the Boost Software License, Version 1.0.
 *    (See accompanying file LICENSE_1_0.txt or copy at
 *          http://www.boost.org/LICENSE_1_0.txt)
 */
module std.contracts;

import std.array, std.c.string, std.conv, std.range, std.string, std.traits;
import core.stdc.errno;
version(unittest)
{
    import std.stdio;
}

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

/**
 * If $(D_PARAM value) is nonzero, returns it. Otherwise, throws
 * $(D_PARAM new Exception(msg)).
 * Example:
 * ----
 * auto f = enforce(fopen("data.txt"));
 * auto line = readln(f);
 * enforce(line.length); // expect a non-empty line
 * ----
 */

T enforce(T, string file = __FILE__, int line = __LINE__)
    (T value, lazy const(char)[] msg = null)
{
    if (!value) bailOut(file, line, msg);
    return value;
}

T enforce(T, string file = __FILE__, int line = __LINE__)
(T value, scope void delegate() dg)
{
    if (!value) dg();
    return value;
}

private void bailOut(string file, int line, in char[] msg)
{
    throw new Exception(text(file, '(', line, "): ",
                    msg ? msg : "Enforcement failed"));
}

/**
 * If $(D_PARAM value) is nonzero, returns it. Otherwise, throws
 * $(D_PARAM ex).
 * Example:
 * ----
 * auto f = enforce(fopen("data.txt"));
 * auto line = readln(f);
 * enforce(line.length, new IOException); // expect a non-empty line
 * ----
 */

T enforce(T)(T value, lazy Exception ex)
{
    if (!value) throw ex();
    return value;
}

unittest
{
    enforce(true, new Exception("this should not be thrown"));
    try
    {
        enforce(false, new Exception("this should be thrown"));
        assert(false);
    }
    catch (Exception e)
    {
    }
}

/**
If $(D value) is nonzero, returns it. Otherwise, throws $(D new
ErrnoException(msg)). The $(D ErrnoException) class assumes that the
last operation has set $(D errno) to an error code.
 *
 * Example:
 *
 * ----
 * auto f = errnoEnforce(fopen("data.txt"));
 * auto line = readln(f);
 * enforce(line.length); // expect a non-empty line
 * ----
 */

T errnoEnforce(T, string file = __FILE__, int line = __LINE__)
    (T value, lazy string msg = null)
{
    if (!value) throw new ErrnoException(msg, file, line);
    return value;
}

/**
 * If $(D_PARAM value) is nonzero, returns it. Otherwise, throws
 * $(D_PARAM new E(msg)).
 * Example:
 * ----
 * auto f = enforceEx!(FileMissingException)(fopen("data.txt"));
 * auto line = readln(f);
 * enforceEx!(DataCorruptionException)(line.length);
 * ----
 */

template enforceEx(E)
{
    T enforceEx(T)(T value, lazy string msg = "")
    {
        if (!value) throw new E(msg);
        return value;
    }
}

unittest
{
    enforce(true);
    enforce(true, "blah");
    typedef Exception MyException;
    try
    {
        enforceEx!(MyException)(false);
        assert(false);
    }
    catch (MyException e)
    {
    }
}

/**
 * Evaluates $(D_PARAM expression). If evaluation throws an exception,
 * return that exception. Otherwise, deposit the resulting value in
 * $(D_PARAM target) and return $(D_PARAM null).
 * Example:
 * ----
 * int[] a = new int[3];
 * int b;
 * assert(collectException(a[4], b));
 * ----
 */

Exception collectException(T)(lazy T expression, ref T target)
{
    try
    {
        target = expression();
    }
    catch (Exception e)
    {
        return e;
    }
    return null;
}

unittest
{
    int[] a = new int[3];
    int b;
    int foo() { throw new Exception("blah"); }
    assert(collectException(foo(), b));
}

/** Evaluates $(D_PARAM expression). If evaluation throws an
 * exception, return that exception. Otherwise, return $(D_PARAM
 * null). $(D_PARAM T) can be $(D_PARAM void).
 */

Exception collectException(T)(lazy T expression)
{
    try
    {
        expression();
    }
    catch (Exception e)
    {
        return e;
    }
    return null;
}

unittest
{
    int foo() { throw new Exception("blah"); }
    assert(collectException(foo()));
}

/**
 * Casts a mutable array to an invariant array in an idiomatic
 * manner. Technically, $(D_PARAM assumeUnique) just inserts a cast,
 * but its name documents assumptions on the part of the
 * caller. $(D_PARAM assumeUnique(arr)) should only be called when
 * there are no more active mutable aliases to elements of $(D_PARAM
 * arr). To strenghten this assumption, $(D_PARAM assumeUnique(arr))
 * also clears $(D_PARAM arr) before returning. Essentially $(D_PARAM
 * assumeUnique(arr)) indicates commitment from the caller that there
 * is no more mutable access to any of $(D_PARAM arr)'s elements
 * (transitively), and that all future accesses will be done through
 * the invariant array returned by $(D_PARAM assumeUnique).
 *
 * Typically, $(D_PARAM assumeUnique) is used to return arrays from
 * functions that have allocated and built them.
 *
 * Example:
 *
 * ----
 * string letters()
 * {
 *   char[] result = new char['z' - 'a' + 1];
 *   foreach (i, ref e; result)
 *   {
 *     e = 'a' + i;
 *   }
 *   return assumeUnique(result);
 * }
 * ----
 *
 * The use in the example above is correct because $(D_PARAM result)
 * was private to $(D_PARAM letters) and is unaccessible in writing
 * after the function returns. The following example shows an
 * incorrect use of $(D_PARAM assumeUnique).
 *
 * Bad:
 *
 * ----
 * private char[] buffer;
 * string letters(char first, char last)
 * {
 *   if (first >= last) return null; // fine
 *   auto sneaky = buffer;
 *   sneaky.length = last - first + 1;
 *   foreach (i, ref e; sneaky)
 *   {
 *     e = 'a' + i;
 *   }
 *   return assumeUnique(sneaky); // BAD
 * }
 * ----
 *
 * The example above wreaks havoc on client code because it is
 * modifying arrays that callers considered immutable. To obtain an
 * invariant array from the writable array $(D_PARAM buffer), replace
 * the last line with:
 * ----
 * return to!(string)(sneaky); // not that sneaky anymore
 * ----
 *
 * The call will duplicate the array appropriately.
 *
 * Checking for uniqueness during compilation is possible in certain
 * cases (see the $(D_PARAM unique) and $(D_PARAM lent) keywords in
 * the $(WEB archjava.fluid.cs.cmu.edu/papers/oopsla02.pdf, ArchJava)
 * language), but complicates the language considerably. The downside
 * of $(D_PARAM assumeUnique)'s convention-based usage is that at this
 * time there is no formal checking of the correctness of the
 * assumption; on the upside, the idiomatic use of $(D_PARAM
 * assumeUnique) is simple and rare enough to be tolerable.
 *
 */

invariant(T)[] assumeUnique(T)(ref T[] array)
{
    auto result = cast(invariant(T)[]) array;
    array = null;
    return result;
}

unittest
{
    int[] arr = new int[1];
    auto arr1 = assumeUnique(arr);
    assert(is(typeof(arr1) == invariant(int)[]) && arr == null);
}

invariant(T[U]) assumeUnique(T, U)(ref T[U] array)
{
    auto result = cast(invariant(T[U])) array;
    array = null;
    return result;
}

// @@@BUG@@@
version(none) unittest
{
    int[string] arr = ["a":1];
    auto arr1 = assumeUnique(arr);
    assert(is(typeof(arr1) == invariant(int[string])) && arr == null);
}

/**
Passes the type system the information that $(D range) is already
sorted by predicate $(D pred). No checking is performed; debug builds
may insert checks randomly. To insert a check, see $(XREF algorithm,
isSorted).
 */
struct AssumeSorted(Range, alias pred = "a < b")
{
    /// Alias for $(D Range).
    alias Range AssumeSorted;
    /// The passed-in range.
    Range assumeSorted;
    /// The sorting predicate.
    alias pred assumeSortedBy;
}

/// Ditto
AssumeSorted!(Range, pred) assumeSorted(alias pred = "a < b", Range)
(Range r)
{
    AssumeSorted!(Range, pred) result;
    result.assumeSorted = r;
    return result;
}

unittest
{
    static assert(is(AssumeSorted!(int[]).AssumeSorted == int[]));
    int[] a = [ 1, 2 ];
    auto b = assumeSorted(a);
    assert(b.assumeSorted == a);
}

/**
Returns $(D true) if $(D source)'s representation embeds a pointer
that points to $(D target)'s representation or somewhere inside
it. Note that evaluating $(D pointsTo(x, x)) checks whether $(D x) has
internal pointers.
*/
bool pointsTo(S, T)(ref S source, ref T target)
{
    static if (is(S P : U*, U))
    {
        const void * m = source, b = &target, e = b + target.sizeof;
        return b <= m && m < e;
    }
    else static if (is(S == struct))
    {
        foreach (i, subobj; source.tupleof)
        {
            static if (!isStaticArray!(typeof(subobj)))
                if (pointsTo(subobj, target)) return true;
        }
        return false;
    }
    else static if (isDynamicArray!(S))
    {
        const void* p1 = source.ptr, p2 = p1 + source.length,
            b = &target, e = b + target.sizeof;
        return overlap(p1[0 .. p2 - p1], b[0 .. e - b]).length != 0;
    }
    else
    {
        return false;
    }
}

unittest
{
    struct S1 { int a; S1 * b; }
    S1 a1;
    S1 * p = &a1;
    assert(pointsTo(p, a1));

    S1 a2;
    a2.b = &a1;
    assert(pointsTo(a2, a1));

    struct S3 { int[10] a; }
    S3 a3;
    auto a4 = a3.a[2 .. 3];
    assert(pointsTo(a4, a3));

    auto a5 = new double[4];
    auto a6 = a5[1 .. 2];
    assert(!pointsTo(a5, a6));

    auto a7 = new double[3];
    auto a8 = new double[][1];
    a8[0] = a7;
    assert(!pointsTo(a8[0], a8[0]));
}

/*********************
 * Thrown if errors that set $(D errno) happen.
 */
class ErrnoException : Exception
{
    uint errno;                 // operating system error code
    this(string msg, string file = null, uint line = 0)
    {
        errno = getErrno;
        version (linux)
        {
            char[1024] buf = void;
            auto s = std.c.string.strerror_r(errno, buf.ptr, buf.length);
        }
        else
        {
            auto s = std.c.string.strerror(errno);
        }
        super((file ? file~'('~to!string(line)~"): " : "")
                ~msg~" ("~to!string(s)~")");
    }
}

// structuralCast
// class-to-class structural cast
Target structuralCast(Target, Source)(Source obj)
    if (is(Source == class) || is(Target == class))
{
    // For the structural cast to work, the source and the target must
    // have the same base class, and the target must add no data or
    // methods
    static assert(0, "Not implemented");
}

// interface-to-interface structural cast
Target structuralCast(Target, Source)(Source obj)
    if (is(Source == interface) || is(Target == interface))
{
}

unittest
{
    interface I1 { void f1(); }
    interface I2 { void f2(); }
    interface I12 : I1, I2 { }
    //pragma(msg, TransitiveBaseTypeTuple!I12.stringof);
    //static assert(is(TransitiveBaseTypeTuple!I12 == TypeTuple!(I2, I1)));
}

// Target structuralCast(Target, Source)(Source obj)
//     if (is(Source == interface) || is(Target == interface))
// {
//     static assert(is(BaseTypeTuple!(Source)[0] ==
//                     BaseTypeTuple!(Target)[0]));
//     alias BaseTypeTuple!(Source)[1 .. $] SBases;
//     alias BaseTypeTuple!(Target)[1 .. $] TBases;
//         else
//         {
//             // interface-to-class
//             static assert(0);
//         }
//     }
//     else
//     {
//         static if (is(Source == class))
//         {
//             // class-to-interface structural cast
//             alias BaseTypeTuple!(Source)[1 .. $] SBases;
//             alias BaseTypeTuple!(Target) TBases;
//         }
//         else
//         {
//             // interface-to-interface structural cast
//             alias BaseTypeTuple!(Source) SBases;
//             alias BaseTypeTuple!(Target) TBases;
//         }
//     }
//     static assert(SBases.length >= TBases.length,
//             "Cannot structurally cast to a target with"
//             " more interfaces implemented");
//     static assert(
//         is(typeof(Target.tupleof) == typeof(Source.tupleof)),
//             "Cannot structurally cast to a target with more fields");
//     // Target bases must be a prefix of the source bases
//     foreach (i, B; TBases)
//     {
//         static assert(is(SBases[i] == B)
//                 || is(SBases[i] == interface) && is(SBases[i] : B),
//                 SBases[i].stringof ~ " does not inherit "
//                 ~ B.stringof);
//     }
//     union Result
//     {
//         Source src;
//         Target tgt;
//     }
//     Result result = { obj };
//     return result.tgt;
// }

template structurallyCompatible(S, T) if (!isArray!S || !isArray!T)
{
    enum structurallyCompatible =
        FieldTypeTuple!S.length >= FieldTypeTuple!T.length
        && is(FieldTypeTuple!S[0 .. FieldTypeTuple!T.length]
                == FieldTypeTuple!T);
}

template structurallyCompatible(S, T) if (isArray!S && isArray!T)
{
    enum structurallyCompatible =
        .structurallyCompatible!(ElementType!S, ElementType!T) &&
        .structurallyCompatible!(ElementType!T, ElementType!S);
}

unittest
{
    // struct X { uint a; }
    // static assert(structurallyCompatible!(uint[], X[]));
    // struct Y { uint a, b; }
    // static assert(!structurallyCompatible!(uint[], Y[]));
    // static assert(!structurallyCompatible!(Y[], uint[]));
    // static assert(!structurallyCompatible!(Y[], X[]));
}

/*
Structural cast. Allows casting among class types that logically have
a common base, but that base is not made explicit.

Example:
----
interface Document { ... }
interface Storable { ... }
interface StorableDocument : Storable, Document { ... }
class Doc : Storable, Document { ... }
void process(StorableDocument d);
...

auto c = new Doc;
process(c); // does not work
process(structuralCast!StorableDocument(c)); // works
 */

// template structuralCast(Target)
// {
//     Target structuralCast(Source)(Source obj)
//     {
//         static if (is(Source : Object) || is(Source == interface))
//         {
//             return .structuralCastImpl!(Target)(obj);
//         }
//         else
//         {
//             static if (structurallyCompatible!(Source, Target))
//                 return *(cast(Target*) &obj);
//             else
//                 static assert(false);
//         }
//     }
// }

unittest
{
    // interface I1 {}
    // interface I2 {}
    // class Base : I1 { int x; }
    // class A : I1 {}
    // class B : I1, I2 {}

    // auto b = new B;
    // auto a = structuralCast!(A)(b);
    // assert(a);

    // struct X { int a; }
    // int[] arr = [ 1 ];
    // auto x = structuralCast!(X[])(arr);
    // assert(x[0].a == 1);
}

unittest
{
    // interface Document { int fun(); }
    // interface Storable { int gun(); }
    // interface StorableDocument : Storable, Document {  }
    // class Doc : Storable, Document {
    //     int fun() { return 42; }
    //     int gun() { return 43; }
    // }
    // void process(StorableDocument d) {
    //     assert(d.fun + d.gun == 85, text(d.fun + d.gun));
    // }

    // auto c = new Doc;
    // Document d = c;
    // //process(c); // does not work
    // union A
    // {
    //     Storable s;
    //     StorableDocument sd;
    // }
    // A a = { c };
    //process(a.sd); // works
    //process(structuralCast!StorableDocument(d)); // works
}
