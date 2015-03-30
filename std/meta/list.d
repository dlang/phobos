/**
 * Module that provides one of core D meta-programming primitives - list
 * of compile-time entities. It can contain any type, expression or
 * symbol that is legal template argument.
 *
 * Copyright: Copyright Digital Mars 2005 - 2009.
 * License: $(WEB www.boost.org/LICENSE_1_0.txt, Boost License 1.0).
 * Authors: Mihails Strasuns, Nick Treleaven
 * Source: $(PHOBOSSRC std/meta/_list.d)
 */

module std.meta.list;

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
