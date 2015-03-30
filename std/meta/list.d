/**
 * Provides MetaList and utilities for its manipulation
 *
 * Module that provides one of core D meta-programming primitives - list
 * of compile-time entities. It can contain any type, expression or
 * symbol that is legal template argument.
 *
 * In the same module can be found several template utilities for
 * `MetaList` manipulation and creation of new `MetaList`s.
 *
 * Copyright: Copyright Digital Mars 2005 - 2009.
 * License: $(WEB www.boost.org/LICENSE_1_0.txt, Boost License 1.0).
 * Authors: Mihails Strasuns, Nick Treleaven
 * Source: $(PHOBOSSRC std/meta/_list.d)
 */

module std.meta.list;

import std.meta.internal;

/**
 * Aliases the given compile-time list of template arguments.
 */
alias MetaList(Args...) = Args;

///
unittest
{
    import std.meta.list;

    alias Types = MetaList!(int, double);

    static assert (Types.length == 2);
    static assert (is(Types[0] == int));
    static assert (is(Types[1] == double));
}

///
unittest
{
    import std.meta.list;

    alias ArgumentTypes = MetaList!(int, double);

    auto foo(ArgumentTypes td)  // same as int foo(int, double);
    {
        return td[0] + td[1];
    }
    assert(foo(2, 3.5) == 5.5);
}

///
unittest
{
    alias numbers = MetaList!(1, 2, 3);
    auto arr = [ numbers ];
    assert(arr == [1, 2, 3]);
}

///
unittest
{
    // MetaList does not nest
    alias Types1 = MetaList!(int, double);
    alias Types2 = MetaList!(Types1, char);

    static assert(is(Types2 == MetaList!(int, double, char)));
}

/**
 * Returns the index of the first occurrence of T in the
 * sequence of zero or more elements TList.
 * If not found, -1 is returned.
 */
template indexOf(T, TList...)
{
    enum indexOf = genericIndexOf!(T, TList).index;
}

/// Ditto
template indexOf(alias T, TList...)
{
    enum indexOf = genericIndexOf!(T, TList).index;
}

///
unittest
{
    alias Types = MetaList!(int, long, double);
    static assert(indexOf!(long, Types) == 1);
}

// [internal]
private template genericIndexOf(args...)
    if (args.length >= 1)
{
    alias e     = Alias!(args[0]);
    alias tuple = args[1 .. $];

    static if (tuple.length)
    {
        alias head = Alias!(tuple[0]);
        alias tail = tuple[1 .. $];

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
    static assert(indexOf!( byte, byte, short, int, long) ==  0);
    static assert(indexOf!(short, byte, short, int, long) ==  1);
    static assert(indexOf!(  int, byte, short, int, long) ==  2);
    static assert(indexOf!( long, byte, short, int, long) ==  3);
    static assert(indexOf!( char, byte, short, int, long) == -1);
    static assert(indexOf!(   -1, byte, short, int, long) == -1);
    static assert(indexOf!(void) == -1);

    static assert(indexOf!("abc", "abc", "def", "ghi", "jkl") ==  0);
    static assert(indexOf!("def", "abc", "def", "ghi", "jkl") ==  1);
    static assert(indexOf!("ghi", "abc", "def", "ghi", "jkl") ==  2);
    static assert(indexOf!("jkl", "abc", "def", "ghi", "jkl") ==  3);
    static assert(indexOf!("mno", "abc", "def", "ghi", "jkl") == -1);
    static assert(indexOf!( void, "abc", "def", "ghi", "jkl") == -1);
    static assert(indexOf!(42) == -1);

    static assert(indexOf!(void, 0, "void", void) == 2);
    static assert(indexOf!("void", 0, void, "void") == 2);
}

/**
 * Returns a list created from TList with the first occurrence,
 * if any, of T removed.
 */
template Erase(T, TList...)
{
    alias Erase = GenericErase!(T, TList).result;
}

/// Ditto
template Erase(alias T, TList...)
{
    alias Erase = GenericErase!(T, TList).result;
}

///
unittest
{
    alias Types = MetaList!(int, long, double, char);
    alias TL = Erase!(long, Types);
    static assert(is(TL == MetaList!(int, double, char)));
}

// [internal]
private template GenericErase(args...)
    if (args.length >= 1)
{
    alias e     = Alias!(args[0]);
    alias tuple = args[1 .. $] ;

    static if (tuple.length)
    {
        alias head = Alias!(tuple[0]);
        alias tail = tuple[1 .. $];

        static if (isSame!(e, head))
            alias result = tail;
        else
            alias result = MetaList!(head, GenericErase!(e, tail).result);
    }
    else
    {
        alias result = MetaList!();
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
 * Returns a list created from TList with all occurrences,
 * if any, of T removed.
 */
template EraseAll(T, TList...)
{
    alias EraseAll = GenericEraseAll!(T, TList).result;
}

/// Ditto
template EraseAll(alias T, TList...)
{
    alias EraseAll = GenericEraseAll!(T, TList).result;
}

///
unittest
{
    alias Types = MetaList!(int, long, long, int);

    alias TL = EraseAll!(long, Types);
    static assert(is(TL == MetaList!(int, int)));
}

// [internal]
private template GenericEraseAll(args...)
    if (args.length >= 1)
{
    alias e     = Alias!(args[0]);
    alias tuple = args[1 .. $];

    static if (tuple.length)
    {
        alias head = Alias!(tuple[0]);
        alias tail = tuple[1 .. $];
        alias next = GenericEraseAll!(e, tail).result;

        static if (isSame!(e, head))
            alias result = next;
        else
            alias result = MetaList!(head, next);
    }
    else
    {
        alias result = MetaList!();
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
 * Returns a list created from TList with all duplicate
 * elements removed.
 */
template NoDuplicates(TList...)
{
    static if (TList.length == 0)
        alias NoDuplicates = TList;
    else
        alias NoDuplicates =
            MetaList!(TList[0], NoDuplicates!(EraseAll!(TList[0], TList[1 .. $])));
}

///
unittest
{
    alias Types = MetaList!(int, long, long, int, float);

    alias TL = NoDuplicates!(Types);
    static assert(is(TL == MetaList!(int, long, float)));
}

unittest
{
    static assert(
        Pack!(
            NoDuplicates!(1, int, 1, NoDuplicates, int, NoDuplicates, real))
        .equals!(1, int,    NoDuplicates,                    real));
}


/**
 * Returns a list created from TList with the first occurrence
 * of T, if found, replaced with U.
 */
template Replace(T, U, TList...)
{
    alias Replace = GenericReplace!(T, U, TList).result;
}

/// Ditto
template Replace(alias T, U, TList...)
{
    alias Replace = GenericReplace!(T, U, TList).result;
}

/// Ditto
template Replace(T, alias U, TList...)
{
    alias Replace = GenericReplace!(T, U, TList).result;
}

/// Ditto
template Replace(alias T, alias U, TList...)
{
    alias Replace = GenericReplace!(T, U, TList).result;
}

///
unittest
{
    alias Types = MetaList!(int, long, long, int, float);

    alias TL = Replace!(long, char, Types);
    static assert(is(TL == MetaList!(int, char, long, int, float)));
}

// [internal]
private template GenericReplace(args...)
    if (args.length >= 2)
{
    alias from  = Alias!(args[0]);
    alias to    = Alias!(args[1]);
    alias tuple = args[2 .. $];

    static if (tuple.length)
    {
        alias head = Alias!(tuple[0]);
        alias tail = tuple[1 .. $];

        static if (isSame!(from, head))
            alias result = MetaList!(to, tail);
        else
            alias result = MetaList!(head,
                GenericReplace!(from, to, tail).result);
    }
    else
    {
        alias result = MetaList!();
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
 * Returns a list created from TList with each occurrence
 * of T, if found, replaced with U.
 */
template ReplaceAll(T, U, TList...)
{
    alias ReplaceAll = GenericReplaceAll!(T, U, TList).result;
}

/// Ditto
template ReplaceAll(alias T, U, TList...)
{
    alias ReplaceAll = GenericReplaceAll!(T, U, TList).result;
}

/// Ditto
template ReplaceAll(T, alias U, TList...)
{
    alias ReplaceAll = GenericReplaceAll!(T, U, TList).result;
}

/// Ditto
template ReplaceAll(alias T, alias U, TList...)
{
    alias ReplaceAll = GenericReplaceAll!(T, U, TList).result;
}

///
unittest
{
    alias Types = MetaList!(int, long, long, int, float);

    alias TL = ReplaceAll!(long, char, Types);
    static assert(is(TL == MetaList!(int, char, char, int, float)));
}

// [internal]
private template GenericReplaceAll(args...)
    if (args.length >= 2)
{
    alias from  = Alias!(args[0]);
    alias to    = Alias!(args[1]);
    alias tuple = args[2 .. $];

    static if (tuple.length)
    {
        alias head = Alias!(tuple[0]);
        alias tail = tuple[1 .. $];
        alias next = GenericReplaceAll!(from, to, tail).result;

        static if (isSame!(from, head))
            alias result = MetaList!(to, next);
        else
            alias result = MetaList!(head, next);
    }
    else
    {
        alias result = MetaList!();
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
 * Returns a list created from TList with the order reversed.
 */
template Reverse(TList...)
{
    static if (TList.length <= 1)
    {
        alias Reverse = TList;
    }
    else
    {
        alias Reverse =
            MetaList!(
                Reverse!(TList[$/2 ..  $ ]),
                Reverse!(TList[ 0  .. $/2]));
    }
}

///
unittest
{
    alias Types = MetaList!(int, long, long, int, float);

    alias TL = Reverse!(Types);
    static assert(is(TL == MetaList!(float, int, long, long, int)));
}

