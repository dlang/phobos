// Written in the D programming language.

/**
 * Templates with which to manipulate type tuples (also known as type lists).
 *
 * Some operations on type tuples are built in to the language,
 * such as TL[$(I n)] which gets the $(I n)th type from the
 * type tuple. TL[$(I lwr) .. $(I upr)] returns a new type
 * list that is a slice of the old one.
 *
 * References:
 *  Based on ideas in Table 3.1 from
 *  $(LINK2 http://amazon.com/exec/obidos/ASIN/0201704315/ref=ase_classicempire/102-2957199-2585768,
 *      Modern C++ Design),
 *   Andrei Alexandrescu (Addison-Wesley Professional, 2001)
 * Macros:
 *  WIKI = Phobos/StdTypeTuple
 *
 * Copyright: Copyright Digital Mars 2005 - 2009.
 * License:   <a href="http://www.boost.org/LICENSE_1_0.txt">Boost License 1.0</a>.
 * Authors:   $(WEB digitalmars.com, Walter Bright)
 * Source:    $(PHOBOSSRC std/_typetuple.d)
 */
/*          Copyright Digital Mars 2005 - 2009.
 * Distributed under the Boost Software License, Version 1.0.
 *    (See accompanying file LICENSE_1_0.txt or copy at
 *          http://www.boost.org/LICENSE_1_0.txt)
 */
module std.typetuple;

import std.traits;

/**
 * Creates a typetuple out of a sequence of zero or more types.
 * Example:
 * ---
 * import std.typetuple;
 * alias TypeTuple!(int, double) TL;
 *
 * int foo(TL td)  // same as int foo(int, double);
 * {
 *    return td[0] + cast(int)td[1];
 * }
 * ---
 *
 * Example:
 * ---
 * TypeTuple!(TL, char)
 * // is equivalent to:
 * TypeTuple!(int, double, char)
 * ---
 */
template TypeTuple(TList...)
{
    alias TList TypeTuple;
}

/**
 * Returns the index of the first occurrence of type T in the
 * sequence of zero or more types TList.
 * If not found, -1 is returned.
 * Example:
 * ---
 * import std.typetuple;
 * import std.stdio;
 *
 * void foo()
 * {
 *    writefln("The index of long is %s",
 *          staticIndexOf!(long, TypeTuple!(int, long, double)));
 *    // prints: The index of long is 1
 * }
 * ---
 */
template staticIndexOf(T, TList...)
{
    enum staticIndexOf = genericIndexOf!(T, TList).index;
}

/// Ditto
template staticIndexOf(alias T, TList...)
{
    enum staticIndexOf = genericIndexOf!(T, TList).index;
}

// [internal]
private template genericIndexOf(args...)
    if (args.length >= 1)
{
    alias Alias!(args[0]) e;
    alias   args[1 .. $]  tuple;

    static if (tuple.length)
    {
        alias Alias!(tuple[0]) head;
        alias   tuple[1 .. $]  tail;

        static if (isSame!(e, head))
        {
            enum index = 0;
        }
        else
        {
            enum next  = genericIndexOf!(e, tail).index;
            enum index = (next == -1) ? -1 : 1 + next;
        }
    }
    else
    {
        enum index = -1;
    }
}

unittest
{
    static assert(staticIndexOf!( byte, byte, short, int, long) ==  0);
    static assert(staticIndexOf!(short, byte, short, int, long) ==  1);
    static assert(staticIndexOf!(  int, byte, short, int, long) ==  2);
    static assert(staticIndexOf!( long, byte, short, int, long) ==  3);
    static assert(staticIndexOf!( char, byte, short, int, long) == -1);
    static assert(staticIndexOf!(   -1, byte, short, int, long) == -1);
    static assert(staticIndexOf!(void) == -1);

    static assert(staticIndexOf!("abc", "abc", "def", "ghi", "jkl") ==  0);
    static assert(staticIndexOf!("def", "abc", "def", "ghi", "jkl") ==  1);
    static assert(staticIndexOf!("ghi", "abc", "def", "ghi", "jkl") ==  2);
    static assert(staticIndexOf!("jkl", "abc", "def", "ghi", "jkl") ==  3);
    static assert(staticIndexOf!("mno", "abc", "def", "ghi", "jkl") == -1);
    static assert(staticIndexOf!( void, "abc", "def", "ghi", "jkl") == -1);
    static assert(staticIndexOf!(42) == -1);

    static assert(staticIndexOf!(void, 0, "void", void) == 2);
    static assert(staticIndexOf!("void", 0, void, "void") == 2);
}

/// Kept for backwards compatibility
alias staticIndexOf IndexOf;

/**
 * Returns a typetuple created from TList with the first occurrence,
 * if any, of T removed.
 * Example:
 * ---
 * Erase!(long, int, long, double, char)
 * // is the same as:
 * TypeTuple!(int, double, char)
 * ---
 */
// template Erase(T, TList...)
// {
//     static if (TList.length == 0)
//  alias TList Erase;
//     else static if (is(T == TList[0]))
//  alias TList[1 .. $] Erase;
//     else
//  alias TypeTuple!(TList[0], Erase!(T, TList[1 .. $])) Erase;
// }
 template Erase(T, TList...)
 {
    alias GenericErase!(T, TList).result Erase;
}

/// Ditto
template Erase(alias T, TList...)
{
    alias GenericErase!(T, TList).result Erase;
}

// [internal]
private template GenericErase(args...)
    if (args.length >= 1)
{
    alias Alias!(args[0]) e;
    alias   args[1 .. $]  tuple;

    static if (tuple.length)
    {
        alias Alias!(tuple[0]) head;
        alias   tuple[1 .. $]  tail;

        static if (isSame!(e, head))
            alias tail result;
        else
            alias TypeTuple!(head, GenericErase!(e, tail).result) result;
    }
     else
    {
        alias TypeTuple!() result;
    }
 }

unittest
{
    static assert(Pack!(Erase!(int,
                short, int, int, 4)).
        equals!(short,      int, 4));

    static assert(Pack!(Erase!(1,
                real, 3, 1, 4, 1, 5, 9)).
        equals!(real, 3,    4, 1, 5, 9));
}


/**
 * Returns a typetuple created from TList with the all occurrences,
 * if any, of T removed.
 * Example:
 * ---
 * alias TypeTuple!(int, long, long, int) TL;
 *
 * EraseAll!(long, TL)
 * // is the same as:
 * TypeTuple!(int, int)
 * ---
 */
template EraseAll(T, TList...)
{
    alias GenericEraseAll!(T, TList).result EraseAll;
}

/// Ditto
template EraseAll(alias T, TList...)
{
    alias GenericEraseAll!(T, TList).result EraseAll;
}

// [internal]
private template GenericEraseAll(args...)
    if (args.length >= 1)
{
    alias Alias!(args[0]) e;
    alias   args[1 .. $]  tuple;

    static if (tuple.length)
    {
        alias Alias!(tuple[0]) head;
        alias   tuple[1 .. $]  tail;
        alias GenericEraseAll!(e, tail).result next;

        static if (isSame!(e, head))
            alias next result;
        else
            alias TypeTuple!(head, next) result;
    }
     else
    {
        alias TypeTuple!() result;
    }
 }

unittest
{
    static assert(Pack!(EraseAll!(int,
                short, int, int, 4)).
        equals!(short,           4));

    static assert(Pack!(EraseAll!(1,
                real, 3, 1, 4, 1, 5, 9)).
        equals!(real, 3,    4,    5, 9));
}


/**
 * Returns a typetuple created from TList with the all duplicate
 * types removed.
 * Example:
 * ---
 * alias TypeTuple!(int, long, long, int, float) TL;
 *
 * NoDuplicates!(TL)
 * // is the same as:
 * TypeTuple!(int, long, float)
 * ---
 */
template NoDuplicates(TList...)
{
    static if (TList.length == 0)
    alias TList NoDuplicates;
    else
    alias TypeTuple!(TList[0], NoDuplicates!(EraseAll!(TList[0], TList[1 .. $]))) NoDuplicates;
}

unittest
{
    static assert(
        Pack!(
            NoDuplicates!(1, int, 1, NoDuplicates, int, NoDuplicates, real))
        .equals!(1, int,    NoDuplicates,                    real));
}


/**
 * Returns a typetuple created from TList with the first occurrence
 * of type T, if found, replaced with type U.
 * Example:
 * ---
 * alias TypeTuple!(int, long, long, int, float) TL;
 *
 * Replace!(long, char, TL)
 * // is the same as:
 * TypeTuple!(int, char, long, int, float)
 * ---
 */
template Replace(T, U, TList...)
{
    alias GenericReplace!(T, U, TList).result Replace;
}

/// Ditto
template Replace(alias T, U, TList...)
{
    alias GenericReplace!(T, U, TList).result Replace;
}

/// Ditto
template Replace(T, alias U, TList...)
{
    alias GenericReplace!(T, U, TList).result Replace;
}

/// Ditto
template Replace(alias T, alias U, TList...)
{
    alias GenericReplace!(T, U, TList).result Replace;
}

// [internal]
private template GenericReplace(args...)
    if (args.length >= 2)
{
    alias Alias!(args[0]) from;
    alias Alias!(args[1]) to;
    alias   args[2 .. $]  tuple;

    static if (tuple.length)
    {
        alias Alias!(tuple[0]) head;
        alias    tuple[1 .. $] tail;

        static if (isSame!(from, head))
            alias TypeTuple!(to, tail) result;
        else
            alias TypeTuple!(head,
                GenericReplace!(from, to, tail).result) result;
    }
     else
    {
        alias TypeTuple!() result;
    }
 }

unittest
{
    static assert(Pack!(Replace!(byte, ubyte,
                short,  byte, byte, byte)).
        equals!(short, ubyte, byte, byte));

    static assert(Pack!(Replace!(1111, byte,
                2222, 1111, 1111, 1111)).
        equals!(2222, byte, 1111, 1111));

    static assert(Pack!(Replace!(byte, 1111,
                short, byte, byte, byte)).
        equals!(short, 1111, byte, byte));

    static assert(Pack!(Replace!(1111, "11",
                2222, 1111, 1111, 1111)).
        equals!(2222, "11", 1111, 1111));
}

/**
 * Returns a typetuple created from TList with all occurrences
 * of type T, if found, replaced with type U.
 * Example:
 * ---
 * alias TypeTuple!(int, long, long, int, float) TL;
 *
 * ReplaceAll!(long, char, TL)
 * // is the same as:
 * TypeTuple!(int, char, char, int, float)
 * ---
 */
template ReplaceAll(T, U, TList...)
{
    alias GenericReplaceAll!(T, U, TList).result ReplaceAll;
}

/// Ditto
template ReplaceAll(alias T, U, TList...)
{
    alias GenericReplaceAll!(T, U, TList).result ReplaceAll;
}

/// Ditto
template ReplaceAll(T, alias U, TList...)
{
    alias GenericReplaceAll!(T, U, TList).result ReplaceAll;
}

/// Ditto
template ReplaceAll(alias T, alias U, TList...)
{
    alias GenericReplaceAll!(T, U, TList).result ReplaceAll;
}

// [internal]
private template GenericReplaceAll(args...)
    if (args.length >= 2)
{
    alias Alias!(args[0]) from;
    alias Alias!(args[1]) to;
    alias   args[2 .. $]  tuple;

    static if (tuple.length)
    {
        alias Alias!(tuple[0]) head;
        alias    tuple[1 .. $] tail;
        alias GenericReplaceAll!(from, to, tail).result next;

        static if (isSame!(from, head))
            alias TypeTuple!(to, next) result;
        else
            alias TypeTuple!(head, next) result;
    }
    else
    {
        alias TypeTuple!() result;
    }
}

unittest
{
    static assert(Pack!(ReplaceAll!(byte, ubyte,
                 byte, short,  byte,  byte)).
        equals!(ubyte, short, ubyte, ubyte));

    static assert(Pack!(ReplaceAll!(1111, byte,
                1111, 2222, 1111, 1111)).
        equals!(byte, 2222, byte, byte));

    static assert(Pack!(ReplaceAll!(byte, 1111,
                byte, short, byte, byte)).
        equals!(1111, short, 1111, 1111));

    static assert(Pack!(ReplaceAll!(1111, "11",
                1111, 2222, 1111, 1111)).
        equals!("11", 2222, "11", "11"));
}

/**
 * Returns a typetuple created from TList with the order reversed.
 * Example:
 * ---
 * alias TypeTuple!(int, long, long, int, float) TL;
 *
 * Reverse!(TL)
 * // is the same as:
 * TypeTuple!(float, int, long, long, int)
 * ---
 */
template Reverse(TList...)
{
    static if (TList.length == 0)
    alias TList Reverse;
    else
    alias TypeTuple!(Reverse!(TList[1 .. $]), TList[0]) Reverse;
}

/**
 * Returns the type from TList that is the most derived from type T.
 * If none are found, T is returned.
 * Example:
 * ---
 * class A { }
 * class B : A { }
 * class C : B { }
 * alias TypeTuple!(A, C, B) TL;
 *
 * MostDerived!(Object, TL) x;  // x is declared as type C
 * ---
 */
template MostDerived(T, TList...)
{
    static if (TList.length == 0)
    alias T MostDerived;
    else static if (is(TList[0] : T))
    alias MostDerived!(TList[0], TList[1 .. $]) MostDerived;
    else
    alias MostDerived!(T, TList[1 .. $]) MostDerived;
}

/**
 * Returns the typetuple TList with the types sorted so that the most
 * derived types come first.
 * Example:
 * ---
 * class A { }
 * class B : A { }
 * class C : B { }
 * alias TypeTuple!(A, C, B) TL;
 *
 * DerivedToFront!(TL)
 * // is the same as:
 * TypeTuple!(C, B, A)
 * ---
 */
template DerivedToFront(TList...)
{
    static if (TList.length == 0)
    alias TList DerivedToFront;
    else
    alias TypeTuple!(MostDerived!(TList[0], TList[1 .. $]),
                    DerivedToFront!(ReplaceAll!(MostDerived!(TList[0], TList[1 .. $]),
                            TList[0],
                            TList[1 .. $]))) DerivedToFront;
}


/**
Evaluates to $(D TypeTuple!(F[T[0]], F[T[1]], ..., F[T[$ - 1]])).

Example:
----
alias staticMap!(Unqual, int, const int, immutable int) T;
static assert(is(T == TypeTuple!(int, int, int)));
----
 */
template staticMap(alias F, T...)
{
    static if (T.length == 0)
    {
        alias TypeTuple!() staticMap;
    }
    else
    {
        alias TypeTuple!(F!(T[0]),
                         staticMap!(F, T[1 .. $])) staticMap;
    }
}

unittest
{
    // empty
    alias staticMap!(Unqual) Empty;
    static assert(Empty.length == 0);

    // single
    alias staticMap!(Unqual, const int) Single;
    static assert(is(Single == TypeTuple!int));

    alias staticMap!(Unqual, int, const int, immutable int) T;
    static assert(is(T == TypeTuple!(int, int, int)));
}

/**
Evaluates to $(D F[T[0]] && F[T[1]] && ... && F[T[$ - 1]]).

Example:
----
static assert(!allSatisfy!(isIntegral, int, double));
static assert(allSatisfy!(isIntegral, int, long));
----
 */
template allSatisfy(alias F, T...)
{
    static if (T.length == 0)
    {
        enum bool allSatisfy = true;
    }
    else static if (T.length == 1)
    {
        alias F!(T[0]) allSatisfy;
    }
    else
    {
        enum bool allSatisfy = F!(T[0]) && allSatisfy!(F, T[1 .. $]);
    }
}

unittest
{
    static assert(!allSatisfy!(isIntegral, int, double));
    static assert(allSatisfy!(isIntegral, int, long));
}

/**
Evaluates to $(D F[T[0]] || F[T[1]] || ... || F[T[$ - 1]]).

Example:
----
static assert(!anySatisfy!(isIntegral, string, double));
static assert(anySatisfy!(isIntegral, int, double));
----
 */
template anySatisfy(alias F, T...)
{
    static if(T.length == 0)
    {
        enum bool anySatisfy = false;
    }
    else static if (T.length == 1)
    {
        alias F!(T[0]) anySatisfy;
    }
    else
    {
        enum bool anySatisfy = F!(T[0]) || anySatisfy!(F, T[1 .. $]);
    }
}

unittest
{
    static assert(!anySatisfy!(isIntegral, string, double));
    static assert(anySatisfy!(isIntegral, int, double));
}

// : : : : : : : : : : : : : : : : : : : : : : : : : : : : : : : : : //
private:

/*
 * [internal] With the builtin alias declaration, you cannot declare
 * aliases of, for example, literal values. You can alias anything
 * including literal values via this template.
 */
private
{
    // symbols and literal values
    template Alias(alias a)
    {
        static if (__traits(compiles, { alias a x; }))
            alias a Alias;
        else static if (__traits(compiles, { enum x = a; }))
            enum Alias = a;
        else
            static assert(0, "Cannot alias " ~ a.stringof);
    }
    // types and tuples
    template Alias(a...)
    {
        alias a Alias;
    }
}

unittest
{
    enum abc = 1;
    static assert(__traits(compiles, { alias Alias!(123) a; }));
    static assert(__traits(compiles, { alias Alias!(abc) a; }));
    static assert(__traits(compiles, { alias Alias!(int) a; }));
    static assert(__traits(compiles, { alias Alias!(1,abc,int) a; }));
}


/*
 * [internal] Returns true if a and b are the same thing, or false if
 * not. Both a and b can be types, literals, or symbols.
 *
 * How:                     When:
 *      is(a == b)        - both are types
 *        a == b          - both are literals (true literals, enums)
 * __traits(isSame, a, b) - other cases (variables, functions,
 *                          templates, etc.)
 */
private template isSame(ab...)
    if (ab.length == 2)
{
    static if (__traits(compiles, expectType!(ab[0]),
                                  expectType!(ab[1])))
    {
        enum isSame = is(ab[0] == ab[1]);
    }
    else static if (!__traits(compiles, expectType!(ab[0])) &&
                    !__traits(compiles, expectType!(ab[1])) &&
                     __traits(compiles, ab[0] == ab[1]))
    {
        static if (!__traits(compiles, &ab[0]) ||
                   !__traits(compiles, &ab[1]))
            enum isSame = (ab[0] == ab[1]);
        else
            enum isSame = __traits(isSame, ab[0], ab[1]);
    }
    else
    {
        enum isSame = __traits(isSame, ab[0], ab[1]);
    }
}
private template expectType(T) {}

unittest
{
    static assert( isSame!(int, int));
    static assert(!isSame!(int, short));

    enum a = 1, b = 1, c = 2;
    static assert( isSame!(1, 1));
    static assert( isSame!(a, 1));
    static assert( isSame!(a, b));
    static assert(!isSame!(b, c));
    static assert(!isSame!(1, "1"));
    static assert(!isSame!(a, "a"));
    static assert( isSame!(isSame, isSame));
    static assert(!isSame!(isSame, a));

    static assert(!isSame!(byte, a));
    static assert(!isSame!(short, isSame));
    static assert(!isSame!(a, int));
    static assert(!isSame!(long, isSame));

    static immutable X = 1, Y = 1, Z = 2;
    static assert( isSame!(X, X));
    static assert(!isSame!(X, Y));
    static assert(!isSame!(Y, Z));

    int  foo();
    int  bar();
    real baz(int);
    static assert( isSame!(foo, foo));
    static assert(!isSame!(foo, bar));
    static assert(!isSame!(bar, baz));
    static assert( isSame!(baz, baz));

    int  x, y;
    real z;
    static assert( isSame!(x, x));
    static assert(!isSame!(x, y));
    static assert(!isSame!(y, z));
    static assert( isSame!(z, z));
}

/*
 * [internal] Confines a tuple within a template.
 */
private template Pack(T...)
{
    alias T tuple;

    // For convenience
    template equals(U...)
    {
        static if (T.length == U.length)
        {
            static if (T.length == 0)
                enum equals = true;
            else
                enum equals = isSame!(T[0], U[0]) &&
                    Pack!(T[1 .. $]).equals!(U[1 .. $]);
        }
        else
        {
            enum equals = false;
        }
    }
}

unittest
{
    static assert( Pack!(1, int, "abc").equals!(1, int, "abc"));
    static assert(!Pack!(1, int, "abc").equals!(1, int, "cba"));
}

