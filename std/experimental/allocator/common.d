module std.experimental.allocator.common;
import std.traits;

/*
Ternary by Timon Gehr and Andrei Alexandrescu.
*/
struct Ternary
{
    private ubyte value = 6;
    private static Ternary make(ubyte b)
    {
        Ternary r = void;
        r.value = b;
        return r;
    }

    enum no = make(0), yes = make(2), unknown = make(6);

    this(bool b) { value = b << 1; }

    void opAssign(bool b) { value = b << 1; }

    Ternary opUnary(string s)() if (s == "~")
    {
        return make(386 >> value & 6);
    }

    Ternary opBinary(string s)(Ternary rhs) if (s == "|")
    {
        return make(25512 >> value + rhs.value & 6);
    }

    Ternary opBinary(string s)(Ternary rhs) if (s == "&")
    {
        return make(26144 >> value + rhs.value & 6);
    }

    Ternary opBinary(string s)(Ternary rhs) if (s == "^")
    {
        return make(26504 >> value + rhs.value & 6);
    }
}

unittest
{
    alias f = Ternary.no, t = Ternary.yes, u = Ternary.unknown;
    auto truthTableAnd =
    [
        t, t, t,
        t, u, u,
        t, f, f,
        u, t, u,
        u, u, u,
        u, f, f,
        f, t, f,
        f, u, f,
        f, f, f,
    ];

    auto truthTableOr =
    [
        t, t, t,
        t, u, t,
        t, f, t,
        u, t, t,
        u, u, u,
        u, f, u,
        f, t, t,
        f, u, u,
        f, f, f,
    ];

    auto truthTableXor =
    [
        t, t, f,
        t, u, u,
        t, f, t,
        u, t, u,
        u, u, u,
        u, f, u,
        f, t, t,
        f, u, u,
        f, f, f,
    ];

    for (auto i = 0; i != truthTableAnd.length; i += 3)
    {
        assert((truthTableAnd[i] & truthTableAnd[i + 1])
            == truthTableAnd[i + 2]);
        assert((truthTableOr[i] | truthTableOr[i + 1])
            == truthTableOr[i + 2]);
        assert((truthTableXor[i] ^ truthTableXor[i + 1])
            == truthTableXor[i + 2]);
    }

    Ternary a;
    assert(a == Ternary.unknown);
    static assert(!is(typeof({ if (a) {} })));
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

/**
Returns the size in bytes of the state that needs to be allocated to hold an
object of type $(D T). $(D stateSize!T) is zero for $(D struct)s that are not
nested and have no nonstatic member variables.
 */
template stateSize(T)
{
    static if (is(T == class) || is(T == interface))
        enum stateSize = __traits(classInstanceSize, T);
    else static if (is(T == struct) || is(T == union))
        enum stateSize = FieldTypeTuple!T.length || isNested!T ? T.sizeof : 0;
    else static if (is(T == void))
        enum size_t stateSize = 0;
    else
        enum stateSize = T.sizeof;
}

unittest
{
    static assert(stateSize!void == 0);
    struct A {}
    static assert(stateSize!A == 0);
    struct B { int x; }
    static assert(stateSize!B == 4);
    interface I1 {}
    //static assert(stateSize!I1 == 2 * size_t.sizeof);
    class C1 {}
    static assert(stateSize!C1 == 3 * size_t.sizeof);
    class C2 { char c; }
    static assert(stateSize!C2 == 4 * size_t.sizeof);
    static class C3 { char c; }
    static assert(stateSize!C3 == 2 * size_t.sizeof + char.sizeof);
}
