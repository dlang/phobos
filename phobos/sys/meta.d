// Written in the D programming language
/++
    Templates to manipulate
    $(DDSUBLINK spec/template, variadic-templates, template parameter sequences)
    (also known as $(I alias sequences)).

    Some operations on alias sequences are built into the language,
    such as `S[i]`, which accesses the element at index `i` in the
    sequence. `S[low .. high]` returns a new alias
    sequence that is a slice of the old one.

    For more information, see
    $(DDLINK ctarguments, Compile-time Sequences, Compile-time Sequences).

    One thing that should be noted is that while the templates provided in this
    module can be extremely useful, they generally should not be used with lists
    of values. The language uses alias sequences for a variety of things
    (including both parameter lists and argument lists), so they can contain
    types, symbols, values, or a mixture of them all. The ability to manipulate
    types and symbols within alias sequences is vital, because that's really
    the only way to do it. However, because D has CTFE (Compile-Time Function
    Evaluation), making it possible to call many functions at compile time, if
    code needs to be able to manipulate values at compile-time, CTFE is
    typically much more efficient and easier to do. Instantiating a bunch of
    templates to manipulate values is incredibly inefficient in comparison.

    So, while many of the templates in this module will work with values simply
    because alias sequences can contain values, most code should restrict
    itself to using them for operating on types or symbols - i.e. the stuff
    where CTFE can't be used. That being said, there will be times when one can
    be used to feed into the other. E.G.
    ---
    alias Types = AliasSeq!(int, byte, ulong, int[10]);

    enum Sizeof(T) = T.sizeof;

    alias sizesAsAliasSeq = Map!(Sizeof, Types);
    static assert(sizesAsAliasSeq == AliasSeq!(4, 1, 8, 40));

    enum size_t[] sizes = [sizesAsAliasSeq];
    static assert(sizes == [4, 1, 8, 40]);
    ---

    Just be aware that if CTFE can be used for a particular task, it's better to
    use CTFE than to manipulate alias sequences with the kind of templates
    provided by this module.

    $(SCRIPT inhibitQuickIndex = 1;)
    $(DIVC quickindex,
    $(BOOKTABLE ,
    $(TR $(TH Category) $(TH Templates))
    $(TR $(TD Building blocks) $(TD
             $(LREF Alias)
             $(LREF AliasSeq)
    ))
    $(TR $(TD Alias sequence filtering) $(TD
              $(LREF Filter)
    ))
    $(TR $(TD Alias sequence transformation) $(TD
              $(LREF Map)
              $(LREF Reverse)
    ))
    $(TR $(TD Alias sequence searching) $(TD
              $(LREF all)
              $(LREF any)
    ))
    )

   References:
       Based on ideas in Table 3.1 from
       $(LINK2 http://amazon.com/exec/obidos/ASIN/0201704315/ref=ase_classicempire/102-2957199-2585768,
         Modern C++ Design),
       Andrei Alexandrescu (Addison-Wesley Professional, 2001)

    Copyright: Copyright The D Language Foundation 2005 - 2024.
    License: $(HTTP www.boost.org/LICENSE_1_0.txt, Boost License 1.0).
    Authors: $(HTTP digitalmars.com, Walter Bright),
             $(HTTP klickverbot.at, David Nadlinger)
             $(HTTP jmdavisprog.com, Jonathan M Davis)
    Source:    $(PHOBOSSRC phobos/sys/meta)
+/
module phobos.sys.meta;

// Example for converting types to values from module documentation.
@safe unittest
{
    alias Types = AliasSeq!(int, byte, ulong, int[10]);

    enum Sizeof(T) = T.sizeof;

    alias sizesAsAliasSeq = Map!(Sizeof, Types);
    static assert(sizesAsAliasSeq == AliasSeq!(4, 1, 8, 40));

    enum size_t[] sizes = [sizesAsAliasSeq];
    static assert(sizes == [4, 1, 8, 40]);
}

/++
   Creates a sequence of zero or more aliases. This is most commonly
   used as template parameters or arguments.
 +/
alias AliasSeq(TList...) = TList;

///
@safe unittest
{
    alias TL = AliasSeq!(int, double);

    int foo(TL td)  // same as int foo(int, double);
    {
        return td[0] + cast(int) td[1];
    }
}

///
@safe unittest
{
    alias TL = AliasSeq!(int, double);

    alias Types = AliasSeq!(TL, char);
    static assert(is(Types == AliasSeq!(int, double, char)));
}

///
@safe unittest
{
    static char foo(size_t i, string str)
    {
        return str[i];
    }

    alias vars = AliasSeq!(2, "dlang");

    assert(foo(vars) == 'a');
}

/++
    Allows aliasing of any single symbol, type or compile-time expression.

    Not everything can be directly aliased. An alias cannot be declared
    of - for example - a literal:
    ---
    alias a = 4; //Error
    ---
    With this template any single entity can be aliased:
    ---
    alias b = Alias!4; //OK
    ---
    See_Also:
        To alias more than one thing at once, use $(LREF AliasSeq).
  +/
alias Alias(alias a) = a;

/// Ditto
alias Alias(T) = T;

///
@safe unittest
{
    // Without Alias this would fail if Args[0] were e.g. a value and
    // some logic would be needed to detect when to use enum instead.
    alias Head(Args...) = Alias!(Args[0]);
    alias Tail(Args...) = Args[1 .. $];

    alias Blah = AliasSeq!(3, int, "hello");
    static assert(Head!Blah == 3);
    static assert(is(Head!(Tail!Blah) == int));
    static assert((Tail!Blah)[1] == "hello");
}

///
@safe unittest
{
    {
        alias a = Alias!123;
        static assert(a == 123);
    }
    {
        enum e = 1;
        alias a = Alias!e;
        static assert(a == 1);
    }
    {
        alias a = Alias!(3 + 4);
        static assert(a == 7);
    }
    {
        alias concat = (s0, s1) => s0 ~ s1;
        alias a = Alias!(concat("Hello", " World!"));
        static assert(a == "Hello World!");
    }
    {
        alias A = Alias!int;
        static assert(is(A == int));
    }
    {
        alias A = Alias!(AliasSeq!int);
        static assert(!is(typeof(A[0]))); // An Alias is not an AliasSeq.
        static assert(is(A == int));
    }
    {
        auto i = 6;
        alias a = Alias!i;
        ++a;
        assert(i == 7);
    }
}

/++
    Filters an $(D AliasSeq) using the given template predicate.

    The result is an $(D AliasSeq) that contains only the elements which satisfy
    the predicate.
  +/
template Filter(alias Pred, Args...)
{
    alias Filter = AliasSeq!();
    static foreach (Arg; Args)
    {
        static if (Pred!Arg)
            Filter = AliasSeq!(Filter, Arg);
    }
}

///
@safe unittest
{
    import phobos.sys.traits : isDynamicArray, isPointer, isUnsignedInteger;

    alias Types = AliasSeq!(string, int, int[], bool[], ulong, double, ubyte);

    static assert(is(Filter!(isDynamicArray, Types) ==
                     AliasSeq!(string, int[], bool[])));

    static assert(is(Filter!(isUnsignedInteger, Types) ==
                     AliasSeq!(ulong, ubyte)));

    static assert(is(Filter!(isPointer, Types) == AliasSeq!()));
}

/++
    Map takes a template and applies it to every element in the given
    $(D AliasSeq), resulting in an $(D AliasSeq) with the transformed elements.

    So, it's equivalent to
    `AliasSeq!(Fun!(Args[0]), Fun!(Args[1]), ..., Fun!(Args[$ - 1]))`.
 +/
template Map(alias Fun, Args...)
{
    alias Map = AliasSeq!();
    static foreach (Arg; Args)
        Map = AliasSeq!(Map, Fun!Arg);
}

///
@safe unittest
{
    import phobos.sys.traits : Unqualified;

    // empty
    alias Empty = Map!Unqualified;
    static assert(Empty.length == 0);

    // single
    alias Single = Map!(Unqualified, const int);
    static assert(is(Single == AliasSeq!int));

    // several
    alias Several = Map!(Unqualified, int, const int, immutable int, uint,
                         ubyte, byte, short, ushort, const long);
    static assert(is(Several == AliasSeq!(int, int, int, uint,
                                          ubyte, byte, short, ushort, long)));

    alias ToDynamicArray(T) = T[];

    alias Arrays = Map!(ToDynamicArray, int, const ubyte, string);
    static assert(is(Arrays == AliasSeq!(int[], const(ubyte)[], string[])));
}

// @@@ BUG @@@ The test below exposes failure of the straightforward use.
// See @adamdruppe's comment to https://github.com/dlang/phobos/pull/8039
@safe unittest
{
    template id(alias what)
    {
        enum id = __traits(identifier, what);
    }

    enum A { a }
    static assert(Map!(id, A.a) == AliasSeq!"a");
}

// regression test for https://issues.dlang.org/show_bug.cgi?id=21088
@system unittest // typeid opEquals is @system
{
    enum getTypeId(T) = typeid(T);
    alias A = Map!(getTypeId, int);

    assert(A == typeid(int));
}

/++
    Takes an $(D AliasSeq) and result in an $(D AliasSeq) where the order of
    the elements has been reversed.
  +/
template Reverse(Args...)
{
    alias Reverse = AliasSeq!();
    static foreach_reverse (Arg; Args)
        Reverse = AliasSeq!(Reverse, Arg);
}

///
@safe unittest
{
    static assert(is(Reverse!(int, byte, long, string) ==
                     AliasSeq!(string, long, byte, int)));

    alias Types = AliasSeq!(int, long, long, int, float,
                            ubyte, short, ushort, uint);
    static assert(is(Reverse!Types == AliasSeq!(uint, ushort, short, ubyte,
                                                float, int, long, long, int)));

    static assert(is(Reverse!() == AliasSeq!()));
}

/++
    Whether the given template predicate is $(D true) for all of the elements in
    the given $(D AliasSeq).

    Evaluation is $(I not) short-circuited if a $(D false) result is
    encountered; the template predicate must be instantiable with all the
    elements.
  +/
version (StdDdoc) template all(alias Pred, Args...)
{
    import core.internal.traits : allSatisfy;
    alias all = allSatisfy!(Pred, Args);
}
else
{
    import core.internal.traits : allSatisfy;
    alias all = allSatisfy;
}

///
@safe unittest
{
    import phobos.sys.traits : isDynamicArray, isInteger;

    static assert(!all!(isInteger, int, double));
    static assert( all!(isInteger, int, long));

    alias Types = AliasSeq!(string, int[], bool[]);

    static assert( all!(isDynamicArray, Types));
    static assert(!all!(isInteger, Types));

    static assert( all!isInteger);
}

/++
    Whether the given template predicate is $(D true) for any of the elements in
    the given $(D AliasSeq).

    Evaluation is $(I not) short-circuited if a $(D true) result is
    encountered; the template predicate must be instantiable with all the
    elements.
  +/
version (StdDdoc) template any(alias Pred, Args...)
{
    import core.internal.traits : anySatisfy;
    alias any = anySatisfy!(Pred, Args);
}
else
{
    import core.internal.traits : anySatisfy;
    alias any = anySatisfy;
}

///
@safe unittest
{
    import phobos.sys.traits : isDynamicArray, isInteger;

    static assert(!any!(isInteger, string, double));
    static assert( any!(isInteger, int, double));

    alias Types = AliasSeq!(string, int[], bool[], real, bool);

    static assert( any!(isDynamicArray, Types));
    static assert(!any!(isInteger, Types));

    static assert(!any!isInteger);
}
