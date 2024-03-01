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

    $(SCRIPT inhibitQuickIndex = 1;)
    $(DIVC quickindex,
    $(BOOKTABLE ,
    $(TR $(TH Category) $(TH Templates))
    $(TR $(TD Building blocks) $(TD
             $(LREF Alias)
             $(LREF AliasSeq)
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
    Source:    $(PHOBOSSRC lib/sys/meta)
+/
module lib.sys.meta;

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
    // some logic would be needed to detect when to use enum instead
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
        static assert(!is(typeof(A[0]))); //not an AliasSeq
        static assert(is(A == int));
    }
    {
        auto i = 6;
        alias a = Alias!i;
        ++a;
        assert(i == 7);
    }
}
