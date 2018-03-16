/*
    Regualar expressions package test suite.
*/
module std.regex.internal.common;

package(std.regex):

import std.conv, std.exception, std.meta, std.range,
    std.typecons, std.regex;

import std.uni : Escapables; // characters that need escaping

struct TestVectors
{
    string pattern;
    string input;
    string result;
    string format;
    string replace;
    string flags;
}


void runTests(alias tv)()
{

    string produceExpected(M,String)(auto ref M m, String fmt)
    {
        auto app = appender!(String)();
        replaceFmt(fmt, m.captures, app, true);
        return app.data;
    }
    void run_tests(alias matchFn)()
    {
        int i;
        static foreach (Char; AliasSeq!( char, wchar, dchar))
        {{
            alias String = immutable(Char)[];
            String produceExpected(M,Range)(auto ref M m, Range fmt)
            {
                auto app = appender!(String)();
                replaceFmt(fmt, m.captures, app, true);
                return app.data;
            }
            Regex!(Char) r;
            foreach (a, tvd; tv)
            {
                uint c = tvd.result[0];
                debug(std_regex_test) writeln(" Test #", a, " pattern: ", tvd.pattern, " with Char = ", Char.stringof);
                try
                {
                    i = 1;
                    r = regex(to!(String)(tvd.pattern), tvd.flags);
                }
                catch (RegexException e)
                {
                    i = 0;
                    debug(std_regex_test) writeln(e.msg);
                }

                assert((c == 'c') ? !i : i, "failed to compile pattern "~tvd.pattern);

                if (c != 'c')
                {
                    auto m = matchFn(to!(String)(tvd.input), r);
                    i = !m.empty;
                    assert(
                        (c == 'y') ? i : !i,
                        text(matchFn.stringof ~": failed to match pattern #", a ,": ", tvd.pattern)
                    );
                    if (c == 'y')
                    {
                        auto result = produceExpected(m, to!(String)(tvd.format));
                        assert(result == to!String(tvd.replace),
                            text(matchFn.stringof ~": mismatch pattern #", a, ": ", tvd.pattern," expected: ",
                                    tvd.replace, " vs ", result));
                    }
                }
            }
        }}
        debug(std_regex_test) writeln("!!! FReD bulk test done "~matchFn.stringof~" !!!");
    }


    void ct_tests()
    {
        import std.algorithm.comparison : equal;
        static foreach (v; 0 .. tv.length)
        {{
            enum tvd = tv[v];
            static if (tvd.result == "c")
            {
                static assert(!__traits(compiles, (){
                    enum r = regex(tvd.pattern, tvd.flags);
                }), "errornously compiles regex pattern: " ~ tvd.pattern);
            }
            else
            {
                //BUG: tv[v] is fine but tvd is not known at compile time?!
                auto r = ctRegex!(tv[v].pattern, tv[v].flags);
                auto nr = regex(tvd.pattern, tvd.flags);
                assert(equal(r.ir, nr.ir),
                    text("!C-T regex! failed to compile pattern #", v ,": ", tvd.pattern));
                auto m = match(tvd.input, r);
                auto c = tvd.result[0];
                bool ok = (c == 'y') ^ m.empty;
                assert(ok, text("ctRegex: failed to match pattern #",
                    v ,": ", tvd.pattern));
                if (c == 'y')
                {
                    import std.stdio : writeln;
                    auto result = produceExpected(m, tvd.format);
                    if (result != tvd.replace)
                        writeln("ctRegex mismatch pattern #", v, ": ", tvd.pattern," expected: ",
                                tvd.replace, " vs ", result);
                }
            }
        }}
        debug(std_regex_test) writeln("!!! FReD C-T test done !!!");
    }

    ct_tests();
    run_tests!bmatch(); //backtracker
    run_tests!match(); //thompson VM
}
