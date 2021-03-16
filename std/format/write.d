// Written in the D programming language.

/**
   This is a submodule of $(MREF std, format).
   It provides some helpful tools.

   Copyright: Copyright The D Language Foundation 2000-2013.

   License: $(HTTP boost.org/LICENSE_1_0.txt, Boost License 1.0).

   Authors: $(HTTP walterbright.com, Walter Bright), $(HTTP erdani.com,
   Andrei Alexandrescu), and Kenji Hara

   Source: $(PHOBOSSRC std/format/write.d)
 */
module std.format.write;

import std.format.internal.write;

import std.format.spec : FormatSpec;
import std.traits : isSomeString;

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
    import std.format : checkFormatException;

    alias e = checkFormatException!(fmt, A);
    static assert(!e, e.msg);
    return .formattedWrite(w, fmt, args);
}

/// The format string can be checked at compile-time (see $(REF_ALTTEXT format, format, std, format) for details):
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
    import std.format : enforceFmt, FormatException;
    import std.traits : isSomeChar;

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
    import std.format : format;

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
    import std.array;

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
 *     f = The $(REF FormatSpec, std, format, spec) defining how to write the value.
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
    import std.format.spec : singleSpec;

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
    import std.format.spec : singleSpec;

    auto w = appender!string();
    auto spec = singleSpec("%s");
    formatValue(w, true, spec);

    assert(w.data == "true");
}

/// `null` literal is formatted as `"null"`.
@safe pure unittest
{
    import std.array : appender;
    import std.format.spec : singleSpec;

    auto w = appender!string();
    auto spec = singleSpec("%s");
    formatValue(w, null, spec);

    assert(w.data == "null");
}

/// Integrals are formatted like $(REF printf, core, stdc, stdio).
@safe pure unittest
{
    import std.array : appender;
    import std.format.spec : singleSpec;

    auto w = appender!string();
    auto spec = singleSpec("%d");
    formatValue(w, 1337, spec);

    assert(w.data == "1337");
}

/// Floating-point values are formatted like $(REF printf, core, stdc, stdio)
@safe unittest
{
    import std.array : appender;
    import std.format.spec : singleSpec;

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
    import std.format.spec : singleSpec;

    auto w = appender!string();
    auto spec = singleSpec("%c");
    formatValue(w, 'a', spec);

    assert(w.data == "a");
}

/// Strings are formatted like $(REF printf, core, stdc, stdio)
@safe pure unittest
{
    import std.array : appender;
    import std.format.spec : singleSpec;

    auto w = appender!string();
    auto spec = singleSpec("%s");
    formatValue(w, "hello", spec);

    assert(w.data == "hello");
}

/// Static-size arrays are formatted as dynamic arrays.
@safe pure unittest
{
    import std.array : appender;
    import std.format.spec : singleSpec;

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
    import std.format.spec : singleSpec;

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
    import std.format.spec : singleSpec;

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
    import std.format.spec : singleSpec;

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
    import std.format.spec : FormatSpec, singleSpec;
    import std.range.primitives : isOutputRange, put;

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
   import std.format : format;
   import std.format.spec : FormatSpec;

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
    import std.format.spec : singleSpec;

    auto w = appender!string();
    auto spec = singleSpec("%s");

    auto q = cast(void*) 0xFFEECCAA;
    formatValue(w, q, spec);

    assert(w.data == "FFEECCAA");
}

/// SIMD vectors are formatted as arrays.
@safe unittest
{
    import core.simd; // cannot be selective, because float4 might not be defined
    import std.array : appender;
    import std.format.spec : singleSpec;

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

/**
 * Delegates are formatted by `ReturnType delegate(Parameters) FunctionAttributes`
 *
 * Known Bug: Function attributes are not always correct.
 *            See $(BUGZILLA 18269) for more details.
 */
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
