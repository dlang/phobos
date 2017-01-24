/*
    Regualar expressions package test suite part 3.
*/
module std.regex.internal.tests3;

package(std.regex):

import std.algorithm, std.conv, std.exception, std.meta, std.range,
    std.typecons, std.regex;

unittest
{ // bugzilla 7141
    string pattern = `[a\--b]`;
    assert(match("-", pattern));
    assert(match("b", pattern));
    string pattern2 = `[&-z]`;
    assert(match("b", pattern2));
}
unittest
{//bugzilla 7111
    assert(match("", regex("^")));
}
unittest
{//bugzilla 7300
    assert(!match("a"d, "aa"d));
}

// bugzilla 7551
unittest
{
    auto r = regex("[]abc]*");
    assert("]ab".matchFirst(r).hit == "]ab");
    assertThrown(regex("[]"));
    auto r2 = regex("[]abc--ab]*");
    assert("]ac".matchFirst(r2).hit == "]");
}

unittest
{//bugzilla 7674
    assert("1234".replace(regex("^"), "$$") == "$1234");
    assert("hello?".replace(regex(r"\?", "g"), r"\?") == r"hello\?");
    assert("hello?".replace(regex(r"\?", "g"), r"\\?") != r"hello\?");
}
unittest
{// bugzilla 7679
    foreach (S; AliasSeq!(string, wstring, dstring))
    (){ // avoid slow optimizations for large functions @@@BUG@@@ 2396
        const re = ctRegex!(to!S(r"\."));
        auto str = to!S("a.b");
        assert(equal(std.regex.splitter(str, re), [to!S("a"), to!S("b")]));
        assert(split(str, re) == [to!S("a"), to!S("b")]);
    }();
}
unittest
{//bugzilla 8203
    string data = "
    NAME   = XPAW01_STA:STATION
    NAME   = XPAW01_STA
    ";
    auto uniFileOld = data;
    auto r = regex(
       r"^NAME   = (?P<comp>[a-zA-Z0-9_]+):*(?P<blk>[a-zA-Z0-9_]*)","gm");
    auto uniCapturesNew = match(uniFileOld, r);
    for (int i = 0; i < 20; i++)
        foreach (matchNew; uniCapturesNew) {}
    //a second issue with same symptoms
    auto r2 = regex(`([а-яА-Я\-_]+\s*)+(?<=[\s\.,\^])`);
    match("аллея Театральная", r2);
}
unittest
{// bugzilla 8637 purity of enforce
    auto m = match("hello world", regex("world"));
    enforce(m);
}

// bugzilla 8725
unittest
{
  static italic = regex( r"\*
                (?!\s+)
                (.*?)
                (?!\s+)
                \*", "gx" );
  string input = "this * is* interesting, *very* interesting";
  assert(replace(input, italic, "<i>$1</i>") ==
      "this * is* interesting, <i>very</i> interesting");
}

// bugzilla 8349
unittest
{
    const peakRegexStr = r"\>(wgEncode.*Tfbs.*\.(?:narrow)|(?:broad)Peak.gz)</a>";
    const peakRegex = ctRegex!(peakRegexStr);
    //note that the regex pattern itself is probably bogus
    assert(match(r"\>wgEncode-blah-Tfbs.narrow</a>", peakRegex));
}

// bugzilla 9211
unittest
{
    auto rx_1 =  regex(r"^(\w)*(\d)");
    auto m = match("1234", rx_1);
    assert(equal(m.front, ["1234", "3", "4"]));
    auto rx_2 = regex(r"^([0-9])*(\d)");
    auto m2 = match("1234", rx_2);
    assert(equal(m2.front, ["1234", "3", "4"]));
}

// bugzilla 9280
unittest
{
    string tomatch = "a!b@c";
    static r = regex(r"^(?P<nick>.*?)!(?P<ident>.*?)@(?P<host>.*?)$");
    auto nm = match(tomatch, r);
    assert(nm);
    auto c = nm.captures;
    assert(c[1] == "a");
    assert(c["nick"] == "a");
}


// bugzilla 9579
unittest
{
    char[] input = ['a', 'b', 'c'];
    string format = "($1)";
    // used to give a compile error:
    auto re = regex(`(a)`, "g");
    auto r = replace(input, re, format);
    assert(r == "(a)bc");
}

// bugzilla 9634
unittest
{
    auto re = ctRegex!"(?:a+)";
    assert(match("aaaa", re).hit == "aaaa");
}

//bugzilla 10798
unittest
{
    auto cr = ctRegex!("[abcd--c]*");
    auto m  = "abc".match(cr);
    assert(m);
    assert(m.hit == "ab");
}

// bugzilla 10913
unittest
{
    @system static string foo(const(char)[] s)
    {
        return s.dup;
    }
    @safe static string bar(const(char)[] s)
    {
        return s.dup;
    }
    () @system {
        replace!((a) => foo(a.hit))("blah", regex(`a`));
    }();
    () @safe {
        replace!((a) => bar(a.hit))("blah", regex(`a`));
    }();
}

// bugzilla 11262
unittest
{
    const reg = ctRegex!(r",", "g");
    auto str = "This,List";
    str = str.replace(reg, "-");
    assert(str == "This-List");
}

// bugzilla 11775
unittest
{
    assert(collectException(regex("a{1,0}")));
}

// bugzilla 11839
unittest
{
    assert(regex(`(?P<var1>\w+)`).namedCaptures.equal(["var1"]));
    assert(collectException(regex(`(?P<1>\w+)`)));
    assert(regex(`(?P<v1>\w+)`).namedCaptures.equal(["v1"]));
    assert(regex(`(?P<__>\w+)`).namedCaptures.equal(["__"]));
    assert(regex(`(?P<я>\w+)`).namedCaptures.equal(["я"]));
}

// bugzilla 12076
unittest
{
    auto RE = ctRegex!(r"(?<!x[a-z]+)\s([a-z]+)");
    string s = "one two";
    auto m = match(s, RE);
}

// bugzilla 12105
unittest
{
    auto r = ctRegex!`.*?(?!a)`;
    assert("aaab".matchFirst(r).hit == "aaa");
    auto r2 = ctRegex!`.*(?!a)`;
    assert("aaab".matchFirst(r2).hit == "aaab");
}

//bugzilla 11784
unittest
{
    assert("abcdefghijklmnopqrstuvwxyz"
        .matchFirst("[a-z&&[^aeiuo]]").hit == "b");
}

//bugzilla 12366
unittest
{
     auto re = ctRegex!(`^((?=(xx+?)\2+$)((?=\2+$)(?=(x+)(\4+$))\5){2})*x?$`);
     assert("xxxxxxxx".match(re).empty);
     assert(!"xxxx".match(re).empty);
}

// bugzilla 12582
unittest
{
    auto r = regex(`(?P<a>abc)`);
    assert(collectException("abc".matchFirst(r)["b"]));
}

// bugzilla 12691
unittest
{
    assert(bmatch("e@", "^([a-z]|)*$").empty);
    assert(bmatch("e@", ctRegex!`^([a-z]|)*$`).empty);
}

//bugzilla  12713
unittest
{
    assertThrown(regex("[[a-z]([a-z]|(([[a-z])))"));
}

//bugzilla 12747
unittest
{
    assertThrown(regex(`^x(\1)`));
    assertThrown(regex(`^(x(\1))`));
    assertThrown(regex(`^((x)(?=\1))`));
}

// bugzilla 14504
unittest
{
    auto p = ctRegex!("a?a?a?a?a?a?a?a?a?a?a?a?a?a?a?a?a?a?a?a?a?a?a?a?a?a?a?a?a?a?" ~
            "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa");
}

// bugzilla 14529
unittest
{
    auto ctPat2 = regex(r"^[CDF]$", "i");
    foreach (v; ["C", "c", "D", "d", "F", "f"])
        assert(matchAll(v, ctPat2).front.hit  == v);
}

// bugzilla 14615
unittest
{
    import std.stdio : writeln;
    import std.regex : replaceFirst, replaceFirstInto, regex;
    import std.array : appender;

    auto example = "Hello, world!";
    auto pattern = regex("^Hello, (bug)");  // won't find this one
    auto result = replaceFirst(example, pattern, "$1 Sponge Bob");
    assert(result == "Hello, world!");  // Ok.

    auto sink = appender!string;
    replaceFirstInto(sink, example, pattern, "$1 Sponge Bob");
    assert(sink.data == "Hello, world!");
    replaceAllInto(sink, example, pattern, "$1 Sponge Bob");
    assert(sink.data == "Hello, world!Hello, world!");
}

// bugzilla 15573
unittest
{
    auto rx = regex("[c d]", "x");
    assert("a b".matchFirst(rx));
}

// bugzilla 15864
unittest
{
    regex(`(<a (?:(?:\w+=\"[^"]*\")?\s*)*href="\.\.?)"`);
}

unittest
{
    auto r = regex("(?# comment)abc(?# comment2)");
    assert("abc".matchFirst(r));
    assertThrown(regex("(?#..."));
}

// bugzilla 17066
unittest
{
    string message = "fix issue 16319 and fix std.traits.isInnerClass";
    static auto matchToRefs(M)(M m)
    {
        // ctRegex throws a weird error in unittest compilation
        enum splitRE = regex(`[^\d]+`);
        return m.captures[5].splitter(splitRE);
    }

    enum issueRE = ctRegex!(`((close|fix|address)e?(s|d)? )` ~
        `?(ticket|bug|tracker item|issue)s?:? *([\d ,\+&#and]+)`, "i");
    auto r = message.matchAll(issueRE);
    r.map!matchToRefs.joiner.array;
}
