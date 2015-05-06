/**
 * Templates that act as compile-time predicates
 *
 * Utility templates available in this module are most commonly
 * used with compile-time algorithms like `Map` or `Filter`.
 *
 * Copyright: Copyright Digital Mars 2005 - 2009.
 * License: $(WEB www.boost.org/LICENSE_1_0.txt, Boost License 1.0).
 * Authors: Mihails Strasuns, Nick Treleaven
 * Source: $(PHOBOSSRC std/meta/_predicates.d)
 */

module std.meta.predicates;

import std.meta.internal;

/**
 * Negates the passed template predicate.
 */
template Not(alias pred)
{
    enum Not(T...) = !pred!T;
}

///
unittest
{
    import std.traits : isPointer;
    import std.meta.algorithm : all;

    alias isNoPointer = Not!isPointer;
    static assert(!isNoPointer!(int*));
    static assert(all!(isNoPointer, string, char, float));
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

unittest
{
    import std.meta.list;
    import std.meta.algorithm : Map;

    foreach (T; MetaList!(int, Map, 42))
    {
        static assert(!Instantiate!(Not!testAlways, T));
        static assert(Instantiate!(Not!testNever, T));
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
template And(Preds...)
{
    template And(T...)
    {
        static if (Preds.length == 0)
        {
            enum And = true;
        }
        else
        {
            static if (Instantiate!(Preds[0], T))
                alias And = Instantiate!(.And!(Preds[1 .. $]), T);
            else
                enum And = false;
        }
    }
}

///
unittest
{
    import std.traits : isNumeric, isUnsigned;

    alias storesNegativeNumbers = And!(isNumeric, Not!isUnsigned);
    static assert(storesNegativeNumbers!int);
    static assert(!storesNegativeNumbers!string && !storesNegativeNumbers!uint);

    // An empty list of predicates always yields true.
    alias alwaysTrue = And!();
    static assert(alwaysTrue!int);
}

unittest
{
    import std.meta.list;
    import std.meta.algorithm : Map;

    foreach (T; MetaList!(int, Map, 42))
    {
        static assert( Instantiate!(And!(), T));
        static assert( Instantiate!(And!(testAlways), T));
        static assert( Instantiate!(And!(testAlways, testAlways), T));
        static assert(!Instantiate!(And!(testNever), T));
        static assert(!Instantiate!(And!(testAlways, testNever), T));
        static assert(!Instantiate!(And!(testNever, testAlways), T));

        static assert(!Instantiate!(And!(testNever, testError), T));
        static assert(!is(typeof(Instantiate!(And!(testAlways, testError), T))));
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
template Or(Preds...)
{
    template Or(T...)
    {
        static if (Preds.length == 0)
        {
            enum Or = false;
        }
        else
        {
            static if (Instantiate!(Preds[0], T))
                enum Or = true;
            else
                alias Or = Instantiate!(.Or!(Preds[1 .. $]), T);
        }
    }
}

///
unittest
{
    import std.traits : isPointer, isUnsigned;

    alias isPtrOrUnsigned = Or!(isPointer, isUnsigned);
    static assert( isPtrOrUnsigned!uint &&  isPtrOrUnsigned!(short*));
    static assert(!isPtrOrUnsigned!int  && !isPtrOrUnsigned!(string));

    // An empty list of predicates never yields true.
    alias alwaysFalse = Or!();
    static assert(!alwaysFalse!int);
}

unittest
{
    import std.meta.list;
    import std.meta.algorithm : Map;

    foreach (T; MetaList!(int, Map, 42))
    {
        static assert( Instantiate!(Or!(testAlways), T));
        static assert( Instantiate!(Or!(testAlways, testAlways), T));
        static assert( Instantiate!(Or!(testAlways, testNever), T));
        static assert( Instantiate!(Or!(testNever, testAlways), T));
        static assert(!Instantiate!(Or!(), T));
        static assert(!Instantiate!(Or!(testNever), T));

        static assert( Instantiate!(Or!(testAlways, testError), T));
        static assert( Instantiate!(Or!(testNever, testAlways, testError), T));
        // DMD @@BUG@@: Assertion fails for int, seems like a error gagging
        // problem. The bug goes away when removing some of the other template
        // instantiations in the module.
        // static assert(!is(typeof(Instantiate!(Or!(testNever, testError), T))));
    }
}
