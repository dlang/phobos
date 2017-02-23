module std.stringbenchmarks;

version(randomized_unittest_benchmark) unittest
{
    import std.string : indexOf;
    import std.format : format;
    import std.experimental.randomized_unittest_benchmark;

    void fun(Gen!(string, 0, 10) toSearchIn,
            Gen!(int, 0xDFFF, 0x10FFFF) toSearchFor)
    {
        auto idx = toSearchIn.indexOf(cast(dchar)toSearchFor);
        doNotOptimizeAway(idx);

        debug
        {
            foreach (int jdx, dchar it; toSearchIn)
            {
                if (it == cast(dchar)toSearchFor)
                {
                    assert(jdx == idx);
                }
            }

            assert(idx == -1, format("%s in \n%s", toSearchFor, toSearchIn));
        }
    }

    benchmark!fun("string.indexOf(dchar)");
}

version(randomized_unittest_benchmark) unittest
{
    import std.experimental.randomized_unittest_benchmark;
    import std.range : chain, iota;
    import std.conv : to;
    import std.stdio : writefln;
    import std.algorithm : equal;
    import std.format : format;
    import std.string : indexOf, indexOfAny, indexOfNeither,
        lastIndexOf, front;

    enum charsToSearch = chain(iota(0x21, 0x7E), iota(0xA1, 0x1FF))
        .to!dstring();
    enum size_t len = charsToSearch.length;

    immutable rounds = 20000;
    auto rnd = Random(1);

    void funIndexOf(S)(S toSearchIn, Gen!(size_t, 0, len) toSearchFor)
    {

        immutable theChar = cast(dchar)charsToSearch[toSearchFor];
        auto idx = toSearchIn.indexOf(theChar);
        doNotOptimizeAway(idx);

        debug
        {
            bool didFind;
            foreach (jdx, dchar it; toSearchIn)
            {
                if (it == theChar)
                {
                    assert(jdx == idx);
                    didFind = true;
                    break;
                }
            }

            assert((didFind ? true : idx == -1),
                format("%s in \n%s", toSearchFor, toSearchIn));
        }

    }


    void funIndexOf2(S,R)(Gen!(S, 10, 500) toSearchIn,
            Gen!(R, 1, 10) toSearchFor)
    {
        auto idx = toSearchIn.indexOf(toSearchFor);
        doNotOptimizeAway(idx);

        debug
        {
            if (idx != -1)
            {
                assert(equal(
                    toSearchIn[idx .. idx + to!S(toSearchFor).length],
                    toSearchFor));
            }
        }
    }

    void funIndexOf3(S)(S toSearchIn, Gen!(size_t, 0, len) toSearchFor)
    {
        immutable theChar = cast(dchar)charsToSearch[toSearchFor];
        auto idx = toSearchIn.lastIndexOf(theChar);

        debug
        {
            bool didFind;
            foreach_reverse (jdx, dchar it; toSearchIn)
            {
                if (it == theChar)
                {
                    assert(jdx == idx);
                    didFind = true;
                    break;
                }
            }

            assert((didFind ? true : idx == -1),
                format("%s in \n%s", toSearchFor, toSearchIn));
        }
    }

    foreach (S; TypeTuple!(string, wstring, dstring))
    {
        benchmark!(funIndexOf!(S))();
        benchmark!(funIndexOf3!(S))();
    }

    void funIndexOf4(S,R)(Gen!(S, 10, 500) toSearchIn,
            Gen!(R, 1, 10) toSearchFor)
    {
        auto idx = toSearchIn.lastIndexOf(toSearchFor);
        doNotOptimizeAway(idx);

        debug
        {
            if (idx != -1)
            {
                assert(equal(
                    toSearchIn[idx .. idx + to!S(toSearchFor).length],
                    toSearchFor));
            }
        }
    }

    void funIndexOf5(S,R)(Gen!(S, 10, 500) toSearchIn,
            Gen!(R, 1, 10) toSearchFor)
    {
        auto idx = toSearchIn.indexOfAny(toSearchFor);
        doNotOptimizeAway(idx);

        debug
        {
            if (idx != -1)
            {
                bool canBeFound;
                foreach (dchar it; toSearchFor)
                {
                    if (toSearchIn[idx .. $].front == it)
                    {
                        canBeFound = true;
                        break;
                    }
                }

                assert(canBeFound);
            }
        }
    }

    void funIndexOf6(S,R)(Gen!(S, 10, 500) toSearchIn,
            Gen!(R, 1, 10) toSearchFor)
    {
        auto idx = toSearchIn.indexOfNeither(toSearchFor);
        doNotOptimizeAway(idx);

        debug
        {
            if (idx != -1)
            {
                bool canBeFound;
                foreach (dchar it; toSearchFor)
                {
                    if (toSearchIn[idx .. $].front == it)
                    {
                        canBeFound = true;
                        break;
                    }
                }

                assert(!canBeFound);
            }
        }
    }

    void funIndexOf7(S,R)(Gen!(S, 10, 500) toSearchIn,
            Gen!(R, 1, 10) toSearchFor)
    {
        auto idx = toSearchIn.indexOfAny(toSearchFor);
        doNotOptimizeAway(idx);

        debug
        {
            if (idx != -1)
            {
                bool canBeFound;
                foreach (dchar it; toSearchFor)
                {
                    if (toSearchIn[idx .. $].front == it)
                    {
                        canBeFound = true;
                        break;
                    }
                }

                assert(canBeFound);
            }
        }
    }

    void funIndexOf8(S,R)(Gen!(S, 10, 500) toSearchIn,
            Gen!(R, 1, 10) toSearchFor)
    {
        auto idx = toSearchIn.indexOfNeither(toSearchFor);
        doNotOptimizeAway(idx);

        debug
        {
            if (idx != -1)
            {
                bool canBeFound;
                foreach (dchar it; toSearchFor)
                {
                    if (toSearchIn[idx .. $].front == it)
                    {
                        canBeFound = true;
                        break;
                    }
                }

                assert(!canBeFound);
            }
        }
    }

    foreach (S; TypeTuple!(string, wstring, dstring))
    {
        foreach (R; TypeTuple!(string, wstring, dstring))
        {
            benchmark!(funIndexOf2!(S,R))();
            benchmark!(funIndexOf4!(S,R))();
            benchmark!(funIndexOf5!(S,R))();
            benchmark!(funIndexOf6!(S,R))();
            benchmark!(funIndexOf7!(S,R))();
            benchmark!(funIndexOf8!(S,R))();
        }
    }
}

version(randomized_unittest_benchmark) unittest
{
    import std.experimental.randomized_unittest_benchmark;
    import std.range : chain, iota, lockstep;
    import std.conv : to;
    import std.array : empty;
    import std.utf : isValidDchar;
    import std.stdio : writefln, writeln;
    import std.format : format;
    import std.string : translate;

    auto charsToSearch = chain(iota(0x21, 0x7E), iota(0xA1, 0x1FF));
    size_t len = charsToSearch.length;
    auto rnd = Random(1);

    dchar[dchar] tt;
    outer: while (tt.length < 50)
    {
        dchar k = charsToSearch[uniform(0, len/2, rnd)];
        assert(isValidDchar(k));
        dchar v = charsToSearch[uniform(len/2, len, rnd)];
        assert(isValidDchar(v));

        if (k == v)
        {
            continue;
        }

        foreach (dchar key, dchar value; tt)
        {
            if (key == k || key == v || value == k || value == v)
            {
                continue outer;
            }
        }
        tt[k] = v;
    }
    assert(tt.length > 0);

    void fun(S)(Gen!(S, 10, 2000) toTrans)
    {
        S afterTrans = translate(toTrans, tt);
        doNotOptimizeAway(afterTrans);

        foreach (dchar it; afterTrans)
        {
            foreach (dchar key; tt.byKey())
            {
                assert(it != key, format("%c %c", it, key));
            }
        }
    }

    foreach (S; TypeTuple!(string, wstring, dstring))
    {
        benchmark!(fun!S)();
    }
}

version(randomized_unittest_benchmark) unittest
{
    import std.experimental.randomized_unittest_benchmark;
    import std.uni : isUpper, isLower;
    import std.string : capitalize, toLower, toUpper;
    import std.format : format;

    void fun(S)(Gen!(S, 0, 200) toUp)
    {
        auto cap = toUp.capitalize();
        doNotOptimizeAway(cap);

        debug
        {
            foreach (idx, dchar it; cap)
            {
                if (idx == 0u)
                {
                    assert(isUpper(it) ? true : toUpper(it) == it);
                }
                else
                {
                    assert(isLower(it) ? true : toLower(it) == it,
                        format("%s %s", it, cap));
                }
            }
        }
    }

    foreach (S; TypeTuple!(string, wstring, dstring))
    {
        benchmark!(fun!S)();
    }
}
