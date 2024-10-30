// Written in the D programming language.

/**
This module implements a variety of type constructors, i.e., templates
that allow construction of new, useful general-purpose types.

$(SCRIPT inhibitQuickIndex = 1;)
$(DIVC quickindex,
$(BOOKTABLE,
$(TR $(TH Category) $(TH Symbols))
$(TR $(TD Types) $(TD
    $(LREF Ternary)
))
))
*/
module phobos.sys.typecons;

/**
Ternary type with three truth values:

$(UL
    $(LI `Ternary.yes` for `true`)
    $(LI `Ternary.no` for `false`)
    $(LI `Ternary.unknown` as an unknown state)
)

Also known as trinary, trivalent, or trilean.

See_Also:
    $(HTTP en.wikipedia.org/wiki/Three-valued_logic,
        Three Valued Logic on Wikipedia)
*/
struct Ternary
{
@safe @nogc nothrow pure:

    private ubyte value = 6;
    private static Ternary make(ubyte b)
    {
        Ternary r = void;
        r.value = b;
        return r;
    }

    /**
        The possible states of the `Ternary`
    */
    enum no = make(0);
    /// ditto
    enum yes = make(2);
    /// ditto
    enum unknown = make(6);

    /**
     Construct and assign from a `bool`, receiving `no` for `false` and `yes`
     for `true`.
    */
    this(bool b)
    {
        value = b << 1;
    }

    /// ditto
    void opAssign(bool b)
    {
        value = b << 1;
    }

    /**
    Construct a ternary value from another ternary value
    */
    this(const Ternary b)
    {
        value = b.value;
    }

    /**
    $(TABLE Truth table for logical operations,
      $(TR $(TH `a`) $(TH `b`) $(TH `$(TILDE)a`) $(TH `a | b`) $(TH `a & b`) $(TH `a ^ b`))
      $(TR $(TD `no`) $(TD `no`) $(TD `yes`) $(TD `no`) $(TD `no`) $(TD `no`))
      $(TR $(TD `no`) $(TD `yes`) $(TD) $(TD `yes`) $(TD `no`) $(TD `yes`))
      $(TR $(TD `no`) $(TD `unknown`) $(TD) $(TD `unknown`) $(TD `no`) $(TD `unknown`))
      $(TR $(TD `yes`) $(TD `no`) $(TD `no`) $(TD `yes`) $(TD `no`) $(TD `yes`))
      $(TR $(TD `yes`) $(TD `yes`) $(TD) $(TD `yes`) $(TD `yes`) $(TD `no`))
      $(TR $(TD `yes`) $(TD `unknown`) $(TD) $(TD `yes`) $(TD `unknown`) $(TD `unknown`))
      $(TR $(TD `unknown`) $(TD `no`) $(TD `unknown`) $(TD `unknown`) $(TD `no`) $(TD `unknown`))
      $(TR $(TD `unknown`) $(TD `yes`) $(TD) $(TD `yes`) $(TD `unknown`) $(TD `unknown`))
      $(TR $(TD `unknown`) $(TD `unknown`) $(TD) $(TD `unknown`) $(TD `unknown`) $(TD `unknown`))
    )
    */
    Ternary opUnary(string s)() if (s == "~")
    {
        return make((386 >> value) & 6);
    }

    /// ditto
    Ternary opBinary(string s)(Ternary rhs) if (s == "|")
    {
        return make((25_512 >> (value + rhs.value)) & 6);
    }

    /// ditto
    Ternary opBinary(string s)(Ternary rhs) if (s == "&")
    {
        return make((26_144 >> (value + rhs.value)) & 6);
    }

    /// ditto
    Ternary opBinary(string s)(Ternary rhs) if (s == "^")
    {
        return make((26_504 >> (value + rhs.value)) & 6);
    }

    /// ditto
    Ternary opBinary(string s)(bool rhs) if (s == "|" || s == "&" || s == "^")
    {
        return this.opBinary!s(Ternary(rhs));
    }
}

///
@safe @nogc nothrow pure unittest
{
    Ternary a;
    assert(a == Ternary.unknown);

    assert(~Ternary.yes == Ternary.no);
    assert(~Ternary.no == Ternary.yes);
    assert(~Ternary.unknown == Ternary.unknown);
}

@safe @nogc nothrow pure unittest
{
    alias f = Ternary.no, t = Ternary.yes, u = Ternary.unknown;
    Ternary[27] truthTableAnd = [
        t, t, t, t, u, u, t, f, f, u, t, u, u, u, u, u, f, f, f, t, f, f, u, f, f,
        f, f,
    ];

    Ternary[27] truthTableOr = [
        t, t, t, t, u, t, t, f, t, u, t, t, u, u, u, u, f, u, f, t, t, f, u, u, f,
        f, f,
    ];

    Ternary[27] truthTableXor = [
        t, t, f, t, u, u, t, f, t, u, t, u, u, u, u, u, f, u, f, t, t, f, u, u, f,
        f, f,
    ];

    for (auto i = 0; i != truthTableAnd.length; i += 3)
    {
        assert((truthTableAnd[i] & truthTableAnd[i + 1]) == truthTableAnd[i + 2]);
        assert((truthTableOr[i] | truthTableOr[i + 1]) == truthTableOr[i + 2]);
        assert((truthTableXor[i] ^ truthTableXor[i + 1]) == truthTableXor[i + 2]);
    }

    Ternary a;
    assert(a == Ternary.unknown);
    static assert(!is(typeof({
                if (a)
                {
                }
            })));
    assert(!is(typeof({ auto b = Ternary(3); })));
    a = true;
    assert(a == Ternary.yes);
    a = false;
    assert(a == Ternary.no);
    a = Ternary.unknown;
    assert(a == Ternary.unknown);
    Ternary b;
    b = a;
    assert(b == a);
    assert(~Ternary.yes == Ternary.no);
    assert(~Ternary.no == Ternary.yes);
    assert(~Ternary.unknown == Ternary.unknown);
}

@safe @nogc nothrow pure unittest
{
    Ternary a = Ternary(true);
    assert(a == Ternary.yes);
    assert((a & false) == Ternary.no);
    assert((a | false) == Ternary.yes);
    assert((a ^ true) == Ternary.no);
    assert((a ^ false) == Ternary.yes);
}
