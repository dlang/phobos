// Written in the D programming language.

/**
String handling functions. Objects of types $(D _string), $(D
wstring), and $(D dstring) are value types and cannot be mutated
element-by-element. For using mutation during building strings, use
$(D char[]), $(D wchar[]), or $(D dchar[]). The $(D *_string) types
are preferable because they don't exhibit undesired aliasing, thus
making code more robust.

Macros: WIKI = Phobos/StdString

Copyright: Copyright Digital Mars 2007-.

License: $(WEB boost.org/LICENSE_1_0.txt, Boost License 1.0).

Authors: $(WEB digitalmars.com, Walter Bright),
         $(WEB erdani.org, Andrei Alexandrescu),
         and Jonathan M Davis

Source:    $(PHOBOSSRC std/_string.d)

$(B $(RED IMPORTANT NOTE:)) Beginning with version 2.052, the
following symbols have been generalized beyond strings and moved to
different modules. This action was prompted by the fact that
generalized routines belong better in other places, although they
still work for strings as expected. In order to use moved symbols, you
will need to import the respective modules as follows:

$(BOOKTABLE ,

$(TR $(TH Symbol) $(TH Comment))

$(TR $(TD $(D cmp)) $(TD Moved to $(XREF algorithm, cmp) and
generalized to work for all input ranges and accept a custom
predicate.))

$(TR $(TD $(D count)) $(TD Moved to $(XREF algorithm, count) and
generalized to accept a custom predicate.))

$(TR $(TD $(D ByCodeUnit)) $(TD Removed.))

$(TR $(TD $(D insert)) $(TD Use $(XREF array, insertInPlace) instead.))

$(TR $(TD $(D join)) $(TD Use $(XREF array, join) instead.))

$(TR $(TD $(D repeat)) $(TD Use $(XREF array, replicate) instead.))

$(TR $(TD $(D replace)) $(TD Use $(XREF array, replace) instead.))

$(TR $(TD $(D replaceSlice)) $(TD Use $(XREF array, replace) instead.))

$(TR $(TD $(D split)) $(TD Use $(XREF array, split) instead.))
)

*/
module std.string;

//debug=string;                 // uncomment to turn on debugging printf's

import core.exception : onRangeError;
import core.vararg, core.stdc.stdlib, core.stdc.string,
    std.algorithm, std.ascii, std.conv, std.exception, std.format, std.functional,
    std.metastrings, std.range, std.regex, std.traits,
    std.typetuple, std.uni, std.utf;

//Remove when repeat is finally removed. They're only here as part of the
//deprecation of these functions in std.string.
public import std.algorithm : startsWith, endsWith, cmp, count;
public import std.array : join, split;

version(Windows) extern (C)
{
    size_t wcslen(in wchar *);
    int wcscmp(in wchar *, in wchar *);
}

version(unittest) import std.algorithm : filter;

/* ************* Exceptions *************** */

/++
    Exception thrown on errors in std.string functions.
  +/
class StringException : Exception
{
    /++
        Params:
            msg  = The message for the exception.
            file = The file where the exception occurred.
            line = The line number where the exception occurred.
            next = The previous exception in the chain of exceptions, if any.
      +/
    this(string msg,
         string file = __FILE__,
         size_t line = __LINE__,
         Throwable next = null)
    {
        super(msg, file, line, next);
    }
}

/* ************* Constants *************** */

/++
    $(RED Scheduled for deprecation in January 2012.
          Please use $(XREF ascii, hexDigits) instead.)

    0..9A..F
  +/
immutable char[16] hexdigits = "0123456789ABCDEF";

/++
    $(RED Scheduled for deprecation in January 2012.
          Please use $(XREF ascii, _digits) instead.)

    0..9
  +/
alias std.ascii.digits digits;

/++
    $(RED Scheduled for deprecation in January 2012.
          Please use $(XREF ascii, octDigits) instead.)

    0..7
  +/
immutable char[8]  octdigits = "01234567";

/++
    $(RED Scheduled for deprecation in January 2012.
          Please use $(XREF ascii, _lowercase) instead.)

    a..z
  +/
immutable char[26] lowercase = "abcdefghijklmnopqrstuvwxyz";

/++
    $(RED Scheduled for deprecation in January 2012.
          Please use $(XREF ascii, _letters) instead.)

    A..Za..z
  +/
immutable char[52] letters   = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
    "abcdefghijklmnopqrstuvwxyz";

/++
    $(RED Scheduled for deprecation in January 2012.
          Please use $(XREF ascii, _uppercase) instead.)

    A..Z
  +/
immutable char[26] uppercase = "ABCDEFGHIJKLMNOPQRSTUVWXYZ";

/++
    $(RED Scheduled for deprecation in January 2012.
          Please use $(XREF ascii, _whitespace) instead.)

    ASCII whitespace.
  +/
alias std.ascii.whitespace whitespace;

/++
    $(RED Scheduled for deprecation in January 2012.
          Please use $(XREF uni, lineSep) instead.)

    UTF line separator.
  +/
enum dchar LS = '\u2028';

/++
    $(RED Scheduled for deprecation in January 2012.
          Please use $(XREF uni, paraSep) instead.)

    UTF paragraph separator.
  +/
enum dchar PS = '\u2029';

/++
    $(RED Scheduled for deprecation in January 2012.
          Please use $(XREF ascii, _newline) instead.)

    Newline sequence for this system.
  +/
alias std.ascii.newline newline;

/**********************************
 * $(RED Scheduled for deprecation in January 2012.
 *       Please use $(XREF ascii, isWhite) or $(XREF uni, isWhite) instead.)
 *
 * Returns true if c is ASCII whitespace or unicode LS or PS.
 */
version(StdDdoc) bool iswhite(dchar c);
else bool iswhite(C)(C c)
    if(is(Unqual!C : dchar))
{
    return c <= 0x7F
        ? indexOf(whitespace, c) != -1
        : (c == paraSep || c == lineSep);
}


/++
    Compares two ranges of characters lexicographically. The comparison is
    case insensitive. Use $(D XREF algorithm, cmp) for a case sensitive
    comparison. $(D icmp) works like $(D XREF algorithm, cmp) except that it
    converts characters to lowercase prior to applying ($D pred). Technically,
    $(D icmp(r1, r2)) is equivalent to
    $(D cmp!"std.uni.toLower(a) < std.uni.toLower(b)"(r1, r2)).

    $(BOOKTABLE,
        $(TR $(TD $(D < 0))  $(TD $(D s1 < s2) ))
        $(TR $(TD $(D = 0))  $(TD $(D s1 == s2)))
        $(TR $(TD $(D > 0))  $(TD $(D s1 > s2)))
     )
  +/
int icmp(alias pred = "a < b", S1, S2)(S1 s1, S2 s2)
    if(isSomeString!S1 && isSomeString!S2)
{
    static if(is(typeof(pred) : string))
        enum isLessThan = pred == "a < b";
    else
        enum isLessThan = false;

    size_t i, j;
    while(i < s1.length && j < s2.length)
    {
        immutable c1 = std.uni.toLower(decode(s1, i));
        immutable c2 = std.uni.toLower(decode(s2, j));

        static if(isLessThan)
        {
            if(c1 != c2)
            {
                if(c1 < c2) return -1;
                if(c1 > c2) return 1;
            }
        }
        else
        {
            if(binaryFun!pred(c1, c2)) return -1;
            if(binaryFun!pred(c2, c1)) return 1;
        }
    }

    if(i < s1.length) return 1;
    if(j < s2.length) return -1;

    return 0;
}

int icmp(alias pred = "a < b", S1, S2)(S1 s1, S2 s2)
    if(!(isSomeString!S1 && isSomeString!S2) &&
       isForwardRange!S1 && is(Unqual!(ElementType!S1) == dchar) &&
       isForwardRange!S2 && is(Unqual!(ElementType!S2) == dchar))
{
    static if(is(typeof(pred) : string))
        enum isLessThan = pred == "a < b";
    else
        enum isLessThan = false;

    for(;; s1.popFront(), s2.popFront())
    {
        if(s1.empty) return s2.empty ? 0 : -1;
        if(s2.empty) return 1;

        immutable c1 = std.uni.toLower(s1.front);
        immutable c2 = std.uni.toLower(s2.front);

        static if(isLessThan)
        {
            if(c1 != c2)
            {
                if(c1 < c2) return -1;
                if(c1 > c2) return 1;
            }
        }
        else
        {
            if(binaryFun!pred(c1, c2)) return -1;
            if(binaryFun!pred(c2, c1)) return 1;
        }
    }
}

unittest
{
    debug(string) printf("string.icmp.unittest\n");

    assert(icmp("Ü", "ü") == 0, "Über failure");
    assert(icmp("abc", "abc") == 0);
    assert(icmp("ABC", "abc") == 0);
    assert(icmp("abc"w, "abc") == 0);
    assert(icmp("ABC", "abc"w) == 0);
    assert(icmp("abc"d, "abc") == 0);
    assert(icmp("ABC", "abc"d) == 0);
    assert(icmp(cast(char[])"abc", "abc") == 0);
    assert(icmp("ABC", cast(char[])"abc") == 0);
    assert(icmp(cast(wchar[])"abc"w, "abc") == 0);
    assert(icmp("ABC", cast(wchar[])"abc"w) == 0);
    assert(icmp(cast(dchar[])"abc"d, "abc") == 0);
    assert(icmp("ABC", cast(dchar[])"abc"d) == 0);
    assert(icmp(cast(string)null, cast(string)null) == 0);
    assert(icmp("", "") == 0);
    assert(icmp("abc", "abcd") < 0);
    assert(icmp("abcd", "abc") > 0);
    assert(icmp("abc", "abd") < 0);
    assert(icmp("bbc", "abc") > 0);
    assert(icmp("abc", "abc"w) == 0);
    assert(icmp("ABC"w, "abc") == 0);
    assert(icmp("", ""w) == 0);
    assert(icmp("abc"w, "abcd") < 0);
    assert(icmp("abcd", "abc"w) > 0);
    assert(icmp("abc", "abd") < 0);
    assert(icmp("bbc"w, "abc") > 0);
    assert(icmp("aaa", "aaaa"d) < 0);
    assert(icmp("aaaa"w, "aaa"d) > 0);
    assert(icmp("aaa"d, "aaa"w) == 0);
    assert(icmp("\u0430\u0411\u0543"d, "\u0430\u0411\u0543") == 0);
    assert(icmp("\u0430\u0411\u0543"d, "\u0431\u0410\u0544") < 0);
    assert(icmp("\u0431\u0411\u0544"d, "\u0431\u0410\u0543") > 0);
    assert(icmp("\u0430\u0410\u0543"d, "\u0430\u0410\u0544") < 0);
    assert(icmp("\u0430\u0411\u0543"d, "\u0430\u0411\u0543\u0237") < 0);
    assert(icmp("\u0430\u0411\u0543\u0237"d, "\u0430\u0411\u0543") > 0);

    assert(icmp("aaa", filter!"true"("aaa")) == 0);
    assert(icmp(filter!"true"("aaa"), "aaa") == 0);
    assert(icmp(filter!"true"("aaa"), filter!"true"("aaa")) == 0);
    assert(icmp(filter!"true"("\u0430\u0411\u0543"d), "\u0430\u0411\u0543") == 0);
    assert(icmp(filter!"true"("\u0430\u0411\u0543"d), "\u0431\u0410\u0544"w) < 0);
    assert(icmp("\u0431\u0411\u0544"d, filter!"true"("\u0431\u0410\u0543"w)) > 0);
    assert(icmp("\u0430\u0410\u0543"d, filter!"true"("\u0430\u0410\u0544")) < 0);
    assert(icmp(filter!"true"("\u0430\u0411\u0543"d), filter!"true"("\u0430\u0411\u0543\u0237")) < 0);
    assert(icmp(filter!"true"("\u0430\u0411\u0543\u0237"d), filter!"true"("\u0430\u0411\u0543")) > 0);
}


/++
    Returns a C-style 0-terminated string equivalent to $(D s). $(D s) must not
    contain embedded $(D 0)'s as any C functions will treat the first $(D 0)
    that it sees a the end of the string. I $(D s) is $(D null) or empty, then
    a string containing only $(D '\0') is returned.

    $(RED Important Note:) When passing a $(D char*) to a C function, and the C
    function keeps it around for any reason, make sure that you keep a reference
    to it in your D code. Otherwise, it may go away during a garbage collection
    cycle and cause a nasty bug when the C code tries to use it.
  +/
immutable(char)* toStringz(const(char)[] s) pure nothrow
in
{
    // The assert below contradicts the unittests!
    //assert(memchr(s.ptr, 0, s.length) == null,
    //text(s.length, ": `", s, "'"));
}
out (result)
{
    if (result)
    {
        auto slen = s.length;
        while (slen > 0 && s[slen-1] == 0) --slen;
        assert(strlen(result) == slen);
        assert(memcmp(result, s.ptr, slen) == 0);
    }
}
body
{
    /+ Unfortunately, this isn't reliable.
     We could make this work if string literals are put
     in read-only memory and we test if s[] is pointing into
     that.

     /* Peek past end of s[], if it's 0, no conversion necessary.
     * Note that the compiler will put a 0 past the end of static
     * strings, and the storage allocator will put a 0 past the end
     * of newly allocated char[]'s.
     */
     char* p = &s[0] + s.length;
     if (*p == 0)
     return s;
     +/

    // Need to make a copy
    auto copy = new char[s.length + 1];
    copy[0..s.length] = s;
    copy[s.length] = 0;

    return assumeUnique(copy).ptr;
}

/++ Ditto +/
immutable(char)* toStringz(string s) pure nothrow
{
    if (s.empty) return "".ptr;
    /* Peek past end of s[], if it's 0, no conversion necessary.
     * Note that the compiler will put a 0 past the end of static
     * strings, and the storage allocator will put a 0 past the end
     * of newly allocated char[]'s.
     */
    immutable p = s.ptr + s.length;
    // Is p dereferenceable? A simple test: if the p points to an
    // address multiple of 4, then conservatively assume the pointer
    // might be pointing to a new block of memory, which might be
    // unreadable. Otherwise, it's definitely pointing to valid
    // memory.
    if ((cast(size_t) p & 3) && *p == 0)
        return s.ptr;
    return toStringz(cast(const char[]) s);
}

unittest
{
    debug(string) printf("string.toStringz.unittest\n");

    auto p = toStringz("foo");
    assert(strlen(p) == 3);
    const(char) foo[] = "abbzxyzzy";
    p = toStringz(foo[3..5]);
    assert(strlen(p) == 2);

    string test = "";
    p = toStringz(test);
    assert(*p == 0);

    test = "\0";
    p = toStringz(test);
    assert(*p == 0);

    test = "foo\0";
    p = toStringz(test);
    assert(p[0] == 'f' && p[1] == 'o' && p[2] == 'o' && p[3] == 0);
}


/**
   Flag indicating whether a search is case-sensitive.
*/
enum CaseSensitive { no, yes }

/++
    Returns the index of the first occurence of $(D c) in $(D s). If $(D c)
    is not found, then $(D -1) is returned.

    $(D cs) indicates whether the comparisons are case sensitive.
  +/
sizediff_t indexOf(Char)(in Char[] s,
                         dchar c,
                         CaseSensitive cs = CaseSensitive.yes) pure
    if(isSomeChar!Char)
{
    if (cs == CaseSensitive.yes)
    {
        static if (Char.sizeof == 1)
        {
            if (std.ascii.isASCII(c))
            {                                               // Plain old ASCII
                auto p = cast(char*)memchr(s.ptr, c, s.length);
                if (p)
                    return p - cast(char *)s;
                else
                    return -1;
            }
        }

        // c is a universal character
        foreach (sizediff_t i, dchar c2; s)
        {
            if (c == c2)
                return i;
        }
    }
    else
    {
        if (std.ascii.isASCII(c))
        {                                                   // Plain old ASCII
            auto c1 = cast(char) std.ascii.toLower(c);

            foreach (sizediff_t i, c2; s)
            {
                auto c3 = std.ascii.toLower(c2);
                if (c1 == c3)
                    return i;
            }
        }
        else
        {                                                   // c is a universal character
            auto c1 = std.uni.toLower(c);

            foreach (sizediff_t i, dchar c2; s)
            {
                auto c3 = std.uni.toLower(c2);
                if (c1 == c3)
                    return i;
            }
        }
    }
    return -1;
}

unittest
{
    debug(string) printf("string.indexOf.unittest\n");

    foreach (S; TypeTuple!(string, wstring, dstring))
    {
        assert(indexOf(cast(S)null, cast(dchar)'a') == -1);
        assert(indexOf(to!S("def"), cast(dchar)'a') == -1);
        assert(indexOf(to!S("abba"), cast(dchar)'a') == 0);
        assert(indexOf(to!S("def"), cast(dchar)'f') == 2);

        assert(indexOf(to!S("def"), cast(dchar)'a', CaseSensitive.no) == -1);
        assert(indexOf(to!S("def"), cast(dchar)'a', CaseSensitive.no) == -1);
        assert(indexOf(to!S("Abba"), cast(dchar)'a', CaseSensitive.no) == 0);
        assert(indexOf(to!S("def"), cast(dchar)'F', CaseSensitive.no) == 2);

        S sPlts = "Mars: the fourth Rock (Planet) from the Sun.";
        assert(indexOf("def", cast(char)'f', CaseSensitive.no) == 2);
        assert(indexOf(sPlts, cast(char)'P', CaseSensitive.no) == 23);
        assert(indexOf(sPlts, cast(char)'R', CaseSensitive.no) == 2);
    }

    foreach(cs; EnumMembers!CaseSensitive)
    {
        assert(indexOf("hello\U00010143\u0100\U00010143", '\u0100', cs) == 9);
        assert(indexOf("hello\U00010143\u0100\U00010143"w, '\u0100', cs) == 7);
        assert(indexOf("hello\U00010143\u0100\U00010143"d, '\u0100', cs) == 6);
    }
}

/++
    Returns the index of the first occurence of $(D sub) in $(D s). If $(D sub)
    is not found, then $(D -1) is returned.

    $(D cs) indicates whether the comparisons are case sensitive.
  +/
sizediff_t indexOf(Char1, Char2)(const(Char1)[] s,
                                 const(Char2)[] sub,
                                 CaseSensitive cs = CaseSensitive.yes)
    if(isSomeChar!Char1 && isSomeChar!Char2)
{
    const(Char1)[] balance;
    if (cs == CaseSensitive.yes)
    {
        balance = std.algorithm.find(s, sub);
    }
    else
    {
        balance = std.algorithm.find!
            ((dchar a, dchar b){return std.uni.toLower(a) == std.uni.toLower(b);})
            (s, sub);
    }
    return balance.empty ? -1 : balance.ptr - s.ptr;
}

unittest
{
    debug(string) printf("string.indexOf.unittest\n");

    foreach(S; TypeTuple!(string, wstring, dstring))
    {
        foreach(T; TypeTuple!(string, wstring, dstring))
        {
            assert(indexOf(cast(S)null, to!T("a")) == -1);
            assert(indexOf(to!S("def"), to!T("a")) == -1);
            assert(indexOf(to!S("abba"), to!T("a")) == 0);
            assert(indexOf(to!S("def"), to!T("f")) == 2);
            assert(indexOf(to!S("dfefffg"), to!T("fff")) == 3);
            assert(indexOf(to!S("dfeffgfff"), to!T("fff")) == 6);

            assert(indexOf(to!S("dfeffgfff"), to!T("a"), CaseSensitive.no) == -1);
            assert(indexOf(to!S("def"), to!T("a"), CaseSensitive.no) == -1);
            assert(indexOf(to!S("abba"), to!T("a"), CaseSensitive.no) == 0);
            assert(indexOf(to!S("def"), to!T("f"), CaseSensitive.no) == 2);
            assert(indexOf(to!S("dfefffg"), to!T("fff"), CaseSensitive.no) == 3);
            assert(indexOf(to!S("dfeffgfff"), to!T("fff"), CaseSensitive.no) == 6);

            S sPlts = "Mars: the fourth Rock (Planet) from the Sun.";
            S sMars = "Who\'s \'My Favorite Maritian?\'";

            assert(indexOf(sMars, to!T("MY fAVe"), CaseSensitive.no) == -1);
            assert(indexOf(sMars, to!T("mY fAVOriTe"), CaseSensitive.no) == 7);
            assert(indexOf(sPlts, to!T("mArS:"), CaseSensitive.no) == 0);
            assert(indexOf(sPlts, to!T("rOcK"), CaseSensitive.no) == 17);
            assert(indexOf(sPlts, to!T("Un."), CaseSensitive.no) == 41);
            assert(indexOf(sPlts, to!T(sPlts), CaseSensitive.no) == 0);

            assert(indexOf("\u0100", to!T("\u0100"), CaseSensitive.no) == 0);

            // Thanks to Carlos Santander B. and zwang
            assert(indexOf("sus mejores cortesanos. Se embarcaron en el puerto de Dubai y",
                           to!T("page-break-before"), CaseSensitive.no) == -1);
        }

        foreach(cs; EnumMembers!CaseSensitive)
        {
            assert(indexOf("hello\U00010143\u0100\U00010143", to!S("\u0100"), cs) == 9);
            assert(indexOf("hello\U00010143\u0100\U00010143"w, to!S("\u0100"), cs) == 7);
            assert(indexOf("hello\U00010143\u0100\U00010143"d, to!S("\u0100"), cs) == 6);
        }
    }
}


/++
    Returns the index of the last occurence of $(D c) in $(D s). If $(D c)
    is not found, then $(D -1) is returned.

    $(D cs) indicates whether the comparisons are case sensitive.
  +/
sizediff_t lastIndexOf(Char)(const(Char)[] s,
                             dchar c,
                             CaseSensitive cs = CaseSensitive.yes)
    if(isSomeChar!Char)
{
    if(cs == CaseSensitive.yes)
    {
        if(cast(dchar)(cast(Char)c) == c)
        {
            for(auto i = s.length; i-- != 0;)
            {
                if(s[i] == c)
                    return cast(sizediff_t)i;
            }
        }
        else
        {
            for(size_t i = s.length; !s.empty;)
            {
                if(s.back == c)
                    return cast(sizediff_t)i - codeLength!Char(c);

                i -= strideBack(s, i);
                s = s[0 .. i];
            }
        }
    }
    else
    {
        if(std.ascii.isASCII(c))
        {
            immutable c1 = std.ascii.toLower(c);

            for(auto i = s.length; i-- != 0;)
            {
                immutable c2 = std.ascii.toLower(s[i]);
                if(c1 == c2)
                    return cast(sizediff_t)i;
            }
        }
        else
        {
            immutable c1 = std.uni.toLower(c);

            for(size_t i = s.length; !s.empty;)
            {
                if(std.uni.toLower(s.back) == c1)
                    return cast(sizediff_t)i - codeLength!Char(c);

                i -= strideBack(s, i);
                s = s[0 .. i];
            }
        }
    }

    return -1;
}

unittest
{
    debug(string) printf("string.lastIndexOf.unittest\n");

    foreach(S; TypeTuple!(string, wstring, dstring))
    {
        assert(lastIndexOf(cast(S) null, 'a') == -1);
        assert(lastIndexOf(to!S("def"), 'a') == -1);
        assert(lastIndexOf(to!S("abba"), 'a') == 3);
        assert(lastIndexOf(to!S("def"), 'f') == 2);

        assert(lastIndexOf(cast(S) null, 'a', CaseSensitive.no) == -1);
        assert(lastIndexOf(to!S("def"), 'a', CaseSensitive.no) == -1);
        assert(lastIndexOf(to!S("AbbA"), 'a', CaseSensitive.no) == 3);
        assert(lastIndexOf(to!S("def"), 'F', CaseSensitive.no) == 2);

        S sPlts = "Mars: the fourth Rock (Planet) from the Sun.";

        assert(lastIndexOf(to!S("def"), 'f', CaseSensitive.no) == 2);
        assert(lastIndexOf(sPlts, 'M', CaseSensitive.no) == 34);
        assert(lastIndexOf(sPlts, 'S', CaseSensitive.no) == 40);
    }

    foreach(cs; EnumMembers!CaseSensitive)
    {
        assert(lastIndexOf("\U00010143\u0100\U00010143hello", '\u0100', cs) == 4);
        assert(lastIndexOf("\U00010143\u0100\U00010143hello"w, '\u0100', cs) == 2);
        assert(lastIndexOf("\U00010143\u0100\U00010143hello"d, '\u0100', cs) == 1);
    }
}

/++
    Returns the index of the last occurence of $(D sub) in $(D s). If $(D sub)
    is not found, then $(D -1) is returned.

    $(D cs) indicates whether the comparisons are case sensitive.
  +/
sizediff_t lastIndexOf(Char1, Char2)(const(Char1)[] s,
                                     const(Char2)[] sub,
                                     CaseSensitive cs = CaseSensitive.yes)
    if(isSomeChar!Char1 && isSomeChar!Char2)
{
    if(sub.empty)
        return s.length;

    if(walkLength(sub) == 1)
        return lastIndexOf(s, sub.front, cs);

    if(cs == CaseSensitive.yes)
    {
        static if(is(Unqual!Char1 == Unqual!Char2))
        {
            immutable c = sub[0];

            for(sizediff_t i = s.length - sub.length; i >= 0; --i)
            {
                if(s[i] == c && memcmp(&s[i + 1], &sub[1], sub.length - 1) == 0)
                    return i;
            }
        }
        else
        {
            for(size_t i = s.length; !s.empty;)
            {
                if(s.endsWith(sub))
                    return cast(sizediff_t)i - to!(const(Char1)[])(sub).length;

                i -= strideBack(s, i);
                s = s[0 .. i];
            }
        }
    }
    else
    {
        for(size_t i = s.length; !s.empty;)
        {
            if(endsWith!((dchar a, dchar b) {return std.uni.toLower(a) == std.uni.toLower(b);})
                        (s, sub))
            {
                return cast(sizediff_t)i - to!(const(Char1)[])(sub).length;
            }

            i -= strideBack(s, i);
            s = s[0 .. i];
        }
    }

    return -1;
}

unittest
{
    debug(string) printf("string.lastIndexOf.unittest\n");

    foreach(S; TypeTuple!(string, wstring, dstring))
    {
        foreach(T; TypeTuple!(string, wstring, dstring))
        {
            enum typeStr = S.stringof ~ " " ~ T.stringof;

            assert(lastIndexOf(cast(S)null, to!T("a")) == -1, typeStr);
            assert(lastIndexOf(to!S("abcdefcdef"), to!T("c")) == 6, typeStr);
            assert(lastIndexOf(to!S("abcdefcdef"), to!T("cd")) == 6, typeStr);
            assert(lastIndexOf(to!S("abcdefcdef"), to!T("ef")) == 8, typeStr);
            assert(lastIndexOf(to!S("abcdefCdef"), to!T("c")) == 2, typeStr);
            assert(lastIndexOf(to!S("abcdefCdef"), to!T("cd")) == 2, typeStr);
            assert(lastIndexOf(to!S("abcdefcdef"), to!T("x")) == -1, typeStr);
            assert(lastIndexOf(to!S("abcdefcdef"), to!T("xy")) == -1, typeStr);
            assert(lastIndexOf(to!S("abcdefcdef"), to!T("")) == 10, typeStr);

            assert(lastIndexOf(cast(S)null, to!T("a"), CaseSensitive.no) == -1, typeStr);
            assert(lastIndexOf(to!S("abcdefCdef"), to!T("c"), CaseSensitive.no) == 6, typeStr);
            assert(lastIndexOf(to!S("abcdefCdef"), to!T("cD"), CaseSensitive.no) == 6, typeStr);
            assert(lastIndexOf(to!S("abcdefcdef"), to!T("x"), CaseSensitive.no) == -1, typeStr);
            assert(lastIndexOf(to!S("abcdefcdef"), to!T("xy"), CaseSensitive.no) == -1, typeStr);
            assert(lastIndexOf(to!S("abcdefcdef"), to!T(""), CaseSensitive.no) == 10, typeStr);

            assert(lastIndexOf(to!S("abcdefcdef"), to!T("c"), CaseSensitive.no) == 6, typeStr);
            assert(lastIndexOf(to!S("abcdefcdef"), to!T("cd"), CaseSensitive.no) == 6, typeStr);
            assert(lastIndexOf(to!S("abcdefcdef"), to!T("def"), CaseSensitive.no) == 7, typeStr);

            S sPlts = "Mars: the fourth Rock (Planet) from the Sun.";
            S sMars = "Who\'s \'My Favorite Maritian?\'";

            assert(lastIndexOf(sMars, to!T("RiTE maR"), CaseSensitive.no) == 14, typeStr);
            assert(lastIndexOf(sPlts, to!T("FOuRTh"), CaseSensitive.no) == 10, typeStr);
            assert(lastIndexOf(sMars, to!T("whO\'s \'MY"), CaseSensitive.no) == 0, typeStr);
            assert(lastIndexOf(sMars, to!T(sMars), CaseSensitive.no) == 0, typeStr);
        }

        foreach(cs; EnumMembers!CaseSensitive)
        {
            enum csString = to!string(cs);

            assert(lastIndexOf("\U00010143\u0100\U00010143hello", to!S("\u0100"), cs) == 4, csString);
            assert(lastIndexOf("\U00010143\u0100\U00010143hello"w, to!S("\u0100"), cs) == 2, csString);
            assert(lastIndexOf("\U00010143\u0100\U00010143hello"d, to!S("\u0100"), cs) == 1, csString);
        }
    }
}


/**
 * Returns the representation type of a string, which is the same type
 * as the string except the character type is replaced by $(D ubyte),
 * $(D ushort), or $(D uint) depending on the character width.
 *
 * Example:
----
string s = "hello";
static assert(is(typeof(representation(s)) == immutable(ubyte)[]));
----
 */
auto representation(Char)(Char[] s) pure nothrow
    if(isSomeChar!Char)
{
    // Get representation type
    static if (Char.sizeof == 1) enum t = "ubyte";
    else static if (Char.sizeof == 2) enum t = "ushort";
    else static if (Char.sizeof == 4) enum t = "uint";
    else static assert(false); // can't happen due to isSomeChar!Char

    // Get representation qualifier
    static if (is(Char == immutable)) enum q = "immutable";
    else static if (is(Char == const)) enum q = "const";
    else static if (is(Char == shared)) enum q = "shared";
    else enum q = "";

    // Result type is qualifier(RepType)[]
    static if (q.length)
        return mixin("cast(" ~ q ~ "(" ~ t ~ ")[]) s");
    else
        return mixin("cast(" ~ t ~ "[]) s");
}

unittest
{
    auto c = to!(char[])("hello");
    static assert(is(typeof(representation(c)) == ubyte[]));

    auto w = to!(wchar[])("hello");
    static assert(is(typeof(representation(w)) == ushort[]));

    auto d = to!(dchar[])("hello");
    static assert(is(typeof(representation(d)) == uint[]));

    const(char[]) cc = "hello";
    static assert(is(typeof(representation(cc)) == const(ubyte)[]));

    const(wchar[]) cw = "hello"w;
    static assert(is(typeof(representation(cw)) == const(ushort)[]));

    const(dchar[]) cd = "hello"d;
    static assert(is(typeof(representation(cd)) == const(uint)[]));

    string s = "hello";
    static assert(is(typeof(representation(s)) == immutable(ubyte)[]));

    wstring iw = "hello"w;
    static assert(is(typeof(representation(iw)) == immutable(ushort)[]));

    dstring id = "hello"d;
    static assert(is(typeof(representation(id)) == immutable(uint)[]));
}


/************************************
 * $(RED Scheduled for deprecation in January 2012.
 *       Please use $(D toLower) instead.)
 *
 * Convert string s[] to lower case.
 */
S tolower(S)(S s) if (isSomeString!S)
{
    return toLower!S(s);
}

/++
    Returns a string which is identical to $(D s) except that all of its
    characters are lowercase (in unicode, not just ASCII). If $(D s) does not
    have any uppercase characters, then $(D s) is returned.
  +/
S toLower(S)(S s) @trusted pure
    if(isSomeString!S)
{
    foreach (i, dchar cOuter; s)
    {
        if (!std.uni.isUpper(cOuter)) continue;
        auto result = s[0.. i].dup;
        foreach (dchar c; s[i .. $])
        {
            if (std.uni.isUpper(c))
            {
                c = std.uni.toLower(c);
            }
            result ~= c;
        }
        return cast(S) result;
    }
    return s;
}

unittest
{
    debug(string) printf("string.toLower.unittest\n");

    foreach(S; TypeTuple!(string, wstring, dstring, char[], wchar[], dchar[]))
    {
        S s = cast(S)"hello world\u0101";
        assert(toLower(s) is s);
        const S sc = "hello world\u0101";
        assert(toLower(sc) is sc);
        immutable S si = "hello world\u0101";
        assert(toLower(si) is si);

        S t = cast(S)"Hello World\u0100";
        assert(toLower(t) == s);
        const S tc = "hello world\u0101";
        assert(toLower(tc) == s);
        immutable S ti = "hello world\u0101";
        assert(toLower(ti) == s);
    }
}

/**
   $(RED Scheduled for deprecation in January 2012.
         Please use $(D toLowerInPlace) instead.)

   Converts $(D s) to lowercase in place.
 */
void tolowerInPlace(C)(ref C[] s) if (isSomeChar!C)
{
    toLowerInPlace!C(s);
}

/++
    Converts $(D s) to lowercase (in unicode, not just ASCII) in place.
    If $(D s) does not have any uppercase characters, then $(D s) is unaltered.
 +/
void toLowerInPlace(C)(ref C[] s)
    if(is(C == char) || is(C == wchar))
{
    for (size_t i = 0; i < s.length; )
    {
        immutable c = s[i];
        if (std.ascii.isUpper(c))
        {
            s[i++] = cast(C) (c + (cast(C)'a' - 'A'));
        }
        else if (!std.ascii.isASCII(c))
        {
            // wide character
            size_t j = i;
            dchar dc = decode(s, j);
            assert(j > i);
            if (!std.uni.isUpper(dc))
            {
                i = j;
                continue;
            }
            auto toAdd = to!(C[])(std.uni.toLower(dc));
            s = s[0 .. i] ~ toAdd  ~ s[j .. $];
            i += toAdd.length;
        }
        else
        {
            ++i;
        }
    }
}

void toLowerInPlace(C)(ref C[] s) @safe pure nothrow
    if(is(C == dchar))
{
    foreach(ref c; s)
    {
        if(std.uni.isUpper(c))
            c = std.uni.toLower(c);
    }
}

unittest
{
    debug(string) printf("string.toLowerInPlace.unittest\n");

    foreach(S; TypeTuple!(char[], wchar[], dchar[]))
    {
        S s = to!S("hello world\u0101");
        toLowerInPlace(s);
        assert(s == "hello world\u0101");

        S t = to!S("Hello World\u0100");
        toLowerInPlace(t);
        assert(t == "hello world\u0101");
    }
}

unittest
{
    debug(string) printf("string.toLower/toLowerInPlace.unittest\n");

    string s1 = "FoL";
    string s2 = toLower(s1);
    assert(cmp(s2, "fol") == 0, s2);
    assert(s2 != s1);

    char[] s3 = s1.dup;
    toLowerInPlace(s3);
    assert(s3 == s2, s3);

    s1 = "A\u0100B\u0101d";
    s2 = toLower(s1);
    s3 = s1.dup;
    assert(cmp(s2, "a\u0101b\u0101d") == 0);
    assert(s2 !is s1);
    toLowerInPlace(s3);
    assert(s3 == s2, s3);

    s1 = "A\u0460B\u0461d";
    s2 = toLower(s1);
    s3 = s1.dup;
    assert(cmp(s2, "a\u0461b\u0461d") == 0);
    assert(s2 !is s1);
    toLowerInPlace(s3);
    assert(s3 == s2, s3);

    s1 = "\u0130";
    s2 = toLower(s1);
    s3 = s1.dup;
    assert(s2 == "i");
    assert(s2 !is s1);
    toLowerInPlace(s3);
    assert(s3 == s2, s3);

    // Test on wchar and dchar strings.
    assert(toLower("Some String"w) == "some string"w);
    assert(toLower("Some String"d) == "some string"d);
}

/************************************
 * $(RED Scheduled for deprecation in January 2012.
 *       Please use $(D toUpper) instead.)
 *
 * Convert string s[] to upper case.
 */
S toupper(S)(S s) if (isSomeString!S)
{
    return toUpper!S(s);
}

/++
    Returns a string which is identical to $(D s) except that all of its
    characters are uppercase (in unicode, not just ASCII). If $(D s) does not
    have any lowercase characters, then $(D s) is returned.
  +/
S toUpper(S)(S s) @trusted pure
    if(isSomeString!S)
{
    foreach (i, dchar cOuter; s)
    {
        if (!std.uni.isLower(cOuter)) continue;
        auto result = s[0.. i].dup;
        foreach (dchar c; s[i .. $])
        {
            if (std.uni.isLower(c))
            {
                c = std.uni.toUpper(c);
            }
            result ~= c;
        }
        return cast(S) result;
    }
    return s;
}

unittest
{
    debug(string) printf("string.toUpper.unittest\n");

    foreach(S; TypeTuple!(string, wstring, dstring, char[], wchar[], dchar[]))
    {
        S s = cast(S)"HELLO WORLD\u0100";
        assert(toUpper(s) is s);
        const S sc = "HELLO WORLD\u0100";
        assert(toUpper(sc) is sc);
        immutable S si = "HELLO WORLD\u0100";
        assert(toUpper(si) is si);

        S t = cast(S)"hello world\u0101";
        assert(toUpper(t) == s);
        const S tc = "HELLO WORLD\u0100";
        assert(toUpper(tc) == s);
        immutable S ti = "HELLO WORLD\u0100";
        assert(toUpper(ti) == s);
    }
}

/**
    $(RED Scheduled for deprecation in January 2012.
          Please use $(D toUpperInPlace) instead.)

   Converts $(D s) to uppercase in place.
 */
void toupperInPlace(C)(ref C[] s) if (isSomeChar!C)
{
    toUpperInPlace!C(s);
}

/++
    Converts $(D s) to uppercase (in unicode, not just ASCII) in place.
    If $(D s) does not have any lowercase characters, then $(D s) is unaltered.
 +/
void toUpperInPlace(C)(ref C[] s)
    if(isSomeChar!C &&
       (is(C == char) || is(C == wchar)))
{
    for (size_t i = 0; i < s.length; )
    {
        immutable c = s[i];
        if ('a' <= c && c <= 'z')
        {
            s[i++] = cast(C) (c - (cast(C)'a' - 'A'));
        }
        else if (!std.ascii.isASCII(c))
        {
            // wide character
            size_t j = i;
            dchar dc = decode(s, j);
            assert(j > i);
            if (!std.uni.isLower(dc))
            {
                i = j;
                continue;
            }
            auto toAdd = to!(C[])(std.uni.toUpper(dc));
            s = s[0 .. i] ~ toAdd  ~ s[j .. $];
            i += toAdd.length;
        }
        else
        {
            ++i;
        }
    }
}

void toUpperInPlace(C)(ref C[] s) @safe pure nothrow
    if(is(C == dchar))
{
    foreach(ref c; s)
    {
        if(std.uni.isLower(c))
            c = std.uni.toUpper(c);
    }
}

unittest
{
    debug(string) printf("string.toUpperInPlace.unittest\n");

    foreach(S; TypeTuple!(char[], wchar[], dchar[]))
    {
        S s = to!S("HELLO WORLD\u0100");
        toUpperInPlace(s);
        assert(s == "HELLO WORLD\u0100");

        S t = to!S("Hello World\u0101");
        toUpperInPlace(t);
        assert(t == "HELLO WORLD\u0100");
    }
}

unittest
{
    debug(string) printf("string.toUpper/toUpperInPlace.unittest\n");

    string s1 = "FoL";
    string s2;
    char[] s3;

    s2 = toUpper(s1);
    s3 = s1.dup; toUpperInPlace(s3);
    assert(s3 == s2, s3);
    assert(cmp(s2, "FOL") == 0);
    assert(s2 !is s1);

    s1 = "a\u0100B\u0101d";
    s2 = toUpper(s1);
    s3 = s1.dup; toUpperInPlace(s3);
    assert(s3 == s2);
    assert(cmp(s2, "A\u0100B\u0100D") == 0);
    assert(s2 !is s1);

    s1 = "a\u0460B\u0461d";
    s2 = toUpper(s1);
    s3 = s1.dup; toUpperInPlace(s3);
    assert(s3 == s2);
    assert(cmp(s2, "A\u0460B\u0460D") == 0);
    assert(s2 !is s1);
}


/++
    Capitalize the first character of $(D s) and conver the rest of $(D s)
    to lowercase.
 +/
S capitalize(S)(S s) @trusted pure
    if(isSomeString!S)
{
    Unqual!(typeof(s[0]))[] retval;
    bool changed = false;

    foreach(i, dchar c; s)
    {
        dchar c2;

        if(i == 0)
        {
            c2 = std.uni.toUpper(c);
            if(c != c2)
                changed = true;
        }
        else
        {
            c2 = std.uni.toLower(c);
            if(c != c2)
            {
                if(!changed)
                {
                    changed = true;
                    retval = s[0 .. i].dup;
                }
            }
        }

        if(changed)
            std.utf.encode(retval, c2);
    }

    return changed ? cast(S)retval : s;
}

unittest
{
    debug(string) printf("string.capitalize.unittest\n");

    foreach (S; TypeTuple!(string, wstring, dstring, char[], wchar[], dchar[]))
    {
        S s1 = to!S("FoL");
        S s2;

        s2 = capitalize(s1);
        assert(cmp(s2, "Fol") == 0);
        assert(s2 !is s1);

        s2 = capitalize(s1[0 .. 2]);
        assert(cmp(s2, "Fo") == 0);
        assert(s2.ptr == s1.ptr);

        s1 = to!S("fOl");
        s2 = capitalize(s1);
        assert(cmp(s2, "Fol") == 0);
        assert(s2 !is s1);

        s1 = to!S("\u0131 \u0130");
        s2 = capitalize(s1);
        assert(cmp(s2, "\u0049 \u0069") == 0);
        assert(s2 !is s1);

        s1 = to!S("\u017F \u0049");
        s2 = capitalize(s1);
        assert(cmp(s2, "\u0053 \u0069") == 0);
        assert(s2 !is s1);
    }
}


/********************************************
 *  $(RED Scheduled for deprecation in January 2012.)
 *
 * Capitalize all words in string s[].
 * Remove leading and trailing whitespace.
 * Replace all sequences of whitespace with a single space.
 */
S capwords(S)(S s) if (isSomeString!S)
{
    return _capWords!S(s);
}

// This is purely so that capwords can be unit tested without spitting
// out the deprecation message.
private S _capWords(S)(S s) if (isSomeString!S)
{
    alias typeof(s[0]) C;
    auto retval = appender!(C[])();
    bool inWord = false;
    size_t wordStart = 0;

    foreach(i, dchar c; s)
    {
        if(std.uni.isWhite(s[i]))
        {
            if(inWord)
            {
                retval.put(capitalize(s[wordStart .. i]));
                inWord = false;
            }
        }
        else if(!inWord)
        {
            if(!retval.data.empty)
                retval.put(' ');

            wordStart = i;
            inWord = true;
        }
    }

    if(inWord)
        retval.put(capitalize(s[wordStart .. $]));

    return cast(S)retval.data;
}

unittest
{
    debug(string) printf("string.capwords.unittest\n");

    foreach (S; TypeTuple!(string, wstring, dstring, char[], wchar[], dchar[]))
    {
        auto s1 = to!S("\tfoo abc(aD)*  \t  (q PTT  ");
        S s2;

        s2 = _capWords(s1);
        assert(cmp(s2, "Foo Abc(ad)* (q Ptt") == 0);

        s1 = to!S("\u0430\u0411\u0544 \uFF48elLO\u00A0\u0131\u0053\u0049\u017F " ~
                  "\u017F\u0053\u0131\u0130");
        s2 = _capWords(s1);
        assert(cmp(s2, "\u0410\u0431\u0574 \uFF28ello\u00A0\u0049\u0073\u0069\u017F " ~
                       "\u0053\u0053\u0131\u0069"));
    }
}


/********************************************
 * $(RED Deprecated. It will be removed in February 2012.
 *        Please use $(XREF array, replicate) instead.)
 *
 * Repeat $(D s) for $(D n) times.
 */
deprecated S repeat(S)(S s, size_t n)
{
    pragma(msg, hardDeprec!("2.055", "February 2012", "repeat", "std.array.replicate"));
    return std.array.replicate(s, n);
}


/**************************************
 * $(RED Scheduled for deprecation in January 2012.
 *       Please use $(LREF, splitLines) instead.)
 *
 * Split s[] into an array of lines,
 * using CR, LF, or CR-LF as the delimiter.
 * The delimiter is not included in the line.
 */
S[] splitlines(S)(S s)
{
    return splitLines!S(s);
}

/++
    Split $(D s) into an array of lines using $(D '\r'), $(D '\n'),
    $(D "\r\n"), $(XREF uni, lineSep), and $(XREF uni, paraSep) as delimiters.
    If $(D keepTerm) is set to $(D KeepTerminator.yes), then the delimiter
    is included in the strings returned.
  +/
enum KeepTerminator : bool { no, yes }
/// ditto
S[] splitLines(S)(S s, KeepTerminator keepTerm = KeepTerminator.no)
    if(isSomeString!S)
{
    size_t iStart = 0;
    size_t nextI = 0;
    auto retval = appender!(S[])();

    for(size_t i; i < s.length; i = nextI)
    {
        immutable c = decode(s, nextI);

        if(c == '\r' || c == '\n' || c == lineSep || c == paraSep)
        {
            immutable isWinEOL = c == '\r' && i + 1 < s.length && s[i + 1] == '\n';
            auto iEnd = i;

            if(keepTerm == KeepTerminator.yes)
            {
                iEnd = isWinEOL? nextI + 1 : nextI;
            }

            retval.put(s[iStart .. iEnd]);
            iStart = nextI;

            if(isWinEOL)
            {
                ++nextI;
                ++iStart;
            }
        }
    }

    if(iStart != nextI)
        retval.put(s[iStart .. $]);

    return retval.data;
}

unittest
{
    debug(string) printf("string.splitLines.unittest\n");

    foreach (S; TypeTuple!(char[], wchar[], dchar[], string, wstring, dstring))
    {
        auto s = to!S("\rpeter\n\rpaul\r\njerry\u2028ice\u2029cream\n\nsunday\n");

        auto lines = splitLines(s);
        assert(lines.length == 9);
        assert(lines[0] == "");
        assert(lines[1] == "peter");
        assert(lines[2] == "");
        assert(lines[3] == "paul");
        assert(lines[4] == "jerry");
        assert(lines[5] == "ice");
        assert(lines[6] == "cream");
        assert(lines[7] == "");
        assert(lines[8] == "sunday");

        lines = splitLines(s, KeepTerminator.yes);
        assert(lines.length == 9);
        assert(lines[0] == "\r");
        assert(lines[1] == "peter\n");
        assert(lines[2] == "\r");
        assert(lines[3] == "paul\r\n");
        assert(lines[4] == "jerry\u2028");
        assert(lines[5] == "ice\u2029");
        assert(lines[6] == "cream\n");
        assert(lines[7] == "\n");
        assert(lines[8] == "sunday\n");

        s.popBack(); // Lop-off trailing \n
        lines = splitLines(s);
        assert(lines.length == 9);
        assert(lines[8] == "sunday");

        lines = splitLines(s, KeepTerminator.yes);
        assert(lines.length == 9);
        assert(lines[8] == "sunday");
    }
}


/*****************************************
 *  $(RED Scheduled for deprecation in January 2012.
 *        Please use $(D stripLeft) instead.)
 *
 * Strips leading whitespace.
 */
String stripl(String)(String s)
{
    return stripLeft!String(s);
}

/++
    Strips leading whitespace.
  +/
S stripLeft(S)(S s) @safe pure
    if(isSomeString!S)
{
    bool foundIt;
    size_t nonWhite;
    foreach(i, dchar c; s)
    {
        if(!std.uni.isWhite(c))
        {
            foundIt = true;
            nonWhite = i;
            break;
        }
    }

    if(foundIt)
        return s[nonWhite .. $];

    return s[0 .. 0]; //Empty string with correct type.
}

/*****************************************
 *  $(RED Scheduled for deprecation in January 2012.
 *        Please use $(D stripRight) instead.)
 *
 * Strips trailing whitespace.
 */
String stripr(String)(String s)
{
    return stripRight!String(s);
}

/++
    Strips trailing whitespace.
  +/
S stripRight(S)(S s)
    if(isSomeString!S)
{
    alias typeof(s[0]) C;
    size_t codeLen;
    foreach(dchar c; retro(s))
    {
        if(std.uni.isWhite(c))
            codeLen += codeLength!C(c);
        else
            break;
    }

    return s[0 .. $ - codeLen];
}

/++
    Strips both leading and trailing whitespace.
  +/
S strip(S)(S s)
    if(isSomeString!S)
{
    return stripRight(stripLeft(s));
}

unittest
{
    debug(string) printf("string.strip.unittest\n");

    assert(stripLeft("  foo\t ") == "foo\t ");
    assert(stripLeft("\u2008  foo\t \u2007") == "foo\t \u2007");
    assert(stripLeft("1") == "1");

    assert(stripRight("  foo\t ") == "  foo");
    assert(stripRight("\u2008  foo\t \u2007") == "\u2008  foo");
    assert(stripRight("1") == "1");

    assert(strip("  foo\t ") == "foo");
    assert(strip("\u2008  foo\t \u2007") == "foo");
    assert(strip("1") == "1");
}


/++
    Returns $(D s) sans the trailing $(D delimiter), if any. If no $(D delimiter)
    is given, then any trailing  $(D '\r'), $(D '\n'), $(D "\r\n"),
    $(XREF uni, lineSep), or $(XREF uni, paraSep)s are removed.
  +/
S chomp(S)(S s)
    if(isSomeString!S)
{
    if(s.empty)
        return s;

    switch(s.back)
    {
        case '\n':
        {
            s.popBack();

            if(!s.empty && s.back == '\r')
                s.popBack();

            break;
        }
        case '\r':
        case lineSep:
        case paraSep:
        {
            s.popBack();
            break;
        }
        default:
            break;
    }

    return s;
}

/// Ditto
S chomp(S, C)(S s, const(C)[] delimiter)
    if(isSomeString!S && isSomeString!(C[]))
{
    if(delimiter.empty)
        return chomp(s);
    else if(endsWith(s, delimiter))
    {
        static if(is(Unqual!(typeof(s[0])) == Unqual!C))
            return s[0 .. $ - delimiter.length];
        else
            return s[0 .. $ - to!S(delimiter).length];
    }

    return s;
}

unittest
{
    debug(string) printf("string.chomp.unittest\n");
    string s;

    foreach(S; TypeTuple!(char[], wchar[], dchar[], string, wstring, dstring))
    {
        // @@@ BUG IN COMPILER, MUST INSERT CAST
        assert(chomp(cast(S)null) is null);
        assert(chomp(to!S("hello")) == "hello");
        assert(chomp(to!S("hello\n")) == "hello");
        assert(chomp(to!S("hello\r")) == "hello");
        assert(chomp(to!S("hello\r\n")) == "hello");
        assert(chomp(to!S("hello\n\r")) == "hello\n");
        assert(chomp(to!S("hello\n\n")) == "hello\n");
        assert(chomp(to!S("hello\r\r")) == "hello\r");
        assert(chomp(to!S("hello\nxxx\n")) == "hello\nxxx");
        assert(chomp(to!S("hello\u2028")) == "hello");
        assert(chomp(to!S("hello\u2029")) == "hello");
        assert(chomp(to!S("hello\u2028\u2028")) == "hello\u2028");
        assert(chomp(to!S("hello\u2029\u2029")) == "hello\u2029");

        foreach(T; TypeTuple!(char[], wchar[], dchar[], string, wstring, dstring))
        {
            // @@@ BUG IN COMPILER, MUST INSERT CAST
            assert(chomp(cast(S)null, cast(T)null) is null);
            assert(chomp("hello\n", cast(T)null) == "hello");
            assert(chomp(to!S("hello"), to!T("o")) == "hell");
            assert(chomp(to!S("hello"), to!T("p")) == "hello");
            // @@@ BUG IN COMPILER, MUST INSERT CAST
            assert(chomp(to!S("hello"), cast(T) null) == "hello");
            assert(chomp(to!S("hello"), to!T("llo")) == "he");
            assert(chomp(to!S("\uFF28ello"), to!T("llo")) == "\uFF28e");
            assert(chomp(to!S("\uFF28el\uFF4co"), to!T("l\uFF4co")) == "\uFF28e");
        }
    }
}


/++
    If $(D longer.startsWith(shorter)), returns $(D longer[shorter.length .. $]).
    Otherwise, returns $(D longer).
 +/
C1[] chompPrefix(C1, C2)(C1[] longer, C2[] shorter)
    if(isSomeString!(C1[]) && isSomeString!(C2[]))
{
    return startsWith(longer, shorter) ? longer[shorter.length .. $] : longer;
}

unittest
{
    assert(chompPrefix("abcdefgh", "abcde") == "fgh");
    assert(chompPrefix("abcde", "abcdefgh") == "abcde");
    assert(chompPrefix("\uFF28el\uFF4co", "\uFF28el\uFF4co") == "");
    assert(chompPrefix("\uFF28el\uFF4co", "\uFF28el") == "\uFF4co");
    assert(chompPrefix("\uFF28el", "\uFF28el\uFF4co") == "\uFF28el");
}


/++
    Returns $(D s) sans its last character, if there is one.
    If $(D s) ends in "\r\n", then both are removed.
 +/
S chop(S)(S s) if (isSomeString!S)
{
    auto len = s.length;
    if (!len) return s;
    if (len >= 2 && s[len - 1] == '\n' && s[len - 2] == '\r')
        return s[0 .. len - 2];
    s.popBack();
    return s;
}

unittest
{
    debug(string) printf("string.chop.unittest\n");

    assert(chop(cast(string) null) is null);
    assert(chop("hello") == "hell");
    assert(chop("hello\r\n") == "hello");
    assert(chop("hello\n\r") == "hello\n");
}


/*******************************************
 *  $(RED Scheduled for deprecation in January 2012.
 *        Please use $(D leftJustify) instead.)
 *
 * Left justify string s[] in field width chars wide.
 */
S ljustify(S)(S s, size_t width) if (isSomeString!S)
{
    return leftJustify!S(s, width);
}

/++
    Left justify $(D s) in a field $(D width) characters wide. $(D fillChar)
    is the character that will be used to fill up the space in the field that
    $(D s) doesn't fill.
  +/
S leftJustify(S)(S s, size_t width, dchar fillChar = ' ') @trusted
    if(isSomeString!S)
{
    alias typeof(S[0]) C;

    if(cast(dchar)(cast(C)fillChar) == fillChar)
    {
        immutable len = s.walkLength();
        if(len >= width)
            return s;

        auto retval = new Unqual!(C)[width - len + s.length];
        retval[0 .. s.length] = s[];
        retval[s.length .. $] = cast(C)fillChar;
        return cast(S)retval;
    }
    else
    {
        auto dstr = to!dstring(s);
        if(dstr.length >= width)
            return s;

        auto retval = new dchar[](width);
        retval[0 .. dstr.length] = dstr[];
        retval[dstr.length .. $] = fillChar;
        return to!S(retval);
    }
}


/*******************************************
 *  $(RED Scheduled for deprecation in January 2012.
 *        Please use $(D rightJustify) instead.)
 *
 * Left right string s[] in field width chars wide.
 */
S rjustify(S)(S s, size_t width) if (isSomeString!S)
{
    return rightJustify!S(s, width);
}

/++
    Right justify $(D s) in a field $(D width) characters wide. $(D fillChar)
    is the character that will be used to fill up the space in the field that
    $(D s) doesn't fill.
  +/
S rightJustify(S)(S s, size_t width, dchar fillChar = ' ') @trusted
    if(isSomeString!S)
{
    alias typeof(S[0]) C;

    if(cast(dchar)(cast(C)fillChar) == fillChar)
    {
        immutable len = s.walkLength();
        if(len >= width)
            return s;

        auto retval = new Unqual!(C)[width - len + s.length];
        retval[0 .. $ - s.length] = cast(C)fillChar;
        retval[$ - s.length .. $] = s[];
        return cast(S)retval;
    }
    else
    {
        auto dstr = to!dstring(s);
        if(dstr.length >= width)
            return s;

        auto retval = new dchar[](width);
        retval[0 .. $ - dstr.length] = fillChar;
        retval[$ - dstr.length .. $] = dstr[];
        return to!S(retval);
    }
}


/++
    Center $(D s) in a field $(D width) characters wide. $(D fillChar)
    is the character that will be used to fill up the space in the field that
    $(D s) doesn't fill.
  +/
S center(S)(S s, size_t width, dchar fillChar = ' ') @trusted
    if(isSomeString!S)
{
    alias typeof(S[0]) C;

    if(cast(dchar)(cast(C)fillChar) == fillChar)
    {
        immutable len = s.walkLength();
        if(len >= width)
            return s;

        auto retval = new Unqual!(C)[width - len + s.length];
        immutable left = (retval.length - s.length) / 2;
        retval[0 .. left] = cast(C)fillChar;
        retval[left .. left + s.length] = s[];
        retval[left + s.length .. $] = cast(C)fillChar;
        return to!S(retval);
    }
    else
    {
        auto dstr = to!dstring(s);
        if(dstr.length >= width)
            return s;

        auto retval = new dchar[](width);
        immutable left = (retval.length - dstr.length) / 2;
        retval[0 .. left] = fillChar;
        retval[left .. left + dstr.length] = dstr[];
        retval[left + dstr.length .. $] = fillChar;
        return to!S(retval);
    }
}

unittest
{
    debug(string) printf("string.justify.unittest\n");

    foreach(S; TypeTuple!(char[], wchar[], dchar[], string, wstring, dstring))
    {
        S s = to!S("hello");

        assert(leftJustify(s, 2) == "hello");
        assert(rightJustify(s, 2) == "hello");
        assert(center(s, 2) == "hello");

        assert(leftJustify(s, 7) == "hello  ");
        assert(rightJustify(s, 7) == "  hello");
        assert(center(s, 7) == " hello ");

        assert(leftJustify(s, 8) == "hello   ");
        assert(rightJustify(s, 8) == "   hello");
        assert(center(s, 8) == " hello  ");

        assert(leftJustify(s, 8, '\u0100') == "hello\u0100\u0100\u0100");
        assert(rightJustify(s, 8, '\u0100') == "\u0100\u0100\u0100hello");
        assert(center(s, 8, '\u0100') == "\u0100hello\u0100\u0100");
    }
}


/*****************************************
 * $(RED Scheduled for deprecation in January 2012.
 *       Please use $(D rightJustify) with a fill character of '0' instead.)
 *
 * Same as rjustify(), but fill with '0's.
 *
 */
S zfill(S)(S s, int width) if (isSomeString!S)
{
    return rightJustify!S(s, width, '0');
}


/**********************************************
 * $(RED Deprecated. It will be removed in February 2012.
 *       Please use $(XREF array, insertInPlace) instead.)
 *
 * Insert sub[] into s[] at location index.
 */
deprecated S insert(S)(S s, size_t index, S sub)
in
{
    assert(0 <= index && index <= s.length);
}
body
{
    std.array.insertInPlace(s, index, sub);
    return s;
}


/************************************************
 * $(RED Scheduled for deprecation in January 2012.
 *       Please use $(D detab) instead.)
 *
 * Replace tabs with the appropriate number of spaces.
 * tabsize is the distance between tab stops.
 */
S expandtabs(S)(S str, size_t tabsize = 8) if (isSomeString!S)
{
    return detab!S(str, tabsize);
}

/++
    Replace each tab character in $(D s) with the number of spaces necessary
    to align the following character at the next tab stop where $(D tabSize)
    is the distance between tab stops.
  +/
S detab(S)(S s, size_t tabSize = 8) @trusted pure
    if(isSomeString!S)
{
    assert(tabSize > 0);
    alias Unqual!(typeof(s[0])) C;
    bool changes = false;
    C[] result;
    int column;
    size_t nspaces;

    foreach (size_t i, dchar c; s)
    {
        switch (c)
        {
        case '\t':
            nspaces = tabSize - (column % tabSize);
            if (!changes)
            {
                changes = true;
                result = null;
                result.length = s.length + nspaces - 1;
                result.length = i + nspaces;
                result[0 .. i] = s[0 .. i];
                result[i .. i + nspaces] = ' ';
            }
            else
            {
                sizediff_t j = result.length;
                result.length = j + nspaces;
                result[j .. j + nspaces] = ' ';
            }
            column += nspaces;
            break;

        case '\r':
        case '\n':
        case paraSep:
        case lineSep:
            column = 0;
            goto L1;

        default:
            column++;
        L1:
            if (changes)
            {
                if (cast(dchar)(cast(C)c) == c)
                    result ~= cast(C)c;
                else
                    std.utf.encode(result, c);
            }
            break;
        }
    }

    return changes ? cast(S) result : s;
}

unittest
{
    debug(string) printf("string.detab.unittest\n");

    foreach (S; TypeTuple!(char[], wchar[], dchar[], string, wstring, dstring))
    {
        S s = to!S("This \tis\t a fofof\tof list");
        assert(cmp(detab(s), "This    is       a fofof        of list") == 0);

        assert(detab(cast(S)null) is null);
        assert(detab("").empty);
        assert(detab("a") == "a");
        assert(detab("\t") == "        ");
        assert(detab("\t", 3) == "   ");
        assert(detab("\t", 9) == "         ");
        assert(detab(  "  ab\t asdf ") == "  ab     asdf ");
        assert(detab(  "  \U00010000b\tasdf ") == "  \U00010000b    asdf ");
    }
}


/++
    Replaces spaces in $(D s) with the optimal number of tabs.
    All spaces and tabs at the end of a line are removed.

    Params:
        s       = String to convert.
        tabSize = Tab columns are $(D tabSize) spaces apart.
 +/
S entab(S)(S s, size_t tabSize = 8) @trusted pure
    if(isSomeString!S)
{
    bool changes = false;
    alias Unqual!(typeof(s[0])) C;
    C[] result;

    int nspaces = 0;
    int nwhite = 0;
    size_t column = 0;         // column number

    foreach (size_t i, dchar c; s)
    {

        void change()
        {
            changes = true;
            result = null;
            result.length = s.length;
            result.length = i;
            result[0 .. i] = s[0 .. i];
        }

        switch (c)
        {
        case '\t':
            nwhite++;
            if (nspaces)
            {
                if (!changes)
                    change();

                sizediff_t j = result.length - nspaces;
                auto ntabs = (((column - nspaces) % tabSize) + nspaces) / tabSize;
                result.length = j + ntabs;
                result[j .. j + ntabs] = '\t';
                nwhite += ntabs - nspaces;
                nspaces = 0;
            }
            column = (column + tabSize) / tabSize * tabSize;
            break;

        case '\r':
        case '\n':
        case paraSep:
        case lineSep:
            // Truncate any trailing spaces or tabs
            if (nwhite)
            {
                if (!changes)
                    change();
                result = result[0 .. result.length - nwhite];
            }
            break;

        default:
            if (nspaces >= 2 && (column % tabSize) == 0)
            {
                if (!changes)
                    change();

                auto j = result.length - nspaces;
                auto ntabs = (nspaces + tabSize - 1) / tabSize;
                result.length = j + ntabs;
                result[j .. j + ntabs] = '\t';
                nwhite += ntabs - nspaces;
                nspaces = 0;
            }
            if (c == ' ')
            {   nwhite++;
                nspaces++;
            }
            else
            {   nwhite = 0;
                nspaces = 0;
            }
            column++;
            break;
        }
        if (changes)
        {
            if (cast(dchar)(cast(C)c) == c)
                result ~= cast(C)c;
            else
                std.utf.encode(result, c);
        }
    }

    // Truncate any trailing spaces or tabs
    if (nwhite)
    {
        if (changes)
            result = result[0 .. result.length - nwhite];
        else
            s = s[0 .. s.length - nwhite];
    }
    return changes ? assumeUnique(result) : s;
}

unittest
{
    debug(string) printf("string.entab.unittest\n");

    string r;

    assert(entab(cast(string) null) is null);
    assert(entab("").empty);
    assert(entab("a") == "a");
    assert(entab("        ") == "");
    assert(entab("        x") == "\tx");
    assert(entab("  ab    asdf ") == "  ab\tasdf");
    assert(entab("  ab     asdf ") == "  ab\t asdf");
    assert(entab("  ab \t   asdf ") == "  ab\t   asdf");
    assert(entab("1234567 \ta") == "1234567\t\ta");
    assert(entab("1234567  \ta") == "1234567\t\ta");
    assert(entab("1234567   \ta") == "1234567\t\ta");
    assert(entab("1234567    \ta") == "1234567\t\ta");
    assert(entab("1234567     \ta") == "1234567\t\ta");
    assert(entab("1234567      \ta") == "1234567\t\ta");
    assert(entab("1234567       \ta") == "1234567\t\ta");
    assert(entab("1234567        \ta") == "1234567\t\ta");
    assert(entab("1234567         \ta") == "1234567\t\t\ta");

    assert(entab("a               ") == "a");
    assert(entab("a\v") == "a\v");
    assert(entab("a\f") == "a\f");
    assert(entab("a\n") == "a\n");
    assert(entab("a\n\r") == "a\n\r");
    assert(entab("a\r\n") == "a\r\n");
    assert(entab("a\u2028") == "a\u2028");
    assert(entab("a\u2029") == "a\u2029");
    assert(entab("a  ") == "a");
    assert(entab("a\t") == "a");
    assert(entab("\uFF28\uFF45\uFF4C\uFF4C567      \t\uFF4F \t") ==
                 "\uFF28\uFF45\uFF4C\uFF4C567\t\t\uFF4F");
}


/++
    Replaces the characters in $(D str) which are keys in $(D transTable) with
    their corresponding values in $(D transTable). $(D transTable) is an AA
    where its keys are $(D dchar) and its values are either $(D dchar) or some
    type of string. Also, if $(D toRemove) is given, the characters in it are
    removed from $(D str) prior to translation. $(D str) itself is unaltered.
    A copy with the changes is returned.

    See_Also:
        $(LREF tr)
        $(XREF array, replace)

    Params:
        str        = The original string.
        transTable = The AA indicating which characters to replace and what to
                     replace them with.
        toRemove   = The characters to remove from the string.

        Examples:
--------------------
dchar[dchar] transTable1 = ['e' : '5', 'o' : '7', '5': 'q'];
assert(translate("hello world", transTable1) == "h5ll7 w7rld");

dchar[dchar] transTable2 = ['e' : '5', 'o' : '7', '5': 'q'];
assert(translate("hello world", transTable2, "low") == "h5 rd");

string[dchar] transTable3 = ['e' : "5", 'o' : "orange"];
assert(translate("hello world", transTable3) == "h5llorange worangerld");
--------------------
  +/
C1[] translate(C1, C2 = immutable char)(C1[] str,
                                        dchar[dchar] transTable,
                                        const(C2)[] toRemove = null) @safe
    if(isSomeChar!C1 && isSomeChar!C2)
{
    return translateImpl(str, transTable, toRemove);
}

//Verify Examples.
unittest
{
    dchar[dchar] transTable1 = ['e' : '5', 'o' : '7', '5': 'q'];
    assert(translate("hello world", transTable1) == "h5ll7 w7rld");

    dchar[dchar] transTable2 = ['e' : '5', 'o' : '7', '5': 'q'];
    assert(translate("hello world", transTable2, "low") == "h5 rd");

    string[dchar] transTable3 = ['e' : "5", 'o' : "orange"];
    assert(translate("hello world", transTable3) == "h5llorange worangerld");
}

unittest
{
    foreach(S; TypeTuple!(char[], const(char)[], immutable(char)[],
                          wchar[], const(wchar)[], immutable(wchar)[],
                          dchar[], const(dchar)[], immutable(dchar)[]))
    {
        assert(translate(to!S("hello world"), cast(dchar[dchar])['h' : 'q', 'l' : '5']) ==
               to!S("qe55o wor5d"));
        assert(translate(to!S("hello world"), cast(dchar[dchar])['o' : 'l', 'l' : '\U00010143']) ==
               to!S("he\U00010143\U00010143l wlr\U00010143d"));
        assert(translate(to!S("hello \U00010143 world"), cast(dchar[dchar])['h' : 'q', 'l': '5']) ==
               to!S("qe55o \U00010143 wor5d"));
        assert(translate(to!S("hello \U00010143 world"), cast(dchar[dchar])['o' : '0', '\U00010143' : 'o']) ==
               to!S("hell0 o w0rld"));
        assert(translate(to!S("hello world"), cast(dchar[dchar])null) == to!S("hello world"));

        foreach(T; TypeTuple!(char[], const(char)[], immutable(char)[],
                              wchar[], const(wchar)[], immutable(wchar)[],
                              dchar[], const(dchar)[], immutable(dchar)[]))
        {
            assert(translate(to!S("hello world"),
                             cast(dchar[dchar])['h' : 'q', 'l' : '5'],
                             to!T("r")) ==
                   to!S("qe55o wo5d"));
            assert(translate(to!S("hello world"),
                             cast(dchar[dchar])['h' : 'q', 'l' : '5'],
                             to!T("helo")) ==
                   to!S(" wrd"));
            assert(translate(to!S("hello world"),
                             cast(dchar[dchar])['h' : 'q', 'l' : '5'],
                             to!T("q5")) ==
                   to!S("qe55o wor5d"));
            assert(translate(to!S("hello \U00010143 world"),
                             cast(dchar[dchar])['o' : '0', '\U00010143' : 'o'],
                             to!T("\U00010143 ")) ==
                   to!S("hell0w0rld"));
        }

        auto s = to!S("hello world");
        dchar[dchar] transTable = ['h' : 'q', 'l' : '5'];
        static assert(is(typeof(s) == typeof(translate(s, transTable))));
    }
}

/++ Ditto +/
C1[] translate(C1, S, C2 = immutable char)(C1[] str,
                                           S[dchar] transTable,
                                           const(C2)[] toRemove = null) @safe
    if(isSomeChar!C1 && isSomeString!S && isSomeChar!C2)
{
    return translateImpl(str, transTable, toRemove);
}

unittest
{
    foreach(S; TypeTuple!(char[], const(char)[], immutable(char)[],
                          wchar[], const(wchar)[], immutable(wchar)[],
                          dchar[], const(dchar)[], immutable(dchar)[]))
    {
        assert(translate(to!S("hello world"), ['h' : "yellow", 'l' : "42"]) ==
               to!S("yellowe4242o wor42d"));
        assert(translate(to!S("hello world"), ['o' : "owl", 'l' : "\U00010143\U00010143"]) ==
               to!S("he\U00010143\U00010143\U00010143\U00010143owl wowlr\U00010143\U00010143d"));
        assert(translate(to!S("hello \U00010143 world"), ['h' : "yellow", 'l' : "42"]) ==
               to!S("yellowe4242o \U00010143 wor42d"));
        assert(translate(to!S("hello \U00010143 world"), ['o' : "owl", 'l' : "\U00010143\U00010143"]) ==
               to!S("he\U00010143\U00010143\U00010143\U00010143owl \U00010143 wowlr\U00010143\U00010143d"));
        assert(translate(to!S("hello \U00010143 world"), ['h' : ""]) ==
               to!S("ello \U00010143 world"));
        assert(translate(to!S("hello \U00010143 world"), ['\U00010143' : ""]) ==
               to!S("hello  world"));
        assert(translate(to!S("hello world"), cast(string[dchar])null) == to!S("hello world"));

        foreach(T; TypeTuple!(char[], const(char)[], immutable(char)[],
                              wchar[], const(wchar)[], immutable(wchar)[],
                              dchar[], const(dchar)[], immutable(dchar)[]))
        {
            assert(translate(to!S("hello world"), ['h' : "yellow", 'l' : "42"], to!T("r")) ==
                   to!S("yellowe4242o wo42d"));
            assert(translate(to!S("hello world"), ['h' : "yellow", 'l' : "42"], to!T("helo")) ==
                   to!S(" wrd"));
            assert(translate(to!S("hello world"), ['h' : "yellow", 'l' : "42"], to!T("y42")) ==
                   to!S("yellowe4242o wor42d"));
            assert(translate(to!S("hello \U00010143 world"),
                             ['o' : "owl", '\U00010143' : "\n"],
                             to!T("\U00010143 ")) ==
                   to!S("hellowlwowlrld"));
        }

        auto s = to!S("hello world");
        string[dchar] transTable = ['h' : "silly", 'l' : "putty"];
        static assert(is(typeof(s) == typeof(translate(s, transTable))));
    }
}

private auto translateImpl(C1, T, C2)(C1[] str,
                                      T transTable,
                                      const(C2)[] toRemove) @trusted
{
    auto retval = appender!(C1[])();

    bool[dchar] removeTable;

    foreach(dchar c; toRemove)
        removeTable[c] = true;

    foreach(dchar c; str)
    {
        if(c in removeTable)
            continue;

        auto newC = c in transTable;

        if(newC)
            retval.put(*newC);
        else
            retval.put(c);
    }

    return retval.data;
}



/************************************
 * $(RED Scheduled for deprecation in February 2012.)
 *
 * Construct translation table for translate().
 * BUGS: only works with ASCII
 */

string maketrans(in char[] from, in char[] to)
in
{
    assert(from.length == to.length);
    assert(from.length <= 128);
    foreach (char c; from)
        assert(std.ascii.isASCII(c));
    foreach (char c; to)
        assert(std.ascii.isASCII(c));
}
body
{
    char[] t = new char[256];

    foreach (i; 0 .. t.length)
        t[i] = cast(char)i;
    foreach (i; 0 .. from.length)
        t[from[i]] = to[i];

    return assumeUnique(t);
}

/******************************************
 * $(RED Scheduled for deprecation in February 2012.
 *   Please use the version of $(D translate) which takes an AA instead.)
 *
 * Translate characters in s[] using table created by maketrans().
 * Delete chars in delchars[].
 * BUGS: only works with ASCII
 */

string translate()(in char[] s, in char[] transtab, in char[] delchars)
in
{
    assert(transtab.length == 256);
}
body
{
    bool[256] deltab;

    deltab[] = false;
    foreach (char c; delchars)
    {
        deltab[c] = true;
    }

    size_t count = 0;
    foreach (char c; s)
    {
        if (!deltab[c])
            count++;
        //printf("s[%d] = '%c', count = %d\n", i, s[i], count);
    }

    auto r = new char[count];
    count = 0;
    foreach (char c; s)
    {
        if (!deltab[c])
        {
            r[count] = transtab[c];
            count++;
        }
    }

    return assumeUnique(r);
}

unittest
{
    debug(string) printf("string.translate.unittest\n");

    string from = "abcdef";
    string to   = "ABCDEF";
    string s    = "The quick dog fox";
    string t;
    string r;
    int i;

    t = maketrans(from, to);
    r = translate(s, t, "kg");
    //printf("r = '%.*s'\n", r);
    i = cmp(r, "ThE quiC Do Fox");
    assert(i == 0);
}


private:

// @@@BUG@@@ workaround for bugzilla 2479
string bug2479format(TypeInfo[] arguments, va_list argptr)
{
    char[] s;

    void putc(dchar c)
    {
        std.utf.encode(s, c);
    }
    std.format.doFormat(&putc, arguments, argptr);
    return assumeUnique(s);
}

// @@@BUG@@@ workaround for bugzilla 2479
char[] bug2479sformat(char[] s, TypeInfo[] arguments, va_list argptr)
{   size_t i;

    void putc(dchar c)
    {
    if(std.ascii.isASCII(c))
    {
        if (i >= s.length)
            onRangeError("std.string.sformat", 0);
        s[i] = cast(char)c;
        ++i;
    }
    else
    {   char[4] buf;
        auto b = std.utf.toUTF8(buf, c);
        if (i + b.length > s.length)
            onRangeError("std.string.sformat", 0);
        s[i..i+b.length] = b[];
        i += b.length;
    }
    }

    std.format.doFormat(&putc, arguments, argptr);
    return s[0 .. i];
}
public:


/*****************************************************
 * Format arguments into a string.
 */

string format(...)
{
/+ // @@@BUG@@@ Fails due to regression bug 2479.
    char[] s;

    void putc(dchar c)
    {
        std.utf.encode(s, c);
    }

    std.format.doFormat(&putc, _arguments, _argptr);
    return assumeUnique(s);
    +/
    return bug2479format(_arguments, _argptr);
}


/*****************************************************
 * Format arguments into string <i>s</i> which must be large
 * enough to hold the result. Throws RangeError if it is not.
 * Returns: s
 */
char[] sformat(char[] s, ...)
{
/+ // @@@BUG@@@ Fails due to regression bug 2479.

  size_t i;

    void putc(dchar c)
    {
    if(std.ascii.isASCII(c))
    {
        if (i >= s.length)
            onRangeError("std.string.sformat", 0);
        s[i] = cast(char)c;
        ++i;
    }
    else
    {   char[4] buf;
        auto b = std.utf.toUTF8(buf, c);
        if (i + b.length > s.length)
            onRangeError("std.string.sformat", 0);
        s[i..i+b.length] = b[];
        i += b.length;
    }
    }

    std.format.doFormat(&putc, _arguments, _argptr);
    return s[0 .. i];
    +/
    return bug2479sformat(s, _arguments, _argptr);
}

unittest
{
    debug(string) printf("std.string.format.unittest\n");

    string r;
    int i;
/+
    r = format(null);
    i = cmp(r, "");
    assert(i == 0);
+/
    r = format("foo");
    i = cmp(r, "foo");
    assert(i == 0);

    r = format("foo%%");
    i = cmp(r, "foo%");
    assert(i == 0);

    r = format("foo%s", 'C');
    i = cmp(r, "fooC");
    assert(i == 0);

    r = format("%s foo", "bar");
    i = cmp(r, "bar foo");
    assert(i == 0);

    r = format("%s foo %s", "bar", "abc");
    i = cmp(r, "bar foo abc");
    assert(i == 0);

    r = format("foo %d", -123);
    i = cmp(r, "foo -123");
    assert(i == 0);

    r = format("foo %d", 123);
    i = cmp(r, "foo 123");
    assert(i == 0);
}


/***********************************************
 * See if character c is in the pattern.
 * Patterns:
 *
 *  A <i>pattern</i> is an array of characters much like a <i>character
 *  class</i> in regular expressions. A sequence of characters
 *  can be given, such as "abcde". The '-' can represent a range
 *  of characters, as "a-e" represents the same pattern as "abcde".
 *  "a-fA-F0-9" represents all the hex characters.
 *  If the first character of a pattern is '^', then the pattern
 *  is negated, i.e. "^0-9" means any character except a digit.
 *  The functions inPattern, <b>countchars</b>, <b>removeschars</b>,
 *  and <b>squeeze</b>
 *  use patterns.
 *
 * Note: In the future, the pattern syntax may be improved
 *  to be more like regular expression character classes.
 */

bool inPattern(S)(dchar c, in S pattern) if (isSomeString!S)
{
    bool result = false;
    int range = 0;
    dchar lastc;

    foreach (size_t i, dchar p; pattern)
    {
    if (p == '^' && i == 0)
    {   result = true;
        if (i + 1 == pattern.length)
        return (c == p);    // or should this be an error?
    }
    else if (range)
    {
        range = 0;
        if (lastc <= c && c <= p || c == p)
        return !result;
    }
    else if (p == '-' && i > result && i + 1 < pattern.length)
    {
        range = 1;
        continue;
    }
    else if (c == p)
        return !result;
    lastc = p;
    }
    return result;
}


unittest
{
    debug(string) printf("std.string.inPattern.unittest\n");

    int i;

    i = inPattern('x', "x");
    assert(i == 1);
    i = inPattern('x', "y");
    assert(i == 0);
    i = inPattern('x', cast(string)null);
    assert(i == 0);
    i = inPattern('x', "^y");
    assert(i == 1);
    i = inPattern('x', "yxxy");
    assert(i == 1);
    i = inPattern('x', "^yxxy");
    assert(i == 0);
    i = inPattern('x', "^abcd");
    assert(i == 1);
    i = inPattern('^', "^^");
    assert(i == 0);
    i = inPattern('^', "^");
    assert(i == 1);
    i = inPattern('^', "a^");
    assert(i == 1);
    i = inPattern('x', "a-z");
    assert(i == 1);
    i = inPattern('x', "A-Z");
    assert(i == 0);
    i = inPattern('x', "^a-z");
    assert(i == 0);
    i = inPattern('x', "^A-Z");
    assert(i == 1);
    i = inPattern('-', "a-");
    assert(i == 1);
    i = inPattern('-', "^A-");
    assert(i == 0);
    i = inPattern('a', "z-a");
    assert(i == 1);
    i = inPattern('z', "z-a");
    assert(i == 1);
    i = inPattern('x', "z-a");
    assert(i == 0);
}


/***********************************************
 * See if character c is in the intersection of the patterns.
 */

bool inPattern(S)(dchar c, S[] patterns) if (isSomeString!S)
{
    foreach (string pattern; patterns)
    {
        if (!inPattern(c, pattern))
        {
            return false;
        }
    }
    return true;
}


/********************************************
 * Count characters in s that match pattern.
 */

size_t countchars(S, S1)(S s, in S1 pattern) if (isSomeString!S && isSomeString!S1)
{
    size_t count;
    foreach (dchar c; s)
    {
        count += inPattern(c, pattern);
    }
    return count;
}

unittest
{
    debug(string) printf("std.string.count.unittest\n");

    size_t c;

    c = countchars("abc", "a-c");
    assert(c == 3);
    c = countchars("hello world", "or");
    assert(c == 3);
}


/********************************************
 * Return string that is s with all characters removed that match pattern.
 */

S removechars(S)(S s, in S pattern) if (isSomeString!S)
{
    Unqual!(typeof(s[0]))[] r;
    bool changed = false;

    foreach (size_t i, dchar c; s)
    {
        if (inPattern(c, pattern)){
            if (!changed)
            {
                changed = true;
                r = s[0 .. i].dup;
            }
            continue;
        }
        if (changed)
        {
            std.utf.encode(r, c);
        }
    }
    return (changed? cast(S) r : s);
}

unittest
{
    debug(string) printf("std.string.removechars.unittest\n");

    string r;

    r = removechars("abc", "a-c");
    assert(r.length == 0);
    r = removechars("hello world", "or");
    assert(r == "hell wld");
    r = removechars("hello world", "d");
    assert(r == "hello worl");
    r = removechars("hah", "h");
    assert(r == "a");
}


/***************************************************
 * Return string where sequences of a character in s[] from pattern[]
 * are replaced with a single instance of that character.
 * If pattern is null, it defaults to all characters.
 */

S squeeze(S)(S s, in S pattern = null)
{
    Unqual!(typeof(s[0]))[] r;
    dchar lastc;
    size_t lasti;
    int run;
    bool changed;

    foreach (size_t i, dchar c; s)
    {
        if (run && lastc == c)
        {
            changed = true;
        }
        else if (pattern is null || inPattern(c, pattern))
        {
            run = 1;
            if (changed)
            {   if (r is null)
                    r = s[0 .. lasti].dup;
                std.utf.encode(r, c);
            }
            else
                lasti = i + std.utf.stride(s, i);
            lastc = c;
        }
        else
        {
            run = 0;
            if (changed)
            {   if (r is null)
                    r = s[0 .. lasti].dup;
                std.utf.encode(r, c);
            }
        }
    }
    return changed ? ((r is null) ? s[0 .. lasti] : cast(S) r) : s;
}

unittest
{
    debug(string) printf("std.string.squeeze.unittest\n");
    string s,r;

    r = squeeze("hello");
    //writefln("r = '%s'", r);
    assert(r == "helo");
    s = "abcd";
    r = squeeze(s);
    assert(r is s);
    s = "xyzz";
    r = squeeze(s);
    assert(r.ptr == s.ptr); // should just be a slice
    r = squeeze("hello goodbyee", "oe");
    assert(r == "hello godbye");
}

/***************************************************************
 Finds the position $(D_PARAM pos) of the first character in $(D_PARAM
 s) that does not match $(D_PARAM pattern) (in the terminology used by
 $(LINK2 std_string.html,inPattern)). Updates $(D_PARAM s =
 s[pos..$]). Returns the slice from the beginning of the original
 (before update) string up to, and excluding, $(D_PARAM pos).

 Example:
 ---
string s = "123abc";
string t = munch(s, "0123456789");
assert(t == "123" && s == "abc");
t = munch(s, "0123456789");
assert(t == "" && s == "abc");
 ---

The $(D_PARAM munch) function is mostly convenient for skipping
certain category of characters (e.g. whitespace) when parsing
strings. (In such cases, the return value is not used.)
 */

S1 munch(S1, S2)(ref S1 s, S2 pattern)
{
    size_t j = s.length;
    foreach (i, c; s)
    {
        if (!inPattern(c, pattern))
        {
            j = i;
            break;
        }
    }
    scope(exit) s = s[j .. $];
    return s[0 .. j];
}

unittest
{
    string s = "123abc";
    string t = munch(s, "0123456789");
    assert(t == "123" && s == "abc");
    t = munch(s, "0123456789");
    assert(t == "" && s == "abc");
}


/**********************************************
 * Return string that is the 'successor' to s[].
 * If the rightmost character is a-zA-Z0-9, it is incremented within
 * its case or digits. If it generates a carry, the process is
 * repeated with the one to its immediate left.
 */

S succ(S)(S s) if (isSomeString!S)
{
    if (s.length && std.ascii.isAlphaNum(s[$ - 1]))
    {
        auto r = s.dup;
        size_t i = r.length - 1;

        while (1)
        {
            dchar c = s[i];
            dchar carry;

            switch (c)
            {
            case '9':
                c = '0';
                carry = '1';
                goto Lcarry;
            case 'z':
            case 'Z':
                c -= 'Z' - 'A';
                carry = c;
            Lcarry:
                r[i] = cast(char)c;
                if (i == 0)
                {
                    auto t = new typeof(r[0])[r.length + 1];
                    t[0] = cast(char) carry;
                    t[1 .. $] = r[];
                    return assumeUnique(t);
                }
                i--;
                break;

            default:
                if (std.ascii.isAlphaNum(c))
                    r[i]++;
                return cast(S) r;
            }
        }
    }
    return s;
}

unittest
{
    debug(string) printf("std.string.succ.unittest\n");

    string r;

    r = succ(cast(string) null);
    assert(r is null);
    r = succ("!@#$%");
    assert(r == "!@#$%");
    r = succ("1");
    assert(r == "2");
    r = succ("9");
    assert(r == "10");
    r = succ("999");
    assert(r == "1000");
    r = succ("zz99");
    assert(r == "aaa00");
}


/++
    Replaces the characters in $(D str) which are in $(D from) with the
    the corresponding characters in $(D to) and returns the resulting string.

    $(D tr) is based on
    $(WEB pubs.opengroup.org/onlinepubs/9699919799/utilities/_tr.html, Posix's tr),
    though it doesn't do everything that the Posix utility does.

    Params:
        str       = The original string.
        from      = The characters to replace.
        to        = The characters to replace with.
        modifiers = String containing modifiers.

    Modifiers:
        $(BOOKTABLE,
        $(TR $(TD Modifier) $(TD Description))
        $(TR $(TD $(D 'c')) $(TD Complement the list of characters in $(D from)))
        $(TR $(TD $(D 'd')) $(TD Removes matching characters with no corresponding
                              replacement in $(D to)))
        $(TR $(TD $(D 's')) $(TD Removes adjacent duplicates in the replaced
                              characters))
        )

    If the modifier $(D 'd') is present, then the number of characters in
    $(D to) may be only $(D 0) or $(D 1).

    If the modifier $(D 'd') is $(I not) present, and $(D to) is empty, then
    $(D to) is taken to be the same as $(D from).

    If the modifier $(D 'd') is $(I not) present, and $(D to) is shorter than
    $(D from), then $(D to) is extended by replicating the last charcter in
    $(D to).

    Both $(D from) and $(D to) may contain ranges using the $(D '-') character
    (e.g. $(D "a-d") is synonymous with $(D "abcd).) Neither accept a leading
    $(D '^') as meaning the complement of the string (use the $(D 'c') modifier
    for that).
  +/
C1[] tr(C1, C2, C3, C4 = immutable char)
       (C1[] str, const(C2)[] from, const(C3)[] to, const(C4)[] modifiers = null)
{
    bool mod_c;
    bool mod_d;
    bool mod_s;

    foreach (char c; modifiers)
    {
        switch (c)
        {
        case 'c':   mod_c = 1; break;   // complement
        case 'd':   mod_d = 1; break;   // delete unreplaced chars
        case 's':   mod_s = 1; break;   // squeeze duplicated replaced chars
        default:    assert(0);
        }
    }

    if (to.empty && !mod_d)
        to = std.conv.to!(typeof(to))(from);

    auto result = appender!(C1[])();
    bool modified;
    dchar lastc;

    foreach (dchar c; str)
    {
        dchar lastf;
        dchar lastt;
        dchar newc;
        int n = 0;

        for (size_t i = 0; i < from.length; )
        {
            dchar f = std.utf.decode(from, i);
            if (f == '-' && lastf != dchar.init && i < from.length)
            {
                dchar nextf = std.utf.decode(from, i);
                if (lastf <= c && c <= nextf)
                {
                    n += c - lastf - 1;
                    if (mod_c)
                        goto Lnotfound;
                    goto Lfound;
                }
                n += nextf - lastf;
                lastf = lastf.init;
                continue;
            }

            if (c == f)
            {   if (mod_c)
                    goto Lnotfound;
                goto Lfound;
            }
            lastf = f;
            n++;
        }
        if (!mod_c)
            goto Lnotfound;
        n = 0;          // consider it 'found' at position 0

      Lfound:

        // Find the nth character in to[]
        dchar nextt;
        for (size_t i = 0; i < to.length; )
        {   dchar t = std.utf.decode(to, i);
            if (t == '-' && lastt != dchar.init && i < to.length)
            {
                nextt = std.utf.decode(to, i);
                n -= nextt - lastt;
                if (n < 0)
                {
                    newc = nextt + n + 1;
                    goto Lnewc;
                }
                lastt = dchar.init;
                continue;
            }
            if (n == 0)
            {   newc = t;
                goto Lnewc;
            }
            lastt = t;
            nextt = t;
            n--;
        }
        if (mod_d)
            continue;
        newc = nextt;

      Lnewc:
        if (mod_s && modified && newc == lastc)
            continue;
        result.put(newc);
        assert(newc != dchar.init);
        modified = true;
        lastc = newc;
        continue;

      Lnotfound:
        result.put(c);
        lastc = c;
        modified = false;
    }

    return result.data;
}

unittest
{
    debug(string) printf("std.string.tr.unittest\n");
    import std.algorithm;

    // Complete list of test types; too slow to test'em all
    // alias TypeTuple!(char[], const(char)[], immutable(char)[],
    //         wchar[], const(wchar)[], immutable(wchar)[],
    //         dchar[], const(dchar)[], immutable(dchar)[])
    // TestTypes;

    // Reduced list of test types
    alias TypeTuple!(char[], const(wchar)[], immutable(dchar)[])
    TestTypes;

    foreach(S; TestTypes)
    {
        foreach(T; TestTypes)
        {
            foreach(U; TestTypes)
            {
                assert(equal(tr(to!S("abcdef"), to!T("cd"), to!U("CD")), "abCDef"));
                assert(equal(tr(to!S("abcdef"), to!T("b-d"), to!U("B-D")), "aBCDef"));
                assert(equal(tr(to!S("abcdefgh"), to!T("b-dh"), to!U("B-Dx")), "aBCDefgx"));
                assert(equal(tr(to!S("abcdefgh"), to!T("b-dh"), to!U("B-CDx")), "aBCDefgx"));
                assert(equal(tr(to!S("abcdefgh"), to!T("b-dh"), to!U("B-BCDx")), "aBCDefgx"));
                assert(equal(tr(to!S("abcdef"), to!T("ef"), to!U("*"), to!S("c")), "****ef"));
                assert(equal(tr(to!S("abcdef"), to!T("ef"), to!U(""), to!T("d")), "abcd"));
                assert(equal(tr(to!S("hello goodbye"), to!T("lo"), to!U(""), to!U("s")), "helo godbye"));
                assert(equal(tr(to!S("hello goodbye"), to!T("lo"), to!U("x"), "s"), "hex gxdbye"));
                assert(equal(tr(to!S("14-Jul-87"), to!T("a-zA-Z"), to!U(" "), "cs"), " Jul "));
                assert(equal(tr(to!S("Abc"), to!T("AAA"), to!U("XYZ")), "Xbc"));
            }
        }

        auto s = to!S("hello world");
        static assert(is(typeof(s) == typeof(tr(s, "he", "if"))));
    }
}


/* ************************************************
 * Version       : v0.3
 * Author        : David L. 'SpottedTiger' Davis
 * Date Created  : 31.May.05 Compiled and Tested with dmd v0.125
 * Date Modified : 01.Jun.05 Modified the function to handle the
 *               :           imaginary and complex float-point
 *               :           datatypes.
 *               :
 * Licence       : Public Domain / Contributed to Digital Mars
 */

/**
 * [in] string s can be formatted in the following ways:
 *
 * Integer Whole Number:
 * (for byte, ubyte, short, ushort, int, uint, long, and ulong)
 * ['+'|'-']digit(s)[U|L|UL]
 *
 * examples: 123, 123UL, 123L, +123U, -123L
 *
 * Floating-Point Number:
 * (for float, double, real, ifloat, idouble, and ireal)
 * ['+'|'-']digit(s)[.][digit(s)][[e-|e+]digit(s)][i|f|L|Li|fi]]
 *      or [nan|nani|inf|-inf]
 *
 * examples: +123., -123.01, 123.3e-10f, 123.3e-10fi, 123.3e-10L
 *
 * (for cfloat, cdouble, and creal)
 * ['+'|'-']digit(s)[.][digit(s)][[e-|e+]digit(s)][+]
 *         [digit(s)[.][digit(s)][[e-|e+]digit(s)][i|f|L|Li|fi]]
 *      or [nan|nani|nan+nani|inf|-inf]
 *
 * examples: nan, -123e-1+456.9e-10Li, +123e+10+456i, 123+456
 *
 * [in] bool bAllowSep
 * False by default, but when set to true it will accept the
 * separator characters "," and "_" within the string, but these
 * characters should be stripped from the string before using any
 * of the conversion functions like toInt(), toFloat(), and etc
 * else an error will occur.
 *
 * Also please note, that no spaces are allowed within the string
 * anywhere whether it's a leading, trailing, or embedded space(s),
 * thus they too must be stripped from the string before using this
 * function, or any of the conversion functions.
 */

bool isNumeric(const(char)[] s, in bool bAllowSep = false)
{
    sizediff_t iLen = s.length;
    bool   bDecimalPoint = false;
    bool   bExponent = false;
    bool   bComplex = false;
    auto sx = std.string.toLower(s);
    int    j  = 0;
    char   c;

    //writefln("isNumeric(string, bool = false) called!");
    // Empty string, return false
    if (iLen == 0)
        return false;

    // Check for NaN (Not a Number)
    if (sx == "nan" || sx == "nani" || sx == "nan+nani")
        return true;

    // Check for Infinity
    if (sx == "inf" || sx == "-inf")
        return true;

    // A sign is allowed only in the 1st character
    if (sx[0] == '-' || sx[0] == '+')
        j++;

    for (int i = j; i < iLen; i++)
    {
        c = sx[i];

        // Digits are good, continue checking
        // with the popFront character... ;)
        if (c >= '0' && c <= '9')
            continue;

        // Check for the complex type, and if found
        // reset the flags for checking the 2nd number.
        else if (c == '+')
            if (i > 0)
            {
                bDecimalPoint = false;
                bExponent = false;
                bComplex = true;
                continue;
            }
            else
                return false;

        // Allow only one exponent per number
        else if (c == 'e')
        {
            // A 2nd exponent found, return not a number
            if (bExponent)
                return false;

            if (i + 1 < iLen)
            {
                // Look forward for the sign, and if
                // missing then this is not a number.
                if (sx[i + 1] != '-' && sx[i + 1] != '+')
                    return false;
                else
                {
                    bExponent = true;
                    i++;
                }
            }
            else
                // Ending in "E", return not a number
                return false;
        }
        // Allow only one decimal point per number to be used
        else if (c == '.' )
        {
            // A 2nd decimal point found, return not a number
            if (bDecimalPoint)
                return false;

            bDecimalPoint = true;
            continue;
        }
        // Check for ending literal characters: "f,u,l,i,ul,fi,li",
        // and wheater they're being used with the correct datatype.
        else if (i == iLen - 2)
        {
            // Integer Whole Number
            if (sx[i..iLen] == "ul" &&
               (!bDecimalPoint && !bExponent && !bComplex))
                return true;
            // Floating-Point Number
            else if ((sx[i..iLen] == "fi" || sx[i..iLen] == "li") &&
                     (bDecimalPoint || bExponent || bComplex))
                return true;
            else if (sx[i..iLen] == "ul" &&
                    (bDecimalPoint || bExponent || bComplex))
                return false;
            // Could be a Integer or a Float, thus
            // all these suffixes are valid for both
            else if (sx[i..iLen] == "ul" ||
                     sx[i..iLen] == "fi" ||
                     sx[i..iLen] == "li")
                return true;
            else
                return false;
        }
        else if (i == iLen - 1)
        {
            // Integer Whole Number
            if ((c == 'u' || c == 'l') &&
                (!bDecimalPoint && !bExponent && !bComplex))
                return true;
            // Check to see if the last character in the string
            // is the required 'i' character
            else if (bComplex)
                if (c == 'i')
                    return true;
                else
                    return false;
            // Floating-Point Number
            else if ((c == 'l' || c == 'f' || c == 'i') &&
                     (bDecimalPoint || bExponent))
                return true;
            // Could be a Integer or a Float, thus
            // all these suffixes are valid for both
            else if (c == 'l' || c == 'f' || c == 'i')
                return true;
            else
                return false;
        }
        else
            // Check if separators are allow
            // to be in the numeric string
            if (bAllowSep == true && (c == '_' || c == ','))
                continue;
            else
                return false;
    }

    return true;
}

/++
    $(RED Scheduled for deprecation in January 2012.)

    Allow any object as a parameter
  +/
bool isNumeric(...)
{
    return isNumeric(_arguments, _argptr);
}

/++
    $(RED Scheduled for deprecation in January 2012.)

    Check only the first parameter, all others will be ignored.
  +/
bool isNumeric(TypeInfo[] _arguments, va_list _argptr)
{
    auto  s = ""c;
    auto ws = ""w;
    auto ds = ""d;

    //writefln("isNumeric(...) called!");
    if (_arguments.length == 0)
        return false;

    if (_arguments[0] == typeid(char[]))
        return isNumeric(va_arg!(char[])(_argptr));
    else if (_arguments[0] == typeid(wchar[]))
        return isNumeric(std.utf.toUTF8(va_arg!(wchar[])(_argptr)));
    else if (_arguments[0] == typeid(dchar[]))
        return isNumeric(std.utf.toUTF8(va_arg!(dstring)(_argptr)));
    else if (_arguments[0] == typeid(real))
        return true;
    else if (_arguments[0] == typeid(double))
        return true;
    else if (_arguments[0] == typeid(float))
        return true;
    else if (_arguments[0] == typeid(ulong))
        return true;
    else if (_arguments[0] == typeid(long))
        return true;
    else if (_arguments[0] == typeid(uint))
        return true;
    else if (_arguments[0] == typeid(int))
        return true;
    else if (_arguments[0] == typeid(ushort))
        return true;
    else if (_arguments[0] == typeid(short))
        return true;
    else if (_arguments[0] == typeid(ubyte))
    {
    char[1] t;
    t[0]= va_arg!(ubyte)(_argptr);
    return isNumeric(cast(string)t);
    }
    else if (_arguments[0] == typeid(byte))
    {
    char[1] t;
    t[0] = va_arg!(char)(_argptr);
    return isNumeric(cast(string)t);
    }
    else if (_arguments[0] == typeid(ireal))
        return true;
    else if (_arguments[0] == typeid(idouble))
        return true;
    else if (_arguments[0] == typeid(ifloat))
        return true;
    else if (_arguments[0] == typeid(creal))
        return true;
    else if (_arguments[0] == typeid(cdouble))
        return true;
    else if (_arguments[0] == typeid(cfloat))
        return true;
    else if (_arguments[0] == typeid(char))
    {
    char[1] t;
    t[0] = va_arg!(char)(_argptr);
        return isNumeric(cast(string)t);
    }
    else if (_arguments[0] == typeid(wchar))
    {
    wchar[1] t;
    t[0] = va_arg!(wchar)(_argptr);
        return isNumeric(std.utf.toUTF8(t));
    }
    else if (_arguments[0] == typeid(dchar))
    {
    dchar[1] t;
    t[0] = va_arg!(dchar)(_argptr);
        dchar[] t1 = t;
    return isNumeric(std.utf.toUTF8(cast(dstring) t1));
    }
    //else if (_arguments[0] == typeid(cent))
    //    return true;
    //else if (_arguments[0] == typeid(ucent))
    //    return true;
    else
       return false;
}

unittest
{
    debug (string) printf("isNumeric(in string, bool = false).unittest\n");
    string s;

    // Test the isNumeric(in string) function
    assert(isNumeric("1") == true );
    assert(isNumeric("1.0") == true );
    assert(isNumeric("1e-1") == true );
    assert(isNumeric("12345xxxx890") == false );
    assert(isNumeric("567L") == true );
    assert(isNumeric("23UL") == true );
    assert(isNumeric("-123..56f") == false );
    assert(isNumeric("12.3.5.6") == false );
    assert(isNumeric(" 12.356") == false );
    assert(isNumeric("123 5.6") == false );
    assert(isNumeric("1233E-1+1.0e-1i") == true );

    assert(isNumeric("123.00E-5+1234.45E-12Li") == true);
    assert(isNumeric("123.00e-5+1234.45E-12iL") == false);
    assert(isNumeric("123.00e-5+1234.45e-12uL") == false);
    assert(isNumeric("123.00E-5+1234.45e-12lu") == false);

    assert(isNumeric("123fi") == true);
    assert(isNumeric("123li") == true);
    assert(isNumeric("--123L") == false);
    assert(isNumeric("+123.5UL") == false);
    assert(isNumeric("123f") == true);
    assert(isNumeric("123.u") == false);

    assert(isNumeric(to!string(real.nan)) == true);
    assert(isNumeric(to!string(-real.infinity)) == true);
    assert(isNumeric(to!string(123e+2+1234.78Li)) == true);

    s = "$250.99-";
    assert(isNumeric(s[1..s.length - 2]) == true);
    assert(isNumeric(s) == false);
    assert(isNumeric(s[0..s.length - 1]) == false);

    // These test calling the isNumeric(...) function
    assert(isNumeric(1,123UL) == true);
    assert(isNumeric('2') == true);
    assert(isNumeric('x') == false);
    assert(isNumeric(cast(byte)0x57) == false); // 'W'
    assert(isNumeric(cast(byte)0x37) == true);  // '7'
    assert(isNumeric(cast(wchar[])"145.67") == true);
    assert(isNumeric(cast(dchar[])"145.67U") == false);
    assert(isNumeric(123_000.23fi) == true);
    assert(isNumeric(123.00E-5+1234.45E-12Li) == true);
    assert(isNumeric(real.nan) == true);
    assert(isNumeric(-real.infinity) == true);
}


/*****************************
 * Soundex algorithm.
 *
 * The Soundex algorithm converts a word into 4 characters
 * based on how the word sounds phonetically. The idea is that
 * two spellings that sound alike will have the same Soundex
 * value, which means that Soundex can be used for fuzzy matching
 * of names.
 *
 * Params:
 *  string = String to convert to Soundex representation.
 *  buffer = Optional 4 char array to put the resulting Soundex
 *      characters into. If null, the return value
 *      buffer will be allocated on the heap.
 * Returns:
 *  The four character array with the Soundex result in it.
 *  Returns null if there is no Soundex representation for the string.
 *
 * See_Also:
 *  $(LINK2 http://en.wikipedia.org/wiki/Soundex, Wikipedia),
 *  $(LUCKY The Soundex Indexing System)
 *
 * Bugs:
 *  Only works well with English names.
 *  There are other arguably better Soundex algorithms,
 *  but this one is the standard one.
 */

char[] soundex(const(char)[] string, char[] buffer = null)
in
{
    assert(!buffer || buffer.length >= 4);
}
out (result)
{
    if (result)
    {
        assert(result.length == 4);
        assert(result[0] >= 'A' && result[0] <= 'Z');
        foreach (char c; result[1 .. 4])
            assert(c >= '0' && c <= '6');
    }
}
body
{
    static immutable dex =
        // ABCDEFGHIJKLMNOPQRSTUVWXYZ
        "01230120022455012623010202";

    int b = 0;
    char lastc;
    foreach (char cs; string)
    {   auto c = cs;        // necessary because cs is final

        if (c >= 'a' && c <= 'z')
            c -= 'a' - 'A';
        else if (c >= 'A' && c <= 'Z')
        {
            ;
        }
        else
        {   lastc = lastc.init;
            continue;
        }
        if (b == 0)
        {
            if (!buffer)
                buffer = new char[4];
            buffer[0] = c;
            b++;
            lastc = dex[c - 'A'];
        }
        else
        {
            if (c == 'H' || c == 'W')
                continue;
            if (c == 'A' || c == 'E' || c == 'I' || c == 'O' || c == 'U')
                lastc = lastc.init;
            c = dex[c - 'A'];
            if (c != '0' && c != lastc)
            {
                buffer[b] = c;
                b++;
                lastc = c;
            }
        }
        if (b == 4)
            goto Lret;
    }
    if (b == 0)
        buffer = null;
    else
        buffer[b .. 4] = '0';
  Lret:
    return buffer;
}

unittest
{   char[4] buffer;

    assert(soundex(null) == null);
    assert(soundex("") == null);
    assert(soundex("0123^&^^**&^") == null);
    assert(soundex("Euler") == "E460");
    assert(soundex(" Ellery ") == "E460");
    assert(soundex("Gauss") == "G200");
    assert(soundex("Ghosh") == "G200");
    assert(soundex("Hilbert") == "H416");
    assert(soundex("Heilbronn") == "H416");
    assert(soundex("Knuth") == "K530");
    assert(soundex("Kant", buffer) == "K530");
    assert(soundex("Lloyd") == "L300");
    assert(soundex("Ladd") == "L300");
    assert(soundex("Lukasiewicz", buffer) == "L222");
    assert(soundex("Lissajous") == "L222");
    assert(soundex("Robert") == "R163");
    assert(soundex("Rupert") == "R163");
    assert(soundex("Rubin") == "R150");
    assert(soundex("Washington") == "W252");
    assert(soundex("Lee") == "L000");
    assert(soundex("Gutierrez") == "G362");
    assert(soundex("Pfister") == "P236");
    assert(soundex("Jackson") == "J250");
    assert(soundex("Tymczak") == "T522");
    assert(soundex("Ashcraft") == "A261");

    assert(soundex("Woo") == "W000");
    assert(soundex("Pilgrim") == "P426");
    assert(soundex("Flingjingwaller") == "F452");
    assert(soundex("PEARSE") == "P620");
    assert(soundex("PIERCE") == "P620");
    assert(soundex("Price") == "P620");
    assert(soundex("CATHY") == "C300");
    assert(soundex("KATHY") == "K300");
    assert(soundex("Jones") == "J520");
    assert(soundex("johnsons") == "J525");
    assert(soundex("Hardin") == "H635");
    assert(soundex("Martinez") == "M635");
}


/***************************************************
 * Construct an associative array consisting of all
 * abbreviations that uniquely map to the strings in values.
 *
 * This is useful in cases where the user is expected to type
 * in one of a known set of strings, and the program will helpfully
 * autocomplete the string once sufficient characters have been
 * entered that uniquely identify it.
 * Example:
 * ---
 * import std.stdio;
 * import std.string;
 *
 * void main()
 * {
 *    static string[] list = [ "food", "foxy" ];
 *
 *    auto abbrevs = std.string.abbrev(list);
 *
 *    foreach (key, value; abbrevs)
 *    {
 *       writefln("%s => %s", key, value);
 *    }
 * }
 * ---
 * produces the output:
 * <pre>
 * fox =&gt; foxy
 * food =&gt; food
 * foxy =&gt; foxy
 * foo =&gt; food
 * </pre>
 */

string[string] abbrev(string[] values)
{
    string[string] result;

    // Make a copy when sorting so we follow COW principles.
    values = values.dup.sort;

    size_t values_length = values.length;
    size_t lasti = values_length;
    size_t nexti;

    string nv;
    string lv;

    for (size_t i = 0; i < values_length; i = nexti)
    {   string value = values[i];

    // Skip dups
    for (nexti = i + 1; nexti < values_length; nexti++)
    {   nv = values[nexti];
        if (value != values[nexti])
        break;
    }

    for (size_t j = 0; j < value.length; j += std.utf.stride(value, j))
    {   string v = value[0 .. j];

        if ((nexti == values_length || j > nv.length || v != nv[0 .. j]) &&
        (lasti == values_length || j > lv.length || v != lv[0 .. j]))
        result[v] = value;
    }
    result[value] = value;
    lasti = i;
    lv = value;
    }

    return result;
}

unittest
{
    debug(string) printf("string.abbrev.unittest\n");

    string[] values;
    values ~= "hello";
    values ~= "hello";
    values ~= "he";

    string[string] r;

    r = abbrev(values);
    auto keys = r.keys.dup;
    keys.sort;

    assert(keys.length == 4);
    assert(keys[0] == "he");
    assert(keys[1] == "hel");
    assert(keys[2] == "hell");
    assert(keys[3] == "hello");

    assert(r[keys[0]] == "he");
    assert(r[keys[1]] == "hello");
    assert(r[keys[2]] == "hello");
    assert(r[keys[3]] == "hello");
}


/******************************************
 * Compute column number after string if string starts in the
 * leftmost column, which is numbered starting from 0.
 */

size_t column(S)(S str, size_t tabsize = 8) if (isSomeString!S)
{
    size_t column;

    foreach (dchar c; str)
    {
        switch (c)
        {
        case '\t':
            column = (column + tabsize) / tabsize * tabsize;
            break;

        case '\r':
        case '\n':
        case paraSep:
        case lineSep:
            column = 0;
            break;

        default:
            column++;
            break;
        }
    }
    return column;
}

unittest
{
    debug(string) printf("string.column.unittest\n");

    assert(column(cast(string) null) == 0);
    assert(column("") == 0);
    assert(column("\t") == 8);
    assert(column("abc\t") == 8);
    assert(column("12345678\t") == 16);
}

/******************************************
 * Wrap text into a paragraph.
 *
 * The input text string s is formed into a paragraph
 * by breaking it up into a sequence of lines, delineated
 * by \n, such that the number of columns is not exceeded
 * on each line.
 * The last line is terminated with a \n.
 * Params:
 *  s = text string to be wrapped
 *  columns = maximum number of _columns in the paragraph
 *  firstindent = string used to _indent first line of the paragraph
 *  indent = string to use to _indent following lines of the paragraph
 *  tabsize = column spacing of tabs
 * Returns:
 *  The resulting paragraph.
 */

S wrap(S)(S s, size_t columns = 80, S firstindent = null,
        S indent = null, size_t tabsize = 8) if (isSomeString!S)
{
    typeof(s.dup) result;
    int spaces;
    bool inword;
    bool first = true;
    size_t wordstart;

    result.length = firstindent.length + s.length;
    result.length = firstindent.length;
    result[] = firstindent[];
    auto col = column(result.idup, tabsize);
    foreach (size_t i, dchar c; s)
    {
    if (std.uni.isWhite(c))
    {
        if (inword)
        {
        if (first)
        {
            ;
        }
        else if (col + 1 + (i - wordstart) > columns)
        {
            result ~= '\n';
            result ~= indent;
            col = column(indent, tabsize);
        }
        else
        {   result ~= ' ';
            col += 1;
        }
        result ~= s[wordstart .. i];
        col += i - wordstart;
        inword = false;
        first = false;
        }
    }
    else
    {
        if (!inword)
        {
        wordstart = i;
        inword = true;
        }
    }
    }

    if (inword)
    {
    if (col + 1 + (s.length - wordstart) >= columns)
    {
        result ~= '\n';
        result ~= indent;
    }
    else if (result.length != firstindent.length)
        result ~= ' ';
    result ~= s[wordstart .. s.length];
    }
    result ~= '\n';

    return assumeUnique(result);
}

unittest
{
    debug(string) printf("string.wrap.unittest\n");

    assert(wrap(cast(string) null) == "\n");
    assert(wrap(" a b   df ") == "a b df\n");
    //writefln("'%s'", wrap(" a b   df ",3));
    assert(wrap(" a b   df ", 3) == "a b\ndf\n");
    assert(wrap(" a bc   df ", 3) == "a\nbc\ndf\n");
    //writefln("'%s'", wrap(" abcd   df ",3));
    assert(wrap(" abcd   df ", 3) == "abcd\ndf\n");
    assert(wrap("x") == "x\n");
    assert(wrap("u u") == "u u\n");
}

/******************************************
 * Removes indentation from a multi-line string or an array of single-line strings.
 *
 * This uniformly outdents the text as much as possible.
 * Whitespace-only lines are always converted to blank lines.
 *
 * A StringException will be thrown if inconsistent indentation prevents
 * the input from being outdented.
 * 
 * Works at compile-time.
 * 
 * Example:
 * ---
 * writeln(q{
 *     import std.stdio;
 *     void main() {
 *         writeln("Hello");
 *     }
 * }.outdent());
 * ---
 * 
 * Output:
 * ---
 * 
 * import std.stdio;
 * void main() {
 *     writeln("Hello");
 * }
 * 
 * ---
 * 
 */

S outdent(S)(S str) if(isSomeString!S)
{
    return str.splitLines(KeepTerminator.yes).outdent().join();
}

/// ditto
S[] outdent(S)(S[] lines) if(isSomeString!S)
{
    if (lines.empty)
    {
        return null;
    }

    static S leadingWhiteOf(S str)
    {
        return str[ 0 .. $-find!(not!(std.uni.isWhite))(str).length ];
    }

    S shortestIndent;
    foreach (i, line; lines)
    {
        auto stripped = __ctfe? line.ctfe_strip() : line.strip();

        if (stripped.empty)
        {
            lines[i] = line[line.chomp().length..$];
        }
        else
        {
            auto indent = leadingWhiteOf(line);

            // Comparing number of code units instead of code points is OK here
            // because this function throws upon inconsistent indentation.
            if (shortestIndent is null || indent.length < shortestIndent.length)
            {
                if (indent.empty) return lines;
                shortestIndent = indent;
            }
        }
    }

    foreach (i; 0..lines.length)
    {
        auto stripped = __ctfe? lines[i].ctfe_strip() : lines[i].strip();
        if (stripped.empty)
        {
            // Do nothing
        }
        else if (lines[i].startsWith(shortestIndent))
        {
            lines[i] = lines[i][shortestIndent.length..$];
        }
        else
        {
            if (__ctfe) assert(false, "outdent: Inconsistent indentation");
            else throw new StringException("outdent: Inconsistent indentation");
        }
    }

    return lines;
}

// TODO: Remove this and use std.string.strip when retro() becomes ctfe-able.
private S ctfe_strip(S)(S str) if(isSomeString!(Unqual!S))
{
    return str.stripLeft().ctfe_stripRight();
}

// TODO: Remove this and use std.string.strip when retro() becomes ctfe-able.
private S ctfe_stripRight(S)(S str) if(isSomeString!(Unqual!S))
{
    size_t endIndex = 0;
    size_t prevIndex = str.length;

    foreach_reverse (i, dchar ch; str)
    {
        if (!std.uni.isWhite(ch))
        {
            endIndex = prevIndex;
            break;
        }
        prevIndex = i;
    }

    return str[0..endIndex];
}

version(unittest)
{
    template outdent_testStr(S)
    {
        enum S outdent_testStr =
"
 \t\tX
 \t\U00010143X
 \t\t

 \t\t\tX
\t ";
    }

    template outdent_expected(S)
    {
        enum S outdent_expected =
"
\tX
\U00010143X


\t\tX
";
    }
}

unittest
{
    debug(string) printf("string.outdent.unittest\n");

    static assert(ctfe_strip(" \tHi \r\n") == "Hi");
    static assert(ctfe_strip(" \tHi&copy;\u2028 \r\n") == "Hi&copy;");
    static assert(ctfe_strip("Hi")         == "Hi");
    static assert(ctfe_strip(" \t \r\n")   == "");
    static assert(ctfe_strip("")           == "");

    foreach (S; TypeTuple!(string, wstring, dstring))
    {
        enum S blank = "";
        assert(blank.outdent() == blank);
        static assert(blank.outdent() == blank);

        enum S testStr1  = " \n \t\n ";
        enum S expected1 = "\n\n";
        assert(testStr1.outdent() == expected1);
        static assert(testStr1.outdent() == expected1);

        assert(testStr1[0..$-1].outdent() == expected1);
        static assert(testStr1[0..$-1].outdent() == expected1);

        enum S testStr2  = "a\n \t\nb";
        assert(testStr2.outdent() == testStr2);
        static assert(testStr2.outdent() == testStr2);

        enum S testStr3 =
"
 \t\tX
 \t\U00010143X
 \t\t

 \t\t\tX
\t ";

        enum S expected3 =
"
\tX
\U00010143X


\t\tX
";
        assert(testStr3.outdent() == expected3);
        static assert(testStr3.outdent() == expected3);

        enum testStr4 = "  X\r  X\n  X\r\n  X\u2028  X\u2029  X";
        enum expected4 = "X\rX\nX\r\nX\u2028X\u2029X";
        assert(testStr4.outdent() == expected4);
        static assert(testStr4.outdent() == expected4);

        enum testStr5  = testStr4[0..$-1];
        enum expected5 = expected4[0..$-1];
        assert(testStr5.outdent() == expected5);
        static assert(testStr5.outdent() == expected5);

        enum testStr6 = "  \r  \n  \r\n  \u2028  \u2029";
        enum expected6 = "\r\n\r\n\u2028\u2029";
        assert(testStr6.outdent() == expected6);
        static assert(testStr6.outdent() == expected6);
    }
}

private template hardDeprec(string vers, string date, string oldFunc, string newFunc)
{
    enum hardDeprec = Format!("Notice: As of Phobos %s, std.string.%s has been deprecated " ~
                              "It will be removed in %s. Please use %s instead.",
                              vers, oldFunc, date, newFunc);
}
