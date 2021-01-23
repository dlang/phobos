// Written in the D programming language.

/**
   This is a submodule of $(MREF std, format).
   It provides writing values to an OutputRange.

   Copyright: Copyright The D Language Foundation 2000-2013.

   License: $(HTTP boost.org/LICENSE_1_0.txt, Boost License 1.0).

   Authors: $(HTTP walterbright.com, Walter Bright), $(HTTP erdani.com,
   Andrei Alexandrescu), and Kenji Hara

   Source: $(PHOBOSSRC std/format/write.d)
 */
module std.format.write;

import std.format.tools;
import std.exception;
import std.range.primitives;
import std.traits;

/**********************************************************************
   Interprets variadic argument list `args`, formats them according
   to `fmt`, and sends the resulting characters to `w`. The
   encoding of the output is the same as `Char`. The type `Writer`
   must satisfy $(D $(REF isOutputRange, std,range,primitives)!(Writer, Char)).

   The variadic arguments are normally consumed in order. POSIX-style
   $(HTTP opengroup.org/onlinepubs/009695399/functions/printf.html,
   positional parameter syntax) is also supported. Each argument is
   formatted into a sequence of chars according to the format
   specification, and the characters are passed to `w`. As many
   arguments as specified in the format string are consumed and
   formatted. If there are fewer arguments than format specifiers, a
   `FormatException` is thrown. If there are more remaining arguments
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
   $(REF Appender!string, std,array) and $(REF LockingTextWriter, std,stdio).

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
    $(B '%') $(I Position) $(I Flags) $(I Width) $(I Separator) $(I Precision) $(I FormatChar)
    $(B '%$(LPAREN)') $(I FormatString) $(B '%$(RPAREN)')
    $(B '%-$(LPAREN)') $(I FormatString) $(B '%$(RPAREN)')
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
$(I Separator):
    $(I empty)
    $(B ',')
    $(B ',') $(B '?')
    $(B ',') $(B '*') $(B '?')
    $(B ',') $(I Integer) $(B '?')
    $(B ',') $(B '*')
    $(B ',') $(I Integer)
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
    $(B 's')|$(B 'c')|$(B 'b')|$(B 'd')|$(B 'o')|$(B 'x')|$(B 'X')|$(B 'e')|$(B 'E')|$(B 'f')|$(B 'F')|$(B 'g')|$(B 'G')|$(B 'a')|$(B 'A')|$(B '|')
)

    $(BOOKTABLE Flags affect formatting depending on the specifier as
    follows., $(TR $(TH Flag) $(TH Types&nbsp;affected) $(TH Semantics))

    $(TR $(TD $(B '-')) $(TD numeric, bool, null, char, string, enum, pointer) $(TD Left justify the result in
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

    $(TR $(TD $(B '0')) $(TD numeric) $(TD Use leading
    zeros to pad rather than spaces (except for the floating point
    values `nan` and `infinity`).  Ignore if there's a $(I
    Precision).))

    $(TR $(TD $(B ' ')) $(TD numeric) $(TD Prefix positive
    numbers in a signed conversion with a space.)))

    $(DL
        $(DT $(I Width))
        $(DD
        Only used for numeric, bool, null, char, string, enum and pointer types.
        Specifies the minimum field width.
        If the width is a $(B *), an additional argument of type $(B int),
        preceding the actual argument, is taken as the width.
        If the width is negative, it is as if the $(B -) was given
        as a $(I Flags) character.)

        $(DT $(I Precision))
        $(DD Gives the precision for numeric conversions.
        If the precision is a $(B *), an additional argument of type $(B int),
        preceding the actual argument, is taken as the precision.
        If it is negative, it is as if there was no $(I Precision) specifier.)

        $(DT $(I Separator))
        $(DD Inserts the separator symbols ',' every $(I X) digits, from right
        to left, into numeric values to increase readability.
        The fractional part of floating point values inserts the separator
        from left to right.
        Entering an integer after the ',' allows to specify $(I X).
        If a '*' is placed after the ',' then $(I X) is specified by an
        additional parameter to the format function.
        Adding a '?' after the ',' or $(I X) specifier allows to specify
        the separator character as an additional parameter.
        )

        $(DT $(I FormatChar))
        $(DD
        $(DL
            $(DT $(B 's'))
            $(DD The corresponding argument is formatted in a manner consistent
            with its type:
            $(DL
                $(DT $(B bool))
                $(DD The result is `"true"` or `"false"`.)
                $(DT integral types)
                $(DD The $(B %d) format is used.)
                $(DT floating point types)
                $(DD The $(B %g) format is used.)
                $(DT string types)
                $(DD The result is the string converted to UTF-8.
                A $(I Precision) specifies the maximum number of characters
                to use in the result.)
                $(DT structs)
                $(DD If the struct defines a $(B toString()) method the result is
                the string returned from this function. Otherwise the result is
                StructName(field<sub>0</sub>, field<sub>1</sub>, ...) where
                field<sub>n</sub> is the nth element formatted with the default
                format.)
                $(DT classes derived from $(B Object))
                $(DD The result is the string returned from the class instance's
                $(B .toString()) method.
                A $(I Precision) specifies the maximum number of characters
                to use in the result.)
                $(DT unions)
                $(DD If the union defines a $(B toString()) method the result is
                the string returned from this function. Otherwise the result is
                the name of the union, without its contents.)
                $(DT non-string static and dynamic arrays)
                $(DD The result is [s<sub>0</sub>, s<sub>1</sub>, ...]
                where s<sub>n</sub> is the nth element
                formatted with the default format.)
                $(DT associative arrays)
                $(DD The result is the equivalent of what the initializer
                would look like for the contents of the associative array,
                e.g.: ["red" : 10, "blue" : 20].)
            ))

            $(DT $(B 'c'))
            $(DD The corresponding argument must be a character type.)

            $(DT $(B 'b','d','o','x','X'))
            $(DD The corresponding argument must be an integral type
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
            result.)

            $(DT $(B 'e','E'))
            $(DD A floating point number is formatted as one digit before
            the decimal point, $(I Precision) digits after, the $(I FormatChar),
            &plusmn;, followed by at least a two digit exponent:
            $(I d.dddddd)e$(I &plusmn;dd).
            If there is no $(I Precision), six
            digits are generated after the decimal point.
            If the $(I Precision) is 0, no decimal point is generated.)

            $(DT $(B 'f','F'))
            $(DD A floating point number is formatted in decimal notation.
            The $(I Precision) specifies the number of digits generated
            after the decimal point. It defaults to six. At least one digit
            is generated before the decimal point. If the $(I Precision)
            is zero, no decimal point is generated.)

            $(DT $(B 'g','G'))
            $(DD A floating point number is formatted in either $(B e) or
            $(B f) format for $(B g); $(B E) or $(B F) format for
            $(B G).
            The $(B f) format is used if the exponent for an $(B e) format
            is greater than -5 and less than the $(I Precision).
            The $(I Precision) specifies the number of significant
            digits, and defaults to six.
            Trailing zeros are elided after the decimal point, if the fractional
            part is zero then no decimal point is generated.)

            $(DT $(B 'a','A'))
            $(DD A floating point number is formatted in hexadecimal
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
            $(I FormatChar) is upper case.)
        ))
    )

    Floating point NaN's are formatted as $(B nan) if the
    $(I FormatChar) is lower case, or $(B NAN) if upper.
    Floating point infinities are formatted as $(B inf) or
    $(B infinity) if the
    $(I FormatChar) is lower case, or $(B INF) or $(B INFINITY) if upper.

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
$(CONSOLE
My items are 1 2 3.
My items are 1, 2, 3.
)

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
$(CONSOLE
My items are -1-, -2-, -3-.
)

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
$(CONSOLE
1 2 3
4 5 6
7 8 9

[1 2 3
 4 5 6
 7 8 9]

[[1 2 3]
 [4 5 6]
 [7 8 9]]
)

    Inside a compound format specifier, strings and characters are escaped
    automatically. To avoid this behavior, add $(B '-') flag to
    `"%$(LPAREN)"`.
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
$(CONSOLE
My friends are ["John", "Nancy"].
My friends are "John", "Nancy".
My friends are John, Nancy.
)
 */
uint formattedWrite(alias fmt, Writer, A...)(auto ref Writer w, A args)
if (isSomeString!(typeof(fmt)))
{
    alias e = checkFormatException!(fmt, A);
    static assert(!e, e.msg);
    return .formattedWrite(w, fmt, args);
}

/// The format string can be checked at compile-time (see see $(REF_ALTTEXT format, format, std,format,tools) for details):
@safe pure unittest
{
    import std.array : appender;

    auto writer = appender!string();
    writer.formattedWrite!"%s is the ultimate %s."(42, "answer");
    assert(writer[] == "42 is the ultimate answer.");

    // Clear the writer
    writer = appender!string();
    writer.formattedWrite!"Date: %2$s %1$s"("October", 5);
    assert(writer[] == "Date: 5 October");
}

/// ditto
uint formattedWrite(Writer, Char, A...)(auto ref Writer w, const scope Char[] fmt, A args)
{
    import std.conv : text;

    auto spec = FormatSpec!Char(fmt);

    // Are we already done with formats? Then just dump each parameter in turn
    uint currentArg = 0;
    while (spec.writeUpToNextSpec(w))
    {
        if (currentArg == A.length && !spec.indexStart)
        {
            // leftover spec?
            enforceFmt(fmt.length == 0,
                text("Orphan format specifier: %", spec.spec));
            break;
        }

        if (spec.width == spec.DYNAMIC)
        {
            auto width = getNthInt!"integer width"(currentArg, args);
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
            assert(index > 0, "The index must be greater than zero");
            auto width = getNthInt!"integer width"(index - 1, args);
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
            auto precision = getNthInt!"integer precision"(currentArg, args);
            if (precision >= 0) spec.precision = precision;
            // else negative precision is same as no precision
            else spec.precision = spec.UNSPECIFIED;
            ++currentArg;
        }
        else if (spec.precision < 0)
        {
            // means: get precision as a positional parameter
            auto index = cast(uint) -spec.precision;
            assert(index > 0, "The precision must be greater than zero");
            auto precision = getNthInt!"integer precision"(index- 1, args);
            if (currentArg < index) currentArg = index;
            if (precision >= 0) spec.precision = precision;
            // else negative precision is same as no precision
            else spec.precision = spec.UNSPECIFIED;
        }

        if (spec.separators == spec.DYNAMIC)
        {
            auto separators = getNthInt!"separator digit width"(currentArg, args);
            spec.separators = separators;
            ++currentArg;
        }

        if (spec.separatorCharPos == spec.DYNAMIC)
        {
            auto separatorChar =
                getNth!("separator character", isSomeChar, dchar)(currentArg, args);
            spec.separatorChar = separatorChar;
            ++currentArg;
        }

        if (currentArg == A.length && !spec.indexStart)
        {
            // leftover spec?
            enforceFmt(fmt.length == 0,
                text("Orphan format specifier: %", spec.spec));
            break;
        }

        // Format an argument
        // This switch uses a static foreach to generate a jump table.
        // Currently `spec.indexStart` use the special value '0' to signal
        // we should use the current argument. An enhancement would be to
        // always store the index.
        size_t index = currentArg;
        if (spec.indexStart != 0)
            index = spec.indexStart - 1;
        else
            ++currentArg;
    SWITCH: switch (index)
        {
            foreach (i, Tunused; A)
            {
            case i:
                formatValue(w, args[i], spec);
                if (currentArg < spec.indexEnd)
                    currentArg = spec.indexEnd;
                // A little know feature of format is to format a range
                // of arguments, e.g. `%1:3$` will format the first 3
                // arguments. Since they have to be consecutive we can
                // just use explicit fallthrough to cover that case.
                if (i + 1 < spec.indexEnd)
                {
                    // You cannot goto case if the next case is the default
                    static if (i + 1 < A.length)
                        goto case;
                    else
                        goto default;
                }
                else
                    break SWITCH;
            }
        default:
            throw new FormatException(
                text("Positional specifier %", spec.indexStart, '$', spec.spec,
                     " index exceeds ", A.length));
        }
    }
    return currentArg;
}

///
@safe unittest
{
    import std.format;

    assert(format("%,d", 1000) == "1,000");
    assert(format("%,f", 1234567.891011) == "1,234,567.891011");
    assert(format("%,?d", '?', 1000) == "1?000");
    assert(format("%,1d", 1000) == "1,0,0,0", format("%,1d", 1000));
    assert(format("%,*d", 4, -12345) == "-1,2345");
    assert(format("%,*?d", 4, '_', -12345) == "-1_2345");
    assert(format("%,6?d", '_', -12345678) == "-12_345678");
    assert(format("%12,3.3f", 1234.5678) == "   1,234.568", "'" ~
            format("%12,3.3f", 1234.5678) ~ "'");
}

@safe pure unittest
{
    import std.array : appender;
    auto w = appender!string();
    formattedWrite(w, "%s %d", "@safe/pure", 42);
    assert(w.data == "@safe/pure 42");
}

@safe pure unittest
{
    char[20] buf;
    auto w = buf[];
    formattedWrite(w, "%s %d", "@safe/pure", 42);
    assert(buf[0 .. $ - w.length] == "@safe/pure 42");
}

// https://issues.dlang.org/show_bug.cgi?id=3479
@safe unittest
{
    import std.array;
    auto stream = appender!(char[])();
    formattedWrite(stream, "%2$.*1$d", 12, 10);
    assert(stream.data == "000000000010", stream.data);
}

// https://issues.dlang.org/show_bug.cgi?id=6893
@safe unittest
{
    import std.array;
    enum E : ulong { A, B, C }
    auto stream = appender!(char[])();
    formattedWrite(stream, "%s", E.C);
    assert(stream.data == "C");
}

// Fix for https://issues.dlang.org/show_bug.cgi?id=1591
private int getNthInt(string kind, A...)(uint index, A args)
{
    return getNth!(kind, isIntegral,int)(index, args);
}

private T getNth(string kind, alias Condition, T, A...)(uint index, A args)
{
    import std.conv : text, to;

    switch (index)
    {
        foreach (n, _; A)
        {
            case n:
                static if (Condition!(typeof(args[n])))
                {
                    return to!T(args[n]);
                }
                else
                {
                    throw new FormatException(
                        text(kind, " expected, not ", typeof(args[n]).stringof,
                            " for argument #", index + 1));
                }
        }
        default:
            throw new FormatException(
                text("Missing ", kind, " argument"));
    }
}

/**
 * Formats any value into `Char` accepting `OutputRange`, using the given `FormatSpec`.
 *
 * Aggregates:
 * `struct`, `union`, `class`, and `interface` are formatted by calling `toString`.
 *
 * `toString` should have one of the following signatures:
 *
 * ---
 * void toString(Writer, Char)(ref Writer w, scope const ref FormatSpec!Char fmt)
 * void toString(Writer)(ref Writer w)
 * string toString();
 * ---
 *
 * Where `Writer` is an $(REF_ALTTEXT output range, isOutputRange, std,range,primitives)
 * which accepts characters. The template type does not have to be called `Writer`.
 *
 * The following overloads are also accepted for legacy reasons or for use in virtual
 * functions. It's recommended that any new code forgo these overloads if possible for
 * speed and attribute acceptance reasons.
 *
 * ---
 * void toString(scope void delegate(const(char)[]) sink, const ref FormatSpec!char fmt);
 * void toString(scope void delegate(const(char)[]) sink, string fmt);
 * void toString(scope void delegate(const(char)[]) sink);
 * ---
 *
 * For the class objects which have input range interface,
 * $(UL
 *     $(LI If the instance `toString` has overridden `Object.toString`, it is used.)
 *     $(LI Otherwise, the objects are formatted as input range.)
 * )
 *
 * For the `struct` and `union` objects which does not have `toString`,
 * $(UL
 *     $(LI If they have range interface, formatted as input range.)
 *     $(LI Otherwise, they are formatted like `Type(field1, filed2, ...)`.)
 * )
 *
 * Otherwise, are formatted just as their type name.
 *
 * Params:
 *     w = The $(REF_ALTTEXT output range, isOutputRange, std,range,primitives) to write to.
 *     val = The value to write.
 *     f = The $(REF FormatSpec, std, format, tools) defining how to write the value.
 */
void formatValue(Writer, T, Char)(auto ref Writer w, auto ref T val, scope const ref FormatSpec!Char f)
{
    formatValueImpl(w, val, f);
}

/++
   The following code compares the use of `formatValue` and `formattedWrite`.
 +/
@safe pure unittest
{
    import std.array : appender;
    import std.format;

    auto writer1 = appender!string();
    writer1.formattedWrite("%08b", 42);

    auto writer2 = appender!string();
    auto f = singleSpec("%08b");
    writer2.formatValue(42, f);

    assert(writer1.data == writer2.data && writer1.data == "00101010");
}

/**
 * `bool`s are formatted as `"true"` or `"false"` with `%s` and as `1` or
 * `0` with integral-specific format specs.
 */
@safe pure unittest
{
    import std.array : appender;
    import std.format;

    auto w = appender!string();
    auto spec = singleSpec("%s");
    formatValue(w, true, spec);

    assert(w.data == "true");
}

/// `null` literal is formatted as `"null"`.
@safe pure unittest
{
    import std.array : appender;
    import std.format;

    auto w = appender!string();
    auto spec = singleSpec("%s");
    formatValue(w, null, spec);

    assert(w.data == "null");
}

/// Integrals are formatted like $(REF printf, core, stdc, stdio).
@safe pure unittest
{
    import std.array : appender;
    import std.format;

    auto w = appender!string();
    auto spec = singleSpec("%d");
    formatValue(w, 1337, spec);

    assert(w.data == "1337");
}

/// Floating-point values are formatted like $(REF printf, core, stdc, stdio)
@safe unittest
{
    import std.array : appender;
    import std.format;

    auto w = appender!string();
    auto spec = singleSpec("%.1f");
    formatValue(w, 1337.7, spec);

    assert(w.data == "1337.7");
}

/**
 * Individual characters (`char, `wchar`, or `dchar`) are formatted as
 * Unicode characters with `%s` and as integers with integral-specific format
 * specs.
 */
@safe pure unittest
{
    import std.array : appender;
    import std.format;

    auto w = appender!string();
    auto spec = singleSpec("%c");
    formatValue(w, 'a', spec);

    assert(w.data == "a");
}

/// Strings are formatted like $(REF printf, core, stdc, stdio)
@safe pure unittest
{
    import std.array : appender;
    import std.format;

    auto w = appender!string();
    auto spec = singleSpec("%s");
    formatValue(w, "hello", spec);

    assert(w.data == "hello");
}

/// Static-size arrays are formatted as dynamic arrays.
@safe pure unittest
{
    import std.array : appender;
    import std.format;

    auto w = appender!string();
    auto spec = singleSpec("%s");
    char[2] two = ['a', 'b'];
    formatValue(w, two, spec);

    assert(w.data == "ab");
}

/**
 * Dynamic arrays are formatted as input ranges.
 *
 * Specializations:
 *   $(UL
 *      $(LI `void[]` is formatted like `ubyte[]`.)
 *      $(LI Const array is converted to input range by removing its qualifier.)
 *   )
 */
@safe pure unittest
{
    import std.array : appender;
    import std.format;

    auto w = appender!string();
    auto spec = singleSpec("%s");
    auto two = [1, 2];
    formatValue(w, two, spec);

    assert(w.data == "[1, 2]");
}

/**
 * Associative arrays are formatted by using `':'` and `", "` as
 * separators, and enclosed by `'['` and `']'`.
 */
@safe pure unittest
{
    import std.array : appender;
    import std.format;

    auto w = appender!string();
    auto spec = singleSpec("%s");
    auto aa = ["H":"W"];
    formatValue(w, aa, spec);

    assert(w.data == "[\"H\":\"W\"]", w.data);
}

/// `enum`s are formatted like their base value
@safe pure unittest
{
    import std.array : appender;
    import std.format;

    auto w = appender!string();
    auto spec = singleSpec("%s");

    enum A { first, second, third }

    formatValue(w, A.second, spec);

    assert(w.data == "second");
}

/**
 * Formatting a struct by defining a method `toString`, which takes an output
 * range.
 *
 * It's recommended that any `toString` using $(REF_ALTTEXT output ranges, isOutputRange, std,range,primitives)
 * use $(REF put, std,range,primitives) rather than use the `put` method of the range
 * directly.
 */
@safe unittest
{
    import std.array : appender;
    import std.range.primitives;
    import std.format;

    static struct Point
    {
        int x, y;

        void toString(W)(ref W writer, scope const ref FormatSpec!char f)
        if (isOutputRange!(W, char))
        {
            // std.range.primitives.put
            put(writer, "(");
            formatValue(writer, x, f);
            put(writer, ",");
            formatValue(writer, y, f);
            put(writer, ")");
        }
    }

    auto w = appender!string();
    auto spec = singleSpec("%s");
    auto p = Point(16, 11);

    formatValue(w, p, spec);
    assert(w.data == "(16,11)");
}

/**
 * Another example of formatting a `struct` with a defined `toString`,
 * this time using the `scope delegate` method.
 *
 * $(RED This method is now discouraged for non-virtual functions).
 * If possible, please use the output range method instead.
 */
@safe unittest
{
    import std.format;

    static struct Point
    {
        int x, y;

        void toString(scope void delegate(scope const(char)[]) @safe sink,
                      scope const FormatSpec!char fmt) const
        {
            sink("(");
            sink.formatValue(x, fmt);
            sink(",");
            sink.formatValue(y, fmt);
            sink(")");
        }
    }

    auto p = Point(16,11);
    assert(format("%03d", p) == "(016,011)");
    assert(format("%02x", p) == "(10,0b)");
}

/// Pointers are formatted as hex integers.
@system pure unittest
{
    import std.array : appender;
    import std.format;

    auto w = appender!string();
    auto spec = singleSpec("%s");

    auto q = cast(void*) 0xFFEECCAA;
    formatValue(w, q, spec);

    assert(w.data == "FFEECCAA");
}

/// SIMD vectors are formatted as arrays.
@safe unittest
{
    import core.simd;
    import std.array : appender;
    import std.format;

    auto w = appender!string();
    auto spec = singleSpec("%s");

    static if (is(float4))
    {
        version (X86) {}
        else
        {
            float4 f4;
            f4.array[0] = 1;
            f4.array[1] = 2;
            f4.array[2] = 3;
            f4.array[3] = 4;

            formatValue(w, f4, spec);
            assert(w.data == "[1, 2, 3, 4]");
        }
    }
}

/// Delegates are formatted by `ReturnType delegate(Parameters) FunctionAttributes`
@safe unittest
{
    import std.conv : to;

    int i;

    int foo(short k) @nogc
    {
        return i + k;
    }

    @system int delegate(short) @nogc bar() nothrow pure
    {
        int* p = new int(1);
        i = *p;
        return &foo;
    }

    assert(to!string(&bar) == "int delegate(short) @nogc delegate() pure nothrow @system");
    assert(() @trusted { return bar()(3); }() == 4);
}

/*
    `bool`s are formatted as `"true"` or `"false"` with `%s` and as `1` or
    `0` with integral-specific format specs.
 */
private void formatValueImpl(Writer, T, Char)(auto ref Writer w, T obj, scope const ref FormatSpec!Char f)
if (is(BooleanTypeOf!T) && !is(T == enum) && !hasToString!(T, Char))
{
    BooleanTypeOf!T val = obj;

    if (f.spec == 's')
        writeAligned(w, val ? "true" : "false", f);
    else
        formatValueImpl(w, cast(int) val, f);
}

@safe pure unittest
{
    assertCTFEable!(
    {
        formatTest( false, "false" );
        formatTest( true,  "true"  );
    });
}
@system unittest
{
    class C1 { bool val; alias val this; this(bool v){ val = v; } }
    class C2 { bool val; alias val this; this(bool v){ val = v; }
               override string toString() const { return "C"; } }
    formatTest( new C1(false), "false" );
    formatTest( new C1(true),  "true" );
    formatTest( new C2(false), "C" );
    formatTest( new C2(true),  "C" );

    struct S1 { bool val; alias val this; }
    struct S2 { bool val; alias val this;
                string toString() const { return "S"; } }
    formatTest( S1(false), "false" );
    formatTest( S1(true),  "true"  );
    formatTest( S2(false), "S" );
    formatTest( S2(true),  "S" );
}

@safe pure unittest
{
    string t1 = format("[%6s] [%6s] [%-6s]", true, false, true);
    assert(t1 == "[  true] [ false] [true  ]");

    string t2 = format("[%3s] [%-2s]", true, false);
    assert(t2 == "[true] [false]");
}

/*
    `null` literal is formatted as `"null"`
*/
private void formatValueImpl(Writer, T, Char)(auto ref Writer w, T obj, scope const ref FormatSpec!Char f)
if (is(immutable T == immutable typeof(null)) && !is(T == enum) && !hasToString!(T, Char))
{
    const spec = f.spec;
    enforceFmt(spec == 's',
        "null literal cannot match %" ~ spec);

    writeAligned(w, "null", f);
}

@safe pure unittest
{
    assert(collectExceptionMsg!FormatException(format("%p", null)).back == 'p');

    assertCTFEable!(
    {
        formatTest( null, "null" );
    });
}

@safe pure unittest
{
    string t = format("[%6s] [%-6s]", null, null);
    assert(t == "[  null] [null  ]");
}

/*
    Integrals are formatted like $(REF printf, core, stdc, stdio).
*/
private void formatValueImpl(Writer, T, Char)(auto ref Writer w, T obj, scope const ref FormatSpec!Char f)
if (is(IntegralTypeOf!T) && !is(T == enum) && !hasToString!(T, Char))
{
    alias U = IntegralTypeOf!T;
    U val = obj;    // Extracting alias this may be impure/system/may-throw

    const spec = f.spec;
    if (spec == 'r')
    {
        // raw write, skip all else and write the thing
        auto raw = (ref val)@trusted{
            return (cast(const char*) &val)[0 .. val.sizeof];
        }(val);
        if (needToSwapEndianess(f))
        {
            foreach_reverse (c; raw)
                put(w, c);
        }
        else
        {
            foreach (c; raw)
                put(w, c);
        }
        return;
    }

    immutable uint base =
        spec == 'x' || spec == 'X' ? 16 :
        spec == 'o' ? 8 :
        spec == 'b' ? 2 :
        spec == 's' || spec == 'd' || spec == 'u' ? 10 :
        0;
    enforceFmt(base > 0,
        "incompatible format character for integral argument: %" ~ spec);

    // Forward on to formatIntegral to handle both U and const(U)
    // Saves duplication of code for both versions.
    static if (is(ucent) && (is(U == cent) || is(U == ucent)))
        alias C = U;
    else static if (isSigned!U)
        alias C = long;
    else
        alias C = ulong;
    formatIntegral(w, cast(C) val, f, base, Unsigned!U.max);
}

private void formatIntegral(Writer, T, Char)(ref Writer w, const(T) val, scope const ref FormatSpec!Char fs,
    uint base, ulong mask)
{
    T arg = val;

    immutable negative = (base == 10 && arg < 0);
    if (negative)
    {
        arg = -arg;
    }

    // All unsigned integral types should fit in ulong.
    static if (is(ucent) && is(typeof(arg) == ucent))
        formatUnsigned(w, (cast(ucent) arg) & mask, fs, base, negative);
    else
        formatUnsigned(w, (cast(ulong) arg) & mask, fs, base, negative);
}

private void formatUnsigned(Writer, T, Char)
(ref Writer w, T arg, scope const ref FormatSpec!Char fs, uint base, bool negative)
{
    /* Write string:
     *    leftpad prefix1 prefix2 zerofill digits rightpad
     */

    /* Convert arg to digits[].
     * Note that 0 becomes an empty digits[]
     */
    char[64] buffer = void; // 64 bits in base 2 at most
    char[] digits;
    if (arg < base && base <= 10 && arg)
    {
        // Most numbers are a single digit - avoid expensive divide
        buffer[0] = cast(char)(arg + '0');
        digits = buffer[0 .. 1];
    }
    else
    {
        size_t i = buffer.length;
        while (arg)
        {
            --i;
            char c = cast(char) (arg % base);
            arg /= base;
            if (c < 10)
                buffer[i] = cast(char)(c + '0');
            else
                buffer[i] = cast(char)(c + (fs.spec == 'x' ? 'a' - 10 : 'A' - 10));
        }
        digits = buffer[i .. $]; // got the digits without the sign
    }


    immutable precision = (fs.precision == fs.UNSPECIFIED) ? 1 : fs.precision;

    char padChar = 0;
    if (!fs.flDash)
    {
        padChar = (fs.flZero && fs.precision == fs.UNSPECIFIED) ? '0' : ' ';
    }

    // Compute prefix1 and prefix2
    char prefix1 = 0;
    char prefix2 = 0;
    if (base == 10)
    {
        if (negative)
            prefix1 = '-';
        else if (fs.flPlus)
            prefix1 = '+';
        else if (fs.flSpace)
            prefix1 = ' ';
    }
    else if (base == 16 && fs.flHash && digits.length)
    {
        prefix1 = '0';
        prefix2 = fs.spec == 'x' ? 'x' : 'X';
    }
    // adjust precision to print a '0' for octal if alternate format is on
    else if (base == 8 && fs.flHash &&
             (precision <= 1 || precision <= digits.length) && // too low precision
             digits.length > 0)
        prefix1 = '0';

    size_t zerofill = precision > digits.length ? precision - digits.length : 0;
    size_t leftpad = 0;
    size_t rightpad = 0;

    immutable prefixWidth = (prefix1 != 0) + (prefix2 != 0);
    size_t finalWidth, separatorsCount;
    if (fs.flSeparator != 0)
    {
        finalWidth = prefixWidth + digits.length + ((digits.length > 0) ? (digits.length - 1) / fs.separators : 0);
        if (finalWidth < fs.width)
            finalWidth = fs.width + (padChar == '0') * (((fs.width - prefixWidth) % (fs.separators + 1) == 0) ? 1 : 0);

        separatorsCount = (padChar == '0') ? (finalWidth - prefixWidth - 1) / (fs.separators + 1) :
                         ((digits.length > 0) ? (digits.length - 1) / fs.separators : 0);
    }
    else
    {
        import std.algorithm.comparison : max;
        finalWidth = max(fs.width, prefixWidth + digits.length);
    }

    immutable ptrdiff_t spacesToPrint =
        finalWidth - (
            + prefixWidth
            + zerofill
            + digits.length
            + separatorsCount
        );
    if (spacesToPrint > 0) // need to do some padding
    {
        if (padChar == '0')
            zerofill += spacesToPrint;
        else if (padChar)
            leftpad = spacesToPrint;
        else
            rightpad = spacesToPrint;
    }

    // Print
    foreach (i ; 0 .. leftpad)
        put(w, ' ');

    if (prefix1) put(w, prefix1);
    if (prefix2) put(w, prefix2);

    if (fs.flSeparator)
    {
        if (zerofill > 0)
        {
            put(w, '0');
            --zerofill;
        }

        int j = cast(int) (finalWidth - prefixWidth - separatorsCount - 1);
        for (size_t i = 0; i < zerofill; ++i, --j)
        {
            if (j % fs.separators == 0)
            {
                put(w, fs.separatorChar);
            }
            put(w, '0');
        }
    }
    else
    {
        foreach (i ; 0 .. zerofill)
            put(w, '0');
    }

    if (fs.flSeparator)
    {
        for (size_t j = 0; j < digits.length; ++j)
        {
            if (((j != 0) || ((spacesToPrint > 0) && (padChar == '0'))) && (digits.length - j) % fs.separators == 0)
            {
                put(w, fs.separatorChar);
            }
            put(w, digits[j]);
        }
    }
    else
    {
        put(w, digits);
    }

    foreach (i ; 0 .. rightpad)
        put(w, ' ');
}

// https://issues.dlang.org/show_bug.cgi?id=18838
@safe pure unittest
{
    assert("%12,d".format(0) == "           0");
}

@safe pure unittest
{
    assert(collectExceptionMsg!FormatException(format("%c", 5)).back == 'c');

    assertCTFEable!(
    {
        formatTest(9, "9");
        formatTest( 10, "10" );
    });
}

@system unittest
{
    class C1 { long val; alias val this; this(long v){ val = v; } }
    class C2 { long val; alias val this; this(long v){ val = v; }
               override string toString() const { return "C"; } }
    formatTest( new C1(10), "10" );
    formatTest( new C2(10), "C" );

    struct S1 { long val; alias val this; }
    struct S2 { long val; alias val this;
                string toString() const { return "S"; } }
    formatTest( S1(10), "10" );
    formatTest( S2(10), "S" );
}

// https://issues.dlang.org/show_bug.cgi?id=9117
@safe unittest
{
    static struct Frop {}

    static struct Foo
    {
        int n = 0;
        alias n this;
        T opCast(T) () if (is(T == Frop))
        {
            return Frop();
        }
        string toString()
        {
            return "Foo";
        }
    }

    static struct Bar
    {
        Foo foo;
        alias foo this;
        string toString()
        {
            return "Bar";
        }
    }

    const(char)[] result;
    void put(scope const char[] s){ result ~= s; }

    Foo foo;
    formattedWrite(&put, "%s", foo);    // OK
    assert(result == "Foo");

    result = null;

    Bar bar;
    formattedWrite(&put, "%s", bar);    // NG
    assert(result == "Bar");

    result = null;

    int i = 9;
    formattedWrite(&put, "%s", 9);
    assert(result == "9");
}

// https://issues.dlang.org/show_bug.cgi?id=20064
@safe unittest
{
    assert(format( "%03,d",  1234) ==              "1,234");
    assert(format( "%04,d",  1234) ==              "1,234");
    assert(format( "%05,d",  1234) ==              "1,234");
    assert(format( "%06,d",  1234) ==             "01,234");
    assert(format( "%07,d",  1234) ==            "001,234");
    assert(format( "%08,d",  1234) ==          "0,001,234");
    assert(format( "%09,d",  1234) ==          "0,001,234");
    assert(format("%010,d",  1234) ==         "00,001,234");
    assert(format("%011,d",  1234) ==        "000,001,234");
    assert(format("%012,d",  1234) ==      "0,000,001,234");
    assert(format("%013,d",  1234) ==      "0,000,001,234");
    assert(format("%014,d",  1234) ==     "00,000,001,234");
    assert(format("%015,d",  1234) ==    "000,000,001,234");
    assert(format("%016,d",  1234) ==  "0,000,000,001,234");
    assert(format("%017,d",  1234) ==  "0,000,000,001,234");

    assert(format( "%03,d", -1234) ==             "-1,234");
    assert(format( "%04,d", -1234) ==             "-1,234");
    assert(format( "%05,d", -1234) ==             "-1,234");
    assert(format( "%06,d", -1234) ==             "-1,234");
    assert(format( "%07,d", -1234) ==            "-01,234");
    assert(format( "%08,d", -1234) ==           "-001,234");
    assert(format( "%09,d", -1234) ==         "-0,001,234");
    assert(format("%010,d", -1234) ==         "-0,001,234");
    assert(format("%011,d", -1234) ==        "-00,001,234");
    assert(format("%012,d", -1234) ==       "-000,001,234");
    assert(format("%013,d", -1234) ==     "-0,000,001,234");
    assert(format("%014,d", -1234) ==     "-0,000,001,234");
    assert(format("%015,d", -1234) ==    "-00,000,001,234");
    assert(format("%016,d", -1234) ==   "-000,000,001,234");
    assert(format("%017,d", -1234) == "-0,000,000,001,234");
}

@safe pure unittest
{
    string t1 = format("[%6s] [%-6s]", 123, 123);
    assert(t1 == "[   123] [123   ]");

    string t2 = format("[%6s] [%-6s]", -123, -123);
    assert(t2 == "[  -123] [-123  ]");
}

package enum RoundingMode { up, down, toZero, toNearestTiesToEven, toNearestTiesAwayFromZero }

/*
    Floating-point values are formatted like $(REF printf, core, stdc, stdio)
 */
private void formatValueImpl(Writer, T, Char)(auto ref Writer w, T obj, scope const ref FormatSpec!Char f)
if (is(FloatingPointTypeOf!T) && !is(T == enum) && !hasToString!(T, Char))
{
    import std.algorithm.comparison : min;
    import std.algorithm.searching : find;
    import std.string : indexOf, indexOfAny, indexOfNeither;
    import std.math : isInfinity, isNaN, signbit;
    import std.ascii : isUpper;

    string nanInfStr(scope const ref FormatSpec!Char f, const bool nan,
            const bool inf, const int sb, const bool up) @safe pure nothrow
    {
        return nan
            ? up
                ? sb ? "-NAN" : f.flPlus ? "+NAN" : (f.flSpace ? " NAN" : "NAN")
                : sb ? "-nan" : f.flPlus ? "+nan" : (f.flSpace ? " nan" : "nan")
            : inf
                ? up
                    ? sb ? "-INF" : f.flPlus ? "+INF" : (f.flSpace ? " INF" : "INF")
                    : sb ? "-inf" : f.flPlus ? "+inf" : (f.flSpace ? " inf" : "inf")
                : "";
    }

    FloatingPointTypeOf!T val = obj;
    const char spec = f.spec;

    if (spec == 'r')
    {
        // raw write, skip all else and write the thing
        auto raw = (ref val)@trusted{
            return (cast(const char*) &val)[0 .. val.sizeof];
        }(val);
        if (needToSwapEndianess(f))
        {
            foreach_reverse (c; raw)
                put(w, c);
        }
        else
        {
            foreach (c; raw)
                put(w, c);
        }
        return;
    }
    enforceFmt(find("fgFGaAeEs", spec).length,
        "incompatible format character for floating point argument: %" ~ spec);
    enforceFmt(!__ctfe, ctfpMessage);

    FormatSpec!Char fs = f; // fs is copy for change its values.
    const spec2 = spec == 's' ? 'g' : spec;

    version (CRuntime_Microsoft)
    {
        // convert early to get "inf" in case of overflow
        // windows handels inf and nan strange
        // https://devblogs.microsoft.com/oldnewthing/20130228-01/?p=5103
        immutable double tval = val;
    }
    else
    {
        alias tval = val;
    }

    const nan = isNaN(tval);
    const inf = isInfinity(tval);

    char[512] buf2 = void;
    size_t len;
    char[] buf;
    if (fs.spec=='a' || fs.spec=='A' || fs.spec=='e' || fs.spec=='E')
    {
        static if (is(T == float) || is(T == double) || (is(T == real) && T.mant_dig == double.mant_dig))
        {
            import std.math;

            auto mode = RoundingMode.toNearestTiesToEven;

            // std.math's FloatingPointControl isn't available on all target platforms
            static if (is(FloatingPointControl))
            {
                switch (FloatingPointControl.rounding)
                {
                case FloatingPointControl.roundUp:
                    mode = RoundingMode.up;
                    break;
                case FloatingPointControl.roundDown:
                    mode = RoundingMode.down;
                    break;
                case FloatingPointControl.roundToZero:
                    mode = RoundingMode.toZero;
                    break;
                case FloatingPointControl.roundToNearest:
                    mode = RoundingMode.toNearestTiesToEven;
                    break;
                default: assert(false);
                }
            }

            import std.format.floats : printFloat;

            buf = printFloat(buf2[], val, fs, mode);
            len = buf.length;
        }
        else
            goto useSnprintf;
    }
    else
    {
useSnprintf:
        if (nan || inf)
        {
            const sb = signbit(tval);
            const up = isUpper(spec);
            string ns = nanInfStr(f, nan, inf, sb, up);
            FormatSpec!Char co;
            co.spec = 's';
            co.width = f.width;
            co.flDash = f.flDash;
            formatValue(w, ns, co);
            return;
        }

        char[1 /*%*/ + 5 /*flags*/ + 3 /*width.prec*/ + 2 /*format*/
             + 1 /*\0*/] sprintfSpec = void;
        sprintfSpec[0] = '%';
        uint i = 1;
        if (fs.flDash) sprintfSpec[i++] = '-';
        if (fs.flPlus) sprintfSpec[i++] = '+';
        if (fs.flZero) sprintfSpec[i++] = '0';
        if (fs.flSpace) sprintfSpec[i++] = ' ';
        if (fs.flHash) sprintfSpec[i++] = '#';
        sprintfSpec[i .. i + 3] = "*.*";
        i += 3;
        if (is(immutable typeof(val) == immutable real)) sprintfSpec[i++] = 'L';
        sprintfSpec[i++] = spec2;
        sprintfSpec[i] = 0;
        //printf("format: '%s'; geeba: %g\n", sprintfSpec.ptr, val);

        //writefln("'%s'", sprintfSpec[0 .. i]);

        immutable n = ()@trusted{
            import core.stdc.stdio : snprintf;
            return snprintf(buf2.ptr, buf2.length,
                            sprintfSpec.ptr,
                            fs.width,
                            // negative precision is same as no precision specified
                            fs.precision == fs.UNSPECIFIED ? -1 : fs.precision,
                            tval);
        }();

        enforceFmt(n >= 0,
                   "floating point formatting failure");

        len = min(n, buf2.length-1);
        buf = buf2;
    }

    if (fs.flSeparator && !inf && !nan)
    {
        ptrdiff_t indexOfRemovable()
        {
            if (len < 2)
                return -1;

            size_t start = (buf[0 .. 1].indexOfAny(" 0123456789") == -1) ? 1 : 0;
            if (len < 2 + start)
                return -1;
            if ((buf[start] == ' ') || (buf[start] == '0' && buf[start + 1] != '.'))
                return start;

            return -1;
        }

        ptrdiff_t dot, firstDigit, ePos, dotIdx, firstLen;
        size_t separatorScoreCnt;

        while (true)
        {
            dot = buf[0 .. len].indexOf('.');
            firstDigit = buf[0 .. len].indexOfAny("0123456789");
            ePos = buf[0 .. len].indexOf('e');
            dotIdx = dot == -1 ? ePos == -1 ? len : ePos : dot;

            firstLen = dotIdx - firstDigit;
            separatorScoreCnt = (firstLen > 0) ? (firstLen - 1) / fs.separators : 0;

            ptrdiff_t removableIdx = (len + separatorScoreCnt > fs.width) ? indexOfRemovable() : -1;
            if ((removableIdx != -1) &&
                ((firstLen - (buf[removableIdx] == '0' ? 2 : 1)) / fs.separators + len - 1 >= fs.width))
            {
                buf[removableIdx .. $ - 1] = buf.dup[removableIdx + 1 .. $];
                len--;
            }
            else
                break;
        }

        immutable afterDotIdx = (ePos != -1) ? ePos : len;

        // plus, minus, prefix
        if (firstDigit > 0)
        {
            put(w, buf[0 .. firstDigit]);
        }

        // digits until dot with separator
        for (auto j = 0; j < firstLen; ++j)
        {
            if (j > 0 && (firstLen - j) % fs.separators == 0)
            {
                put(w, fs.separatorChar);
            }
            put(w, buf[j + firstDigit]);
        }

        // print dot for decimal numbers only or with '#' format specifier
        if (dot != -1 || fs.flHash)
        {
            put(w, '.');
        }

        // digits after dot
        for (auto j = dotIdx + 1; j < afterDotIdx; ++j)
        {
            put(w, buf[j]);
        }

        // rest
        if (ePos != -1)
        {
            put(w, buf[afterDotIdx .. len]);
        }
    }
    else
    {
        put(w, buf[0 .. len]);
    }
}

@safe unittest
{
    assert(format("%.1f", 1337.7) == "1337.7");
    assert(format("%,3.2f", 1331.982) == "1,331.98");
    assert(format("%,3.0f", 1303.1982) == "1,303");
    assert(format("%#,3.4f", 1303.1982) == "1,303.1982");
    assert(format("%#,3.0f", 1303.1982) == "1,303.");
}

@safe /*pure*/ unittest     // formatting floating point values is now impure
{
    import std.conv : to;
    import std.meta : AliasSeq;

    assert(collectExceptionMsg!FormatException(format("%d", 5.1)).back == 'd');

    static foreach (T; AliasSeq!(float, double, real))
    {
        formatTest( to!(          T)(5.5), "5.5" );
        formatTest( to!(    const T)(5.5), "5.5" );
        formatTest( to!(immutable T)(5.5), "5.5" );

        formatTest( T.nan, "nan" );
    }
}

@system unittest
{
    formatTest( 2.25, "2.25" );

    class C1 { double val; alias val this; this(double v){ val = v; } }
    class C2 { double val; alias val this; this(double v){ val = v; }
               override string toString() const { return "C"; } }
    formatTest( new C1(2.25), "2.25" );
    formatTest( new C2(2.25), "C" );

    struct S1 { double val; alias val this; }
    struct S2 { double val; alias val this;
                string toString() const { return "S"; } }
    formatTest( S1(2.25), "2.25" );
    formatTest( S2(2.25), "S" );
}

// https://issues.dlang.org/show_bug.cgi?id=19939
@safe unittest
{
    assert(format("^%13,3.2f$",          1.00) == "^         1.00$");
    assert(format("^%13,3.2f$",         10.00) == "^        10.00$");
    assert(format("^%13,3.2f$",        100.00) == "^       100.00$");
    assert(format("^%13,3.2f$",      1_000.00) == "^     1,000.00$");
    assert(format("^%13,3.2f$",     10_000.00) == "^    10,000.00$");
    assert(format("^%13,3.2f$",    100_000.00) == "^   100,000.00$");
    assert(format("^%13,3.2f$",  1_000_000.00) == "^ 1,000,000.00$");
    assert(format("^%13,3.2f$", 10_000_000.00) == "^10,000,000.00$");
}

// https://issues.dlang.org/show_bug.cgi?id=20069
@safe unittest
{
    assert(format("%012,f",   -1234.0) ==    "-1,234.000000");
    assert(format("%013,f",   -1234.0) ==    "-1,234.000000");
    assert(format("%014,f",   -1234.0) ==   "-01,234.000000");
    assert(format("%011,f",    1234.0) ==     "1,234.000000");
    assert(format("%012,f",    1234.0) ==     "1,234.000000");
    assert(format("%013,f",    1234.0) ==    "01,234.000000");
    assert(format("%014,f",    1234.0) ==   "001,234.000000");
    assert(format("%015,f",    1234.0) == "0,001,234.000000");
    assert(format("%016,f",    1234.0) == "0,001,234.000000");

    assert(format( "%08,.2f", -1234.0) ==        "-1,234.00");
    assert(format( "%09,.2f", -1234.0) ==        "-1,234.00");
    assert(format("%010,.2f", -1234.0) ==       "-01,234.00");
    assert(format("%011,.2f", -1234.0) ==      "-001,234.00");
    assert(format("%012,.2f", -1234.0) ==    "-0,001,234.00");
    assert(format("%013,.2f", -1234.0) ==    "-0,001,234.00");
    assert(format("%014,.2f", -1234.0) ==   "-00,001,234.00");
    assert(format( "%08,.2f",  1234.0) ==         "1,234.00");
    assert(format( "%09,.2f",  1234.0) ==        "01,234.00");
    assert(format("%010,.2f",  1234.0) ==       "001,234.00");
    assert(format("%011,.2f",  1234.0) ==     "0,001,234.00");
    assert(format("%012,.2f",  1234.0) ==     "0,001,234.00");
    assert(format("%013,.2f",  1234.0) ==    "00,001,234.00");
    assert(format("%014,.2f",  1234.0) ==   "000,001,234.00");
    assert(format("%015,.2f",  1234.0) == "0,000,001,234.00");
    assert(format("%016,.2f",  1234.0) == "0,000,001,234.00");
}

@safe unittest
{
    string t1 = format("[%6s] [%-6s]", 12.3, 12.3);
    assert(t1 == "[  12.3] [12.3  ]");

    string t2 = format("[%6s] [%-6s]", -12.3, -12.3);
    assert(t2 == "[ -12.3] [-12.3 ]");
}

// https://issues.dlang.org/show_bug.cgi?id=20396
@safe unittest
{
    import std.math : nextUp;

    assert(format!"%a"(nextUp(0.0f)) == "0x0.000002p-126");
    assert(format!"%a"(nextUp(0.0)) == "0x0.0000000000001p-1022");
}

// https://issues.dlang.org/show_bug.cgi?id=20371
@safe unittest
{
    assert(format!"%.1000a"(1.0) ==
           "0x1.000000000000000000000000000000000000000000000000000000000000000000000000000"
           ~"000000000000000000000000000000000000000000000000000000000000000000000000000000"
           ~"000000000000000000000000000000000000000000000000000000000000000000000000000000"
           ~"000000000000000000000000000000000000000000000000000000000000000000000000000000"
           ~"000000000000000000000000000000000000000000000000000000000000000000000000000000"
           ~"000000000000000000000000000000000000000000000000000000000000000000000000000000"
           ~"000000000000000000000000000000000000000000000000000000000000000000000000000000"
           ~"000000000000000000000000000000000000000000000000000000000000000000000000000000"
           ~"000000000000000000000000000000000000000000000000000000000000000000000000000000"
           ~"000000000000000000000000000000000000000000000000000000000000000000000000000000"
           ~"000000000000000000000000000000000000000000000000000000000000000000000000000000"
           ~"000000000000000000000000000000000000000000000000000000000000000000000000000000"
           ~"0000000000000000000000000000000000000000000000000000000000000000000p+0");
}

/*
    Formatting a `creal` is deprecated but still kept around for a while.
 */
deprecated("Use of complex types is deprecated. Use std.complex")
private void formatValueImpl(Writer, T, Char)(auto ref Writer w, T obj, scope const ref FormatSpec!Char f)
if (is(immutable T : immutable creal) && !is(T == enum) && !hasToString!(T, Char))
{
    immutable creal val = obj;

    formatValueImpl(w, val.re, f);
    if (val.im >= 0)
    {
        put(w, '+');
    }
    formatValueImpl(w, val.im, f);
    put(w, 'i');
}

version (TestComplex)
deprecated
@safe /*pure*/ unittest     // formatting floating point values is now impure
{
    import std.conv : to;
    import std.meta : AliasSeq;

    static foreach (T; AliasSeq!(cfloat, cdouble, creal))
    {
        formatTest( to!(          T)(1 + 1i), "1+1i" );
        formatTest( to!(    const T)(1 + 1i), "1+1i" );
        formatTest( to!(immutable T)(1 + 1i), "1+1i" );
    }
    static foreach (T; AliasSeq!(cfloat, cdouble, creal))
    {
        formatTest( to!(          T)(0 - 3i), "0-3i" );
        formatTest( to!(    const T)(0 - 3i), "0-3i" );
        formatTest( to!(immutable T)(0 - 3i), "0-3i" );
    }
}

version (TestComplex)
deprecated
@system unittest
{
    formatTest( 3+2.25i, "3+2.25i" );

    class C1 { cdouble val; alias val this; this(cdouble v){ val = v; } }
    class C2 { cdouble val; alias val this; this(cdouble v){ val = v; }
               override string toString() const { return "C"; } }
    formatTest( new C1(3+2.25i), "3+2.25i" );
    formatTest( new C2(3+2.25i), "C" );

    struct S1 { cdouble val; alias val this; }
    struct S2 { cdouble val; alias val this;
                string toString() const { return "S"; } }
    formatTest( S1(3+2.25i), "3+2.25i" );
    formatTest( S2(3+2.25i), "S" );
}

/*
    Formatting an `ireal` is deprecated but still kept around for a while.
 */
deprecated("Use of imaginary types is deprecated. Use std.complex")
private void formatValueImpl(Writer, T, Char)(auto ref Writer w, T obj, scope const ref FormatSpec!Char f)
if (is(immutable T : immutable ireal) && !is(T == enum) && !hasToString!(T, Char))
{
    immutable ireal val = obj;

    formatValueImpl(w, val.im, f);
    put(w, 'i');
}

version (TestComplex)
deprecated
@safe /*pure*/ unittest     // formatting floating point values is now impure
{
    import std.conv : to;
    import std.meta : AliasSeq;

    static foreach (T; AliasSeq!(ifloat, idouble, ireal))
    {
        formatTest( to!(          T)(1i), "1i" );
        formatTest( to!(    const T)(1i), "1i" );
        formatTest( to!(immutable T)(1i), "1i" );
    }
}

version (TestComplex)
deprecated
@system unittest
{
    formatTest( 2.25i, "2.25i" );

    class C1 { idouble val; alias val this; this(idouble v){ val = v; } }
    class C2 { idouble val; alias val this; this(idouble v){ val = v; }
               override string toString() const { return "C"; } }
    formatTest( new C1(2.25i), "2.25i" );
    formatTest( new C2(2.25i), "C" );

    struct S1 { idouble val; alias val this; }
    struct S2 { idouble val; alias val this;
                string toString() const { return "S"; } }
    formatTest( S1(2.25i), "2.25i" );
    formatTest( S2(2.25i), "S" );
}

/*
    Individual characters are formatted as Unicode characters with `%s`
    and as integers with integral-specific format specs
 */
private void formatValueImpl(Writer, T, Char)(auto ref Writer w, T obj, scope const ref FormatSpec!Char f)
if (is(CharTypeOf!T) && !is(T == enum) && !hasToString!(T, Char))
{
    import std.meta : AliasSeq;

    CharTypeOf!T[1] val = obj;

    if (f.spec == 's' || f.spec == 'c')
        writeAligned(w, val[], f);
    else
    {
        alias U = AliasSeq!(ubyte, ushort, uint)[CharTypeOf!T.sizeof/2];
        formatValueImpl(w, cast(U) val[0], f);
    }
}

@safe pure unittest
{
    assertCTFEable!(
    {
        formatTest( 'c', "c" );
    });
}

@system unittest
{
    class C1 { char val; alias val this; this(char v){ val = v; } }
    class C2 { char val; alias val this; this(char v){ val = v; }
               override string toString() const { return "C"; } }
    formatTest( new C1('c'), "c" );
    formatTest( new C2('c'), "C" );

    struct S1 { char val; alias val this; }
    struct S2 { char val; alias val this;
                string toString() const { return "S"; } }
    formatTest( S1('c'), "c" );
    formatTest( S2('c'), "S" );
}

@safe unittest
{
    //Little Endian
    formatTest( "%-r", cast( char)'c', ['c'         ] );
    formatTest( "%-r", cast(wchar)'c', ['c', 0      ] );
    formatTest( "%-r", cast(dchar)'c', ['c', 0, 0, 0] );
    formatTest( "%-r", '本', ['\x2c', '\x67'] );

    //Big Endian
    formatTest( "%+r", cast( char)'c', [         'c'] );
    formatTest( "%+r", cast(wchar)'c', [0,       'c'] );
    formatTest( "%+r", cast(dchar)'c', [0, 0, 0, 'c'] );
    formatTest( "%+r", '本', ['\x67', '\x2c'] );
}


@safe pure unittest
{
    string t1 = format("[%6s] [%-6s]", 'A', 'A');
    assert(t1 == "[     A] [A     ]");
    string t2 = format("[%6s] [%-6s]", '本', '本');
    assert(t2 == "[     本] [本     ]");
}

/*
    Strings are formatted like $(REF printf, core, stdc, stdio)
 */
private void formatValueImpl(Writer, T, Char)(auto ref Writer w, scope T obj, scope const ref FormatSpec!Char f)
if (is(StringTypeOf!T) && !is(StaticArrayTypeOf!T) && !is(T == enum) && !hasToString!(T, Char))
{
    Unqual!(StringTypeOf!T) val = obj;  // for `alias this`, see bug5371
    formatRange(w, val, f);
}

@safe unittest
{
    formatTest( "abc", "abc" );
}

@system unittest
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

@system unittest
{
    class  C3 { string val; alias val this; this(string s){ val = s; }
                override string toString() const { return "C"; } }
    formatTest( new C3("c3"), "C" );

    struct S3 { string val; alias val this;
                string toString() const { return "S"; } }
    formatTest( S3("s3"), "S" );
}

@safe pure unittest
{
    //Little Endian
    formatTest( "%-r", "ab"c, ['a'         , 'b'         ] );
    formatTest( "%-r", "ab"w, ['a', 0      , 'b', 0      ] );
    formatTest( "%-r", "ab"d, ['a', 0, 0, 0, 'b', 0, 0, 0] );
    formatTest( "%-r", "日本語"c, ['\xe6', '\x97', '\xa5', '\xe6', '\x9c', '\xac', '\xe8', '\xaa', '\x9e'] );
    formatTest( "%-r", "日本語"w, ['\xe5', '\x65', '\x2c', '\x67', '\x9e', '\x8a']);
    formatTest( "%-r", "日本語"d, ['\xe5', '\x65', '\x00', '\x00', '\x2c', '\x67',
        '\x00', '\x00', '\x9e', '\x8a', '\x00', '\x00'] );

    //Big Endian
    formatTest( "%+r", "ab"c, [         'a',          'b'] );
    formatTest( "%+r", "ab"w, [      0, 'a',       0, 'b'] );
    formatTest( "%+r", "ab"d, [0, 0, 0, 'a', 0, 0, 0, 'b'] );
    formatTest( "%+r", "日本語"c, ['\xe6', '\x97', '\xa5', '\xe6', '\x9c', '\xac', '\xe8', '\xaa', '\x9e'] );
    formatTest( "%+r", "日本語"w, ['\x65', '\xe5', '\x67', '\x2c', '\x8a', '\x9e'] );
    formatTest( "%+r", "日本語"d, ['\x00', '\x00', '\x65', '\xe5', '\x00', '\x00',
        '\x67', '\x2c', '\x00', '\x00', '\x8a', '\x9e'] );
}

@safe pure unittest
{
    string t1 = format("[%6s] [%-6s]", "AB", "AB");
    assert(t1 == "[    AB] [AB    ]");
    string t2 = format("[%6s] [%-6s]", "本Ä", "本Ä");
    assert(t2 == "[    本Ä] [本Ä    ]");
}

/*
    Static-size arrays are formatted as dynamic arrays.
 */
private void formatValueImpl(Writer, T, Char)(auto ref Writer w, auto ref T obj, scope const ref FormatSpec!Char f)
if (is(StaticArrayTypeOf!T) && !is(T == enum) && !hasToString!(T, Char))
{
    formatValueImpl(w, obj[], f);
}

// Test for https://issues.dlang.org/show_bug.cgi?id=8310
@safe unittest
{
    import std.array : appender;
    FormatSpec!char f;
    auto w = appender!string();

    char[2] two = ['a', 'b'];
    formatValue(w, two, f);

    char[2] getTwo(){ return two; }
    formatValue(w, getTwo(), f);
}

/*
    Dynamic arrays are formatted as input ranges.
 */
private void formatValueImpl(Writer, T, Char)(auto ref Writer w, T obj, scope const ref FormatSpec!Char f)
if (is(DynamicArrayTypeOf!T) && !is(StringTypeOf!T) && !is(T == enum) && !hasToString!(T, Char))
{
    static if (is(const(ArrayTypeOf!T) == const(void[])))
    {
        formatValueImpl(w, cast(const ubyte[]) obj, f);
    }
    else static if (!isInputRange!T)
    {
        alias U = Unqual!(ArrayTypeOf!T);
        static assert(isInputRange!U, U.stringof ~ " must be an InputRange");
        U val = obj;
        formatValueImpl(w, val, f);
    }
    else
    {
        formatRange(w, obj, f);
    }
}

// alias this, input range I/F, and toString()
@system unittest
{
    struct S(int flags)
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
        string toString() const { return "S"; }
    }
    formatTest(S!0b000([0, 1, 2]), "S!0([0, 1, 2])");
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
        override string toString() const { return "C"; }
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

@system unittest
{
    // void[]
    void[] val0;
    formatTest( val0, "[]" );

    void[] val = cast(void[]) cast(ubyte[])[1, 2, 3];
    formatTest( val, "[1, 2, 3]" );

    void[0] sval0 = [];
    formatTest( sval0, "[]");

    void[3] sval = cast(void[3]) cast(ubyte[3])[1, 2, 3];
    formatTest( sval, "[1, 2, 3]" );
}

@safe unittest
{
    // const(T[]) -> const(T)[]
    const short[] a = [1, 2, 3];
    formatTest( a, "[1, 2, 3]" );

    struct S { const(int[]) arr; alias arr this; }
    auto s = S([1,2,3]);
    formatTest( s, "[1, 2, 3]" );
}

// https://issues.dlang.org/show_bug.cgi?id=6640
@safe unittest
{
    struct Range
    {
      @safe:
        string value;
        @property bool empty() const { return !value.length; }
        @property dchar front() const { return value.front; }
        void popFront() { value.popFront(); }

        @property size_t length() const { return value.length; }
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

@system unittest
{
    import std.meta : AliasSeq;

    // string literal from valid UTF sequence is encoding free.
    static foreach (StrType; AliasSeq!(string, wstring, dstring))
    {
        // Valid and printable (ASCII)
        formatTest( [cast(StrType)"hello"],
                    `["hello"]` );

        // 1 character escape sequences (' is not escaped in strings)
        formatTest( [cast(StrType)"\"'\0\\\a\b\f\n\r\t\v"],
                    `["\"'\0\\\a\b\f\n\r\t\v"]` );

        // 1 character optional escape sequences
        formatTest( [cast(StrType)"\'\?"],
                    `["'?"]` );

        // Valid and non-printable code point (<= U+FF)
        formatTest( [cast(StrType)"\x10\x1F\x20test"],
                    `["\x10\x1F test"]` );

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

@safe unittest
{
    // nested range formatting with array of string
    formatTest( "%({%(%02x %)}%| %)", ["test", "msg"],
                `{74 65 73 74} {6d 73 67}` );
}

@safe unittest
{
    // stop auto escaping inside range formatting
    auto arr = ["hello", "world"];
    formatTest( "%(%s, %)",  arr, `"hello", "world"` );
    formatTest( "%-(%s, %)", arr, `hello, world` );

    auto aa1 = [1:"hello", 2:"world"];
    formatTest( "%(%s:%s, %)",  aa1, [`1:"hello", 2:"world"`, `2:"world", 1:"hello"`] );
    formatTest( "%-(%s:%s, %)", aa1, [`1:hello, 2:world`, `2:world, 1:hello`] );

    auto aa2 = [1:["ab", "cd"], 2:["ef", "gh"]];
    formatTest( "%-(%s:%s, %)",        aa2, [`1:["ab", "cd"], 2:["ef", "gh"]`, `2:["ef", "gh"], 1:["ab", "cd"]`] );
    formatTest( "%-(%s:%(%s%), %)",    aa2, [`1:"ab""cd", 2:"ef""gh"`, `2:"ef""gh", 1:"ab""cd"`] );
    formatTest( "%-(%s:%-(%s%)%|, %)", aa2, [`1:abcd, 2:efgh`, `2:efgh, 1:abcd`] );
}

// input range formatting
private void formatRange(Writer, T, Char)(ref Writer w, ref T val, scope const ref FormatSpec!Char f)
if (isInputRange!T)
{
    // in this mode, we just want to do a representative print to discover if the format spec is valid
    enum formatTestMode = is(Writer == NoOpSink);

    import std.conv : text;

    // Formatting character ranges like string
    if (f.spec == 's')
    {
        alias E = ElementType!T;

        static if (!is(E == enum) && is(CharTypeOf!E))
        {
            static if (is(StringTypeOf!T))
                writeAligned(w, val[0 .. f.precision < $ ? f.precision : $], f);
            else
            {
                if (!f.flDash)
                {
                    static if (hasLength!T)
                    {
                        // right align
                        auto len = val.length;
                    }
                    else static if (isForwardRange!T && !isInfinite!T)
                    {
                        auto len = walkLength(val.save);
                    }
                    else
                    {
                        enforceFmt(f.width == 0, "Cannot right-align a range without length");
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
                            {
                                put(w, val.front);
                                static if (formatTestMode) break; // one is enough to test
                            }
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
        }
        else
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
                    static if (formatTestMode) break; // one is enough to test
                }
            }
            static if (!isInfinite!T) put(w, f.seqAfter);
        }
    }
    else if (f.spec == 'r')
    {
        static if (is(DynamicArrayTypeOf!T))
        {
            alias ARR = DynamicArrayTypeOf!T;
            scope a = cast(ARR) val;
            foreach (e ; a)
            {
                formatValue(w, e, f);
                static if (formatTestMode) break; // one is enough to test
            }
        }
        else
        {
            for (size_t i; !val.empty; val.popFront(), ++i)
            {
                formatValue(w, val.front, f);
                static if (formatTestMode) break; // one is enough to test
            }
        }
    }
    else if (f.spec == '(')
    {
        if (val.empty)
            return;
        // Nested specifier is to be used
        for (;;)
        {
            auto fmt = FormatSpec!Char(f.nested);
            w: while (true)
            {
                immutable r = fmt.writeUpToNextSpec(w);
                // There was no format specifier, so break
                if (!r)
                    break;
                if (f.flDash)
                    formatValue(w, val.front, fmt);
                else
                    formatElement(w, val.front, fmt);
                // Check if there will be a format specifier farther on in the
                // string. If so, continue the loop, otherwise break. This
                // prevents extra copies of the `sep` from showing up.
                foreach (size_t i; 0 .. fmt.trailing.length)
                    if (fmt.trailing[i] == '%')
                        continue w;
                break w;
            }
            static if (formatTestMode)
            {
                break; // one is enough to test
            }
            else
            {
                if (f.sep !is null)
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
    }
    else
        throw new FormatException(text("Incorrect format specifier for range: %", f.spec));
}

// https://issues.dlang.org/show_bug.cgi?id=18778
@safe pure unittest
{
    assert(format("%-(%1$s - %1$s, %)", ["A", "B", "C"]) == "A - A, B - B, C - C");
}

@safe pure unittest
{
    assert(collectExceptionMsg(format("%d", "hi")).back == 'd');
}

// character formatting with ecaping
private void formatChar(Writer)(ref Writer w, in dchar c, in char quote)
{
    import std.uni : isGraphical;

    string fmt;
    if (isGraphical(c))
    {
        if (c == quote || c == '\\')
            put(w, '\\');
        put(w, c);
        return;
    }
    else if (c <= 0xFF)
    {
        if (c < 0x20)
        {
            foreach (i, k; "\n\r\t\a\b\f\v\0")
            {
                if (c == k)
                {
                    put(w, '\\');
                    put(w, "nrtabfv0"[i]);
                    return;
                }
            }
        }
        fmt = "\\x%02X";
    }
    else if (c <= 0xFFFF)
        fmt = "\\u%04X";
    else
        fmt = "\\U%08X";

    formattedWrite(w, fmt, cast(uint) c);
}

// undocumented because of deprecation
// string elements are formatted like UTF-8 string literals.
void formatElement(Writer, T, Char)(auto ref Writer w, T val, scope const ref FormatSpec!Char f)
if (is(StringTypeOf!T) && !is(T == enum))
{
    import std.array : appender;
    import std.utf : decode, UTFException;

    StringTypeOf!T str = val;   // https://issues.dlang.org/show_bug.cgi?id=8015

    if (f.spec == 's')
    {
        try
        {
            // ignore other specifications and quote
            for (size_t i = 0; i < str.length; )
            {
                auto c = decode(str, i);
                // \uFFFE and \uFFFF are considered valid by isValidDchar,
                // so need checking for interchange.
                if (c == 0xFFFE || c == 0xFFFF)
                    goto LinvalidSeq;
            }
            put(w, '\"');
            for (size_t i = 0; i < str.length; )
            {
                auto c = decode(str, i);
                formatChar(w, c, '"');
            }
            put(w, '\"');
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
            alias IntArr = const(ubyte)[];
        }
        else static if (is(typeof(str[0]) : const(wchar)))
        {
            enum postfix = 'w';
            alias IntArr = const(ushort)[];
        }
        else static if (is(typeof(str[0]) : const(dchar)))
        {
            enum postfix = 'd';
            alias IntArr = const(uint)[];
        }
        formattedWrite(w, "x\"%(%02X %)\"%s", cast(IntArr) str, postfix);
    }
    else
        formatValue(w, str, f);
}

@safe pure unittest
{
    import std.array : appender;
    auto w = appender!string();
    auto spec = singleSpec("%s");
    formatElement(w, "Hello World", spec);

    assert(w.data == "\"Hello World\"");
}

@safe unittest
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

// undocumented because of deprecation
// Character elements are formatted like UTF-8 character literals.
void formatElement(Writer, T, Char)(auto ref Writer w, T val, scope const ref FormatSpec!Char f)
if (is(CharTypeOf!T) && !is(T == enum))
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

@safe unittest
{
    import std.array : appender;
    auto w = appender!string();
    auto spec = singleSpec("%s");
    formatElement(w, "H", spec);

    assert(w.data == "\"H\"", w.data);
}

// undocumented
// Maybe T is noncopyable struct, so receive it by 'auto ref'.
void formatElement(Writer, T, Char)(auto ref Writer w, auto ref T val, scope const ref FormatSpec!Char f)
if (!is(StringTypeOf!T) && !is(CharTypeOf!T) || is(T == enum))
{
    formatValue(w, val, f);
}

/*
   Associative arrays are formatted by using `':'` and $(D ", ") as
   separators, and enclosed by `'['` and `']'`.
 */
private void formatValueImpl(Writer, T, Char)(auto ref Writer w, T obj, scope const ref FormatSpec!Char f)
if (is(AssocArrayTypeOf!T) && !is(T == enum) && !hasToString!(T, Char))
{
    AssocArrayTypeOf!T val = obj;
    const spec = f.spec;

    enforceFmt(spec == 's' || spec == '(',
        "incompatible format character for associative array argument: %" ~ spec);

    enum const(Char)[] defSpec = "%s" ~ f.keySeparator ~ "%s" ~ f.seqSeparator;
    auto fmtSpec = spec == '(' ? f.nested : defSpec;

    size_t i = 0;
    immutable end = val.length;

    if (spec == 's')
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
        if (f.sep !is null)
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
    if (spec == 's')
        put(w, f.seqAfter);
}

@safe unittest
{
    assert(collectExceptionMsg!FormatException(format("%d", [0:1])).back == 'd');

    int[string] aa0;
    formatTest( aa0, `[]` );

    // elements escaping
    formatTest(  ["aaa":1, "bbb":2],
               [`["aaa":1, "bbb":2]`, `["bbb":2, "aaa":1]`] );
    formatTest(  ['c':"str"],
                `['c':"str"]` );
    formatTest(  ['"':"\"", '\'':"'"],
               [`['"':"\"", '\'':"'"]`, `['\'':"'", '"':"\""]`] );

    // range formatting for AA
    auto aa3 = [1:"hello", 2:"world"];
    // escape
    formatTest( "{%(%s:%s $ %)}", aa3,
               [`{1:"hello" $ 2:"world"}`, `{2:"world" $ 1:"hello"}`]);
    // use range formatting for key and value, and use %|
    formatTest( "{%([%04d->%(%c.%)]%| $ %)}", aa3,
               [`{[0001->h.e.l.l.o] $ [0002->w.o.r.l.d]}`, `{[0002->w.o.r.l.d] $ [0001->h.e.l.l.o]}`] );

    // https://issues.dlang.org/show_bug.cgi?id=12135
    formatTest("%(%s:<%s>%|,%)", [1:2], "1:<2>");
    formatTest("%(%s:<%s>%|%)" , [1:2], "1:<2>");
}

@system unittest
{
    class C1 { int[char] val; alias val this; this(int[char] v){ val = v; } }
    class C2 { int[char] val; alias val this; this(int[char] v){ val = v; }
               override string toString() const { return "C"; } }
    formatTest( new C1(['c':1, 'd':2]), [`['c':1, 'd':2]`, `['d':2, 'c':1]`] );
    formatTest( new C2(['c':1, 'd':2]), "C" );

    struct S1 { int[char] val; alias val this; }
    struct S2 { int[char] val; alias val this;
                string toString() const { return "S"; } }
    formatTest( S1(['c':1, 'd':2]), [`['c':1, 'd':2]`, `['d':2, 'c':1]`] );
    formatTest( S2(['c':1, 'd':2]), "S" );
}

// https://issues.dlang.org/show_bug.cgi?id=8921
@safe unittest
{
    enum E : char { A = 'a', B = 'b', C = 'c' }
    E[3] e = [E.A, E.B, E.C];
    formatTest(e, "[A, B, C]");

    E[] e2 = [E.A, E.B, E.C];
    formatTest(e2, "[A, B, C]");
}

private enum HasToStringResult
{
    none,
    hasSomeToString,
    constCharSink,
    constCharSinkFormatString,
    constCharSinkFormatSpec,
    customPutWriter,
    customPutWriterFormatSpec,
}

private template hasToString(T, Char)
{
    static if (isPointer!T)
    {
        // X* does not have toString, even if X is aggregate type has toString.
        enum hasToString = HasToStringResult.none;
    }
    else static if (is(typeof(
        {T val = void;
        const FormatSpec!Char f;
        static struct S {void put(scope Char s){}}
        S s;
        val.toString(s, f);
        // force toString to take parameters by ref
        static assert(!__traits(compiles, val.toString(s, FormatSpec!Char())));
        static assert(!__traits(compiles, val.toString(S(), f)));}
    )))
    {
        enum hasToString = HasToStringResult.customPutWriterFormatSpec;
    }
    else static if (is(typeof(
        {T val = void;
        static struct S {void put(scope Char s){}}
        S s;
        val.toString(s);
        // force toString to take parameters by ref
        static assert(!__traits(compiles, val.toString(S())));}
    )))
    {
        enum hasToString = HasToStringResult.customPutWriter;
    }
    else static if (is(typeof({ T val = void; FormatSpec!Char f; val.toString((scope const(char)[] s){}, f); })))
    {
        enum hasToString = HasToStringResult.constCharSinkFormatSpec;
    }
    else static if (is(typeof({ T val = void; val.toString((scope const(char)[] s){}, "%s"); })))
    {
        enum hasToString = HasToStringResult.constCharSinkFormatString;
    }
    else static if (is(typeof({ T val = void; val.toString((scope const(char)[] s){}); })))
    {
        enum hasToString = HasToStringResult.constCharSink;
    }
    else static if (is(typeof({ T val = void; return val.toString(); }()) S) && isSomeString!S)
    {
        enum hasToString = HasToStringResult.hasSomeToString;
    }
    else
    {
        enum hasToString = HasToStringResult.none;
    }
}

@safe unittest
{
    static struct A
    {
        void toString(Writer)(ref Writer w)
        if (isOutputRange!(Writer, string))
        {}
    }
    static struct B
    {
        void toString(scope void delegate(scope const(char)[]) sink, scope FormatSpec!char fmt) {}
    }
    static struct C
    {
        void toString(scope void delegate(scope const(char)[]) sink, string fmt) {}
    }
    static struct D
    {
        void toString(scope void delegate(scope const(char)[]) sink) {}
    }
    static struct E
    {
        string toString() {return "";}
    }
    static struct F
    {
        void toString(Writer)(ref Writer w, scope const ref FormatSpec!char fmt)
        if (isOutputRange!(Writer, string))
        {}
    }
    static struct G
    {
        string toString() {return "";}
        void toString(Writer)(ref Writer w) if (isOutputRange!(Writer, string)) {}
    }
    static struct H
    {
        string toString() {return "";}
        void toString(Writer)(ref Writer w, scope const ref FormatSpec!char fmt)
        if (isOutputRange!(Writer, string))
        {}
    }
    static struct I
    {
        void toString(Writer)(ref Writer w) if (isOutputRange!(Writer, string)) {}
        void toString(Writer)(ref Writer w, scope const ref FormatSpec!char fmt)
        if (isOutputRange!(Writer, string))
        {}
    }
    static struct J
    {
        string toString() {return "";}
        void toString(Writer)(ref Writer w, scope ref FormatSpec!char fmt)
        if (isOutputRange!(Writer, string))
        {}
    }
    static struct K
    {
        void toString(Writer)(Writer w, scope const ref FormatSpec!char fmt)
        if (isOutputRange!(Writer, string))
        {}
    }
    static struct L
    {
        void toString(Writer)(ref Writer w, scope const FormatSpec!char fmt)
        if (isOutputRange!(Writer, string))
        {}
    }

    with(HasToStringResult)
    {
        static assert(hasToString!(A, char) == customPutWriter);
        static assert(hasToString!(B, char) == constCharSinkFormatSpec);
        static assert(hasToString!(C, char) == constCharSinkFormatString);
        static assert(hasToString!(D, char) == constCharSink);
        static assert(hasToString!(E, char) == hasSomeToString);
        static assert(hasToString!(F, char) == customPutWriterFormatSpec);
        static assert(hasToString!(G, char) == customPutWriter);
        static assert(hasToString!(H, char) == customPutWriterFormatSpec);
        static assert(hasToString!(I, char) == customPutWriterFormatSpec);
        static assert(hasToString!(J, char) == hasSomeToString);
        static assert(hasToString!(K, char) == constCharSinkFormatSpec);
        static assert(hasToString!(L, char) == none);
    }
}

// object formatting with toString
private void formatObject(Writer, T, Char)(ref Writer w, ref T val, scope const ref FormatSpec!Char f)
if (hasToString!(T, Char))
{
    enum overload = hasToString!(T, Char);

    enum noop = is(Writer == NoOpSink);

    static if (overload == HasToStringResult.customPutWriterFormatSpec)
    {
        static if (!noop) val.toString(w, f);
    }
    else static if (overload == HasToStringResult.customPutWriter)
    {
        static if (!noop) val.toString(w);
    }
    else static if (overload == HasToStringResult.constCharSinkFormatSpec)
    {
        static if (!noop) val.toString((scope const(char)[] s) { put(w, s); }, f);
    }
    else static if (overload == HasToStringResult.constCharSinkFormatString)
    {
        static if (!noop) val.toString((scope const(char)[] s) { put(w, s); }, f.getCurFmtStr());
    }
    else static if (overload == HasToStringResult.constCharSink)
    {
        static if (!noop) val.toString((scope const(char)[] s) { put(w, s); });
    }
    else static if (overload == HasToStringResult.hasSomeToString)
    {
        static if (!noop) put(w, val.toString());
    }
    else
    {
        static assert(0, "No way found to format " ~ T.stringof ~ " as string");
    }
}

void enforceValidFormatSpec(T, Char)(scope const ref FormatSpec!Char f)
{
    enum overload = hasToString!(T, Char);
    static if (
            overload != HasToStringResult.constCharSinkFormatSpec &&
            overload != HasToStringResult.customPutWriterFormatSpec &&
            !isInputRange!T)
    {
        enforceFmt(f.spec == 's',
            "Expected '%s' format specifier for type '" ~ T.stringof ~ "'");
    }
}

@system unittest
{
    static interface IF1 { }
    class CIF1 : IF1 { }
    static struct SF1 { }
    static union UF1 { }
    static class CF1 { }

    static interface IF2 { string toString(); }
    static class CIF2 : IF2 { override string toString() { return ""; } }
    static struct SF2 { string toString() { return ""; } }
    static union UF2 { string toString() { return ""; } }
    static class CF2 { override string toString() { return ""; } }

    static interface IK1 { void toString(scope void delegate(scope const(char)[]) sink,
                           FormatSpec!char) const; }
    static class CIK1 : IK1 { override void toString(scope void delegate(scope const(char)[]) sink,
                              FormatSpec!char) const { sink("CIK1"); } }
    static struct KS1 { void toString(scope void delegate(scope const(char)[]) sink,
                        FormatSpec!char) const { sink("KS1"); } }

    static union KU1 { void toString(scope void delegate(scope const(char)[]) sink,
                       FormatSpec!char) const { sink("KU1"); } }

    static class KC1 { void toString(scope void delegate(scope const(char)[]) sink,
                       FormatSpec!char) const { sink("KC1"); } }

    IF1 cif1 = new CIF1;
    assertThrown!FormatException(format("%f", cif1));
    assertThrown!FormatException(format("%f", SF1()));
    assertThrown!FormatException(format("%f", UF1()));
    assertThrown!FormatException(format("%f", new CF1()));

    IF2 cif2 = new CIF2;
    assertThrown!FormatException(format("%f", cif2));
    assertThrown!FormatException(format("%f", SF2()));
    assertThrown!FormatException(format("%f", UF2()));
    assertThrown!FormatException(format("%f", new CF2()));

    IK1 cik1 = new CIK1;
    assert(format("%f", cik1) == "CIK1");
    assert(format("%f", KS1()) == "KS1");
    assert(format("%f", KU1()) == "KU1");
    assert(format("%f", new KC1()) == "KC1");
}

/*
   Aggregates
 */
private void formatValueImpl(Writer, T, Char)(auto ref Writer w, T val, scope const ref FormatSpec!Char f)
if (is(T == class) && !is(T == enum))
{
    enforceValidFormatSpec!(T, Char)(f);

    // TODO: remove this check once `@disable override` deprecation cycle is finished
    static if (__traits(hasMember, T, "toString") && isSomeFunction!(val.toString))
        static assert(!__traits(isDisabled, T.toString), T.stringof ~
            " cannot be formatted because its `toString` is marked with `@disable`");

    if (val is null)
        put(w, "null");
    else
    {
        import std.algorithm.comparison : among;
        enum overload = hasToString!(T, Char);
        with(HasToStringResult)
        static if ((is(T == immutable) || is(T == const) || is(T == shared)) && overload == none)
        {
            // Remove this when Object gets const toString
            // https://issues.dlang.org/show_bug.cgi?id=7879
            static if (is(T == immutable))
                put(w, "immutable(");
            else static if (is(T == const))
                put(w, "const(");
            else static if (is(T == shared))
                put(w, "shared(");

            put(w, typeid(Unqual!T).name);
            put(w, ')');
        }
        else static if (overload.among(constCharSink, constCharSinkFormatString, constCharSinkFormatSpec) ||
                       (!isInputRange!T && !is(BuiltinTypeOf!T)))
        {
            formatObject!(Writer, T, Char)(w, val, f);
        }
        else
        {
          //string delegate() dg = &val.toString;
            Object o = val;     // workaround
            string delegate() dg = &o.toString;
            scope Object object = new Object();
            if (dg.funcptr != (&object.toString).funcptr) // toString is overridden
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
                formatValueImpl(w, x, f);
            }
            else
            {
                formatObject(w, val, f);
            }
        }
    }
}

@system unittest
{
    import std.array : appender;
    import std.range.interfaces;
    // class range (https://issues.dlang.org/show_bug.cgi?id=5154)
    auto c = inputRangeObject([1,2,3,4]);
    formatTest( c, "[1, 2, 3, 4]" );
    assert(c.empty);
    c = null;
    formatTest( c, "null" );
}

@system unittest
{
    // https://issues.dlang.org/show_bug.cgi?id=5354
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
        void toString(scope void delegate(scope const(char)[]) dg,
                      scope const ref FormatSpec!char f) const
        {
            dg("[012]");
        }
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
        override string toString() const { return "[012]"; }
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

// outside the unittest block, otherwise the FQN of the
// class contains the line number of the unittest
version (StdUnittest)
{
    private class C {}
}

// https://issues.dlang.org/show_bug.cgi?id=7879
@safe unittest
{
    const(C) c;
    auto s = format("%s", c);
    assert(s == "null");

    immutable(C) c2 = new C();
    s = format("%s", c2);
    assert(s == "immutable(std.format.write.C)");

    const(C) c3 = new C();
    s = format("%s", c3);
    assert(s == "const(std.format.write.C)");

    shared(C) c4 = new C();
    s = format("%s", c4);
    assert(s == "shared(std.format.write.C)");
}

// https://issues.dlang.org/show_bug.cgi?id=19003
@safe unittest
{
    struct S
    {
        int i;

        @disable this();

        invariant { assert(this.i); }

        this(int i) @safe in { assert(i); } do { this.i = i; }

        string toString() { return "S"; }
    }

    S s = S(1);

    format!"%s"(s);
}

// https://issues.dlang.org/show_bug.cgi?id=20218
@safe pure unittest
{
    void notCalled()
    {
        import std.range : repeat;

        auto value = 1.repeat;

        // test that range is not evaluated to completion at compiletime
        format!"%s"(value);
    }
}

// https://issues.dlang.org/show_bug.cgi?id=7879
@safe unittest
{
    class F
    {
        override string toString() const @safe
        {
            return "Foo";
        }
    }

    const(F) c;
    auto s = format("%s", c);
    assert(s == "null");

    const(F) c2 = new F();
    s = format("%s", c2);
    assert(s == "Foo", s);
}

// ditto
private void formatValueImpl(Writer, T, Char)(auto ref Writer w, T val, scope const ref FormatSpec!Char f)
if (is(T == interface) && (hasToString!(T, Char) || !is(BuiltinTypeOf!T)) && !is(T == enum))
{
    enforceValidFormatSpec!(T, Char)(f);
    if (val is null)
        put(w, "null");
    else
    {
        static if (__traits(hasMember, T, "toString") && isSomeFunction!(val.toString))
            static assert(!__traits(isDisabled, T.toString), T.stringof ~
                " cannot be formatted because its `toString` is marked with `@disable`");

        static if (hasToString!(T, Char) != HasToStringResult.none)
        {
            formatObject(w, val, f);
        }
        else static if (isInputRange!T)
        {
            formatRange(w, val, f);
        }
        else
        {
            version (Windows)
            {
                import core.sys.windows.com : IUnknown;
                static if (is(T : IUnknown))
                {
                    formatValueImpl(w, *cast(void**)&val, f);
                }
                else
                {
                    formatValueImpl(w, cast(Object) val, f);
                }
            }
            else
            {
                formatValueImpl(w, cast(Object) val, f);
            }
        }
    }
}

@system unittest
{
    // interface
    import std.range.interfaces;
    InputRange!int i = inputRangeObject([1,2,3,4]);
    formatTest( i, "[1, 2, 3, 4]" );
    assert(i.empty);
    i = null;
    formatTest( i, "null" );

    // interface (downcast to Object)
    interface Whatever {}
    class C : Whatever
    {
        override @property string toString() const { return "ab"; }
    }
    Whatever val = new C;
    formatTest( val, "ab" );

    // https://issues.dlang.org/show_bug.cgi?id=11175
    version (Windows)
    {
        import core.sys.windows.com : IUnknown, IID;
        import core.sys.windows.windef : HRESULT;

        interface IUnknown2 : IUnknown { }

        class D : IUnknown2
        {
            extern(Windows) HRESULT QueryInterface(const(IID)* riid, void** pvObject) { return typeof(return).init; }
            extern(Windows) uint AddRef() { return 0; }
            extern(Windows) uint Release() { return 0; }
        }

        IUnknown2 d = new D;
        string expected = format("%X", cast(void*) d);
        formatTest(d, expected);
    }
}

/// ditto
// Maybe T is noncopyable struct, so receive it by 'auto ref'.
private void formatValueImpl(Writer, T, Char)(auto ref Writer w, auto ref T val, scope const ref FormatSpec!Char f)
if ((is(T == struct) || is(T == union)) && (hasToString!(T, Char) || !is(BuiltinTypeOf!T)) && !is(T == enum))
{

    static if (__traits(hasMember, T, "toString") && isSomeFunction!(val.toString))
        static assert(!__traits(isDisabled, T.toString), T.stringof ~
            " cannot be formatted because its `toString` is marked with `@disable`");

    enforceValidFormatSpec!(T, Char)(f);
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
            static if (__traits(identifier, val.tupleof[i]) == "this")
                continue;
            else static if (0 < i && val.tupleof[i-1].offsetof == val.tupleof[i].offsetof)
            {
                static if (i == val.tupleof.length - 1 || val.tupleof[i].offsetof != val.tupleof[i+1].offsetof)
                    put(w, separator~val.tupleof[i].stringof[4..$]~"}");
                else
                    put(w, separator~val.tupleof[i].stringof[4..$]);
            }
            else static if (i+1 < val.tupleof.length && val.tupleof[i].offsetof == val.tupleof[i+1].offsetof)
                put(w, (i > 0 ? separator : "")~"#{overlap "~val.tupleof[i].stringof[4..$]);
            else
            {
                static if (i > 0)
                    put(w, separator);
                formatElement(w, e, f);
            }
        }
        put(w, right);
    }
    else
    {
        put(w, T.stringof);
    }
}

// https://issues.dlang.org/show_bug.cgi?id=9588
@safe pure unittest
{
    struct S { int x; bool empty() { return false; } }
    formatTest( S(), "S(0)" );
}

// https://issues.dlang.org/show_bug.cgi?id=4638
@safe unittest
{
    struct U8  {  string toString() const { return "blah"; } }
    struct U16 { wstring toString() const { return "blah"; } }
    struct U32 { dstring toString() const { return "blah"; } }
    formatTest( U8(), "blah" );
    formatTest( U16(), "blah" );
    formatTest( U32(), "blah" );
}

// https://issues.dlang.org/show_bug.cgi?id=3890
@safe unittest
{
    struct Int{ int n; }
    struct Pair{ string s; Int i; }
    formatTest( Pair("hello", Int(5)),
                `Pair("hello", Int(5))` );
}

@system unittest
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
        string toString() const { return s; }
    }
    U2 u2;
    u2.s = "hello";
    formatTest( u2, "hello" );
}

@system unittest
{
    import std.array : appender;
    // https://issues.dlang.org/show_bug.cgi?id=7230
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

@safe unittest
{
    import std.array : appender;
    static struct S{ @disable this(this); }
    S s;

    FormatSpec!char f;
    auto w = appender!string();
    formatValue(w, s, f);
    assert(w.data == "S()");
}

@safe unittest
{
    //struct Foo { @disable string toString(); }
    //Foo foo;

    interface Bar { @disable string toString(); }
    Bar bar;

    import std.array : appender;
    auto w = appender!(char[])();
    FormatSpec!char f;

    // NOTE: structs cant be tested : the assertion is correct so compilation
    // continues and fails when trying to link the unimplemented toString.
    //static assert(!__traits(compiles, formatValue(w, foo, f)));
    static assert(!__traits(compiles, formatValue(w, bar, f)));
}

/*
    `enum`s are formatted like their base value
 */
private void formatValueImpl(Writer, T, Char)(auto ref Writer w, T val, scope const ref FormatSpec!Char f)
if (is(T == enum))
{
    if (f.spec == 's')
    {
        foreach (i, e; EnumMembers!T)
        {
            if (val == e)
            {
                formatValueImpl(w, __traits(allMembers, T)[i], f);
                return;
            }
        }

        import std.array : appender;
        auto w2 = appender!string();

        // val is not a member of T, output cast(T) rawValue instead.
        put(w2, "cast(" ~ T.stringof ~ ")");
        static assert(!is(OriginalType!T == T), "OriginalType!" ~ T.stringof ~
                "must not be equal to " ~ T.stringof);

        FormatSpec!Char f2 = f;
        f2.width = 0;
        formatValueImpl(w2, cast(OriginalType!T) val, f2);
        writeAligned(w, w2.data, f);
        return;
    }
    formatValueImpl(w, cast(OriginalType!T) val, f);
}

@safe unittest
{
    enum A { first, second, third }
    formatTest( A.second, "second" );
    formatTest( cast(A) 72, "cast(A)72" );
}
@safe unittest
{
    enum A : string { one = "uno", two = "dos", three = "tres" }
    formatTest( A.three, "three" );
    formatTest( cast(A)"mill\&oacute;n", "cast(A)mill\&oacute;n" );
}
@safe unittest
{
    enum A : bool { no, yes }
    formatTest( A.yes, "yes" );
    formatTest( A.no, "no" );
}
@safe unittest
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

@safe pure unittest
{
    enum A { one, two, three }

    string t1 = format("[%6s] [%-6s]", A.one, A.one);
    assert(t1 == "[   one] [one   ]");
    string t2 = format("[%10s] [%-10s]", cast(A) 10, cast(A) 10);
    assert(t2 == "[ cast(A)" ~ "10] [cast(A)" ~ "10 ]"); // due to bug in style checker
}

/*
   Pointers are formatted as hex integers.
 */
private void formatValueImpl(Writer, T, Char)(auto ref Writer w, scope T val, scope const ref FormatSpec!Char f)
if (isPointer!T && !is(T == enum) && !hasToString!(T, Char))
{
    static if (is(typeof({ shared const void* p = val; })))
        alias SharedOf(T) = shared(T);
    else
        alias SharedOf(T) = T;

    const SharedOf!(void*) p = val;
    const pnum = ()@trusted{ return cast(ulong) p; }();

    if (f.spec == 's')
    {
        if (p is null)
        {
            writeAligned(w, "null", f);
            return;
        }
        FormatSpec!Char fs = f; // fs is copy for change its values.
        fs.spec = 'X';
        formatValueImpl(w, pnum, fs);
    }
    else
    {
        enforceFmt(f.spec == 'X' || f.spec == 'x',
           "Expected one of %s, %x or %X for pointer type.");
        formatValueImpl(w, pnum, f);
    }
}

@safe pure unittest
{
    int* p;

    string t1 = format("[%6s] [%-6s]", p, p);
    assert(t1 == "[  null] [null  ]");
}

/*
   SIMD vectors are formatted as arrays.
 */
private void formatValueImpl(Writer, V, Char)(auto ref Writer w, V val, scope const ref FormatSpec!Char f)
if (isSIMDVector!V)
{
    formatValueImpl(w, val.array, f);
}

@safe unittest
{
    import core.simd;
    static if (is(float4))
    {
        version (X86)
        {
            version (OSX) {/* https://issues.dlang.org/show_bug.cgi?id=17823 */}
        }
        else
        {
            float4 f;
            f.array[0] = 1;
            f.array[1] = 2;
            f.array[2] = 3;
            f.array[3] = 4;
            formatTest(f, "[1, 2, 3, 4]");
        }
    }
}

@safe pure unittest
{
    int* p = null;
    formatTest( p, "null" );

    auto q = ()@trusted{ return cast(void*) 0xFFEECCAA; }();
    formatTest( q, "FFEECCAA" );
}

// https://issues.dlang.org/show_bug.cgi?id=11782
@safe pure unittest
{
    import std.range : iota;

    auto a = iota(0, 10);
    auto b = iota(0, 10);
    auto p = ()@trusted{ auto p = &a; return p; }();

    assert(format("%s",p) != format("%s",b));
}

@system pure unittest
{
    // Test for https://issues.dlang.org/show_bug.cgi?id=7869
    struct S
    {
        string toString() const { return ""; }
    }
    S* p = null;
    formatTest( p, "null" );

    S* q = cast(S*) 0xFFEECCAA;
    formatTest( q, "FFEECCAA" );
}

// https://issues.dlang.org/show_bug.cgi?id=8186
@system unittest
{
    class B
    {
        int*a;
        this(){ a = new int; }
        alias a this;
    }
    formatTest( B.init, "null" );
}

// https://issues.dlang.org/show_bug.cgi?id=9336
@system pure unittest
{
    shared int i;
    format("%s", &i);
}

// https://issues.dlang.org/show_bug.cgi?id=11778
@system pure unittest
{
    int* p = null;
    assertThrown!FormatException(format("%d", p));
    assertThrown!FormatException(format("%04d", p + 2));
}

// https://issues.dlang.org/show_bug.cgi?id=12505
@safe pure unittest
{
    void* p = null;
    formatTest( "%08X", p, "00000000" );
}

/*
   Delegates are formatted by `ReturnType delegate(Parameters) FunctionAttributes`
 */
private void formatValueImpl(Writer, T, Char)(auto ref Writer w, scope T, scope const ref FormatSpec!Char f)
if (isDelegate!T)
{
    formatValueImpl(w, T.stringof, f);
}

@safe unittest
{
    void func() @system { __gshared int x; ++x; throw new Exception("msg"); }
    version (linux) formatTest( &func, "void delegate() @system" );
}

@safe pure unittest
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

@safe unittest
{
    // width/precision
    assert(collectExceptionMsg!FormatException(format("%*.d", 5.1, 2))
        == "integer width expected, not double for argument #1");
    assert(collectExceptionMsg!FormatException(format("%-1*.d", 5.1, 2))
        == "integer width expected, not double for argument #1");

    assert(collectExceptionMsg!FormatException(format("%.*d", '5', 2))
        == "integer precision expected, not char for argument #1");
    assert(collectExceptionMsg!FormatException(format("%-1.*d", 4.7, 3))
        == "integer precision expected, not double for argument #1");
    assert(collectExceptionMsg!FormatException(format("%.*d", 5))
        == "Orphan format specifier: %d");
    assert(collectExceptionMsg!FormatException(format("%*.*d", 5))
        == "Missing integer precision argument");

    // separatorCharPos
    assert(collectExceptionMsg!FormatException(format("%,?d", 5))
        == "separator character expected, not int for argument #1");
    assert(collectExceptionMsg!FormatException(format("%,?d", '?'))
        == "Orphan format specifier: %d");
    assert(collectExceptionMsg!FormatException(format("%.*,*?d", 5))
        == "Missing separator digit width argument");
}

private bool needToSwapEndianess(Char)(scope const ref FormatSpec!Char f)
{
    import std.system : endian, Endian;

    return endian == Endian.littleEndian && f.flPlus
        || endian == Endian.bigEndian && f.flDash;
}

private void writeAligned(Writer, T, Char)(auto ref Writer w, T s, scope const ref FormatSpec!Char f)
if (isSomeString!T)
{
    size_t width;
    if (f.width > 0)
    {
        // check for non-ascii character
        import std.algorithm.searching : any;
        if (s.any!(a => a > 0x7F))
        {
            //TODO: optimize this
            import std.uni : graphemeStride;
            for (size_t i; i < s.length; i += graphemeStride(s, i))
                ++width;
        }
        else
            width = s.length;
    }
    else
        width = s.length;

    if (!f.flDash)
    {
        // right align
        if (f.width > width)
            foreach (i ; 0 .. f.width - width) put(w, ' ');
        put(w, s);
    }
    else
    {
        // left align
        put(w, s);
        if (f.width > width)
            foreach (i ; 0 .. f.width - width) put(w, ' ');
    }
}

@safe pure unittest
{
    import std.array : appender;
    auto w = appender!string();
    auto spec = singleSpec("%s");
    writeAligned(w, "a本Ä", spec);
    assert(w.data == "a本Ä", w.data);
}

@safe pure unittest
{
    import std.array : appender;
    auto w = appender!string();
    auto spec = singleSpec("%10s");
    writeAligned(w, "a本Ä", spec);
    assert(w.data == "       a本Ä", "|" ~ w.data ~ "|");
}

@safe pure unittest
{
    import std.array : appender;
    auto w = appender!string();
    auto spec = singleSpec("%-10s");
    writeAligned(w, "a本Ä", spec);
    assert(w.data == "a本Ä       ", w.data);
}

version (StdUnittest)
private void formatTest(T)(T val, string expected, size_t ln = __LINE__, string fn = __FILE__)
{
    import core.exception : AssertError;
    import std.array : appender;
    import std.conv : text;
    FormatSpec!char f;
    auto w = appender!string();
    formatValue(w, val, f);
    enforce!AssertError(
            w.data == expected,
            text("expected = `", expected, "`, result = `", w.data, "`"), fn, ln);
}

version (StdUnittest)
private void formatTest(T)(string fmt, T val, string expected, size_t ln = __LINE__, string fn = __FILE__) @safe
{
    import core.exception : AssertError;
    import std.array : appender;
    import std.conv : text;
    auto w = appender!string();
    formattedWrite(w, fmt, val);
    enforce!AssertError(
            w.data == expected,
            text("expected = `", expected, "`, result = `", w.data, "`"), fn, ln);
}

version (StdUnittest)
private void formatTest(T)(T val, string[] expected, size_t ln = __LINE__, string fn = __FILE__)
{
    import core.exception : AssertError;
    import std.array : appender;
    import std.conv : text;
    FormatSpec!char f;
    auto w = appender!string();
    formatValue(w, val, f);
    foreach (cur; expected)
    {
        if (w.data == cur) return;
    }
    enforce!AssertError(
            false,
            text("expected one of `", expected, "`, result = `", w.data, "`"), fn, ln);
}

version (StdUnittest)
private void formatTest(T)(string fmt, T val, string[] expected, size_t ln = __LINE__, string fn = __FILE__) @safe
{
    import core.exception : AssertError;
    import std.array : appender;
    import std.conv : text;
    auto w = appender!string();
    formattedWrite(w, fmt, val);
    foreach (cur; expected)
    {
        if (w.data == cur) return;
    }
    enforce!AssertError(
            false,
            text("expected one of `", expected, "`, result = `", w.data, "`"), fn, ln);
}

@safe /*pure*/ unittest     // formatting floating point values is now impure
{
    import std.array : appender;

    auto stream = appender!string();
    formattedWrite(stream, "%s", 1.1);
    assert(stream.data == "1.1", stream.data);
}

@safe pure unittest
{
    import std.algorithm.iteration : map;
    import std.array : appender;

    auto stream = appender!string();
    formattedWrite(stream, "%s", map!"a*a"([2, 3, 5]));
    assert(stream.data == "[4, 9, 25]", stream.data);

    // Test shared data.
    stream = appender!string();
    shared int s = 6;
    formattedWrite(stream, "%s", s);
    assert(stream.data == "6");
}

@safe pure unittest
{
    import std.array : appender;
    auto stream = appender!string();
    formattedWrite(stream, "%u", 42);
    assert(stream.data == "42", stream.data);
}

@safe pure unittest
{
    // testing raw writes
    import std.array : appender;
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

@safe pure unittest
{
    // testing positional parameters
    import std.array : appender;
    auto w = appender!(char[])();
    formattedWrite(w,
            "Numbers %2$s and %1$s are reversed and %1$s%2$s repeated",
            42, 0);
    assert(w.data == "Numbers 0 and 42 are reversed and 420 repeated",
            w.data);
    assert(collectExceptionMsg!FormatException(formattedWrite(w, "%1$s, %3$s", 1, 2))
        == "Positional specifier %3$s index exceeds 2");

    w.clear();
    formattedWrite(w, "asd%s", 23);
    assert(w.data == "asd23", w.data);
    w.clear();
    formattedWrite(w, "%s%s", 23, 45);
    assert(w.data == "2345", w.data);
}

@safe unittest
{
    import core.stdc.string : strlen;
    import std.array : appender;
    import std.conv : text, octal;
    import core.stdc.stdio : snprintf;

    auto stream = appender!(char[])();

    formattedWrite(stream,
            "hello world! %s %s ", true, 57, 1_000_000_000, 'x', " foo");
    assert(stream.data == "hello world! true 57 ",
        stream.data);

    stream.clear();
    formattedWrite(stream, "%g %A %s", 1.67, -1.28, float.nan);
    assert(stream.data == "1.67 -0X1.47AE147AE147BP+0 nan",
           stream.data);
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

    formattedWrite(stream, "%04f|%05d|%#05x|%#5x",-4.0,-10,1,1);
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

    s = "helloworld";
    string r;
    stream.clear(); formattedWrite(stream, "%.2s", s[0 .. 5]);
    assert(stream.data == "he");
    stream.clear(); formattedWrite(stream, "%.20s", s[0 .. 5]);
    assert(stream.data == "hello");
    stream.clear(); formattedWrite(stream, "%8s", s[0 .. 5]);
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
    assert(stream.data == "7");

    stream.clear(); formattedWrite(stream, "%s", "abc"c);
    assert(stream.data == "abc");
    stream.clear(); formattedWrite(stream, "%s", "def"w);
    assert(stream.data == "def", text(stream.data.length));
    stream.clear(); formattedWrite(stream, "%s", "ghi"d);
    assert(stream.data == "ghi");

here:
    @trusted void* deadBeef() { return cast(void*) 0xDEADBEEF; }
    stream.clear(); formattedWrite(stream, "%s", deadBeef());
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

    @trusted void ObjectTest()
    {
        Object c = null;
        stream.clear(); formattedWrite(stream, "%s", c);
        assert(stream.data == "null");
    }
    ObjectTest();

    enum TestEnum
    {
        Value1, Value2
    }
    stream.clear(); formattedWrite(stream, "%s", TestEnum.Value2);
    assert(stream.data == "Value2", stream.data);
    stream.clear(); formattedWrite(stream, "%s", cast(TestEnum) 5);
    assert(stream.data == "cast(TestEnum)5", stream.data);

    //immutable(char[5])[int] aa = ([3:"hello", 4:"betty"]);
    //stream.clear(); formattedWrite(stream, "%s", aa.values);
    //core.stdc.stdio.fwrite(stream.data.ptr, stream.data.length, 1, stderr);
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
}

@safe unittest
{
    import std.array : appender;
    import std.meta : AliasSeq;

    immutable(char[5])[int] aa = ([3:"hello", 4:"betty"]);
    assert(aa[3] == "hello");
    assert(aa[4] == "betty");

    auto stream = appender!(char[])();
    alias AllNumerics =
        AliasSeq!(byte, ubyte, short, ushort, int, uint, long, ulong,
                  float, double, real);
    foreach (T; AllNumerics)
    {
        T value = 1;
        stream.clear();
        formattedWrite(stream, "%s", value);
        assert(stream.data == "1");
    }

    stream.clear();
    formattedWrite(stream, "%s", aa);
}
