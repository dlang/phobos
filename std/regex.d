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

//debug = regex;                // uncomment to turn on debugging printf's

import core.stdc.stdio;
import core.stdc.stdlib;
import core.stdc.string;
import std.stdio;
import std.string;
import std.ctype;
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
    alias Tuple!(uint, "startIdx", uint, "endIdx") regmatch_t;
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
    ubyte attributes;
    immutable(ubyte)[] program; // pattern[] compiled into regular
                                // expression program

// Opcodes

    enum : ubyte
    {
        REend,          // end of program
            REchar,             // single character
            REichar,            // single character, case insensitive
            REdchar,            // single UCS character
            REidchar,           // single wide character, case insensitive
            REanychar,          // any character
            REanystar,          // ".*"
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
            REnm,               // n..m
            REnmq,              // n..m, non-greedy version
            REbol,              // beginning of line
            REeol,              // end of line
            REparen,            // parenthesized subexpression
            REgoto,             // goto offset

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
    private void initialize(String)(String pattern, string attributes)
    {
        compile(pattern, attributes);
    }

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
        debug(regex) printf("regex.opCall.unittest()\n");
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
        assert(std.algorithm.indexOf(msg, "unrecognized attribute") >= 0);
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
        //printf("Regex.compile('%.*s', '%.*s')\n", pattern, attributes);

        this.attributes = 0;
        foreach (c; attributes)
        {   REA att;

            switch (c)
            {
            case 'g': att = REA.global;         break;
            case 'i': att = REA.ignoreCase;     break;
            case 'm': att = REA.multiline;      break;
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

        uint oldre_nsub = re_nsub;
        re_nsub = 0;

        auto buf = new OutBuffer;
        buf.reserve(pattern.length * 8);
        size_t p = 0;
        parseRegex(pattern, p, buf);
        if (p < pattern.length)
        {       error("unmatched ')'");
        }
        optimize(buf);
        program = cast(immutable(ubyte)[]) buf.data;
        buf.data = null;
        delete buf;
    }

    void error(string msg)
    {
        //errors++;
        debug(regex) printf("error: %.*s\n", msg);
        throw new Exception(msg);
    }

/* ==================== optimizer ======================= */

    void optimize(OutBuffer buf)
    {   ubyte[] prog;

        debug(regex) printf("Regex.optimize()\n");
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
                uint offset = i;
                if (starrchars(r, prog[i .. prog.length]))
                {
                    debug(regex) printf("\tfilter built\n");
                    buf.spread(offset, 1 + 4 + r.maxb);
                    buf.data[offset] = REtestbit;
                    (cast(ushort *)&buf.data[offset + 1])[0] =
                        cast(ushort)r.maxc;
                    (cast(ushort *)&buf.data[offset + 1])[1] =
                        cast(ushort)r.maxb;
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

/* =================== Compiler ================== */

    int parseRegex(String)(in String pattern, ref size_t p, OutBuffer buf)
    {
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
                auto gotooffset = buf.offset;
                buf.write(REgoto);
                buf.write(cast(uint)0);
                immutable len1 = buf.offset - offset;
                buf.spread(offset, 1 + uint.sizeof);
                gotooffset += 1 + uint.sizeof;
                parseRegex(pattern, p, buf);
                immutable len2 = buf.offset - (gotooffset + 1 + uint.sizeof);
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

    int parsePiece(String)(in String pattern, ref size_t p, OutBuffer buf)
    {   uint offset;
        uint len;
        uint n;
        uint m;
        ubyte op;
        int plength = pattern.length;

        //printf("parsePiece() '%.*s'\n", pattern[p .. pattern.length]);
        offset = buf.offset;
        parseAtom(pattern, p, buf);
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

        case '{':       // {n} {n,} {n,m}
            p++;
            if (p == plength || !isdigit(pattern[p]))
                goto Lerr;
            n = 0;
            do
            {
                // BUG: handle overflow
                n = n * 10 + pattern[p] - '0';
                p++;
                if (p == plength)
                    goto Lerr;
            } while (isdigit(pattern[p]));
            if (pattern[p] == '}')              // {n}
            {   m = n;
                goto Lnm;
            }
            if (pattern[p] != ',')
                goto Lerr;
            p++;
            if (p == plength)
                goto Lerr;
            if (pattern[p] == /*{*/ '}')        // {n,}
            {   m = inf;
                goto Lnm;
            }
            if (!isdigit(pattern[p]))
                goto Lerr;
            m = 0;                      // {n,m}
            do
            {
                // BUG: handle overflow
                m = m * 10 + pattern[p] - '0';
                p++;
                if (p == plength)
                    goto Lerr;
            } while (isdigit(pattern[p]));
            if (pattern[p] != /*{*/ '}')
                goto Lerr;
            goto Lnm;

        Lnm:
            p++;
            op = REnm;
            if (p < plength && pattern[p] == '?')
            {   op = REnmq;     // minimal munch version
                p++;
            }
            len = buf.offset - offset;
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

    int parseAtom(String)(in String pattern, ref size_t p, OutBuffer buf)
    {   ubyte op;
        uint offset;
        E c;

        //printf("parseAtom() '%.*s'\n", pattern[p .. pattern.length]);
        if (p >= pattern.length) return 1;
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
            buf.write(cast(uint)0);             // reserve space for length
            buf.write(re_nsub);
            re_nsub++;
            parseRegex(pattern, p, buf);
            *cast(uint *)&buf.data[offset] =
                buf.offset - (offset + uint.sizeof * 2);
            if (p == pattern.length || pattern[p] != ')')
            {
                error("')' expected");
                return 0;
            }
            p++;
            break;

        case '[':
            if (!parseRange(pattern, p, buf))
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
                if (isalpha(c))
                {
                    op = REichar;
                    c = cast(char)std.ctype.toupper(c);
                }
            }
            if (op == REchar && c <= 0xFF)
            {
                // Look ahead and see if we can make this into
                // an REstring
                int q = p;
                int len;

                for (; q < pattern.length; ++q)
                {       auto qc = pattern[q];

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
                    debug(regex) printf("writing string len %d, c = '%c'"
                            ", pattern[p] = '%c'\n", len+1, c, pattern[p]);
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
                // Convert to dchar opcode
                op = (op == REchar) ? REdchar : REidchar;
                buf.write(op);
                buf.write(c);
            }
            else
            {
              Lchar:
                debug(regex) printf("It's an REchar '%c'\n", c);
                buf.write(op);
                buf.write(cast(char)c);
            }
            break;
        }
        return 1;
    }

    class Range
    {
        uint maxc;
        uint maxb;
        OutBuffer buf;
        ubyte* base;
        BitArray bits;

        this(OutBuffer buf)
        {
            this.buf = buf;
            if (buf.data.length)
                this.base = &buf.data[buf.offset];
        }

        void setbitmax(uint u)
        {
            //printf("setbitmax(x%x), maxc = x%x\n", u, maxc);
            if (u <= maxc)
                return;
            maxc = u;
            uint b = u / 8;
            if (b >= maxb)
            {   uint u2;

                u2 = base ? base - &buf.data[0] : 0;
                buf.fill0(b - maxb + 1);
                base = &buf.data[u2];
                maxb = b + 1;
                //bits = (cast(bit*)this.base)[0 .. maxc + 1];
                bits.ptr = cast(uint*)this.base;
            }
            bits.len = maxc + 1;
        }

        void setbit2(uint u)
        {
            setbitmax(u + 1);
            //printf("setbit2 [x%02x] |= x%02x\n", u >> 3, 1 << (u & 7));
            bits[u] = 1;
        }

    }

    int parseRange(String)(in String pattern, ref size_t p, OutBuffer buf)
    {
        int c;
        int c2;
        uint i;
        uint offset;

        uint cmax = 0x7F;
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
        offset = buf.offset;
        buf.write(cast(uint)0);         // reserve space for length
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
        auto rs = RS.start;
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
                        if (isspace(i))
                            r.bits[i] = 1;
                    goto Lrs;

                case 'S':
                    for (i = 1; i <= cmax; i++)
                        if (!isspace(i))
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
                    {   case RS.dash:
                            r.setbit2('-');
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
                {   case RS.rliteral:
                        r.setbit2(c);
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

// OR the leading character bits into r.  Limit the character range
// from 0..7F, trymatch() will allow through anything over maxc.
// Return 1 if success, 0 if we can't build a filter or if there is no
// point to one.

    bool starrchars(Range r, const(ubyte)[] prog)
    {   E c;
        uint maxc;
        uint maxb;
        uint len;
        uint b;
        uint n;
        uint m;
        const(ubyte)* pop;

        //printf("Regex.starrchars(prog = %p, progend = %p)\n", prog, progend);
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
                    r.setbit2(std.ctype.tolower(cast(E) c));
                }
                return 1;

            case REdchar:
            case REidchar:
                return 1;

            case REanychar:
                return 0;               // no point

            case REstring:
                len = *cast(uint *)&prog[i + 1] / E.sizeof;
                assert(len);
                c = *cast(E *)&prog[i + 1 + uint.sizeof];
                debug(regex) printf("\tREstring %d, '%c'\n", len, c);
                if (c <= 0x7F)
                    r.setbit2(c);
                return 1;

            case REistring:
                len = *cast(uint *)&prog[i + 1];
                assert(len && len % E.sizeof == 0);
                len /= E.sizeof;
                c = *cast(E *)&prog[i + 1 + uint.sizeof];
                debug(regex) printf("\tREistring %d, '%c'\n", len, c);
                if (c <= 0x7F)
                {   r.setbit2(std.ctype.toupper(cast(E) c));
                    r.setbit2(std.ctype.tolower(cast(E) c));
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
                return starrchars(r, prog[i + 1 + uint.sizeof
                                .. prog.length]) &&
                    starrchars(r, prog[i + 1 + uint.sizeof + len
                                    .. prog.length]);

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
                    if (isspace(c))
                        r.bits[c] = 1;
                return 1;

            case REnotspace:
                r.setbitmax(0x7F);
                for (c = 0; c <= r.maxc; c++)
                    if (!isspace(c))
                        r.bits[c] = 1;
                return 1;

            case REword:
                r.setbitmax(0x7F);
                for (c = 0; c <= r.maxc; c++)
                    if (isword(cast(E) c))
                        r.bits[c] = 1;
                return 1;

            case REnotword:
                r.setbitmax(0x7F);
                for (c = 0; c <= r.maxc; c++)
                    if (!isword(cast(E) c))
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

    int escape(String)(in String pattern, ref size_t p)
    in
    {
        assert(p < pattern.length);
    }
    body
    {   int c;
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
    private int isword(dchar c) { return isalnum(c) || c == '_'; }

    void printProgram(const(ubyte)[] prog = null)
    {
        if (!prog) prog = program;
        //debug(regex)
        {
            uint len;
            uint n;
            uint m;
            ushort *pu;
            uint *puint;

            printf("printProgram()\n");
            for (uint pc = 0; pc < prog.length; )
            {
                printf("%3d: ", pc);
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
                    len = *cast(uint *)&prog[pc + 1];
                    assert(len %  E.sizeof == 0);
                    len /=  E.sizeof;
                    printf("\tREstring x%x*%d, ", len, E.sizeof);
                    auto es = cast(E*) (&prog[pc + 1 + uint.sizeof]);
                    foreach (e; es[0 .. len])
                    {
                        printf("'%c' ", e);
                    }
                    printf("\n");
                    pc += 1 + uint.sizeof + len * E.sizeof;
                    break;

                case REistring:
                    len = *cast(uint *)&prog[pc + 1];
                    printf("\tREistring x%x, '%.*s'\n", len,
                            (&prog[pc + 1 + uint.sizeof])[0 .. len]);
                    pc += 1 + uint.sizeof + len * E.sizeof;
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
                    printf("\tREor %d, pc=>%d\n", len,
                            pc + 1 + uint.sizeof + len);
                    pc += 1 + uint.sizeof;
                    break;

                case REgoto:
                    len = *cast(uint *)&prog[pc + 1];
                    printf("\tREgoto %d, pc=>%d\n",
                            len, pc + 1 + uint.sizeof + len);
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
                    printf("\tREnm%.*s len=%d, n=%u, m=%u, pc=>%d\n",
                            (prog[pc] == REnmq) ? "q" : " ",
                            len, n, m, pc + 1 + uint.sizeof * 3 + len);
                    pc += 1 + uint.sizeof * 3;
                    break;

                case REparen:
                    // len, n, ()
                    puint = cast(uint *)&prog[pc + 1];
                    len = puint[0];
                    n = puint[1];
                    printf("\tREparen len=%d n=%d, pc=>%d\n",
                            len, n, pc + 1 + uint.sizeof * 2 + len);
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
}

/// Ditto
Regex!(Unqual!(typeof(String.init[0]))) regex(String)
(String pattern, string flags = null)
{
    static Tuple!(String, string) lastReq;
    static typeof(return) lastResult;
    if (lastReq.field[0] == pattern && lastReq.field[1] == flags)
    {
        // cache hit
        return lastResult;
    }

    auto result = typeof(return)(pattern, flags);

    lastReq.field[0] = cast(String) pattern.dup;
    lastReq.field[1] = cast(string) flags.dup;
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

/**
Get or set the engine of the match.
*/
    public Regex engine;
    // the string to search
    Range input;
    size_t src;                     // current source index in input[]
    size_t src_start;           // starting index for match in input[]
    regmatch_t[] pmatch;    // array [engine.re_nsub + 1]

/*
Build a RegexMatch from an engineine and an input.
*/
    private this(Regex engine)
    {
        this.engine = engine;
        pmatch.length = engine.re_nsub + 1;
        pmatch[0].startIdx = 0;
        pmatch[0].endIdx = 0;
    }

/*
Build a RegexMatch from an engine and an input.
*/
    private this(Regex engine, Range input)
    {
        this.engine = engine;
        pmatch.length = engine.re_nsub + 1;
        pmatch[0].startIdx = 0;
        pmatch[0].endIdx = 0;
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
        // debug(regex) printf("regex.search.unittest()\n");

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

        bool empty()
        {
            return matches.empty;
        }

        Range front()
        {
            return input[matches[0].startIdx .. matches[0].endIdx];
        }

        void popFront() {  matches.popFront; }

        @property size_t length()
        {
            foreach (i; 0 .. matches.length)
            {
                if (matches[i].startIdx >= input.length) return i;
            }
            return matches.length;
        }

        Range opIndex(size_t n)
        {
            assert(n < length, text(n));
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
        return Captures(input, pmatch);
    }

    unittest
    {
        // @@@BUG@@@ This doesn't work if a client module uses -unittest
        // Appender!(char[]) app;
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
        return input[0 .. pmatch[0].endIdx > pmatch[0].startIdx
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
        uint lastindex = 0;
        uint offset = 0;
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
                debug(regex)
                         printf("pattern: %.*s, slice: %.*s, format: %.*s"
                         ", replacement: %.*s\n",
                         pattern,result[offset + so .. offset + eo],format,
                         replacement);
                result = std.string.replace(result,slice,replacement);
                break; }
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
        if (startindex == size_t.max) startindex = pmatch[0].endIdx;
        //writeln("matching [", input, "] starting from ", startindex);
        debug (regex) printf("Regex.test(input[] = '%.*s', "
                "startindex = %d)\n", input, startindex);
        if (startindex > input.length)
        {
            pmatch[0].startIdx = pmatch[0].startIdx.max;
            pmatch[0].endIdx = pmatch[0].endIdx.max;
            return 0;                   // fail
        }
        //engine.printProgram(engine.program);
        pmatch[0].startIdx = 0;
        pmatch[0].endIdx = 0;

        // First character optimization
        Unqual!(typeof(Range.init[0])) firstc = 0;
        if (engine.program[0] == engine.REchar)
        {
            firstc = engine.program[1];
            if (engine.attributes & engine.REA.ignoreCase && isalpha(firstc))
                firstc = 0;
        }

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
            foreach (i; 0 .. engine.re_nsub + 1)
            {
                pmatch[i].startIdx = -1;
                pmatch[i].endIdx = -1;
            }
            src_start = src = startindex;
            if (trymatch(0, engine.program.length))
            {
                //writeln("matched [", input, "] from ", si, " to ", src);
                pmatch[0].startIdx = startindex;
                pmatch[0].endIdx = src;
                return true;
            }
            // If possible match must start at beginning, we are done
            if (engine.program[0] == engine.REbol || engine.program[0] == engine.REanystar)
            {
                if (!(engine.attributes & engine.REA.multiline)) break;
                // Scan for the popFront \n
                if (!chr(startindex, '\n'))
                    break;              // no match if '\n' not found
            }
            if (startindex == input.length)
                break;
            //debug(regex) printf("Starting new try: '%.*s'\n",
            //input[si + 1 .. input.length]);
        }
        pmatch[0].startIdx = pmatch[0].startIdx.max;
        pmatch[0].endIdx = pmatch[0].endIdx.max;
        return false;  // no match
    }

    /**
       Returns whether string $(D_PARAM s) matches $(D_PARAM this).
    */
    //alias test opEquals;

    private bool chr(ref uint si, E c)
    {
        for (; si < input.length; si++)
        {
            if (input[si] == c)
                return 1;
        }
        return 0;
    }

    private static int icmp(E[] a, E[] b)
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
                immutable x = std.uni.toUniLower(a[i]),
                    y = std.uni.toUniLower(b[j]);
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

    private bool trymatch(uint pc, uint pcend)
    {
        uint len;
        uint n;
        uint m;
        uint count;
        uint pop;
        uint ss;
        uint c1;
        uint c2;
        ushort* pu;
        uint* puint;

        // printf("Regex.trymatch(pc = %d, src = '%.*s'"
        //         ", pcend = %d)\n", pc, input[src .. input.length], pcend);
        auto srcsave = src;
        regmatch_t *psave = null;
        for (;;)
        {
            if (pc == pcend)            // if done matching
            {   debug(regex) printf("\tprogend\n");
                return true;
            }

            //printf("\top = %d\n", program[pc]);
            switch (engine.program[pc])
            {
            case engine.REchar:
                if (src == input.length)
                    goto Lnomatch;
                debug(regex) printf("\tREchar '%c', src = '%c'\n",
                                    engine.program[pc + 1], input[src]);
                if (engine.program[pc + 1] != input[src])
                    goto Lnomatch;
                src++;
                pc += 1 + char.sizeof;
                break;

            case engine.REichar:

                if (src == input.length)
                    goto Lnomatch;
                debug(regex) printf("\tREichar '%c', src = '%c'\n",
                                    engine.program[pc + 1], input[src]);
                c1 = engine.program[pc + 1];
                c2 = input[src];
                if (c1 != c2)
                {
                    if (islower(cast(E) c2))
                        c2 = std.ctype.toupper(cast(E) c2);
                    else
                        goto Lnomatch;
                    if (c1 != c2)
                        goto Lnomatch;
                }
                src++;
                pc += 1 + char.sizeof;
                break;

            case engine.REdchar:
                if (src == input.length)
                    goto Lnomatch;
                debug(regex) printf("\tREdchar '%c', src = '%c'\n",
                                    *(cast(dchar *)&engine.program[pc + 1]), input[src]);
                if (*(cast(dchar *)&engine.program[pc + 1]) != input[src])
                    goto Lnomatch;
                src++;
                pc += 1 + dchar.sizeof;
                break;

            case engine.REidchar:
                if (src == input.length)
                    goto Lnomatch;
                debug(regex) printf("\tREidchar '%c', src = '%c'\n",
                                    *(cast(dchar *)&engine.program[pc + 1]), input[src]);
                c1 = *(cast(dchar *)&engine.program[pc + 1]);
                c2 = input[src];
                if (c1 != c2)
                {
                    if (islower(cast(E) c2))
                        c2 = std.ctype.toupper(cast(E) c2);
                    else
                        goto Lnomatch;
                    if (c1 != c2)
                        goto Lnomatch;
                }
                src++;
                pc += 1 + dchar.sizeof;
                break;

            case engine.REanychar:
                debug(regex) printf("\tREanychar\n");
                if (src == input.length)
                    goto Lnomatch;
                if (!(engine.attributes & engine.REA.dotmatchlf) && input[src] == '\n')
                    goto Lnomatch;
                src += std.utf.stride(input, src);
                pc++;
                break;

            case engine.REstring:
                len = *cast(uint *)&engine.program[pc + 1];
                assert(len % E.sizeof == 0);
                len /= E.sizeof;
                debug(regex) printf("\tREstring x%x, '%.*s'\n", len,
                                    (&engine.program[pc + 1 + uint.sizeof])[0 .. len]);
                if (src + len > input.length)
                    goto Lnomatch;
                if (memcmp(&engine.program[pc + 1 + uint.sizeof],
                                &input[src], len * E.sizeof))
                    goto Lnomatch;
                src += len;
                pc += 1 + uint.sizeof + len * E.sizeof;
                break;

            case engine.REistring:
                len = *cast(uint *)&engine.program[pc + 1];
                assert(len % E.sizeof == 0);
                len /= E.sizeof;
                debug(regex) printf("\tREistring x%x, '%.*s'\n", len,
                                    (&engine.program[pc + 1 + uint.sizeof])[0 .. len]);
                if (src + len > input.length)
                    goto Lnomatch;
                // version (Win32)
                // {
                //     if (memicmp(cast(E*)&engine.program[pc + 1 + uint.sizeof],
                //                     &input[src], len * E.sizeof))
                //         goto Lnomatch;
                // }
                // else
                {
                    if (icmp(
                       (cast(E*)&engine.program[pc+1+uint.sizeof])[0..len],
                          input[src .. src + len]))
                        goto Lnomatch;
                }
                src += len;
                pc += 1 + uint.sizeof + len * E.sizeof;
                break;

            case engine.REtestbit:
                pu = (cast(ushort *)&engine.program[pc + 1]);
                if (src == input.length)
                    goto Lnomatch;
                debug(regex) printf("\tREtestbit %d, %d, '%c', x%02x\n",
                                    pu[0], pu[1], input[src], input[src]);
                len = pu[1];
                c1 = input[src];
                if (c1 <= pu[0] &&
                   !((&(engine.program[pc + 1 + 4]))[c1 >> 3] & (1 << (c1 & 7))))
                    goto Lnomatch;
                pc += 1 + 2 * ushort.sizeof + len;
                break;

            case engine.REbit:
                if (src == input.length)
                    goto Lnomatch;
                pu = (cast(ushort *)&engine.program[pc + 1]);
                debug(regex) printf("\tREbit %d, %d, '%c'\n",
                                    pu[0], pu[1], input[src]);
                len = pu[1];
                c1 = input[src];
                if (c1 > pu[0])
                    goto Lnomatch;
                if (!((&engine.program[pc + 1 + 4])[c1 >> 3] & (1 << (c1 & 7))))
                    goto Lnomatch;
                src++;
                pc += 1 + 2 * ushort.sizeof + len;
                break;

            case engine.REnotbit:
                if (src == input.length)
                    goto Lnomatch;
                pu = (cast(ushort *)&engine.program[pc + 1]);
                debug(regex) printf("\tREnotbit %d, %d, '%c'\n",
                                    pu[0], pu[1], input[src]);
                len = pu[1];
                c1 = input[src];
                if (c1 <= pu[0] &&
                        ((&engine.program[pc + 1 + 4])[c1 >> 3] & (1 << (c1 & 7))))
                    goto Lnomatch;
                src++;
                pc += 1 + 2 * ushort.sizeof + len;
                break;

            case engine.RErange:
                len = *cast(uint *)&engine.program[pc + 1];
                debug(regex) printf("\tRErange %d\n", len);
                if (src == input.length)
                    goto Lnomatch;
                // BUG: REA.ignoreCase?
                if (memchr(cast(char*)&engine.program[pc + 1 + uint.sizeof],
                                input[src], len) == null)
                    goto Lnomatch;
                src++;
                pc += 1 + uint.sizeof + len;
                break;

            case engine.REnotrange:
                len = *cast(uint *)&engine.program[pc + 1];
                debug(regex) printf("\tREnotrange %d\n", len);
                if (src == input.length)
                    goto Lnomatch;
                // BUG: REA.ignoreCase?
                if (memchr(cast(char*)&engine.program[pc + 1 + uint.sizeof],
                                input[src], len) != null)
                    goto Lnomatch;
                src++;
                pc += 1 + uint.sizeof + len;
                break;

            case engine.REbol:
                debug(regex) printf("\tREbol\n");
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
                debug(regex) printf("\tREeol\n");
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
                len = (cast(uint *)&engine.program[pc + 1])[0];
                debug(regex) printf("\tREor %d\n", len);
                pop = pc + 1 + uint.sizeof;
                ss = src;
                if (trymatch(pop, pcend))
                {
                    if (pcend != engine.program.length)
                    {   int s;

                        s = src;
                        if (trymatch(pcend, engine.program.length))
                        {   debug(regex) printf("\tfirst operand matched\n");
                            src = s;
                            return 1;
                        }
                        else
                        {
                            // If second branch doesn't match to end,
                            // take first anyway
                            src = ss;
                            if (!trymatch(pop + len, engine.program.length))
                            {
                                debug(regex) printf("\tfirst operand"
                                        " matched\n");
                                src = s;
                                return 1;
                            }
                        }
                        src = ss;
                    }
                    else
                    {   debug(regex) printf("\tfirst operand matched\n");
                        return 1;
                    }
                }
                pc = pop + len;         // proceed with 2nd branch
                break;

            case engine.REgoto:
                debug(regex) printf("\tREgoto\n");
                len = (cast(uint *)&engine.program[pc + 1])[0];
                pc += 1 + uint.sizeof + len;
                break;

            case engine.REanystar:
                debug(regex) printf("\tREanystar\n");
                pc++;
                for (;;)
                {
                    auto s1 = src;
                    if (src == input.length)
                        break;
                    if (!(engine.attributes & engine.REA.dotmatchlf)
                            && input[src] == '\n')
                        break;
                    src++;
                    auto s2 = src;

                    // If no match after consumption, but it
                    // did match before, then no match
                    if (!trymatch(pc, engine.program.length))
                    {
                        src = s1;
                        // BUG: should we save/restore pmatch[]?
                        if (trymatch(pc, engine.program.length))
                        {
                            src = s1;           // no match
                            break;
                        }
                    }
                    src = s2;
                }
                break;

            case engine.REnm:
            case engine.REnmq:
                // len, n, m, ()
                puint = cast(uint *)&engine.program[pc + 1];
                len = puint[0];
                n = puint[1];
                m = puint[2];
                debug(regex) printf("\tREnm%s len=%d, n=%u, m=%u\n",
                        (engine.program[pc] == engine.REnmq) ? cast(char*)"q"
                        : cast(char*)"", len, n, m);
                pop = pc + 1 + uint.sizeof * 3;
                for (count = 0; count < n; count++)
                {
                    if (!trymatch(pop, pop + len))
                        goto Lnomatch;
                }
                if (!psave && count < m)
                {
                    psave = cast(regmatch_t *)alloca(
                        (engine.re_nsub + 1) * regmatch_t.sizeof);
                }
                if (engine.program[pc] == engine.REnmq) // if minimal munch
                {
                    for (; count < m; count++)
                    {   int s1;

                        memcpy(psave, pmatch.ptr,
                                (engine.re_nsub + 1) * regmatch_t.sizeof);
                        s1 = src;

                        if (trymatch(pop + len, engine.program.length))
                        {
                            src = s1;
                            memcpy(pmatch.ptr, psave,
                                    (engine.re_nsub + 1) * regmatch_t.sizeof);
                            break;
                        }

                        if (!trymatch(pop, pop + len))
                        {   debug(regex) printf("\tdoesn't match"
                                    " subexpression\n");
                            break;
                        }

                        // If source is not consumed, don't
                        // infinite loop on the match
                        if (s1 == src)
                        {   debug(regex) printf("\tsource is not consumed\n");
                            break;
                        }
                    }
                }
                else    // maximal munch
                {
                    for (; count < m; count++)
                    {
                        memcpy(psave, pmatch.ptr,
                                (engine.re_nsub + 1) * regmatch_t.sizeof);
                        auto s1 = src;
                        if (!trymatch(pop, pop + len))
                        {
                            debug(regex) printf("\tdoesn't match subexpr\n");
                            break;
                        }
                        auto s2 = src;

                        // If source is not consumed, don't
                        // infinite loop on the match
                        if (s1 == s2)
                        {   debug(regex) printf("\tsource is not consumed\n");
                            break;
                        }

                        // If no match after consumption, but it
                        // did match before, then no match
                        if (!trymatch(pop + len, engine.program.length))
                        {
                            src = s1;
                            if (trymatch(pop + len, engine.program.length))
                            {
                                src = s1;               // no match
                                memcpy(pmatch.ptr, psave,
                                        (engine.re_nsub + 1) * regmatch_t.sizeof);
                                break;
                            }
                        }
                        src = s2;
                    }
                }
                debug(regex) printf("\tREnm len=%d, n=%u, m=%u,"
                        " DONE count=%d\n", len, n, m, count);
                pc = pop + len;
                break;

            case engine.REparen:
                // len, ()
                debug(regex) printf("\tREparen\n");
                puint = cast(uint *)&engine.program[pc + 1];
                len = puint[0];
                n = puint[1];
                pop = pc + 1 + uint.sizeof * 2;
                ss = src;
                if (!trymatch(pop, pop + len))
                    goto Lnomatch;
                pmatch[n + 1].startIdx = ss;
                pmatch[n + 1].endIdx = src;
                pc = pop + len;
                break;

            case engine.REend:
                debug(regex) printf("\tREend\n");
                return 1;               // successful match

            case engine.REwordboundary:
                debug(regex) printf("\tREwordboundary\n");
                if (src > 0 && src < input.length)
                {
                    c1 = input[src - 1];
                    c2 = input[src];
                    if (!((engine.isword(cast(E)c1) && !engine.isword(cast(E)c2)) ||
                       (!engine.isword(cast(E)c1) && engine.isword(cast(E)c2))))
                        goto Lnomatch;
                }
                pc++;
                break;

            case engine.REnotwordboundary:
                debug(regex) printf("\tREnotwordboundary\n");
                if (src == 0 || src == input.length)
                    goto Lnomatch;
                c1 = input[src - 1];
                c2 = input[src];
                if (
                    (engine.isword(cast(E)c1) && !engine.isword(cast(E)c2)) ||
                    (!engine.isword(cast(E)c1) && engine.isword(cast(E)c2))
                    )
                    goto Lnomatch;
                pc++;
                break;

            case engine.REdigit:
                debug(regex) printf("\tREdigit\n");
                if (src == input.length)
                    goto Lnomatch;
                if (!isdigit(input[src]))
                    goto Lnomatch;
                src++;
                pc++;
                break;

            case engine.REnotdigit:
                debug(regex) printf("\tREnotdigit\n");
                if (src == input.length)
                    goto Lnomatch;
                if (isdigit(input[src]))
                    goto Lnomatch;
                src++;
                pc++;
                break;

            case engine.REspace:
                debug(regex) printf("\tREspace\n");
                if (src == input.length)
                    goto Lnomatch;
                if (!isspace(input[src]))
                    goto Lnomatch;
                src++;
                pc++;
                break;

            case engine.REnotspace:
                debug(regex) printf("\tREnotspace\n");
                if (src == input.length)
                    goto Lnomatch;
                if (isspace(input[src]))
                    goto Lnomatch;
                src++;
                pc++;
                break;

            case engine.REword:
                debug(regex) printf("\tREword\n");
                if (src == input.length)
                    goto Lnomatch;
                if (!engine.isword(input[src]))
                    goto Lnomatch;
                src++;
                pc++;
                break;

            case engine.REnotword:
                debug(regex) printf("\tREnotword\n");
                if (src == input.length)
                    goto Lnomatch;
                if (engine.isword(input[src]))
                    goto Lnomatch;
                src++;
                pc++;
                break;

            case engine.REbackref:
            {
                n = engine.program[pc + 1];
                debug(regex) printf("\tREbackref %d\n", n);

                auto so = pmatch[n + 1].startIdx;
                auto eo = pmatch[n + 1].endIdx;
                len = eo - so;
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
            }
        }

      Lnomatch:
        debug(regex) printf("\tnomatch pc=%d\n", pc);
        src = srcsave;
        return false;
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
        string result;
        uint c2;
        int startIdx;
        int endIdx;
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
                    {   i = (c - '0') * 10 + (c2 - '0');
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
                {   startIdx = pmatch[i].startIdx;
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

//printf("replace: this = %p so = %d, eo = %d\n", this, pmatch[0].startIdx, pmatch[0].endIdx);
//printf("3input = '%.*s'\n", input);
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
                    {   uint j;

                        j = c - '0';
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
    debug(regex) printf("regex.replace.unittest()\n");
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
    debug(regex) printf("regex.sub.unittest\n");
    assert(replace("hello", regex("ll"), "ss") == "hesso");
    assert(replace("barat", regex("a"), "A") == "bArat");
    assert(replace("barat", regex("a", "g"), "A") == "bArAt");
    auto s = "ark rapacity";
    assert(replace(s, regex("r"), "c") == "ack rapacity");
    assert(replace(s, regex("r", "g"), "c") == "ack capacity");
    assert(replace("noon", regex("^n"), "[$&]") == "[n]oon");
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
    return std.string.toupper(m.hit);
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
    auto lastindex = 0;
    auto offset = 0;
    while (r.test(lastindex))
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
            debug(regex) printf("pattern: %.*s, slice: %.*s"
                    ", replacement: %.*s\n",
                    pattern, result[offset + so .. offset + eo], replacement);
            result = std.string.replace(result, slice, replacement);
            break;
        }
+/
        result = replaceSlice(result, result[offset + so .. offset + eo],
                replacement);

        if (rx.attributes & rx.REA.global)
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
    //debug(regex) printf("regex.sub.unittest\n");
    string foo(RegexMatch!(string) r) { return "ss"; }
    auto r = replace!(foo)("hello", regex("ll"));
    assert(r == "hesso");

    string bar(RegexMatch!(string) r) { return "l"; }
    r = replace!(bar)("hello", regex("l", "g"));
    assert(r == "hello");

    string baz(RegexMatch!(string) m)
    {
        return std.string.toupper(m.hit);
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

    Range front()
    {
        //write("[");scope(success) writeln("]");
        assert(!empty && _offset <= _match.pre.length
                && _match.pre.length <= _input.length);
        return _input[_offset .. min($, _match.pre.length)];
    }

    bool empty()
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
    Appender!(String[]) a;
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
        {  "^", "abc",  "y",    "&",    "" },
        {  "$", "abc",  "y",    "&",    "" },
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
//{  "()*",     "-",    "c",    "-",    "-" },
        {  "()*",       "-",    "y",    "-",    "-" },
        {  "*a",        "-",    "c",    "-",    "-" },
//{  "^*",      "-",    "c",    "-",    "-" },
        {  "^*",        "-",    "y",    "-",    "-" },
//{  "$*",      "-",    "c",    "-",    "-" },
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
//{  "a*?",     "-",    "c",    "-",    "-" },
        {  "a*?a",      "aa",   "y",    "&",    "a" },
//{  "(a*)*",   "-",    "c",    "-",    "-" },
        {  "(a*)*",     "aaa",  "y",    "-",    "-" },
//{  "(a*)+",   "-",    "c",    "-",    "-" },
        {  "(a*)+",     "aaa",  "y",    "-",    "-" },
//{  "(a|)*",   "-",    "c",    "-",    "-" },
        {  "(a|)*",     "-",    "y",    "-",    "-" },
//{  "(a*|b)*", "-",    "c",    "-",    "-" },
        {  "(a*|b)*",   "aabb", "y",    "-",    "-" },
        {  "(a|b)*",    "ab",   "y",    "&-\\1",        "ab-b" },
        {  "(a+|b)*",   "ab",   "y",    "&-\\1",        "ab-b" },
        {  "(a+|b)+",   "ab",   "y",    "&-\\1",        "ab-b" },
        {  "(a+|b)?",   "ab",   "y",    "&-\\1",        "a-a" },
        {  "[^ab]*",    "cde",  "y",    "&",    "cde" },
//{  "(^)*",    "-",    "c",    "-",    "-" },
        {  "(^)*",      "-",    "y",    "-",    "-" },
//{  "(ab|)*",  "-",    "c",    "-",    "-" },
        {  "(ab|)*",    "-",    "y",    "-",    "-" },
        {  ")(",        "-",    "c",    "-",    "-" },
        {  "",  "abc",  "y",    "&",    "" },
        {  "abc",       "",     "n",    "-",    "-" },
        {  "a*",        "",     "y",    "&",    "" },
        {  "([abc])*d", "abbbcd",       "y",    "&-\\1",        "abbbcd-c" },
        {  "([abc])*bcd", "abcd",       "y",    "&-\\1",        "abcd-a" },
        {  "a|b|c|d|e", "e",    "y",    "&",    "e" },
        {  "(a|b|c|d|e)f", "ef",        "y",    "&-\\1",        "ef-e" },
//{  "((a*|b))*", "-",  "c",    "-",    "-" },
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
//{    "((((((((((a))))))))))", "-",    "c",    "-",    "-" },
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

        ];

    int i;
    int a;
    uint c;
    int start;
    int end;
    TestVectors tvd;

    foreach (Char; TypeTuple!(char, wchar, dchar))
    {
        alias immutable(Char)[] String;
        Regex!(Char) r;
        start = 0;
        end = tv.length;

        for (a = start; a < end; a++)
        {
            // printf("width: %d tv[%d]: pattern='%.*s' input='%.*s' result=%.*s"
            //         " format='%.*s' replace='%.*s'\n",
            //         Char.sizeof, a, tv[a].pattern, tv[a].input,
            //         tv[a].result, tv[a].format, tv[a].replace);

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

            //printf("\tcompile() = %d\n", i);
            assert((c == 'c') ? !i : i);

            if (c != 'c')
            {
                i = !match(to!(String)(tvd.input), r).empty;
                //printf("\ttest() = %d\n", i);
                //fflush(stdout);
                assert((c == 'y') ? i : !i);
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
        Appender!(typeof(return)) result;
        auto f = File(filename);
        scope(exit) f.close;
        RegexMatch!(Char[]) match;
        foreach (line; f.byLine())
        {
            match = .match(line, rx);
            Tuple!(Types) t;
            foreach (i, unused; t.field)
            {
                t.field[i] = to!(typeof(t.field[i]))(match.captures[i + 1]);
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
