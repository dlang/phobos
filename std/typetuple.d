// Written in the D programming language.

/**
 * Templates with which to manipulate type tuples (also known as type lists).
 *
 * Some operations on type tuples are built in to the language,
 * such as TL[$(I n)] which gets the $(I n)th type from the
 * type tuple. TL[$(I lwr) .. $(I upr)] returns a new type
 * list that is a slice of the old one.
 *
 * Several templates in this module use or operate on eponymous templates that
 * take a single argument and evaluate to a boolean constant. Such templates
 * are referred to as $(I template predicates).
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
 * License:   $(WEB www.boost.org/LICENSE_1_0.txt, Boost License 1.0).
 * Authors:
 *     $(WEB digitalmars.com, Walter Bright),
 *     $(WEB klickverbot.at, David Nadlinger)
 * Source:    $(PHOBOSSRC std/_typetuple.d)
 */
/*          Copyright Digital Mars 2005 - 2009.
 * Distributed under the Boost Software License, Version 1.0.
 *    (See accompanying file LICENSE_1_0.txt or copy at
 *          http://www.boost.org/LICENSE_1_0.txt)
 */
module std.typetuple;

/**
 * Creates a typetuple out of a sequence of zero or more types.
 */
template TypeTuple(TList...)
{
    alias TypeTuple = TList;
}

///
unittest
{
    import std.typetuple;
    alias TL = TypeTuple!(int, double);

    int foo(TL td)  // same as int foo(int, double);
    {
        return td[0] + cast(int)td[1];
    }
}

///
unittest
{
    alias TL = TypeTuple!(int, double);

    alias Types = TypeTuple!(TL, char);
    static assert(is(Types == TypeTuple!(int, double, char)));
}

/**
 * Returns the index of the first occurrence of type T in the
 * sequence of zero or more types TList.
 * If not found, -1 is returned.
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

///
unittest
{
    import std.typetuple;
    import std.stdio;

    void foo()
    {
        writefln("The index of long is %s",
                 staticIndexOf!(long, TypeTuple!(int, long, double)));
        // prints: The index of long is 1
    }
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
alias IndexOf = staticIndexOf;

/**
 * Returns a typetuple created from TList with the first occurrence,
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
    alias Types = TypeTuple!(int, long, double, char);
    alias TL = Erase!(long, Types);
    static assert(is(TL == TypeTuple!(int, double, char)));
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
            alias result = TypeTuple!(head, GenericErase!(e, tail).result);
    }
    else
    {
        alias result = TypeTuple!();
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
    alias Types = TypeTuple!(int, long, long, int);

    alias TL = EraseAll!(long, Types);
    static assert(is(TL == TypeTuple!(int, int)));
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
            alias result = TypeTuple!(head, next);
    }
    else
    {
        alias result = TypeTuple!();
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
 */
template NoDuplicates(TList...)
{
    static if (TList.length == 0)
        alias NoDuplicates = TList;
    else
        alias NoDuplicates =
            TypeTuple!(TList[0], NoDuplicates!(EraseAll!(TList[0], TList[1 .. $])));
}

///
unittest
{
    alias Types = TypeTuple!(int, long, long, int, float);

    alias TL = NoDuplicates!(Types);
    static assert(is(TL == TypeTuple!(int, long, float)));
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
    alias Types = TypeTuple!(int, long, long, int, float);

    alias TL = Replace!(long, char, Types);
    static assert(is(TL == TypeTuple!(int, char, long, int, float)));
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
            alias result = TypeTuple!(to, tail);
        else
            alias result = TypeTuple!(head,
                GenericReplace!(from, to, tail).result);
    }
    else
    {
        alias result = TypeTuple!();
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
    alias Types = TypeTuple!(int, long, long, int, float);

    alias TL = ReplaceAll!(long, char, Types);
    static assert(is(TL == TypeTuple!(int, char, char, int, float)));
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
            alias result = TypeTuple!(to, next);
        else
            alias result = TypeTuple!(head, next);
    }
    else
    {
        alias result = TypeTuple!();
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
            TypeTuple!(
                Reverse!(TList[$/2 ..  $ ]),
                Reverse!(TList[ 0  .. $/2]));
    }
}

///
unittest
{
    alias Types = TypeTuple!(int, long, long, int, float);

    alias TL = Reverse!(Types);
    static assert(is(TL == TypeTuple!(float, int, long, long, int)));
}

/**
 * Returns the type from TList that is the most derived from type T.
 * If none are found, T is returned.
 */
template MostDerived(T, TList...)
{
    static if (TList.length == 0)
        alias MostDerived = T;
    else static if (is(TList[0] : T))
        alias MostDerived = MostDerived!(TList[0], TList[1 .. $]);
    else
        alias MostDerived = MostDerived!(T, TList[1 .. $]);
}

///
unittest
{
    class A { }
    class B : A { }
    class C : B { }
    alias Types = TypeTuple!(A, C, B);

    MostDerived!(Object, Types) x;  // x is declared as type C
    static assert(is(typeof(x) == C));
}

/**
 * Returns the typetuple TList with the types sorted so that the most
 * derived types come first.
 */
template DerivedToFront(TList...)
{
    static if (TList.length == 0)
        alias DerivedToFront = TList;
    else
        alias DerivedToFront =
            TypeTuple!(MostDerived!(TList[0], TList[1 .. $]),
                       DerivedToFront!(ReplaceAll!(MostDerived!(TList[0], TList[1 .. $]),
                                TList[0],
                                TList[1 .. $])));
}

///
unittest
{
    class A { }
    class B : A { }
    class C : B { }
    alias Types = TypeTuple!(A, C, B);

    alias TL = DerivedToFront!(Types);
    static assert(is(TL == TypeTuple!(C, B, A)));
}

/**
Evaluates to $(D TypeTuple!(F!(T[0]), F!(T[1]), ..., F!(T[$ - 1]))).
 */
template staticMap(alias F, T...)
{
    static if (T.length == 0)
    {
        alias staticMap = TypeTuple!();
    }
    else static if (T.length == 1)
    {
        alias staticMap = TypeTuple!(F!(T[0]));
    }
    else
    {
        alias staticMap =
            TypeTuple!(
                staticMap!(F, T[ 0  .. $/2]),
                staticMap!(F, T[$/2 ..  $ ]));
    }
}

///
unittest
{
    import std.traits : Unqual;
    alias TL = staticMap!(Unqual, int, const int, immutable int);
    static assert(is(TL == TypeTuple!(int, int, int)));
}

unittest
{
    import std.traits : Unqual;

    // empty
    alias Empty = staticMap!(Unqual);
    static assert(Empty.length == 0);

    // single
    alias Single = staticMap!(Unqual, const int);
    static assert(is(Single == TypeTuple!int));

    alias T = staticMap!(Unqual, int, const int, immutable int);
    static assert(is(T == TypeTuple!(int, int, int)));
}

/**
Tests whether all given items satisfy a template predicate, i.e. evaluates to
$(D F!(T[0]) && F!(T[1]) && ... && F!(T[$ - 1])).

Evaluation is $(I not) short-circuited if a false result is encountered; the
template predicate must be instantiable with all the given items.
 */
template allSatisfy(alias F, T...)
{
    static if (T.length == 0)
    {
        enum allSatisfy = true;
    }
    else static if (T.length == 1)
    {
        enum allSatisfy = F!(T[0]);
    }
    else
    {
        enum allSatisfy =
            allSatisfy!(F, T[ 0  .. $/2]) &&
            allSatisfy!(F, T[$/2 ..  $ ]);
    }
}

///
unittest
{
    import std.traits : isIntegral;

    static assert(!allSatisfy!(isIntegral, int, double));
    static assert( allSatisfy!(isIntegral, int, long));
}

/**
Tests whether any given items satisfy a template predicate, i.e. evaluates to
$(D F!(T[0]) || F!(T[1]) || ... || F!(T[$ - 1])).

Evaluation is $(I not) short-circuited if a true result is encountered; the
template predicate must be instantiable with all the given items.
 */
template anySatisfy(alias F, T...)
{
    static if(T.length == 0)
    {
        enum anySatisfy = false;
    }
    else static if (T.length == 1)
    {
        enum anySatisfy = F!(T[0]);
    }
    else
    {
        enum anySatisfy =
            anySatisfy!(F, T[ 0  .. $/2]) ||
            anySatisfy!(F, T[$/2 ..  $ ]);
    }
}

///
unittest
{
    import std.traits : isIntegral;

    static assert(!anySatisfy!(isIntegral, string, double));
    static assert( anySatisfy!(isIntegral, int, double));
}


/**
 * Filters a $(D TypeTuple) using a template predicate. Returns a
 * $(D TypeTuple) of the elements which satisfy the predicate.
 */
template Filter(alias pred, TList...)
{
    static if (TList.length == 0)
    {
        alias Filter = TypeTuple!();
    }
    else static if (TList.length == 1)
    {
        static if (pred!(TList[0]))
            alias Filter = TypeTuple!(TList[0]);
        else
            alias Filter = TypeTuple!();
    }
    else
    {
        alias Filter =
            TypeTuple!(
                Filter!(pred, TList[ 0  .. $/2]),
                Filter!(pred, TList[$/2 ..  $ ]));
    }
}

///
unittest
{
    import std.traits : isNarrowString, isUnsigned;

    alias Types1 = TypeTuple!(string, wstring, dchar[], char[], dstring, int);
    alias TL1 = Filter!(isNarrowString, Types1);
    static assert(is(TL1 == TypeTuple!(string, wstring, char[])));

    alias Types2 = TypeTuple!(int, byte, ubyte, dstring, dchar, uint, ulong);
    alias TL2 = Filter!(isUnsigned, Types2);
    static assert(is(TL2 == TypeTuple!(ubyte, uint, ulong)));
}

unittest
{
    import std.traits : isPointer;

    static assert(is(Filter!(isPointer, int, void*, char[], int*) == TypeTuple!(void*, int*)));
    static assert(is(Filter!isPointer == TypeTuple!()));
}


// Used in template predicate unit tests below.
private version (unittest)
{
    template testAlways(T...)
    {
        enum testAlways = true;
    }

    template testNever(T...)
    {
        enum testNever = false;
    }

    template testError(T...)
    {
        static assert(false, "Should never be instantiated.");
    }
}


/**
 * Negates the passed template predicate.
 */
template templateNot(alias pred)
{
    enum templateNot(T...) = !pred!T;
}

///
unittest
{
    import std.traits : isPointer;

    alias isNoPointer = templateNot!isPointer;
    static assert(!isNoPointer!(int*));
    static assert(allSatisfy!(isNoPointer, string, char, float));
}

unittest
{
    foreach (T; TypeTuple!(int, staticMap, 42))
    {
        static assert(!Instantiate!(templateNot!testAlways, T));
        static assert(Instantiate!(templateNot!testNever, T));
    }
}


/**
 * Combines several template predicates using logical AND, i.e. constructs a new
 * predicate which evaluates to true for a given input T if and only if all of
 * the passed predicates are true for T.
 *
 * The predicates are evaluated from left to right, aborting evaluation in a
 * short-cut manner if a false result is encountered, in which case the latter
 * instantiations do not need to compile.
 */
template templateAnd(Preds...)
{
    template templateAnd(T...)
    {
        static if (Preds.length == 0)
        {
            enum templateAnd = true;
        }
        else
        {
            static if (Instantiate!(Preds[0], T))
                alias templateAnd = Instantiate!(.templateAnd!(Preds[1 .. $]), T);
            else
                enum templateAnd = false;
        }
    }
}

///
unittest
{
    import std.traits : isNumeric, isUnsigned;

    alias storesNegativeNumbers = templateAnd!(isNumeric, templateNot!isUnsigned);
    static assert(storesNegativeNumbers!int);
    static assert(!storesNegativeNumbers!string && !storesNegativeNumbers!uint);

    // An empty list of predicates always yields true.
    alias alwaysTrue = templateAnd!();
    static assert(alwaysTrue!int);
}

unittest
{
    foreach (T; TypeTuple!(int, staticMap, 42))
    {
        static assert( Instantiate!(templateAnd!(), T));
        static assert( Instantiate!(templateAnd!(testAlways), T));
        static assert( Instantiate!(templateAnd!(testAlways, testAlways), T));
        static assert(!Instantiate!(templateAnd!(testNever), T));
        static assert(!Instantiate!(templateAnd!(testAlways, testNever), T));
        static assert(!Instantiate!(templateAnd!(testNever, testAlways), T));

        static assert(!Instantiate!(templateAnd!(testNever, testError), T));
        static assert(!is(typeof(Instantiate!(templateAnd!(testAlways, testError), T))));
    }
}


/**
 * Combines several template predicates using logical OR, i.e. constructs a new
 * predicate which evaluates to true for a given input T if and only at least
 * one of the passed predicates is true for T.
 *
 * The predicates are evaluated from left to right, aborting evaluation in a
 * short-cut manner if a true result is encountered, in which case the latter
 * instantiations do not need to compile.
 */
template templateOr(Preds...)
{
    template templateOr(T...)
    {
        static if (Preds.length == 0)
        {
            enum templateOr = false;
        }
        else
        {
            static if (Instantiate!(Preds[0], T))
                enum templateOr = true;
            else
                alias templateOr = Instantiate!(.templateOr!(Preds[1 .. $]), T);
        }
    }
}

///
unittest
{
    import std.traits : isPointer, isUnsigned;

    alias isPtrOrUnsigned = templateOr!(isPointer, isUnsigned);
    static assert( isPtrOrUnsigned!uint &&  isPtrOrUnsigned!(short*));
    static assert(!isPtrOrUnsigned!int  && !isPtrOrUnsigned!(string));

    // An empty list of predicates never yields true.
    alias alwaysFalse = templateOr!();
    static assert(!alwaysFalse!int);
}

unittest
{
    foreach (T; TypeTuple!(int, staticMap, 42))
    {
        static assert( Instantiate!(templateOr!(testAlways), T));
        static assert( Instantiate!(templateOr!(testAlways, testAlways), T));
        static assert( Instantiate!(templateOr!(testAlways, testNever), T));
        static assert( Instantiate!(templateOr!(testNever, testAlways), T));
        static assert(!Instantiate!(templateOr!(), T));
        static assert(!Instantiate!(templateOr!(testNever), T));

        static assert( Instantiate!(templateOr!(testAlways, testError), T));
        static assert( Instantiate!(templateOr!(testNever, testAlways, testError), T));
        // DMD @@BUG@@: Assertion fails for int, seems like a error gagging
        // problem. The bug goes away when removing some of the other template
        // instantiations in the module.
        // static assert(!is(typeof(Instantiate!(templateOr!(testNever, testError), T))));
    }
}


// : : : : : : : : : : : : : : : : : : : : : : : : : : : : : : : : : //
package:

/*
 * With the builtin alias declaration, you cannot declare
 * aliases of, for example, literal values. You can alias anything
 * including literal values via this template.
 */
// symbols and literal values
template Alias(alias a)
{
    static if (__traits(compiles, { alias x = a; }))
        alias Alias = a;
    else static if (__traits(compiles, { enum x = a; }))
        enum Alias = a;
    else
        static assert(0, "Cannot alias " ~ a.stringof);
}
// types and tuples
template Alias(a...)
{
    alias Alias = a;
}

unittest
{
    enum abc = 1;
    static assert(__traits(compiles, { alias a = Alias!(123); }));
    static assert(__traits(compiles, { alias a = Alias!(abc); }));
    static assert(__traits(compiles, { alias a = Alias!(int); }));
    static assert(__traits(compiles, { alias a = Alias!(1,abc,int); }));
}


// : : : : : : : : : : : : : : : : : : : : : : : : : : : : : : : : : //
private:

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
                     __traits(compiles, expectBool!(ab[0] == ab[1])))
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
private template expectBool(bool b) {}

unittest
{
    static assert( isSame!(int, int));
    static assert(!isSame!(int, short));

    enum a = 1, b = 1, c = 2, s = "a", t = "a";
    static assert( isSame!(1, 1));
    static assert( isSame!(a, 1));
    static assert( isSame!(a, b));
    static assert(!isSame!(b, c));
    static assert( isSame!("a", "a"));
    static assert( isSame!(s, "a"));
    static assert( isSame!(s, t));
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
    static assert(!isSame!(foo, 0));

    int  x, y;
    real z;
    static assert( isSame!(x, x));
    static assert(!isSame!(x, y));
    static assert(!isSame!(y, z));
    static assert( isSame!(z, z));
    static assert(!isSame!(x, 0));
}

/*
 * [internal] Confines a tuple within a template.
 */
private template Pack(T...)
{
    alias tuple = T;

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

/*
 * Instantiates the given template with the given list of parameters.
 *
 * Used to work around syntactic limitations of D with regard to instantiating
 * a template from a type tuple (e.g. T[0]!(...) is not valid) or a template
 * returning another template (e.g. Foo!(Bar)!(Baz) is not allowed).
 */
// TODO: Consider publicly exposing this, maybe even if only for better
// understandability of error messages.
alias Instantiate(alias Template, Params...) = Template!Params;
