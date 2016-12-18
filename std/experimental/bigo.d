module std.experimental.bigo;

struct BigO
{
    import std.typecons : Tuple;
    import std.algorithm : cartesianProduct, map, sum;
    import std.array : array, empty, front, popFront;
    import std.range : chain;

    alias Atom = Tuple!(int, "id", double, "exp", double, "logExp");
    private Atom[][] terms;

    string toString() const @safe
    {
        if (terms.empty) return "O(1)";
        string result = "O(";
        foreach (ref e; terms)
        {
            if (result.length > 2) result ~= " + ";
            foreach (ref f; e)
            {
                import std.conv : to;
                if (f.exp != 0)
                {
                    result ~= "n";
                    if (f.id != 0) result ~= f.id.to!string;
                    if (f.exp != 1)
                    {
                        result ~= "^^";
                        result ~= f.exp.to!string;
                    }
                }
                if (f.logExp != 0)
                {
                    if (f.exp != 0)
                    {
                        result ~= " * ";
                    }
                    result ~= "log(n";
                    if (f.id) result ~= f.id.to!string;
                    result ~= ")";
                    if (f.logExp != 1)
                    {
                        result ~= "^^";
                        result ~= f.exp.to!string;
                    }
                }
            }
        }
        result ~= ")";
        return result;
    }

    unittest
    {
        static assert(constantTime.toString == "O(1)");
        static assert(linearTime.toString == "O(n)");
        static assert(linearTime.shifted.toString == "O(n1)");
        assert(quadraticTime.toString == "O(n^^2)");
        assert(linearithmicTime.shifted.toString == "O(n1 * log(n1))");
        static assert((linearTime + linearTime.shifted).toString == "O(n + n1)");
    }

    @safe pure nothrow:

    int opCmp(const BigO rhs) const
    {
        if (terms.empty) return rhs.terms.empty ? 0 : -1;
        if (rhs.terms.empty) return 1;
        int result = 0;
        foreach (ref l; terms)
        {
            foreach (ref r; rhs.terms)
            {
                if (l == r) goto move_on;
                if (smaller(l, r))
                {
                    if (result == 1) return 0;
                    if (result == 0) result = -1;
                    goto move_on;
                }
                if (smaller(r, l))
                {
                    if (result == -1) return 0;
                    if (result == 0) result = 1;
                    goto move_on;
                }
            }
            // Not comparable
            return 0;
            // https://issues.dlang.org/show_bug.cgi?id=15450
        move_on:
        }
        return result;
    }

    unittest
    {
        static assert(
                      constantTime <= constantTime
                      && constantTime == constantTime
                      && linearTime <= linearTime
                      && linearTime == linearTime
                      && constantTime != linearTime
                      && constantTime < linearTime
                      && constantTime <= linearTime
                      && linearTime >= constantTime
                      && linearTime > constantTime
                      && linearTime < logarithmicTime * linearTime
                      && linearTime * logarithmicTime > linearTime);
    }

    private static Atom[] multiply(const(Atom)[] lhs, const(Atom)[] rhs)
    {
        Atom[] result;
        for (;;)
        {
            if (lhs.empty)
            {
                result ~= rhs;
                break;
            }
            if (rhs.empty)
            {
                result ~= lhs;
                break;
            }
            if (lhs.front.id == rhs.front.id)
            {
                // Add exponents
                result ~= Atom(lhs.front.id,
                               lhs.front.exp + rhs.front.exp,
                               lhs.front.logExp + rhs.front.logExp);
                lhs.popFront;
                rhs.popFront;
            }
            else if (lhs.front.id < rhs.front.id)
            {
                result ~= lhs.front;
                lhs.popFront;
            }
            else
            {
                result ~= rhs.front;
                rhs.popFront;
            }
        }
        return result;
    }

    unittest
    {
        auto a = [ Atom(0, 1, 1), Atom(2, 1, 0) ];
        auto b = [ Atom(0, 2, 0), Atom(1, 1, 0) ];
        assert(multiply(a, b) == [ Atom(0, 3, 1), Atom(1, 1, 0), Atom(2, 1, 0) ]);
    }

    // Product lhs is smaller than product rhs
    private static bool smaller(const Atom lhs, const Atom rhs)
    {
        if (lhs.id != rhs.id) return false;
        if (lhs.exp != rhs.exp) return lhs.exp < rhs.exp;
        if (lhs.logExp != rhs.logExp) return lhs.logExp < rhs.logExp;
        return false;
    }

    unittest
    {
        assert(!smaller(Atom(0, 1, 1), Atom(0, 1, 1)));
        assert(smaller(Atom(0, 1, 1), Atom(0, 1, 2)));
        assert(!smaller(Atom(0, 1, 1), Atom(1, 0, 1)));
    }

    // Term lhs is smaller than term rhs
    // Assume lhs and rhs sorted by id
    private static bool smaller(const(Atom)[] lhs, const(Atom)[] rhs)
    {
        for (;;)
        {
            if (lhs.empty) return !rhs.empty;
            if (rhs.empty) return false;
            if (lhs.front.id < rhs.front.id)
            {
                // lhs's variable not in rhs, definitely not smaller
                return false;
            }
            if (rhs.front.id < lhs.front.id)
            {
                // rhs's variable not in lhs, check if all lhs included
                rhs.popFront;
                break;
            }
            // Same variable, check the exponents
            assert(lhs.front.id == rhs.front.id);
            if (lhs.front.exp > rhs.front.exp) return false;
            if (lhs.front.exp < rhs.front.exp)
            {
                lhs.popFront;
                rhs.popFront;
                break;
            }
            // Same polynomial exponent, check the log exponent
            if (lhs.front.logExp > rhs.front.logExp) return false;
            if (lhs.front.logExp < rhs.front.logExp)
            {
                lhs.popFront;
                rhs.popFront;
                break;
            }
            // Same poly and log exponents, move forward with both
            lhs.popFront;
            rhs.popFront;
        }
        // If we got here, recurse
        return lhs == rhs || smaller(lhs, rhs);
    }

    unittest
    {
        assert(smaller([Atom(0, 1, 1), Atom(1, 1, 0)],
                       [Atom(0, 1, 1), Atom(1, 1, 1)]));
    }

    BigO opAdd(const BigO rhs) const
    {
        Atom[][] result;
    bigone:
        foreach (ref term; chain(terms, rhs.terms))
        {
            foreach (ref r; result)
            {
                if (term == r || smaller(term, r)) continue bigone;
                if (smaller(r, term))
                {
                    r = term.dup;
                    continue bigone;
                }
            }
            result ~= term.dup;
        }
        return BigO(result);
    }

    BigO opMul(const BigO rhs) const
    {
        if (terms.empty) return rhs.dup;
        if (rhs.terms.empty) return dup;
        Atom[][] result;
    bigone:
        foreach (ref e; cartesianProduct(terms, rhs.terms))
        {
            auto term = multiply(e[0], e[1]);
            foreach (ref r; result)
            {
                if (term == r || smaller(term, r)) continue bigone;
                if (smaller(r, term))
                {
                    r = term;
                    continue bigone;
                }
            }
            // This is not comparable to any existing term, add it
            result ~= term;
        }
        return BigO(result);
    }

    BigO shifted(int delta = 1) const
    {
        return BigO(terms
                    .map!(term => term
                          .map!(f => Atom(f.id + delta, f.exp, f.logExp))
                          .array)
                    .array);
    }

    unittest
    {
        static assert(constantTime.shifted == constantTime);
        static assert(linearTime.shifted == BigO([ [ BigO.Atom(1, 1, 0) ] ]));
        static assert(linearTime.shifted.shifted(-1) == linearTime);
    }

    BigO dup() const
    {
        return BigO(terms
                    .map!(term => term
                          .map!(f => Atom(f.id, f.exp, f.logExp))
                          .array)
                    .array);
    }
}

static immutable
    constantTime = BigO.init,
    linearTime = BigO([ [ BigO.Atom(0, 1, 0) ] ]),
    logarithmicTime = BigO([ [ BigO.Atom(0, 0, 1) ] ]),
    linearithmicTime = BigO([ [ BigO.Atom(0, 1, 1) ] ]),
    quadraticTime = BigO([ [ BigO.Atom(0, 2, 0) ] ]),
    cubicTime = BigO([ [ BigO.Atom(0, 3, 0) ] ]);

// Approximate O(log(f1 + f2)) = O(log f1) + O(log f2)
// Approximate O(log(n^^a * log(n)^^b)) = O(log n)
BigO log(const BigO x) @safe pure nothrow
{
    BigO.Atom[][] result;
    import std.algorithm : joiner;
    foreach (ref term; x.terms)
    {
    by_factor:
        foreach (ref factor; term)
        {
            if (factor.exp <= 0) continue;
            foreach (ref r; result)
            {
                if (r[0].id == factor.id) continue by_factor;
            }
            result ~= [ BigO.Atom(factor.id, 0, 1) ];
        }
    }
    return BigO(result);
}

unittest
{
    static void test()
    {
        auto l = log(linearTime);
        assert(l.terms.length == 1 && l.terms[0].length == 1);
        assert(l.terms[0][0] == BigO.Atom(0, 0, 1));
        assert(log(l) == constantTime);
        assert(linearTime * logarithmicTime > linearTime);
        assert(linearTime * linearTime == quadraticTime);
    }
    enum _ = (test(), true);
}

BigO complexity(T, string fun)()
{
    BigO candidate;
    bool candidateChosen = false;
    import std.math : isNaN;
    foreach (overload; __traits(getOverloads, T, fun))
    {
        foreach (trait; __traits(getAttributes, overload))
        {
            static if (is(typeof(trait) : const BigO))
            {
                if (!candidateChosen)
                {
                    candidate = trait.dup;
                    candidateChosen = true;
                }
                else
                {
                    assert(candidate == trait,
                        "Overloads of " ~ T.stringof ~ "." ~ fun
                           ~ " cannot declare different complexities.");
                }
            }
        }
    }
    // Assume constantTime complexity if annotation is missing.
    return candidate;
}

BigO complexity(alias fun)()
{
    return complexity!(__traits(parent, fun), __traits(identifier, fun));
}

unittest
{
    static struct List(T)
    {
        void insertFront(T x, T y) @constantTime;
        void insertFront(T x) @constantTime;
    }

    static void insertMany(C)(C container)
    //    @BigO(complexity!("C.insertFront") * linearTime)
    {
    }

    template complexityOf(alias F, C)
        if (__traits(isSame, F, insertMany))
    {
        enum complexityOf = complexity!(C.insertFront) * linearTime;
    }

    List!int lst;
    static assert(complexity!(List!int, "insertFront") == constantTime);
    static assert(complexity!(List!int, "insertFront") < quadraticTime);
    static assert(complexity!(List!int.insertFront) == constantTime);
    import std.stdio;
    assert(constantTime * linearTime == linearTime);
    assert(quadraticTime + cubicTime == cubicTime);
    assert(complexityOf!(insertMany, List!int) == linearTime);
}
