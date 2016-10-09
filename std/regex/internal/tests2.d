/*
    Regualar expressions package test suite part 2.
*/
module std.regex.internal.tests2;

package(std.regex):

import std.algorithm, std.conv, std.exception, std.meta, std.range,
    std.typecons, std.regex;

import std.regex.internal.parser : Escapables; // characters that need escaping


unittest
{
    auto cr5 = ctRegex!("(?:a{2,4}b{1,3}){1,2}");
    assert(bmatch("aaabaaaabbb", cr5).hit == "aaabaaaabbb");
    auto cr6 = ctRegex!("(?:a{2,4}b{1,3}){1,2}?"w);
    assert(bmatch("aaabaaaabbb"w,  cr6).hit == "aaab"w);
}

unittest
{
    auto cr7 = ctRegex!(`\r.*?$`,"sm");
    assert(bmatch("abc\r\nxy",  cr7).hit == "\r\nxy");
    auto greed =  ctRegex!("<packet.*?/packet>");
    assert(bmatch("<packet>text</packet><packet>text</packet>", greed).hit
            == "<packet>text</packet>");
}

unittest
{
    auto cr8 = ctRegex!("^(a)(b)?(c*)");
    auto m8 = bmatch("abcc",cr8);
    assert(m8);
    assert(m8.captures[1] == "a");
    assert(m8.captures[2] == "b");
    assert(m8.captures[3] == "cc");
    auto cr9 = ctRegex!("q(a|b)*q");
    auto m9 = match("xxqababqyy",cr9);
    assert(m9);
    assert(equal(bmatch("xxqababqyy",cr9).captures, ["qababq", "b"]));
}

unittest
{
    auto rtr = regex("a|b|c");
    const ctr = regex("a|b|c");
    assert(equal(rtr.ir,ctr.ir));
    //CTFE parser BUG is triggered by group
    //in the middle of alternation (at least not first and not last)
    const testCT = regex(`abc|(edf)|xyz`);
    auto testRT = regex(`abc|(edf)|xyz`);
    assert(equal(testCT.ir,testRT.ir));
}

unittest
{
    immutable cx = ctRegex!"(A|B|C)";
    auto mx = match("B",cx);
    assert(mx);
    assert(equal(mx.captures, [ "B", "B"]));
    immutable cx2 = ctRegex!"(A|B)*";
    assert(match("BAAA",cx2));

    immutable cx3 = ctRegex!("a{3,4}","i");
    auto mx3 = match("AaA",cx3);
    assert(mx3);
    assert(mx3.captures[0] == "AaA");
    immutable cx4 = ctRegex!(`^a{3,4}?[a-zA-Z0-9~]{1,2}`,"i");
    auto mx4 = match("aaaabc", cx4);
    assert(mx4);
    assert(mx4.captures[0] == "aaaab");
    auto cr8 = ctRegex!("(a)(b)?(c*)");
    auto m8 = bmatch("abcc",cr8);
    assert(m8);
    assert(m8.captures[1] == "a");
    assert(m8.captures[2] == "b");
    assert(m8.captures[3] == "cc");
    auto cr9 = ctRegex!(".*$", "gm");
    auto m9 = match("First\rSecond", cr9);
    assert(m9);
    assert(equal(map!"a.hit"(m9), ["First", "", "Second"]));
}

unittest
{
//global matching
    void test_body(alias matchFn)()
    {
        string s = "a quick brown fox jumps over a lazy dog";
        auto r1 = regex("\\b[a-z]+\\b","g");
        string[] test;
        foreach (m; matchFn(s, r1))
            test ~= m.hit;
        assert(equal(test, [ "a", "quick", "brown", "fox", "jumps", "over", "a", "lazy", "dog"]));
        auto free_reg = regex(`

            abc
            \s+
            "
            (
                    [^"]+
                |   \\ "
            )+
            "
            z
        `, "x");
        auto m = match(`abc  "quoted string with \" inside"z`,free_reg);
        assert(m);
        string mails = " hey@you.com no@spam.net ";
        auto rm = regex(`@(?<=\S+@)\S+`,"g");
        assert(equal(map!"a[0]"(matchFn(mails, rm)), ["@you.com", "@spam.net"]));
        auto m2 = matchFn("First line\nSecond line",regex(".*$","gm"));
        assert(equal(map!"a[0]"(m2), ["First line", "", "Second line"]));
        auto m2a = matchFn("First line\nSecond line",regex(".+$","gm"));
        assert(equal(map!"a[0]"(m2a), ["First line", "Second line"]));
        auto m2b = matchFn("First line\nSecond line",regex(".+?$","gm"));
        assert(equal(map!"a[0]"(m2b), ["First line", "Second line"]));
        debug(std_regex_test) writeln("!!! FReD FLAGS test done "~matchFn.stringof~" !!!");
    }
    test_body!bmatch();
    test_body!match();
}

//tests for accumulated std.regex issues and other regressions
unittest
{
    void test_body(alias matchFn)()
    {
        //issue 5857
        //matching goes out of control if ... in (...){x} has .*/.+
        auto c = matchFn("axxxzayyyyyzd",regex("(a.*z){2}d")).captures;
        assert(c[0] == "axxxzayyyyyzd");
        assert(c[1] == "ayyyyyz");
        auto c2 = matchFn("axxxayyyyyd",regex("(a.*){2}d")).captures;
        assert(c2[0] == "axxxayyyyyd");
        assert(c2[1] == "ayyyyy");
        //issue 2108
        //greedy vs non-greedy
        auto nogreed = regex("<packet.*?/packet>");
        assert(matchFn("<packet>text</packet><packet>text</packet>", nogreed).hit
               == "<packet>text</packet>");
        auto greed =  regex("<packet.*/packet>");
        assert(matchFn("<packet>text</packet><packet>text</packet>", greed).hit
               == "<packet>text</packet><packet>text</packet>");
        //issue 4574
        //empty successful match still advances the input
        string[] pres, posts, hits;
        foreach (m; matchFn("abcabc", regex("","g"))) {
            pres ~= m.pre;
            posts ~= m.post;
            assert(m.hit.empty);

        }
        auto heads = [
            "abcabc",
            "abcab",
            "abca",
            "abc",
            "ab",
            "a",
            ""
        ];
        auto tails = [
            "abcabc",
             "bcabc",
              "cabc",
               "abc",
                "bc",
                 "c",
                  ""
        ];
        assert(pres == array(retro(heads)));
        assert(posts == tails);
        //issue 6076
        //regression on .*
        auto re = regex("c.*|d");
        auto m = matchFn("mm", re);
        assert(!m);
        debug(std_regex_test) writeln("!!! FReD REGRESSION test done "~matchFn.stringof~" !!!");
        auto rprealloc = regex(`((.){5}.{1,10}){5}`);
        auto arr = array(repeat('0',100));
        auto m2 = matchFn(arr, rprealloc);
        assert(m2);
        assert(collectException(
                regex(r"^(import|file|binary|config)\s+([^\(]+)\(?([^\)]*)\)?\s*$")
                ) is null);
        foreach (ch; [Escapables])
        {
            assert(match(to!string(ch),regex(`[\`~ch~`]`)));
            assert(!match(to!string(ch),regex(`[^\`~ch~`]`)));
            assert(match(to!string(ch),regex(`[\`~ch~`-\`~ch~`]`)));
        }
        //bugzilla 7718
        string strcmd = "./myApp.rb -os OSX -path \"/GIT/Ruby Apps/sec\" -conf 'notimer'";
        auto reStrCmd = regex (`(".*")|('.*')`, "g");
        assert(equal(map!"a[0]"(matchFn(strcmd, reStrCmd)),
                     [`"/GIT/Ruby Apps/sec"`, `'notimer'`]));
    }
    test_body!bmatch();
    test_body!match();
}

// tests for replace
unittest
{
    void test(alias matchFn)()
    {
        import std.uni : toUpper;

        foreach (i, v; AliasSeq!(string, wstring, dstring))
        {
            auto baz(Cap)(Cap m)
            if (is(Cap == Captures!(Cap.String)))
            {
                return toUpper(m.hit);
            }
            alias String = v;
            assert(std.regex.replace!(matchFn)(to!String("ark rapacity"), regex(to!String("r")), to!String("c"))
                   == to!String("ack rapacity"));
            assert(std.regex.replace!(matchFn)(to!String("ark rapacity"), regex(to!String("r"), "g"), to!String("c"))
                   == to!String("ack capacity"));
            assert(std.regex.replace!(matchFn)(to!String("noon"), regex(to!String("^n")), to!String("[$&]"))
                   == to!String("[n]oon"));
            assert(std.regex.replace!(matchFn)(to!String("test1 test2"), regex(to!String(`\w+`),"g"), to!String("$`:$'"))
                   == to!String(": test2 test1 :"));
            auto s = std.regex.replace!(baz!(Captures!(String)))(to!String("Strap a rocket engine on a chicken."),
                    regex(to!String("[ar]"), "g"));
            assert(s == "StRAp A Rocket engine on A chicken.", text(s));
        }
        debug(std_regex_test) writeln("!!! Replace test done "~matchFn.stringof~"  !!!");
    }
    test!(bmatch)();
    test!(match)();
}

// tests for splitter
unittest
{
    auto s1 = ", abc, de,     fg, hi, ";
    auto sp1 = splitter(s1, regex(", *"));
    auto w1 = ["", "abc", "de", "fg", "hi", ""];
    assert(equal(sp1, w1));

    auto s2 = ", abc, de,  fg, hi";
    auto sp2 = splitter(s2, regex(", *"));
    auto w2 = ["", "abc", "de", "fg", "hi"];

    uint cnt;
    foreach (e; sp2) {
        assert(w2[cnt++] == e);
    }
    assert(equal(sp2, w2));
}

unittest
{
    char[] s1 = ", abc, de,  fg, hi, ".dup;
    auto sp2 = splitter(s1, regex(", *"));
}

unittest
{
    auto s1 = ", abc, de,  fg, hi, ";
    auto w1 = ["", "abc", "de", "fg", "hi", ""];
    assert(equal(split(s1, regex(", *")), w1[]));
}
