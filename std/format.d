// Written in the D programming language.

/**
   This module implements the formatting functionality for strings and
   I/O. It's comparable to C99's $(D vsprintf()) and uses a similar
   format encoding scheme.

   Macros: WIKI = Phobos/StdFormat

   Copyright: Copyright Digital Mars 2000-.

   License: $(WEB boost.org/LICENSE_1_0.txt, Boost License 1.0).

   Authors: $(WEB digitalmars.com, Walter Bright), $(WEB erdani.com,
   Andrei Alexandrescu), and Kenji Hara

   Source: $(PHOBOSSRC std/_format.d)
 */
module std.format;

//debug=format;                // uncomment to turn on debugging printf's

import core.stdc.stdio, core.stdc.stdlib, core.stdc.string, core.vararg;
import std.algorithm, std.array, std.ascii, std.bitmanip, std.conv,
    std.exception, std.functional, std.math, std.range,
    std.string, std.system, std.traits, std.typecons, std.typetuple,
    std.utf;
version(unittest) {
    import std.stdio;
    import core.exception;
}

version (Windows) version (DigitalMars)
{
    version = DigitalMarsC;
}

version (DigitalMarsC)
{
    // This is DMC's internal floating point formatting function
    extern (C)
    {
        extern shared char* function(int c, int flags, int precision,
                in real* pdval,
                char* buf, size_t* psl, int width) __pfloatfmt;
    }
    alias core.stdc.stdio._snprintf snprintf;
}
else
{
    // Use C99 snprintf
    extern (C) int snprintf(char* s, size_t n, in char* format, ...);
}

/**********************************************************************
 * Signals a mismatch between a format and its corresponding argument.
 */
class FormatException : Exception
{
    this()
    {
        super("format error");
    }

    this(string msg, string fn = __FILE__, size_t ln = __LINE__, Throwable next = null)
    {
        super(msg, fn, ln, next);
    }
}

/**
$(RED Scheduled for deprecation. Please use $(D FormatException) instead.)
 */
/*deprecated*/ alias FormatException FormatError;

/**********************************************************************
   Interprets variadic argument list $(D args), formats them according
   to $(D fmt), and sends the resulting characters to $(D w). The
   encoding of the output is the same as $(D Char). type $(D Writer)
   must satisfy $(XREF range,isOutputRange!(Writer, Char)).

   The variadic arguments are normally consumed in order. POSIX-style
   $(WEB opengroup.org/onlinepubs/009695399/functions/printf.html,
   positional parameter syntax) is also supported. Each argument is
   formatted into a sequence of chars according to the format
   specification, and the characters are passed to $(D w). As many
   arguments as specified in the format string are consumed and
   formatted. If there are fewer arguments than format specifiers, a
   $(D FormatException) is thrown. If there are more remaining arguments
   than needed by the format specification, they are ignored but only
   if at least one argument was formatted.

   The format string supports the formatting of array and nested array elements
   via the grouping format specifiers $(B %&#40;) and $(B %&#41;). Each
   matching pair of $(B %&#40;) and $(B %&#41;) corresponds with a single array
   argument. The enclosed sub-format string is applied to individual array
   elements.  The trailing portion of the sub-format string following the
   conversion specifier for the array element is interpreted as the array
   delimiter, and is therefore omitted following the last array element. The
   $(B %|) specifier may be used to explicitly indicate the start of the
   delimiter, so that the preceding portion of the string will be included
   following the last array element.  (See below for explicit examples.)

   Params:

   w = Output is sent to this writer. Typical output writers include
   $(XREF array,Appender!string) and $(XREF stdio,LockingTextWriter).

   fmt = Format string.

   args = Variadic argument list.

   Returns: Formatted number of arguments.

   Throws: Mismatched arguments and formats result in a $(D
   FormatException) being thrown.

   Format_String: <a name="format-string">$(I Format strings)</a>
   consist of characters interspersed with $(I format
   specifications). Characters are simply copied to the output (such
   as putc) after any necessary conversion to the corresponding UTF-8
   sequence.

   The format string has the following grammar:

$(PRE
$(I FormatString):
    $(I FormatStringItem)*
$(I FormatStringItem):
    $(B '%%')
    $(B '%') $(I Position) $(I Flags) $(I Width) $(I Precision) $(I FormatChar)
    $(B '%$(LPAREN)') $(I FormatString) $(B '%$(RPAREN)')
    $(I OtherCharacterExceptPercent)
$(I Position):
    $(I empty)
    $(I Integer) $(B '$')
$(I Flags):
    $(I empty)
    $(B '-') $(I Flags)
    $(B '+') $(I Flags)
    $(B '#') $(I Flags)
    $(B '0') $(I Flags)
    $(B ' ') $(I Flags)
$(I Width):
    $(I empty)
    $(I Integer)
    $(B '*')
$(I Precision):
    $(I empty)
    $(B '.')
    $(B '.') $(I Integer)
    $(B '.*')
$(I Integer):
    $(I Digit)
    $(I Digit) $(I Integer)
$(I Digit):
    $(B '0')|$(B '1')|$(B '2')|$(B '3')|$(B '4')|$(B '5')|$(B '6')|$(B '7')|$(B '8')|$(B '9')
$(I FormatChar):
    $(B 's')|$(B 'b')|$(B 'd')|$(B 'o')|$(B 'x')|$(B 'X')|$(B 'e')|$(B 'E')|$(B 'f')|$(B 'F')|$(B 'g')|$(B 'G')|$(B 'a')|$(B 'A')
)

    $(BOOKTABLE Flags affect formatting depending on the specifier as
    follows., $(TR $(TH Flag) $(TH Types&nbsp;affected) $(TH Semantics))

    $(TR $(TD $(B '-')) $(TD numeric) $(TD Left justify the result in
        the field.  It overrides any $(B 0) flag.))

    $(TR $(TD $(B '+')) $(TD numeric) $(TD Prefix positive numbers in
    a signed conversion with a $(B +).  It overrides any $(I space)
    flag.))

    $(TR $(TD $(B '#')) $(TD integral ($(B 'o'))) $(TD Add to
    precision as necessary so that the first digit of the octal
    formatting is a '0', even if both the argument and the $(I
    Precision) are zero.))

    $(TR $(TD $(B '#')) $(TD integral ($(B 'x'), $(B 'X'))) $(TD If
       non-zero, prefix result with $(B 0x) ($(B 0X)).))

    $(TR $(TD $(B '#')) $(TD floating) $(TD Always insert the decimal
       point and print trailing zeros.))

    $(TR $(TD $(B '#')) $(TD numeric ($(B '0'))) $(TD Use leading
    zeros to pad rather than spaces (except for the floating point
    values $(D nan) and $(D infinity)).  Ignore if there's a $(I
    Precision).))

    $(TR $(TD $(B ' ')) $(TD integral ($(B 'd'))) $(TD Prefix positive
    numbers in a signed conversion with a space.)))

    <dt>$(I Width)
    <dd>
    Specifies the minimum field width.
    If the width is a $(B *), the next argument, which must be
    of type $(B int), is taken as the width.
    If the width is negative, it is as if the $(B -) was given
    as a $(I Flags) character.

    <dt>$(I Precision)
    <dd> Gives the precision for numeric conversions.
    If the precision is a $(B *), the next argument, which must be
    of type $(B int), is taken as the precision. If it is negative,
    it is as if there was no $(I Precision).

    <dt>$(I FormatChar)
    <dd>
    <dl>
        <dt>$(B 's')
        <dd>The corresponding argument is formatted in a manner consistent
        with its type:
        <dl>
            <dt>$(B bool)
            <dd>The result is <tt>'true'</tt> or <tt>'false'</tt>.
            <dt>integral types
            <dd>The $(B %d) format is used.
            <dt>floating point types
            <dd>The $(B %g) format is used.
            <dt>string types
            <dd>The result is the string converted to UTF-8.
            A $(I Precision) specifies the maximum number of characters
            to use in the result.
            <dt>classes derived from $(B Object)
            <dd>The result is the string returned from the class instance's
            $(B .toString()) method.
            A $(I Precision) specifies the maximum number of characters
            to use in the result.
            <dt>non-string static and dynamic arrays
            <dd>The result is [s<sub>0</sub>, s<sub>1</sub>, ...]
            where s<sub>k</sub> is the kth element
            formatted with the default format.
        </dl>

        <dt>$(B 'c')
        <dd>The corresponding argument must be a character type.

        <dt>$(B 'b','d','o','x','X')
        <dd> The corresponding argument must be an integral type
        and is formatted as an integer. If the argument is a signed type
        and the $(I FormatChar) is $(B d) it is converted to
        a signed string of characters, otherwise it is treated as
        unsigned. An argument of type $(B bool) is formatted as '1'
        or '0'. The base used is binary for $(B b), octal for $(B o),
        decimal
        for $(B d), and hexadecimal for $(B x) or $(B X).
        $(B x) formats using lower case letters, $(B X) uppercase.
        If there are fewer resulting digits than the $(I Precision),
        leading zeros are used as necessary.
        If the $(I Precision) is 0 and the number is 0, no digits
        result.

        <dt>$(B 'e','E')
        <dd> A floating point number is formatted as one digit before
        the decimal point, $(I Precision) digits after, the $(I FormatChar),
        &plusmn;, followed by at least a two digit exponent: $(I d.dddddd)e$(I &plusmn;dd).
        If there is no $(I Precision), six
        digits are generated after the decimal point.
        If the $(I Precision) is 0, no decimal point is generated.

        <dt>$(B 'f','F')
        <dd> A floating point number is formatted in decimal notation.
        The $(I Precision) specifies the number of digits generated
        after the decimal point. It defaults to six. At least one digit
        is generated before the decimal point. If the $(I Precision)
        is zero, no decimal point is generated.

        <dt>$(B 'g','G')
        <dd> A floating point number is formatted in either $(B e) or
        $(B f) format for $(B g); $(B E) or $(B F) format for
        $(B G).
        The $(B f) format is used if the exponent for an $(B e) format
        is greater than -5 and less than the $(I Precision).
        The $(I Precision) specifies the number of significant
        digits, and defaults to six.
        Trailing zeros are elided after the decimal point, if the fractional
        part is zero then no decimal point is generated.

        <dt>$(B 'a','A')
        <dd> A floating point number is formatted in hexadecimal
        exponential notation 0x$(I h.hhhhhh)p$(I &plusmn;d).
        There is one hexadecimal digit before the decimal point, and as
        many after as specified by the $(I Precision).
        If the $(I Precision) is zero, no decimal point is generated.
        If there is no $(I Precision), as many hexadecimal digits as
        necessary to exactly represent the mantissa are generated.
        The exponent is written in as few digits as possible,
        but at least one, is in decimal, and represents a power of 2 as in
        $(I h.hhhhhh)*2<sup>$(I &plusmn;d)</sup>.
        The exponent for zero is zero.
        The hexadecimal digits, x and p are in upper case if the
        $(I FormatChar) is upper case.
    </dl>

    Floating point NaN's are formatted as $(B nan) if the
    $(I FormatChar) is lower case, or $(B NAN) if upper.
    Floating point infinities are formatted as $(B inf) or
    $(B infinity) if the
    $(I FormatChar) is lower case, or $(B INF) or $(B INFINITY) if upper.
    </dl>

Examples:

-------------------------
import std.c.stdio;
import std.format;

void main()
{
    auto writer = appender!string();
    formattedWrite(writer, "%s is the ultimate %s.", 42, "answer");
    assert(writer.data == "42 is the ultimate answer.");
    // Clear the writer
    writer = appender!string();
    formattedWrite(writer, "Date: %2$s %1$s", "October", 5);
    assert(writer.data == "Date: 5 October");
}
------------------------

The positional and non-positional styles can be mixed in the same
format string. (POSIX leaves this behavior undefined.) The internal
counter for non-positional parameters tracks the next parameter after
the largest positional parameter already used.

Example using array and nested array formatting:
-------------------------
import std.stdio;

void main()
{
    writefln("My items are %(%s %).", [1,2,3]);
    writefln("My items are %(%s, %).", [1,2,3]);
}
-------------------------
   The output is:
<pre class=console>
My items are 1 2 3.
My items are 1, 2, 3.
</pre>

   The trailing end of the sub-format string following the specifier for each
   item is interpreted as the array delimiter, and is therefore omitted
   following the last array item. The $(B %|) delimiter specifier may be used
   to indicate where the delimiter begins, so that the portion of the format
   string prior to it will be retained in the last array element:
-------------------------
import std.stdio;

void main()
{
    writefln("My items are %(-%s-%|, %).", [1,2,3]);
}
-------------------------
   which gives the output:
<pre class=console>
My items are -1-, -2-, -3-.
</pre>

   These compound format specifiers may be nested in the case of a nested
   array argument:
-------------------------
import std.stdio;
void main() {
     auto mat = [[1, 2, 3],
                 [4, 5, 6],
                 [7, 8, 9]];

     writefln("%(%(%d %)\n%)", mat);
     writeln();

     writefln("[%(%(%d %)\n %)]", mat);
     writeln();

     writefln("[%([%(%d %)]%|\n %)]", mat);
     writeln();
}
-------------------------
   The output is:
<pre class=console>
1 2 3
4 5 6
7 8 9

[1 2 3
 4 5 6
 7 8 9]

[[1 2 3]
 [4 5 6]
 [7 8 9]]
</pre>

   Inside a compound format specifier, strings and characters are escaped
   automatically. To avoid this behavior, add $(B '-') flag to
   $(D "%$(LPAREN)").
-------------------------
import std.stdio;

void main()
{
    writefln("My friends are %s.", ["John", "Nancy"]);
    writefln("My friends are %(%s, %).", ["John", "Nancy"]);
    writefln("My friends are %-(%s, %).", ["John", "Nancy"]);
}
-------------------------
   which gives the output:
<pre class=console>
My friends are ["John", "Nancy"].
My friends are "John", "Nancy".
My friends are John, Nancy.
</pre>
 */
uint formattedWrite(Writer, Char, A...)(Writer w, in Char[] fmt, A args)
{
    enum len = args.length;
    void function(Writer, const(void)*, ref FormatSpec!Char) funs[len] = void;
    const(void)* argsAddresses[len] = void;
    if (!__ctfe)
    {
        foreach (i, arg; args)
        {
            funs[i] = &formatGeneric!(Writer, typeof(arg), Char);
            // We can safely cast away shared because all data is either
            // immutable or completely owned by this function.
            argsAddresses[i] = cast(const(void*)) &args[ i ];
        }
    }
    // Are we already done with formats? Then just dump each parameter in turn
    uint currentArg = 0;
    auto spec = FormatSpec!Char(fmt);
    while (spec.writeUpToNextSpec(w))
    {
        if (currentArg == funs.length && !spec.indexStart)
        {
            // leftover spec?
            enforceEx!FormatException(
                    fmt.length == 0,
                    text("Orphan format specifier: %", fmt));
            break;
        }
        if (spec.width == spec.DYNAMIC)
        {
            auto width = to!(typeof(spec.width))(getNthInt(currentArg, args));
            if (width < 0)
            {
                spec.flDash = true;
                width = -width;
            }
            spec.width = width;
            ++currentArg;
        }
        else if (spec.width < 0)
        {
            // means: get width as a positional parameter
            auto index = cast(uint) -spec.width;
            assert(index > 0);
            auto width = to!(typeof(spec.width))(getNthInt(index - 1, args));
            if (currentArg < index) currentArg = index;
            if (width < 0)
            {
                spec.flDash = true;
                width = -width;
            }
            spec.width = width;
        }
        if (spec.precision == spec.DYNAMIC)
        {
            auto precision = to!(typeof(spec.precision))(
                getNthInt(currentArg, args));
            if (precision >= 0) spec.precision = precision;
            // else negative precision is same as no precision
            else spec.precision = spec.UNSPECIFIED;
            ++currentArg;
        }
        else if (spec.precision < 0)
        {
            // means: get precision as a positional parameter
            auto index = cast(uint) -spec.precision;
            assert(index > 0);
            auto precision = to!(typeof(spec.precision))(
                getNthInt(index- 1, args));
            if (currentArg < index) currentArg = index;
            if (precision >= 0) spec.precision = precision;
            // else negative precision is same as no precision
            else spec.precision = spec.UNSPECIFIED;
        }
        // Format!
        if (spec.indexStart > 0)
        {
            // using positional parameters!
            foreach (i; spec.indexStart - 1 .. spec.indexEnd)
            {
                if (funs.length <= i) break;
                if (__ctfe)
                    formatNth(w, spec, i, args);
                else
                    funs[i](w, argsAddresses[i], spec);
            }
            if (currentArg < spec.indexEnd) currentArg = spec.indexEnd;
        }
        else
        {
            if (__ctfe)
                formatNth(w, spec, currentArg, args);
            else
                funs[currentArg](w, argsAddresses[currentArg], spec);
            ++currentArg;
        }
    }
    return currentArg;
}

/**
   Reads characters from input range $(D r), converts them according
   to $(D fmt), and writes them to $(D args).

   Example:
----
string s = "hello!124:34.5";
string a;
int b;
double c;
formattedRead(s, "%s!%s:%s", &a, &b, &c);
assert(a == "hello" && b == 124 && c == 34.5);
----
 */
uint formattedRead(R, Char, S...)(ref R r, const(Char)[] fmt, S args)
{
    auto spec = FormatSpec!Char(fmt);
    static if (!S.length)
    {
        spec.readUpToNextSpec(r);
        enforce(spec.trailing.empty);
        return 0;
    }
    else
    {
        // The function below accounts for '*' == fields meant to be
        // read and skipped
        void skipUnstoredFields()
        {
            for (;;)
            {
                spec.readUpToNextSpec(r);
                if (spec.width != spec.DYNAMIC) break;
                // must skip this field
                skipData(r, spec);
            }
        }

        skipUnstoredFields();
        if (r.empty)
        {
            // Input is empty, nothing to read
            return 0;
        }
        alias typeof(*args[0]) A;
        static if (isTuple!A)
        {
            foreach (i, T; A.Types)
            {
                (*args[0])[i] = unformatValue!(T)(r, spec);
                skipUnstoredFields();
            }
        }
        else
        {
            *args[0] = unformatValue!(A)(r, spec);
        }
        return 1 + formattedRead(r, spec.trailing, args[1 .. $]);
    }
}

unittest
{
    string s = " 1.2 3.4 ";
    double x, y, z;
    assert(formattedRead(s, " %s %s %s ", &x, &y, &z) == 2);
    assert(s.empty);
    assert(x == 1.2);
    assert(y == 3.4);
    assert(isnan(z));
}

template FormatSpec(Char)
    if (!is(Unqual!Char == Char))
{
    alias FormatSpec!(Unqual!Char) FormatSpec;
}

/**
   A General handler for $(D printf) style format specifiers. Used for building more
   specific formatting functions.

   Example:
----
auto a = appender!(string)();
auto fmt = "Number: %2.4e\nString: %s";
auto f = FormatSpec!char(fmt);

f.writeUpToNextSpec(a);

assert(a.data == "Number: ");
assert(f.trailing == "\nString: %s");
assert(f.spec == 'e');
assert(f.width == 2);
assert(f.precision == 4);

f.writeUpToNextSpec(a);

assert(a.data == "Number: \nString: ");
assert(f.trailing == "");
assert(f.spec == 's');
----
 */
struct FormatSpec(Char)
    if (is(Unqual!Char == Char))
{
    /**
       Minimum _width, default $(D 0).
     */
    int width = 0;
    /**
       Precision. Its semantics depends on the argument type. For
       floating point numbers, _precision dictates the number of
       decimals printed.
     */
    int precision = UNSPECIFIED;
    /**
       Special value for width and precision. $(D DYNAMIC) width or
       precision means that they were specified with $(D '*') in the
       format string and are passed at runtime through the varargs.
     */
    enum int DYNAMIC = int.max;
    /**
       Special value for precision, meaning the format specifier
       contained no explicit precision.
     */
    enum int UNSPECIFIED = DYNAMIC - 1;
    /**
       The actual format specifier, $(D 's') by default.
    */
    char spec = 's';
    /**
       Index of the argument for positional parameters, from $(D 1) to
       $(D ubyte.max). ($(D 0) means not used).
    */
    ubyte indexStart;
    /**
       Index of the last argument for positional parameter range, from
       $(D 1) to $(D ubyte.max). ($(D 0) means not used).
    */
    ubyte indexEnd;
    version(StdDdoc) {
        /**
         The format specifier contained a $(D '-') ($(D printf)
         compatibility).
         */
        bool flDash;
        /**
         The format specifier contained a $(D '0') ($(D printf)
         compatibility).
         */
        bool flZero;
        /**
         The format specifier contained a $(D ' ') ($(D printf)
         compatibility).
         */
        bool flSpace;
        /**
         The format specifier contained a $(D '+') ($(D printf)
         compatibility).
         */
        bool flPlus;
        /**
         The format specifier contained a $(D '#') ($(D printf)
         compatibility).
         */
        bool flHash;
        // Fake field to allow compilation
        ubyte allFlags;
    }
    else
    {
        union
        {
            ubyte allFlags;
            mixin(bitfields!(
                        bool, "flDash", 1,
                        bool, "flZero", 1,
                        bool, "flSpace", 1,
                        bool, "flPlus", 1,
                        bool, "flHash", 1,
                        ubyte, "", 3));
        }
    }

    /**
       In case of a compound format specifier starting with $(D
       "%$(LPAREN)") and ending with $(D "%$(RPAREN)"), $(D _nested)
       contains the string contained within the two separators.
     */
    const(Char)[] nested;

    /**
       In case of a compound format specifier, $(D _sep) contains the
       string positioning after $(D "%|").
     */
    const(Char)[] sep;

    /**
       $(D _trailing) contains the rest of the format string.
     */
    const(Char)[] trailing;

    /*
       This string is inserted before each sequence (e.g. array)
       formatted (by default $(D "[")).
     */
    enum immutable(Char)[] seqBefore = "[";

    /*
       This string is inserted after each sequence formatted (by
       default $(D "]")).
     */
    enum immutable(Char)[] seqAfter = "]";

    /*
       This string is inserted after each element keys of a sequence (by
       default $(D ":")).
     */
    enum immutable(Char)[] keySeparator = ":";

    /*
       This string is inserted in between elements of a sequence (by
       default $(D ", ")).
     */
    enum immutable(Char)[] seqSeparator = ", ";

    /**
       Construct a new $(D FormatSpec) using the format string $(D fmt), no
       processing is done until needed.
     */
    this(in Char[] fmt)
    {
        trailing = fmt;
    }

    bool writeUpToNextSpec(OutputRange)(OutputRange writer)
    {
        if (trailing.empty) return false;
        for (size_t i = 0; i < trailing.length; ++i)
        {
            if (trailing[i] != '%') continue;
            if (trailing[++i] != '%')
            {
                // Spec found. Print, fill up the spec, and bailout
                put(writer, trailing[0 .. i - 1]);
                trailing = trailing[i .. $];
                fillUp();
                return true;
            }
            // Doubled! Now print whatever we had, then update the
            // string and move on
            put(writer, trailing[0 .. i - 1]);
            trailing = trailing[i .. $];
            i = 0;
        }
        // no format spec found
        put(writer, trailing);
        trailing = null;
        return false;
    }

    unittest
    {
        auto w = appender!(char[])();
        auto f = FormatSpec("abc%sdef%sghi");
        f.writeUpToNextSpec(w);
        assert(w.data == "abc", w.data);
        assert(f.trailing == "def%sghi", text(f.trailing));
        f.writeUpToNextSpec(w);
        assert(w.data == "abcdef", w.data);
        assert(f.trailing == "ghi");
        // test with embedded %%s
        f = FormatSpec("ab%%cd%%ef%sg%%h%sij");
        w.clear();
        f.writeUpToNextSpec(w);
        assert(w.data == "ab%cd%ef" && f.trailing == "g%%h%sij", w.data);
        f.writeUpToNextSpec(w);
        assert(w.data == "ab%cd%efg%h" && f.trailing == "ij");
        // bug4775
        f = FormatSpec("%%%s");
        w.clear();
        f.writeUpToNextSpec(w);
        assert(w.data == "%" && f.trailing == "");
        f = FormatSpec("%%%%%s%%");
        w.clear();
        while (f.writeUpToNextSpec(w)) continue;
        assert(w.data == "%%%");
    }

    private void fillUp()
    {
        // Reset content
        if (__ctfe)
        {
            flDash = false;
            flZero = false;
            flSpace = false;
            flPlus = false;
            flHash = false;
        }
        else
        {
            allFlags = 0;
        }

        width = 0;
        precision = UNSPECIFIED;
        nested = null;
        // Parse the spec (we assume we're past '%' already)
        for (size_t i = 0; i < trailing.length; )
        {
            switch (trailing[i])
            {
            case '(':
                // Embedded format specifier.
                auto j = i + 1;
                void check(bool condition)
                {
                    enforce(
                        condition,
                        text("Incorrect format specifier: %", trailing[i .. $]));
                }
                // Get the matching balanced paren
                for (uint innerParens;;)
                {
                    check(j < trailing.length);
                    if (trailing[j++] != '%')
                    {
                        // skip, we're waiting for %( and %)
                        continue;
                    }
                    if (trailing[j] == '-') // for %-(
                        ++j;    // skip
                    if (trailing[j] == ')')
                    {
                        if (innerParens-- == 0) break;
                    }
                    else if (trailing[j] == '|')
                    {
                        if (innerParens == 0) break;
                    }
                    else if (trailing[j] == '(')
                    {
                        ++innerParens;
                    }
                }
                if (trailing[j] == '|')
                {
                    auto k = j;
                    for (++j;;)
                    {
                        if (trailing[j++] != '%')
                            continue;
                        if (trailing[j] == '%')
                            ++j;
                        else if (trailing[j] == ')')
                            break;
                        else
                            throw new Exception(
                                text("Incorrect format specifier: %",
                                        trailing[j .. $]));
                    }
                    nested = to!(typeof(nested))(trailing[i + 1 .. k - 1]);
                    sep = to!(typeof(nested))(trailing[k + 1 .. j - 1]);
                }
                else
                {
                    nested = to!(typeof(nested))(trailing[i + 1 .. j - 1]);
                    sep = null;
                }
                //this = FormatSpec(innerTrailingSpec);
                spec = '(';
                // We practically found the format specifier
                trailing = trailing[j + 1 .. $];
                return;
            case '-': flDash = true; ++i; break;
            case '+': flPlus = true; ++i; break;
            case '#': flHash = true; ++i; break;
            case '0': flZero = true; ++i; break;
            case ' ': flSpace = true; ++i; break;
            case '*':
                if (isDigit(trailing[++i]))
                {
                    // a '*' followed by digits and '$' is a
                    // positional format
                    trailing = trailing[1 .. $];
                    width = -.parse!(typeof(width))(trailing);
                    i = 0;
                    enforceEx!FormatException(
                            trailing[i++] == '$',
                            "$ expected");
                }
                else
                {
                    // read result
                    width = DYNAMIC;
                }
                break;
            case '1': .. case '9':
                auto tmp = trailing[i .. $];
                const widthOrArgIndex = .parse!(uint)(tmp);
                enforceEx!FormatException(
                        tmp.length,
                        text("Incorrect format specifier %", trailing[i .. $]));
                i = tmp.ptr - trailing.ptr;
                if (tmp.startsWith('$'))
                {
                    // index of the form %n$
                    indexEnd = indexStart = to!ubyte(widthOrArgIndex);
                    ++i;
                }
                else if (tmp.length && tmp[0] == ':')
                {
                    // two indexes of the form %m:n$, or one index of the form %m:$
                    indexStart = to!ubyte(widthOrArgIndex);
                    tmp = tmp[1 .. $];
                    if (tmp.startsWith('$'))
                    {
                        indexEnd = indexEnd.max;
                    }
                    else
                    {
                        indexEnd = .parse!(typeof(indexEnd))(tmp);
                    }
                    i = tmp.ptr - trailing.ptr;
                    enforceEx!FormatException(
                            trailing[i++] == '$',
                            "$ expected");
                }
                else
                {
                    // width
                    width = to!int(widthOrArgIndex);
                }
                break;
            case '.':
                // Precision
                if (trailing[++i] == '*')
                {
                    if (isDigit(trailing[++i]))
                    {
                        // a '.*' followed by digits and '$' is a
                        // positional precision
                        trailing = trailing[i .. $];
                        i = 0;
                        precision = -.parse!int(trailing);
                        enforceEx!FormatException(
                                trailing[i++] == '$',
                                "$ expected");
                    }
                    else
                    {
                        // read result
                        precision = DYNAMIC;
                    }
                }
                else if (trailing[i] == '-')
                {
                    // negative precision, as good as 0
                    precision = 0;
                    auto tmp = trailing[i .. $];
                    .parse!(int)(tmp); // skip digits
                    i = tmp.ptr - trailing.ptr;
                }
                else if (isDigit(trailing[i]))
                {
                    auto tmp = trailing[i .. $];
                    precision = .parse!int(tmp);
                    i = tmp.ptr - trailing.ptr;
                }
                else
                {
                    // "." was specified, but nothing after it
                    precision = 0;
                }
                break;
            default:
                // this is the format char
                spec = cast(char) trailing[i++];
                trailing = trailing[i .. $];
                return;
            } // end switch
        } // end for
        throw new Exception(text("Incorrect format specifier: ", trailing));
    }

    //--------------------------------------------------------------------------
    private bool readUpToNextSpec(R)(ref R r)
    {
        // Reset content
        if (__ctfe)
        {
            flDash = false;
            flZero = false;
            flSpace = false;
            flPlus = false;
            flHash = false;
        }
        else
        {
            allFlags = 0;
        }
        width = 0;
        precision = UNSPECIFIED;
        nested = null;
        // Parse the spec
        while (trailing.length)
        {
            if (*trailing.ptr == '%')
            {
                if (trailing.length > 1 && trailing.ptr[1] == '%')
                {
                    assert(!r.empty);
                    // Require a '%'
                    if (r.front != '%') break;
                    trailing = trailing[2 .. $];
                    r.popFront();
                }
                else
                {
                    enforce(isLower(trailing[1]) || trailing[1] == '*' ||
                            trailing[1] == '(',
                            text("'%", trailing[1],
                                    "' not supported with formatted read"));
                    trailing = trailing[1 .. $];
                    fillUp();
                    return true;
                }
            }
            else
            {
                if (trailing.ptr[0] == ' ')
                {
                    while (!r.empty && std.ascii.isWhite(r.front)) r.popFront();
                    //r = std.algorithm.find!(not!(std.ascii.isWhite))(r);
                }
                else
                {
                    enforce(!r.empty,
                            text("parseToFormatSpec: Cannot find character `",
                                    trailing.ptr[0], "' in the input string."));
                    if (r.front != trailing.front) break;
                    r.popFront();
                }
                trailing = trailing[std.utf.stride(trailing, 0) .. $];
            }
        }
        return false;
    }

    private const string getCurFmtStr()
    {
        auto w = appender!string();
        auto f = FormatSpec!Char("%s"); // for stringnize

        put(w, '%');
        if (indexStart != 0)
            formatValue(w, indexStart, f), put(w, '$');
        if (flDash)  put(w, '-');
        if (flZero)  put(w, '0');
        if (flSpace) put(w, ' ');
        if (flPlus)  put(w, '+');
        if (flHash)  put(w, '#');
        if (width != 0)
            formatValue(w, width, f);
        if (precision != FormatSpec!Char.UNSPECIFIED)
            put(w, '.'), formatValue(w, precision, f);
        put(w, spec);
        return w.data;
    }

    unittest
    {
        // issue 5237
        auto w = appender!string();
        auto f = FormatSpec!char("%.16f");
        f.writeUpToNextSpec(w); // dummy eating
        assert(f.spec == 'f');
        auto fmt = f.getCurFmtStr();
        assert(fmt == "%.16f");
    }

    private const(Char)[] headUpToNextSpec()
    {
        auto w = appender!(typeof(return))();
        auto tr = trailing;

        while (tr.length)
        {
            if (*tr.ptr == '%')
            {
                if (tr.length > 1 && tr.ptr[1] == '%')
                {
                    tr = tr[2 .. $];
                    w.put('%');
                }
                else
                    break;
            }
            else
            {
                w.put(tr.front);
                tr.popFront();
            }
        }
        return w.data;
    }

    string toString()
    {
        return text("address = ", cast(void*) &this,
                "\nwidth = ", width,
                "\nprecision = ", precision,
                "\nspec = ", spec,
                "\nindexStart = ", indexStart,
                "\nindexEnd = ", indexEnd,
                "\nflDash = ", flDash,
                "\nflZero = ", flZero,
                "\nflSpace = ", flSpace,
                "\nflPlus = ", flPlus,
                "\nflHash = ", flHash,
                "\nnested = ", nested,
                "\ntrailing = ", trailing, "\n");
    }
}
unittest
{
    //Test the example
    auto a = appender!(string)();
    auto fmt = "Number: %2.4e\nString: %s";
    auto f = FormatSpec!char(fmt);

    f.writeUpToNextSpec(a);

    assert(a.data == "Number: ");
    assert(f.trailing == "\nString: %s");
    assert(f.spec == 'e');
    assert(f.width == 2);
    assert(f.precision == 4);

    f.writeUpToNextSpec(a);

    assert(a.data == "Number: \nString: ");
    assert(f.trailing == "");
    assert(f.spec == 's');
}

/**
   Helper function that returns a $(D FormatSpec) for a single specifier given
   in $(D fmt)

   Returns a $(D FormatSpec) with the specifier parsed.

   Enforces giving only one specifier to the function.
  */
FormatSpec!Char singleSpec(Char)(Char[] fmt)
{
    enforce(fmt.length >= 2, new Exception("fmt must be at least 2 characters long"));
    enforce(fmt.front == '%', new Exception("fmt must start with a '%' character"));

    static struct DummyOutputRange {
        void put(C)(C[] buf) {} // eat elements
    }
    auto a = DummyOutputRange();
    auto spec = FormatSpec!Char(fmt);
    //dummy write
    spec.writeUpToNextSpec(a);

    enforce(spec.trailing.empty,
            new Exception(text("Trailing characters in fmt string: '", spec.trailing)));

    return spec;
}
unittest
{
    auto spec = singleSpec("%2.3e");

    assert(spec.trailing == "");
    assert(spec.spec == 'e');
    assert(spec.width == 2);
    assert(spec.precision == 3);

    assertThrown(singleSpec(""));
    assertThrown(singleSpec("2.3e"));
    assertThrown(singleSpec("%2.3eTest"));
}

/**
   $(D bool)s are formatted as "true" or "false" with %s and as "1" or
   "0" with integral-specific format specs.
 */
void formatValue(Writer, T, Char)(Writer w, T obj, ref FormatSpec!Char f)
if (!hasToString!(T, Char) && isBoolean!T)
{
    BooleanTypeOf!T val = obj;

    if (f.spec == 's')
        put(w, val ? "true" : "false");
    else
        formatValue(w, cast(int) val, f);
}

unittest
{
    formatTest( false, "false" );
    formatTest( true,  "true"  );

    class C1 { bool val; alias val this; this(bool v){ val = v; } }
    class C2 { bool val; alias val this; this(bool v){ val = v; }
               override string toString(){ return "C"; } }
    formatTest( new C1(false), "false" );
    formatTest( new C1(true),  "true" );
    formatTest( new C2(false), "C" );
    formatTest( new C2(true),  "C" );

    struct S1 { bool val; alias val this; }
    struct S2 { bool val; alias val this; string toString(){ return "S"; } }
    formatTest( S1(false), "false" );
    formatTest( S1(true),  "true"  );
    formatTest( S2(false), "S" );
    formatTest( S2(true),  "S" );
}

/**
   $(D null) literal is formatted as $(D "null").
 */
void formatValue(Writer, T, Char)(Writer w, T obj, ref FormatSpec!Char f)
if (!hasToString!(T, Char) && is(T == typeof(null)))
{
    enforceEx!FormatException(f.spec == 's', "null");

    put(w, "null");
}

unittest
{
    formatTest( null, "null" );
}

/**
   Integrals are formatted like $(D printf) does.
 */
void formatValue(Writer, T, Char)(Writer w, T obj, ref FormatSpec!Char f)
if (!hasToString!(T, Char) && isIntegral!T)
{
    IntegralTypeOf!T val = obj;

    if (f.spec == 'r')
    {
        // raw write, skip all else and write the thing
        auto begin = cast(const char*) &val;
        if (std.system.endian == Endian.littleEndian && f.flPlus
            || std.system.endian == Endian.bigEndian && f.flDash)
        {
            // must swap bytes
            foreach_reverse (i; 0 .. val.sizeof)
                put(w, begin[i]);
        }
        else
        {
            foreach (i; 0 .. val.sizeof)
                put(w, begin[i]);
        }
        return;
    }

    // Forward on to formatIntegral to handle both T and const(T)
    // Saves duplication of code for both versions.
    static if (isSigned!T)
        formatIntegral(w, cast(long) val, f, Unsigned!(T).max);
    else
        formatIntegral(w, cast(ulong) val, f, T.max);
}

private void formatIntegral(Writer, T, Char)(Writer w, const(T) val, ref FormatSpec!Char f, ulong mask)
{
    FormatSpec!Char fs = f; // fs is copy for change its values.

    T arg = val;

    uint base =
        fs.spec == 'x' || fs.spec == 'X' ? 16 :
        fs.spec == 'o' ? 8 :
        fs.spec == 'b' ? 2 :
        fs.spec == 's' || fs.spec == 'd' || fs.spec == 'u' ? 10 :
        0;
    enforceEx!FormatException(
            base > 0,
            "integral");

    bool negative = (base == 10 && arg < 0);
    if (negative)
    {
        arg = -arg;
    }

    // All unsigned integral types should fit in ulong.
    formatUnsigned(w, (cast(ulong) arg) & mask, fs, base, negative);
}

private void formatUnsigned(Writer, Char)(Writer w, ulong arg, ref FormatSpec!Char fs, uint base, bool negative)
{
    if (fs.precision == fs.UNSPECIFIED)
    {
        // default precision for integrals is 1
        fs.precision = 1;
    }
    else
    {
        // if a precision is specified, the '0' flag is ignored.
        fs.flZero = false;
    }

    char leftPad = void;
    if (!fs.flDash && !fs.flZero)
        leftPad = ' ';
    else if (!fs.flDash && fs.flZero)
        leftPad = '0';
    else
        leftPad = 0;

    // figure out sign and continue in unsigned mode
    char forcedPrefix = void;
    if (fs.flPlus) forcedPrefix = '+';
    else if (fs.flSpace) forcedPrefix = ' ';
    else forcedPrefix = 0;
    if (base != 10)
    {
        // non-10 bases are always unsigned
        forcedPrefix = 0;
    }
    else if (negative)
    {
        // argument is signed
        forcedPrefix = '-';
    }
    // fill the digits
    char[] digits = void;
    {
        char buffer[64]; // 64 bits in base 2 at most
        uint i = buffer.length;
        auto n = arg;
        do
        {
            --i;
            buffer[i] = cast(char) (n % base);
            n /= base;
            if (buffer[i] < 10) buffer[i] += '0';
            else buffer[i] += (fs.spec == 'x' ? 'a' : 'A') - 10;
        } while (n);
        digits = buffer[i .. $]; // got the digits without the sign
    }
    // adjust precision to print a '0' for octal if alternate format is on
    if (base == 8 && fs.flHash
        && (fs.precision <= digits.length)) // too low precision
    {
        //fs.precision = digits.length + (arg != 0);
        forcedPrefix = '0';
    }
    // write left pad; write sign; write 0x or 0X; write digits;
    //   write right pad
    // Writing left pad
    sizediff_t spacesToPrint =
        fs.width // start with the minimum width
        - digits.length  // take away digits to print
        - (forcedPrefix != 0) // take away the sign if any
        - (base == 16 && fs.flHash && arg ? 2 : 0); // 0x or 0X
    const sizediff_t delta = fs.precision - digits.length;
    if (delta > 0) spacesToPrint -= delta;
    if (spacesToPrint > 0) // need to do some padding
    {
        if (leftPad == '0')
        {
            // pad with zeros

            fs.precision =
                cast(typeof(fs.precision)) (spacesToPrint + digits.length);
                //to!(typeof(fs.precision))(spacesToPrint + digits.length);
        }
        else if (leftPad) foreach (i ; 0 .. spacesToPrint) put(w, ' ');
    }
    // write sign
    if (forcedPrefix) put(w, forcedPrefix);
    // write 0x or 0X
    if (base == 16 && fs.flHash && arg) {
        // @@@ overcome bug in dmd;
        //w.write(fs.spec == 'x' ? "0x" : "0X"); //crashes the compiler
        put(w, '0');
        put(w, fs.spec == 'x' ? 'x' : 'X'); // x or X
    }
    // write the digits
    if (arg || fs.precision)
    {
        sizediff_t zerosToPrint = fs.precision - digits.length;
        foreach (i ; 0 .. zerosToPrint) put(w, '0');
        put(w, digits);
    }
    // write the spaces to the right if left-align
    if (!leftPad) foreach (i ; 0 .. spacesToPrint) put(w, ' ');
}

unittest
{
    formatTest( 10, "10" );

    class C1 { long val; alias val this; this(long v){ val = v; } }
    class C2 { long val; alias val this; this(long v){ val = v; }
               override string toString(){ return "C"; } }
    formatTest( new C1(10), "10" );
    formatTest( new C2(10), "C" );

    struct S1 { long val; alias val this; }
    struct S2 { long val; alias val this; string toString(){ return "S"; } }
    formatTest( S1(10), "10" );
    formatTest( S2(10), "S" );
}

/**
 * Floating-point values are formatted like $(D printf) does.
 */
void formatValue(Writer, T, Char)(Writer w, T obj, ref FormatSpec!Char f)
if (!hasToString!(T, Char) && isFloatingPoint!T)
{
    FormatSpec!Char fs = f; // fs is copy for change its values.
    FloatingPointTypeOf!T val = obj;

    if (fs.spec == 'r')
    {
        // raw write, skip all else and write the thing
        auto begin = cast(const char*) &val;
        if (std.system.endian == Endian.littleEndian && f.flPlus
            || std.system.endian == Endian.bigEndian && f.flDash)
        {
            // must swap bytes
            foreach_reverse (i; 0 .. val.sizeof)
                put(w, begin[i]);
        }
        else
        {
            foreach (i; 0 .. val.sizeof)
                put(w, begin[i]);
        }
        return;
    }
    enforceEx!FormatException(
            std.algorithm.find("fgFGaAeEs", fs.spec).length,
            "floating");
    if (fs.spec == 's') fs.spec = 'g';
    char sprintfSpec[1 /*%*/ + 5 /*flags*/ + 3 /*width.prec*/ + 2 /*format*/
                     + 1 /*\0*/] = void;
    sprintfSpec[0] = '%';
    uint i = 1;
    if (fs.flDash) sprintfSpec[i++] = '-';
    if (fs.flPlus) sprintfSpec[i++] = '+';
    if (fs.flZero) sprintfSpec[i++] = '0';
    if (fs.flSpace) sprintfSpec[i++] = ' ';
    if (fs.flHash) sprintfSpec[i++] = '#';
    sprintfSpec[i .. i + 3] = "*.*";
    i += 3;
    if (is(Unqual!(typeof(val)) == real)) sprintfSpec[i++] = 'L';
    sprintfSpec[i++] = fs.spec;
    sprintfSpec[i] = 0;
    //printf("format: '%s'; geeba: %g\n", sprintfSpec.ptr, val);
    char[512] buf;
    immutable n = snprintf(buf.ptr, buf.length,
            sprintfSpec.ptr,
            fs.width,
            // negative precision is same as no precision specified
            fs.precision == fs.UNSPECIFIED ? -1 : fs.precision,
            val);
    enforceEx!FormatException(
            n >= 0,
            "floating point formatting failure");
    put(w, buf[0 .. strlen(buf.ptr)]);
}

unittest
{
    foreach (T; TypeTuple!(float, double, real))
    {
        formatTest( to!(          T)(5.5), "5.5" );
        formatTest( to!(    const T)(5.5), "5.5" );
        formatTest( to!(immutable T)(5.5), "5.5" );
    }
}

unittest
{
    formatTest( 2.25, "2.25" );

    class C1 { double val; alias val this; this(double v){ val = v; } }
    class C2 { double val; alias val this; this(double v){ val = v; }
               override string toString(){ return "C"; } }
    formatTest( new C1(2.25), "2.25" );
    formatTest( new C2(2.25), "C" );

    struct S1 { double val; alias val this; }
    struct S2 { double val; alias val this; string toString(){ return "S"; } }
    formatTest( S1(2.25), "2.25" );
    formatTest( S2(2.25), "S" );
}

/*
   Formatting a $(D creal) is deprecated but still kept around for a while.
 */
void formatValue(Writer, T, Char)(Writer w, T obj, ref FormatSpec!Char f)
if (!hasToString!(T, Char) && is(Unqual!T : creal) && !is(T == enum))
{
    creal val = obj;

    formatValue(w, val.re, f);
    put(w, '+');
    formatValue(w, val.im, f);
    put(w, 'i');
}

unittest
{
    foreach (T; TypeTuple!(cfloat, cdouble, creal))
    {
        formatTest( to!(          T)(1 + 1i), "1+1i" );
        formatTest( to!(    const T)(1 + 1i), "1+1i" );
        formatTest( to!(immutable T)(1 + 1i), "1+1i" );
    }
}

unittest
{
    formatTest( 3+2.25i, "3+2.25i" );

    class C1 { cdouble val; alias val this; this(cdouble v){ val = v; } }
    class C2 { cdouble val; alias val this; this(cdouble v){ val = v; }
               override string toString(){ return "C"; } }
    formatTest( new C1(3+2.25i), "3+2.25i" );
    formatTest( new C2(3+2.25i), "C" );

    struct S1 { cdouble val; alias val this; }
    struct S2 { cdouble val; alias val this; string toString(){ return "S"; } }
    formatTest( S1(3+2.25i), "3+2.25i" );
    formatTest( S2(3+2.25i), "S" );
}

/*
   Formatting an $(D ireal) is deprecated but still kept around for a while.
 */
void formatValue(Writer, T, Char)(Writer w, T obj, ref FormatSpec!Char f)
if (!hasToString!(T, Char) && is(Unqual!T : ireal) && !is(T == enum))
{
    ireal val = obj;

    formatValue(w, val.im, f);
    put(w, 'i');
}

unittest
{
    foreach (T; TypeTuple!(ifloat, idouble, ireal))
    {
        formatTest( to!(          T)(1i), "1i" );
        formatTest( to!(    const T)(1i), "1i" );
        formatTest( to!(immutable T)(1i), "1i" );
    }
}

unittest
{
    formatTest( 2.25i, "2.25i" );

    class C1 { idouble val; alias val this; this(idouble v){ val = v; } }
    class C2 { idouble val; alias val this; this(idouble v){ val = v; }
               override string toString(){ return "C"; } }
    formatTest( new C1(2.25i), "2.25i" );
    formatTest( new C2(2.25i), "C" );

    struct S1 { idouble val; alias val this; }
    struct S2 { idouble val; alias val this; string toString(){ return "S"; } }
    formatTest( S1(2.25i), "2.25i" );
    formatTest( S2(2.25i), "S" );
}

/**
   Individual characters ($(D char), $(D wchar), or $(D dchar)) are
   formatted as Unicode characters with %s and as integers with
   integral-specific format specs.
 */
void formatValue(Writer, T, Char)(Writer w, T obj, ref FormatSpec!Char f)
if (!hasToString!(T, Char) && isSomeChar!T)
{
    CharTypeOf!T val = obj;

    if (f.spec == 's' || f.spec == 'c')
    {
        put(w, val);
    }
    else
    {
        formatValue(w, cast(uint) val, f);
    }
}

unittest
{
    formatTest( 'c', "c" );

    class C1 { char val; alias val this; this(char v){ val = v; } }
    class C2 { char val; alias val this; this(char v){ val = v; }
               override string toString(){ return "C"; } }
    formatTest( new C1('c'), "c" );
    formatTest( new C2('c'), "C" );

    struct S1 { char val; alias val this; }
    struct S2 { char val; alias val this; string toString(){ return "S"; } }
    formatTest( S1('c'), "c" );
    formatTest( S2('c'), "S" );
}

/**
   Strings are formatted like $(D printf) does.
 */
void formatValue(Writer, T, Char)(Writer w, T obj, ref FormatSpec!Char f)
if (!hasToString!(T, Char) && isSomeString!T && !isStaticArray!T)
{
    Unqual!(StringTypeOf!T) val = obj;  // for `alias this`, see bug5371
    formatRange(w, val, f);
}

unittest
{
    formatTest( "abc", "abc" );
}

unittest
{
    // Test for bug 5371 for classes
    class C1 { const string var; alias var this; this(string s){ var = s; } }
    class C2 {       string var; alias var this; this(string s){ var = s; } }
    formatTest( new C1("c1"), "c1" );
    formatTest( new C2("c2"), "c2" );

    // Test for bug 5371 for structs
    struct S1 { const string var; alias var this; }
    struct S2 {       string var; alias var this; }
    formatTest( S1("s1"), "s1" );
    formatTest( S2("s2"), "s2" );
}

unittest
{
    class  C3 { string val; alias val this; this(string s){ val = s; }
                override string toString(){ return "C"; } }
    formatTest( new C3("c3"), "C" );

    struct S3 { string val; alias val this; string toString(){ return "S"; } }
    formatTest( S3("s3"), "S" );
}

/**
   Static-size arrays are formatted as dynamic arrays.
 */
void formatValue(Writer, T, Char)(Writer w, auto ref T obj, ref FormatSpec!Char f)
if (!hasToString!(T, Char) && isStaticArray!T)
{
    formatValue(w, obj[], f);
}

unittest    // Test for issue 8310
{
    FormatSpec!char f;
    auto w = appender!string();

    char[2] two = ['a', 'b'];
    formatValue(w, two, f);

    char[2] getTwo(){ return two; }
    formatValue(w, getTwo(), f);
}

/**
   Dynamic arrays are formatted as input ranges.

   Specializations:
     $(UL $(LI $(D void[]) is formatted like $(D ubyte[]).)
          $(LI Const array is converted to input range by removing its qualifier.))
 */
void formatValue(Writer, T, Char)(Writer w, T obj, ref FormatSpec!Char f)
if (!hasToString!(T, Char) && !isSomeString!T && isDynamicArray!T)
{
    static if (is(const(ArrayTypeOf!T) == const(void[])))
    {
        formatValue(w, cast(const ubyte[])obj, f);
    }
    else static if (!isInputRange!T)
    {
        alias Unqual!(ArrayTypeOf!T) U;
        static assert(isInputRange!U);
        U val = obj;
        formatValue(w, val, f);
    }
    else
    {
        formatRange(w, obj, f);
    }
}

// alias this, input range I/F, and toString()
unittest
{
    struct S(uint flags)
    {
        int[] arr;
      static if (flags & 1)
        alias arr this;

      static if (flags & 2)
      {
        @property bool empty() const { return arr.length == 0; }
        @property int front() const { return arr[0] * 2; }
        void popFront() { arr = arr[1..$]; }
      }

      static if (flags & 4)
        string toString(){ return "S"; }
    }
    formatTest(S!0b000([0, 1, 2]), "S!(0)([0, 1, 2])");
    formatTest(S!0b001([0, 1, 2]), "[0, 1, 2]");        // Test for bug 7628
    formatTest(S!0b010([0, 1, 2]), "[0, 2, 4]");
    formatTest(S!0b011([0, 1, 2]), "[0, 2, 4]");
    formatTest(S!0b100([0, 1, 2]), "S");
    formatTest(S!0b101([0, 1, 2]), "S");                // Test for bug 7628
    formatTest(S!0b110([0, 1, 2]), "S");
    formatTest(S!0b111([0, 1, 2]), "S");

    class C(uint flags)
    {
        int[] arr;
      static if (flags & 1)
        alias arr this;

        this(int[] a) { arr = a; }

      static if (flags & 2)
      {
        @property bool empty() const { return arr.length == 0; }
        @property int front() const { return arr[0] * 2; }
        void popFront() { arr = arr[1..$]; }
      }

      static if (flags & 4)
        override string toString(){ return "C"; }
    }
    formatTest(new C!0b000([0, 1, 2]), (new C!0b000([])).toString());
    formatTest(new C!0b001([0, 1, 2]), "[0, 1, 2]");    // Test for bug 7628
    formatTest(new C!0b010([0, 1, 2]), "[0, 2, 4]");
    formatTest(new C!0b011([0, 1, 2]), "[0, 2, 4]");
    formatTest(new C!0b100([0, 1, 2]), "C");
    formatTest(new C!0b101([0, 1, 2]), "C");            // Test for bug 7628
    formatTest(new C!0b110([0, 1, 2]), "C");
    formatTest(new C!0b111([0, 1, 2]), "C");
}

unittest
{
    // void[]
    void[] val0;
    formatTest( val0, "[]" );

    void[] val = cast(void[])cast(ubyte[])[1, 2, 3];
    formatTest( val, "[1, 2, 3]" );

    void[0] sval0 = [];
    formatTest( sval0, "[]");

    void[3] sval = cast(void[3])cast(ubyte[3])[1, 2, 3];
    formatTest( sval, "[1, 2, 3]" );
}

unittest
{
    // const(T[]) -> const(T)[]
    const short[] a = [1, 2, 3];
    formatTest( a, "[1, 2, 3]" );

    struct S { const(int[]) arr; alias arr this; }
    auto s = S([1,2,3]);
    formatTest( s, "[1, 2, 3]" );
}

unittest
{
    // 6640
    struct Range
    {
        string value;
        const @property bool empty(){ return !value.length; }
        const @property dchar front(){ return value.front(); }
        void popFront(){ value.popFront(); }

        const @property size_t length(){ return value.length; }
    }
    immutable table =
    [
        ["[%s]", "[string]"],
        ["[%10s]", "[    string]"],
        ["[%-10s]", "[string    ]"],
        ["[%(%02x %)]", "[73 74 72 69 6e 67]"],
        ["[%(%c %)]", "[s t r i n g]"],
    ];
    foreach (e; table)
    {
        formatTest(e[0], "string", e[1]);
        formatTest(e[0], Range("string"), e[1]);
    }
}

unittest
{
    // string literal from valid UTF sequence is encoding free.
    foreach (StrType; TypeTuple!(string, wstring, dstring))
    {
        // Valid and printable (ASCII)
        formatTest( [cast(StrType)"hello"],
                    `["hello"]` );

        // 1 character escape sequences (' is not escaped in strings)
        formatTest( [cast(StrType)"\"'\\\a\b\f\n\r\t\v"],
                    `["\"'\\\a\b\f\n\r\t\v"]` );

        // Valid and non-printable code point (<= U+FF)
        formatTest( [cast(StrType)"\x00\x10\x1F\x20test"],
                    `["\x00\x10\x1F test"]` );

        // Valid and non-printable code point (<= U+FFFF)
        formatTest( [cast(StrType)"\u200B..\u200F"],
                    `["\u200B..\u200F"]` );

        // Valid and non-printable code point (<= U+10FFFF)
        formatTest( [cast(StrType)"\U000E0020..\U000E007F"],
                    `["\U000E0020..\U000E007F"]` );
    }

    // invalid UTF sequence needs hex-string literal postfix (c/w/d)
    {
        // U+FFFF with UTF-8 (Invalid code point for interchange)
        formatTest( [cast(string)[0xEF, 0xBF, 0xBF]],
                    `[x"EF BF BF"c]` );

        // U+FFFF with UTF-16 (Invalid code point for interchange)
        formatTest( [cast(wstring)[0xFFFF]],
                    `[x"FFFF"w]` );

        // U+FFFF with UTF-32 (Invalid code point for interchange)
        formatTest( [cast(dstring)[0xFFFF]],
                    `[x"FFFF"d]` );
    }
}

unittest
{
    // nested range formatting with array of string
    formatTest( "%({%(%02x %)}%| %)", ["test", "msg"],
                `{74 65 73 74} {6d 73 67}` );
}

unittest
{
    // stop auto escaping inside range formatting
    auto arr = ["hello", "world"];
    formatTest( "%(%s, %)",  arr, `"hello", "world"` );
    formatTest( "%-(%s, %)", arr, `hello, world` );

    auto aa1 = [1:"hello", 2:"world"];
    formatTest( "%(%s:%s, %)",  aa1, `1:"hello", 2:"world"` );
    formatTest( "%-(%s:%s, %)", aa1, `1:hello, 2:world` );

    auto aa2 = [1:["ab", "cd"], 2:["ef", "gh"]];
    formatTest( "%-(%s:%s, %)",        aa2, `1:["ab", "cd"], 2:["ef", "gh"]` );
    formatTest( "%-(%s:%(%s%), %)",    aa2, `1:"ab""cd", 2:"ef""gh"` );
    formatTest( "%-(%s:%-(%s%)%|, %)", aa2, `1:abcd, 2:efgh` );
}

// input range formatting
private void formatRange(Writer, T, Char)(ref Writer w, ref T val, ref FormatSpec!Char f)
if (isInputRange!T)
{
    // Formatting character ranges like string
    static if (isSomeChar!(ElementType!T))
    if (f.spec == 's')
    {
        static if (isSomeString!T)
        {
            auto s = val[0 .. f.precision < $ ? f.precision : $];
            if (!f.flDash)
            {
                // right align
                if (f.width > s.length)
                    foreach (i ; 0 .. f.width - s.length) put(w, ' ');
                put(w, s);
            }
            else
            {
                // left align
                put(w, s);
                if (f.width > s.length)
                    foreach (i ; 0 .. f.width - s.length) put(w, ' ');
            }
        }
        else
        {
            if (!f.flDash)
            {
                static if (hasLength!T)
                {
                    // right align
                    auto len = val.length;
                }
                else static if (isForwardRange!T)
                {
                    auto len = walkLength(val.save);
                }
                else
                {
                    enforce(f.width == 0, "Cannot right-align a range without length");
                    size_t len = 0;
                }
                if (f.precision != f.UNSPECIFIED && len > f.precision)
                    len = f.precision;

                if (f.width > len)
                    foreach (i ; 0 .. f.width - len)
                        put(w, ' ');
                if (f.precision == f.UNSPECIFIED)
                    put(w, val);
                else
                {
                    size_t printed = 0;
                    for (; !val.empty && printed < f.precision; val.popFront(), ++printed)
                        put(w, val.front);
                }
            }
            else
            {
                size_t printed = void;

                // left align
                if (f.precision == f.UNSPECIFIED)
                {
                    static if (hasLength!T)
                    {
                        printed = val.length;
                        put(w, val);
                    }
                    else
                    {
                        printed = 0;
                        for (; !val.empty; val.popFront(), ++printed)
                            put(w, val.front);
                    }
                }
                else
                {
                    printed = 0;
                    for (; !val.empty && printed < f.precision; val.popFront(), ++printed)
                        put(w, val.front);
                }

                if (f.width > printed)
                    foreach (i ; 0 .. f.width - printed)
                        put(w, ' ');
            }
        }
        return;
    }

    if (f.spec == 'r')
    {
        // raw writes
        for (size_t i; !val.empty; val.popFront(), ++i)
        {
            formatValue(w, val.front, f);
        }
    }
    else if (f.spec == 's')
    {
        put(w, f.seqBefore);
        if (!val.empty)
        {
            formatElement(w, val.front, f);
            val.popFront();
            for (size_t i; !val.empty; val.popFront(), ++i)
            {
                put(w, f.seqSeparator);
                formatElement(w, val.front, f);
            }
        }
        static if (!isInfinite!T) put(w, f.seqAfter);
    }
    else if (f.spec == '(')
    {
        if (val.empty)
            return;
        // Nested specifier is to be used
        for (;;)
        {
            auto fmt = FormatSpec!Char(f.nested);
            fmt.writeUpToNextSpec(w);
            if (f.flDash)
                formatValue(w, val.front, fmt);
            else
                formatElement(w, val.front, fmt);
            if (f.sep)
            {
                put(w, fmt.trailing);
                val.popFront();
                if (val.empty)
                    break;
                put(w, f.sep);
            }
            else
            {
                val.popFront();
                if (val.empty)
                    break;
                put(w, fmt.trailing);
            }
        }
    }
    else
        throw new Exception(text("Incorrect format specifier for range: %", f.spec));
}

// character formatting with ecaping
private void formatChar(Writer)(Writer w, in dchar c, in char quote)
{
    if (std.uni.isGraphical(c))
    {
        if (c == quote || c == '\\')
            put(w, '\\'), put(w, c);
        else
            put(w, c);
    }
    else if (c <= 0xFF)
    {
        put(w, '\\');
        switch (c)
        {
        case '\a':  put(w, 'a');  break;
        case '\b':  put(w, 'b');  break;
        case '\f':  put(w, 'f');  break;
        case '\n':  put(w, 'n');  break;
        case '\r':  put(w, 'r');  break;
        case '\t':  put(w, 't');  break;
        case '\v':  put(w, 'v');  break;
        default:
            formattedWrite(w, "x%02X", cast(uint)c);
        }
    }
    else if (c <= 0xFFFF)
        formattedWrite(w, "\\u%04X", cast(uint)c);
    else
        formattedWrite(w, "\\U%08X", cast(uint)c);
}

// undocumented
// string elements are formatted like UTF-8 string literals.
void formatElement(Writer, T, Char)(Writer w, T val, ref FormatSpec!Char f)
if (isSomeString!T)
{
    StringTypeOf!T str = val;   // bug 8015

    if (f.spec == 's')
    {
        try
        {
            // ignore other specifications and quote
            auto app = appender!(typeof(T[0])[])();
            put(app, '\"');
            for (size_t i = 0; i < str.length; )
            {
                auto c = std.utf.decode(str, i);
                // \uFFFE and \uFFFF are considered valid by isValidDchar,
                // so need checking for interchange.
                if (c == 0xFFFE || c == 0xFFFF)
                    goto LinvalidSeq;
                formatChar(app, c, '"');
            }
            put(app, '\"');
            put(w, app.data());
            return;
        }
        catch (UTFException)
        {
        }

        // If val contains invalid UTF sequence, formatted like HexString literal
    LinvalidSeq:
        static if (is(typeof(str[0]) : const(char)))
        {
            enum postfix = 'c';
            alias const(ubyte)[] IntArr;
        }
        else static if (is(typeof(str[0]) : const(wchar)))
        {
            enum postfix = 'w';
            alias const(ushort)[] IntArr;
        }
        else static if (is(typeof(str[0]) : const(dchar)))
        {
            enum postfix = 'd';
            alias const(uint)[] IntArr;
        }
        formattedWrite(w, "x\"%(%02X %)\"%s", cast(IntArr)str, postfix);
    }
    else
        formatValue(w, str, f);
}

unittest
{
    // Test for bug 8015
    import std.typecons;

    struct MyStruct {
        string str;
        @property string toStr() {
            return str;
        }
        alias toStr this;
    }

    Tuple!(MyStruct) t;
}

// undocumented
// character elements are formatted like UTF-8 character literals.
void formatElement(Writer, T, Char)(Writer w, T val, ref FormatSpec!Char f)
if (isSomeChar!T)
{
    if (f.spec == 's')
    {
        put(w, '\'');
        formatChar(w, val, '\'');
        put(w, '\'');
    }
    else
        formatValue(w, val, f);
}

// undocumented
// Maybe T is noncopyable struct, so receive it by 'auto ref'.
void formatElement(Writer, T, Char)(Writer w, auto ref T val, ref FormatSpec!Char f)
if (!isSomeString!T && !isSomeChar!T)
{
    formatValue(w, val, f);
}

/**
   Associative arrays are formatted by using $(D ':') and $(D ', ') as
   separators, and enclosed by $(D '[') and $(D ']').
 */
void formatValue(Writer, T, Char)(Writer w, T obj, ref FormatSpec!Char f)
if (!hasToString!(T, Char) && isAssociativeArray!T)
{
    AssocArrayTypeOf!T val = obj;

    enforceEx!FormatException(
            f.spec == 's' || f.spec == '(',
            "associative");

    enum const(Char)[] defSpec = "%s" ~ f.keySeparator ~ "%s" ~ f.seqSeparator;
    auto fmtSpec = f.spec == '(' ? f.nested : defSpec;

    size_t i = 0, end = val.length;

    if (f.spec == 's')
        put(w, f.seqBefore);
    foreach (k, ref v; val)
    {
        auto fmt = FormatSpec!Char(fmtSpec);
        fmt.writeUpToNextSpec(w);
        if (f.flDash)
        {
            formatValue(w, k, fmt);
            fmt.writeUpToNextSpec(w);
            formatValue(w, v, fmt);
        }
        else
        {
            formatElement(w, k, fmt);
            fmt.writeUpToNextSpec(w);
            formatElement(w, v, fmt);
        }
        if (f.sep)
        {
            fmt.writeUpToNextSpec(w);
            if (++i != end)
                put(w, f.sep);
        }
        else
        {
            if (++i != end)
                fmt.writeUpToNextSpec(w);
        }
    }
    if (f.spec == 's')
        put(w, f.seqAfter);
}

unittest
{
    int[string] aa0;
    formatTest( aa0, `[]` );

    // elements escaping
    formatTest(  ["aaa":1, "bbb":2, "ccc":3],
                `["aaa":1, "bbb":2, "ccc":3]` );
    formatTest(  ['c':"str"],
                `['c':"str"]` );
    formatTest(  ['"':"\"", '\'':"'"],
                `['"':"\"", '\'':"'"]` );

    // range formatting for AA
    auto aa3 = [1:"hello", 2:"world"];
    // escape
    formatTest( "{%(%s:%s $ %)}", aa3,
                `{1:"hello" $ 2:"world"}`);
    // use range formatting for key and value, and use %|
    formatTest( "{%([%04d->%(%c.%)]%| $ %)}", aa3,
                `{[0001->h.e.l.l.o] $ [0002->w.o.r.l.d]}` );
}

unittest
{
    class C1 { int[char] val; alias val this; this(int[char] v){ val = v; } }
    class C2 { int[char] val; alias val this; this(int[char] v){ val = v; }
               override string toString(){ return "C"; } }
    formatTest( new C1(['c':1, 'd':2]), `['c':1, 'd':2]` );
    formatTest( new C2(['c':1, 'd':2]), "C" );

    struct S1 { int[char] val; alias val this; }
    struct S2 { int[char] val; alias val this; string toString(){ return "S"; } }
    formatTest( S1(['c':1, 'd':2]), `['c':1, 'd':2]` );
    formatTest( S2(['c':1, 'd':2]), "S" );
}


template hasToString(T, Char)
{
    static if(isPointer!T && !isAggregateType!T)
    {
        // X* does not have toString, even if X is aggregate type has toString.
        enum hasToString = 0;
    }
    else static if (is(typeof({ T val; FormatSpec!Char f; val.toString((const(char)[] s){}, f); })))
    {
        enum hasToString = 4;
    }
    else static if (is(typeof({ T val; val.toString((const(char)[] s){}, "%s"); })))
    {
        enum hasToString = 3;
    }
    else static if (is(typeof({ T val; val.toString((const(char)[] s){}); })))
    {
        enum hasToString = 2;
    }
    else static if (is(typeof({ T val; return val.toString(); }()) S) && isSomeString!S)
    {
        enum hasToString = 1;
    }
    else
    {
        enum hasToString = 0;
    }
}

// object formatting with toString
private void formatObject(Writer, T, Char)(ref Writer w, ref T val, ref FormatSpec!Char f)
if (hasToString!(T, Char))
{
    static if (is(typeof(val.toString((const(char)[] s){}, f))))
    {
        val.toString((const(char)[] s) { put(w, s); }, f);
    }
    else static if (is(typeof(val.toString((const(char)[] s){}, "%s"))))
    {
        val.toString((const(char)[] s) { put(w, s); }, f.getCurFmtStr());
    }
    else static if (is(typeof(val.toString((const(char)[] s){}))))
    {
        val.toString((const(char)[] s) { put(w, s); });
    }
    else static if (is(typeof(val.toString()) S) && isSomeString!S)
    {
        put(w, val.toString());
    }
    else
        static assert(0);
}

/**
   Aggregates ($(D struct), $(D union), $(D class), and $(D interface)) are
   basically formatted by calling $(D toString).
   $(D toString) should have one of the following signatures:

---
const void toString(scope void delegate(const(char)[]) sink, FormatSpec fmt);
const void toString(scope void delegate(const(char)[]) sink, string fmt);
const void toString(scope void delegate(const(char)[]) sink);
const string toString();
---

   For the class objects which have input range interface,
   $(UL $(LI If the instance $(D toString) has overridden
             $(D Object.toString), it is used.)
        $(LI Otherwise, the objects are formatted as input range.))

   For the struct and union objects which does not have $(D toString),
   $(UL $(LI If they have range interface, formatted as input range.)
        $(LI Otherwise, they are formatted like $(D Type(field1, filed2, ...)).))

   Otherwise, are formatted just as their type name.
 */
void formatValue(Writer, T, Char)(Writer w, T val, ref FormatSpec!Char f)
if (is(T == class) && !is(T == enum))
{
    // TODO: Change this once toString() works for shared objects.
    static assert(!is(T == shared), "unable to format shared objects");

    if (val is null)
        put(w, "null");
    else
    {
        static if (hasToString!(T, Char) > 1 || (!isInputRange!T && !isBuiltinType!T))
        {
            formatObject!(Writer, T, Char)(w, val, f);
        }
        else
        {
          //string delegate() dg = &val.toString;
            Object o = val;     // workaround
            string delegate() dg = &o.toString;
            if (dg.funcptr != &Object.toString) // toString is overridden
            {
                formatObject(w, val, f);
            }
            else static if (isInputRange!T)
            {
                formatRange(w, val, f);
            }
            else static if (is(BuiltinTypeOf!T X))
            {
                X x = val;
                formatValue(w, x, f);
            }
            else
            {
                formatObject(w, val, f);
            }
        }
    }
}

unittest
{
    // class range (issue 5154)
    auto c = inputRangeObject([1,2,3,4]);
    formatTest( c, "[1, 2, 3, 4]" );
    assert(c.empty);
    c = null;
    formatTest( c, "null" );
}

unittest
{
    // 5354
    // If the class has both range I/F and custom toString, the use of custom
    // toString routine is prioritized.

    // Enable the use of custom toString that gets a sink delegate
    // for class formatting.

    enum inputRangeCode =
    q{
        int[] arr;
        this(int[] a){ arr = a; }
        @property int front() const { return arr[0]; }
        @property bool empty() const { return arr.length == 0; }
        void popFront(){ arr = arr[1..$]; }
    };

    class C1
    {
        mixin(inputRangeCode);
        void toString(scope void delegate(const(char)[]) dg, ref FormatSpec!char f) const { dg("[012]"); }
    }
    class C2
    {
        mixin(inputRangeCode);
        void toString(scope void delegate(const(char)[]) dg, string f) const { dg("[012]"); }
    }
    class C3
    {
        mixin(inputRangeCode);
        void toString(scope void delegate(const(char)[]) dg) const { dg("[012]"); }
    }
    class C4
    {
        mixin(inputRangeCode);
        override string toString() { return "[012]"; }
    }
    class C5
    {
        mixin(inputRangeCode);
    }

    formatTest( new C1([0, 1, 2]), "[012]" );
    formatTest( new C2([0, 1, 2]), "[012]" );
    formatTest( new C3([0, 1, 2]), "[012]" );
    formatTest( new C4([0, 1, 2]), "[012]" );
    formatTest( new C5([0, 1, 2]), "[0, 1, 2]" );
}

/// ditto
void formatValue(Writer, T, Char)(Writer w, T val, ref FormatSpec!Char f)
if (is(T == interface) && (hasToString!(T, Char) || !isBuiltinType!T) && !is(T == enum))
{
    if (val is null)
        put(w, "null");
    else
    {
        static if (hasToString!(T, Char))
        {
            formatObject(w, val, f);
        }
        else static if (isInputRange!T)
        {
            formatRange(w, val, f);
        }
        else
        {
            formatValue(w, cast(Object)val, f);
        }
    }
}

unittest
{
    // interface
    InputRange!int i = inputRangeObject([1,2,3,4]);
    formatTest( i, "[1, 2, 3, 4]" );
    assert(i.empty);
    i = null;
    formatTest( i, "null" );

    // interface (downcast to Object)
    interface Whatever {}
    class C : Whatever
    {
        override @property string toString() { return "ab"; }
    }
    Whatever val = new C;
    formatTest( val, "ab" );
}

/// ditto
// Maybe T is noncopyable struct, so receive it by 'auto ref'.
void formatValue(Writer, T, Char)(Writer w, auto ref T val, ref FormatSpec!Char f)
if ((is(T == struct) || is(T == union)) && (hasToString!(T, Char) || !isBuiltinType!T) && !is(T == enum))
{
    static if (hasToString!(T, Char))
    {
        formatObject(w, val, f);
    }
    else static if (isInputRange!T)
    {
        formatRange(w, val, f);
    }
    else static if (is(T == struct))
    {
        enum left = T.stringof~"(";
        enum separator = ", ";
        enum right = ")";

        put(w, left);
        foreach (i, e; val.tupleof)
        {
            static if (0 < i && val.tupleof[i-1].offsetof == val.tupleof[i].offsetof)
            {
                static if (i == val.tupleof.length - 1 || val.tupleof[i].offsetof != val.tupleof[i+1].offsetof)
                    put(w, separator~val.tupleof[i].stringof[4..$]~"}");
                else
                    put(w, separator~val.tupleof[i].stringof[4..$]);
            }
            else
            {
                static if (i+1 < val.tupleof.length && val.tupleof[i].offsetof == val.tupleof[i+1].offsetof)
                    put(w, (i > 0 ? separator : "")~"#{overlap "~val.tupleof[i].stringof[4..$]);
                else
                {
                    static if (i > 0)
                        put(w, separator);
                    formatElement(w, e, f);
                }
            }
        }
        put(w, right);
    }
    else
    {
        put(w, T.stringof);
    }
}

unittest
{
    // bug 4638
    struct U8  {  string toString() { return "blah"; } }
    struct U16 { wstring toString() { return "blah"; } }
    struct U32 { dstring toString() { return "blah"; } }
    formatTest( U8(), "blah" );
    formatTest( U16(), "blah" );
    formatTest( U32(), "blah" );
}

unittest
{
    // 3890
    struct Int{ int n; }
    struct Pair{ string s; Int i; }
    formatTest( Pair("hello", Int(5)),
                `Pair("hello", Int(5))` );
}

unittest
{
    // union formatting without toString
    union U1
    {
        int n;
        string s;
    }
    U1 u1;
    formatTest( u1, "U1" );

    // union formatting with toString
    union U2
    {
        int n;
        string s;
        string toString(){ return s; }
    }
    U2 u2;
    u2.s = "hello";
    formatTest( u2, "hello" );
}

unittest
{
    // 7230
    static struct Bug7230
    {
        string s = "hello";
        union {
            string a;
            int b;
            double c;
        }
        long x = 10;
    }

    Bug7230 bug;
    bug.b = 123;

    FormatSpec!char f;
    auto w = appender!(char[])();
    formatValue(w, bug, f);
    assert(w.data == `Bug7230("hello", #{overlap a, b, c}, 10)`);
}

unittest
{
    static struct S{ @disable this(this); }
    S s;

    FormatSpec!char f;
    auto w = appender!string();
    formatValue(w, s, f);
    assert(w.data == "S()");
}

/**
   $(D enum) is formatted like its base value.
 */
void formatValue(Writer, T, Char)(Writer w, T val, ref FormatSpec!Char f)
if (is(T == enum))
{
    if (f.spec == 's')
    {
        foreach (i, e; EnumMembers!T)
        {
            if (val == e)
            {
                formatValue(w, __traits(allMembers, T)[i], f);
                return;
            }
        }

        // val is not a member of T, output cast(T)rawValue instead.
        put(w, "cast(" ~ T.stringof ~ ")");
        static assert(!is(OriginalType!T == T));
    }
    formatValue(w, cast(OriginalType!T)val, f);
}
unittest
{
    enum A { first, second, third }
    formatTest( A.second, "second" );
    formatTest( cast(A)72, "cast(A)72" );
}
unittest
{
    enum A : string { one = "uno", two = "dos", three = "tres" }
    formatTest( A.three, "three" );
    formatTest( cast(A)"mill\&oacute;n", "cast(A)mill\&oacute;n" );
}
unittest
{
    enum A : bool { no, yes }
    formatTest( A.yes, "yes" );
    formatTest( A.no, "no" );
}
unittest
{
    // Test for bug 6892
    enum Foo { A = 10 }
    formatTest("%s",    Foo.A, "A");
    formatTest(">%4s<", Foo.A, ">   A<");
    formatTest("%04d",  Foo.A, "0010");
    formatTest("%+2u",  Foo.A, "+10");
    formatTest("%02x",  Foo.A, "0a");
    formatTest("%3o",   Foo.A, " 12");
    formatTest("%b",    Foo.A, "1010");
}

/**
   Pointers are formatted as hex integers.
 */
void formatValue(Writer, T, Char)(Writer w, T val, ref FormatSpec!Char f)
if (!hasToString!(T, Char) && isPointer!T)
{
    if (val is null)
        put(w, "null");
    else
    {
        static if (isInputRange!T)
        {
            formatRange(w, *val, f);
        }
        else
        {
            const void * p = val;
            if (f.spec == 's')
            {
                FormatSpec!Char fs = f; // fs is copy for change its values.
                fs.spec = 'X';
                formatValue(w, cast(ulong) p, fs);
            }
            else
            {
                enforceEx!FormatException(f.spec == 'X' || f.spec == 'x',
                   "Expected one of %s, %x or %X for pointer type.");
                formatValue(w, cast(ulong) p, f);
            }
        }
    }
}

unittest
{
    // pointer
    auto r = retro([1,2,3,4]);
    auto p = &r;
    formatTest( p, "[4, 3, 2, 1]" );
    assert(p.empty);
    p = null;
    formatTest( p, "null" );

    auto q = cast(void*)0xFFEECCAA;
    formatTest( q, "FFEECCAA" );
}

unittest
{
    // Test for issue 7869
    struct S
    {
        string toString(){ return ""; }
    }
    S* p = null;
    formatTest( p, "null" );

    S* q = cast(S*)0xFFEECCAA;
    formatTest( q, "FFEECCAA" );
}

unittest
{
    // Test for issue 8186
    class B
    {
        int*a;
        this(){ a = new int; }
        alias a this;
    }
    formatTest( B.init, "null" );
}


/**
   Delegates are formatted by 'Attributes ReturnType delegate(Parameters)'
 */
void formatValue(Writer, T, Char)(Writer w, T val, ref FormatSpec!Char f)
if (!hasToString!(T, Char) && is(T == delegate))
{
    alias FunctionAttribute FA;
    if (functionAttributes!T & FA.pure_)    formatValue(w, "pure ", f);
    if (functionAttributes!T & FA.nothrow_) formatValue(w, "nothrow ", f);
    if (functionAttributes!T & FA.ref_)     formatValue(w, "ref ", f);
    if (functionAttributes!T & FA.property) formatValue(w, "@property ", f);
    if (functionAttributes!T & FA.trusted)  formatValue(w, "@trusted ", f);
    if (functionAttributes!T & FA.safe)     formatValue(w, "@safe ", f);
    formatValue(w, ReturnType!(T).stringof,f);
    formatValue(w, " delegate",f);
    formatValue(w, ParameterTypeTuple!(T).stringof,f);
}

unittest
{
    void func() {}
    formatTest( &func, "void delegate()" );
}

/*
   Formatting a $(D typedef) is deprecated but still kept around for a while.
 */
void formatValue(Writer, T, Char)(Writer w, T val, ref FormatSpec!Char f)
if (is(T == typedef))
{
    static if (is(T U == typedef))
    {
        formatValue(w, cast(U) val, f);
    }
}

/*
  Formats an object of type 'D' according to 'f' and writes it to
  'w'. The pointer 'arg' is assumed to point to an object of type
  'D'. The untyped signature is for the sake of taking this function's
  address.
 */
private void formatGeneric(Writer, D, Char)(Writer w, const(void)* arg, ref FormatSpec!Char f)
{
    formatValue(w, *cast(D*) arg, f);
}

private void formatNth(Writer, Char, A...)(Writer w, ref FormatSpec!Char f, size_t index, A args)
{
    static string gencode(size_t count)()
    {
        string result;
        foreach (n; 0 .. count)
        {
            auto num = to!string(n);
            result ~=
                "case "~num~":"~
                "    formatValue(w, args["~num~"], f);"~
                "    break;";
        }
        return result;
    }

    switch (index)
    {
        mixin(gencode!(A.length)());

        default:
            assert(0, "n = "~cast(char)(index + '0'));
    }
}

unittest
{
    int[] a = [ 1, 3, 2 ];
    formatTest( "testing %(%s & %) embedded", a,
                "testing 1 & 3 & 2 embedded");
    formatTest( "testing %((%s) %)) wyda3", a,
                "testing (1) (3) (2) wyda3" );

    int[0] empt = [];
    formatTest( "(%s)", empt,
                "([])" );
}

//------------------------------------------------------------------------------
// Fix for issue 1591
private int getNthInt(A...)(uint index, A args)
{
    static if (A.length)
    {
        if (index)
        {
            return getNthInt(index - 1, args[1 .. $]);
        }
        static if (is(typeof(args[0]) : long) || is(typeof(arg) : ulong))
        {
            return to!(int)(args[0]);
        }
        else
        {
            throw new FormatException("int expected");
        }
    }
    else
    {
        throw new FormatException("int expected");
    }
}

/* ======================== Unit Tests ====================================== */

version(unittest)
void formatTest(T)(T val, string expected, size_t ln = __LINE__, string fn = __FILE__)
{
    FormatSpec!char f;
    auto w = appender!string();
    formatValue(w, val, f);
    enforceEx!AssertError(
            w.data == expected,
            text("expected = `", expected, "`, result = `", w.data, "`"), fn, ln);
}

version(unittest)
void formatTest(T)(string fmt, T val, string expected, size_t ln = __LINE__, string fn = __FILE__)
{
    auto w = appender!string();
    formattedWrite(w, fmt, val);
    enforceEx!AssertError(
            w.data == expected,
            text("expected = `", expected, "`, result = `", w.data, "`"), fn, ln);
}

unittest
{
    auto stream = appender!string();
    formattedWrite(stream, "%s", 1.1);
    assert(stream.data == "1.1", stream.data);

    stream = appender!string();
    formattedWrite(stream, "%s", map!"a*a"([2, 3, 5]));
    assert(stream.data == "[4, 9, 25]", stream.data);

    // Test shared data.
    stream = appender!string();
    shared int s = 6;
    formattedWrite(stream, "%s", s);
    assert(stream.data == "6");
}

unittest
{
    auto stream = appender!string();
    formattedWrite(stream, "%u", 42);
    assert(stream.data == "42", stream.data);
}

unittest
{
    // testing raw writes
    auto w = appender!(char[])();
    uint a = 0x02030405;
    formattedWrite(w, "%+r", a);
    assert(w.data.length == 4 && w.data[0] == 2 && w.data[1] == 3
        && w.data[2] == 4 && w.data[3] == 5);
    w.clear();
    formattedWrite(w, "%-r", a);
    assert(w.data.length == 4 && w.data[0] == 5 && w.data[1] == 4
        && w.data[2] == 3 && w.data[3] == 2);
}

unittest
{
    // testing positional parameters
    auto w = appender!(char[])();
    formattedWrite(w,
            "Numbers %2$s and %1$s are reversed and %1$s%2$s repeated",
            42, 0);
    assert(w.data == "Numbers 0 and 42 are reversed and 420 repeated",
            w.data);
    w.clear();
    formattedWrite(w, "asd%s", 23);
    assert(w.data == "asd23", w.data);
    w.clear();
    formattedWrite(w, "%s%s", 23, 45);
    assert(w.data == "2345", w.data);
}

unittest
{
    debug(format) printf("std.format.format.unittest\n");

    auto stream = appender!(char[])();
    //goto here;

    formattedWrite(stream,
            "hello world! %s %s ", true, 57, 1_000_000_000, 'x', " foo");
    assert(stream.data == "hello world! true 57 ",
        stream.data);

    stream.clear();
    formattedWrite(stream, "%g %A %s", 1.67, -1.28, float.nan);
    // std.c.stdio.fwrite(stream.data.ptr, stream.data.length, 1, stderr);

    /* The host C library is used to format floats.  C99 doesn't
    * specify what the hex digit before the decimal point is for
    * %A.  */

    version (linux)
    {
        assert(stream.data == "1.67 -0X1.47AE147AE147BP+0 nan",
                stream.data);
    }
    else version (OSX)
    {
        assert(stream.data == "1.67 -0X1.47AE147AE147BP+0 nan",
                stream.data);
    }
    else
    {
        assert(stream.data == "1.67 -0X1.47AE147AE147BP+0 nan",
                stream.data);
    }
    stream.clear();

    formattedWrite(stream, "%x %X", 0x1234AF, 0xAFAFAFAF);
    assert(stream.data == "1234af AFAFAFAF");
    stream.clear();

    formattedWrite(stream, "%b %o", 0x1234AF, 0xAFAFAFAF);
    assert(stream.data == "100100011010010101111 25753727657");
    stream.clear();

    formattedWrite(stream, "%d %s", 0x1234AF, 0xAFAFAFAF);
    assert(stream.data == "1193135 2947526575");
    stream.clear();

    // formattedWrite(stream, "%s", 1.2 + 3.4i);
    // assert(stream.data == "1.2+3.4i");
    // stream.clear();

    formattedWrite(stream, "%a %A", 1.32, 6.78f);
    //formattedWrite(stream, "%x %X", 1.32);
    assert(stream.data == "0x1.51eb851eb851fp+0 0X1.B1EB86P+2");
    stream.clear();

    formattedWrite(stream, "%#06.*f",2,12.345);
    assert(stream.data == "012.35");
    stream.clear();

    formattedWrite(stream, "%#0*.*f",6,2,12.345);
    assert(stream.data == "012.35");
    stream.clear();

    const real constreal = 1;
    formattedWrite(stream, "%g",constreal);
    assert(stream.data == "1");
    stream.clear();

    formattedWrite(stream, "%7.4g:", 12.678);
    assert(stream.data == "  12.68:");
    stream.clear();

    formattedWrite(stream, "%7.4g:", 12.678L);
    assert(stream.data == "  12.68:");
    stream.clear();

    formattedWrite(stream, "%04f|%05d|%#05x|%#5x",-4.,-10,1,1);
    assert(stream.data == "-4.000000|-0010|0x001|  0x1",
            stream.data);
    stream.clear();

    int i;
    string s;

    i = -10;
    formattedWrite(stream, "%d|%3d|%03d|%1d|%01.4f",i,i,i,i,cast(double) i);
    assert(stream.data == "-10|-10|-10|-10|-10.0000");
    stream.clear();

    i = -5;
    formattedWrite(stream, "%d|%3d|%03d|%1d|%01.4f",i,i,i,i,cast(double) i);
    assert(stream.data == "-5| -5|-05|-5|-5.0000");
    stream.clear();

    i = 0;
    formattedWrite(stream, "%d|%3d|%03d|%1d|%01.4f",i,i,i,i,cast(double) i);
    assert(stream.data == "0|  0|000|0|0.0000");
    stream.clear();

    i = 5;
    formattedWrite(stream, "%d|%3d|%03d|%1d|%01.4f",i,i,i,i,cast(double) i);
    assert(stream.data == "5|  5|005|5|5.0000");
    stream.clear();

    i = 10;
    formattedWrite(stream, "%d|%3d|%03d|%1d|%01.4f",i,i,i,i,cast(double) i);
    assert(stream.data == "10| 10|010|10|10.0000");
    stream.clear();

    formattedWrite(stream, "%.0d", 0);
    assert(stream.data == "");
    stream.clear();

    formattedWrite(stream, "%.g", .34);
    assert(stream.data == "0.3");
    stream.clear();

    stream.clear(); formattedWrite(stream, "%.0g", .34);
    assert(stream.data == "0.3");

    stream.clear(); formattedWrite(stream, "%.2g", .34);
    assert(stream.data == "0.34");

    stream.clear(); formattedWrite(stream, "%0.0008f", 1e-08);
    assert(stream.data == "0.00000001");

    stream.clear(); formattedWrite(stream, "%0.0008f", 1e-05);
    assert(stream.data == "0.00001000");

    //return;
    //std.c.stdio.fwrite(stream.data.ptr, stream.data.length, 1, stderr);

    s = "helloworld";
    string r;
    stream.clear(); formattedWrite(stream, "%.2s", s[0..5]);
    assert(stream.data == "he");
    stream.clear(); formattedWrite(stream, "%.20s", s[0..5]);
    assert(stream.data == "hello");
    stream.clear(); formattedWrite(stream, "%8s", s[0..5]);
    assert(stream.data == "   hello");

    byte[] arrbyte = new byte[4];
    arrbyte[0] = 100;
    arrbyte[1] = -99;
    arrbyte[3] = 0;
    stream.clear(); formattedWrite(stream, "%s", arrbyte);
    assert(stream.data == "[100, -99, 0, 0]", stream.data);

    ubyte[] arrubyte = new ubyte[4];
    arrubyte[0] = 100;
    arrubyte[1] = 200;
    arrubyte[3] = 0;
    stream.clear(); formattedWrite(stream, "%s", arrubyte);
    assert(stream.data == "[100, 200, 0, 0]", stream.data);

    short[] arrshort = new short[4];
    arrshort[0] = 100;
    arrshort[1] = -999;
    arrshort[3] = 0;
    stream.clear(); formattedWrite(stream, "%s", arrshort);
    assert(stream.data == "[100, -999, 0, 0]");
    stream.clear(); formattedWrite(stream, "%s",arrshort);
    assert(stream.data == "[100, -999, 0, 0]");

    ushort[] arrushort = new ushort[4];
    arrushort[0] = 100;
    arrushort[1] = 20_000;
    arrushort[3] = 0;
    stream.clear(); formattedWrite(stream, "%s", arrushort);
    assert(stream.data == "[100, 20000, 0, 0]");

    int[] arrint = new int[4];
    arrint[0] = 100;
    arrint[1] = -999;
    arrint[3] = 0;
    stream.clear(); formattedWrite(stream, "%s", arrint);
    assert(stream.data == "[100, -999, 0, 0]");
    stream.clear(); formattedWrite(stream, "%s",arrint);
    assert(stream.data == "[100, -999, 0, 0]");

    long[] arrlong = new long[4];
    arrlong[0] = 100;
    arrlong[1] = -999;
    arrlong[3] = 0;
    stream.clear(); formattedWrite(stream, "%s", arrlong);
    assert(stream.data == "[100, -999, 0, 0]");
    stream.clear(); formattedWrite(stream, "%s",arrlong);
    assert(stream.data == "[100, -999, 0, 0]");

    ulong[] arrulong = new ulong[4];
    arrulong[0] = 100;
    arrulong[1] = 999;
    arrulong[3] = 0;
    stream.clear(); formattedWrite(stream, "%s", arrulong);
    assert(stream.data == "[100, 999, 0, 0]");

    string[] arr2 = new string[4];
    arr2[0] = "hello";
    arr2[1] = "world";
    arr2[3] = "foo";
    stream.clear(); formattedWrite(stream, "%s", arr2);
    assert(stream.data == `["hello", "world", "", "foo"]`, stream.data);

    stream.clear(); formattedWrite(stream, "%.8d", 7);
    assert(stream.data == "00000007");

    stream.clear(); formattedWrite(stream, "%.8x", 10);
    assert(stream.data == "0000000a");

    stream.clear(); formattedWrite(stream, "%-3d", 7);
    assert(stream.data == "7  ");

    stream.clear(); formattedWrite(stream, "%*d", -3, 7);
    assert(stream.data == "7  ");

    stream.clear(); formattedWrite(stream, "%.*d", -3, 7);
    //writeln(stream.data);
    assert(stream.data == "7");

//  assert(false);
//   typedef int myint;
//   myint m = -7;
//   stream.clear(); formattedWrite(stream, "", m);
//   assert(stream.data == "-7");

    stream.clear(); formattedWrite(stream, "%s", "abc"c);
    assert(stream.data == "abc");
    stream.clear(); formattedWrite(stream, "%s", "def"w);
    assert(stream.data == "def", text(stream.data.length));
    stream.clear(); formattedWrite(stream, "%s", "ghi"d);
    assert(stream.data == "ghi");

here:
    void* p = cast(void*)0xDEADBEEF;
    stream.clear(); formattedWrite(stream, "%s", p);
    assert(stream.data == "DEADBEEF", stream.data);

    stream.clear(); formattedWrite(stream, "%#x", 0xabcd);
    assert(stream.data == "0xabcd");
    stream.clear(); formattedWrite(stream, "%#X", 0xABCD);
    assert(stream.data == "0XABCD");

    stream.clear(); formattedWrite(stream, "%#o", octal!12345);
    assert(stream.data == "012345");
    stream.clear(); formattedWrite(stream, "%o", 9);
    assert(stream.data == "11");

    stream.clear(); formattedWrite(stream, "%+d", 123);
    assert(stream.data == "+123");
    stream.clear(); formattedWrite(stream, "%+d", -123);
    assert(stream.data == "-123");
    stream.clear(); formattedWrite(stream, "% d", 123);
    assert(stream.data == " 123");
    stream.clear(); formattedWrite(stream, "% d", -123);
    assert(stream.data == "-123");

    stream.clear(); formattedWrite(stream, "%%");
    assert(stream.data == "%");

    stream.clear(); formattedWrite(stream, "%d", true);
    assert(stream.data == "1");
    stream.clear(); formattedWrite(stream, "%d", false);
    assert(stream.data == "0");

    stream.clear(); formattedWrite(stream, "%d", 'a');
    assert(stream.data == "97", stream.data);
    wchar wc = 'a';
    stream.clear(); formattedWrite(stream, "%d", wc);
    assert(stream.data == "97");
    dchar dc = 'a';
    stream.clear(); formattedWrite(stream, "%d", dc);
    assert(stream.data == "97");

    byte b = byte.max;
    stream.clear(); formattedWrite(stream, "%x", b);
    assert(stream.data == "7f");
    stream.clear(); formattedWrite(stream, "%x", ++b);
    assert(stream.data == "80");
    stream.clear(); formattedWrite(stream, "%x", ++b);
    assert(stream.data == "81");

    short sh = short.max;
    stream.clear(); formattedWrite(stream, "%x", sh);
    assert(stream.data == "7fff");
    stream.clear(); formattedWrite(stream, "%x", ++sh);
    assert(stream.data == "8000");
    stream.clear(); formattedWrite(stream, "%x", ++sh);
    assert(stream.data == "8001");

    i = int.max;
    stream.clear(); formattedWrite(stream, "%x", i);
    assert(stream.data == "7fffffff");
    stream.clear(); formattedWrite(stream, "%x", ++i);
    assert(stream.data == "80000000");
    stream.clear(); formattedWrite(stream, "%x", ++i);
    assert(stream.data == "80000001");

    stream.clear(); formattedWrite(stream, "%x", 10);
    assert(stream.data == "a");
    stream.clear(); formattedWrite(stream, "%X", 10);
    assert(stream.data == "A");
    stream.clear(); formattedWrite(stream, "%x", 15);
    assert(stream.data == "f");
    stream.clear(); formattedWrite(stream, "%X", 15);
    assert(stream.data == "F");

    Object c = null;
    stream.clear(); formattedWrite(stream, "%s", c);
    assert(stream.data == "null");

    enum TestEnum
    {
        Value1, Value2
    }
    stream.clear(); formattedWrite(stream, "%s", TestEnum.Value2);
    assert(stream.data == "Value2", stream.data);
    stream.clear(); formattedWrite(stream, "%s", cast(TestEnum)5);
    assert(stream.data == "cast(TestEnum)5", stream.data);

    //immutable(char[5])[int] aa = ([3:"hello", 4:"betty"]);
    //stream.clear(); formattedWrite(stream, "%s", aa.values);
    //std.c.stdio.fwrite(stream.data.ptr, stream.data.length, 1, stderr);
    //assert(stream.data == "[[h,e,l,l,o],[b,e,t,t,y]]");
    //stream.clear(); formattedWrite(stream, "%s", aa);
    //assert(stream.data == "[3:[h,e,l,l,o],4:[b,e,t,t,y]]");

    static const dchar[] ds = ['a','b'];
    for (int j = 0; j < ds.length; ++j)
    {
        stream.clear(); formattedWrite(stream, " %d", ds[j]);
        if (j == 0)
            assert(stream.data == " 97");
        else
            assert(stream.data == " 98");
    }

    stream.clear(); formattedWrite(stream, "%.-3d", 7);
    assert(stream.data == "7", ">" ~ stream.data ~ "<");


    // systematic test
    const string[] flags = [ "-", "+", "#", "0", " ", "" ];
    const string[] widths = [ "", "0", "4", "20" ];
    const string[] precs = [ "", ".", ".0", ".4", ".20" ];
    const string formats = "sdoxXeEfFgGaA";
  /+
  foreach (flag1; flags)
      foreach (flag2; flags)
          foreach (flag3; flags)
              foreach (flag4; flags)
                  foreach (flag5; flags)
                      foreach (width; widths)
                          foreach (prec; precs)
                              foreach (format; formats)
                              {
                                  stream.clear();
                                  auto fmt = "%" ~ flag1 ~ flag2  ~ flag3
                                      ~ flag4 ~ flag5 ~ width ~ prec ~ format
                                      ~ '\0';
                                  fmt = fmt[0 .. $ - 1]; // keep it zero-term
                                  char buf[256];
                                  buf[0] = 0;
                                  switch (format)
                                  {
                                  case 's':
                                      formattedWrite(stream, fmt, "wyda");
                                      snprintf(buf.ptr, buf.length, fmt.ptr,
                                          "wyda\0".ptr);
                                      break;
                                  case 'd':
                                      formattedWrite(stream, fmt, 456);
                                      snprintf(buf.ptr, buf.length, fmt.ptr,
                                               456);
                                      break;
                                  case 'o':
                                      formattedWrite(stream, fmt, 345);
                                      snprintf(buf.ptr, buf.length, fmt.ptr,
                                               345);
                                      break;
                                  case 'x':
                                      formattedWrite(stream, fmt, 63546);
                                      snprintf(buf.ptr, buf.length, fmt.ptr,
                                          63546);
                                      break;
                                  case 'X':
                                      formattedWrite(stream, fmt, 12566);
                                      snprintf(buf.ptr, buf.length, fmt.ptr,
                                          12566);
                                      break;
                                  case 'e':
                                      formattedWrite(stream, fmt, 3245.345234);
                                      snprintf(buf.ptr, buf.length, fmt.ptr,
                                          3245.345234);
                                      break;
                                  case 'E':
                                      formattedWrite(stream, fmt, 3245.2345234);
                                      snprintf(buf.ptr, buf.length, fmt.ptr,
                                          3245.2345234);
                                      break;
                                  case 'f':
                                      formattedWrite(stream, fmt, 3245234.645675);
                                      snprintf(buf.ptr, buf.length, fmt.ptr,
                                          3245234.645675);
                                      break;
                                  case 'F':
                                      formattedWrite(stream, fmt, 213412.43);
                                      snprintf(buf.ptr, buf.length, fmt.ptr,
                                          213412.43);
                                      break;
                                  case 'g':
                                      formattedWrite(stream, fmt, 234134.34);
                                      snprintf(buf.ptr, buf.length, fmt.ptr,
                                          234134.34);
                                      break;
                                  case 'G':
                                      formattedWrite(stream, fmt, 23141234.4321);
                                      snprintf(buf.ptr, buf.length, fmt.ptr,
                                               23141234.4321);
                                      break;
                                  case 'a':
                                      formattedWrite(stream, fmt, 21341234.2134123);
                                      snprintf(buf.ptr, buf.length, fmt.ptr,
                                               21341234.2134123);
                                      break;
                                  case 'A':
                                      formattedWrite(stream, fmt, 1092384098.45234);
                                      snprintf(buf.ptr, buf.length, fmt.ptr,
                                               1092384098.45234);
                                      break;
                                  default:
                                      break;
                                  }
                                  auto exp = buf[0 .. strlen(buf.ptr)];
                                  if (stream.data != exp)
                                  {
                                      writeln("Format: \"", fmt, '"');
                                      writeln("Expected: >", exp, "<");
                                      writeln("Actual:   >", stream.data,
                                              "<");
                                      assert(false);
                                  }
                              }+/
}

unittest
{
    immutable(char[5])[int] aa = ([3:"hello", 4:"betty"]);
    if (false) writeln(aa.keys);
    assert(aa[3] == "hello");
    assert(aa[4] == "betty");
    // if (false)
    // {
    //     writeln(aa.values[0]);
    //     writeln(aa.values[1]);
    //     writefln("%s", typeid(typeof(aa.values)));
    //     writefln("%s", aa[3]);
    //     writefln("%s", aa[4]);
    //     writefln("%s", aa.values);
    //     //writefln("%s", aa);
    //     wstring a = "abcd";
    //     writefln(a);
    //     dstring b = "abcd";
    //     writefln(b);
    // }

    auto stream = appender!(char[])();
    alias TypeTuple!(byte, ubyte, short, ushort, int, uint, long, ulong,
            float, double, real) AllNumerics;
    foreach (T; AllNumerics)
    {
        T value = 1;
        stream.clear();
        formattedWrite(stream, "%s", value);
        assert(stream.data == "1");
    }

    //auto r = std.string.format("%s", aa.values);
    stream.clear(); formattedWrite(stream, "%s", aa);
    //assert(stream.data == "[3:[h,e,l,l,o],4:[b,e,t,t,y]]", stream.data);
//    r = std.string.format("%s", aa);
//   assert(r == "[3:[h,e,l,l,o],4:[b,e,t,t,y]]");
}

unittest
{
    string s = "hello!124:34.5";
    string a;
    int b;
    double c;
    formattedRead(s, "%s!%s:%s", &a, &b, &c);
    assert(a == "hello" && b == 124 && c == 34.5);
}

version(unittest)
void formatReflectTest(T)(ref T val, string fmt, string formatted, string fn = __FILE__, size_t ln = __LINE__)
{
    auto w = appender!string();
    formattedWrite(w, fmt, val);

    auto input = w.data;
    enforceEx!AssertError(
            input == formatted,
            input, fn, ln);

    T val2;
    formattedRead(input, fmt, &val2);
    static if (isAssociativeArray!T)
    if (__ctfe)
    {
        alias val aa1;
        alias val2 aa2;
        //assert(aa1 == aa2);

        assert(aa1.length == aa2.length);

        assert(aa1.keys == aa2.keys);

        //assert(aa1.values == aa2.values);
        assert(aa1.values.length == aa2.values.length);
        foreach (i; 0 .. aa1.values.length)
            assert(aa1.values[i] == aa2.values[i]);

        //foreach (i, key; aa1.keys)
        //    assert(aa1.values[i] == aa1[key]);
        //foreach (i, key; aa2.keys)
        //    assert(aa2.values[i] == aa2[key]);
        return;
    }
    enforceEx!AssertError(
            val == val2,
            input, fn, ln);
}

version(unittest)
@property void checkCTFEable(alias dg)()
{
    static assert({ dg(); return true; }());
    dg();
}

unittest
{
    void booleanTest()
    {
        auto b = true;
        formatReflectTest(b, "%s",  `true`);
        formatReflectTest(b, "%b",  `1`);
        formatReflectTest(b, "%o",  `1`);
        formatReflectTest(b, "%d",  `1`);
        formatReflectTest(b, "%u",  `1`);
        formatReflectTest(b, "%x",  `1`);
    }

    void integerTest()
    {
        auto n = 127;
        formatReflectTest(n, "%s",  `127`);
        formatReflectTest(n, "%b",  `1111111`);
        formatReflectTest(n, "%o",  `177`);
        formatReflectTest(n, "%d",  `127`);
        formatReflectTest(n, "%u",  `127`);
        formatReflectTest(n, "%x",  `7f`);
    }

    void floatingTest()
    {
        auto f = 3.14;
        formatReflectTest(f, "%s",  `3.14`);
        formatReflectTest(f, "%e",  `3.140000e+00`);
        formatReflectTest(f, "%f",  `3.140000`);
        formatReflectTest(f, "%g",  `3.14`);
    }

    void charTest()
    {
        auto c = 'a';
        formatReflectTest(c, "%s",  `a`);
        formatReflectTest(c, "%c",  `a`);
        formatReflectTest(c, "%b",  `1100001`);
        formatReflectTest(c, "%o",  `141`);
        formatReflectTest(c, "%d",  `97`);
        formatReflectTest(c, "%u",  `97`);
        formatReflectTest(c, "%x",  `61`);
    }

    void strTest()
    {
        auto s = "hello";
        formatReflectTest(s, "%s",                      `hello`);
        formatReflectTest(s, "%(%c,%)",                 `h,e,l,l,o`);
        formatReflectTest(s, "%(%s,%)",                 `'h','e','l','l','o'`);
        formatReflectTest(s, "[%(<%c>%| $ %)]",         `[<h> $ <e> $ <l> $ <l> $ <o>]`);
    }

    void daTest()
    {
        auto a = [1,2,3,4];
        formatReflectTest(a, "%s",                      `[1, 2, 3, 4]`);
        formatReflectTest(a, "[%(%s; %)]",              `[1; 2; 3; 4]`);
        formatReflectTest(a, "[%(<%s>%| $ %)]",         `[<1> $ <2> $ <3> $ <4>]`);
    }

    void saTest()
    {
        int[4] sa = [1,2,3,4];
        formatReflectTest(sa, "%s",                     `[1, 2, 3, 4]`);
        formatReflectTest(sa, "[%(%s; %)]",             `[1; 2; 3; 4]`);
        formatReflectTest(sa, "[%(<%s>%| $ %)]",        `[<1> $ <2> $ <3> $ <4>]`);
    }

    void aaTest()
    {
        auto aa = [1:"hello", 2:"world"];
        formatReflectTest(aa, "%s",                     `[1:"hello", 2:"world"]`);
        formatReflectTest(aa, "[%(%s->%s, %)]",         `[1->"hello", 2->"world"]`);
        formatReflectTest(aa, "{%([%s=%(%c%)]%|; %)}",  `{[1=hello]; [2=world]}`);
    }

    checkCTFEable!({
        booleanTest();
        integerTest();
        if (!__ctfe) floatingTest();    // snprintf
        charTest();
        strTest();
        daTest();
        saTest();
        aaTest();
        return true;
    });
}

//------------------------------------------------------------------------------
private void skipData(Range, Char)(ref Range input, ref FormatSpec!Char spec)
{
    switch (spec.spec)
    {
        case 'c': input.popFront(); break;
        case 'd':
            if (input.front == '+' || input.front == '-') input.popFront();
            goto case 'u';
        case 'u':
            while (!input.empty && isDigit(input.front)) input.popFront();
            break;
        default:
            assert(false,
                    text("Format specifier not understood: %", spec.spec));
    }
}

private template acceptedSpecs(T)
{
         static if (isIntegral!T)       enum acceptedSpecs = "bdosuxX";
    else static if (isFloatingPoint!T)  enum acceptedSpecs = "seEfgG";
    else static if (isSomeChar!T)       enum acceptedSpecs = "bcdosuxX";    // integral + 'c'
    else                                enum acceptedSpecs = "";
}

/**
 * Reads a boolean value and returns it.
 */
T unformatValue(T, Range, Char)(ref Range input, ref FormatSpec!Char spec)
    if (isInputRange!Range && is(Unqual!T == bool))
{
    if (spec.spec == 's')
    {
        return parse!T(input);
    }
    enforce(std.algorithm.find(acceptedSpecs!long, spec.spec).length,
            text("Wrong unformat specifier '%", spec.spec , "' for ", T.stringof));

    return unformatValue!long(input, spec) != 0;
}

unittest
{
    string line;

    bool f1;

    line = "true";
    formattedRead(line, "%s", &f1);
    assert(f1);

    line = "TrUE";
    formattedRead(line, "%s", &f1);
    assert(f1);

    line = "false";
    formattedRead(line, "%s", &f1);
    assert(!f1);

    line = "fALsE";
    formattedRead(line, "%s", &f1);
    assert(!f1);

    line = "1";
    formattedRead(line, "%d", &f1);
    assert(f1);

    line = "-1";
    formattedRead(line, "%d", &f1);
    assert(f1);

    line = "0";
    formattedRead(line, "%d", &f1);
    assert(!f1);

    line = "-0";
    formattedRead(line, "%d", &f1);
    assert(!f1);
}

/**
 * Reads null literal and returns it.
 */
T unformatValue(T, Range, Char)(ref Range input, ref FormatSpec!Char spec)
    if (isInputRange!Range && is(T == typeof(null)))
{
    enforce(spec.spec == 's',
            text("Wrong unformat specifier '%", spec.spec , "' for ", T.stringof));

    return parse!T(input);
}

/**
   Reads an integral value and returns it.
 */
T unformatValue(T, Range, Char)(ref Range input, ref FormatSpec!Char spec)
    if (isInputRange!Range && isIntegral!T)
{
    enforce(std.algorithm.find(acceptedSpecs!T, spec.spec).length,
            text("Wrong unformat specifier '%", spec.spec , "' for ", T.stringof));

    enforce(spec.width == 0);   // TODO

    uint base =
        spec.spec == 'x' || spec.spec == 'X' ? 16 :
        spec.spec == 'o' ? 8 :
        spec.spec == 'b' ? 2 :
        spec.spec == 's' || spec.spec == 'd' || spec.spec == 'u' ? 10 : 0;
    assert(base != 0);
    return parse!T(input, base);
}

/**
   Reads a floating-point value and returns it.
 */
T unformatValue(T, Range, Char)(ref Range input, ref FormatSpec!Char spec)
    if (isFloatingPoint!T)
{
    if (spec.spec == 'r')
    {
        // raw read
        //enforce(input.length >= T.sizeof);
        enforce(isSomeString!Range || ElementType!(Range).sizeof == 1);
        union X
        {
            ubyte[T.sizeof] raw;
            T typed;
        }
        X x;
        foreach (i; 0 .. T.sizeof)
        {
            static if (isSomeString!Range)
            {
                x.raw[i] = input[0];
                input = input[1 .. $];
            }
            else
            {
                // TODO: recheck this
                x.raw[i] = cast(ubyte) input.front;
                input.popFront();
            }
        }
        return x.typed;
    }
    enforce(std.algorithm.find(acceptedSpecs!T, spec.spec).length,
            text("Wrong unformat specifier '%", spec.spec , "' for ", T.stringof));

    return parse!T(input);
}

version(none)unittest
{
    union A
    {
        char[float.sizeof] untyped;
        float typed;
    }
    A a;
    a.typed = 5.5;
    char[] input = a.untyped[];
    float witness;
    formattedRead(input, "%r", &witness);
    assert(witness == a.typed);
}

unittest
{
    char[] line = "1 2".dup;
    int a, b;
    formattedRead(line, "%s %s", &a, &b);
    assert(a == 1 && b == 2);

    line = "10 2 3".dup;
    formattedRead(line, "%d ", &a);
    assert(a == 10);
    assert(line == "2 3");

    Tuple!(int, float) t;
    line = "1 2.125".dup;
    formattedRead(line, "%d %g", &t);
    assert(t[0] == 1 && t[1] == 2.125);

    line = "1 7643 2.125".dup;
    formattedRead(line, "%s %*u %s", &t);
    assert(t[0] == 1 && t[1] == 2.125);
}

/**
 * Reads one character and returns it.
 */
T unformatValue(T, Range, Char)(ref Range input, ref FormatSpec!Char spec)
    if (isInputRange!Range && isSomeChar!T)
{
    if (spec.spec == 's' || spec.spec == 'c')
    {
        auto result = to!T(input.front);
        input.popFront();
        return result;
    }
    enforce(std.algorithm.find(acceptedSpecs!T, spec.spec).length,
            text("Wrong unformat specifier '%", spec.spec , "' for ", T.stringof));

    static if (T.sizeof == 1)
        return unformatValue!ubyte(input, spec);
    else static if (T.sizeof == 2)
        return unformatValue!ushort(input, spec);
    else static if (T.sizeof == 4)
        return unformatValue!uint(input, spec);
    else
        static assert(0);
}

unittest
{
    string line;

    char c1, c2;

    line = "abc";
    formattedRead(line, "%s%c", &c1, &c2);
    assert(c1 == 'a' && c2 == 'b');
    assert(line == "c");
}

/**
   Reads a string and returns it.
 */
T unformatValue(T, Range, Char)(ref Range input, ref FormatSpec!Char spec)
    if (isInputRange!Range && isSomeString!T)
{
    if (spec.spec == '(')
    {
        return unformatRange!T(input, spec);
    }
    enforce(spec.spec == 's',
            text("Wrong unformat specifier '%", spec.spec , "' for ", T.stringof));

    static if (isStaticArray!T)
    {
        T result;
        auto app = result[];
    }
    else
        auto app = appender!T();
    if (spec.trailing.empty)
    {
        for (; !input.empty; input.popFront())
        {
            static if (isStaticArray!T)
                if (app.empty)
                    break;
            app.put(input.front);
        }
    }
    else
    {
        auto end = spec.trailing.front;
        for (; !input.empty && input.front != end; input.popFront())
        {
            static if (isStaticArray!T)
                if (app.empty)
                    break;
            app.put(input.front);
        }
    }
    static if (isStaticArray!T)
    {
        enforce(app.empty, "need more input");
        return result;
    }
    else
        return app.data;
}

unittest
{
    string line;

    string s1, s2;

    line = "hello, world";
    formattedRead(line, "%s", &s1);
    assert(s1 == "hello, world", s1);

    line = "hello, world;yah";
    formattedRead(line, "%s;%s", &s1, &s2);
    assert(s1 == "hello, world", s1);
    assert(s2 == "yah", s2);

    line = `['h','e','l','l','o']`;
    string s3;
    formattedRead(line, "[%(%s,%)]", &s3);
    assert(s3 == "hello");

    line = `"hello"`;
    string s4;
    formattedRead(line, "\"%(%c%)\"", &s4);
    assert(s4 == "hello");
}

/**
   Reads an array (except for string types) and returns it.
 */
T unformatValue(T, Range, Char)(ref Range input, ref FormatSpec!Char spec)
    if (isInputRange!Range && isArray!T && !isSomeString!T)
{
    if (spec.spec == '(')
    {
        return unformatRange!T(input, spec);
    }
    enforce(spec.spec == 's',
            text("Wrong unformat specifier '%", spec.spec , "' for ", T.stringof));

    return parse!T(input);
}

unittest
{
    string line;

    line = "[1,2,3]";
    int[] s1;
    formattedRead(line, "%s", &s1);
    assert(s1 == [1,2,3]);
}

unittest
{
    string line;

    line = "[1,2,3]";
    int[] s1;
    formattedRead(line, "[%(%s,%)]", &s1);
    assert(s1 == [1,2,3]);

    line = `["hello", "world"]`;
    string[] s2;
    formattedRead(line, "[%(%s, %)]", &s2);
    assert(s2 == ["hello", "world"]);

    line = "123 456";
    int[] s3;
    formattedRead(line, "%(%s %)", &s3);
    assert(s3 == [123, 456]);

    line = "h,e,l,l,o; w,o,r,l,d";
    string[] s4;
    formattedRead(line, "%(%(%c,%); %)", &s4);
    assert(s4 == ["hello", "world"]);
}

unittest
{
    string line;

    int[4] sa1;
    line = `[1,2,3,4]`;
    formattedRead(line, "%s", &sa1);
    assert(sa1 == [1,2,3,4]);

    int[4] sa2;
    line = `[1,2,3]`;
    assertThrown(formattedRead(line, "%s", &sa2));

    int[4] sa3;
    line = `[1,2,3,4,5]`;
    assertThrown(formattedRead(line, "%s", &sa3));
}

unittest
{
    string input;

    int[4] sa1;
    input = `[1,2,3,4]`;
    formattedRead(input, "[%(%s,%)]", &sa1);
    assert(sa1 == [1,2,3,4]);

    int[4] sa2;
    input = `[1,2,3]`;
    assertThrown(formattedRead(input, "[%(%s,%)]", &sa2));
}

unittest
{
    // 7241
    string input = "a";
    auto spec = FormatSpec!char("%s");
    spec.readUpToNextSpec(input);
    auto result = unformatValue!(dchar[1])(input, spec);
    assert(result[0] == 'a');
}

/**
 * Reads an associative array and returns it.
 */
T unformatValue(T, Range, Char)(ref Range input, ref FormatSpec!Char spec)
    if (isInputRange!Range && isAssociativeArray!T)
{
    if (spec.spec == '(')
    {
        return unformatRange!T(input, spec);
    }
    enforce(spec.spec == 's',
            text("Wrong unformat specifier '%", spec.spec , "' for ", T.stringof));

    return parse!T(input);
}

unittest
{
    string line;

    string[int] aa1;
    line = `[1:"hello", 2:"world"]`;
    formattedRead(line, "%s", &aa1);
    assert(aa1 == [1:"hello", 2:"world"]);

    int[string] aa2;
    line = `{"hello"=1; "world"=2}`;
    formattedRead(line, "{%(%s=%s; %)}", &aa2);
    assert(aa2 == ["hello":1, "world":2]);

    int[string] aa3;
    line = `{[hello=1]; [world=2]}`;
    formattedRead(line, "{%([%(%c%)=%s]%|; %)}", &aa3);
    assert(aa3 == ["hello":1, "world":2]);
}

//debug = unformatRange;

private T unformatRange(T, Range, Char)(ref Range input, ref FormatSpec!Char spec)
in
{
    assert(spec.spec == '(');
}
body
{
    debug (unformatRange) printf("unformatRange:\n");

    T result;
    static if (isStaticArray!T)
    {
        size_t i;
    }

    const(Char)[] cont = spec.trailing;
    for (size_t j = 0; j < spec.trailing.length; ++j)
    {
        if (spec.trailing[j] == '%')
        {
            cont = spec.trailing[0 .. j];
            break;
        }
    }
    debug (unformatRange) printf("\t");
    debug (unformatRange) if (!input.empty) printf("input.front = %c, ", input.front);
    debug (unformatRange) printf("cont = %.*s\n", cont);

    bool checkEnd()
    {
        return input.empty || !cont.empty && input.front == cont.front;
    }

    if (!checkEnd())
    {
        for (;;)
        {
            auto fmt = FormatSpec!Char(spec.nested);
            fmt.readUpToNextSpec(input);
            enforce(!input.empty);

            debug (unformatRange) printf("\t) spec = %c, front = %c ", fmt.spec, input.front);
            static if (isStaticArray!T)
            {
                result[i++] = unformatElement!(typeof(T.init[0]))(input, fmt);
            }
            else static if (isDynamicArray!T)
            {
                result ~= unformatElement!(ElementType!T)(input, fmt);
            }
            else static if (isAssociativeArray!T)
            {
                auto key = unformatElement!(typeof(T.keys[0]))(input, fmt);
                fmt.readUpToNextSpec(input);        // eat key separator

                result[key] = unformatElement!(typeof(T.values[0]))(input, fmt);
            }
            debug (unformatRange) {
            if (input.empty) printf("-> front = [empty] ");
            else             printf("-> front = %c ", input.front);
            }

            static if (isStaticArray!T)
            {
                debug (unformatRange) printf("i = %u < %u\n", i, T.length);
                enforce(i <= T.length);
            }

            auto sep =
                spec.sep ? fmt.readUpToNextSpec(input), spec.sep
                         : fmt.trailing;
            debug (unformatRange) {
            if (!sep.empty && !input.empty) printf("-> %c, sep = %.*s\n", input.front, sep);
            else                            printf("\n");
            }

            if (checkEnd())
                break;

            if (!sep.empty && input.front == sep.front)
            {
                while (!sep.empty)
                {
                    enforce(!input.empty);
                    enforce(input.front == sep.front);
                    input.popFront();
                    sep.popFront();
                }
                debug (unformatRange) printf("input.front = %c\n", input.front);
            }
        }
    }
    static if (isStaticArray!T)
    {
        enforce(i == T.length);
    }
    return result;
}

// Undocumented
T unformatElement(T, Range, Char)(ref Range input, ref FormatSpec!Char spec)
    if (isInputRange!Range)
{
    static if (isSomeString!T)
    {
        if (spec.spec == 's')
        {
            return parseElement!T(input);
        }
    }
    else static if (isSomeChar!T)
    {
        if (spec.spec == 's')
        {
            return parseElement!T(input);
        }
    }

    return unformatValue!T(input, spec);
}


// Legacy implementation

enum Mangle : char
{
    Tvoid     = 'v',
    Tbool     = 'b',
    Tbyte     = 'g',
    Tubyte    = 'h',
    Tshort    = 's',
    Tushort   = 't',
    Tint      = 'i',
    Tuint     = 'k',
    Tlong     = 'l',
    Tulong    = 'm',
    Tfloat    = 'f',
    Tdouble   = 'd',
    Treal     = 'e',

    Tifloat   = 'o',
    Tidouble  = 'p',
    Tireal    = 'j',
    Tcfloat   = 'q',
    Tcdouble  = 'r',
    Tcreal    = 'c',

    Tchar     = 'a',
    Twchar    = 'u',
    Tdchar    = 'w',

    Tarray    = 'A',
    Tsarray   = 'G',
    Taarray   = 'H',
    Tpointer  = 'P',
    Tfunction = 'F',
    Tident    = 'I',
    Tclass    = 'C',
    Tstruct   = 'S',
    Tenum     = 'E',
    Ttypedef  = 'T',
    Tdelegate = 'D',

    Tconst    = 'x',
    Timmutable = 'y',
}

// return the TypeInfo for a primitive type and null otherwise.  This
// is required since for arrays of ints we only have the mangled char
// to work from. If arrays always subclassed TypeInfo_Array this
// routine could go away.
private TypeInfo primitiveTypeInfo(Mangle m)
{
    // BUG: should fix this in static this() to avoid double checked locking bug
    __gshared TypeInfo[Mangle] dic;
    if (!dic.length) {
        dic = [
            Mangle.Tvoid : typeid(void),
            Mangle.Tbool : typeid(bool),
            Mangle.Tbyte : typeid(byte),
            Mangle.Tubyte : typeid(ubyte),
            Mangle.Tshort : typeid(short),
            Mangle.Tushort : typeid(ushort),
            Mangle.Tint : typeid(int),
            Mangle.Tuint : typeid(uint),
            Mangle.Tlong : typeid(long),
            Mangle.Tulong : typeid(ulong),
            Mangle.Tfloat : typeid(float),
            Mangle.Tdouble : typeid(double),
            Mangle.Treal : typeid(real),
            Mangle.Tifloat : typeid(ifloat),
            Mangle.Tidouble : typeid(idouble),
            Mangle.Tireal : typeid(ireal),
            Mangle.Tcfloat : typeid(cfloat),
            Mangle.Tcdouble : typeid(cdouble),
            Mangle.Tcreal : typeid(creal),
            Mangle.Tchar : typeid(char),
            Mangle.Twchar : typeid(wchar),
            Mangle.Tdchar : typeid(dchar)
            ];
    }
    auto p = m in dic;
    return p ? *p : null;
}

// This stuff has been removed from the docs and is planned for deprecation.
/*
 * Interprets variadic argument list pointed to by argptr whose types
 * are given by arguments[], formats them according to embedded format
 * strings in the variadic argument list, and sends the resulting
 * characters to putc.
 *
 * The variadic arguments are consumed in order.  Each is formatted
 * into a sequence of chars, using the default format specification
 * for its type, and the characters are sequentially passed to putc.
 * If a $(D char[]), $(D wchar[]), or $(D dchar[]) argument is
 * encountered, it is interpreted as a format string. As many
 * arguments as specified in the format string are consumed and
 * formatted according to the format specifications in that string and
 * passed to putc. If there are too few remaining arguments, a
 * $(D FormatException) is thrown. If there are more remaining arguments than
 * needed by the format specification, the default processing of
 * arguments resumes until they are all consumed.
 *
 * Params:
 *        putc =        Output is sent do this delegate, character by character.
 *        arguments = Array of $(D TypeInfo)s, one for each argument to be formatted.
 *        argptr = Points to variadic argument list.
 *
 * Throws:
 *        Mismatched arguments and formats result in a $(D FormatException) being thrown.
 *
 * Format_String:
 *        <a name="format-string">$(I Format strings)</a>
 *        consist of characters interspersed with
 *        $(I format specifications). Characters are simply copied
 *        to the output (such as putc) after any necessary conversion
 *        to the corresponding UTF-8 sequence.
 *
 *        A $(I format specification) starts with a '%' character,
 *        and has the following grammar:

<pre>
$(I FormatSpecification):
    $(B '%%')
    $(B '%') $(I Flags) $(I Width) $(I Precision) $(I FormatChar)

$(I Flags):
    $(I empty)
    $(B '-') $(I Flags)
    $(B '+') $(I Flags)
    $(B '#') $(I Flags)
    $(B '0') $(I Flags)
    $(B ' ') $(I Flags)

$(I Width):
    $(I empty)
    $(I Integer)
    $(B '*')

$(I Precision):
    $(I empty)
    $(B '.')
    $(B '.') $(I Integer)
    $(B '.*')

$(I Integer):
    $(I Digit)
    $(I Digit) $(I Integer)

$(I Digit):
    $(B '0')
    $(B '1')
    $(B '2')
    $(B '3')
    $(B '4')
    $(B '5')
    $(B '6')
    $(B '7')
    $(B '8')
    $(B '9')

$(I FormatChar):
    $(B 's')
    $(B 'b')
    $(B 'd')
    $(B 'o')
    $(B 'x')
    $(B 'X')
    $(B 'e')
    $(B 'E')
    $(B 'f')
    $(B 'F')
    $(B 'g')
    $(B 'G')
    $(B 'a')
    $(B 'A')
</pre>
    <dl>
    <dt>$(I Flags)
    <dl>
        <dt>$(B '-')
        <dd>
        Left justify the result in the field.
        It overrides any $(B 0) flag.

        <dt>$(B '+')
        <dd>Prefix positive numbers in a signed conversion with a $(B +).
        It overrides any $(I space) flag.

        <dt>$(B '#')
        <dd>Use alternative formatting:
        <dl>
            <dt>For $(B 'o'):
            <dd> Add to precision as necessary so that the first digit
            of the octal formatting is a '0', even if both the argument
            and the $(I Precision) are zero.
            <dt> For $(B 'x') ($(B 'X')):
            <dd> If non-zero, prefix result with $(B 0x) ($(B 0X)).
            <dt> For floating point formatting:
            <dd> Always insert the decimal point.
            <dt> For $(B 'g') ($(B 'G')):
            <dd> Do not elide trailing zeros.
        </dl>

        <dt>$(B '0')
        <dd> For integer and floating point formatting when not nan or
        infinity, use leading zeros
        to pad rather than spaces.
        Ignore if there's a $(I Precision).

        <dt>$(B ' ')
        <dd>Prefix positive numbers in a signed conversion with a space.
    </dl>

    <dt>$(I Width)
    <dd>
    Specifies the minimum field width.
    If the width is a $(B *), the next argument, which must be
    of type $(B int), is taken as the width.
    If the width is negative, it is as if the $(B -) was given
    as a $(I Flags) character.

    <dt>$(I Precision)
    <dd> Gives the precision for numeric conversions.
    If the precision is a $(B *), the next argument, which must be
    of type $(B int), is taken as the precision. If it is negative,
    it is as if there was no $(I Precision).

    <dt>$(I FormatChar)
    <dd>
    <dl>
        <dt>$(B 's')
        <dd>The corresponding argument is formatted in a manner consistent
        with its type:
        <dl>
            <dt>$(B bool)
            <dd>The result is <tt>'true'</tt> or <tt>'false'</tt>.
            <dt>integral types
            <dd>The $(B %d) format is used.
            <dt>floating point types
            <dd>The $(B %g) format is used.
            <dt>string types
            <dd>The result is the string converted to UTF-8.
            A $(I Precision) specifies the maximum number of characters
            to use in the result.
            <dt>classes derived from $(B Object)
            <dd>The result is the string returned from the class instance's
            $(B .toString()) method.
            A $(I Precision) specifies the maximum number of characters
            to use in the result.
            <dt>non-string static and dynamic arrays
            <dd>The result is [s<sub>0</sub>, s<sub>1</sub>, ...]
            where s<sub>k</sub> is the kth element
            formatted with the default format.
        </dl>

        <dt>$(B 'b','d','o','x','X')
        <dd> The corresponding argument must be an integral type
        and is formatted as an integer. If the argument is a signed type
        and the $(I FormatChar) is $(B d) it is converted to
        a signed string of characters, otherwise it is treated as
        unsigned. An argument of type $(B bool) is formatted as '1'
        or '0'. The base used is binary for $(B b), octal for $(B o),
        decimal
        for $(B d), and hexadecimal for $(B x) or $(B X).
        $(B x) formats using lower case letters, $(B X) uppercase.
        If there are fewer resulting digits than the $(I Precision),
        leading zeros are used as necessary.
        If the $(I Precision) is 0 and the number is 0, no digits
        result.

        <dt>$(B 'e','E')
        <dd> A floating point number is formatted as one digit before
        the decimal point, $(I Precision) digits after, the $(I FormatChar),
        &plusmn;, followed by at least a two digit exponent: $(I d.dddddd)e$(I &plusmn;dd).
        If there is no $(I Precision), six
        digits are generated after the decimal point.
        If the $(I Precision) is 0, no decimal point is generated.

        <dt>$(B 'f','F')
        <dd> A floating point number is formatted in decimal notation.
        The $(I Precision) specifies the number of digits generated
        after the decimal point. It defaults to six. At least one digit
        is generated before the decimal point. If the $(I Precision)
        is zero, no decimal point is generated.

        <dt>$(B 'g','G')
        <dd> A floating point number is formatted in either $(B e) or
        $(B f) format for $(B g); $(B E) or $(B F) format for
        $(B G).
        The $(B f) format is used if the exponent for an $(B e) format
        is greater than -5 and less than the $(I Precision).
        The $(I Precision) specifies the number of significant
        digits, and defaults to six.
        Trailing zeros are elided after the decimal point, if the fractional
        part is zero then no decimal point is generated.

        <dt>$(B 'a','A')
        <dd> A floating point number is formatted in hexadecimal
        exponential notation 0x$(I h.hhhhhh)p$(I &plusmn;d).
        There is one hexadecimal digit before the decimal point, and as
        many after as specified by the $(I Precision).
        If the $(I Precision) is zero, no decimal point is generated.
        If there is no $(I Precision), as many hexadecimal digits as
        necessary to exactly represent the mantissa are generated.
        The exponent is written in as few digits as possible,
        but at least one, is in decimal, and represents a power of 2 as in
        $(I h.hhhhhh)*2<sup>$(I &plusmn;d)</sup>.
        The exponent for zero is zero.
        The hexadecimal digits, x and p are in upper case if the
        $(I FormatChar) is upper case.
    </dl>

    Floating point NaN's are formatted as $(B nan) if the
    $(I FormatChar) is lower case, or $(B NAN) if upper.
    Floating point infinities are formatted as $(B inf) or
    $(B infinity) if the
    $(I FormatChar) is lower case, or $(B INF) or $(B INFINITY) if upper.
    </dl>

Example:

-------------------------
import std.c.stdio;
import std.format;

void myPrint(...)
{
    void putc(char c)
    {
        fputc(c, stdout);
    }

    std.format.doFormat(&putc, _arguments, _argptr);
}

...

int x = 27;
// prints 'The answer is 27:6'
myPrint("The answer is %s:", x, 6);
------------------------
 */
void doFormat(void delegate(dchar) putc, TypeInfo[] arguments, va_list argptr)
{
    TypeInfo ti;
    Mangle m;
    uint flags;
    int field_width;
    int precision;

    enum : uint
    {
        FLdash = 1,
        FLplus = 2,
        FLspace = 4,
        FLhash = 8,
        FLlngdbl = 0x20,
        FL0pad = 0x40,
        FLprecision = 0x80,
    }

    static TypeInfo skipCI(TypeInfo valti)
    {
        for (;;)
        {
            if (valti.classinfo.name.length == 18 &&
                    valti.classinfo.name[9..18] == "Invariant")
                valti =        (cast(TypeInfo_Invariant)valti).next;
            else if (valti.classinfo.name.length == 14 &&
                    valti.classinfo.name[9..14] == "Const")
                valti =        (cast(TypeInfo_Const)valti).next;
            else
                break;
        }
        return valti;
    }

    void formatArg(char fc)
    {
        bool vbit;
        ulong vnumber;
        char vchar;
        dchar vdchar;
        Object vobject;
        real vreal;
        creal vcreal;
        Mangle m2;
        int signed = 0;
        uint base = 10;
        int uc;
        char[ulong.sizeof * 8] tmpbuf; // long enough to print long in binary
        const(char)* prefix = "";
        string s;

        void putstr(const char[] s)
        {
            //printf("putstr: s = %.*s, flags = x%x\n", s.length, s.ptr, flags);
            sizediff_t padding = field_width -
                (strlen(prefix) + toUCSindex(s, s.length));
            sizediff_t prepad = 0;
            sizediff_t postpad = 0;
            if (padding > 0)
            {
                if (flags & FLdash)
                    postpad = padding;
                else
                    prepad = padding;
            }

            if (flags & FL0pad)
            {
                while (*prefix)
                    putc(*prefix++);
                while (prepad--)
                    putc('0');
            }
            else
            {
                while (prepad--)
                    putc(' ');
                while (*prefix)
                    putc(*prefix++);
            }

            foreach (dchar c; s)
                putc(c);

            while (postpad--)
                putc(' ');
        }

        void putreal(real v)
        {
            //printf("putreal %Lg\n", vreal);

            switch (fc)
            {
                case 's':
                    fc = 'g';
                    break;

                case 'f', 'F', 'e', 'E', 'g', 'G', 'a', 'A':
                    break;

                default:
                    //printf("fc = '%c'\n", fc);
                Lerror:
                    throw new FormatException("floating");
            }
            version (DigitalMarsC)
            {
                uint sl;
                char[] fbuf = tmpbuf;
                if (!(flags & FLprecision))
                    precision = 6;
                while (1)
                {
                    sl = fbuf.length;
                    prefix = (*__pfloatfmt)(fc, flags | FLlngdbl,
                            precision, &v, cast(char*)fbuf, &sl, field_width);
                    if (sl != -1)
                        break;
                    sl = fbuf.length * 2;
                    fbuf = (cast(char*)alloca(sl * char.sizeof))[0 .. sl];
                }
                putstr(fbuf[0 .. sl]);
            }
            else
            {
                sizediff_t sl;
                char[] fbuf = tmpbuf;
                char[12] format;
                format[0] = '%';
                int i = 1;
                if (flags & FLdash)
                    format[i++] = '-';
                if (flags & FLplus)
                    format[i++] = '+';
                if (flags & FLspace)
                    format[i++] = ' ';
                if (flags & FLhash)
                    format[i++] = '#';
                if (flags & FL0pad)
                    format[i++] = '0';
                format[i + 0] = '*';
                format[i + 1] = '.';
                format[i + 2] = '*';
                format[i + 3] = 'L';
                format[i + 4] = fc;
                format[i + 5] = 0;
                if (!(flags & FLprecision))
                    precision = -1;
                while (1)
                {
                    sl = fbuf.length;
                    auto n = snprintf(fbuf.ptr, sl, format.ptr, field_width,
                            precision, v);
                    //printf("format = '%s', n = %d\n", cast(char*)format, n);
                    if (n >= 0 && n < sl)
                    {        sl = n;
                        break;
                    }
                    if (n < 0)
                        sl = sl * 2;
                    else
                        sl = n + 1;
                    fbuf = (cast(char*)alloca(sl * char.sizeof))[0 .. sl];
                }
                putstr(fbuf[0 .. sl]);
            }
            return;
        }

        static Mangle getMan(TypeInfo ti)
        {
          auto m = cast(Mangle)ti.classinfo.name[9];
          if (ti.classinfo.name.length == 20 &&
              ti.classinfo.name[9..20] == "StaticArray")
                m = cast(Mangle)'G';
          return m;
        }

        /* p = pointer to the first element in the array
         * len = number of elements in the array
         * valti = type of the elements
         */
        void putArray(void* p, size_t len, TypeInfo valti)
        {
          //printf("\nputArray(len = %u), tsize = %u\n", len, valti.tsize());
          putc('[');
          valti = skipCI(valti);
          size_t tsize = valti.tsize();
          auto argptrSave = argptr;
          auto tiSave = ti;
          auto mSave = m;
          ti = valti;
          //printf("\n%.*s\n", valti.classinfo.name.length, valti.classinfo.name.ptr);
          m = getMan(valti);
          while (len--)
          {
            //doFormat(putc, (&valti)[0 .. 1], p);
            version(X86)
                argptr = p;
            else version(X86_64)
            {
                __va_list va;
                va.stack_args = p;
                argptr = &va;
            }
            else
                static assert(false, "unsupported platform");
            formatArg('s');

            p += tsize;
            if (len > 0) putc(',');
          }
          m = mSave;
          ti = tiSave;
          argptr = argptrSave;
          putc(']');
        }

        void putAArray(ubyte[long] vaa, TypeInfo valti, TypeInfo keyti)
        {
            putc('[');
            bool comma=false;
            auto argptrSave = argptr;
            auto tiSave = ti;
            auto mSave = m;
            valti = skipCI(valti);
            keyti = skipCI(keyti);
            foreach(ref fakevalue; vaa)
            {
                if (comma) putc(',');
                comma = true;
                void *pkey = &fakevalue;
                version (D_LP64)
                    pkey -= (long.sizeof + 15) & ~(15);
                else
                    pkey -= (long.sizeof + size_t.sizeof - 1) & ~(size_t.sizeof - 1);

                // the key comes before the value
                auto keysize = keyti.tsize;
                version (D_LP64)
                    auto keysizet = (keysize + 15) & ~(15);
                else
                    auto keysizet = (keysize + size_t.sizeof - 1) & ~(size_t.sizeof - 1);

                void* pvalue = pkey + keysizet;

                //doFormat(putc, (&keyti)[0..1], pkey);
                version (X86)
                    argptr = pkey;
                else version (X86_64)
                {   __va_list va;
                    va.stack_args = pkey;
                    argptr = &va;
                }
                else static assert(false, "unsupported platform");

                ti = keyti;
                m = getMan(keyti);
                formatArg('s');

                putc(':');
                //doFormat(putc, (&valti)[0..1], pvalue);
                version (X86)
                    argptr = pvalue;
                else version (X86_64)
                {   __va_list va2;
                    va2.stack_args = pvalue;
                    argptr = &va2;
                }
                else static assert(false, "unsupported platform");

                ti = valti;
                m = getMan(valti);
                formatArg('s');
            }
            m = mSave;
            ti = tiSave;
            argptr = argptrSave;
            putc(']');
        }

        //printf("formatArg(fc = '%c', m = '%c')\n", fc, m);
        switch (m)
        {
            case Mangle.Tbool:
                vbit = va_arg!(bool)(argptr);
                if (fc != 's')
                {   vnumber = vbit;
                    goto Lnumber;
                }
                putstr(vbit ? "true" : "false");
                return;

            case Mangle.Tchar:
                vchar = va_arg!(char)(argptr);
                if (fc != 's')
                {   vnumber = vchar;
                    goto Lnumber;
                }
            L2:
                putstr((&vchar)[0 .. 1]);
                return;

            case Mangle.Twchar:
                vdchar = va_arg!(wchar)(argptr);
                goto L1;

            case Mangle.Tdchar:
                vdchar = va_arg!(dchar)(argptr);
            L1:
                if (fc != 's')
                {   vnumber = vdchar;
                    goto Lnumber;
                }
                if (vdchar <= 0x7F)
                {   vchar = cast(char)vdchar;
                    goto L2;
                }
                else
                {   if (!isValidDchar(vdchar))
                        throw new UTFException("invalid dchar in format");
                    char[4] vbuf;
                    putstr(toUTF8(vbuf, vdchar));
                }
                return;

            case Mangle.Tbyte:
                signed = 1;
                vnumber = va_arg!(byte)(argptr);
                goto Lnumber;

            case Mangle.Tubyte:
                vnumber = va_arg!(ubyte)(argptr);
                goto Lnumber;

            case Mangle.Tshort:
                signed = 1;
                vnumber = va_arg!(short)(argptr);
                goto Lnumber;

            case Mangle.Tushort:
                vnumber = va_arg!(ushort)(argptr);
                goto Lnumber;

            case Mangle.Tint:
                signed = 1;
                vnumber = va_arg!(int)(argptr);
                goto Lnumber;

            case Mangle.Tuint:
            Luint:
                vnumber = va_arg!(uint)(argptr);
                goto Lnumber;

            case Mangle.Tlong:
                signed = 1;
                vnumber = cast(ulong)va_arg!(long)(argptr);
                goto Lnumber;

            case Mangle.Tulong:
            Lulong:
                vnumber = va_arg!(ulong)(argptr);
                goto Lnumber;

            case Mangle.Tclass:
                vobject = va_arg!(Object)(argptr);
                if (vobject is null)
                    s = "null";
                else
                    s = vobject.toString();
                goto Lputstr;

            case Mangle.Tpointer:
                vnumber = cast(ulong)va_arg!(void*)(argptr);
                if (fc != 'x')  uc = 1;
                flags |= FL0pad;
                if (!(flags & FLprecision))
                {   flags |= FLprecision;
                    precision = (void*).sizeof;
                }
                base = 16;
                goto Lnumber;

            case Mangle.Tfloat:
            case Mangle.Tifloat:
                if (fc == 'x' || fc == 'X')
                    goto Luint;
                vreal = va_arg!(float)(argptr);
                goto Lreal;

            case Mangle.Tdouble:
            case Mangle.Tidouble:
                if (fc == 'x' || fc == 'X')
                    goto Lulong;
                vreal = va_arg!(double)(argptr);
                goto Lreal;

            case Mangle.Treal:
            case Mangle.Tireal:
                vreal = va_arg!(real)(argptr);
                goto Lreal;

            case Mangle.Tcfloat:
                vcreal = va_arg!(cfloat)(argptr);
                goto Lcomplex;

            case Mangle.Tcdouble:
                vcreal = va_arg!(cdouble)(argptr);
                goto Lcomplex;

            case Mangle.Tcreal:
                vcreal = va_arg!(creal)(argptr);
                goto Lcomplex;

            case Mangle.Tsarray:
                version (X86)
                    putArray(argptr, (cast(TypeInfo_StaticArray)ti).len, (cast(TypeInfo_StaticArray)ti).next);
                else
                    putArray((cast(__va_list*)argptr).stack_args, (cast(TypeInfo_StaticArray)ti).len, (cast(TypeInfo_StaticArray)ti).next);
                return;

            case Mangle.Tarray:
                int mi = 10;
                if (ti.classinfo.name.length == 14 &&
                    ti.classinfo.name[9..14] == "Array")
                { // array of non-primitive types
                  TypeInfo tn = (cast(TypeInfo_Array)ti).next;
                  tn = skipCI(tn);
                  switch (cast(Mangle)tn.classinfo.name[9])
                  {
                    case Mangle.Tchar:  goto LarrayChar;
                    case Mangle.Twchar: goto LarrayWchar;
                    case Mangle.Tdchar: goto LarrayDchar;
                    default:
                        break;
                  }
                  void[] va = va_arg!(void[])(argptr);
                  putArray(va.ptr, va.length, tn);
                  return;
                }
                if (ti.classinfo.name.length == 25 &&
                    ti.classinfo.name[9..25] == "AssociativeArray")
                { // associative array
                  ubyte[long] vaa = va_arg!(ubyte[long])(argptr);
                  putAArray(vaa,
                        (cast(TypeInfo_AssociativeArray)ti).next,
                        (cast(TypeInfo_AssociativeArray)ti).key);
                  return;
                }

                while (1)
                {
                    m2 = cast(Mangle)ti.classinfo.name[mi];
                    switch (m2)
                    {
                        case Mangle.Tchar:
                        LarrayChar:
                            s = va_arg!(string)(argptr);
                            goto Lputstr;

                        case Mangle.Twchar:
                        LarrayWchar:
                            wchar[] sw = va_arg!(wchar[])(argptr);
                            s = toUTF8(sw);
                            goto Lputstr;

                        case Mangle.Tdchar:
                        LarrayDchar:
                            auto sd = va_arg!(dstring)(argptr);
                            s = toUTF8(sd);
                        Lputstr:
                            if (fc != 's')
                                throw new FormatException("string");
                            if (flags & FLprecision && precision < s.length)
                                s = s[0 .. precision];
                            putstr(s);
                            break;

                        case Mangle.Tconst:
                        case Mangle.Timmutable:
                            mi++;
                            continue;

                        default:
                            TypeInfo ti2 = primitiveTypeInfo(m2);
                            if (!ti2)
                              goto Lerror;
                            void[] va = va_arg!(void[])(argptr);
                            putArray(va.ptr, va.length, ti2);
                    }
                    return;
                }
                assert(0);

            case Mangle.Ttypedef:
                ti = (cast(TypeInfo_Typedef)ti).base;
                m = cast(Mangle)ti.classinfo.name[9];
                formatArg(fc);
                return;

            case Mangle.Tenum:
                ti = (cast(TypeInfo_Enum)ti).base;
                m = cast(Mangle)ti.classinfo.name[9];
                formatArg(fc);
                return;

            case Mangle.Tstruct:
            {        TypeInfo_Struct tis = cast(TypeInfo_Struct)ti;
                if (tis.xtoString is null)
                    throw new FormatException("Can't convert " ~ tis.toString()
                            ~ " to string: \"string toString()\" not defined");
                version(X86)
                {
                    s = tis.xtoString(argptr);
                    argptr += (tis.tsize() + 3) & ~3;
                }
                else version (X86_64)
                {
                    void[32] parmn = void; // place to copy struct if passed in regs
                    void* p;
                    auto tsize = tis.tsize();
                    TypeInfo arg1, arg2;
                    if (!tis.argTypes(arg1, arg2))      // if could be passed in regs
                    {   assert(tsize <= parmn.length);
                        p = parmn.ptr;
                        va_arg(argptr, tis, p);
                    }
                    else
                    {   /* Avoid making a copy of the struct; take advantage of
                         * it always being passed in memory
                         */
                        // The arg may have more strict alignment than the stack
                        auto talign = tis.talign();
                        __va_list* ap = cast(__va_list*)argptr;
                        p = cast(void*)((cast(size_t)ap.stack_args + talign - 1) & ~(talign - 1));
                        ap.stack_args = cast(void*)(cast(size_t)p + ((tsize + size_t.sizeof - 1) & ~(size_t.sizeof - 1)));
                    }
                    s = tis.xtoString(p);
                }
                else
                     static assert(0);
                goto Lputstr;
            }

            default:
                goto Lerror;
        }

    Lnumber:
        switch (fc)
        {
            case 's':
            case 'd':
                if (signed)
                {   if (cast(long)vnumber < 0)
                    {        prefix = "-";
                        vnumber = -vnumber;
                    }
                    else if (flags & FLplus)
                        prefix = "+";
                    else if (flags & FLspace)
                        prefix = " ";
                }
                break;

            case 'b':
                signed = 0;
                base = 2;
                break;

            case 'o':
                signed = 0;
                base = 8;
                break;

            case 'X':
                uc = 1;
                if (flags & FLhash && vnumber)
                    prefix = "0X";
                signed = 0;
                base = 16;
                break;

            case 'x':
                if (flags & FLhash && vnumber)
                    prefix = "0x";
                signed = 0;
                base = 16;
                break;

            default:
                goto Lerror;
        }

        if (!signed)
        {
            switch (m)
            {
                case Mangle.Tbyte:
                    vnumber &= 0xFF;
                    break;

                case Mangle.Tshort:
                    vnumber &= 0xFFFF;
                    break;

                case Mangle.Tint:
                    vnumber &= 0xFFFFFFFF;
                    break;

                default:
                    break;
            }
        }

        if (flags & FLprecision && fc != 'p')
            flags &= ~FL0pad;

        if (vnumber < base)
        {
            if (vnumber == 0 && precision == 0 && flags & FLprecision &&
                !(fc == 'o' && flags & FLhash))
            {
                putstr(null);
                return;
            }
            if (precision == 0 || !(flags & FLprecision))
            {        vchar = cast(char)('0' + vnumber);
                if (vnumber < 10)
                    vchar = cast(char)('0' + vnumber);
                else
                    vchar = cast(char)((uc ? 'A' - 10 : 'a' - 10) + vnumber);
                goto L2;
            }
        }

        sizediff_t n = tmpbuf.length;
        char c;
        int hexoffset = uc ? ('A' - ('9' + 1)) : ('a' - ('9' + 1));

        while (vnumber)
        {
            c = cast(char)((vnumber % base) + '0');
            if (c > '9')
                c += hexoffset;
            vnumber /= base;
            tmpbuf[--n] = c;
        }
        if (tmpbuf.length - n < precision && precision < tmpbuf.length)
        {
            sizediff_t m = tmpbuf.length - precision;
            tmpbuf[m .. n] = '0';
            n = m;
        }
        else if (flags & FLhash && fc == 'o')
            prefix = "0";
        putstr(tmpbuf[n .. tmpbuf.length]);
        return;

    Lreal:
        putreal(vreal);
        return;

    Lcomplex:
        putreal(vcreal.re);
        putc('+');
        putreal(vcreal.im);
        putc('i');
        return;

    Lerror:
        throw new FormatException("formatArg");
    }

    for (int j = 0; j < arguments.length; )
    {
        ti = arguments[j++];
        //printf("arg[%d]: '%.*s' %d\n", j, ti.classinfo.name.length, ti.classinfo.name.ptr, ti.classinfo.name.length);
        //ti.print();

        flags = 0;
        precision = 0;
        field_width = 0;

        ti = skipCI(ti);
        int mi = 9;
        do
        {
            if (ti.classinfo.name.length <= mi)
                goto Lerror;
            m = cast(Mangle)ti.classinfo.name[mi++];
        } while (m == Mangle.Tconst || m == Mangle.Timmutable);

        if (m == Mangle.Tarray)
        {
            if (ti.classinfo.name.length == 14 &&
                    ti.classinfo.name[9..14] == "Array")
            {
                TypeInfo tn = (cast(TypeInfo_Array)ti).next;
                tn = skipCI(tn);
                switch (cast(Mangle)tn.classinfo.name[9])
                {
                case Mangle.Tchar:
                case Mangle.Twchar:
                case Mangle.Tdchar:
                    ti = tn;
                    mi = 9;
                    break;
                default:
                    break;
                }
            }
          L1:
            Mangle m2 = cast(Mangle)ti.classinfo.name[mi];
            string  fmt;                        // format string
            wstring wfmt;
            dstring dfmt;

            /* For performance reasons, this code takes advantage of the
             * fact that most format strings will be ASCII, and that the
             * format specifiers are always ASCII. This means we only need
             * to deal with UTF in a couple of isolated spots.
             */

            switch (m2)
            {
            case Mangle.Tchar:
                fmt = va_arg!(string)(argptr);
                break;

            case Mangle.Twchar:
                wfmt = va_arg!(wstring)(argptr);
                fmt = toUTF8(wfmt);
                break;

            case Mangle.Tdchar:
                dfmt = va_arg!(dstring)(argptr);
                fmt = toUTF8(dfmt);
                break;

            case Mangle.Tconst:
            case Mangle.Timmutable:
                mi++;
                goto L1;

            default:
                formatArg('s');
                continue;
            }

            for (size_t i = 0; i < fmt.length; )
            {        dchar c = fmt[i++];

                dchar getFmtChar()
                {   // Valid format specifier characters will never be UTF
                    if (i == fmt.length)
                        throw new FormatException("invalid specifier");
                    return fmt[i++];
                }

                int getFmtInt()
                {   int n;

                    while (1)
                    {
                        n = n * 10 + (c - '0');
                        if (n < 0)        // overflow
                            throw new FormatException("int overflow");
                        c = getFmtChar();
                        if (c < '0' || c > '9')
                            break;
                    }
                    return n;
                }

                int getFmtStar()
                {   Mangle m;
                    TypeInfo ti;

                    if (j == arguments.length)
                        throw new FormatException("too few arguments");
                    ti = arguments[j++];
                    m = cast(Mangle)ti.classinfo.name[9];
                    if (m != Mangle.Tint)
                        throw new FormatException("int argument expected");
                    return va_arg!(int)(argptr);
                }

                if (c != '%')
                {
                    if (c > 0x7F)        // if UTF sequence
                    {
                        i--;                // back up and decode UTF sequence
                        c = std.utf.decode(fmt, i);
                    }
                  Lputc:
                    putc(c);
                    continue;
                }

                // Get flags {-+ #}
                flags = 0;
                while (1)
                {
                    c = getFmtChar();
                    switch (c)
                    {
                    case '-':        flags |= FLdash;        continue;
                    case '+':        flags |= FLplus;        continue;
                    case ' ':        flags |= FLspace;        continue;
                    case '#':        flags |= FLhash;        continue;
                    case '0':        flags |= FL0pad;        continue;

                    case '%':        if (flags == 0)
                                          goto Lputc;
                                     break;

                    default:         break;
                    }
                    break;
                }

                // Get field width
                field_width = 0;
                if (c == '*')
                {
                    field_width = getFmtStar();
                    if (field_width < 0)
                    {   flags |= FLdash;
                        field_width = -field_width;
                    }

                    c = getFmtChar();
                }
                else if (c >= '0' && c <= '9')
                    field_width = getFmtInt();

                if (flags & FLplus)
                    flags &= ~FLspace;
                if (flags & FLdash)
                    flags &= ~FL0pad;

                // Get precision
                precision = 0;
                if (c == '.')
                {   flags |= FLprecision;
                    //flags &= ~FL0pad;

                    c = getFmtChar();
                    if (c == '*')
                    {
                        precision = getFmtStar();
                        if (precision < 0)
                        {   precision = 0;
                            flags &= ~FLprecision;
                        }

                        c = getFmtChar();
                    }
                    else if (c >= '0' && c <= '9')
                        precision = getFmtInt();
                }

                if (j == arguments.length)
                    goto Lerror;
                ti = arguments[j++];
                ti = skipCI(ti);
                mi = 9;
                do
                {
                    m = cast(Mangle)ti.classinfo.name[mi++];
                } while (m == Mangle.Tconst || m == Mangle.Timmutable);

                if (c > 0x7F)                // if UTF sequence
                    goto Lerror;        // format specifiers can't be UTF
                formatArg(cast(char)c);
            }
        }
        else
        {
            formatArg('s');
        }
    }
    return;

  Lerror:
    throw new FormatException();
}

/* ======================== Unit Tests ====================================== */

unittest
{
    int i;
    string s;

    debug(format) printf("std.format.format.unittest\n");

    s = std.string.format("hello world! %s %s ", true, 57, 1_000_000_000, 'x', " foo");
    assert(s == "hello world! true 57 1000000000x foo");

    s = std.string.format(1.67, " %A ", -1.28, float.nan);
    /* The host C library is used to format floats.
     * C99 doesn't specify what the hex digit before the decimal point
     * is for %A.
     */
    version (linux)
        assert(s == "1.67 -0XA.3D70A3D70A3D8P-3 nan");
    else version (OSX)
        assert(s == "1.67 -0XA.3D70A3D70A3D8P-3 nan", s);
    else
        assert(s == "1.67 -0X1.47AE147AE147BP+0 nan");

    s = std.string.format("%x %X", 0x1234AF, 0xAFAFAFAF);
    assert(s == "1234af AFAFAFAF");

    s = std.string.format("%b %o", 0x1234AF, 0xAFAFAFAF);
    assert(s == "100100011010010101111 25753727657");

    s = std.string.format("%d %s", 0x1234AF, 0xAFAFAFAF);
    assert(s == "1193135 2947526575");

    version(X86_64)
    {
        pragma(msg, "several format tests disabled on x86_64 due to bug 5625");
    }
    else
    {
        s = std.string.format("%s", 1.2 + 3.4i);
        assert(s == "1.2+3.4i");

        s = std.string.format("%x %X", 1.32, 6.78f);
        assert(s == "3ff51eb851eb851f 40D8F5C3");

    }

    s = std.string.format("%#06.*f",2,12.345);
    assert(s == "012.35");

    s = std.string.format("%#0*.*f",6,2,12.345);
    assert(s == "012.35");

    s = std.string.format("%7.4g:", 12.678);
    assert(s == "  12.68:");

    s = std.string.format("%7.4g:", 12.678L);
    assert(s == "  12.68:");

    s = std.string.format("%04f|%05d|%#05x|%#5x",-4.,-10,1,1);
    assert(s == "-4.000000|-0010|0x001|  0x1");

    i = -10;
    s = std.string.format("%d|%3d|%03d|%1d|%01.4f",i,i,i,i,cast(double) i);
    assert(s == "-10|-10|-10|-10|-10.0000");

    i = -5;
    s = std.string.format("%d|%3d|%03d|%1d|%01.4f",i,i,i,i,cast(double) i);
    assert(s == "-5| -5|-05|-5|-5.0000");

    i = 0;
    s = std.string.format("%d|%3d|%03d|%1d|%01.4f",i,i,i,i,cast(double) i);
    assert(s == "0|  0|000|0|0.0000");

    i = 5;
    s = std.string.format("%d|%3d|%03d|%1d|%01.4f",i,i,i,i,cast(double) i);
    assert(s == "5|  5|005|5|5.0000");

    i = 10;
    s = std.string.format("%d|%3d|%03d|%1d|%01.4f",i,i,i,i,cast(double) i);
    assert(s == "10| 10|010|10|10.0000");

    s = std.string.format("%.0d", 0);
    assert(s == "");

    s = std.string.format("%.g", .34);
    assert(s == "0.3");

    s = std.string.format("%.0g", .34);
    assert(s == "0.3");

    s = std.string.format("%.2g", .34);
    assert(s == "0.34");

    s = std.string.format("%0.0008f", 1e-08);
    assert(s == "0.00000001");

    s = std.string.format("%0.0008f", 1e-05);
    assert(s == "0.00001000");

    s = "helloworld";
    string r;
    r = std.string.format("%.2s", s[0..5]);
    assert(r == "he");
    r = std.string.format("%.20s", s[0..5]);
    assert(r == "hello");
    r = std.string.format("%8s", s[0..5]);
    assert(r == "   hello");

    byte[] arrbyte = new byte[4];
    arrbyte[0] = 100;
    arrbyte[1] = -99;
    arrbyte[3] = 0;
    r = std.string.format(arrbyte);
    assert(r == "[100,-99,0,0]");

    ubyte[] arrubyte = new ubyte[4];
    arrubyte[0] = 100;
    arrubyte[1] = 200;
    arrubyte[3] = 0;
    r = std.string.format(arrubyte);
    assert(r == "[100,200,0,0]");

    short[] arrshort = new short[4];
    arrshort[0] = 100;
    arrshort[1] = -999;
    arrshort[3] = 0;
    r = std.string.format(arrshort);
    assert(r == "[100,-999,0,0]");
    r = std.string.format("%s",arrshort);
    assert(r == "[100,-999,0,0]");

    ushort[] arrushort = new ushort[4];
    arrushort[0] = 100;
    arrushort[1] = 20_000;
    arrushort[3] = 0;
    r = std.string.format(arrushort);
    assert(r == "[100,20000,0,0]");

    int[] arrint = new int[4];
    arrint[0] = 100;
    arrint[1] = -999;
    arrint[3] = 0;
    r = std.string.format(arrint);
    assert(r == "[100,-999,0,0]");
    r = std.string.format("%s",arrint);
    assert(r == "[100,-999,0,0]");

    long[] arrlong = new long[4];
    arrlong[0] = 100;
    arrlong[1] = -999;
    arrlong[3] = 0;
    r = std.string.format(arrlong);
    assert(r == "[100,-999,0,0]");
    r = std.string.format("%s",arrlong);
    assert(r == "[100,-999,0,0]");

    ulong[] arrulong = new ulong[4];
    arrulong[0] = 100;
    arrulong[1] = 999;
    arrulong[3] = 0;
    r = std.string.format(arrulong);
    assert(r == "[100,999,0,0]");

    string[] arr2 = new string[4];
    arr2[0] = "hello";
    arr2[1] = "world";
    arr2[3] = "foo";
    r = std.string.format(arr2);
    assert(r == "[hello,world,,foo]");

    r = std.string.format("%.8d", 7);
    assert(r == "00000007");
    r = std.string.format("%.8x", 10);
    assert(r == "0000000a");

    r = std.string.format("%-3d", 7);
    assert(r == "7  ");

    r = std.string.format("%*d", -3, 7);
    assert(r == "7  ");

    r = std.string.format("%.*d", -3, 7);
    assert(r == "7");

    //typedef int myint;
    //myint m = -7;
    //r = std.string.format(m);
    //assert(r == "-7");

    r = std.string.format("abc"c);
    assert(r == "abc");
    r = std.string.format("def"w);
    assert(r == "def");
    r = std.string.format("ghi"d);
    assert(r == "ghi");

    void* p = cast(void*)0xDEADBEEF;
    r = std.string.format(p);
    assert(r == "DEADBEEF");

    r = std.string.format("%#x", 0xabcd);
    assert(r == "0xabcd");
    r = std.string.format("%#X", 0xABCD);
    assert(r == "0XABCD");

    r = std.string.format("%#o", octal!12345);
    assert(r == "012345");
    r = std.string.format("%o", 9);
    assert(r == "11");

    r = std.string.format("%+d", 123);
    assert(r == "+123");
    r = std.string.format("%+d", -123);
    assert(r == "-123");
    r = std.string.format("% d", 123);
    assert(r == " 123");
    r = std.string.format("% d", -123);
    assert(r == "-123");

    r = std.string.format("%%");
    assert(r == "%");

    r = std.string.format("%d", true);
    assert(r == "1");
    r = std.string.format("%d", false);
    assert(r == "0");

    r = std.string.format("%d", 'a');
    assert(r == "97");
    wchar wc = 'a';
    r = std.string.format("%d", wc);
    assert(r == "97");
    dchar dc = 'a';
    r = std.string.format("%d", dc);
    assert(r == "97");

    byte b = byte.max;
    r = std.string.format("%x", b);
    assert(r == "7f");
    r = std.string.format("%x", ++b);
    assert(r == "80");
    r = std.string.format("%x", ++b);
    assert(r == "81");

    short sh = short.max;
    r = std.string.format("%x", sh);
    assert(r == "7fff");
    r = std.string.format("%x", ++sh);
    assert(r == "8000");
    r = std.string.format("%x", ++sh);
    assert(r == "8001");

    i = int.max;
    r = std.string.format("%x", i);
    assert(r == "7fffffff");
    r = std.string.format("%x", ++i);
    assert(r == "80000000");
    r = std.string.format("%x", ++i);
    assert(r == "80000001");

    r = std.string.format("%x", 10);
    assert(r == "a");
    r = std.string.format("%X", 10);
    assert(r == "A");
    r = std.string.format("%x", 15);
    assert(r == "f");
    r = std.string.format("%X", 15);
    assert(r == "F");

    Object c = null;
    r = std.string.format(c);
    assert(r == "null");

    enum TestEnum
    {
            Value1, Value2
    }
    r = std.string.format("%s", TestEnum.Value2);
    assert(r == "1");

    immutable(char[5])[int] aa = ([3:"hello", 4:"betty"]);
    r = std.string.format("%s", aa.values);
    assert(r == "[[h,e,l,l,o],[b,e,t,t,y]]");
    r = std.string.format("%s", aa);
    assert(r == "[3:[h,e,l,l,o],4:[b,e,t,t,y]]");

    static const dchar[] ds = ['a','b'];
    for (int j = 0; j < ds.length; ++j)
    {
        r = std.string.format(" %d", ds[j]);
        if (j == 0)
            assert(r == " 97");
        else
            assert(r == " 98");
    }

    r = std.string.format(">%14d<, ", 15, [1,2,3]);
    assert(r == ">            15<, [1,2,3]");

    assert(std.string.format("%8s", "bar") == "     bar");
    assert(std.string.format("%8s", "b\u00e9ll\u00f4") == "   b\u00e9ll\u00f4");
}

unittest
{
    // bugzilla 3479
    auto stream = appender!(char[])();
    formattedWrite(stream, "%2$.*1$d", 12, 10);
    assert(stream.data == "000000000010", stream.data);
}
