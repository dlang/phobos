/**
 * Templates with which to manipulate
 * $(LINK2 ../template.html#TemplateArgumentList, $(I TemplateArgumentList))s.
 * Such lists are known as type lists when they only contain types.
 *
 * Some operations on template argument lists are built in to the language,
 * such as $(D Args[$(I n)]) which gets the $(I n)th element from the
 * _list. $(D Args[$(I lwr) .. $(I upr)]) returns a new
 * _list that is a slice of the old one. This is analogous to array slicing syntax.
 *
 * Several templates in this module use or operate on enum templates that
 * take a single argument and evaluate to a boolean constant. Such templates
 * are referred to as $(I template predicates).
 *
 * References:
 *  Based on ideas in Table 3.1 from
 *  $(LINK2 http://amazon.com/exec/obidos/ASIN/0201704315/ref=ase_classicempire/102-2957199-2585768,
 *      Modern C++ Design),
 *   Andrei Alexandrescu (Addison-Wesley Professional, 2001)
 * Macros:
 *  WIKI = Phobos/StdMeta
 *
 * Copyright: Copyright Digital Mars 2005 - 2009.
 * License:   $(WEB www.boost.org/LICENSE_1_0.txt, Boost License 1.0).
 * Authors:
 *     $(WEB digitalmars.com, Walter Bright),
 *     $(WEB klickverbot.at, David Nadlinger)
 * Source:    $(PHOBOSSRC std/meta/_package.d)
 */
module std.meta;

public import std.meta.list;
public import std.meta.algorithm;
public import std.meta.predicates;

// public import temporary to simplify updating rest of Phobos
// shouldn't go into release
public import std.meta.internal;

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
    alias Types = MetaList!(A, C, B);

    MostDerived!(Object, Types) x;  // x is declared as type C
    static assert(is(typeof(x) == C));
}

/**
 * Returns the list TList with the types sorted so that the most
 * derived types come first.
 */
template DerivedToFront(TList...)
{
    static if (TList.length == 0)
        alias DerivedToFront = TList;
    else
        alias DerivedToFront =
            MetaList!(MostDerived!(TList[0], TList[1 .. $]),
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
    alias Types = MetaList!(A, C, B);

    alias TL = DerivedToFront!(Types);
    static assert(is(TL == MetaList!(C, B, A)));
}
