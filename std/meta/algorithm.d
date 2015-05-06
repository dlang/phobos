/**
 * Templates that implement compile-time algorithms
 *
 * Utilities in this module are similar to functions from
 * $(LINK2 std_algorithm.html, std.algorithm) but work with
 * compile-time entities : types, symbols and constants.
 *
 * According to $(LINK2 dstyle.html, Phobos naming convention) those template
 * names start with lower case letter if result is always a value and start with
 * upper case letter if result can also be type or `MetaList`
 *
 * Copyright: Copyright Digital Mars 2005 - 2009.
 * License: $(WEB www.boost.org/LICENSE_1_0.txt, Boost License 1.0).
 * Authors: Mihails Strasuns, Nick Treleaven
 * Source: $(PHOBOSSRC std/meta/_predicates.d)
 */

module std.meta.algorithm;

/**
Evaluates to $(D MetaList!(F!(T[0]), F!(T[1]), ..., F!(T[$ - 1]))).
 */
template Map(alias F, T...)
{
    import std.meta.list;

    static if (T.length == 0)
    {
        alias Map = MetaList!();
    }
    else static if (T.length == 1)
    {
        alias Map = MetaList!(F!(T[0]));
    }
    else
    {
        alias Map =
            MetaList!(
                Map!(F, T[ 0  .. $/2]),
                Map!(F, T[$/2 ..  $ ]));
    }
}

///
unittest
{
    import std.traits : Unqual;
    import std.meta.list;

    alias TL = Map!(Unqual, int, const int, immutable int);
    static assert(is(TL == MetaList!(int, int, int)));
}

unittest
{
    import std.traits : Unqual;
    import std.meta.list;

    // empty
    alias Empty = Map!(Unqual);
    static assert(Empty.length == 0);

    // single
    alias Single = Map!(Unqual, const int);
    static assert(is(Single == MetaList!int));

    alias T = Map!(Unqual, int, const int, immutable int);
    static assert(is(T == MetaList!(int, int, int)));
}

/**
    Tests whether all given items satisfy a template predicate, i.e. evaluates to
    $(D F!(T[0]) && F!(T[1]) && ... && F!(T[$ - 1])).

    Evaluation is $(I not) short-circuited if a false result is encountered; the
    template predicate must be instantiable with all the given items.
 */
template all(alias F, T...)
{
    static if (T.length == 0)
    {
        enum all = true;
    }
    else static if (T.length == 1)
    {
        enum all = F!(T[0]);
    }
    else
    {
        enum all =
            all!(F, T[ 0  .. $/2]) &&
            all!(F, T[$/2 ..  $ ]);
    }
}

///
unittest
{
    import std.traits : isIntegral;

    static assert(!all!(isIntegral, int, double));
    static assert( all!(isIntegral, int, long));
}

/**
Tests whether any given items satisfy a template predicate, i.e. evaluates to
$(D F!(T[0]) || F!(T[1]) || ... || F!(T[$ - 1])).

Evaluation is $(I not) short-circuited if a true result is encountered; the
template predicate must be instantiable with all the given items.
 */
template any(alias F, T...)
{
    static if(T.length == 0)
    {
        enum any = false;
    }
    else static if (T.length == 1)
    {
        enum any = F!(T[0]);
    }
    else
    {
        enum any =
            any!(F, T[ 0  .. $/2]) ||
            any!(F, T[$/2 ..  $ ]);
    }
}

///
unittest
{
    import std.traits : isIntegral;

    static assert(!any!(isIntegral, string, double));
    static assert( any!(isIntegral, int, double));
}

/**
 * Filters a list using a template predicate. Returns a
 * list of the elements which satisfy the predicate.
 */
template Filter(alias pred, TList...)
{
    import std.meta.list;

    static if (TList.length == 0)
    {
        alias Filter = MetaList!();
    }
    else static if (TList.length == 1)
    {
        static if (pred!(TList[0]))
            alias Filter = MetaList!(TList[0]);
        else
            alias Filter = MetaList!();
    }
    else
    {
        alias Filter =
            MetaList!(
                Filter!(pred, TList[ 0  .. $/2]),
                Filter!(pred, TList[$/2 ..  $ ]));
    }
}

///
unittest
{
    import std.traits : isNarrowString, isUnsigned;
    import std.meta.list;

    alias Types1 = MetaList!(string, wstring, dchar[], char[], dstring, int);
    alias TL1 = Filter!(isNarrowString, Types1);
    static assert(is(TL1 == MetaList!(string, wstring, char[])));

    alias Types2 = MetaList!(int, byte, ubyte, dstring, dchar, uint, ulong);
    alias TL2 = Filter!(isUnsigned, Types2);
    static assert(is(TL2 == MetaList!(ubyte, uint, ulong)));
}

unittest
{
    import std.traits : isPointer;
    import std.meta.list;

    static assert(is(Filter!(isPointer, int, void*, char[], int*) == MetaList!(void*, int*)));
    static assert(is(Filter!isPointer == MetaList!()));
}
