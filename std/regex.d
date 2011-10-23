// Written in the D programming language.
// Regular Expressions.

/**
$(WEB digitalmars.com/ctg/regular.html, Regular expressions) are a
powerful method of string pattern matching.  The regular expression
language used in this library is the same as that commonly used,
however, some of the very advanced forms may behave slightly
differently. The standard observed is the $(WEB
www.ecma-international.org/publications/standards/Ecma-262.htm, ECMA
standard) for regular expressions.

$(D std.regex) is designed to work only with valid UTF strings as
input - UTF8 ($(D char)), UTF16 ($(D wchar)), or UTF32 ($(D dchar)).
To validate untrusted input, use $(D std.utf.validate()).

In the following guide, $(D pattern[]) refers to a $(WEB
digitalmars.com/ctg/regular.html, regular expression).  The $(D
attributes[]) refers to a string controlling the interpretation of the
regular expression.  It consists of a sequence of one or more of the
following characters:

$(BOOKTABLE Attribute Characters,
$(TR $(TH Attribute) $(TH Action))
$(TR $(TD $(B g)) $(TD global; repeat over the whole input string))
$(TR $(TD $(B i)) $(TD case insensitive))
$(TR $(TD $(B m)) $(TD treat as multiple lines separated by newlines)))

The $(D format[]) string has the formatting characters:

$(BOOKTABLE Formatting Characters,
$(TR $(TH Format) $(TH Replaced With))
$(TR  $(TD $(B $$)) $(TD $))
$(TR$(TD $(B $&)) $(TD The matched substring.))
$(TR $(TD $(B $`)) $(TD The portion of string that precedes the matched
substring.))
$(TR $(TD $(B $')) $(TD The portion of string that follows the matched
substring.))
$(TR $(TD $(B $(DOLLAR))$(I n)) $(TD The $(I n)th capture, where $(I
n) is a single digit 1-9 and $$(I n) is not followed by a decimal
digit.))
$(TR $(TD $(B $(DOLLAR))$(I nn)) $(TD The $(I nn)th
capture, where $(I nn) is a two-digit decimal number 01-99.  If $(I
nn)th capture is undefined or more than the number of parenthesized
subexpressions, use the empty string instead.)))

Any other $ are left as is.

References: $(WEB en.wikipedia.org/wiki/Regular_expressions,
Wikipedia)

Macros:

WIKI = StdRegex
DOLLAR = $

Copyright: Copyright Digital Mars 2000 - 2009.
License:   <a href="http://www.boost.org/LICENSE_1_0.txt">Boost License 1.0</a>.
Authors:   $(WEB digitalmars.com, Walter Bright),
           $(WEB erdani.org, Andrei Alexandrescu)
Source:    $(PHOBOSSRC std/_regex.d)
*/
/*
         Copyright Digital Mars 2000 - 2009.
Distributed under the Boost Software License, Version 1.0.
   (See accompanying file LICENSE_1_0.txt or copy at
         http://www.boost.org/LICENSE_1_0.txt)
*/

/*
Escape sequences:

\nnn starts out a 1, 2 or 3 digit octal sequence, where n is an octal
digit. If nnn is larger than 0377, then the 3rd digit is not part of
the sequence and is not consumed.  For maximal portability, use
exactly 3 digits.

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

module std.regex;

//debug = std_regex;                // uncomment to turn on debugging writef's

import core.stdc.stdlib;
import core.stdc.string;
import std.stdio;
import std.string;
import std.ascii;
import std.outbuffer;
import std.bitmanip;
import std.utf;
import std.algorithm;
import std.array;
import std.traits;
import std.typecons;
import std.typetuple;
import std.range;
import std.conv;
import std.functional;

unittest
{
    auto r = regex("abc"w);
    auto m = match("abc"w, r);
    if (!m.empty) return;
    writeln(m.pre);
    writeln(m.hit);
    writeln(m.post);
    r.printProgram;
    assert(false);
}

/** Regular expression to extract an _email address.
References:

$(WEB regular-expressions.info/_email.html, How to Find or Validate an
Email Address); $(WEB tools.ietf.org/html/rfc2822#section-3.4.1, RFC
2822 Internet Message Format)
 */
enum string email =
    r"[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,4}";

unittest
{
    assert(match("asdassfsd@", regex(email)).empty);
    assert(!match("andrei@metalanguage.com", regex(email)).empty);
}

/** Regular expression to extract a _url */
enum string url = r"(([h|H][t|T]|[f|F])[t|T][p|P]([s|S]?)\:\/\/|~/|/)?"
    r"([\w]+:\w+@)?(([a-zA-Z]{1}([\w\-]+\.)+([\w]{2,5}))"
    r"(:[\d]{1,5})?)?((/?\w+/)+|/?)"
    r"(\w+\.[\w]{3,4})?([,]\w+)*((\?\w+=\w+)?(&\w+=\w+)*([,]\w*)*)?";

unittest
{
    assert(!match("http://www.erdani.org/asd/sd?asd#eds",
                    regex(url)).empty);
}

/****************************************************
A $(D Regex) stores a regular expression engine. A $(D Regex) object
is constructed from a string and compiled into an internal format for
performance.

The type parameter $(D E) specifies the character type recognized by
the regular expression. Currently $(D char), $(D wchar), and $(D
dchar) are supported. The encoding of the regex string and of the
recognized strings must be the same.

This object will be mostly used via a call to the $(D regex) function,
which automatically deduces the character type.

Example: Declare two variables and assign to them a $(D Regex)
object. The first matches UTF-8 strings, the second matches UTF-32
strings and also has the global option set.

---
auto r = regex("pattern");
auto s = regex(r"p[1-5]\s*"w, "g");
---
 */
struct Regex(E) if (is(E == Unqual!E))
{
private:
    struct regmatch_t
    {
        size_t startIdx, endIdx;
    }
    enum REA
    {
        global          = 1,    // has the g attribute
        ignoreCase      = 2,    // has the i attribute
        multiline       = 4,    // if treat as multiple lines separated by
                            // newlines, or as a single line
        dotmatchlf      = 8,    // if . matches \n
    }
    enum uint inf = ~0u;

    uint re_nsub;        // number of parenthesized subexpression matches
    uint nCounters;  //current counter (internal), number of counters
    ubyte attributes;
    immutable(ubyte)[] program; // pattern[] compiled into regular
                                // expression program
// Opcodes

    enum : ubyte
    {
            REend,              // end of program
            REchar,             // single character
            REichar,            // single character, case insensitive
            REdchar,            // single UCS character
            REidchar,           // single wide character, case insensitive
            REanychar,          // any character

            REstring,           // string of characters
            REistring,          // string of characters, case insensitive
            REtestbit,          // any in bitmap, non-consuming
            REbit,              // any in the bit map
            REnotbit,           // any not in the bit map
            RErange,            // any in the string
            REnotrange,         // any not in the string
            REor,               // a | b
            REplus,             // 1 or more
            REstar,             // 0 or more
            REquest,            // 0 or 1
            REcounter,          // begining of repetition
            REloopg,            // loop on body of repetition (greedy)
            REloop,             // ditto non-greedy
            REbol,              // begining of line
            REeol,              // end of line
            REsave,             // save submatch position i.e. "(" & ")"
            REgoto,             // goto offset
            REret,              // end of subprogram

            RElookahead,
            REneglookahead,
            RElookbehind,
            REneglookbehind,
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
public:
    // @@@BUG Should be a constructor but template constructors don't work
    // private void initialize(String)(String pattern, string attributes)
    // {
    //     compile(pattern, attributes);
    // }

/**
Construct a $(D Regex) object. Compile pattern with $(D attributes)
into an internal form for fast execution.

Params:
pattern = regular expression
attributes = The _attributes (g, i, and m accepted)

Throws: $(D Exception) if there are any compilation errors.
 */
    this(String)(String pattern, string attributes = null)
    {
        compile(pattern, attributes);
    }

    unittest
    {
        debug(std_regex) writefln("regex.opCall.unittest()");
        auto r1 = Regex("hello", "m");
        string msg;
        try
        {
            auto r2 = Regex("hello", "q");
            assert(0);
        }
        catch (Exception ree)
        {
            msg = ree.toString();
            //writefln("message: %s", ree);
        }
        assert(std.algorithm.countUntil(msg, "unrecognized attribute") >= 0);
    }

/**
Returns the number of parenthesized captures
*/
    uint captures() const
    {
        return re_nsub;
    }

/* ********************************
 * Throws Exception on error
 */

    public void compile(String)(String pattern, string attributes)
    {
        this.attributes = 0;
        foreach (c; attributes)
        {
            REA att;

            switch (c)
            {
            case 'g': att = REA.global;         break;
            case 'i': att = REA.ignoreCase;     break;
            case 'm': att = REA.multiline;      break;
            default:
                error("unrecognized attribute");
                assert(0);
            }
            if (this.attributes & att)
            {
                error("redundant attribute");
                assert(0);
            }
            this.attributes |= att;
        }

        uint oldre_nsub = re_nsub;
        re_nsub = 0;

        auto buf = new OutBuffer;
        buf.reserve(pattern.length * 8);
        size_t p = 0;
        parseRegex(pattern, p, buf);
        if (p < pattern.length)
        {
            error("unmatched ')'");
        }
        re_nsub /= 2; //start & ends -> pairs
        postprocess(buf.data);

        program = cast(immutable(ubyte)[]) buf.data;
        buf.data = null;
        delete buf;
    }

    void error(string msg)
    {
        debug(std_regex) writefln("error: %s", msg);
        throw new Exception(msg);
    }

    //Fixup counter numbers, simplify instructions
    private void postprocess(ubyte[] prog)
    {
        uint counter = 0;
        size_t len;
        ushort* pu;
        nCounters = 0;
        size_t pc = 0;
        for (;;)
        {
            switch (prog[pc])
            {
            case REend:
                return;

            case REcounter:
                size_t offs = pc + 1 + 2*uint.sizeof;
                *cast(uint *)&prog[pc+1] = counter;
                counter++;
                nCounters = max(nCounters, counter);
                pc += 1 + 2*uint.sizeof;
                break;

            case REloop, REloopg:
                counter--;
                pc += 1 + 3*uint.sizeof;
                break;

            case REret:
            case REanychar:
            case REbol:
            case REeol:
            case REwordboundary:
            case REnotwordboundary:
            case REdigit:
            case REnotdigit:
            case REspace:
            case REnotspace:
            case REword:
            case REnotword:
                pc++;
                break;

            case REbackref:
            case REchar:
            case REichar:
                pc += 2;
                break;

            case REdchar:
            case REidchar:
                pc += 1 + dchar.sizeof;
                break;

            case REstring:
            case REistring:
                len = *cast(size_t *)&prog[pc+1];
                assert(len % E.sizeof == 0);
                pc += 1 + size_t.sizeof + len;
                break;

            case REtestbit:
            case REbit:
            case REnotbit:
                pu = cast(ushort *)&prog[pc+1];
                len = pu[1];
                pc += 1 + 2 * ushort.sizeof + len;
                break;

            case RErange:
            case REnotrange:
                len = *cast(uint *)&prog[pc+1];
                pc += 1 + uint.sizeof + len;
                break;

            case REneglookahead:
            case RElookahead:
            case REor:
            case REgoto:
                pc += 1 + uint.sizeof;
                break;

            case REsave:
                pc += 1 + uint.sizeof;
                break;

            default:
                assert(0);
            }
        }
    }
/* =================== Compiler ================== */

    void parseRegex(String)(String pattern, ref size_t p, OutBuffer buf)
    {
        auto offset = buf.offset;
        for (;;)
        {
            assert(p <= pattern.length);
            if (p == pattern.length)
            {
                buf.write(REend);
                return;
            }
            switch (pattern[p])
            {
            case ')':
                return;

            case '|':
                p++;
                auto gotooffset = buf.offset;
                buf.write(REgoto);
                buf.write(cast(uint)0);
                immutable uint len1 = cast(uint) (buf.offset - offset);
                buf.spread(offset, 1 + uint.sizeof);
                gotooffset += 1 + uint.sizeof;
                parseRegex(pattern, p, buf);
                immutable len2 = cast(uint)
                    (buf.offset - (gotooffset + 1 + uint.sizeof));
                buf.data[offset] = REor;
                (cast(uint *)&buf.data[offset + 1])[0] = len1;
                (cast(uint *)&buf.data[gotooffset + 1])[0] = len2;
                break;

            default:
                parsePiece(pattern, p, buf);
                break;
            }
        }
    }

    void parsePiece(String)(String pattern, ref size_t p, OutBuffer buf)
    {
        uint n;
        uint m;
        debug(std_regex)
        {
            auto sss = pattern[p .. pattern.length];
            writefln("parsePiece() '%s'", sss);
        }
        size_t offset = buf.offset;
        size_t plength = pattern.length;
        parseAtom(pattern, p, buf);
        if (p == plength)
            return;
        switch (pattern[p])
        {
        case '*':
            n = 0;
            m = inf;
            break;

        case '+':
            n = 1;
            m = inf;
            break;

        case '?':
            n = 0;
            m = 1;
            break;

        case '{':       // {n} {n,} {n,m}
            p++;

            if (p == plength || !isDigit(pattern[p]))
                error("badly formed {n,m}");
            auto src = pattern[p..$];
            n = parse!uint(src);
            p = plength - src.length;
            if (pattern[p] == '}')              // {n}
            {
                m = n;
                break;
            }
            if (pattern[p] != ',')
                error("',' expected in {n,m}");
            p++;
            if (p == plength)
                error("unexpected end of pattern in {n,m}");
            if (pattern[p] == /*{*/ '}')        // {n,}
            {
                m = inf;
                break;
            }
            if (!isDigit(pattern[p]))
                error("badly formed {n,m}");
            src = pattern[p..$];
            m = parse!uint(src);
            p = plength - src.length;
            if (pattern[p] != /*{*/ '}')
                error("unmatched '}' in {n,m}");
            break;
        default:
            return;
        }
        p++;
        uint len = cast(uint)(buf.offset - offset);
        if (p < plength && pattern[p] == '?')
        {
            buf.write(REloop);
            p++;
        }
        else
            buf.write(REloopg);
        buf.write(cast(uint)n);
        buf.write(cast(uint)m);
        buf.write(cast(uint)len);//set jump back
        buf.spread(offset, (1 + 2*uint.sizeof));
        buf.data[offset] = REcounter;
        *(cast(uint*)&buf.data[offset+1]) = 0;//reserve counter num
        *(cast(uint*)&buf.data[offset+5]) = len;
        return;
    }

    void parseAtom(String)(String pattern, ref size_t p, OutBuffer buf)
    {
        ubyte op;
        size_t offset;
        E c;

        debug(std_regex)
        {
            auto sss = pattern[p .. pattern.length];
            writefln("parseAtom() '%s'", sss);
        }
        if (p >= pattern.length) return;
        c = pattern[p];
        switch (c)
        {
        case '*':
        case '+':
        case '?':
            error("*+? not allowed in atom");
            assert(0);

        case '(':
            p++;
            if (pattern[p] != '?')
            {
                buf.write(REsave);
                buf.write(2 + re_nsub);
                //handle nested groups
                uint end = re_nsub;
                re_nsub += 2;
                parseRegex(pattern, p, buf);
                buf.write(REsave);
                buf.write(2 + end + 1);
            }
            else if (pattern.length > p+1)
            {
                p++;
                switch (pattern[p])
                {
                    case ':':
                        p++;
                        parseRegex(pattern, p, buf);
                        break;
                    case '=': case '!':
                        buf.write(pattern[p] == '=' ? RElookahead : REneglookahead);
                        offset = buf.offset;
                        buf.write(cast(uint)0); // reserve space for length
                        p++;
                        parseRegex(pattern, p, buf);
                        *cast(uint *)&buf.data[offset] =
                            cast(uint)(buf.offset - (offset + uint.sizeof)+1);
                        buf.write(REret);
                        break;
                    default:
                        error("any of :=! expected after '(?'");
                        assert(0);
                }
            }
            else
            {
                error("any of :=! expected after '(?'");
                assert(0);
            }
            if (p == pattern.length || pattern[p] != ')')
            {
                error("')' expected");
                assert(0);
            }
            p++;
            break;

        case '[':
            parseRange(pattern, p, buf);
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
            {
                error("no character past '\\'");
                assert(0);
            }
            c = pattern[p];
            switch (c)
            {
            case 'b':    op = REwordboundary;    goto Lop;
            case 'B':    op = REnotwordboundary; goto Lop;
            case 'd':    op = REdigit;           goto Lop;
            case 'D':    op = REnotdigit;        goto Lop;
            case 's':    op = REspace;           goto Lop;
            case 'S':    op = REnotspace;        goto Lop;
            case 'w':    op = REword;            goto Lop;
            case 'W':    op = REnotword;         goto Lop;

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
                c = cast(char)escape(pattern, p);
                goto Lbyte;

            case '1': case '2': case '3':
            case '4': case '5': case '6':
            case '7': case '8': case '9':
                c -= '1';
                if (c < re_nsub)
                {
                    buf.write(REbackref);
                    buf.write(cast(ubyte)c);
                }
                else
                    error("no matching back reference");
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
                sizediff_t q = p;
                sizediff_t len;

                for (; q < pattern.length; ++q)
                {
                    auto qc = pattern[q];
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
                len = q - p;
                if (len > 0)
                {
                    debug(std_regex) writefln("writing string len %d, c = '%s'"
                            ", pattern[p] = '%s'", len+1, c, pattern[p]);
                    buf.reserve(5 + (1 + len) * E.sizeof);
                    buf.write((attributes & REA.ignoreCase)
                            ? REistring : REstring);
                    //auto narrow = to!string(pattern[p .. p + len]);
                    buf.write(E.sizeof * (len + 1));
                    //buf.write(narrow.length + 1);
                    buf.write(c);
                    buf.write(pattern[p .. p + len]);
                    //buf.write(narrow);
                    p = q;
                    break;
                }
            }
            if (c >= 0x80)
            {
                debug(std_regex) writefln("dchar");
                // Convert to dchar opcode
                op = (op == REchar) ? REdchar : REidchar;
                buf.write(op);
                buf.write(c);
            }
            else
            {
              Lchar:
                debug(std_regex) writefln("It's an REchar '%s'", c);
                buf.write(op);
                buf.write(cast(char)c);
            }
            break;
        }
    }

    struct Range
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
            //writefln("setbitmax(x%x), maxc = x%x", u, maxc);
            if (u <= maxc)
                return;
            maxc = u;
            auto b = u / 8;
            if (b >= maxb)
            {
                size_t u2 = base ? base - &buf.data[0] : 0;
                buf.fill0(b - maxb + 1);
                base = &buf.data[u2];
                maxb = b + 1;
                //bits = (cast(bit*)this.base)[0 .. maxc + 1];
                bits.ptr = cast(size_t*)this.base;
            }
            bits.len = maxc + 1;
        }

        void setbit2(size_t u)
        {
            setbitmax(u + 1);
            //writefln("setbit2 [x%02x] |= x%02xn", u >> 3, 1 << (u & 7));
            bits[u] = 1;
        }

    }

    int parseRange(String)(in String pattern, ref size_t p, OutBuffer buf)
    {
        int c;
        int c2;
        uint i;

        uint cmax = 0x7F;
        p++;
        ubyte op = REbit;
        if (p == pattern.length)
            goto Lerr;
        if (pattern[p] == '^')
        {
            p++;
            op = REnotbit;
            if (p == pattern.length)
                goto Lerr;
        }
        buf.write(op);
        auto offset = buf.offset;
        buf.write(cast(uint)0);         // reserve space for length
        buf.reserve(128 / 8);
        auto r = Range(buf);
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
        auto rs = RS.start;
        for (;;)
        {
            if (p == pattern.length)
                goto Lerr;
            switch (pattern[p])
            {
            case ']':
                switch (rs)
                {
                case RS.dash:
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
                        if (isword(cast(E) i))
                            r.bits[i] = 1;
                    goto Lrs;

                case 'W':
                    for (i = 1; i <= cmax; i++)
                        if (!isword(cast(E) i))
                            r.bits[i] = 1;
                    goto Lrs;

                Lrs:
                    switch (rs)
                    {
                    case RS.dash:
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
                c2 = escape(pattern, p);
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
                {
                case RS.rliteral:
                    r.setbit2(c);
                    goto case;
                case RS.start:
                    c = c2;
                    rs = RS.rliteral;
                    break;

                case RS.dash:
                    if (c > c2)
                    {
                        error("inverted range in character class");
                        return 0;
                    }
                    r.setbitmax(c2);
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
        //writefln("maxc = %d, maxb = %d",r.maxc,r.maxb);
        (cast(ushort *)&buf.data[offset])[0] = cast(ushort)r.maxc;
        (cast(ushort *)&buf.data[offset])[1] = cast(ushort)r.maxb;
        return 1;

      Lerr:
        error("invalid range");
        return 0;
    }

    int escape(String)(in String pattern, ref size_t p)
    in
    {
        assert(p < pattern.length);
    }
    body
    {
        int c;
        int i;
        E tc;

        c = pattern[p];         // none of the cases are multibyte
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
                {
                    c = c * 8 + (tc - '0');
                    // Treat overflow as if last
                    // digit was not an octal digit
                    if (c >= 0xFF)
                    {
                        c >>= 3;
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
                else if (i == 0)        // if no hex digits after \x
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

// BUG: should this include '$'?
    private int isword(dchar c) { return isAlphaNum(c) || c == '_'; }

    void printProgram(const(ubyte)[] prog = null)
    {
        if (!prog) prog = program;
        //debug(std_regex)
        {
            size_t len;
            uint n;
            uint m;
            ushort *pu;
            uint *puint;
            char[] str;

            writefln("printProgram()");
            for (uint pc = 0; pc < prog.length; )
            {
                writef("%3d: ", pc);
                switch (prog[pc])
                {
                case REchar:
                    writefln("\tREchar '%s'", cast(char)prog[pc + 1]);
                    pc += 1 + cast(uint)char.sizeof;
                    break;

                case REichar:
                    writefln("\tREichar '%s'", cast(char)prog[pc + 1]);
                    pc += 1 + cast(uint)char.sizeof;
                    break;

                case REdchar:
                    writefln("\tREdchar '%s'", *cast(dchar *)&prog[pc + 1]);
                    pc += 1 + cast(uint)dchar.sizeof;
                    break;

                case REidchar:
                    writefln("\tREidchar '%s'", *cast(dchar *)&prog[pc + 1]);
                    pc += 1 + cast(uint)dchar.sizeof;
                    break;

                case REanychar:
                    writefln("\tREanychar");
                    pc++;
                    break;

                case REstring:
                    len = *cast(size_t *)&prog[pc + 1];
                    assert(len % E.sizeof == 0);
                    len /=  E.sizeof;
                    writef("\tREstring x%x*%d, ", len, E.sizeof);
                    auto es = cast(E*) (&prog[pc + 1 + size_t.sizeof]);
                    foreach (e; es[0 .. len])
                    {
                        writef("'%s' ", e);
                    }
                    writefln("");
                    pc += 1 + cast(uint)size_t.sizeof + len * E.sizeof;
                    break;

                case REistring:
                    len = *cast(size_t *)&prog[pc + 1];
                    assert(len % E.sizeof == 0);
                    len /=  E.sizeof;
                    writef("\tREistring x%x*%d, ", len, E.sizeof);
                    auto es = cast(E*) (&prog[pc + 1 + size_t.sizeof]);
                    foreach (e; es[0 .. len])
                    {
                        writef("'%s' ", e);
                    }
                    writefln("");
                    pc += 1 + cast(uint)size_t.sizeof + len * E.sizeof;
                    break;

                case REtestbit:
                    pu = cast(ushort *)&prog[pc + 1];
                    writef("\tREtestbit %d, %d: ", pu[0], pu[1]);
                    len = pu[1];
                    {
                        ubyte * b = cast(ubyte*)pu;
                        foreach (i; 0 .. len)
                        {
                            writef(" %x", b[i]);
                        }
                        writeln();
                    }
                    pc += 1 + 2 * cast(uint)ushort.sizeof + len;
                    break;

                case REbit:
                    pu = cast(ushort *)&prog[pc + 1];
                    len = pu[1];
                    writef("\tREbit cmax=%02x, len=%d:", pu[0], len);
                    for (n = 0; n < len; n++)
                        writef(" %02x", prog[pc + 1 + 2 * ushort.sizeof + n]);
                    writefln("");
                    pc += 1 + 2 * cast(uint)ushort.sizeof + len;
                    break;

                case REnotbit:
                    pu = cast(ushort *)&prog[pc + 1];
                    writefln("\tREnotbit %d, %d", pu[0], pu[1]);
                    len = pu[1];
                    pc += 1 + 2 * cast(uint)ushort.sizeof + len;
                    break;

                case RErange:
                    len = *cast(uint *)&prog[pc + 1];
                    writefln("\tRErange %d", len);
                    // BUG: REAignoreCase?
                    pc += 1 + cast(uint)uint.sizeof + len;
                    break;

                case REnotrange:
                    len = *cast(uint *)&prog[pc + 1];
                    writefln("\tREnotrange %d", len);
                    // BUG: REAignoreCase?
                    pc += 1 + cast(uint)uint.sizeof + len;
                    break;

                case REbol:
                    writefln("\tREbol");
                    pc++;
                    break;

                case REeol:
                    writefln("\tREeol");
                    pc++;
                    break;

                case REor:
                    len = *cast(uint *)&prog[pc + 1];
                    writefln("\tREor %d, pc=>%d", len,
                            pc + 1 + uint.sizeof + len);
                    pc += 1 + cast(uint)uint.sizeof;
                    break;

                case REgoto:
                    len = *cast(uint *)&prog[pc + 1];
                    writefln("\tREgoto %d, pc=>%d",
                            len, pc + 1 + uint.sizeof + len);
                    pc += 1 + cast(uint)uint.sizeof;
                    break;

                case REcounter:
                    // n, len
                    puint = cast(uint *)&prog[pc + 1];
                    n = puint[0];
                    len = puint[1];
                    writefln("\tREcounter n=%u pc=>%d",
                             n, pc + 1 + 2*uint.sizeof + len);
                    pc += 1 + cast(uint)2*uint.sizeof;
                    break;

                case REloop:
                case REloopg:
                    //n, m, len
                    puint = cast(uint *)&prog[pc + 1];
                    n = puint[0];
                    m = puint[1];
                    len = puint[2];
                    writefln("\tREloop%s min=%u max=%u pc=>%u",
                             prog[pc] == REloopg ? "g" : "",
                             n, m, pc-len);
                    pc += 1 + cast(uint)uint.sizeof*3;
                    break;

                case REsave:
                    // n
                    n = *cast(uint *)&prog[pc + 1];
                    writefln("\tREsave %s n=%d ",
                            n % 2 ? "end" :"start", n/2);
                    pc += 1 + cast(uint)uint.sizeof;
                    break;
                case RElookahead:
                     // len, ()
                    len = *cast(uint *)&prog[pc + 1];
                    writefln("\tRElookahead len=%d, pc=>%d",
                            len, pc + 1 + uint.sizeof + len);
                    pc += 1 + cast(uint)uint.sizeof;
                    break;
                case REneglookahead:
                    // len, ()
                    len = *cast(uint *)&prog[pc + 1];
                    writefln("\tREneglookahead len=%d, pc=>%d",
                            len, pc + 1 + uint.sizeof + len);
                    pc += 1 + cast(uint)uint.sizeof;
                    break;

                case REend:
                    writefln("\tREend");
                    return;

                case REret:
                    writefln("\tREret");
                    pc++;
                    break;

                case REwordboundary:
                    writefln("\tREwordboundary");
                    pc++;
                    break;

                case REnotwordboundary:
                    writefln("\tREnotwordboundary");
                    pc++;
                    break;

                case REdigit:
                    writefln("\tREdigit");
                    pc++;
                    break;

                case REnotdigit:
                    writefln("\tREnotdigit");
                    pc++;
                    break;

                case REspace:
                    writefln("\tREspace");
                    pc++;
                    break;

                case REnotspace:
                    writefln("\tREnotspace");
                    pc++;
                    break;

                case REword:
                    writefln("\tREword");
                    pc++;
                    break;

                case REnotword:
                    writefln("\tREnotword");
                    pc++;
                    break;

                case REbackref:
                    writefln("\tREbackref %d", prog[1]);
                    pc += 2;
                    break;

                default:
                    assert(0);
                }
            }
        }
    }
}

/// Ditto
Regex!(Unqual!(ElementEncodingType!String)) regex(String)
(String pattern, string flags = null) 
    if (isSomeString!String)
{
    alias Unqual!(ElementEncodingType!String) Char;
    alias immutable(Char)[] IString;
    static Tuple!(IString, string) lastReq = tuple(cast(IString)[],"\u0001");//most unlikely
    static typeof(return) lastResult;
    if (lastReq[0] == pattern && lastReq[1] == flags)
    {
        // cache hit
        return lastResult;
    }

    auto result = typeof(return)(pattern, flags);

    lastReq[0] = to!IString(pattern);
    lastReq[1] = flags;
    lastResult = result;

    return result;
}

/**
$(D RegexMatch) is the type returned by a call to $(D match). It
stores the matching state and can be inspected and iterated.
 */
struct RegexMatch(Range = string)
{
    alias typeof(Range.init[0]) E;
    // Engine
    alias .Regex!(Unqual!E) Regex;
    private alias Regex.regmatch_t regmatch_t;
    enum stackSize = 32*1024;
/**
Get or set the engine of the match.
*/
    public Regex engine;
    // the string to search
    Range input;
    size_t src;                     // current source index in input[]
    size_t src_start;           // starting index for match in input[]
    regmatch_t[] pmatch;    // array [engine.re_nsub + 1]
    uint curCounter;
    uint[] counters;            //array [engine.counter]
/*
Build a RegexMatch from an engine.
*/
    private this(Regex engine)
    {
        this.engine = engine;
        pmatch.length = engine.re_nsub + 1;
        counters.length = engine.nCounters;
        pmatch[0].startIdx = -1;
        pmatch[0].endIdx = -1;
    }

/*
Build a RegexMatch from an engine and an input.
*/
    private this(Regex engine, Range input)
    {
        this.engine = engine;
        pmatch.length = engine.re_nsub + 1;
        pmatch[0].startIdx = -1;
        pmatch[0].endIdx = -1;
        counters.length = engine.nCounters;
        this.input = input;
        // amorsate
        test;
    }

/*
Copy zis.
*/
    this(this)
    {
        pmatch = pmatch.dup;
    }

    // ref auto opSlice()
    // {
    //     return this;
    // }

/**
Range primitives that allow incremental matching against a string.

Example:
---
import std.stdio;
import std.regex;

void main()
{
    foreach(m; match("abcabcabab", regex("ab")))
    {
        writefln("%s[%s]%s", m.pre, m.hit, m.post);
    }
}
// Prints:
// [ab]cabcabab
// abc[ab]cabab
// abcabc[ab]ab
// abcabcab[ab]
---
 */
    bool empty() const
    {
        return pmatch[0].startIdx == pmatch[0].startIdx.max;
    }

    /// Ditto
    void popFront()
    {
        assert(!empty);
        test;
    }

    /// Ditto
    RegexMatch!(Range) front()
    {
        return this;
    }

    /// Ditto
    static if (isForwardRange!Range)
    {
        @property typeof(this) save()
        {
            auto ret = this;
            ret.input = input.save;
            return ret;
        }
    }

    unittest
    {
        // @@@BUG@@@ This doesn't work if a client module uses -unittest
        // uint i;
        // foreach (m; match(to!(Range)("abcabcabab"), regex(to!(Range)("ab"))))
        // {
        //     ++i;
        //     assert(m.hit == "ab");
        //     //writefln("%s[%s]%s", m.pre, m.hit, m.post);
        // }
        // assert(i == 4);
    }

    unittest
    {
        // @@@BUG@@@ This doesn't work if a client module uses -unittest
        // debug(std_regex) writefln("regex.search.unittest()");

        // int i;
        // //foreach(m; RegexMatch("ab").search("abcabcabab"))
        // foreach(m; .match("abcabcabab", regex("ab")))
        // {
        //     auto s = std.string.format("%s[%s]%s", m.pre, m.hit, m.post);
        //     if (i == 0) assert(s == "[ab]cabcabab");
        //     else if (i == 1) assert(s == "abc[ab]cabab");
        //     else if (i == 2) assert(s == "abcabc[ab]ab");
        //     else if (i == 3) assert(s == "abcabcab[ab]");
        //     else assert(0);
        //     i++;
        // }
        // assert(i == 4);
    }

    struct Captures
    {
        private Range input;
        private regmatch_t[] matches;

        ref auto opSlice()
        {
            return this;
        }

        @property bool empty()
        {
            return matches.empty;
        }

        @property Range front()
        {
            return input[matches[0].startIdx .. matches[0].endIdx];
        }

        void popFront() {  matches.popFront; }

        @property Range back()
        {
            return input[matches[$-1].startIdx .. matches[$-1].endIdx];
        }

        void popBack() { matches.popBack; }

        @property typeof(this) save()
        {
            return this;
        }

        @property size_t length()
        {
            return matches.length;
        }

        Range opIndex(size_t n)
        {
            assert(n < length, text("length = ", length, ", requested match = ", n));
            return input[matches[n].startIdx .. matches[n].endIdx];
        }
    }

/******************
Retrieve the captured parenthesized matches, in the form of a
random-access range. The first element in the range is always the full
match.

Example:
----
foreach (m; match("abracadabra", "(.)a(.)"))
{
    foreach (c; m.captures)
        write(c, ';');
    writeln();
}
// writes:
// rac;r;c;
// dab;d;b;
----
 */
    public Captures captures()
    {
        return Captures(input, empty ? [] : pmatch);
    }

    unittest
    {
        // @@@BUG@@@ This doesn't work if a client module uses -unittest
        // auto app = appender!string();
        // foreach (m; match("abracadabra", "(.)a(.)"))
        // {
        //     assert(m.captures.length == 3);
        //     foreach (c; m.captures)
        //         app.put(c), app.put(';');
        // }
        // assert(app.data == "rac;r;c;dab;d;b;");
    }

/*******************
Returns the slice of the input that precedes the matched substring.
 */
    public Range pre()
    {
        return input[0 .. pmatch[0].startIdx != pmatch[0].startIdx.max
                ? pmatch[0].startIdx : $];
    }

/**
The matched portion of the input.
*/
    public Range hit()
    {
        assert(pmatch[0].startIdx <= pmatch[0].endIdx
                && pmatch[0].endIdx <= input.length,
                text(pmatch[0].startIdx, " .. ", pmatch[0].endIdx,
                        " vs. ", input.length));
        return input[pmatch[0].startIdx .. pmatch[0].endIdx];
    }

/*******************
Returns the slice of the input that follows the matched substring.
 */
    public Range post()
    {
        return input[pmatch[0].endIdx < $ ? pmatch[0].endIdx : $ .. $];
    }

/**
Returns $(D hit) (converted to $(D string) if necessary).
*/
    string toString()
    {
        return to!string(hit);
    }

/* ************************************************
 * Find regular expression matches in s[]. Replace those matches
 * with a new string composed of format[] merged with the result of the
 * matches.
 * If global, replace all matches. Otherwise, replace first match.
 * Returns: the new string
 */
    private Range replaceAll(String)(String format)
    {
        auto result = input;
        size_t lastindex = 0;
        size_t offset = 0;
        for (;;)
        {
            if (!test(lastindex))
                break;

            auto so = pmatch[0].startIdx;
            auto eo = pmatch[0].endIdx;

            auto replacement = replace(format);
/+
            // Optimize by using std.string.replace if possible - Dave Fladebo
            auto slice = result[offset + so .. offset + eo];
            if (attributes & REA.global &&              // global, so replace all
                    !(attributes & REA.ignoreCase) &&   // not ignoring case
                    !(attributes & REA.multiline) &&    // not multiline
                    pattern == slice &&                 // simple pattern
                                                // (exact match, no
                                                // special characters)
                    format == replacement)              // simple format, not $ formats
            {
                debug(std_regex)
                {
                    auto sss = result[offset + so .. offset + eo];
                    writefln("pattern: %s, slice: %s, format: %s, replacement: %s",
                            pattern,
                            sss,
                            format,
                            replacement);
                }
                result = std.string.replace(result, slice, replacement);
                break;
            }
+/
            result = replaceSlice(result,
                    result[offset + so .. offset + eo], replacement);

            if (engine.attributes & engine.REA.global)
            {
                offset += replacement.length - (eo - so);

                if (lastindex == eo)
                    lastindex++;                // always consume some source
                else
                    lastindex = eo;
            }
            else
                break;
        }
        return result;
    }

/*
 * Test s[] starting at startindex against regular expression.
 * Returns: 0 for no match, !=0 for match
 */

    private bool test(size_t startindex = size_t.max)
    {
        if (startindex == size_t.max)
        {
            if (pmatch[0].endIdx != pmatch[0].endIdx.max)
            {
                startindex = pmatch[0].endIdx;
                if (startindex >= input.length)
                {
                    pmatch[0].startIdx = pmatch[0].startIdx.max;
                    pmatch[0].endIdx = pmatch[0].endIdx.max;
                    return false;                   // fail
                }
                if (pmatch[0].endIdx == pmatch[0].startIdx)
                    startindex += std.utf.stride(input, pmatch[0].endIdx);
            }
            else
               startindex = 0;
        }
        debug (regex) writefln("Regex.test(input[] = '%s', startindex = %d)",
                input, startindex);

        //engine.printProgram(engine.program);
        pmatch[0].startIdx = -1;
        pmatch[0].endIdx = -1;

        // First character optimization
        Unqual!(typeof(Range.init[0])) firstc = 0;
        if (engine.program[0] == engine.REchar)
        {
            firstc = engine.program[1];
            if (engine.attributes & engine.REA.ignoreCase && isAlpha(firstc))
                firstc = 0;
        }
        ubyte* pmemory = cast(ubyte *)alloca(stackSize);
        ubyte[] memory = pmemory ? pmemory[0..stackSize] : new ubyte [stackSize];
        for (;; ++startindex)
        {
            if (firstc)
            {
                if (startindex == input.length)
                {
                    break;                      // no match
                }
                if (input[startindex] != firstc)
                {
                    startindex++;
                    if (!chr(startindex, firstc))       // 1st char not found
                        break;                          // no match
                }
            }
            foreach (i; 1 .. engine.re_nsub + 1)//subs considered empty matches
            {
                pmatch[i].startIdx = 0;
                pmatch[i].endIdx = 0;
            }
            src_start = src = startindex;

            if (trymatch(0, memory))
            {
                pmatch[0].startIdx = startindex;
                pmatch[0].endIdx = src;
                return true;
            }
            // If possible match must start at beginning, we are done
            if (engine.program[0] == engine.REbol)
            {
                if (!(engine.attributes & engine.REA.multiline)) break;
                // Scan for the next \n
                if (!chr(startindex, '\n'))
                    break;              // no match if '\n' not found
            }
            if (startindex == input.length)
                break;
            debug(std_regex)
            {
                auto sss = input[startindex + 1 .. input.length];
                writefln("Starting new try: '%s'", sss);
            }
        }
        pmatch[0].startIdx = pmatch[0].startIdx.max;
        pmatch[0].endIdx = pmatch[0].endIdx.max;
        return false;  // no match
    }

    /**
       Returns whether string $(D_PARAM s) matches $(D_PARAM this).
    */
    //alias test opEquals;

    private bool chr(ref size_t si, E c)
    {
        for (; si < input.length; si++)
        {
            if (input[si] == c)
                return 1;
        }
        return 0;
    }

    private static sizediff_t icmp(E[] a, E[] b)
    {
        static if (is(Unqual!(E) == char))
        {
            return .icmp(a, b);
        }
        else static if (is(E : dchar))
        {
            for (size_t i, j;; ++i, ++j)
            {
                if (j == b.length) return i != a.length;
                if (i == a.length) return -1;
                immutable x = std.uni.toLower(a[i]),
                    y = std.uni.toLower(b[j]);
                if (x == y) continue;
                return x - y;
            }
        }
        else
        {
            for (size_t i, j;; ++i, ++j)
            {
                if (j == b.length) return i != a.length;
                if (i == a.length) return -1;
                immutable x = a[i], y = b[j];
                if (x == y) continue;
                return x - y;
            }
        }
    }

/* *************************************************
 * Match input against a section of the program[].
 * Returns:
 *      1 if successful match
 *      0 no match
 */

    private bool trymatch(uint pc, ubyte[] memory)
    {
        /*
         * All variables related to position in input are size_t
         * almost anything else reasonably fits into uint
         */
        uint pop;
        size_t lastState = 0; //top of backtrack stack
        uint matchesToSave = 0; //number of currently used entries in pmatch
        size_t[] trackers;
        struct StateTail
        {
            //this structure is preceeded by all matches, then by all counters
            size_t src;
            uint pc, counter, matches, size;
        }
        bool backtrack()
        {
            if (lastState == 0)
                return false;
            auto tail = cast(StateTail *)&memory[lastState - StateTail.sizeof];
            pc = tail.pc;
            src = tail.src;
            matchesToSave = tail.matches;
            curCounter = tail.counter;
            lastState -= tail.size;
            debug(std_regex)
                writefln("\tBacktracked pc=>%d src='%s'", pc, input[src..$]);
            auto matchPtr = cast(regmatch_t*)&memory[lastState];
            pmatch[1..matchesToSave+1]  = matchPtr[0..matchesToSave];
            pmatch[matchesToSave+1..$] = regmatch_t(0, 0);//remove any stale matches here
            if (!counters.empty)
            {
                auto counterPtr = cast(uint*)(matchPtr+matchesToSave);
                counters[0..curCounter+1] = counterPtr[0..curCounter+1];
            }
            return true;
        }
        void memoize(uint newpc)
        {
            auto stateSize = (counters.empty ? 0 : (curCounter+1)*uint.sizeof)
                    + matchesToSave*regmatch_t.sizeof;
            if (memory.length < lastState + stateSize + StateTail.sizeof)
                memory.length += memory.length; //reallocates on heap
            auto matchPtr = cast(regmatch_t*)&memory[lastState];
            matchPtr[0..matchesToSave] = pmatch[1..matchesToSave+1];
            if (!counters.empty)
            {
                auto counterPtr = cast(uint*)(matchPtr + matchesToSave);
                counterPtr[0..curCounter+1] = counters[0..curCounter+1];
            }
            lastState += stateSize;
            auto tail = cast(StateTail *) &memory[lastState];
            tail.pc = newpc;
            tail.src = src;
            tail.matches = matchesToSave;
            tail.counter = curCounter;
            tail.size = cast(uint)(stateSize + StateTail.sizeof);
            lastState += StateTail.sizeof;
        }
        debug(std_regex)
        {
            auto sss = input[src .. input.length];
            writefln("Regex.trymatch(pc = %d, src = '%s')",
                    pc, sss);
        }
        auto srcsave = src;
        for (;;)
        {
            //writefln("\top = %d", program[pc]);
            switch (engine.program[pc])
            {
            case engine.REchar:
                if (src == input.length)
                    goto Lnomatch;
                debug(std_regex) writefln("\tREchar '%s', src = '%s'",
                                    engine.program[pc + 1], input[src]);
                if (engine.program[pc + 1] != input[src])
                    goto Lnomatch;
                src++;
                pc += 1 + cast(uint)char.sizeof;
                break;

            case engine.REichar:
                if (src == input.length)
                    goto Lnomatch;
                debug(std_regex) writefln("\tREichar '%s', src = '%s'",
                                    engine.program[pc + 1], input[src]);
                size_t c1 = engine.program[pc + 1];
                size_t c2 = input[src];
                if (c1 != c2)
                {
                    if (isLower(cast(E) c2))
                        c2 = std.ascii.toUpper(cast(E) c2);
                    else
                        goto Lnomatch;
                    if (c1 != c2)
                        goto Lnomatch;
                }
                src++;
                pc += 1 + cast(uint)char.sizeof;
                break;

            case engine.REdchar:
                if (src == input.length)
                    goto Lnomatch;
                debug(std_regex) writefln("\tREdchar '%s', src = '%s'",
                                    *(cast(dchar *)&engine.program[pc + 1]), input[src]);
                if (*(cast(dchar *)&engine.program[pc + 1]) != input[src])
                    goto Lnomatch;
                src++;
                pc += 1 + cast(uint)dchar.sizeof;
                break;

            case engine.REidchar:
                if (src == input.length)
                    goto Lnomatch;
                debug(std_regex) writefln("\tREidchar '%s', src = '%s'",
                                    *(cast(dchar *)&engine.program[pc + 1]), input[src]);
                size_t c1 = *(cast(dchar *)&engine.program[pc + 1]);
                size_t c2 = input[src];
                if (c1 != c2)
                {
                    if (isLower(cast(E) c2))
                        c2 = std.ascii.toUpper(cast(E) c2);
                    else
                        goto Lnomatch;
                    if (c1 != c2)
                        goto Lnomatch;
                }
                src++;
                pc += 1 + cast(uint)dchar.sizeof;
                break;

            case engine.REanychar:
                debug(std_regex) writefln("\tREanychar");
                if (src == input.length)
                    goto Lnomatch;
                if (!(engine.attributes & engine.REA.dotmatchlf)
                    && input[src] == '\n')
                    goto Lnomatch;
                src += std.utf.stride(input, src);
                pc++;
                break;

            case engine.REstring:
                auto len = *cast(size_t *)&engine.program[pc + 1];
                assert(len % E.sizeof == 0);
                len /= E.sizeof;
                debug(std_regex)
                {
                    auto sssa = (&engine.program[pc + 1 + size_t.sizeof])[0 .. len];
                    writefln("\tREstring x%x, '%s'", len, sssa);
                }
                if (src + len > input.length)
                    goto Lnomatch;
                if (memcmp(&engine.program[pc + 1 + size_t.sizeof],
                                &input[src], len * E.sizeof))
                    goto Lnomatch;
                src += len;
                pc += 1 + size_t.sizeof + cast(uint)len * E.sizeof;
                break;

            case engine.REistring:
                auto len = *cast(size_t *)&engine.program[pc + 1];
                assert(len % E.sizeof == 0);
                len /= E.sizeof;
                debug(std_regex)
                {
                    auto sssa = (&engine.program[pc + 1 + size_t.sizeof])[0 .. len];
                    writefln("\tREistring x%x, '%s'", len, sssa);
                }
                if (src + len > input.length)
                    goto Lnomatch;
                if (icmp(
                   (cast(E*)&engine.program[pc+1+size_t.sizeof])[0..len],
                      input[src .. src + len]))
                    goto Lnomatch;
                src += len;
                pc += 1 + size_t.sizeof + cast(uint)len * E.sizeof;
                break;

            case engine.REtestbit:
                auto pu = (cast(ushort *)&engine.program[pc + 1]);
                if (src == input.length)
                    goto Lnomatch;
                debug(std_regex) writefln("\tREtestbit %d, %d, '%s', x%02x",
                                    pu[0], pu[1], input[src], input[src]);
                auto len = pu[1];
                size_t c1 = input[src];
                if (c1 <= pu[0] &&
                   !((&(engine.program[pc + 1 + 4]))[c1 >> 3] & (1 << (c1 & 7))))
                    goto Lnomatch;
                pc += 1 + 2 * cast(uint)ushort.sizeof + len;
                break;

            case engine.REbit:
                if (src == input.length)
                    goto Lnomatch;
                auto pu = (cast(ushort *)&engine.program[pc + 1]);
                debug(std_regex) writefln("\tREbit %d, %d, '%s'",
                                    pu[0], pu[1], input[src]);
                auto len = pu[1];
                size_t c1 = input[src];
                if (c1 > pu[0])
                    goto Lnomatch;
                if (!((&engine.program[pc + 1 + 4])[c1 >> 3] & (1 << (c1 & 7))))
                    goto Lnomatch;
                src++;
                pc += 1 + 2 * cast(uint)ushort.sizeof + len;
                break;

            case engine.REnotbit:
                if (src == input.length)
                    goto Lnomatch;
                auto pu = (cast(ushort *)&engine.program[pc + 1]);
                debug(std_regex) writefln("\tREnotbit %d, %d, '%s'",
                                    pu[0], pu[1], input[src]);
                auto len = pu[1];
                size_t c1 = input[src];
                if (c1 <= pu[0] &&
                        ((&engine.program[pc + 1 + 4])[c1 >> 3] & (1 << (c1 & 7))))
                    goto Lnomatch;
                src++;
                pc += 1 + 2 * cast(uint)ushort.sizeof + len;
                break;

            case engine.RErange:
                auto len = *cast(uint *)&engine.program[pc + 1];
                debug(std_regex) writefln("\tRErange %d", len);
                if (src == input.length)
                    goto Lnomatch;
                // BUG: REA.ignoreCase?
                if (memchr(cast(char*)&engine.program[pc + 1 + uint.sizeof],
                                input[src], len) == null)
                    goto Lnomatch;
                src++;
                pc += 1 + cast(uint)uint.sizeof + len;
                break;

            case engine.REnotrange:
                auto len = *cast(uint *)&engine.program[pc + 1];
                debug(std_regex) writefln("\tREnotrange %d", len);
                if (src == input.length)
                    goto Lnomatch;
                // BUG: REA.ignoreCase?
                if (memchr(cast(char*)&engine.program[pc + 1 + uint.sizeof],
                                input[src], len) != null)
                    goto Lnomatch;
                src++;
                pc += 1 + cast(uint)uint.sizeof + len;
                break;

            case engine.REbol:
                debug(std_regex) writefln("\tREbol");
                if (src == 0)
                {
                }
                else if (engine.attributes & engine.REA.multiline)
                {
                    if (input[src - 1] != '\n')
                        goto Lnomatch;
                }
                else
                    goto Lnomatch;
                pc++;
                break;

            case engine.REeol:
                debug(std_regex) writefln("\tREeol");
                if (src == input.length)
                {
                }
                else if (engine.attributes & engine.REA.multiline
                        && input[src] == '\n')
                    src++;
                else
                    goto Lnomatch;
                pc++;
                break;

            case engine.REor:
                auto len = (cast(uint *)&engine.program[pc + 1])[0];
                debug(std_regex) writefln("\tREor %d", len);
                pop = pc + 1 + cast(uint)uint.sizeof;
                memoize(pop+len); // remember 2nd branch
                pc = pop;         // proceed with 1st branch
                break;

            case engine.REgoto:
                debug(std_regex) writefln("\tREgoto");
                auto len = (cast(uint *)&engine.program[pc + 1])[0];
                pc += 1 + cast(uint)uint.sizeof + len;
                break;

            case engine.REcounter:
                // n
                auto puint = cast(uint *)&engine.program[pc + 1];
                curCounter = puint[0];
                auto len = puint[1];
                counters[curCounter] = 0;
                if (trackers.empty)
                {
                    auto ptracker = cast(size_t *)alloca(counters.length*size_t.sizeof);
                    if (ptracker)
                        trackers = ptracker[0..counters.length];
                    else
                        trackers = new size_t[counters.length];
                }
                trackers[curCounter] = size_t.max;
                pc += len + 1 + cast(uint)2*uint.sizeof;
                break;

            case engine.REloop:
            case engine.REloopg:
                // n, m, len
                auto puint = cast(uint *)&engine.program[pc + 1];
                auto n = puint[0];
                auto m = puint[1];
                auto len = puint[2];

                debug(std_regex)
                    writefln("\tREloop%s min=%u, max=%u pc=>%d",
                        (engine.program[pc] == engine.REloopg) ? "g" : "",
                        n, m, pc - len);
                if (counters[curCounter] < n)
                {
                    counters[curCounter]++;
                    pc = pc - len;
                    break;
                }
                else if (counters[curCounter] == m
                        || trackers[curCounter] == src)
                {//proceed with outer loops
                    curCounter--;
                    pc += 1 + cast(uint)uint.sizeof*3;
                    break;
                }
                counters[curCounter]++;
                if (engine.program[pc] == engine.REloop)
                {
                    memoize(pc-len); //memoize next step of loop
                    curCounter--;
                    pc += 1 + cast(uint)uint.sizeof*3; // proceed with outer loop
                }
                else    // maximal munch
                {
                    curCounter--;
                    memoize(pc + 1 + cast(uint)uint.sizeof*3);
                    curCounter++;
                    pc = pc - len; //move on with the loop
                    trackers[curCounter] = src;
                }
                break;

            case engine.REsave:
                // n
                debug(std_regex) writefln("\tREsave");
                auto n = *cast(uint *)&engine.program[pc + 1];
                (cast(size_t*)pmatch)[n] = src;
                debug(std_regex)
                {
                    if (n % 2)
                        writefln("\tmatch # %d at %d .. %d", n/2,
                                 pmatch[n/2].startIdx, pmatch[n/2].endIdx);
                }
                matchesToSave = max(n/2, matchesToSave);
                pc += cast(uint)uint.sizeof+1;
                break;

            case engine.RElookahead:
            case engine.REneglookahead:
                // len, ()
                debug(std_regex)
                    writef("\t%s", engine.program[pc] == engine.RElookahead ?
                        "RElookahead" : "REneglookahead");
                auto len = *cast(uint*)&engine.program[pc+1];
                pop = pc + 1 + cast(uint)uint.sizeof;
                bool invert = engine.program[pc] == engine.REneglookahead ? true : false;
                auto tmp_match = trymatch(pop, memory[lastState..$]);
                //inverse the match if negative lookahead
                tmp_match = tmp_match ^ invert;
                if (!tmp_match)
                    goto Lnomatch;
                pc = pop + len;
                break;

            case engine.REret:
                debug(std_regex) writefln("\tREret");
                src = srcsave;
                return 1;

            case engine.REend:
                debug(std_regex) writefln("\tREend");
                return 1;               // successful match

            case engine.REwordboundary:
                debug(std_regex) writefln("\tREwordboundary");
                if (src > 0 && src < input.length)
                {
                    size_t c1 = input[src - 1];
                    size_t c2 = input[src];
                    if (!((engine.isword(cast(E)c1) && !engine.isword(cast(E)c2)) ||
                       (!engine.isword(cast(E)c1) && engine.isword(cast(E)c2))))
                        goto Lnomatch;
                }
                pc++;
                break;

            case engine.REnotwordboundary:
                debug(std_regex) writefln("\tREnotwordboundary");
                if (src == 0 || src == input.length)
                    goto Lnomatch;
                size_t c1 = input[src - 1];
                size_t c2 = input[src];
                if (
                    (engine.isword(cast(E)c1) && !engine.isword(cast(E)c2)) ||
                    (!engine.isword(cast(E)c1) && engine.isword(cast(E)c2))
                    )
                    goto Lnomatch;
                pc++;
                break;

            case engine.REdigit:
                debug(std_regex) writefln("\tREdigit");
                if (src == input.length)
                    goto Lnomatch;
                if (!isDigit(input[src]))
                    goto Lnomatch;
                src++;
                pc++;
                break;

            case engine.REnotdigit:
                debug(std_regex) writefln("\tREnotdigit");
                if (src == input.length)
                    goto Lnomatch;
                if (isDigit(input[src]))
                    goto Lnomatch;
                src++;
                pc++;
                break;

            case engine.REspace:
                debug(std_regex) writefln("\tREspace");
                if (src == input.length)
                    goto Lnomatch;
                if (!isWhite(input[src]))
                    goto Lnomatch;
                src++;
                pc++;
                break;

            case engine.REnotspace:
                debug(std_regex) writefln("\tREnotspace");
                if (src == input.length)
                    goto Lnomatch;
                if (isWhite(input[src]))
                    goto Lnomatch;
                src++;
                pc++;
                break;

            case engine.REword:
                debug(std_regex) writefln("\tREword");
                if (src == input.length)
                    goto Lnomatch;
                if (!engine.isword(input[src]))
                    goto Lnomatch;
                src++;
                pc++;
                break;

            case engine.REnotword:
                debug(std_regex) writefln("\tREnotword");
                if (src == input.length)
                    goto Lnomatch;
                if (engine.isword(input[src]))
                    goto Lnomatch;
                src++;
                pc++;
                break;

            case engine.REbackref:
            {
                auto n = engine.program[pc + 1];
                debug(std_regex) writefln("\tREbackref %d", n);

                auto so = pmatch[n + 1].startIdx;
                auto eo = pmatch[n + 1].endIdx;
                auto len = eo - so;
                                debug(std_regex) writefln("len \t%d", len);
                if (src + len > input.length)
                    goto Lnomatch;

                else if (engine.attributes & engine.REA.ignoreCase)
                {
                    if (icmp(input[src .. src + len], input[so .. eo]))
                        goto Lnomatch;
                }
                else if (memcmp(&input[src], &input[so], len * E.sizeof))
                    goto Lnomatch;
                src += len;
                pc += 2;
                break;
            }

            default:
                assert(0);
Lnomatch:
                if (!backtrack())
                {
                    src = srcsave;
                    return false;
                }
            }
        }
        assert(0);
    }

// p is following the \ char
/* ==================== replace ======================= */

/*
After a match was found, this function will take the match results
and, using the format string, generate and return a new string.
 */

    private Range replace(String)(String format)
    {
        return replace3(format, input, pmatch[0 .. engine.re_nsub + 1]);
    }

// Static version that doesn't require a Regex object to be created

    private static Range replace3(String)(String format, Range input,
            regmatch_t[] pmatch)
    {
        Range result;
        uint c2;
        sizediff_t startIdx;
        sizediff_t endIdx;
        int i;

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
                startIdx = pmatch[0].startIdx;
                endIdx = pmatch[0].endIdx;
                goto Lstring;

            case '`':
                startIdx = 0;
                endIdx = pmatch[0].startIdx;
                goto Lstring;

            case '\'':
                startIdx = pmatch[0].endIdx;
                endIdx = input.length;
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
                {
                    startIdx = pmatch[i].startIdx;
                    endIdx = pmatch[i].endIdx;
                    goto Lstring;
                }
                break;

            Lstring:
                if (startIdx != endIdx)
                    result ~= input[startIdx .. endIdx];
                break;

            default:
                result ~= '$';
                result ~= c;
                break;
            }
        }
        return result;
    }

/* ***********************************
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

    deprecated private string replaceOld(string format)
    {
        string result;

//writefln("replace: this = %p so = %d, eo = %d", this, pmatch[0].startIdx, pmatch[0].endIdx);
//writefln("3input = '%s'", input);
        result.length = format.length;
        result.length = 0;
        for (size_t i; i < format.length; i++)
        {
            char c = format[i];
            switch (c)
            {
            case '&':
                result ~= to!string(
                    input[pmatch[0].startIdx .. pmatch[0].endIdx]);
                break;

            case '\\':
                if (i + 1 < format.length)
                {
                    c = format[++i];
                    if (c >= '1' && c <= '9')
                    {
                        uint j = c - '0';
                        if (j <= engine.re_nsub && pmatch[j].startIdx
                                != pmatch[j].endIdx)
                            result ~= to!string
                                (input[pmatch[j].startIdx .. pmatch[j].endIdx]);
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
} // end of class RegexMatch

unittest
{
    debug(std_regex) writefln("regex.replace.unittest()");
    auto r = match("1ab2ac3", regex("a[bc]", "g"));
    auto result = r.replaceAll("x$&y");
    auto i = std.string.cmp(result, "1xaby2xacy3");
    assert(i == 0);

    r = match("1ab2ac3", regex("ab", "g"));
    result = r.replaceAll("xy");
    i = std.string.cmp(result, "1xy2ac3");
    assert(i == 0);

    r = match("wyda", regex("(giba)"));
    assert(r.captures.length == 0);
}

unittest
{
    //@@@
    assert(!match("abc", regex(".b.")).empty);
    assert(match("abc", regex(".b..")).empty);
}

//------------------------------------------------------------------------------

/**
Matches a string against a regular expression. This is the main entry
to the module's functionality. A call to $(D match(input, regex))
returns a $(D RegexMatch) object that can be used for direct
inspection or for iterating over all matches (if the regular
expression was built with the "g" option).
 */
RegexMatch!(Range) match(Range, Engine)(Range r, Engine engine)
if (is(Unqual!Engine == Regex!(Unqual!(typeof(Range.init[0])))))
{
    return typeof(return)(engine, r);
}

RegexMatch!(Range) match(Range, E)(Range r, E[] engine, string opt = null)
//if (is(Engine == Regex!(Unqual!(ElementType!(Range)))))
{
    return typeof(return)(regex(engine, opt), r);
}

unittest
{

    string abr = "abracadabra";
    "abracadabra".match(regex("a[b-e]", "g"));
    abr.match(regex("a[b-e]", "g"));
    "abracadabra".match("a[b-e]", "g");
    abr.match("a[b-e]", "g");
    // Created and placed in public domain by Don Clugston
    auto re = regex(`bc\x20r[\40]s`, "i");
    auto m = match("aBC r s", re);
    static assert(isForwardRange!(typeof(m)));
    static assert(isRandomAccessRange!(typeof(m.captures())));

    assert(m.pre=="a");
    assert(m.hit=="BC r s");
    auto m2 = match("7xxyxxx", regex(`^\d([a-z]{2})\D\1`));
    assert(!m2.empty);
    assert(m2.hit=="7xxyxx");
    // Just check the parsing.
    auto m3 = match("dcbxx", regex(`ca|b[\d\]\D\s\S\w-\W]`));
    assert(!m3.empty);
    auto m4 = match("xy", regex(`[^\ca-\xFa\r\n\b\f\t\v\0123]{2,485}$`));
    assert(m4.empty);
    auto m5 = match("xxx", regex(`^^\r\n\b{13,}\f{4}\t\v\u02aF3a\w\W`));
    assert(m5.empty);
    auto m6 = match("xxy", regex(`.*y`));
    assert(!m6.empty);
    assert(m6.hit=="xxy");
    auto m7 = match("QWDEfGH"d, regex("(ca|b|defg)+"d, "i"));
    assert(!m7.empty);
    assert(m7.hit=="DEfG");
    auto m8 = match("dcbxx"w, regex(`a?\B\s\S`w));
    assert(m8.empty);
    auto m9 = match("dcbxx"d, regex(`[-w]`d));
    assert(m9.empty);
    auto m10 = match("dcbsfd"w,
            regex(`aB[c-fW]dB|\d|\D|\u012356|\w|\W|\s|\S`w, "i"));
    assert(!m10.empty);
    auto m11 = match("dcbsfd", regex(`[]a-]`));
    assert(m11.empty);
    //m.replaceOld(`a&b\1c`);
    m.replace(`a$&b$'$1c`);
}

/******************************************************
Search string for matches with regular expression pattern with
attributes.  Replace the first match with string generated from $(D
format). If the regular expression has the $(D "g") (global)
attribute, continue and replace all matches.

Params:
input = Range to search.
regex = Regular expression pattern.
format = Replacement string format.

Returns:
The resulting string.

Example:
---
s = "ark rapacity";
assert(replace(s, regex("r"), "c") == "ack rapacity");
assert(replace(s, regex("r", "g"), "c") == "ack capacity");
---

The replacement format can reference the matches using the $&amp;, $$,
$', $`, $0 .. $99 notation:

---
assert(replace("noon", regex("^n"), "[$&]") == "[n]oon");
---
 */

Range replace(Range, Engine, String)(Range input, Engine regex, String format)
if (is(Unqual!Engine == Regex!(Unqual!(typeof(Range.init[0])))))
{
    return RegexMatch!(Range)(regex, input).replaceAll(format);
}

unittest
{
    debug(std_regex) writefln("regex.sub.unittest");
    assert(replace("hello", regex("ll"), "ss") == "hesso");
    assert(replace("barat", regex("a"), "A") == "bArat");
    assert(replace("barat", regex("a", "g"), "A") == "bArAt");
    auto s = "ark rapacity";
    assert(replace(s, regex("r"), "c") == "ack rapacity");
    assert(replace(s, regex("r", "g"), "c") == "ack capacity");
    assert(replace("noon", regex("^n"), "[$&]") == "[n]oon");
}

// @@@BUG@@@ workaround for bug 5003
private bool _dummyTest(Engine)(ref Engine r, size_t idx)
{
    return r.test(idx);
}

// @@@BUG@@@ workaround for bug 5003
private ubyte _dummyAttributes(Engine)(ref Engine r)
{
    return r.attributes;
}

/*******************************************************
Search string for matches with regular expression pattern with
attributes.  Pass each match to function $(D fun).  Replace each match
with the return value from dg.

Params:
s = String to search.
pattern = Regular expression pattern.
dg = Delegate

Returns: the resulting string.
Example:
Capitalize the letters 'a' and 'r':
---
string baz(RegexMatch!(string) m)
{
    return std.string.toUpper(m.hit);
}
auto s = replace!(baz)("Strap a rocket engine on a chicken.",
        regex("[ar]", "g"));
assert(s == "StRAp A Rocket engine on A chicken.");
---
 */

Range replace(alias fun, Range, Regex)
(Range s, Regex rx)
{
    auto r = match(s, rx);

    auto result = s;
    size_t lastindex = 0;
    size_t offset = 0;
    // @@@BUG@@@ workaround for bug 5003
    while (_dummyTest(r, lastindex))
    {
        auto so = r.pmatch[0].startIdx;
        auto eo = r.pmatch[0].endIdx;
        auto replacement = unaryFun!(fun)(r);
/+
        // Optimize by using std.string.replace if possible - Dave Fladebo
        auto slice = result[offset + so .. offset + eo];
        if (rx.attributes & rx.REA.global &&            // global, so replace all
                !(rx.attributes & rx.REA.ignoreCase) && // not ignoring case
                !(rx.attributes & rx.REA.multiline) &&  // not multiline
                pattern == slice) // simple pattern (exact match, no
                                  // special characters)
        {
            debug(std_regex)
            {
                auto sss = result[offset + so .. offset + eo];
                writefln("pattern: %s, slice: %s, replacement: %s",
                    pattern,
                    sss,
                    replacement);
            result = std.string.replace(result, slice, replacement);
            break;
        }
+/
        result = replaceSlice(result, result[offset + so .. offset + eo],
                replacement);

        // @@@BUG@@@ workaround for bug 5003
        if (_dummyAttributes(rx) & rx.REA.global)
        {
            offset += replacement.length - (eo - so);

            if (lastindex == eo)
                lastindex++;            // always consume some source
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
    //debug(std_regex) writefln("regex.sub.unittest");
    string foo(RegexMatch!(string) r) { return "ss"; }
    auto r = replace!(foo)("hello", regex("ll"));
    assert(r == "hesso");

    string bar(RegexMatch!(string) r) { return "l"; }
    r = replace!(bar)("hello", regex("l", "g"));
    assert(r == "hello");

    string baz(RegexMatch!(string) m)
    {
        return std.string.toUpper(m.hit);
    }
    auto s = replace!(baz)("Strap a rocket engine on a chicken.",
            regex("[ar]", "g"));
    assert(s == "StRAp A Rocket engine on A chicken.");
}

//------------------------------------------------------------------------------

/**
Range that splits another range using a regular expression as a
separator.

Example:
----
auto s1 = ", abc, de,  fg, hi, ";
assert(equal(splitter(s1, regex(", *")),
    ["", "abc", "de", "fg", "hi", ""][]));
----
 */
struct Splitter(Range)
{
    Range _input;
    size_t _offset;
    alias Regex!(Unqual!(typeof(Range.init[0]))) Rx;
    // Rx _rx;
    RegexMatch!(Range) _match;

    this(Range input, Rx separator)
    {
        _input = input;
        if (_input.empty)
        {
            // there is nothing to match at all, make _offset > 0
            _offset = 1;
        }
        else
        {
            _match = match(_input, separator);
        }
    }

    // @@@BUG 2674 and 2675
    // this(this)
    // {
    //     _match.pmatch = _match.pmatch.dup;
    // }

    ref auto opSlice()
    {
        return this;
    }

    @property Range front()
    {
        //write("[");scope(success) writeln("]");
        assert(!empty && _offset <= _match.pre.length
                && _match.pre.length <= _input.length);
        return _input[_offset .. min($, _match.pre.length)];
    }

    @property bool empty()
    {
        return _offset > _input.length;
    }

    void popFront()
    {
        //write("[");scope(success) writeln("]");
        assert(!empty);
        if (_match.empty)
        {
            // No more separators, work is done here
            _offset = _input.length + 1;
        }
        else
        {
            // skip past the separator
            _offset = _match.pre.length + _match.hit.length;
            _match.popFront;
        }
    }

    static if (isForwardRange!Range)
    {
        @property typeof(this) save()
        {
            auto ret = this;
            ret._input = _input.save;
            ret._match = _match.save;
            return ret;
        }
    }
}

/// Ditto
Splitter!(Range) splitter(Range, Regex)(Range r, Regex pat)
if (is(Unqual!(typeof(Range.init[0])) == char))
{
    static assert(is(Unqual!(typeof(Range.init[0])) == char),
        Unqual!(typeof(Range.init[0])).stringof);
    return Splitter!(Range)(r, pat);
}

unittest
{
    auto s1 = ", abc, de,  fg, hi, ";
    auto sp1 = splitter(s1, regex(", *"));
    auto w1 = ["", "abc", "de", "fg", "hi", ""];
    assert(equal(sp1, w1[]));

    auto s2 = ", abc, de,  fg, hi";
    auto sp2 = splitter(s2, regex(", *"));
    auto w2 = ["", "abc", "de", "fg", "hi"];
    //foreach (e; sp2) writeln(e);
    assert(equal(sp2, w2[]));
}

unittest
{
    char[] s1 = ", abc, de,  fg, hi, ".dup;
    auto sp2 = splitter(s1, regex(", *"));
}

String[] split(String)(String input, Regex!(char) rx)
{
    auto a = appender!(String[])();
    foreach (e; splitter(input, rx))
    {
        a.put(e);
    }
    return a.data;
}

unittest
{
    auto s1 = ", abc, de,  fg, hi, ";
    auto w1 = ["", "abc", "de", "fg", "hi", ""];
    assert(equal(split(s1, regex(", *")), w1[]));
}

/*
 *  Copyright (C) 2000-2005 by Digital Mars, www.digitalmars.com
 *  Written by Walter Bright and Andrei Alexandrescu
 *
 *  This software is provided 'as-is', without any express or implied
 *  warranty. In no event will the authors be held liable for any damages
 *  arising from the use of this software.
 *
 *  Permission is granted to anyone to use this software for any purpose,
 *  including commercial applications, and to alter it and redistribute it
 *  freely, subject to the following restrictions:
 *
 *  o  The origin of this software must not be misrepresented; you must not
 *     claim that you wrote the original software. If you use this software
 *     in a product, an acknowledgment in the product documentation would be
 *     appreciated but is not required.
 *  o  Altered source versions must be plainly marked as such, and must not
 *     be misrepresented as being the original software.
 *  o  This notice may not be removed or altered from any source
 *     distribution.
 */


/* The test vectors in this file are altered from Henry Spencer's regexp
   test code. His copyright notice is:

        Copyright (c) 1986 by University of Toronto.
        Written by Henry Spencer.  Not derived from licensed software.

        Permission is granted to anyone to use this software for any
        purpose on any computer system, and to redistribute it freely,
        subject to the following restrictions:

        1. The author is not responsible for the consequences of use of
                this software, no matter how awful, even if they arise
                from defects in it.

        2. The origin of this software must not be misrepresented, either
                by explicit claim or by omission.

        3. Altered versions must be plainly marked as such, and must not
                be misrepresented as being the original software.


 */

unittest
{
    struct TestVectors
    {
        string pattern;
        string input;
        string result;
        string format;
        string replace;
    };

    static TestVectors tv[] = [
        {  "(a)\\1",    "abaab","y",    "&",    "aa" },
        {  "abc",       "abc",  "y",    "&",    "abc" },
        {  "abc",       "xbc",  "n",    "-",    "-" },
        {  "abc",       "axc",  "n",    "-",    "-" },
        {  "abc",       "abx",  "n",    "-",    "-" },
        {  "abc",       "xabcy","y",    "&",    "abc" },
        {  "abc",       "ababc","y",    "&",    "abc" },
        {  "ab*c",      "abc",  "y",    "&",    "abc" },
        {  "ab*bc",     "abc",  "y",    "&",    "abc" },
        {  "ab*bc",     "abbc", "y",    "&",    "abbc" },
        {  "ab*bc",     "abbbbc","y",   "&",    "abbbbc" },
        {  "ab+bc",     "abbc", "y",    "&",    "abbc" },
        {  "ab+bc",     "abc",  "n",    "-",    "-" },
        {  "ab+bc",     "abq",  "n",    "-",    "-" },
        {  "ab+bc",     "abbbbc","y",   "&",    "abbbbc" },
        {  "ab?bc",     "abbc", "y",    "&",    "abbc" },
        {  "ab?bc",     "abc",  "y",    "&",    "abc" },
        {  "ab?bc",     "abbbbc","n",   "-",    "-" },
        {  "ab?c",      "abc",  "y",    "&",    "abc" },
        {  "^abc$",     "abc",  "y",    "&",    "abc" },
        {  "^abc$",     "abcc", "n",    "-",    "-" },
        {  "^abc",      "abcc", "y",    "&",    "abc" },
        {  "^abc$",     "aabc", "n",    "-",    "-" },
        {  "abc$",      "aabc", "y",    "&",    "abc" },
        {  "^",         "abc",  "y",    "&",    "" },
        {  "$",         "abc",  "y",    "&",    "" },
        {  "a.c",       "abc",  "y",    "&",    "abc" },
        {  "a.c",       "axc",  "y",    "&",    "axc" },
        {  "a.*c",      "axyzc","y",    "&",    "axyzc" },
        {  "a.*c",      "axyzd","n",    "-",    "-" },
        {  "a[bc]d",    "abc",  "n",    "-",    "-" },
        {  "a[bc]d",    "abd",  "y",    "&",    "abd" },
        {  "a[b-d]e",   "abd",  "n",    "-",    "-" },
        {  "a[b-d]e",   "ace",  "y",    "&",    "ace" },
        {  "a[b-d]",    "aac",  "y",    "&",    "ac" },
        {  "a[-b]",     "a-",   "y",    "&",    "a-" },
        {  "a[b-]",     "a-",   "y",    "&",    "a-" },
        {  "a[b-a]",    "-",    "c",    "-",    "-" },
        {  "a[]b",      "-",    "c",    "-",    "-" },
        {  "a[",        "-",    "c",    "-",    "-" },
        {  "a]",        "a]",   "y",    "&",    "a]" },
        {  "a[]]b",     "a]b",  "y",    "&",    "a]b" },
        {  "a[^bc]d",   "aed",  "y",    "&",    "aed" },
        {  "a[^bc]d",   "abd",  "n",    "-",    "-" },
        {  "a[^-b]c",   "adc",  "y",    "&",    "adc" },
        {  "a[^-b]c",   "a-c",  "n",    "-",    "-" },
        {  "a[^]b]c",   "a]c",  "n",    "-",    "-" },
        {  "a[^]b]c",   "adc",  "y",    "&",    "adc" },
        {  "ab|cd",     "abc",  "y",    "&",    "ab" },
        {  "ab|cd",     "abcd", "y",    "&",    "ab" },
        {  "()ef",      "def",  "y",    "&-\\1",        "ef-" },
        {  "()*",       "-",    "y",    "-",    "-" },
        {  "*a",        "-",    "c",    "-",    "-" },
        {  "^*",        "-",    "y",    "-",    "-" },
        {  "$*",        "-",    "y",    "-",    "-" },
        {  "(*)b",      "-",    "c",    "-",    "-" },
        {  "$b",        "b",    "n",    "-",    "-" },
        {  "a\\",       "-",    "c",    "-",    "-" },
        {  "a\\(b",     "a(b",  "y",    "&-\\1",        "a(b-" },
        {  "a\\(*b",    "ab",   "y",    "&",    "ab" },
        {  "a\\(*b",    "a((b", "y",    "&",    "a((b" },
        {  "a\\\\b",    "a\\b", "y",    "&",    "a\\b" },
        {  "abc)",      "-",    "c",    "-",    "-" },
        {  "(abc",      "-",    "c",    "-",    "-" },
        {  "((a))",     "abc",  "y",    "&-\\1-\\2",    "a-a-a" },
        {  "(a)b(c)",   "abc",  "y",    "&-\\1-\\2",    "abc-a-c" },
        {  "a+b+c",     "aabbabc","y",  "&",    "abc" },
        {  "a**",       "-",    "c",    "-",    "-" },
        {  "a*?a",      "aa",   "y",    "&",    "a" },
        {  "(a*)*",     "aaa",  "y",    "-",    "-" },
        {  "(a*)+",     "aaa",  "y",    "-",    "-" },
        {  "(a|)*",     "-",    "y",    "-",    "-" },
        {  "(a*|b)*",   "aabb", "y",    "-",    "-" },
        {  "(a|b)*",    "ab",   "y",    "&-\\1",        "ab-b" },
        {  "(a+|b)*",   "ab",   "y",    "&-\\1",        "ab-b" },
        {  "(a+|b)+",   "ab",   "y",    "&-\\1",        "ab-b" },
        {  "(a+|b)?",   "ab",   "y",    "&-\\1",        "a-a" },
        {  "[^ab]*",    "cde",  "y",    "&",    "cde" },
        {  "(^)*",      "-",    "y",    "-",    "-" },
        {  "(ab|)*",    "-",    "y",    "-",    "-" },
        {  ")(",        "-",    "c",    "-",    "-" },
        {  "",  "abc",  "y",    "&",    "" },
        {  "abc",       "",     "n",    "-",    "-" },
        {  "a*",        "",     "y",    "&",    "" },
        {  "([abc])*d", "abbbcd",       "y",    "&-\\1",        "abbbcd-c" },
        {  "([abc])*bcd", "abcd",       "y",    "&-\\1",        "abcd-a" },
        {  "a|b|c|d|e", "e",    "y",    "&",    "e" },
        {  "(a|b|c|d|e)f", "ef",        "y",    "&-\\1",        "ef-e" },
        {  "((a*|b))*", "aabb", "y",    "-",    "-" },
        {  "abcd*efg",  "abcdefg",      "y",    "&",    "abcdefg" },
        {  "ab*",       "xabyabbbz",    "y",    "&",    "ab" },
        {  "ab*",       "xayabbbz",     "y",    "&",    "a" },
        {  "(ab|cd)e",  "abcde",        "y",    "&-\\1",        "cde-cd" },
        {  "[abhgefdc]ij",      "hij",  "y",    "&",    "hij" },
        {  "^(ab|cd)e", "abcde",        "n",    "x\\1y",        "xy" },
        {  "(abc|)ef",  "abcdef",       "y",    "&-\\1",        "ef-" },
        {  "(a|b)c*d",  "abcd", "y",    "&-\\1",        "bcd-b" },
        {  "(ab|ab*)bc",        "abc",  "y",    "&-\\1",        "abc-a" },
        {  "a([bc]*)c*",        "abc",  "y",    "&-\\1",        "abc-bc" },
        {  "a([bc]*)(c*d)",     "abcd", "y",    "&-\\1-\\2",    "abcd-bc-d" },
        {  "a([bc]+)(c*d)",     "abcd", "y",    "&-\\1-\\2",    "abcd-bc-d" },
        {  "a([bc]*)(c+d)",     "abcd", "y",    "&-\\1-\\2",    "abcd-b-cd" },
        {  "a[bcd]*dcdcde",     "adcdcde",      "y",    "&",    "adcdcde" },
        {  "a[bcd]+dcdcde",     "adcdcde",      "n",    "-",    "-" },
        {  "(ab|a)b*c", "abc",  "y",    "&-\\1",        "abc-ab" },
        {  "((a)(b)c)(d)",      "abcd", "y",    "\\1-\\2-\\3-\\4",      "abc-a-b-d" },
        {  "[a-zA-Z_][a-zA-Z0-9_]*",    "alpha",        "y",    "&",    "alpha" },
        {  "^a(bc+|b[eh])g|.h$",        "abh",  "y",    "&-\\1",        "bh-" },
        {  "(bc+d$|ef*g.|h?i(j|k))",    "effgz",        "y",    "&-\\1-\\2",    "effgz-effgz-" },
        {  "(bc+d$|ef*g.|h?i(j|k))",    "ij",   "y",    "&-\\1-\\2",    "ij-ij-j" },
        {  "(bc+d$|ef*g.|h?i(j|k))",    "effg", "n",    "-",    "-" },
        {  "(bc+d$|ef*g.|h?i(j|k))",    "bcdd", "n",    "-",    "-" },
        {  "(bc+d$|ef*g.|h?i(j|k))",    "reffgz",       "y",    "&-\\1-\\2",    "effgz-effgz-" },
        {  "(((((((((a)))))))))",       "a",    "y",    "&",    "a" },
        {  "multiple words of text",    "uh-uh",        "n",    "-",    "-" },
        {  "multiple words",    "multiple words, yeah", "y",    "&",    "multiple words" },
        {  "(.*)c(.*)", "abcde",        "y",    "&-\\1-\\2",    "abcde-ab-de" },
        {  "\\((.*), (.*)\\)",  "(a, b)",       "y",    "(\\2, \\1)",   "(b, a)" },
        {  "abcd",      "abcd", "y",    "&-\\&-\\\\&",  "abcd-&-\\abcd" },
        {  "a(bc)d",    "abcd", "y",    "\\1-\\\\1-\\\\\\1",    "bc-\\1-\\bc" },
        {  "[k]",                       "ab",   "n",    "-",    "-" },
        {  "[ -~]*",                    "abc",  "y",    "&",    "abc" },
        {  "[ -~ -~]*",         "abc",  "y",    "&",    "abc" },
        {  "[ -~ -~ -~]*",              "abc",  "y",    "&",    "abc" },
        {  "[ -~ -~ -~ -~]*",           "abc",  "y",    "&",    "abc" },
        {  "[ -~ -~ -~ -~ -~]*",        "abc",  "y",    "&",    "abc" },
        {  "[ -~ -~ -~ -~ -~ -~]*",     "abc",  "y",    "&",    "abc" },
        {  "[ -~ -~ -~ -~ -~ -~ -~]*",  "abc",  "y",    "&",    "abc" },
        {  "a{2}",      "candy",                "n",    "",     "" },
        {  "a{2}",      "caandy",               "y",    "&",    "aa" },
        {  "a{2}",      "caaandy",              "y",    "&",    "aa" },
        {  "a{2,}",     "candy",                "n",    "",     "" },
        {  "a{2,}",     "caandy",               "y",    "&",    "aa" },
        {  "a{2,}",     "caaaaaandy",           "y",    "&",    "aaaaaa" },
        {  "a{1,3}",    "cndy",                 "n",    "",     "" },
        {  "a{1,3}",    "candy",                "y",    "&",    "a" },
        {  "a{1,3}",    "caandy",               "y",    "&",    "aa" },
        {  "a{1,3}",    "caaaaaandy",           "y",    "&",    "aaa" },
        {  "e?le?",     "angel",                "y",    "&",    "el" },
        {  "e?le?",     "angle",                "y",    "&",    "le" },
        {  "\\bn\\w",   "noonday",              "y",    "&",    "no" },
        {  "\\wy\\b",   "possibly yesterday",   "y",    "&",    "ly" },
        {  "\\w\\Bn",   "noonday",              "y",    "&",    "on" },
        {  "y\\B\\w",   "possibly yesterday",   "y",    "&",    "ye" },
        {  "\\cJ",      "abc\ndef",             "y",    "&",    "\n" },
        {  "\\d",       "B2 is",                "y",    "&",    "2" },
        {  "\\D",       "B2 is",                "y",    "&",    "B" },
        {  "\\s\\w*",   "foo bar",              "y",    "&",    " bar" },
        {  "\\S\\w*",   "foo bar",              "y",    "&",    "foo" },
        {  "abc",       "ababc",                "y",    "&",    "abc" },
        {  "apple(,)\\sorange\\1",      "apple, orange, cherry, peach", "y", "&", "apple, orange," },
        {  "(\\w+)\\s(\\w+)",           "John Smith", "y", "\\2, \\1", "Smith, John" },
        {  "\\n\\f\\r\\t\\v",           "abc\n\f\r\t\vdef", "y", "&", "\n\f\r\t\v" },
        {  ".*c",       "abcde",                "y",    "&",    "abc" },
        {  "^\\w+((;|=)\\w+)+$", "some=host=tld", "y", "&-\\1-\\2", "some=host=tld-=tld-=" },
        {  "^\\w+((\\.|-)\\w+)+$", "some.host.tld", "y", "&-\\1-\\2", "some.host.tld-.tld-." },
        {  "q(a|b)*q",  "xxqababqyy",           "y",    "&-\\1",        "qababq-b" },
        {  "^(a)(b){0,1}(c*)",   "abcc", "y", "\\1 \\2 \\3", "a b cc" },
        {  "^(a)((b){0,1})(c*)", "abcc", "y", "\\1 \\2 \\3", "a b b" },
        {  "^(a)(b)?(c*)",       "abcc", "y", "\\1 \\2 \\3", "a b cc" },
        {  "^(a)((b)?)(c*)",     "abcc", "y", "\\1 \\2 \\3", "a b b" },
        {  "^(a)(b){0,1}(c*)",   "acc",  "y", "\\1 \\2 \\3", "a  cc" },
        {  "^(a)((b){0,1})(c*)", "acc",  "y", "\\1 \\2 \\3", "a  " },
        {  "^(a)(b)?(c*)",       "acc",  "y", "\\1 \\2 \\3", "a  cc" },
        {  "^(a)((b)?)(c*)",     "acc",  "y", "\\1 \\2 \\3", "a  " },
        {"(?:ab){3}",       "_abababc",  "y","&-\\1","ababab-" },
        {"(?:a(?:x)?)+",    "aaxaxx",     "y","&-\\1-\\2","aaxax--" },
        {"foo.(?=bar)",     "foobar foodbar", "y","&-\\1", "food-" },
        {"(?:(.)(?!\\1))+",  "12345678990", "y", "&-\\1", "12345678-8" },

        ];

    int i;
    sizediff_t a;
    uint c;
    sizediff_t start;
    sizediff_t end;
    TestVectors tvd;

    foreach (Char; TypeTuple!(char, wchar, dchar))
    {
        alias immutable(Char)[] String;
        String produceExpected(Range)(RegexMatch!(Range) m, String fmt)
        {
            String result;
            while (!fmt.empty)
                switch (fmt.front)
                {
                    case '\\':
                        fmt.popFront();
                        if (!isDigit(fmt.front) )
                        {
                            result ~= fmt.front;
                            fmt.popFront();
                            break;
                        }
                        auto nmatch = parse!uint(fmt);
                        if (nmatch < m.captures.length)
                            result ~= m.captures[nmatch];
                    break;
                    case '&':
                        result ~= m.hit;
                        fmt.popFront();
                    break;
                    default:
                        result ~= fmt.front;
                        fmt.popFront();
                }
            return result;
        }
        Regex!(Char) r;
        start = 0;
        end = tv.length;

        for (a = start; a < end; a++)
        {
//             writef("width: %d tv[%d]: pattern='%s' input='%s' result=%s"
//                     " format='%s' replace='%s'\n",
//                     Char.sizeof, a,
//                     tv[a].pattern,
//                     tv[a].input,
//                     tv[a].result,
//                     tv[a].format,
//                     tv[a].replace);

            tvd = tv[a];

            c = tvd.result[0];

            try
            {
                i = 1;
                r = regex(to!(String)(tvd.pattern));
            }
            catch (Exception e)
            {
                i = 0;
            }

            //writefln("\tcompile() = %d", i);
            assert((c == 'c') ? !i : i);

            if (c != 'c')
            {
                auto m = match(to!(String)(tvd.input), r);
                i = !m.empty;
                //writefln("\ttest() = %d", i);
                //fflush(stdout);
                assert((c == 'y') ? i : !i, text("Match failed pattern: ", tvd.pattern));
                if (c == 'y')
                {
                    auto result = produceExpected(m, to!(String)(tvd.format));
                    assert(result == to!String(tvd.replace),
                           text("Mismatch pattern: ", tvd.pattern," expected:",
                                tvd.replace, " vs ", result));
                }

            }
        }

        try
        {
            r = regex(to!(String)("a\\.b"), "i");
        }
        catch (Exception e)
        {
            assert(0);
        }
        assert(!match(to!(String)("A.b"), r).empty);
        assert(!match(to!(String)("a.B"), r).empty);
        assert(!match(to!(String)("A.B"), r).empty);
        assert(!match(to!(String)("a.b"), r).empty);
    }
}

template loadFile(Types...)
{
    Tuple!(Types)[] loadFile(Char)(string filename, Regex!(Char) rx)
    {
        auto result = appender!(typeof(return));
        auto f = File(filename);
        scope(exit) f.close;
        RegexMatch!(Char[]) match;
        foreach (line; f.byLine())
        {
            match = .match(line, rx);
            Tuple!(Types) t;
            foreach (i, unused; t.field)
            {
                t[i] = to!(typeof(t[i]))(match.captures[i + 1]);
            }
            result.put(t);
        }
        return result.data;
    }
}

unittest
{
// DAC: This doesn't create the file before running the test!
pragma(msg, " --- std.regex("~ __LINE__.stringof ~") broken test --- ");
/+
    string tmp = "/tmp/deleteme";
    std.file.write(tmp, "1 abc\n2 defg\n3 hijklm");
    auto t = loadFile!(uint, string)(tmp, regex("([0-9])+ +(.+)"));
    //writeln(t);

    assert(t[0] == tuple(1, "abc"));
    assert(t[1] == tuple(2, "defg"));
    assert(t[2] == tuple(3, "hijklm"));
+/
}

unittest
{
    auto str = "foo";
    string[] re_strs = [
        r"^(a|b|)fo[oas]$",
        r"^(a|o|)fo[oas]$",
        r"^(a|)foo$",
        r"^(a|)foo$",
        r"^(h|)foo$",
        r"(h|)foo",
        r"(h|a|)fo[oas]",
        r"^(a|b|)fo[o]$",
        r"[abf][ops](o|oo|)(h|a|)",
        r"(h|)[abf][ops](o|oo|)",
        r"(c|)[abf][ops](o|oo|)"
    ];

    foreach (re_str; re_strs)
    {
        auto re = regex(re_str);
        auto matches= match(str, re);
        assert(!matches.empty);
        // writefln("'%s' matches '%s' ? %s", str, re_str, !matches.empty);
        // if (matches.empty)
        //     re.printProgram();
    }
}

//issue 5857
//matching goes out of control if ... in (...){x} has .*/.+
unittest
{
    auto c = match("axxxzayyyyyzd",regex("(a.*z){2}d")).captures;
    assert(c[0] == "axxxzayyyyyzd");
    assert(c[1] == "ayyyyyz");
    auto c2 = match("axxxayyyyyd",regex("(a.*){2}d")).captures;
    assert(c2[0] == "axxxayyyyyd");
    assert(c2[1] == "ayyyyy");
}

//issue 2108
//greedy vs non-greedy
unittest
{
    auto nogreed = regex("<packet.*?/packet>");
    assert(match("<packet>text</packet><packet>text</packet>", nogreed).hit
           == "<packet>text</packet>");
    auto greed =  regex("<packet.*/packet>");
    assert(match("<packet>text</packet><packet>text</packet>", greed).hit
           == "<packet>text</packet><packet>text</packet>");

}

//issue 4574
//empty successful match still advances the input
unittest
{
    string[] pres, posts, hits;
    foreach(m; match("abcabc", regex(""))) {
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
}

//issue 6076
//regression on .*
unittest
{
    auto re = regex("c.*|d");
    auto m = match("mm", re);
    assert(m.empty);
    auto re2 = regex(`^(.*)\(([0-9]*)\):(.*)$`);
    m = match("file.d(37): huhu", re2);
    assert(!m.empty);
    assert(m.captures[1] == "file.d");
    assert(m.captures[2] == "37");
    assert(m.captures[3] == " huhu");
}

//issue 6261
//regression: doesn't allow mutable patterns 
unittest{ regex("foo".dup); }
