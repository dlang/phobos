// Written in the D programming language.
// Regular Expressions.

/**
 * $(RED Deprecated. It will be removed in February 2012.
 *       Please use $(LINK2 std_regex.html, std.regex) instead.)
 *
 * $(LINK2 http://www.digitalmars.com/ctg/regular.html, Regular
 * expressions) are a powerful method of string pattern matching.  The
 * regular expression language used in this library is the same as
 * that commonly used, however, some of the very advanced forms may
 * behave slightly differently. The standard observed is the $(WEB
 * www.ecma-international.org/publications/standards/Ecma-262.htm,
 * ECMA standard) for regular expressions.
 *
 * std.regexp is designed to work only with valid UTF strings as input.
 * To validate untrusted input, use std.utf.validate().
 *
 * In the following guide, $(I pattern)[] refers to a
 * $(LINK2 http://www.digitalmars.com/ctg/regular.html, regular expression).
 * The $(I attributes)[] refers to
 * a string controlling the interpretation
 * of the regular expression.
 * It consists of a sequence of one or more
 * of the following characters:
 *
 * <table border=1 cellspacing=0 cellpadding=5>
 * <caption>Attribute Characters</caption>
 * $(TR $(TH Attribute) $(TH Action))
 * <tr>
 * $(TD $(B g))
 * $(TD global; repeat over the whole input string)
 * </tr>
 * <tr>
 * $(TD $(B i))
 * $(TD case insensitive)
 * </tr>
 * <tr>
 * $(TD $(B m))
 * $(TD treat as multiple lines separated by newlines)
 * </tr>
 * </table>
 *
 * The $(I format)[] string has the formatting characters:
 *
 * <table border=1 cellspacing=0 cellpadding=5>
 * <caption>Formatting Characters</caption>
 * $(TR $(TH Format) $(TH Replaced With))
 * $(TR
 * $(TD $(B $$))    $(TD $)
 * )
 * $(TR
 * $(TD $(B $&amp;))    $(TD The matched substring.)
 * )
 * $(TR
 * $(TD $(B $`))    $(TD The portion of string that precedes the matched substring.)
 * )
 * $(TR
 * $(TD $(B $'))    $(TD The portion of string that follows the matched substring.)
 * )
 * $(TR
 * $(TD $(B $(DOLLAR))$(I n)) $(TD The $(I n)th capture, where $(I n)
 *      is a single digit 1-9
 *      and $$(I n) is not followed by a decimal digit.)
 * )
 * $(TR
 * $(TD $(B $(DOLLAR))$(I nn)) $(TD The $(I nn)th capture, where $(I nn)
 *      is a two-digit decimal
 *      number 01-99.
 *      If $(I nn)th capture is undefined or more than the number
 *      of parenthesized subexpressions, use the empty
 *      string instead.)
 * )
 * </table>
 *
 * Any other $ are left as is.
 *
 * References:
 *  $(LINK2 http://en.wikipedia.org/wiki/Regular_expressions, Wikipedia)
 * Macros:
 *  WIKI = StdRegexp
 *  DOLLAR = $
 *
 * Copyright: Copyright Digital Mars 2000 - 2011.
 * License:   <a href="http://www.boost.org/LICENSE_1_0.txt">Boost License 1.0</a>.
 * Authors:   $(WEB digitalmars.com, Walter Bright)
 * Source:    $(PHOBOSSRC std/_regexp.d)
 */
/*          Copyright Digital Mars 2000 - 2011.
 * Distributed under the Boost Software License, Version 1.0.
 *    (See accompanying file LICENSE_1_0.txt or copy at
 *          http://www.boost.org/LICENSE_1_0.txt)
 */

/*
  Escape sequences:

  \nnn starts out a 1, 2 or 3 digit octal sequence,
  where n is an octal digit. If nnn is larger than
  0377, then the 3rd digit is not part of the sequence
  and is not consumed.
  For maximal portability, use exactly 3 digits.

  \xXX starts out a 1 or 2 digit hex sequence. X
  is a hex character. If the first character after the \x
  is not a hex character, the value of the sequence is 'x'
  and the XX are not consumed.
  For maximal portability, use exactly 2 digits.

  \uUUUU is a unicode sequence. There are exactly
  4 hex characters after the \u, if any are not, then
  the value of the sequence is 'u', and the UUUU are not
  consumed.

  Character classes:

  [a-b], where a is greater than b, will produce
  an error.

  References:

  http://www.unicode.org/unicode/reports/tr18/
*/

module std.regexp;

pragma(msg, "Notice: As of Phobos 2.055, std.regexp has been deprecated. " ~
            "It will be removed in February 2012. Please use std.regex instead.");

//debug = regexp;       // uncomment to turn on debugging printf's

private
{
    import core.stdc.stdio;
    import core.stdc.stdlib;
    import core.stdc.string;
    import std.array;
    import std.stdio;
    import std.string;
    import std.ascii;
    import std.outbuffer;
    import std.bitmanip;
    import std.utf;
    import std.algorithm;
    import std.array;
    import std.traits;
}

deprecated:

/** Regular expression to extract an _email address.
 * References:
 *  $(LINK2 http://www.regular-expressions.info/email.html, How to Find or Validate an Email Address)$(BR)
 *  $(LINK2 http://tools.ietf.org/html/rfc2822#section-3.4.1, RFC 2822 Internet Message Format)
 */
string email =
    r"[a-zA-Z]([.]?([[a-zA-Z0-9_]-]+)*)?@([[a-zA-Z0-9_]\-_]+\.)+[a-zA-Z]{2,6}";

/** Regular expression to extract a _url */
string url = r"(([h|H][t|T]|[f|F])[t|T][p|P]([s|S]?)\:\/\/|~/|/)?([\w]+:\w+@)?(([a-zA-Z]{1}([\w\-]+\.)+([\w]{2,5}))(:[\d]{1,5})?)?((/?\w+/)+|/?)(\w+\.[\w]{3,4})?([,]\w+)*((\?\w+=\w+)?(&\w+=\w+)*([,]\w*)*)?";

/************************************
 * One of these gets thrown on compilation errors
 */

class RegExpException : Exception
{
    this(string msg)
    {
        super(msg);
    }
}

struct regmatch_t
{
    sizediff_t rm_so; // index of start of match
    sizediff_t rm_eo; // index past end of match
}

private alias char rchar;   // so we can make a wchar version

/******************************************************
 * Search string for matches with regular expression
 * pattern with attributes.
 * Replace each match with string generated from format.
 * Params:
 *  s = String to search.
 *  pattern = Regular expression pattern.
 *  format = Replacement string format.
 *  attributes = Regular expression attributes.
 * Returns:
 *  the resulting string
 * Example:
 *  Replace the letters 'a' with the letters 'ZZ'.
 * ---
 * s = "Strap a rocket engine on a chicken."
 * sub(s, "a", "ZZ")        // result: StrZZp a rocket engine on a chicken.
 * sub(s, "a", "ZZ", "g")   // result: StrZZp ZZ rocket engine on ZZ chicken.
 * ---
 *  The replacement format can reference the matches using
 *  the $&amp;, $$, $', $`, $0 .. $99 notation:
 * ---
 * sub(s, "[ar]", "[$&]", "g") // result: St[r][a]p [a] [r]ocket engine on [a] chi
 * ---
 */

string sub(string s, string pattern, string format, string attributes = null)
{
    auto r = new RegExp(pattern, attributes);
    auto result = r.replace(s, format);
    delete r;
    return result;
}

unittest
{
    debug(regexp) printf("regexp.sub.unittest\n");

    string r = sub("hello", "ll", "ss");
    assert(r == "hesso");
}

/*******************************************************
 * Search string for matches with regular expression
 * pattern with attributes.
 * Pass each match to delegate dg.
 * Replace each match with the return value from dg.
 * Params:
 *  s = String to search.
 *  pattern = Regular expression pattern.
 *  dg = Delegate
 *  attributes = Regular expression attributes.
 * Returns: the resulting string.
 * Example:
 * Capitalize the letters 'a' and 'r':
 * ---
 * s = "Strap a rocket engine on a chicken.";
 * sub(s, "[ar]",
 *    delegate char[] (RegExp m)
 *    {
 *         return toUpper(m[0]);
 *    },
 *    "g");    // result: StRAp A Rocket engine on A chicken.
 * ---
 */

string sub(string s, string pattern, string delegate(RegExp) dg, string attributes = null)
{
    auto r = new RegExp(pattern, attributes);

    string result = s;
    size_t lastindex = 0;
    size_t offset = 0;

    while (r.test(s, lastindex))
    {
        auto so = r.pmatch[0].rm_so;
        auto eo = r.pmatch[0].rm_eo;

        string replacement = dg(r);

        // Optimize by using std.string.replace if possible - Dave Fladebo
        string slice = result[offset + so .. offset + eo];
        if (r.attributes & RegExp.REA.global &&     // global, so replace all
                !(r.attributes & RegExp.REA.ignoreCase) &&  // not ignoring case
                !(r.attributes & RegExp.REA.multiline) &&   // not multiline
                pattern == slice)               // simple pattern (exact match, no special characters)
        {
            debug(regexp)
                printf("result: %.*s, pattern: %.*s, slice: %.*s, replacement: %.*s\n",
                        result.length,      result.ptr,
                        pattern.length,     pattern.ptr,
                        slice.length,       slice.ptr,
                        replacement.length, replacement.ptr);
            result = replace(result,slice,replacement);
            break;
        }

        result = replaceSlice(result, result[offset + so .. offset + eo], replacement);

        if (r.attributes & RegExp.REA.global)
        {
            offset += replacement.length - (eo - so);

            if (lastindex == eo)
                lastindex++;        // always consume some source
            else
                lastindex = eo;
        }
        else
            break;
    }
    delete r;

    return result;
}

unittest
{
    debug(regexp) printf("regexp.sub.unittest\n");

    string foo(RegExp r) { return "ss"; }

    auto r = sub("hello", "ll", delegate string(RegExp r) { return "ss"; });
    assert(r == "hesso");

    r = sub("hello", "l", delegate string(RegExp r) { return "l"; }, "g");
    assert(r == "hello");

    auto s = sub("Strap a rocket engine on a chicken.",
            "[ar]",
            delegate string (RegExp m)
            {
                return std.string.toUpper(m[0]);
            },
            "g");
    assert(s == "StRAp A Rocket engine on A chicken.");
}


/*************************************************
 * Search $(D_PARAM s[]) for first match with $(D_PARAM pattern).
 * Params:
 *  s = String to search.
 *  pattern = Regular expression pattern.
 * Returns:
 *  index into s[] of match if found, -1 if no match.
 * Example:
 * ---
 * auto s = "abcabcabab";
 * find(s, RegExp("b"));    // match, returns 1
 * find(s, RegExp("f"));    // no match, returns -1
 * ---
 */

sizediff_t find(string s, RegExp pattern)
{
    return pattern.test(s)
        ? pattern.pmatch[0].rm_so
        : -1;
}

unittest
{
    debug(regexp) printf("regexp.find.unittest\n");

    auto i = find("xabcy", RegExp("abc"));
    assert(i == 1);
    i = find("cba", RegExp("abc"));
    assert(i == -1);
}

/**
   Returns:

   Same as $(D_PARAM find(s, RegExp(pattern, attributes))).

   WARNING:

   This function is scheduled for deprecation due to unnecessary
   ambiguity with the homonym function in std.string. Instead of
   $(D_PARAM std.regexp.find(s, p, a)), you may want to use $(D_PARAM
   find(s, RegExp(p, a))).
*/

sizediff_t
find(string s, string pattern, string attributes = null)
{
    auto r = new RegExp(pattern, attributes);
    scope(exit) delete r;
    return r.test(s) ? r.pmatch[0].rm_so : -1;
}

unittest
{
    debug(regexp) printf("regexp.find.unittest\n");

    auto i = find("xabcy", "abc");
    assert(i == 1);
    i = find("cba", "abc");
    assert(i == -1);
}

/*************************************************
 * Search $(D_PARAM s[]) for last match with $(D_PARAM pattern).
 * Params:
 *  s = String to search.
 *  pattern = Regular expression pattern.
 * Returns:
 *  index into s[] of match if found, -1 if no match.
 * Example:
 * ---
 * auto s = "abcabcabab";
 * rfind(s, RegExp("b"));    // match, returns 9
 * rfind(s, RegExp("f"));    // no match, returns -1
 * ---
 */

sizediff_t rfind(string s, RegExp pattern)
{
    sizediff_t i = -1, lastindex = 0;

    while (pattern.test(s, lastindex))
    {
        auto eo = pattern.pmatch[0].rm_eo;
        i = pattern.pmatch[0].rm_so;
        if (lastindex == eo)
            lastindex++;        // always consume some source
        else
            lastindex = eo;
    }
    return i;
}

unittest
{
    sizediff_t i;

    debug(regexp) printf("regexp.rfind.unittest\n");
    i = rfind("abcdefcdef", RegExp("c"));
    assert(i == 6);
    i = rfind("abcdefcdef", RegExp("cd"));
    assert(i == 6);
    i = rfind("abcdefcdef", RegExp("x"));
    assert(i == -1);
    i = rfind("abcdefcdef", RegExp("xy"));
    assert(i == -1);
    i = rfind("abcdefcdef", RegExp(""));
    assert(i == 10);
}

/*************************************************
Returns:

  Same as $(D_PARAM rfind(s, RegExp(pattern, attributes))).

WARNING:

This function is scheduled for deprecation due to unnecessary
ambiguity with the homonym function in std.string. Instead of
$(D_PARAM std.regexp.rfind(s, p, a)), you may want to use $(D_PARAM
rfind(s, RegExp(p, a))).
*/

sizediff_t
rfind(string s, string pattern, string attributes = null)
{
    typeof(return) i = -1, lastindex = 0;

    auto r = new RegExp(pattern, attributes);
    while (r.test(s, lastindex))
    {
        auto eo = r.pmatch[0].rm_eo;
        i = r.pmatch[0].rm_so;
        if (lastindex == eo)
            lastindex++;        // always consume some source
        else
            lastindex = eo;
    }
    delete r;
    return i;
}

unittest
{
    sizediff_t i;

    debug(regexp) printf("regexp.rfind.unittest\n");
    i = rfind("abcdefcdef", "c");
    assert(i == 6);
    i = rfind("abcdefcdef", "cd");
    assert(i == 6);
    i = rfind("abcdefcdef", "x");
    assert(i == -1);
    i = rfind("abcdefcdef", "xy");
    assert(i == -1);
    i = rfind("abcdefcdef", "");
    assert(i == 10);
}


/********************************************
 * Split s[] into an array of strings, using the regular
 * expression $(D_PARAM pattern) as the separator.
 * Params:
 *  s = String to search.
 *  pattern = Regular expression pattern.
 * Returns:
 *  array of slices into s[]
 * Example:
 * ---
 * foreach (s; split("abcabcabab", RegExp("C.", "i")))
 * {
 *     writefln("s = '%s'", s);
 * }
 * // Prints:
 * // s = 'ab'
 * // s = 'b'
 * // s = 'bab'
 * ---
 */

string[] split(string s, RegExp pattern)
{
    return pattern.split(s);
}

unittest
{
    debug(regexp) printf("regexp.split.unittest()\n");
    string[] result;

    result = split("ab", RegExp("a*"));
    assert(result.length == 2);
    assert(result[0] == "");
    assert(result[1] == "b");

    foreach (i, s; split("abcabcabab", RegExp("C.", "i")))
    {
        //writefln("s[%d] = '%s'", i, s);
        if (i == 0) assert(s == "ab");
        else if (i == 1) assert(s == "b");
        else if (i == 2) assert(s == "bab");
        else assert(0);
    }
}

/********************************************
  Returns:
    Same as $(D_PARAM split(s, RegExp(pattern, attributes))).

WARNING:

This function is scheduled for deprecation due to unnecessary
ambiguity with the homonym function in std.string. Instead of
$(D_PARAM std.regexp.split(s, p, a)), you may want to use $(D_PARAM
split(s, RegExp(p, a))).
*/

string[] split(string s, string pattern, string attributes = null)
{
    auto r = new RegExp(pattern, attributes);
    auto result = r.split(s);
    delete r;
    return result;
}

unittest
{
    debug(regexp) printf("regexp.split.unittest()\n");
    string[] result;

    result = split("ab", "a*");
    assert(result.length == 2);
    assert(result[0] == "");
    assert(result[1] == "b");

    foreach (i, s; split("abcabcabab", "C.", "i"))
    {
        //writefln("s[%d] = '%s'", i, s.length, s.ptr);
        if (i == 0) assert(s == "ab");
        else if (i == 1) assert(s == "b");
        else if (i == 2) assert(s == "bab");
        else assert(0);
    }
}

/****************************************************
 * Search s[] for first match with pattern[] with attributes[].
 * Params:
 *  s = String to search.
 *  pattern = Regular expression pattern.
 *  attributes = Regular expression attributes.
 * Returns:
 *  corresponding RegExp if found, null if not.
 * Example:
 * ---
 * import std.stdio;
 * import std.regexp;
 *
 * void main()
 * {
 *     if (auto m = std.regexp.search("abcdef", "c"))
 *     {
 *         writefln("%s[%s]%s", m.pre, m[0], m.post);
 *     }
 * }
 * // Prints:
 * // ab[c]def
 * ---
 */

RegExp search(string s, string pattern, string attributes = null)
{
    auto r = new RegExp(pattern, attributes);
    if (!r.test(s))
    {   delete r;
        assert(r is null);
    }
    return r;
}

unittest
{
    debug(regexp) printf("regexp.string.unittest()\n");

    if (auto m = std.regexp.search("abcdef", "c()"))
    {
        auto result = std.string.format("%s[%s]%s", m.pre, m[0], m.post);
        assert(result == "ab[c]def");
        assert(m[1] == null);
        assert(m[2] == null);
    }
    else
    assert(0);

    if (auto n = std.regexp.search("abcdef", "g"))
    {
        assert(0);
    }
}

/* ********************************* RegExp ******************************** */

/*****************************
 * RegExp is a class to handle regular expressions.
 *
 * It is the core foundation for adding powerful string pattern matching
 * capabilities to programs like grep, text editors, awk, sed, etc.
 */
class RegExp
{
    /*****
     * Construct a RegExp object. Compile pattern
     * with <i>attributes</i> into
     * an internal form for fast execution.
     * Params:
     *  pattern = regular expression
     *  attributes = _attributes
     * Throws: RegExpException if there are any compilation errors.
     * Example:
     *  Declare two variables and assign to them a RegExp object:
     * ---
     * auto r = new RegExp("pattern");
     * auto s = new RegExp(r"p[1-5]\s*");
     * ---
     */
    public this(string pattern, string attributes = null)
    {
        pmatch = (&gmatch)[0 .. 1];
        compile(pattern, attributes);
    }

    /*****
     * Generate instance of RegExp.
     * Params:
     *  pattern = regular expression
     *  attributes = _attributes
     * Throws: RegExpException if there are any compilation errors.
     * Example:
     *  Declare two variables and assign to them a RegExp object:
     * ---
     * auto r = RegExp("pattern");
     * auto s = RegExp(r"p[1-5]\s*");
     * ---
     */
    public static RegExp opCall(string pattern, string attributes = null)
    {
        return new RegExp(pattern, attributes);
    }

    unittest
    {
        debug(regexp) printf("regexp.opCall.unittest()\n");
        auto r1 = RegExp("hello", "m");
        string msg;
        try
        {
            auto r2 = RegExp("hello", "q");
            assert(0);
        }
        catch (RegExpException ree)
        {
            msg = ree.toString();
            //writefln("message: %s", ree);
        }
        assert(std.algorithm.countUntil(msg, "unrecognized attribute") >= 0);
    }

    /************************************
     * Set up for start of foreach loop.
     * Returns:
     *  search() returns instance of RegExp set up to _search string[].
     * Example:
     * ---
     * import std.stdio;
     * import std.regexp;
     *
     * void main()
     * {
     *     foreach(m; RegExp("ab").search("abcabcabab"))
     *     {
     *         writefln("%s[%s]%s", m.pre, m[0], m.post);
     *     }
     * }
     * // Prints:
     * // [ab]cabcabab
     * // abc[ab]cabab
     * // abcabc[ab]ab
     * // abcabcab[ab]
     * ---
     */

    public RegExp search(string string)
    {
        input = string;
        pmatch[0].rm_eo = 0;
        return this;
    }

    /** ditto */
    public int opApply(scope int delegate(ref RegExp) dg)
    {
        int result;
        RegExp r = this;

        while (test())
        {
            result = dg(r);
            if (result)
                break;
        }

        return result;
    }

    unittest
    {
        debug(regexp) printf("regexp.search.unittest()\n");

        int i;
        foreach(m; RegExp("ab").search("abcabcabab"))
        {
            auto s = std.string.format("%s[%s]%s", m.pre, m[0], m.post);
            if (i == 0) assert(s == "[ab]cabcabab");
            else if (i == 1) assert(s == "abc[ab]cabab");
            else if (i == 2) assert(s == "abcabc[ab]ab");
            else if (i == 3) assert(s == "abcabcab[ab]");
            else assert(0);
            i++;
        }
    }

    /******************
     * Retrieve match n.
     *
     * n==0 means the matched substring, n>0 means the
     * n'th parenthesized subexpression.
     * if n is larger than the number of parenthesized subexpressions,
     * null is returned.
     */
    public string opIndex(size_t n)
    {
        if (n >= pmatch.length)
            return null;
        else
        {
            auto rm_so = pmatch[n].rm_so;
            auto rm_eo = pmatch[n].rm_eo;
            if (rm_so == rm_eo)
                return null;
            return input[rm_so .. rm_eo];
        }
    }

    /**
       Same as $(D_PARAM opIndex(n)).

       WARNING:

       Scheduled for deprecation due to confusion with overloaded
       $(D_PARAM match(string)). Instead of $(D_PARAM regex.match(n))
       you may want to use $(D_PARAM regex[n]).
    */
    public string match(size_t n)
    {
        return this[n];
    }

    /*******************
     * Return the slice of the input that precedes the matched substring.
     */
    public string pre()
    {
        return input[0 .. pmatch[0].rm_so];
    }

    /*******************
     * Return the slice of the input that follows the matched substring.
     */
    public string post()
    {
        return input[pmatch[0].rm_eo .. $];
    }

    uint re_nsub;       // number of parenthesized subexpression matches
    regmatch_t[] pmatch;    // array [re_nsub + 1]

    string input;       // the string to search

    // per instance:

    string pattern;     // source text of the regular expression

    string flags;       // source text of the attributes parameter

    int errors;

    uint attributes;

    enum REA
    {
        global      = 1,    // has the g attribute
            ignoreCase  = 2,    // has the i attribute
            multiline   = 4,    // if treat as multiple lines separated
        // by newlines, or as a single line
            dotmatchlf  = 8,    // if . matches \n
            }


private:
    size_t src;         // current source index in input[]
    size_t src_start;       // starting index for match in input[]
    size_t p;           // position of parser in pattern[]
    regmatch_t gmatch;      // match for the entire regular expression
    // (serves as storage for pmatch[0])

    const(ubyte)[] program; // pattern[] compiled into regular expression program
    OutBuffer buf;




/******************************************/

// Opcodes

    enum : ubyte
    {
        REend,      // end of program
            REchar,     // single character
            REichar,        // single character, case insensitive
            REdchar,        // single UCS character
            REidchar,       // single wide character, case insensitive
            REanychar,      // any character
            REanystar,      // ".*"
            REstring,       // string of characters
            REistring,      // string of characters, case insensitive
            REtestbit,      // any in bitmap, non-consuming
            REbit,      // any in the bit map
            REnotbit,       // any not in the bit map
            RErange,        // any in the string
            REnotrange,     // any not in the string
            REor,       // a | b
            REplus,     // 1 or more
            REstar,     // 0 or more
            REquest,        // 0 or 1
            REnm,       // n..m
            REnmq,      // n..m, non-greedy version
            REbol,      // beginning of line
            REeol,      // end of line
            REparen,        // parenthesized subexpression
            REgoto,     // goto offset

            REwordboundary,
            REnotwordboundary,
            REdigit,
            REnotdigit,
            REspace,
            REnotspace,
            REword,
            REnotword,
            REbackref,
            };

// BUG: should this include '$'?
    private int isword(dchar c) { return isAlphaNum(c) || c == '_'; }

    private uint inf = ~0u;

/* ********************************
 * Throws RegExpException on error
 */

    public void compile(string pattern, string attributes)
    {
        //printf("RegExp.compile('%.*s', '%.*s')\n", pattern.length, pattern.ptr, attributes.length, attributes.ptr);

        this.attributes = 0;
        foreach (rchar c; attributes)
        {   REA att;

            switch (c)
            {
            case 'g': att = REA.global;     break;
            case 'i': att = REA.ignoreCase; break;
            case 'm': att = REA.multiline;  break;
            default:
                error("unrecognized attribute");
                return;
            }
            if (this.attributes & att)
            {   error("redundant attribute");
                return;
            }
            this.attributes |= att;
        }

        input = null;

        this.pattern = pattern;
        this.flags = attributes;

        uint oldre_nsub = re_nsub;
        re_nsub = 0;
        errors = 0;

        buf = new OutBuffer();
        buf.reserve(pattern.length * 8);
        p = 0;
        parseRegexp();
        if (p < pattern.length)
        {   error("unmatched ')'");
        }
        // @@@ SKIPPING OPTIMIZATION SOLVES BUG 941 @@@
        //optimize();
        program = buf.data;
        buf.data = null;
        delete buf;

        if (re_nsub > oldre_nsub)
        {
            if (pmatch.ptr is &gmatch)
                pmatch = null;
            pmatch.length = re_nsub + 1;
        }
        pmatch[0].rm_so = 0;
        pmatch[0].rm_eo = 0;
    }

/********************************************
 * Split s[] into an array of strings, using the regular
 * expression as the separator.
 * Returns:
 *  array of slices into s[]
 */

    public string[] split(string s)
    {
        debug(regexp) printf("regexp.split()\n");

        string[] result;

        if (s.length)
        {
            sizediff_t p, q;
            for (q = p; q != s.length;)
            {
                if (test(s, q))
                {
                    q = pmatch[0].rm_so;
                    auto e = pmatch[0].rm_eo;
                    if (e != p)
                    {
                        result ~= s[p .. q];
                        for (size_t i = 1; i < pmatch.length; i++)
                        {
                            auto so = pmatch[i].rm_so;
                            auto eo = pmatch[i].rm_eo;
                            if (so == eo)
                            {   so = 0; // -1 gives array bounds error
                                eo = 0;
                            }
                            result ~= s[so .. eo];
                        }
                        q = p = e;
                        continue;
                    }
                }
                q++;
            }
            result ~= s[p .. s.length];
        }
        else if (!test(s))
            result ~= s;
        return result;
    }

    unittest
    {
        debug(regexp) printf("regexp.split.unittest()\n");

        auto r = new RegExp("a*?", null);
        string[] result;
        string j;
        int i;

        result = r.split("ab");

        assert(result.length == 2);
        i = std.string.cmp(result[0], "a");
        assert(i == 0);
        i = std.string.cmp(result[1], "b");
        assert(i == 0);

        r = new RegExp("a*", null);
        result = r.split("ab");
        assert(result.length == 2);
        i = std.string.cmp(result[0], "");
        assert(i == 0);
        i = std.string.cmp(result[1], "b");
        assert(i == 0);

        r = new RegExp("<(\\/)?([^<>]+)>", null);
        result = r.split("a<b>font</b>bar<TAG>hello</TAG>");

        debug(regexp)
        {
            for (i = 0; i < result.length; i++)
                printf("result[%d] = '%.*s'\n", i, result[i].length, result[i].ptr);
        }

        j = join(result, ",");
        //printf("j = '%.*s'\n", j.length, j.ptr);
        i = std.string.cmp(j, "a,,b,font,/,b,bar,,TAG,hello,/,TAG,");
        assert(i == 0);

        r = new RegExp("a[bc]", null);
        result = r.match("123ab");
        j = join(result, ",");
        i = std.string.cmp(j, "ab");
        assert(i == 0);

        result = r.match("ac");
        j = join(result, ",");
        i = std.string.cmp(j, "ac");
        assert(i == 0);
    }

/*************************************************
 * Search string[] for match with regular expression.
 * Returns:
 *  index of match if successful, -1 if not found
 */

    public sizediff_t find(string string)
    {
        if (test(string))
            return pmatch[0].rm_so;
        else
            return -1;         // no match
    }

//deprecated alias find search;

    unittest
    {
        debug(regexp) printf("regexp.find.unittest()\n");

        RegExp r = new RegExp("abc", null);
        auto i = r.find("xabcy");
        assert(i == 1);
        i = r.find("cba");
        assert(i == -1);
    }


/*************************************************
 * Search s[] for match.
 * Returns:
 *  If global attribute, return same value as exec(s).
 *  If not global attribute, return array of all matches.
 */

    public string[] match(string s)
    {
        string[] result;

        if (attributes & REA.global)
        {
            sizediff_t lastindex = 0;

            while (test(s, lastindex))
            {
                auto eo = pmatch[0].rm_eo;

                result ~= input[pmatch[0].rm_so .. eo];
                if (lastindex == eo)
                    lastindex++;        // always consume some source
                else
                    lastindex = eo;
            }
        }
        else
        {
            result = exec(s);
        }
        return result;
    }

    unittest
    {
        debug(regexp) printf("regexp.match.unittest()\n");

        int i;
        string[] result;
        string j;
        RegExp r;

        r = new RegExp("a[bc]", null);
        result = r.match("1ab2ac3");
        j = join(result, ",");
        i = std.string.cmp(j, "ab");
        assert(i == 0);

        r = new RegExp("a[bc]", "g");
        result = r.match("1ab2ac3");
        j = join(result, ",");
        i = std.string.cmp(j, "ab,ac");
        assert(i == 0);
    }


/*************************************************
 * Find regular expression matches in s[]. Replace those matches
 * with a new string composed of format[] merged with the result of the
 * matches.
 * If global, replace all matches. Otherwise, replace first match.
 * Returns: the new string
 */

    public string replace(string s, string format)
    {
        debug(regexp) printf("string = %.*s, format = %.*s\n", s.length, s.ptr, format.length, format.ptr);

        string result = s;
        sizediff_t lastindex = 0;
        size_t offset = 0;

        for (;;)
        {
            if (!test(s, lastindex))
                break;

            auto so = pmatch[0].rm_so;
            auto eo = pmatch[0].rm_eo;

            string replacement = replace(format);

            // Optimize by using replace if possible - Dave Fladebo
            string slice = result[offset + so .. offset + eo];
            if (attributes & REA.global &&      // global, so replace all
                    !(attributes & REA.ignoreCase) &&   // not ignoring case
                    !(attributes & REA.multiline) &&    // not multiline
                    pattern == slice &&         // simple pattern (exact match, no special characters)
                    format == replacement)      // simple format, not $ formats
            {
                debug(regexp)
                {
                    auto sss = result[offset + so .. offset + eo];
                    printf("pattern: %.*s, slice: %.*s, format: %.*s, replacement: %.*s\n",
                            pattern.length, pattern.ptr, sss.length, sss.ptr, format.length, format.ptr, replacement.length, replacement.ptr);
                }
                result = std.array.replace(result,slice,replacement);
                break;
            }

            result = replaceSlice(result, result[offset + so .. offset + eo], replacement);

            if (attributes & REA.global)
            {
                offset += replacement.length - (eo - so);

                if (lastindex == eo)
                    lastindex++;        // always consume some source
                else
                    lastindex = eo;
            }
            else
                break;
        }

        return result;
    }

    unittest
    {
        debug(regexp) printf("regexp.replace.unittest()\n");

        int i;
        string result;
        RegExp r;

        r = new RegExp("a[bc]", "g");
        result = r.replace("1ab2ac3", "x$&y");
        i = std.string.cmp(result, "1xaby2xacy3");
        assert(i == 0);

        r = new RegExp("ab", "g");
        result = r.replace("1ab2ac3", "xy");
        i = std.string.cmp(result, "1xy2ac3");
        assert(i == 0);
    }


/*************************************************
 * Search string[] for match.
 * Returns:
 *  array of slices into string[] representing matches
 */

    public string[] exec(string s)
    {
        debug(regexp) printf("regexp.exec(string = '%.*s')\n", s.length, s.ptr);
        input = s;
        pmatch[0].rm_so = 0;
        pmatch[0].rm_eo = 0;
        return exec();
    }

/*************************************************
 * Pick up where last exec(string) or exec() left off,
 * searching string[] for next match.
 * Returns:
 *  array of slices into string[] representing matches
 */

    public string[] exec()
    {
        if (!test())
            return null;

        auto result = new string[pmatch.length];
        for (int i = 0; i < pmatch.length; i++)
        {
            if (pmatch[i].rm_so == pmatch[i].rm_eo)
                result[i] = null;
            else
                result[i] = input[pmatch[i].rm_so .. pmatch[i].rm_eo];
        }

        return result;
    }

/************************************************
 * Search s[] for match.
 * Returns: 0 for no match, !=0 for match
 * Example:
---
import std.stdio;
import std.regexp;
import std.string;

int grep(int delegate(char[]) pred, char[][] list)
{
  int count;
  foreach (s; list)
  {  if (pred(s))
       ++count;
  }
  return count;
}

void main()
{
  auto x = grep(&RegExp("[Ff]oo").test,
                std.string.split("mary had a foo lamb"));
  writefln(x);
}
---
* which prints: 1
*/
                //@@@
public bool test(string s)
    {
        return test(s, 0 /*pmatch[0].rm_eo*/) != 0;
    }

/************************************************
 * Pick up where last test(string) or test() left off, and search again.
 * Returns: 0 for no match, !=0 for match
 */

    public int test()
    {
        return test(input, pmatch[0].rm_eo);
    }

/************************************************
 * Test s[] starting at startindex against regular expression.
 * Returns: 0 for no match, !=0 for match
 */

    public int test(string s, size_t startindex)
    {
        char firstc;

        input = s;
        debug (regexp) printf("RegExp.test(input[] = '%.*s', startindex = %zd)\n", input.length, input.ptr, startindex);
        pmatch[0].rm_so = 0;
        pmatch[0].rm_eo = 0;
        if (startindex < 0 || startindex > input.length)
        {
            return 0;           // fail
        }
        //debug(regexp) printProgram(program);

        // First character optimization
        firstc = 0;
        if (program[0] == REchar)
        {
            firstc = program[1];
            if (attributes & REA.ignoreCase && isAlpha(firstc))
                firstc = 0;
        }

        for (auto si = startindex; ; si++)
        {
            if (firstc)
            {
                if (si == input.length)
                    break;          // no match
                if (input[si] != firstc)
                {
                    si++;
                    if (!chr(si, firstc))   // if first character not found
                        break;      // no match
                }
            }
            for (size_t i = 0; i < re_nsub + 1; i++)
            {
                pmatch[i].rm_so = -1;
                pmatch[i].rm_eo = -1;
            }
            src_start = src = si;
            if (trymatch(0, program.length))
            {
                pmatch[0].rm_so = si;
                pmatch[0].rm_eo = src;
                //debug(regexp) printf("start = %d, end = %d\n", gmatch.rm_so, gmatch.rm_eo);
                return 1;
            }
            // If possible match must start at beginning, we are done
            if (program[0] == REbol || program[0] == REanystar)
            {
                if (attributes & REA.multiline)
                {
                    // Scan for the next \n
                    if (!chr(si, '\n'))
                        break;      // no match if '\n' not found
                }
                else
                    break;
            }
            if (si == input.length)
                break;
            debug(regexp)
            {
                auto sss = input[si + 1 .. input.length];
                printf("Starting new try: '%.*s'\n", sss.length, sss.ptr);
            }
        }
        return 0;       // no match
    }

    /**
       Returns whether string $(D_PARAM s) matches $(D_PARAM this).
    */
    alias test opEquals;
//     bool opEquals(string s)
//     {
//         return test(s);
//     }

    unittest
    {
        assert("abc" == RegExp(".b."));
        assert("abc" != RegExp(".b.."));
    }

    int chr(ref size_t si, rchar c)
    {
        for (; si < input.length; si++)
        {
            if (input[si] == c)
                return 1;
        }
        return 0;
    }


    void printProgram(const(ubyte)[] prog)
    {
        //debug(regexp)
        {
            size_t len;
            uint n;
            uint m;
            ushort *pu;
            uint *puint;
            char[] str;

            printf("printProgram()\n");
            for (size_t pc = 0; pc < prog.length; )
            {
                printf("%3d: ", pc);

                //printf("prog[pc] = %d, REchar = %d, REnmq = %d\n", prog[pc], REchar, REnmq);
                switch (prog[pc])
                {
                case REchar:
                    printf("\tREchar '%c'\n", prog[pc + 1]);
                    pc += 1 + char.sizeof;
                    break;

                case REichar:
                    printf("\tREichar '%c'\n", prog[pc + 1]);
                    pc += 1 + char.sizeof;
                    break;

                case REdchar:
                    printf("\tREdchar '%c'\n", *cast(dchar *)&prog[pc + 1]);
                    pc += 1 + dchar.sizeof;
                    break;

                case REidchar:
                    printf("\tREidchar '%c'\n", *cast(dchar *)&prog[pc + 1]);
                    pc += 1 + dchar.sizeof;
                    break;

                case REanychar:
                    printf("\tREanychar\n");
                    pc++;
                    break;

                case REstring:
                    len = *cast(size_t *)&prog[pc + 1];
                    str = (cast(char*)&prog[pc + 1 + size_t.sizeof])[0 .. len];
                    printf("\tREstring x%x, '%.*s'\n", len, str.length, str.ptr);
                    pc += 1 + size_t.sizeof + len * rchar.sizeof;
                    break;

                case REistring:
                    len = *cast(size_t *)&prog[pc + 1];
                    str = (cast(char*)&prog[pc + 1 + size_t.sizeof])[0 .. len];
                    printf("\tREistring x%x, '%.*s'\n", len, str.length, str.ptr);
                    pc += 1 + size_t.sizeof + len * rchar.sizeof;
                    break;

                case REtestbit:
                    pu = cast(ushort *)&prog[pc + 1];
                    printf("\tREtestbit %d, %d\n", pu[0], pu[1]);
                    len = pu[1];
                    pc += 1 + 2 * ushort.sizeof + len;
                    break;

                case REbit:
                    pu = cast(ushort *)&prog[pc + 1];
                    len = pu[1];
                    printf("\tREbit cmax=%02x, len=%d:", pu[0], len);
                    for (n = 0; n < len; n++)
                        printf(" %02x", prog[pc + 1 + 2 * ushort.sizeof + n]);
                    printf("\n");
                    pc += 1 + 2 * ushort.sizeof + len;
                    break;

                case REnotbit:
                    pu = cast(ushort *)&prog[pc + 1];
                    printf("\tREnotbit %d, %d\n", pu[0], pu[1]);
                    len = pu[1];
                    pc += 1 + 2 * ushort.sizeof + len;
                    break;

                case RErange:
                    len = *cast(uint *)&prog[pc + 1];
                    printf("\tRErange %d\n", len);
                    // BUG: REAignoreCase?
                    pc += 1 + uint.sizeof + len;
                    break;

                case REnotrange:
                    len = *cast(uint *)&prog[pc + 1];
                    printf("\tREnotrange %d\n", len);
                    // BUG: REAignoreCase?
                    pc += 1 + uint.sizeof + len;
                    break;

                case REbol:
                    printf("\tREbol\n");
                    pc++;
                    break;

                case REeol:
                    printf("\tREeol\n");
                    pc++;
                    break;

                case REor:
                    len = *cast(uint *)&prog[pc + 1];
                    printf("\tREor %d, pc=>%d\n", len, pc + 1 + uint.sizeof + len);
                    pc += 1 + uint.sizeof;
                    break;

                case REgoto:
                    len = *cast(uint *)&prog[pc + 1];
                    printf("\tREgoto %d, pc=>%d\n", len, pc + 1 + uint.sizeof + len);
                    pc += 1 + uint.sizeof;
                    break;

                case REanystar:
                    printf("\tREanystar\n");
                    pc++;
                    break;

                case REnm:
                case REnmq:
                    // len, n, m, ()
                    puint = cast(uint *)&prog[pc + 1];
                    len = puint[0];
                    n = puint[1];
                    m = puint[2];
                    printf("\tREnm%s len=%d, n=%u, m=%u, pc=>%d\n",
                            (prog[pc] == REnmq) ? "q".ptr : " ".ptr,
                            len, n, m, pc + 1 + uint.sizeof * 3 + len);
                    pc += 1 + uint.sizeof * 3;
                    break;

                case REparen:
                    // len, n, ()
                    puint = cast(uint *)&prog[pc + 1];
                    len = puint[0];
                    n = puint[1];
                    printf("\tREparen len=%d n=%d, pc=>%d\n", len, n, pc + 1 + uint.sizeof * 2 + len);
                    pc += 1 + uint.sizeof * 2;
                    break;

                case REend:
                    printf("\tREend\n");
                    return;

                case REwordboundary:
                    printf("\tREwordboundary\n");
                    pc++;
                    break;

                case REnotwordboundary:
                    printf("\tREnotwordboundary\n");
                    pc++;
                    break;

                case REdigit:
                    printf("\tREdigit\n");
                    pc++;
                    break;

                case REnotdigit:
                    printf("\tREnotdigit\n");
                    pc++;
                    break;

                case REspace:
                    printf("\tREspace\n");
                    pc++;
                    break;

                case REnotspace:
                    printf("\tREnotspace\n");
                    pc++;
                    break;

                case REword:
                    printf("\tREword\n");
                    pc++;
                    break;

                case REnotword:
                    printf("\tREnotword\n");
                    pc++;
                    break;

                case REbackref:
                    printf("\tREbackref %d\n", prog[1]);
                    pc += 2;
                    break;

                default:
                    assert(0);
                }
            }
        }
    }


/**************************************************
 * Match input against a section of the program[].
 * Returns:
 *  1 if successful match
 *  0 no match
 */

    int trymatch(size_t pc, size_t pcend)
    {
        size_t len;
        size_t n;
        size_t m;
        size_t count;
        size_t pop;
        size_t ss;
        regmatch_t *psave;
        size_t c1;
        size_t c2;
        ushort* pu;
        uint* puint;

        debug(regexp)
        {
            auto sss = input[src .. input.length];
            printf("RegExp.trymatch(pc = %zd, src = '%.*s', pcend = %zd)\n", pc, sss.length, sss.ptr, pcend);
        }
        auto srcsave = src;
        psave = null;
        for (;;)
        {
            if (pc == pcend)        // if done matching
            {   debug(regex) printf("\tprogend\n");
                return 1;
            }

            //printf("\top = %d\n", program[pc]);
            switch (program[pc])
            {
            case REchar:
                if (src == input.length)
                    goto Lnomatch;
                debug(regexp) printf("\tREchar '%c', src = '%c'\n", program[pc + 1], input[src]);
                if (program[pc + 1] != input[src])
                    goto Lnomatch;
                src++;
                pc += 1 + char.sizeof;
                break;

            case REichar:
                if (src == input.length)
                    goto Lnomatch;
                debug(regexp) printf("\tREichar '%c', src = '%c'\n", program[pc + 1], input[src]);
                c1 = program[pc + 1];
                c2 = input[src];
                if (c1 != c2)
                {
                    if (isLower(cast(rchar)c2))
                        c2 = std.ascii.toUpper(cast(rchar)c2);
                    else
                        goto Lnomatch;
                    if (c1 != c2)
                        goto Lnomatch;
                }
                src++;
                pc += 1 + char.sizeof;
                break;

            case REdchar:
                debug(regexp) printf("\tREdchar '%c', src = '%c'\n", *(cast(dchar *)&program[pc + 1]), input[src]);
                if (src == input.length)
                    goto Lnomatch;
                if (*(cast(dchar *)&program[pc + 1]) != input[src])
                    goto Lnomatch;
                src++;
                pc += 1 + dchar.sizeof;
                break;

            case REidchar:
                debug(regexp) printf("\tREidchar '%c', src = '%c'\n", *(cast(dchar *)&program[pc + 1]), input[src]);
                if (src == input.length)
                    goto Lnomatch;
                c1 = *(cast(dchar *)&program[pc + 1]);
                c2 = input[src];
                if (c1 != c2)
                {
                    if (isLower(cast(rchar)c2))
                        c2 = std.ascii.toUpper(cast(rchar)c2);
                    else
                        goto Lnomatch;
                    if (c1 != c2)
                        goto Lnomatch;
                }
                src++;
                pc += 1 + dchar.sizeof;
                break;

            case REanychar:
                debug(regexp) printf("\tREanychar\n");
                if (src == input.length)
                    goto Lnomatch;
                if (!(attributes & REA.dotmatchlf) && input[src] == cast(rchar)'\n')
                    goto Lnomatch;
                src += std.utf.stride(input, src);
                //src++;
                pc++;
                break;

            case REstring:
                len = *cast(size_t *)&program[pc + 1];
                debug(regexp)
                {
                    auto sss2 = (&program[pc + 1 + size_t.sizeof])[0 .. len];
                    printf("\tREstring x%x, '%.*s'\n", len, sss2.length, sss2.ptr);
                }
                if (src + len > input.length)
                    goto Lnomatch;
                if (memcmp(&program[pc + 1 + size_t.sizeof], &input[src], len * rchar.sizeof))
                    goto Lnomatch;
                src += len;
                pc += 1 + size_t.sizeof + len * rchar.sizeof;
                break;

            case REistring:
                len = *cast(size_t *)&program[pc + 1];
                debug(regexp)
                {
                    auto sss2 = (&program[pc + 1 + size_t.sizeof])[0 .. len];
                    printf("\tREistring x%x, '%.*s'\n", len, sss2.length, sss2.ptr);
                }
                if (src + len > input.length)
                    goto Lnomatch;
                if (icmp((cast(char*)&program[pc + 1 + size_t.sizeof])[0..len],
                                input[src .. src + len]))
                    goto Lnomatch;
                src += len;
                pc += 1 + size_t.sizeof + len * rchar.sizeof;
                break;

            case REtestbit:
                pu = (cast(ushort *)&program[pc + 1]);
                if (src == input.length)
                    goto Lnomatch;
                debug(regexp) printf("\tREtestbit %d, %d, '%c', x%02x\n",
                        pu[0], pu[1], input[src], input[src]);
                len = pu[1];
                c1 = input[src];
                //printf("[x%02x]=x%02x, x%02x\n", c1 >> 3, ((&program[pc + 1 + 4])[c1 >> 3] ), (1 << (c1 & 7)));
                if (c1 <= pu[0] &&
                        !((&(program[pc + 1 + 4]))[c1 >> 3] & (1 << (c1 & 7))))
                    goto Lnomatch;
                pc += 1 + 2 * ushort.sizeof + len;
                break;

            case REbit:
                pu = (cast(ushort *)&program[pc + 1]);
                if (src == input.length)
                    goto Lnomatch;
                debug(regexp) printf("\tREbit %d, %d, '%c'\n",
                        pu[0], pu[1], input[src]);
                len = pu[1];
                c1 = input[src];
                if (c1 > pu[0])
                    goto Lnomatch;
                if (!((&program[pc + 1 + 4])[c1 >> 3] & (1 << (c1 & 7))))
                    goto Lnomatch;
                src++;
                pc += 1 + 2 * ushort.sizeof + len;
                break;

            case REnotbit:
                pu = (cast(ushort *)&program[pc + 1]);
                if (src == input.length)
                    goto Lnomatch;
                debug(regexp) printf("\tREnotbit %d, %d, '%c'\n",
                        pu[0], pu[1], input[src]);
                len = pu[1];
                c1 = input[src];
                if (c1 <= pu[0] &&
                        ((&program[pc + 1 + 4])[c1 >> 3] & (1 << (c1 & 7))))
                    goto Lnomatch;
                src++;
                pc += 1 + 2 * ushort.sizeof + len;
                break;

            case RErange:
                len = *cast(uint *)&program[pc + 1];
                debug(regexp) printf("\tRErange %d\n", len);
                if (src == input.length)
                    goto Lnomatch;
                // BUG: REA.ignoreCase?
                if (memchr(cast(char*)&program[pc + 1 + uint.sizeof], input[src], len) == null)
                    goto Lnomatch;
                src++;
                pc += 1 + uint.sizeof + len;
                break;

            case REnotrange:
                len = *cast(uint *)&program[pc + 1];
                debug(regexp) printf("\tREnotrange %d\n", len);
                if (src == input.length)
                    goto Lnomatch;
                // BUG: REA.ignoreCase?
                if (memchr(cast(char*)&program[pc + 1 + uint.sizeof], input[src], len) != null)
                    goto Lnomatch;
                src++;
                pc += 1 + uint.sizeof + len;
                break;

            case REbol:
                debug(regexp) printf("\tREbol\n");
                if (src == 0)
                {
                }
                else if (attributes & REA.multiline)
                {
                    if (input[src - 1] != '\n')
                        goto Lnomatch;
                }
                else
                    goto Lnomatch;
                pc++;
                break;

            case REeol:
                debug(regexp) printf("\tREeol\n");
                if (src == input.length)
                {
                }
                else if (attributes & REA.multiline && input[src] == '\n')
                    src++;
                else
                    goto Lnomatch;
                pc++;
                break;

            case REor:
                len = (cast(uint *)&program[pc + 1])[0];
                debug(regexp) printf("\tREor %d\n", len);
                pop = pc + 1 + uint.sizeof;
                ss = src;
                if (trymatch(pop, pcend))
                {
                    if (pcend != program.length)
                    {
                        auto s = src;
                        if (trymatch(pcend, program.length))
                        {   debug(regexp) printf("\tfirst operand matched\n");
                            src = s;
                            return 1;
                        }
                        else
                        {
                            // If second branch doesn't match to end, take first anyway
                            src = ss;
                            if (!trymatch(pop + len, program.length))
                            {
                                debug(regexp) printf("\tfirst operand matched\n");
                                src = s;
                                return 1;
                            }
                        }
                        src = ss;
                    }
                    else
                    {   debug(regexp) printf("\tfirst operand matched\n");
                        return 1;
                    }
                }
                pc = pop + len;     // proceed with 2nd branch
                break;

            case REgoto:
                debug(regexp) printf("\tREgoto\n");
                len = (cast(uint *)&program[pc + 1])[0];
                pc += 1 + uint.sizeof + len;
                break;

            case REanystar:
                debug(regexp) printf("\tREanystar\n");
                pc++;
                for (;;)
                {
                    auto s1 = src;
                    if (src == input.length)
                        break;
                    if (!(attributes & REA.dotmatchlf) && input[src] == '\n')
                        break;
                    src++;
                    auto s2 = src;

                    // If no match after consumption, but it
                    // did match before, then no match
                    if (!trymatch(pc, program.length))
                    {
                        src = s1;
                        // BUG: should we save/restore pmatch[]?
                        if (trymatch(pc, program.length))
                        {
                            src = s1;       // no match
                            break;
                        }
                    }
                    src = s2;
                }
                break;

            case REnm:
            case REnmq:
                // len, n, m, ()
                puint = cast(uint *)&program[pc + 1];
                len = puint[0];
                n = puint[1];
                m = puint[2];
                debug(regexp) printf("\tREnm%s len=%d, n=%u, m=%u\n",
                        (program[pc] == REnmq) ? "q".ptr : "".ptr, len, n, m);
                pop = pc + 1 + uint.sizeof * 3;
                for (count = 0; count < n; count++)
                {
                    if (!trymatch(pop, pop + len))
                        goto Lnomatch;
                }
                if (!psave && count < m)
                {
                    //version (Win32)
                    psave = cast(regmatch_t *)alloca((re_nsub + 1) * regmatch_t.sizeof);
                    //else
                    //psave = new regmatch_t[re_nsub + 1];
                }
                if (program[pc] == REnmq)   // if minimal munch
                {
                    for (; count < m; count++)
                    {
                        memcpy(psave, pmatch.ptr, (re_nsub + 1) * regmatch_t.sizeof);
                        auto s1 = src;

                        if (trymatch(pop + len, program.length))
                        {
                            src = s1;
                            memcpy(pmatch.ptr, psave, (re_nsub + 1) * regmatch_t.sizeof);
                            break;
                        }

                        if (!trymatch(pop, pop + len))
                        {   debug(regexp) printf("\tdoesn't match subexpression\n");
                            break;
                        }

                        // If source is not consumed, don't
                        // infinite loop on the match
                        if (s1 == src)
                        {   debug(regexp) printf("\tsource is not consumed\n");
                            break;
                        }
                    }
                }
                else    // maximal munch
                {
                    for (; count < m; count++)
                    {
                        memcpy(psave, pmatch.ptr, (re_nsub + 1) * regmatch_t.sizeof);
                        auto s1 = src;
                        if (!trymatch(pop, pop + len))
                        {   debug(regexp) printf("\tdoesn't match subexpression\n");
                            break;
                        }
                        auto s2 = src;

                        // If source is not consumed, don't
                        // infinite loop on the match
                        if (s1 == s2)
                        {   debug(regexp) printf("\tsource is not consumed\n");
                            break;
                        }

                        // If no match after consumption, but it
                        // did match before, then no match
                        if (!trymatch(pop + len, program.length))
                        {
                            src = s1;
                            if (trymatch(pop + len, program.length))
                            {
                                src = s1;       // no match
                                memcpy(pmatch.ptr, psave, (re_nsub + 1) * regmatch_t.sizeof);
                                break;
                            }
                        }
                        src = s2;
                    }
                }
                debug(regexp) printf("\tREnm len=%d, n=%u, m=%u, DONE count=%d\n", len, n, m, count);
                pc = pop + len;
                break;

            case REparen:
                // len, ()
                debug(regexp) printf("\tREparen\n");
                puint = cast(uint *)&program[pc + 1];
                len = puint[0];
                n = puint[1];
                pop = pc + 1 + uint.sizeof * 2;
                ss = src;
                if (!trymatch(pop, pop + len))
                    goto Lnomatch;
                pmatch[n + 1].rm_so = ss;
                pmatch[n + 1].rm_eo = src;
                pc = pop + len;
                break;

            case REend:
                debug(regexp) printf("\tREend\n");
                return 1;       // successful match

            case REwordboundary:
                debug(regexp) printf("\tREwordboundary\n");
                if (src > 0 && src < input.length)
                {
                    c1 = input[src - 1];
                    c2 = input[src];
                    if (!(
                                (isword(cast(rchar)c1) && !isword(cast(rchar)c2)) ||
                                (!isword(cast(rchar)c1) && isword(cast(rchar)c2))
                                )
                        )
                        goto Lnomatch;
                }
                pc++;
                break;

            case REnotwordboundary:
                debug(regexp) printf("\tREnotwordboundary\n");
                if (src == 0 || src == input.length)
                    goto Lnomatch;
                c1 = input[src - 1];
                c2 = input[src];
                if (
                    (isword(cast(rchar)c1) && !isword(cast(rchar)c2)) ||
                    (!isword(cast(rchar)c1) && isword(cast(rchar)c2))
                    )
                    goto Lnomatch;
                pc++;
                break;

            case REdigit:
                debug(regexp) printf("\tREdigit\n");
                if (src == input.length)
                    goto Lnomatch;
                if (!isDigit(input[src]))
                    goto Lnomatch;
                src++;
                pc++;
                break;

            case REnotdigit:
                debug(regexp) printf("\tREnotdigit\n");
                if (src == input.length)
                    goto Lnomatch;
                if (isDigit(input[src]))
                    goto Lnomatch;
                src++;
                pc++;
                break;

            case REspace:
                debug(regexp) printf("\tREspace\n");
                if (src == input.length)
                    goto Lnomatch;
                if (!isWhite(input[src]))
                    goto Lnomatch;
                src++;
                pc++;
                break;

            case REnotspace:
                debug(regexp) printf("\tREnotspace\n");
                if (src == input.length)
                    goto Lnomatch;
                if (isWhite(input[src]))
                    goto Lnomatch;
                src++;
                pc++;
                break;

            case REword:
                debug(regexp) printf("\tREword\n");
                if (src == input.length)
                    goto Lnomatch;
                if (!isword(input[src]))
                    goto Lnomatch;
                src++;
                pc++;
                break;

            case REnotword:
                debug(regexp) printf("\tREnotword\n");
                if (src == input.length)
                    goto Lnomatch;
                if (isword(input[src]))
                    goto Lnomatch;
                src++;
                pc++;
                break;

            case REbackref:
            {
                n = program[pc + 1];
                debug(regexp) printf("\tREbackref %d\n", n);

                auto so = pmatch[n + 1].rm_so;
                auto eo = pmatch[n + 1].rm_eo;
                len = eo - so;
                if (src + len > input.length)
                    goto Lnomatch;
                else if (attributes & REA.ignoreCase)
                {
                    if (icmp(input[src .. src + len], input[so .. eo]))
                        goto Lnomatch;
                }
                else if (memcmp(&input[src], &input[so], len * rchar.sizeof))
                    goto Lnomatch;
                src += len;
                pc += 2;
                break;
            }

            default:
                assert(0);
            }
        }

      Lnomatch:
        debug(regexp) printf("\tnomatch pc=%d\n", pc);
        src = srcsave;
        return 0;
    }

/* =================== Compiler ================== */

    int parseRegexp()
    {
        size_t gotooffset;
        uint len1;
        uint len2;

        debug(regexp)
        {
            auto sss = pattern[p .. pattern.length];
            printf("parseRegexp() '%.*s'\n", sss.length, sss.ptr);
        }
        auto offset = buf.offset;
        for (;;)
        {
            assert(p <= pattern.length);
            if (p == pattern.length)
            {   buf.write(REend);
                return 1;
            }
            switch (pattern[p])
            {
            case ')':
                return 1;

            case '|':
                p++;
                gotooffset = buf.offset;
                buf.write(REgoto);
                buf.write(cast(uint)0);
                len1 = cast(uint)(buf.offset - offset);
                buf.spread(offset, 1 + uint.sizeof);
                gotooffset += 1 + uint.sizeof;
                parseRegexp();
                len2 = cast(uint)(buf.offset - (gotooffset + 1 + uint.sizeof));
                buf.data[offset] = REor;
                (cast(uint *)&buf.data[offset + 1])[0] = len1;
                (cast(uint *)&buf.data[gotooffset + 1])[0] = len2;
                break;

            default:
                parsePiece();
                break;
            }
        }
    }

    int parsePiece()
    {
        uint len;
        uint n;
        uint m;
        ubyte op;
        auto plength = pattern.length;

        debug(regexp)
        {
            auto sss = pattern[p .. pattern.length];
            printf("parsePiece() '%.*s'\n", sss.length, sss.ptr);
        }
        auto offset = buf.offset;
        parseAtom();
        if (p == plength)
            return 1;
        switch (pattern[p])
        {
        case '*':
            // Special optimization: replace .* with REanystar
            if (buf.offset - offset == 1 &&
                    buf.data[offset] == REanychar &&
                    p + 1 < plength &&
                    pattern[p + 1] != '?')
            {
                buf.data[offset] = REanystar;
                p++;
                break;
            }

            n = 0;
            m = inf;
            goto Lnm;

        case '+':
            n = 1;
            m = inf;
            goto Lnm;

        case '?':
            n = 0;
            m = 1;
            goto Lnm;

        case '{':   // {n} {n,} {n,m}
            p++;
            if (p == plength || !isDigit(pattern[p]))
                goto Lerr;
            n = 0;
            do
            {
                // BUG: handle overflow
                n = n * 10 + pattern[p] - '0';
                p++;
                if (p == plength)
                    goto Lerr;
            } while (isDigit(pattern[p]));
            if (pattern[p] == '}')      // {n}
            {   m = n;
                goto Lnm;
            }
            if (pattern[p] != ',')
                goto Lerr;
            p++;
            if (p == plength)
                goto Lerr;
            if (pattern[p] == /*{*/ '}')    // {n,}
            {   m = inf;
                goto Lnm;
            }
            if (!isDigit(pattern[p]))
                goto Lerr;
            m = 0;          // {n,m}
            do
            {
                // BUG: handle overflow
                m = m * 10 + pattern[p] - '0';
                p++;
                if (p == plength)
                    goto Lerr;
            } while (isDigit(pattern[p]));
            if (pattern[p] != /*{*/ '}')
                goto Lerr;
            goto Lnm;

        Lnm:
            p++;
            op = REnm;
            if (p < plength && pattern[p] == '?')
            {   op = REnmq; // minimal munch version
                p++;
            }
            len = cast(uint)(buf.offset - offset);
            buf.spread(offset, 1 + uint.sizeof * 3);
            buf.data[offset] = op;
            uint* puint = cast(uint *)&buf.data[offset + 1];
            puint[0] = len;
            puint[1] = n;
            puint[2] = m;
            break;

        default:
            break;
        }
        return 1;

      Lerr:
        error("badly formed {n,m}");
        assert(0);
    }

    int parseAtom()
    {   ubyte op;
        size_t offset;
        rchar c;

        debug(regexp)
        {
            auto sss = pattern[p .. pattern.length];
            printf("parseAtom() '%.*s'\n", sss.length, sss.ptr);
        }
        if (p < pattern.length)
        {
            c = pattern[p];
            switch (c)
            {
            case '*':
            case '+':
            case '?':
                error("*+? not allowed in atom");
                p++;
                return 0;

            case '(':
                p++;
                buf.write(REparen);
                offset = buf.offset;
                buf.write(cast(uint)0);     // reserve space for length
                buf.write(re_nsub);
                re_nsub++;
                parseRegexp();
                *cast(uint *)&buf.data[offset] =
                    cast(uint)(buf.offset - (offset + uint.sizeof * 2));
                if (p == pattern.length || pattern[p] != ')')
                {
                    error("')' expected");
                    return 0;
                }
                p++;
                break;

            case '[':
                if (!parseRange())
                    return 0;
                break;

            case '.':
                p++;
                buf.write(REanychar);
                break;

            case '^':
                p++;
                buf.write(REbol);
                break;

            case '$':
                p++;
                buf.write(REeol);
                break;

            case '\\':
                p++;
                if (p == pattern.length)
                {   error("no character past '\\'");
                    return 0;
                }
                c = pattern[p];
                switch (c)
                {
                case 'b':    op = REwordboundary;    goto Lop;
                case 'B':    op = REnotwordboundary; goto Lop;
                case 'd':    op = REdigit;       goto Lop;
                case 'D':    op = REnotdigit;    goto Lop;
                case 's':    op = REspace;       goto Lop;
                case 'S':    op = REnotspace;    goto Lop;
                case 'w':    op = REword;        goto Lop;
                case 'W':    op = REnotword;     goto Lop;

                Lop:
                    buf.write(op);
                    p++;
                    break;

                case 'f':
                case 'n':
                case 'r':
                case 't':
                case 'v':
                case 'c':
                case 'x':
                case 'u':
                case '0':
                    c = cast(char)escape();
                    goto Lbyte;

                case '1': case '2': case '3':
                case '4': case '5': case '6':
                case '7': case '8': case '9':
                    c -= '1';
                    if (c < re_nsub)
                    {   buf.write(REbackref);
                        buf.write(cast(ubyte)c);
                    }
                    else
                    {   error("no matching back reference");
                        return 0;
                    }
                    p++;
                    break;

                default:
                    p++;
                    goto Lbyte;
                }
                break;

            default:
                p++;
            Lbyte:
                op = REchar;
                if (attributes & REA.ignoreCase)
                {
                    if (isAlpha(c))
                    {
                        op = REichar;
                        c = cast(char)std.ascii.toUpper(c);
                    }
                }
                if (op == REchar && c <= 0xFF)
                {
                    // Look ahead and see if we can make this into
                    // an REstring
                    auto q = p;
                    for (; q < pattern.length; ++q)
                    {   rchar qc = pattern[q];

                        switch (qc)
                        {
                        case '{':
                        case '*':
                        case '+':
                        case '?':
                            if (q == p)
                                goto Lchar;
                            q--;
                            break;

                        case '(':   case ')':
                        case '|':
                        case '[':   case ']':
                        case '.':   case '^':
                        case '$':   case '\\':
                        case '}':
                            break;

                        default:
                            continue;
                        }
                        break;
                    }
                    auto len = q - p;
                    if (len > 0)
                    {
                        debug(regexp) printf("writing string len %d, c = '%c', pattern[p] = '%c'\n", len+1, c, pattern[p]);
                        buf.reserve(5 + (1 + len) * rchar.sizeof);
                        buf.write((attributes & REA.ignoreCase) ? REistring : REstring);
                        buf.write(len + 1);
                        buf.write(c);
                        buf.write(pattern[p .. p + len]);
                        p = q;
                        break;
                    }
                }
                if (c >= 0x80)
                {
                    // Convert to dchar opcode
                    op = (op == REchar) ? REdchar : REidchar;
                    buf.write(op);
                    buf.write(c);
                }
                else
                {
                  Lchar:
                    debug(regexp) printf("It's an REchar '%c'\n", c);
                    buf.write(op);
                    buf.write(cast(char)c);
                }
                break;
            }
        }
        return 1;
    }

private:
    class Range
    {
        size_t maxc;
        size_t maxb;
        OutBuffer buf;
        ubyte* base;
        BitArray bits;

        this(OutBuffer buf)
        {
            this.buf = buf;
            if (buf.data.length)
                this.base = &buf.data[buf.offset];
        }

        void setbitmax(size_t u)
        {
            //printf("setbitmax(x%x), maxc = x%x\n", u, maxc);
            if (u > maxc)
            {
                maxc = u;
                auto b = u / 8;
                if (b >= maxb)
                {
                    auto u2 = base ? base - &buf.data[0] : 0;
                    buf.fill0(b - maxb + 1);
                    base = &buf.data[u2];
                    maxb = b + 1;
                    //bits = (cast(bit*)this.base)[0 .. maxc + 1];
                    bits.ptr = cast(size_t*)this.base;
                }
                bits.len = maxc + 1;
            }
        }

        void setbit2(size_t u)
        {
            setbitmax(u + 1);
            //printf("setbit2 [x%02x] |= x%02x\n", u >> 3, 1 << (u & 7));
            bits[u] = 1;
        }

    };

    int parseRange()
    {
        int c;
        int c2;
        uint i;
        uint cmax;

        cmax = 0x7F;
        p++;
        ubyte op = REbit;
        if (p == pattern.length)
            goto Lerr;
        if (pattern[p] == '^')
        {   p++;
            op = REnotbit;
            if (p == pattern.length)
                goto Lerr;
        }
        buf.write(op);
        auto offset = buf.offset;
        buf.write(cast(uint)0);     // reserve space for length
        buf.reserve(128 / 8);
        auto r = new Range(buf);
        if (op == REnotbit)
            r.setbit2(0);
        switch (pattern[p])
        {
        case ']':
        case '-':
            c = pattern[p];
            p++;
            r.setbit2(c);
            break;

        default:
            break;
        }

        enum RS { start, rliteral, dash };
        RS rs;

        rs = RS.start;
        for (;;)
        {
            if (p == pattern.length)
                goto Lerr;
            switch (pattern[p])
            {
            case ']':
                switch (rs)
                {   case RS.dash:
                        r.setbit2('-');
                        goto case;
                    case RS.rliteral:
                        r.setbit2(c);
                        break;
                    case RS.start:
                        break;
                    default:
                        assert(0);
                }
                p++;
                break;

            case '\\':
                p++;
                r.setbitmax(cmax);
                if (p == pattern.length)
                    goto Lerr;
                switch (pattern[p])
                {
                case 'd':
                    for (i = '0'; i <= '9'; i++)
                        r.bits[i] = 1;
                    goto Lrs;

                case 'D':
                    for (i = 1; i < '0'; i++)
                        r.bits[i] = 1;
                    for (i = '9' + 1; i <= cmax; i++)
                        r.bits[i] = 1;
                    goto Lrs;

                case 's':
                    for (i = 0; i <= cmax; i++)
                        if (isWhite(i))
                            r.bits[i] = 1;
                    goto Lrs;

                case 'S':
                    for (i = 1; i <= cmax; i++)
                        if (!isWhite(i))
                            r.bits[i] = 1;
                    goto Lrs;

                case 'w':
                    for (i = 0; i <= cmax; i++)
                        if (isword(cast(rchar)i))
                            r.bits[i] = 1;
                    goto Lrs;

                case 'W':
                    for (i = 1; i <= cmax; i++)
                        if (!isword(cast(rchar)i))
                            r.bits[i] = 1;
                    goto Lrs;

                Lrs:
                    switch (rs)
                    {   case RS.dash:
                            r.setbit2('-');
                            goto case;
                        case RS.rliteral:
                            r.setbit2(c);
                            break;
                        default:
                            break;
                    }
                    rs = RS.start;
                    continue;

                default:
                    break;
                }
                c2 = escape();
                goto Lrange;

            case '-':
                p++;
                if (rs == RS.start)
                    goto Lrange;
                else if (rs == RS.rliteral)
                    rs = RS.dash;
                else if (rs == RS.dash)
                {
                    r.setbit2(c);
                    r.setbit2('-');
                    rs = RS.start;
                }
                continue;

            default:
                c2 = pattern[p];
                p++;
            Lrange:
                switch (rs)
                {   case RS.rliteral:
                        r.setbit2(c);
                        goto case;
                    case RS.start:
                        c = c2;
                        rs = RS.rliteral;
                        break;

                case RS.dash:
                    if (c > c2)
                    {   error("inverted range in character class");
                        return 0;
                    }
                    r.setbitmax(c2);
                    //printf("c = %x, c2 = %x\n",c,c2);
                    for (; c <= c2; c++)
                        r.bits[c] = 1;
                    rs = RS.start;
                    break;

                default:
                    assert(0);
                }
                continue;
            }
            break;
        }
        if (attributes & REA.ignoreCase)
        {
            // BUG: what about dchar?
            r.setbitmax(0x7F);
            for (c = 'a'; c <= 'z'; c++)
            {
                if (r.bits[c])
                    r.bits[c + 'A' - 'a'] = 1;
                else if (r.bits[c + 'A' - 'a'])
                    r.bits[c] = 1;
            }
        }
        //printf("maxc = %d, maxb = %d\n",r.maxc,r.maxb);
        (cast(ushort *)&buf.data[offset])[0] = cast(ushort)r.maxc;
        (cast(ushort *)&buf.data[offset])[1] = cast(ushort)r.maxb;
        return 1;

      Lerr:
        error("invalid range");
        return 0;
    }

    void error(string msg)
    {
        errors++;
        debug(regexp) printf("error: %.*s\n", msg.length, msg.ptr);
//assert(0);
//*(char*)0=0;
        throw new RegExpException(msg);
    }

// p is following the \ char
    int escape()
    in
    {
        assert(p < pattern.length);
    }
    body
    {   int c;
        int i;
        rchar tc;

        c = pattern[p];     // none of the cases are multibyte
        switch (c)
        {
        case 'b':    c = '\b';  break;
        case 'f':    c = '\f';  break;
        case 'n':    c = '\n';  break;
        case 'r':    c = '\r';  break;
        case 't':    c = '\t';  break;
        case 'v':    c = '\v';  break;

            // BUG: Perl does \a and \e too, should we?

        case 'c':
            ++p;
            if (p == pattern.length)
                goto Lretc;
            c = pattern[p];
            // Note: we are deliberately not allowing dchar letters
            if (!(('a' <= c && c <= 'z') || ('A' <= c && c <= 'Z')))
            {
              Lcerr:
                error("letter expected following \\c");
                return 0;
            }
            c &= 0x1F;
            break;

        case '0':
        case '1':
        case '2':
        case '3':
        case '4':
        case '5':
        case '6':
        case '7':
            c -= '0';
            for (i = 0; i < 2; i++)
            {
                p++;
                if (p == pattern.length)
                    goto Lretc;
                tc = pattern[p];
                if ('0' <= tc && tc <= '7')
                {   c = c * 8 + (tc - '0');
                    // Treat overflow as if last
                    // digit was not an octal digit
                    if (c >= 0xFF)
                    {   c >>= 3;
                        return c;
                    }
                }
                else
                    return c;
            }
            break;

        case 'x':
            c = 0;
            for (i = 0; i < 2; i++)
            {
                p++;
                if (p == pattern.length)
                    goto Lretc;
                tc = pattern[p];
                if ('0' <= tc && tc <= '9')
                    c = c * 16 + (tc - '0');
                else if ('a' <= tc && tc <= 'f')
                    c = c * 16 + (tc - 'a' + 10);
                else if ('A' <= tc && tc <= 'F')
                    c = c * 16 + (tc - 'A' + 10);
                else if (i == 0)    // if no hex digits after \x
                {
                    // Not a valid \xXX sequence
                    return 'x';
                }
                else
                    return c;
            }
            break;

        case 'u':
            c = 0;
            for (i = 0; i < 4; i++)
            {
                p++;
                if (p == pattern.length)
                    goto Lretc;
                tc = pattern[p];
                if ('0' <= tc && tc <= '9')
                    c = c * 16 + (tc - '0');
                else if ('a' <= tc && tc <= 'f')
                    c = c * 16 + (tc - 'a' + 10);
                else if ('A' <= tc && tc <= 'F')
                    c = c * 16 + (tc - 'A' + 10);
                else
                {
                    // Not a valid \uXXXX sequence
                    p -= i;
                    return 'u';
                }
            }
            break;

        default:
            break;
        }
        p++;
      Lretc:
        return c;
    }

/* ==================== optimizer ======================= */

    void optimize()
    {   ubyte[] prog;

        debug(regexp) printf("RegExp.optimize()\n");
        prog = buf.toBytes();
        for (size_t i = 0; 1;)
        {
            //printf("\tprog[%d] = %d, %d\n", i, prog[i], REstring);
            switch (prog[i])
            {
            case REend:
            case REanychar:
            case REanystar:
            case REbackref:
            case REeol:
            case REchar:
            case REichar:
            case REdchar:
            case REidchar:
            case REstring:
            case REistring:
            case REtestbit:
            case REbit:
            case REnotbit:
            case RErange:
            case REnotrange:
            case REwordboundary:
            case REnotwordboundary:
            case REdigit:
            case REnotdigit:
            case REspace:
            case REnotspace:
            case REword:
            case REnotword:
                return;

            case REbol:
                i++;
                continue;

            case REor:
            case REnm:
            case REnmq:
            case REparen:
            case REgoto:
            {
                auto bitbuf = new OutBuffer;
                auto r = new Range(bitbuf);
                auto offset = i;
                if (starrchars(r, prog[i .. prog.length]))
                {
                    debug(regexp) printf("\tfilter built\n");
                    buf.spread(offset, 1 + 4 + r.maxb);
                    buf.data[offset] = REtestbit;
                    (cast(ushort *)&buf.data[offset + 1])[0] = cast(ushort)r.maxc;
                    (cast(ushort *)&buf.data[offset + 1])[1] = cast(ushort)r.maxb;
                    i = offset + 1 + 4;
                    buf.data[i .. i + r.maxb] = r.base[0 .. r.maxb];
                }
                return;
            }
            default:
                assert(0);
            }
        }
    }

/////////////////////////////////////////
// OR the leading character bits into r.
// Limit the character range from 0..7F,
// trymatch() will allow through anything over maxc.
// Return 1 if success, 0 if we can't build a filter or
// if there is no point to one.

    int starrchars(Range r, const(ubyte)[] prog)
    {   rchar c;
        uint maxc;
        size_t maxb;
        size_t len;
        uint b;
        uint n;
        uint m;
        const(ubyte)* pop;

        //printf("RegExp.starrchars(prog = %p, progend = %p)\n", prog, progend);
        for (size_t i = 0; i < prog.length;)
        {
            switch (prog[i])
            {
            case REchar:
                c = prog[i + 1];
                if (c <= 0x7F)
                    r.setbit2(c);
                return 1;

            case REichar:
                c = prog[i + 1];
                if (c <= 0x7F)
                {   r.setbit2(c);
                    r.setbit2(std.ascii.toLower(cast(rchar)c));
                }
                return 1;

            case REdchar:
            case REidchar:
                return 1;

            case REanychar:
                return 0;       // no point

            case REstring:
                len = *cast(size_t *)&prog[i + 1];
                assert(len);
                c = *cast(rchar *)&prog[i + 1 + size_t.sizeof];
                debug(regexp) printf("\tREstring %d, '%c'\n", len, c);
                if (c <= 0x7F)
                    r.setbit2(c);
                return 1;

            case REistring:
                len = *cast(size_t *)&prog[i + 1];
                assert(len);
                c = *cast(rchar *)&prog[i + 1 + size_t.sizeof];
                debug(regexp) printf("\tREistring %d, '%c'\n", len, c);
                if (c <= 0x7F)
                {   r.setbit2(std.ascii.toUpper(cast(rchar)c));
                    r.setbit2(std.ascii.toLower(cast(rchar)c));
                }
                return 1;

            case REtestbit:
            case REbit:
                maxc = (cast(ushort *)&prog[i + 1])[0];
                maxb = (cast(ushort *)&prog[i + 1])[1];
                if (maxc <= 0x7F)
                    r.setbitmax(maxc);
                else
                    maxb = r.maxb;
                for (b = 0; b < maxb; b++)
                    r.base[b] |= prog[i + 1 + 4 + b];
                return 1;

            case REnotbit:
                maxc = (cast(ushort *)&prog[i + 1])[0];
                maxb = (cast(ushort *)&prog[i + 1])[1];
                if (maxc <= 0x7F)
                    r.setbitmax(maxc);
                else
                    maxb = r.maxb;
                for (b = 0; b < maxb; b++)
                    r.base[b] |= ~prog[i + 1 + 4 + b];
                return 1;

            case REbol:
            case REeol:
                return 0;

            case REor:
                len = (cast(uint *)&prog[i + 1])[0];
                return starrchars(r, prog[i + 1 + uint.sizeof .. prog.length]) &&
                    starrchars(r, prog[i + 1 + uint.sizeof + len .. prog.length]);

            case REgoto:
                len = (cast(uint *)&prog[i + 1])[0];
                i += 1 + uint.sizeof + len;
                break;

            case REanystar:
                return 0;

            case REnm:
            case REnmq:
                // len, n, m, ()
                len = (cast(uint *)&prog[i + 1])[0];
                n   = (cast(uint *)&prog[i + 1])[1];
                m   = (cast(uint *)&prog[i + 1])[2];
                pop = &prog[i + 1 + uint.sizeof * 3];
                if (!starrchars(r, pop[0 .. len]))
                    return 0;
                if (n)
                    return 1;
                i += 1 + uint.sizeof * 3 + len;
                break;

            case REparen:
                // len, ()
                len = (cast(uint *)&prog[i + 1])[0];
                n   = (cast(uint *)&prog[i + 1])[1];
                pop = &prog[0] + i + 1 + uint.sizeof * 2;
                return starrchars(r, pop[0 .. len]);

            case REend:
                return 0;

            case REwordboundary:
            case REnotwordboundary:
                return 0;

            case REdigit:
                r.setbitmax('9');
                for (c = '0'; c <= '9'; c++)
                    r.bits[c] = 1;
                return 1;

            case REnotdigit:
                r.setbitmax(0x7F);
                for (c = 0; c <= '0'; c++)
                    r.bits[c] = 1;
                for (c = '9' + 1; c <= r.maxc; c++)
                    r.bits[c] = 1;
                return 1;

            case REspace:
                r.setbitmax(0x7F);
                for (c = 0; c <= r.maxc; c++)
                    if (isWhite(c))
                        r.bits[c] = 1;
                return 1;

            case REnotspace:
                r.setbitmax(0x7F);
                for (c = 0; c <= r.maxc; c++)
                    if (!isWhite(c))
                        r.bits[c] = 1;
                return 1;

            case REword:
                r.setbitmax(0x7F);
                for (c = 0; c <= r.maxc; c++)
                    if (isword(cast(rchar)c))
                        r.bits[c] = 1;
                return 1;

            case REnotword:
                r.setbitmax(0x7F);
                for (c = 0; c <= r.maxc; c++)
                    if (!isword(cast(rchar)c))
                        r.bits[c] = 1;
                return 1;

            case REbackref:
                return 0;

            default:
                assert(0);
            }
        }
        return 1;
    }

/* ==================== replace ======================= */

/***********************
 * After a match is found with test(), this function
 * will take the match results and, using the format
 * string, generate and return a new string.
 */

    public string replace(string format)
    {
        return replace3(format, input, pmatch[0 .. re_nsub + 1]);
    }

// Static version that doesn't require a RegExp object to be created

    public static string replace3(string format, string input, regmatch_t[] pmatch)
    {
        string result;
        size_t c2;
        sizediff_t rm_so, rm_eo, i;

//    printf("replace3(format = '%.*s', input = '%.*s')\n", format.length, format.ptr, input.length, input.ptr);
        result.length = format.length;
        result.length = 0;
        for (size_t f = 0; f < format.length; f++)
        {
            char c = format[f];
          L1:
            if (c != '$')
            {
                result ~= c;
                continue;
            }
            ++f;
            if (f == format.length)
            {
                result ~= '$';
                break;
            }
            c = format[f];
            switch (c)
            {
            case '&':
                rm_so = pmatch[0].rm_so;
                rm_eo = pmatch[0].rm_eo;
                goto Lstring;

            case '`':
                rm_so = 0;
                rm_eo = pmatch[0].rm_so;
                goto Lstring;

            case '\'':
                rm_so = pmatch[0].rm_eo;
                rm_eo = input.length;
                goto Lstring;

            case '0': case '1': case '2': case '3': case '4':
            case '5': case '6': case '7': case '8': case '9':
                i = c - '0';
                if (f + 1 == format.length)
                {
                    if (i == 0)
                    {
                        result ~= '$';
                        result ~= c;
                        continue;
                    }
                }
                else
                {
                    c2 = format[f + 1];
                    if (c2 >= '0' && c2 <= '9')
                    {
                        i = (c - '0') * 10 + (c2 - '0');
                        f++;
                    }
                    if (i == 0)
                    {
                        result ~= '$';
                        result ~= c;
                        c = cast(char)c2;
                        goto L1;
                    }
                }

                if (i < pmatch.length)
                {   rm_so = pmatch[i].rm_so;
                    rm_eo = pmatch[i].rm_eo;
                    goto Lstring;
                }
                break;

            Lstring:
                if (rm_so != rm_eo)
                    result ~= input[rm_so .. rm_eo];
                break;

            default:
                result ~= '$';
                result ~= c;
                break;
            }
        }
        return result;
    }

/************************************
 * Like replace(char[] format), but uses old style formatting:
        <table border=1 cellspacing=0 cellpadding=5>
        <th>Format
        <th>Description
        <tr>
        <td><b>&</b>
        <td>replace with the match
        </tr>
        <tr>
        <td><b>\</b><i>n</i>
        <td>replace with the <i>n</i>th parenthesized match, <i>n</i> is 1..9
        </tr>
        <tr>
        <td><b>\</b><i>c</i>
        <td>replace with char <i>c</i>.
        </tr>
        </table>
*/

    public string replaceOld(string format)
    {
        string result;

//printf("replace: this = %p so = %d, eo = %d\n", this, pmatch[0].rm_so, pmatch[0].rm_eo);
//printf("3input = '%.*s'\n", input.length, input.ptr);
        result.length = format.length;
        result.length = 0;
        for (size_t i; i < format.length; i++)
        {
            char c = format[i];
            switch (c)
            {
            case '&':
                {
                    auto sss = input[pmatch[0].rm_so .. pmatch[0].rm_eo];
                    //printf("match = '%.*s'\n", sss.length, sss.ptr);
                    result ~= sss;
                }
                break;

            case '\\':
                if (i + 1 < format.length)
                {
                    c = format[++i];
                    if (c >= '1' && c <= '9')
                    {   uint j;

                        j = c - '0';
                        if (j <= re_nsub && pmatch[j].rm_so != pmatch[j].rm_eo)
                            result ~= input[pmatch[j].rm_so .. pmatch[j].rm_eo];
                        break;
                    }
                }
                result ~= c;
                break;

            default:
                result ~= c;
                break;
            }
        }
        return result;
    }

}

unittest
{   // Created and placed in public domain by Don Clugston

    auto m = search("aBC r s", `bc\x20r[\40]s`, "i");
    assert(m.pre=="a");
    assert(m[0]=="BC r s");
    auto m2 = search("7xxyxxx", `^\d([a-z]{2})\D\1`);
    assert(m2[0]=="7xxyxx");
    // Just check the parsing.
    auto m3 = search("dcbxx", `ca|b[\d\]\D\s\S\w-\W]`);
    auto m4 = search("xy", `[^\ca-\xFa\r\n\b\f\t\v\0123]{2,485}$`);
    auto m5 = search("xxx", `^^\r\n\b{13,}\f{4}\t\v\u02aF3a\w\W`);
    auto m6 = search("xxy", `.*y`);
    assert(m6[0]=="xxy");
    auto m7 = search("QWDEfGH", "(ca|b|defg)+", "i");
    assert(m7[0]=="DEfG");
    auto m8 = search("dcbxx", `a?\B\s\S`);
    auto m9 = search("dcbxx", `[-w]`);
    auto m10 = search("dcbsfd", `aB[c-fW]dB|\d|\D|\u012356|\w|\W|\s|\S`, "i");
    auto m11 = search("dcbsfd", `[]a-]`);
    m.replaceOld(`a&b\1c`);
    m.replace(`a$&b$'$1c`);
}

// Andrei
//------------------------------------------------------------------------------

struct Pattern(Char)
{
    immutable(Char)[] pattern;

    this(immutable(Char)[] pattern)
    {
        this.pattern = pattern;
    }
}

Pattern!(Char) pattern(Char)(immutable(Char)[] pat)
{
    return typeof(return)(pat);
}

struct Splitter(Range)
{
    Range _input;
    size_t _chunkLength;
    RegExp _rx;

    private Range search()
    {
        //rx = std.regexp.search(_input, "(" ~ _separator.pattern ~ ")");
        auto i = std.regexp.find(cast(string) _input, _rx);
        return _input[i >= 0 ? i : _input.length .. _input.length];
    }

    private void advance()
    {
        //writeln("(" ~ _separator.pattern ~ ")");
        //writeln(_input);
        //assert(_rx[0].length > 0);
        _chunkLength += _rx[0].length;
    }

    this(Range input, Pattern!(char) separator)
    {
        _input = input;
        _rx = RegExp(separator.pattern);
        _chunkLength = _input.length - search().length;
    }

    ref auto opSlice()
    {
        return this;
    }

    Range front()
    {
        return _input[0 .. _chunkLength];
    }

    bool empty()
    {
        return _input.empty;
    }

    void popFront()
    {
        if (_chunkLength == _input.length)
        {
            _input = _input[_chunkLength .. _input.length];
            return;
        }
        advance;
        _input = _input[_chunkLength .. _input.length];
        _chunkLength = _input.length - search().length;
    }
}

Splitter!(Range) splitter(Range)(Range r, Pattern!(char) pat)
{
    static assert(is(Unqual!(typeof(Range.init[0])) == char),
        Unqual!(typeof(Range.init[0])).stringof);
    return typeof(return)(cast(string) r, pat);
}

unittest
{
    auto s1 = ", abc, de,  fg, hi, ";
    auto sp2 = splitter(s1, pattern(", *"));
    //foreach (e; sp2) writeln("[", e, "]");
    assert(equal(sp2, ["", "abc", "de", "fg", "hi"][]));
}

unittest
{
    auto str= "foo";
    string[] re_strs= [
             r"^(h|a|)fo[oas]$",
             r"^(a|b|)fo[oas]$",
             r"^(a|)foo$",
             r"(a|)foo",
             r"^(h|)foo$",
             r"(h|)foo",
             r"(h|a|)fo[oas]",
             r"^(a|b|)fo[o]$",
             r"[abf][ops](o|oo|)(h|a|)",
             r"(h|)[abf][ops](o|oo|)",
             r"(c|)[abf][ops](o|oo|)"
    ];

    foreach (re_str; re_strs) {
        auto re= new RegExp(re_str);
        auto matches= cast(bool)re.test(str);
        assert(matches);
        //writefln("'%s' matches '%s' ? %s", str, re_str, matches);
    }

    for (char c='a'; c<='z'; ++c) {
        auto re_str= "("~c~"|)foo";
        auto re= new RegExp(re_str);
        auto matches= cast(bool)re.test(str);
        assert(matches);
        //writefln("'%s' matches '%s' ? %s", str, re_str, matches);
    }
}
