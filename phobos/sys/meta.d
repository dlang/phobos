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
              $(LREF Stride)
              $(LREF Unique)
    ))
    $(TR $(TD Alias sequence transformation) $(TD
              $(LREF Map)
              $(LREF Reverse)
    ))
    $(TR $(TD Alias sequence searching) $(TD
              $(LREF all)
              $(LREF any)
              $(LREF indexOf)
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
    Evaluates to an $(LREF AliasSeq) which only contains every nth element from
    the $(LREF AliasSeq) that was passed in, where $(D n) is stepSize.

    So, if stepSize is $(D 2), then the result contains every other element from
    the original. If stepSize is $(D 3), then the result contains every third
    element from the original. Etc.

    If stepSize is negative, then the result is equivalent to using
    $(LREF Reverse) on the given $(LREF AliasSeq) and then using Stride on it
    with the absolute value of that stepSize.

    If stepSize is positive, then the first element in the original
    $(LREF AliasSeq) is the first element in the result, whereas if stepSize is
    negative, then the last element in the original is the first element in the
    result. Each subsequent element is then the element at the index of the
    previous element plus stepSize.
  +/
template Stride(int stepSize, Args...)
if (stepSize != 0)
{
    alias Stride = AliasSeq!();
    static if (stepSize > 0)
    {
        static foreach (i; 0 .. (Args.length + stepSize - 1) / stepSize)
            Stride = AliasSeq!(Stride, Args[i * stepSize]);
    }
    else
    {
        static foreach (i; 0 .. (Args.length - stepSize - 1) / -stepSize)
            Stride = AliasSeq!(Stride, Args[$ - 1 + i * stepSize]);
    }
}

///
@safe unittest
{
    static assert(is(Stride!(1, short, int, long) == AliasSeq!(short, int, long)));
    static assert(is(Stride!(2, short, int, long) == AliasSeq!(short, long)));
    static assert(is(Stride!(3, short, int, long) == AliasSeq!short));
    static assert(is(Stride!(100, short, int, long) == AliasSeq!short));

    static assert(is(Stride!(-1, short, int, long) == AliasSeq!(long, int, short)));
    static assert(is(Stride!(-2, short, int, long) == AliasSeq!(long, short)));
    static assert(is(Stride!(-3, short, int, long) == AliasSeq!long));
    static assert(is(Stride!(-100, short, int, long) == AliasSeq!long));

    alias Types = AliasSeq!(short, int, long, ushort, uint, ulong);
    static assert(is(Stride!(3, Types) == AliasSeq!(short, ushort)));
    static assert(is(Stride!(3, Types[1 .. $]) == AliasSeq!(int, uint)));
    static assert(is(Stride!(-3, Types) == AliasSeq!(ulong, long)));

    static assert(is(Stride!(-2, Types) == Stride!(2, Reverse!Types)));

    static assert(is(Stride!1 == AliasSeq!()));
    static assert(is(Stride!100 == AliasSeq!()));
}

@safe unittest
{
    static assert(!__traits(compiles, Stride!(0, int)));

    alias Types = AliasSeq!(bool, byte, ubyte, short, ushort, int, uint, long, ulong,
                            char, wchar, dchar, float, double, real, Object);
    alias Types2 = AliasSeq!(bool, ubyte, ushort, uint, ulong, wchar, float, real);
    alias Types3 = AliasSeq!(bool, short, uint, char, float, Object);
    alias Types4 = AliasSeq!(bool, ushort, ulong, float);
    alias Types5 = AliasSeq!(bool, int, wchar, Object);
    alias Types6 = AliasSeq!(bool, uint, float);
    alias Types7 = AliasSeq!(bool, long, real);
    alias Types8 = AliasSeq!(bool, ulong);
    alias Types9 = AliasSeq!(bool, char);
    alias Types10 = AliasSeq!(bool, wchar);

    static assert(is(Stride!(1, Types) == Types));
    static assert(is(Stride!(2, Types) == Types2));
    static assert(is(Stride!(3, Types) == Types3));
    static assert(is(Stride!(4, Types) == Types4));
    static assert(is(Stride!(5, Types) == Types5));
    static assert(is(Stride!(6, Types) == Types6));
    static assert(is(Stride!(7, Types) == Types7));
    static assert(is(Stride!(8, Types) == Types8));
    static assert(is(Stride!(9, Types) == Types9));
    static assert(is(Stride!(10, Types) == Types10));

    static assert(is(Stride!(-1, Types) == Reverse!Types));
    static assert(is(Stride!(-2, Types) == Stride!(2, Reverse!Types)));
    static assert(is(Stride!(-3, Types) == Stride!(3, Reverse!Types)));
    static assert(is(Stride!(-4, Types) == Stride!(4, Reverse!Types)));
    static assert(is(Stride!(-5, Types) == Stride!(5, Reverse!Types)));
    static assert(is(Stride!(-6, Types) == Stride!(6, Reverse!Types)));
    static assert(is(Stride!(-7, Types) == Stride!(7, Reverse!Types)));
    static assert(is(Stride!(-8, Types) == Stride!(8, Reverse!Types)));
    static assert(is(Stride!(-9, Types) == Stride!(9, Reverse!Types)));
    static assert(is(Stride!(-10, Types) == Stride!(10, Reverse!Types)));
}

/++
    Evaluates to an $(LREF AliasSeq) which contains no duplicate elements.

    Unique takes a binary template predicate that it uses to compare elements
    for equality. If the predicate is $(D true) when an element in the given
    $(LREF AliasSeq) is compared with an element with a lower index, then that
    element is not included in the result (so if any elements in the
    $(LREF AliasSeq) are considered equal per the predicate, then only the
    first one is included in the result).

    Note that the binary predicate must be partially instantiable, e.g.
    ---
    alias PartialCmp = Cmp!(Args[0]);
    enum same = PartialCmp!(Args[1]);
    ---
    Otherwise, it won't work.

    See_Also:
        $(REF isSameSymbol, phobos, sys, traits)
        $(REF isSameType, phobos, sys, traits)
  +/
template Unique(alias Cmp, Args...)
{
    alias Unique = AliasSeq!();
    static foreach (i, Arg; Args)
    {
        static if (i == 0)
            Unique = AliasSeq!Arg;
        else
            Unique = AppendIfUnique!(Cmp, Unique, Arg);
    }
}

// Unfortunately, this can't be done in-place in Unique, because then we get
// errors about reassigning Unique after reading it.
private template AppendIfUnique(alias Cmp, Args...)
{
    static if (indexOf!(Cmp!(Args[$ - 1]), Args[0 .. $ - 1]) == -1)
        alias AppendIfUnique = Args;
    else
        alias AppendIfUnique = Args[0 .. $ - 1];
}

///
@safe unittest
{
    import phobos.sys.traits : isSameType;

    alias Types1 = AliasSeq!(int, long, long, int, int, float, int);

    static assert(is(Unique!(isSameType, Types1) ==
                     AliasSeq!(int, long, float)));

    alias Types2 = AliasSeq!(byte, ubyte, short, ushort, int, uint);
    static assert(is(Unique!(isSameType, Types2) == Types2));

    // Empty AliasSeq.
    static assert(Unique!isSameType.length == 0);

    // An AliasSeq with a single element works as well.
    static assert(Unique!(isSameType, int).length == 1);
}

///
@safe unittest
{
    import phobos.sys.traits : isSameSymbol;

    int i;
    string s;
    real r;
    alias Symbols = AliasSeq!(i, s, i, i, s, r, r, i);

    alias Result = Unique!(isSameSymbol, Symbols);
    static assert(Result.length == 3);
    static assert(__traits(isSame, Result[0], i));
    static assert(__traits(isSame, Result[1], s));
    static assert(__traits(isSame, Result[2], r));

    // Comparing AliasSeqs for equality with is expressions only works
    // if they only contain types.
    static assert(!is(Symbols == Result));
}

///
@safe unittest
{
    alias Types = AliasSeq!(int, uint, long, string, short, int*, ushort);

    template sameSize(T)
    {
        enum sameSize(U) = T.sizeof == U.sizeof;
    }
    static assert(is(Unique!(sameSize, Types) ==
                     AliasSeq!(int, long, string, short)));

    // The predicate must be partially instantiable.
    enum sameSize_fails(T, U) = T.sizeof == U.sizeof;
    static assert(!__traits(compiles, Unique!(sameSize_fails, Types)));
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

/++
    Evaluates to the index of the first element where $(D Pred!(Args[i])) is
    $(D true).

    If $(D Pred!(Args[i])) is not $(D true) for any elements, then the result
    is $(D -1).

    Evaluation is $(I not) short-circuited if a $(D true) result is
    encountered; the template predicate must be instantiable with all the
    elements.
  +/
template indexOf(alias Pred, Args...)
{
    enum ptrdiff_t indexOf =
    {
        static foreach (i; 0 .. Args.length)
        {
            static if (Pred!(Args[i]))
                return i;
        }
        return -1;
    }();
}

///
@safe unittest
{
    import phobos.sys.traits : isInteger, isSameSymbol, isSameType;

    alias Types1 = AliasSeq!(string, int, long, char[], ubyte, int);
    alias Types2 = AliasSeq!(float, double, int[], char[], void);

    static assert(indexOf!(isInteger, Types1) == 1);
    static assert(indexOf!(isInteger, Types2) == -1);

    static assert(indexOf!(isSameType!ubyte, Types1) == 4);
    static assert(indexOf!(isSameType!ubyte, Types2) == -1);

    int i;
    int j;
    string s;
    int foo() { return 0; }
    alias Symbols = AliasSeq!(i, j, foo);
    static assert(indexOf!(isSameSymbol!j, Symbols) == 1);
    static assert(indexOf!(isSameSymbol!s, Symbols) == -1);

    // Empty AliasSeq.
    static assert(indexOf!isInteger == -1);

    // The predicate does not compile with all of the arguments,
    // so indexOf does not compile.
    static assert(!__traits(compiles, indexOf!(isSameType!int, long, int, 42)));
}

unittest
{
    import phobos.sys.traits : isSameType;

    static assert(indexOf!(isSameType!int, short, int, long) >= 0);
    static assert(indexOf!(isSameType!string, short, int, long) < 0);

    // This is to verify that we don't accidentally end up with the type of
    // the result differing based on whether it's -1 or not. Not specifying the
    // type at all in indexOf results in -1 being int on all systems and the
    // other results being whatever size_t is (ulong on most systems at this
    // point), which does generally work, but being explicit with the type
    // avoids any subtle issues that might come from the type of the result
    // varying based on whether the item is found or not.
    static assert(is(typeof(indexOf!(isSameType!int, short, int, long)) ==
                     typeof(indexOf!(isSameType!string, short, int, long))));

    static assert(indexOf!(isSameType!string, string, string, string, string) == 0);
    static assert(indexOf!(isSameType!string,    int, string, string, string) == 1);
    static assert(indexOf!(isSameType!string,    int,    int, string, string) == 2);
    static assert(indexOf!(isSameType!string,    int,    int,    int, string) == 3);
    static assert(indexOf!(isSameType!string,    int,    int,    int,    int) == -1);
}
