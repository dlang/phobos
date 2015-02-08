// Written in the D programming language.

/**
 * This module defines a list of types $(D_PARAM TypeList)
 * and operations on $(D_PARAM TypeList)s.
 * Together they define a compile-time functional programming framework,
 * complete with lambdas, higher-order functions, and arbitrary data structures
 *
 * Macros:
 *    WIKI = Phobos/StdTypelist
 *
 * Synopsis:
 *
 * ----
 * // **** BUG **** problems with mutual recursion
 * template Synopsis(T...)
 * {
 *     alias TypeList!(T) list;
 *
 *     template IsPtr(U) {
 *         static if (is(U foo: V*, V))
 *             enum IsPtr = true;
 *         else
 *             enum IsPtr = false;
 *     }
 *     enum arePointers = All!(list, IsPtr);
 *
 *     alias Map!(StripPtr, list) StripPointers;
 * }
 * static assert(is (Synopsis!(char**, void***).StripPointers.toTuple == TypeTuple!(char, void)));
 * ----
 *
 * Copyright: Copyright Bartosz Milewski 2008- 2009.
 * License:   $(WEB www.boost.org/LICENSE_1_0.txt, Boost License 1.0).
 * Authors:   $(WEB bartoszmilewski.wordpress.com, Bartosz Milewski)
 * Source:    $(PHOBOSSRC std/_typelist.d)
 */
/*          Copyright Burton Radons 2008 - 2009.
 * Distributed under the Boost Software License, Version 1.0.
 *    (See accompanying file LICENSE_1_0.txt or copy at
 *          http://www.boost.org/LICENSE_1_0.txt)
 */
deprecated("Please use std.typecons instead. This module will be removed in March 2015.")
module std.typelist;
version(unittest) {
    import std.typetuple;
}

/**
 * Creates a compile-time list of types from a tuple.
 * $(D TypeList)s are more general than tuples because
 * you can pass more than one $(D TypeList) to a template.
 * You may also combine them into higher-order structures.
 * $(D TypeList)s are passed to other templates as alias parameters
 * To create an empty list use $(D TypeList!())
 *
 * $(D TypeList) efines several "methods":
 *
 * $(D_PARAM toTuple), $(D_PARAM head), $(D_PARAM tail), $(D_PARAM length), $(D_PARAM isEmpty)
 *
 * Example:
 * ---
 * template Filter(alias Pred, alias List)
 * {
 *     static if (List.isEmpty)
 *         alias TypeList!() Filter;
 *     else static if (Pred!(List.head))
 *         alias Cons!(List.head, Filter!(Pred, List.tail)) Filter;
 *     else
 *         alias Filter!(Pred, List.tail) Filter;
 * }
 * ---
 */

template TypeList(T...)
{
    alias T toTuple;

    static if(T.length != 0)
    {
        alias T[0] head;
        alias TypeList!(T[1..$]) tail;
        enum length = T.length;
        enum isEmpty = false;
    }
    else
    {
        enum length = 0;
        enum isEmpty = true;
    }
}

unittest {
    static assert (is (TypeList!(void*, int).toTuple == TypeTuple!(void*, int)));
    static assert (is (TypeList!(void*, int).head == void*));
    static assert (is (TypeList!(void*, int).tail.toTuple == TypeTuple!(int)));
    static assert (is (TypeList!(int).tail.toTuple == TypeTuple!()));
    static assert (TypeList!(int).tail.isEmpty);

    static assert (TypeList!(void*, int).length == 2);
    static assert (!TypeList!(void*, int).isEmpty);
    static assert (TypeList!().length == 0);
    static assert (TypeList!().isEmpty);
}

/**
 * Appends a type tuple to a $(D TypeList), returns a $(D TypeList)
*/
template AppendTypes(alias List, T...)
{
    static if (List.isEmpty)
        alias TypeList!(T) AppendTypes;
    else
        alias TypeList!(List.toTuple, T) AppendTypes;
}

unittest {
    static assert (is (AppendTypes!(TypeList!(void*, int), long, short).toTuple
                       == TypeTuple!(void*, int, long, short)));
    static assert (is (AppendTypes!(TypeList!(void*, int)).toTuple
                       == TypeTuple!(void*, int)));
    static assert (AppendTypes!(TypeList!()).isEmpty);
}

/**
 * Appends one $(D TypeList) to another, returns a $(D TypeList)
*/
template Append(alias Left, alias Right)
{
    alias AppendTypes!(Left, Right.toTuple) Append;
}

unittest {
    static assert (is (Append!(TypeList!(void*, int), TypeList!(long, short)).toTuple
                       == TypeTuple!(void*, int, long, short)));
    static assert (is (Append!(TypeList!(void*, int), TypeList!()).toTuple
                       == TypeTuple!(void*, int)));
    static assert (Append!(TypeList!(), TypeList!()).isEmpty);
}

/**
 * Prepends a type to a $(D TypeList), returns a $(D TypeList)
*/
template Cons(T, alias List)
{
    static if (List.isEmpty)
        alias TypeList!(T) Cons;
    else
        alias TypeList!(T, List.toTuple) Cons;
}

unittest {
    static assert (is (Cons!(long, TypeList!(void*, int)).toTuple
                       == TypeTuple!(long, void*, int)));
    static assert (is (Cons!(long, TypeList!(void*, int)).head
                       == long));
    static assert (is (Cons!(int, TypeList!()).toTuple == TypeTuple!(int)));
    static assert (is (Cons!(char[], Cons!(int, TypeList!())).toTuple
                    == TypeTuple!(char[], int)));
}

/**
 * Tests if all emements of a $(D TypeList) against a predicate.
 * Returns true if all all types satisfy the predicate, false otherwise.
*/
template All(alias List, alias F)
{
    static if (List.isEmpty)
        enum All = true;
    else
        enum All = F!(List.head) && All!(List.tail, F);
}

version(unittest) {
    template IsPointer(T)
    {
        static if (is (T foo: U*, U))
            enum IsPointer = true;
        else
            enum IsPointer = false;
    }
}

unittest {
    static assert (All!(TypeList!(void*, char*, int**), IsPointer));
    static assert (!All!(TypeList!(void*, char*, int), IsPointer));
}

/**
 * Tests if there is an emement in a $(D TypeList) that satisfies a predicate.
*/
template Any(alias List, alias F)
{
    static if (List.isEmpty)
        enum Any = false;
    else
        enum Any = F!(List.head) || Any!(List.tail, F);
}

unittest {
    static assert (Any!(TypeList!(int, char*, int**), IsPointer));
    static assert (!Any!(TypeList!(char[], char, int), IsPointer));
}

/**
 * Applies a given "function" on types to a type tuple. Returns a tuple of results
*/
template Map(alias F, T...)
{
    alias Map!(F, TypeList!(T)).toTuple Map;
}

/**
 * Applies a given "function" to a $(D TypeList). Returns a $(D TypeList) of results
*/
private template Map(alias F, alias List)
{
    static if (List.isEmpty)
        alias TypeList!() Map;
    else
        alias Cons!(F!(List.head), Map!(F, List.tail)) Map;
}

version(unittest) {
    template MakePtr(T)
    {
        alias T* MakePtr;
    }
}

unittest {
    static assert (is (MakePtr!(int) == int*));
    static assert (is (Map!(MakePtr, void *, char) == TypeTuple!(void**, char*)));
}

/**
 * Filters a type tuple using a predicate.
 * Takes a predicate and a tuple and returns another tuple
*/
template Filter(alias Pred, T...)
{
    alias Filter!(Pred, TypeList!(T)).toTuple Filter;
}

/**
 * Filters a $(D TypeList) using a predicate. Returns a $(D TypeList) of elements that
 * satisfy the predicate.
*/
template Filter(alias Pred, alias List)
{
    static if (List.isEmpty)
        alias TypeList!() Filter;
    else static if (Pred!(List.head))
        alias Cons!(List.head, Filter!(Pred, List.tail)) Filter;
    else
        alias Filter!(Pred, List.tail) Filter;
}

unittest {
    static assert(is(Filter!(IsPointer, int, void*, char[], int*) == TypeTuple!(void*, int*)));
    static assert(is(Filter!(IsPointer) == TypeTuple!()));
}

template FoldRight(alias F, alias Init, alias List)
{
    static if (List.isEmpty)
        alias Init FoldRight;
    else
        alias F!(List.head, FoldRight!(F, Init, List.tail)) FoldRight;
}

template FoldRight(alias F, int Init, alias List)
{
    static if (List.isEmpty)
        alias Init FoldRight;
    else
        alias F!(List.head, FoldRight!(F, Init, List.tail)) FoldRight;
}

version(unittest) {
    template snoC(T, alias List)
    {
        alias TypeList!(List.toTuple, T) snoC;
    }

    template Inc(T, int i)
    {
        enum Inc = i + 1;
    }
}

unittest {
    // *** Compiler bugs
    //static assert (snoC!(int, TypeList!(long)).toTuple == TypeTuple!(long, int));
    //static assert (FoldRight!(snoC, TypeList!(), TypeList!(int, long)).toTuple == TypeTuple!(long, int));
    static assert (!FoldRight!(snoC, TypeList!(), TypeList!(int)).isEmpty);
    static assert (FoldRight!(Inc, 0, TypeList!(int, long)) == 2);
}

/** A list of functions operating on types.
 * Used to pass multiple type functions to
 * a template.
 *
 * Example:
 * ----
 * template Or(alias FList)
 * {
 *     template lambda(X)
 *     {
 *         static if (FList.isEmpty)
 *             enum lambda = true;
 *         else
 *             enum lambda = FList.head!(X) || Or!(FList.tail).apply!(X);
 *     }
 *     alias lambda apply;
 * }
 * ----
*/
template TypeFunList()
{
    enum length = 0;
    enum isEmpty = true;
}

template TypeFunList(alias F)
{
    alias F head;
    alias TypeFunList!() tail;
    enum length = 1;
    enum isEmpty = false;
}

template TypeFunList(alias F, alias Tail)
{
    alias F head;
    alias Tail tail;
    enum length = 1 + Tail.length;
    enum isEmpty = false;
}

unittest {
    static assert (TypeFunList!().isEmpty);
    static assert (!TypeFunList!(IsPointer).isEmpty);
    static assert (TypeFunList!(IsPointer).tail.isEmpty);
    static assert (TypeFunList!(IsPointer).head!(void*));
    static assert (TypeFunList!(IsPointer, TypeFunList!(IsPointer)).head!(void *));
    static assert (TypeFunList!(IsPointer, TypeFunList!(IsPointer)).tail.head!(void *));
}

/** Negates a type predicate.
 * The negated predicate is a "member" $(D apply).
 *
 * Example:
 * ----
 * static assert (Not!(IsPointer).apply!(int));
 * ----
*/
template Not(alias F)
{
    template lambda(X)
    {
        enum lambda = !F!(X);
    }
    alias lambda apply;
}

unittest {
    static assert (Not!(IsPointer).apply!(int));
}

/** Combines two type predicates using logical OR.
 * The resulting predicate is callable through the field $(D apply)
 *
 * Example:
 * ----
 * static assert(Or!(IsPointer, Not!(IsPointer).apply).apply!(int));
 * ----
*/
template Or(alias F1, alias F2)
{
    template lambda(X)
    {
        enum lambda = F1!(X) || F2!(X);
    }
    alias lambda apply;
}

unittest {
    static assert(Or!(IsPointer, IsPointer).apply!(int*));
    static assert(Or!(IsPointer, Not!(IsPointer).apply).apply!(int));
}

/** Combines a list of type predicates using logical OR.
 * The resulting predicate is callable through the field $(D apply)
*/
template Or(alias FList)
{
    template lambda(X)
    {
        static if (FList.isEmpty)
            enum lambda = true;
        else
            enum lambda = FList.head!(X) || Or!(FList.tail).apply!(X);
    }
    alias lambda apply;
}

unittest {
    static assert (Or!(
        TypeFunList!(IsPointer,
                     TypeFunList!(Not!(IsPointer).apply)
                     )).apply!(int*));
}

/** Combines two type predicates using logical AND.
 * The resulting predicate is callable through the field $(D apply)
 *
 * Example:
 * ----
 * static assert(!And!(IsPointer, Not!(IsPointer).apply).apply!(int));
 * ----
*/
template And(alias F1, alias F2)
{
    template lambda(X)
    {
        enum lambda = F1!(X) && F2!(X);
    }
    alias lambda apply;
}

unittest {
    static assert(And!(IsPointer, IsPointer).apply!(int*));
    static assert(!And!(IsPointer, Not!(IsPointer).apply).apply!(int));
}

/** Combines a list of type predicates using logical AND.
 * The resulting predicate is callable through the field $(D apply)
*/
template And(alias FList)
{
    template lambda(X)
    {
        static if (FList.isEmpty)
            enum lambda = true;
        else
            enum lambda = FList.head!(X) && And!(FList.tail).apply!(X);
    }
    alias lambda apply;
}

unittest {
    static assert (!And!(
        TypeFunList!(IsPointer,
                     TypeFunList!(Not!(IsPointer).apply)
                     )).apply!(int*));
}
