// Written in the D programming language.

/**
This package provides string formatting functionality using
`printf` style format strings.

$(BOOKTABLE ,
$(TR $(TH Submodule) $(TH Function Name) $(TH Description))
$(TR
    $(TD $(I package))
    $(TD $(LREF format))
    $(TD Converts its arguments according to a format string into a string.)
)
$(TR
    $(TD $(I package))
    $(TD $(LREF sformat))
    $(TD Converts its arguments according to a format string into a buffer.)
)
$(TR
    $(TD $(I package))
    $(TD $(LREF FormatException))
    $(TD Signals a problem while formatting.)
)
$(TR
    $(TD $(MREF_ALTTEXT $(D write), std, format, write))
    $(TD $(REF_ALTTEXT $(D formattedWrite), formattedWrite, std, format, write))
    $(TD Converts its arguments according to a format string and writes
         the result to an output range.)
)
$(TR
    $(TD $(MREF_ALTTEXT $(D write), std, format, write))
    $(TD $(REF_ALTTEXT $(D formatValue), formatValue, std, format, write))
    $(TD Formats a value of any type according to a format specifier and
         writes the result to an output range.)
)
$(TR
    $(TD $(MREF_ALTTEXT $(D read), std, format, read))
    $(TD $(REF_ALTTEXT $(D formattedRead), formattedRead, std, format, read))
    $(TD Reads an input range according to a format string and stores the read
         values into its arguments.)
)
$(TR
    $(TD $(MREF_ALTTEXT $(D read), std, format, read))
    $(TD $(REF_ALTTEXT $(D unformatValue), unformatValue, std, format, read))
    $(TD Reads a value from the given input range and converts it according to
         a format specifier.)
)
$(TR
    $(TD $(MREF_ALTTEXT $(D spec), std, format, spec))
    $(TD $(REF_ALTTEXT $(D FormatSpec), FormatSpec, std, format, spec))
    $(TD A general handler for format strings.)
)
$(TR
    $(TD $(MREF_ALTTEXT $(D spec), std, format, spec))
    $(TD $(REF_ALTTEXT $(D singleSpec), singleSpec, std, format, spec))
    $(TD Helper function that returns a `FormatSpec` for a single format specifier.)
))

Limitation: This package does not support localization, but
    adheres to the rounding mode of the floating point unit, if
    available.

   Format_String:

   <a name="format-string">$(I Format strings)</a>
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

    The variadic arguments are normally consumed in order.
    POSIX-style $(HTTP opengroup.org/onlinepubs/009695399/functions/printf.html,
    positional parameter syntax) is also supported. Each argument is
    formatted into a sequence of chars according to the format
    specification, and the characters are passed to `w`. As many
    arguments as specified in the format string are consumed and
    formatted. If there are fewer arguments than format specifiers, a
    `FormatException` is thrown. If there are more remaining
    arguments than needed by the format specification, they are
    ignored but only if at least one argument was formatted.

    The positional and non-positional styles can be mixed in the same
    format string. (POSIX leaves this behavior undefined.) The internal
    counter for non-positional parameters tracks the next parameter after
    the largest positional parameter already used.

    The format string supports the formatting of array and nested
    array elements via the grouping format specifiers $(B %&#40;) and
    $(B %&#41;). Each matching pair of $(B %&#40;) and $(B %&#41;)
    corresponds with a single array argument. The enclosed sub-format
    string is applied to individual array elements.  The trailing
    portion of the sub-format string following the conversion
    specifier for the array element is interpreted as the array
    delimiter, and is therefore omitted following the last array
    element. The $(B %|) specifier may be used to explicitly indicate
    the start of the delimiter, so that the preceding portion of the
    string will be included following the last array element.

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

   Aggregates:
   `struct`, `union`, `class`, and `interface` are formatted by calling `toString`.

   `toString` should have one of the following signatures:

   ---
   void toString(Writer, Char)(ref Writer w, scope const ref FormatSpec!Char fmt)
   void toString(Writer)(ref Writer w)
   string toString();
   ---

   Where `Writer` is an $(REF_ALTTEXT output range, isOutputRange, std,range,primitives)
   which accepts characters. The template type does not have to be called `Writer`.

   The following overloads are also accepted for legacy reasons or for use in virtual
   functions. It's recommended that any new code forgo these overloads if possible for
   speed and attribute acceptance reasons.

   ---
   void toString(scope void delegate(const(char)[]) sink, const ref FormatSpec!char fmt);
   void toString(scope void delegate(const(char)[]) sink, string fmt);
   void toString(scope void delegate(const(char)[]) sink);
   ---

   For the class objects which have input range interface,
   $(UL
       $(LI If the instance `toString` has overridden `Object.toString`, it is used.)
       $(LI Otherwise, the objects are formatted as input range.)
   )

   For the `struct` and `union` objects which does not have `toString`,
   $(UL
       $(LI If they have range interface, formatted as input range.)
       $(LI Otherwise, they are formatted like `Type(field1, filed2, ...)`.)
   )

   Otherwise, are formatted just as their type name.

   Copyright: Copyright The D Language Foundation 2000-2013.

   Macros:
   SUBREF = $(REF_ALTTEXT $2, $2, std, format, $1)$(NBSP)

   License: $(HTTP boost.org/LICENSE_1_0.txt, Boost License 1.0).

   Authors: $(HTTP walterbright.com, Walter Bright), $(HTTP erdani.com,
   Andrei Alexandrescu), and Kenji Hara

   Source: $(PHOBOSSRC std/format.d)
 */
module std.format;

@safe unittest
{
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

public import std.format.read;
public import std.format.spec;
public import std.format.write;

import std.exception : enforce;
import std.range.primitives : isInputRange;
import std.traits : CharTypeOf, isSomeChar, isSomeString, StringTypeOf;
import std.format.internal.write : hasToString;

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

/**
Signals an issue encountered while formatting.
 */
class FormatException : Exception
{
    /// Generic constructor.
    @safe @nogc pure nothrow
    this()
    {
        super("format error");
    }

    /**
       Creates a new instance of `FormatException`.

       Params:
           msg = message of the exception
           fn = file name of the file where the exception was created (optional)
           ln = line number of the file where the exception was created (optional)
           next = for internal use, should always be null (optional)
     */
    @safe @nogc pure nothrow
    this(string msg, string fn = __FILE__, size_t ln = __LINE__, Throwable next = null)
    {
        super(msg, fn, ln, next);
    }
}

///
@safe unittest
{
    import std.exception : assertThrown;

    assertThrown!FormatException(format("%d", "foo"));
}

package alias enforceFmt = enforce!FormatException;

// @@@DEPRECATED_[2.107.0]@@@
deprecated("formatElement was accidentally made public and will be removed in 2.107.0")
void formatElement(Writer, T, Char)(auto ref Writer w, T val, scope const ref FormatSpec!Char f)
if (is(StringTypeOf!T) && !hasToString!(T, Char) && !is(T == enum))
{
    import std.format.internal.write : fe = formatElement;

    fe(w, val, f);
}

// @@@DEPRECATED_[2.107.0]@@@
deprecated("formatElement was accidentally made public and will be removed in 2.107.0")
void formatElement(Writer, T, Char)(auto ref Writer w, T val, scope const ref FormatSpec!Char f)
if (is(CharTypeOf!T) && !is(T == enum))
{
    import std.format.internal.write : fe = formatElement;

    fe(w, val, f);
}

// @@@DEPRECATED_[2.107.0]@@@
deprecated("formatElement was accidentally made public and will be removed in 2.107.0")
void formatElement(Writer, T, Char)(auto ref Writer w, auto ref T val, scope const ref FormatSpec!Char f)
if ((!is(StringTypeOf!T) || hasToString!(T, Char)) && !is(CharTypeOf!T) || is(T == enum))
{
    import std.format.internal.write : fe = formatElement;

    fe(w, val, f);
}

// Like NullSink, but toString() isn't even called at all. Used to test the format string.
package struct NoOpSink
{
    void put(E)(scope const E) pure @safe @nogc nothrow {}
}

/* ======================== Unit Tests ====================================== */

version (StdUnittest)
package void formatTest(T)(T val, string expected, size_t ln = __LINE__, string fn = __FILE__)
{
    import core.exception : AssertError;
    import std.array : appender;
    import std.conv : text;

    FormatSpec!char f;
    auto w = appender!string();
    formatValue(w, val, f);
    enforce!AssertError(w.data == expected,
        text("expected = `", expected, "`, result = `", w.data, "`"), fn, ln);
}

version (StdUnittest)
package void formatTest(T)(string fmt, T val, string expected, size_t ln = __LINE__, string fn = __FILE__) @safe
{
    import core.exception : AssertError;
    import std.array : appender;
    import std.conv : text;

    auto w = appender!string();
    formattedWrite(w, fmt, val);
    enforce!AssertError(w.data == expected,
        text("expected = `", expected, "`, result = `", w.data, "`"), fn, ln);
}

version (StdUnittest)
package void formatTest(T)(T val, string[] expected, size_t ln = __LINE__, string fn = __FILE__)
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
    enforce!AssertError(false,
        text("expected one of `", expected, "`, result = `", w.data, "`"), fn, ln);
}

version (StdUnittest)
package void formatTest(T)(string fmt, T val, string[] expected, size_t ln = __LINE__, string fn = __FILE__) @safe
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
    enforce!AssertError(false,
        text("expected one of `", expected, "`, result = `", w.data, "`"), fn, ln);
}

@safe pure unittest
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
    import std.exception : collectExceptionMsg;

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
    import std.array : appender;
    import std.conv : text, octal;

    auto stream = appender!(char[])();

    formattedWrite(stream, "hello world! %s %s ", true, 57, 1_000_000_000, 'x', " foo");
    assert(stream.data == "hello world! true 57 ", stream.data);
    stream.clear();

    formattedWrite(stream, "%g %A %s", 1.67, -1.28, float.nan);
    assert(stream.data == "1.67 -0X1.47AE147AE147BP+0 nan", stream.data);
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

    formattedWrite(stream, "%a %A", 1.32, 6.78f);
    assert(stream.data == "0x1.51eb851eb851fp+0 0X1.B1EB86P+2");
    stream.clear();

    formattedWrite(stream, "%#06.*f", 2, 12.345);
    assert(stream.data == "012.35");
    stream.clear();

    formattedWrite(stream, "%#0*.*f", 6, 2, 12.345);
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

    formattedWrite(stream, "%04f|%05d|%#05x|%#5x", -4.0, -10, 1, 1);
    assert(stream.data == "-4.000000|-0010|0x001|  0x1", stream.data);
    stream.clear();

    int i;
    string s;

    i = -10;
    formattedWrite(stream, "%d|%3d|%03d|%1d|%01.4f", i, i, i, i, cast(double) i);
    assert(stream.data == "-10|-10|-10|-10|-10.0000");
    stream.clear();

    i = -5;
    formattedWrite(stream, "%d|%3d|%03d|%1d|%01.4f", i, i, i, i, cast(double) i);
    assert(stream.data == "-5| -5|-05|-5|-5.0000");
    stream.clear();

    i = 0;
    formattedWrite(stream, "%d|%3d|%03d|%1d|%01.4f", i, i, i, i, cast(double) i);
    assert(stream.data == "0|  0|000|0|0.0000");
    stream.clear();

    i = 5;
    formattedWrite(stream, "%d|%3d|%03d|%1d|%01.4f", i, i, i, i, cast(double) i);
    assert(stream.data == "5|  5|005|5|5.0000");
    stream.clear();

    i = 10;
    formattedWrite(stream, "%d|%3d|%03d|%1d|%01.4f", i, i, i, i, cast(double) i);
    assert(stream.data == "10| 10|010|10|10.0000");
    stream.clear();

    formattedWrite(stream, "%.0d", 0);
    assert(stream.data == "");
    stream.clear();

    formattedWrite(stream, "%.g", .34);
    assert(stream.data == "0.3");
    stream.clear();

    stream.clear();
    formattedWrite(stream, "%.0g", .34);
    assert(stream.data == "0.3");

    stream.clear();
    formattedWrite(stream, "%.2g", .34);
    assert(stream.data == "0.34");

    stream.clear();
    formattedWrite(stream, "%0.0008f", 1e-08);
    assert(stream.data == "0.00000001");

    stream.clear();
    formattedWrite(stream, "%0.0008f", 1e-05);
    assert(stream.data == "0.00001000");

    s = "helloworld";
    string r;
    stream.clear();
    formattedWrite(stream, "%.2s", s[0 .. 5]);
    assert(stream.data == "he");
    stream.clear();
    formattedWrite(stream, "%.20s", s[0 .. 5]);
    assert(stream.data == "hello");
    stream.clear();
    formattedWrite(stream, "%8s", s[0 .. 5]);
    assert(stream.data == "   hello");

    byte[] arrbyte = new byte[4];
    arrbyte[0] = 100;
    arrbyte[1] = -99;
    arrbyte[3] = 0;
    stream.clear();
    formattedWrite(stream, "%s", arrbyte);
    assert(stream.data == "[100, -99, 0, 0]", stream.data);

    ubyte[] arrubyte = new ubyte[4];
    arrubyte[0] = 100;
    arrubyte[1] = 200;
    arrubyte[3] = 0;
    stream.clear();
    formattedWrite(stream, "%s", arrubyte);
    assert(stream.data == "[100, 200, 0, 0]", stream.data);

    short[] arrshort = new short[4];
    arrshort[0] = 100;
    arrshort[1] = -999;
    arrshort[3] = 0;
    stream.clear();
    formattedWrite(stream, "%s", arrshort);
    assert(stream.data == "[100, -999, 0, 0]");
    stream.clear();
    formattedWrite(stream, "%s", arrshort);
    assert(stream.data == "[100, -999, 0, 0]");

    ushort[] arrushort = new ushort[4];
    arrushort[0] = 100;
    arrushort[1] = 20_000;
    arrushort[3] = 0;
    stream.clear();
    formattedWrite(stream, "%s", arrushort);
    assert(stream.data == "[100, 20000, 0, 0]");

    int[] arrint = new int[4];
    arrint[0] = 100;
    arrint[1] = -999;
    arrint[3] = 0;
    stream.clear();
    formattedWrite(stream, "%s", arrint);
    assert(stream.data == "[100, -999, 0, 0]");
    stream.clear();
    formattedWrite(stream, "%s", arrint);
    assert(stream.data == "[100, -999, 0, 0]");

    long[] arrlong = new long[4];
    arrlong[0] = 100;
    arrlong[1] = -999;
    arrlong[3] = 0;
    stream.clear();
    formattedWrite(stream, "%s", arrlong);
    assert(stream.data == "[100, -999, 0, 0]");
    stream.clear();
    formattedWrite(stream, "%s",arrlong);
    assert(stream.data == "[100, -999, 0, 0]");

    ulong[] arrulong = new ulong[4];
    arrulong[0] = 100;
    arrulong[1] = 999;
    arrulong[3] = 0;
    stream.clear();
    formattedWrite(stream, "%s", arrulong);
    assert(stream.data == "[100, 999, 0, 0]");

    string[] arr2 = new string[4];
    arr2[0] = "hello";
    arr2[1] = "world";
    arr2[3] = "foo";
    stream.clear();
    formattedWrite(stream, "%s", arr2);
    assert(stream.data == `["hello", "world", "", "foo"]`, stream.data);

    stream.clear();
    formattedWrite(stream, "%.8d", 7);
    assert(stream.data == "00000007");

    stream.clear();
    formattedWrite(stream, "%.8x", 10);
    assert(stream.data == "0000000a");

    stream.clear();
    formattedWrite(stream, "%-3d", 7);
    assert(stream.data == "7  ");

    stream.clear();
    formattedWrite(stream, "%*d", -3, 7);
    assert(stream.data == "7  ");

    stream.clear();
    formattedWrite(stream, "%.*d", -3, 7);
    assert(stream.data == "7");

    stream.clear();
    formattedWrite(stream, "%s", "abc"c);
    assert(stream.data == "abc");
    stream.clear();
    formattedWrite(stream, "%s", "def"w);
    assert(stream.data == "def", text(stream.data.length));
    stream.clear();
    formattedWrite(stream, "%s", "ghi"d);
    assert(stream.data == "ghi");

    @trusted void* deadBeef() { return cast(void*) 0xDEADBEEF; }
    stream.clear();
    formattedWrite(stream, "%s", deadBeef());
    assert(stream.data == "DEADBEEF", stream.data);

    stream.clear();
    formattedWrite(stream, "%#x", 0xabcd);
    assert(stream.data == "0xabcd");
    stream.clear();
    formattedWrite(stream, "%#X", 0xABCD);
    assert(stream.data == "0XABCD");

    stream.clear();
    formattedWrite(stream, "%#o", octal!12345);
    assert(stream.data == "012345");
    stream.clear();
    formattedWrite(stream, "%o", 9);
    assert(stream.data == "11");

    stream.clear();
    formattedWrite(stream, "%+d", 123);
    assert(stream.data == "+123");
    stream.clear();
    formattedWrite(stream, "%+d", -123);
    assert(stream.data == "-123");
    stream.clear();
    formattedWrite(stream, "% d", 123);
    assert(stream.data == " 123");
    stream.clear();
    formattedWrite(stream, "% d", -123);
    assert(stream.data == "-123");

    stream.clear();
    formattedWrite(stream, "%%");
    assert(stream.data == "%");

    stream.clear();
    formattedWrite(stream, "%d", true);
    assert(stream.data == "1");
    stream.clear();
    formattedWrite(stream, "%d", false);
    assert(stream.data == "0");

    stream.clear();
    formattedWrite(stream, "%d", 'a');
    assert(stream.data == "97", stream.data);
    wchar wc = 'a';
    stream.clear();
    formattedWrite(stream, "%d", wc);
    assert(stream.data == "97");
    dchar dc = 'a';
    stream.clear();
    formattedWrite(stream, "%d", dc);
    assert(stream.data == "97");

    byte b = byte.max;
    stream.clear();
    formattedWrite(stream, "%x", b);
    assert(stream.data == "7f");
    stream.clear();
    formattedWrite(stream, "%x", ++b);
    assert(stream.data == "80");
    stream.clear();
    formattedWrite(stream, "%x", ++b);
    assert(stream.data == "81");

    short sh = short.max;
    stream.clear();
    formattedWrite(stream, "%x", sh);
    assert(stream.data == "7fff");
    stream.clear();
    formattedWrite(stream, "%x", ++sh);
    assert(stream.data == "8000");
    stream.clear();
    formattedWrite(stream, "%x", ++sh);
    assert(stream.data == "8001");

    i = int.max;
    stream.clear();
    formattedWrite(stream, "%x", i);
    assert(stream.data == "7fffffff");
    stream.clear();
    formattedWrite(stream, "%x", ++i);
    assert(stream.data == "80000000");
    stream.clear();
    formattedWrite(stream, "%x", ++i);
    assert(stream.data == "80000001");

    stream.clear();
    formattedWrite(stream, "%x", 10);
    assert(stream.data == "a");
    stream.clear();
    formattedWrite(stream, "%X", 10);
    assert(stream.data == "A");
    stream.clear();
    formattedWrite(stream, "%x", 15);
    assert(stream.data == "f");
    stream.clear();
    formattedWrite(stream, "%X", 15);
    assert(stream.data == "F");

    @trusted void ObjectTest()
    {
        Object c = null;
        stream.clear();
        formattedWrite(stream, "%s", c);
        assert(stream.data == "null");
    }
    ObjectTest();

    enum TestEnum
    {
        Value1, Value2
    }
    stream.clear();
    formattedWrite(stream, "%s", TestEnum.Value2);
    assert(stream.data == "Value2", stream.data);
    stream.clear();
    formattedWrite(stream, "%s", cast(TestEnum) 5);
    assert(stream.data == "cast(TestEnum)5", stream.data);

    //immutable(char[5])[int] aa = ([3:"hello", 4:"betty"]);
    //stream.clear();
    //formattedWrite(stream, "%s", aa.values);
    //assert(stream.data == "[[h,e,l,l,o],[b,e,t,t,y]]");
    //stream.clear();
    //formattedWrite(stream, "%s", aa);
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

    stream.clear();
    formattedWrite(stream, "%.-3d", 7);
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

@system unittest
{
    string s = "hello!124:34.5";
    string a;
    int b;
    double c;
    formattedRead(s, "%s!%s:%s", &a, &b, &c);
    assert(a == "hello" && b == 124 && c == 34.5);
}

version (StdUnittest)
private void formatReflectTest(T)(ref T val, string fmt, string formatted, string fn = __FILE__, size_t ln = __LINE__)
{
    import core.exception : AssertError;
    import std.array : appender;
    import std.traits : isAssociativeArray;

    auto w = appender!string();
    formattedWrite(w, fmt, val);

    auto input = w.data;
    enforce!AssertError(input == formatted, input, fn, ln);

    T val2;
    formattedRead(input, fmt, &val2);

    static if (isAssociativeArray!T)
        if (__ctfe)
        {
            alias aa1 = val;
            alias aa2 = val2;
            assert(aa1 == aa2);

            assert(aa1.length == aa2.length);

            assert(aa1.keys == aa2.keys);

            assert(aa1.values == aa2.values);
            assert(aa1.values.length == aa2.values.length);
            foreach (i; 0 .. aa1.values.length)
                assert(aa1.values[i] == aa2.values[i]);

            foreach (i, key; aa1.keys)
                assert(aa1.values[i] == aa1[key]);
            foreach (i, key; aa2.keys)
                assert(aa2.values[i] == aa2[key]);
            return;
        }

    enforce!AssertError(val == val2, input, fn, ln);
}

version (StdUnittest)
private void formatReflectTest(T)(ref T val, string fmt, string[] formatted, string fn = __FILE__, size_t ln = __LINE__)
{
    import core.exception : AssertError;
    import std.array : appender;
    import std.traits : isAssociativeArray;

    auto w = appender!string();
    formattedWrite(w, fmt, val);

    auto input = w.data;

    foreach (cur; formatted)
    {
        if (input == cur) return;
    }
    enforce!AssertError(false, input, fn, ln);

    T val2;
    formattedRead(input, fmt, &val2);

    static if (isAssociativeArray!T)
        if (__ctfe)
        {
            alias aa1 = val;
            alias aa2 = val2;
            assert(aa1 == aa2);

            assert(aa1.length == aa2.length);

            assert(aa1.keys == aa2.keys);

            assert(aa1.values == aa2.values);
            assert(aa1.values.length == aa2.values.length);
            foreach (i; 0 .. aa1.values.length)
                assert(aa1.values[i] == aa2.values[i]);

            foreach (i, key; aa1.keys)
                assert(aa1.values[i] == aa1[key]);
            foreach (i, key; aa2.keys)
                assert(aa2.values[i] == aa2[key]);
            return;
        }

    enforce!AssertError(val == val2, input, fn, ln);
}

@system unittest
{
    void booleanTest()
    {
        auto b = true;
        formatReflectTest(b, "%s", `true`);
        formatReflectTest(b, "%b", `1`);
        formatReflectTest(b, "%o", `1`);
        formatReflectTest(b, "%d", `1`);
        formatReflectTest(b, "%u", `1`);
        formatReflectTest(b, "%x", `1`);
    }

    void integerTest()
    {
        auto n = 127;
        formatReflectTest(n, "%s", `127`);
        formatReflectTest(n, "%b", `1111111`);
        formatReflectTest(n, "%o", `177`);
        formatReflectTest(n, "%d", `127`);
        formatReflectTest(n, "%u", `127`);
        formatReflectTest(n, "%x", `7f`);
    }

    void floatingTest()
    {
        auto f = 3.14;
        formatReflectTest(f, "%s", `3.14`);
        formatReflectTest(f, "%e", `3.140000e+00`);
        formatReflectTest(f, "%f", `3.140000`);
        formatReflectTest(f, "%g", `3.14`);
    }

    void charTest()
    {
        auto c = 'a';
        formatReflectTest(c, "%s", `a`);
        formatReflectTest(c, "%c", `a`);
        formatReflectTest(c, "%b", `1100001`);
        formatReflectTest(c, "%o", `141`);
        formatReflectTest(c, "%d", `97`);
        formatReflectTest(c, "%u", `97`);
        formatReflectTest(c, "%x", `61`);
    }

    void strTest()
    {
        auto s = "hello";
        formatReflectTest(s, "%s",              `hello`);
        formatReflectTest(s, "%(%c,%)",         `h,e,l,l,o`);
        formatReflectTest(s, "%(%s,%)",         `'h','e','l','l','o'`);
        formatReflectTest(s, "[%(<%c>%| $ %)]", `[<h> $ <e> $ <l> $ <l> $ <o>]`);
    }

    void daTest()
    {
        auto a = [1,2,3,4];
        formatReflectTest(a, "%s",              `[1, 2, 3, 4]`);
        formatReflectTest(a, "[%(%s; %)]",      `[1; 2; 3; 4]`);
        formatReflectTest(a, "[%(<%s>%| $ %)]", `[<1> $ <2> $ <3> $ <4>]`);
    }

    void saTest()
    {
        int[4] sa = [1,2,3,4];
        formatReflectTest(sa, "%s",              `[1, 2, 3, 4]`);
        formatReflectTest(sa, "[%(%s; %)]",      `[1; 2; 3; 4]`);
        formatReflectTest(sa, "[%(<%s>%| $ %)]", `[<1> $ <2> $ <3> $ <4>]`);
    }

    void aaTest()
    {
        auto aa = [1:"hello", 2:"world"];
        formatReflectTest(aa, "%s",                    [`[1:"hello", 2:"world"]`, `[2:"world", 1:"hello"]`]);
        formatReflectTest(aa, "[%(%s->%s, %)]",        [`[1->"hello", 2->"world"]`, `[2->"world", 1->"hello"]`]);
        formatReflectTest(aa, "{%([%s=%(%c%)]%|; %)}", [`{[1=hello]; [2=world]}`, `{[2=world]; [1=hello]}`]);
    }

    import std.exception : assertCTFEable;

    assertCTFEable!(
    {
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

// @@@DEPRECATED_[2.107.0]@@@
deprecated("unformatElement was accidentally made public and will be removed in 2.107.0")
T unformatElement(T, Range, Char)(ref Range input, scope const ref FormatSpec!Char spec)
if (isInputRange!Range)
{
    import std.format.internal.read : ue = unformatElement;

    return ue(input, spec);
}

/* ======================== Unit Tests ====================================== */

@system unittest
{
    int i;
    string s;

    s = format("hello world! %s %s %s%s%s", true, 57, 1_000_000_000, 'x', " foo");
    assert(s == "hello world! true 57 1000000000x foo");

    s = format("%s %A %s", 1.67, -1.28, float.nan);
    assert(s == "1.67 -0X1.47AE147AE147BP+0 nan", s);

    s = format("%x %X", 0x1234AF, 0xAFAFAFAF);
    assert(s == "1234af AFAFAFAF");

    s = format("%b %o", 0x1234AF, 0xAFAFAFAF);
    assert(s == "100100011010010101111 25753727657");

    s = format("%d %s", 0x1234AF, 0xAFAFAFAF);
    assert(s == "1193135 2947526575");
}

@system unittest
{
    import std.conv : octal;

    string s;
    int i;

    s = format("%#06.*f", 2, 12.345);
    assert(s == "012.35");

    s = format("%#0*.*f", 6, 2, 12.345);
    assert(s == "012.35");

    s = format("%7.4g:", 12.678);
    assert(s == "  12.68:");

    s = format("%7.4g:", 12.678L);
    assert(s == "  12.68:");

    s = format("%04f|%05d|%#05x|%#5x", -4.0, -10, 1, 1);
    assert(s == "-4.000000|-0010|0x001|  0x1");

    i = -10;
    s = format("%d|%3d|%03d|%1d|%01.4f", i, i, i, i, cast(double) i);
    assert(s == "-10|-10|-10|-10|-10.0000");

    i = -5;
    s = format("%d|%3d|%03d|%1d|%01.4f", i, i, i, i, cast(double) i);
    assert(s == "-5| -5|-05|-5|-5.0000");

    i = 0;
    s = format("%d|%3d|%03d|%1d|%01.4f", i, i, i, i, cast(double) i);
    assert(s == "0|  0|000|0|0.0000");

    i = 5;
    s = format("%d|%3d|%03d|%1d|%01.4f", i, i, i, i, cast(double) i);
    assert(s == "5|  5|005|5|5.0000");

    i = 10;
    s = format("%d|%3d|%03d|%1d|%01.4f", i, i, i, i, cast(double) i);
    assert(s == "10| 10|010|10|10.0000");

    s = format("%.0d", 0);
    assert(s == "");

    s = format("%.g", .34);
    assert(s == "0.3");

    s = format("%.0g", .34);
    assert(s == "0.3");

    s = format("%.2g", .34);
    assert(s == "0.34");

    s = format("%0.0008f", 1e-08);
    assert(s == "0.00000001");

    s = format("%0.0008f", 1e-05);
    assert(s == "0.00001000");

    s = "helloworld";
    string r;
    r = format("%.2s", s[0 .. 5]);
    assert(r == "he");
    r = format("%.20s", s[0 .. 5]);
    assert(r == "hello");
    r = format("%8s", s[0 .. 5]);
    assert(r == "   hello");

    byte[] arrbyte = new byte[4];
    arrbyte[0] = 100;
    arrbyte[1] = -99;
    arrbyte[3] = 0;
    r = format("%s", arrbyte);
    assert(r == "[100, -99, 0, 0]");

    ubyte[] arrubyte = new ubyte[4];
    arrubyte[0] = 100;
    arrubyte[1] = 200;
    arrubyte[3] = 0;
    r = format("%s", arrubyte);
    assert(r == "[100, 200, 0, 0]");

    short[] arrshort = new short[4];
    arrshort[0] = 100;
    arrshort[1] = -999;
    arrshort[3] = 0;
    r = format("%s", arrshort);
    assert(r == "[100, -999, 0, 0]");

    ushort[] arrushort = new ushort[4];
    arrushort[0] = 100;
    arrushort[1] = 20_000;
    arrushort[3] = 0;
    r = format("%s", arrushort);
    assert(r == "[100, 20000, 0, 0]");

    int[] arrint = new int[4];
    arrint[0] = 100;
    arrint[1] = -999;
    arrint[3] = 0;
    r = format("%s", arrint);
    assert(r == "[100, -999, 0, 0]");

    long[] arrlong = new long[4];
    arrlong[0] = 100;
    arrlong[1] = -999;
    arrlong[3] = 0;
    r = format("%s", arrlong);
    assert(r == "[100, -999, 0, 0]");

    ulong[] arrulong = new ulong[4];
    arrulong[0] = 100;
    arrulong[1] = 999;
    arrulong[3] = 0;
    r = format("%s", arrulong);
    assert(r == "[100, 999, 0, 0]");

    string[] arr2 = new string[4];
    arr2[0] = "hello";
    arr2[1] = "world";
    arr2[3] = "foo";
    r = format("%s", arr2);
    assert(r == `["hello", "world", "", "foo"]`);

    r = format("%.8d", 7);
    assert(r == "00000007");
    r = format("%.8x", 10);
    assert(r == "0000000a");

    r = format("%-3d", 7);
    assert(r == "7  ");

    r = format("%-1*d", 4, 3);
    assert(r == "3   ");

    r = format("%*d", -3, 7);
    assert(r == "7  ");

    r = format("%.*d", -3, 7);
    assert(r == "7");

    r = format("%-1.*f", 2, 3.1415);
    assert(r == "3.14");

    r = format("abc"c);
    assert(r == "abc");

    //format() returns the same type as inputted.
    wstring wr;
    wr = format("def"w);
    assert(wr == "def"w);

    dstring dr;
    dr = format("ghi"d);
    assert(dr == "ghi"d);

    // Empty static character arrays work as well
    const char[0] cempty;
    assert(format("test%spath", cempty) == "testpath");
    const wchar[0] wempty;
    assert(format("test%spath", wempty) == "testpath");
    const dchar[0] dempty;
    assert(format("test%spath", dempty) == "testpath");

    void* p = cast(void*) 0xDEADBEEF;
    r = format("%s", p);
    assert(r == "DEADBEEF");

    r = format("%#x", 0xabcd);
    assert(r == "0xabcd");
    r = format("%#X", 0xABCD);
    assert(r == "0XABCD");

    r = format("%#o", octal!12345);
    assert(r == "012345");
    r = format("%o", 9);
    assert(r == "11");
    r = format("%#o", 0);   // https://issues.dlang.org/show_bug.cgi?id=15663
    assert(r == "0");

    r = format("%+d", 123);
    assert(r == "+123");
    r = format("%+d", -123);
    assert(r == "-123");
    r = format("% d", 123);
    assert(r == " 123");
    r = format("% d", -123);
    assert(r == "-123");

    r = format("%%");
    assert(r == "%");

    r = format("%d", true);
    assert(r == "1");
    r = format("%d", false);
    assert(r == "0");

    r = format("%d", 'a');
    assert(r == "97");
    wchar wc = 'a';
    r = format("%d", wc);
    assert(r == "97");
    dchar dc = 'a';
    r = format("%d", dc);
    assert(r == "97");

    byte b = byte.max;
    r = format("%x", b);
    assert(r == "7f");
    r = format("%x", ++b);
    assert(r == "80");
    r = format("%x", ++b);
    assert(r == "81");

    short sh = short.max;
    r = format("%x", sh);
    assert(r == "7fff");
    r = format("%x", ++sh);
    assert(r == "8000");
    r = format("%x", ++sh);
    assert(r == "8001");

    i = int.max;
    r = format("%x", i);
    assert(r == "7fffffff");
    r = format("%x", ++i);
    assert(r == "80000000");
    r = format("%x", ++i);
    assert(r == "80000001");

    r = format("%x", 10);
    assert(r == "a");
    r = format("%X", 10);
    assert(r == "A");
    r = format("%x", 15);
    assert(r == "f");
    r = format("%X", 15);
    assert(r == "F");

    Object c = null;
    r = format("%s", c);
    assert(r == "null");

    enum TestEnum
    {
        Value1, Value2
    }
    r = format("%s", TestEnum.Value2);
    assert(r == "Value2");

    immutable(char[5])[int] aa = ([3:"hello", 4:"betty"]);
    r = format("%s", aa.values);
    assert(r == `["hello", "betty"]` || r == `["betty", "hello"]`);
    r = format("%s", aa);
    assert(r == `[3:"hello", 4:"betty"]` || r == `[4:"betty", 3:"hello"]`);

    static const dchar[] ds = ['a','b'];
    for (int j = 0; j < ds.length; ++j)
    {
        r = format(" %d", ds[j]);
        if (j == 0)
            assert(r == " 97");
        else
            assert(r == " 98");
    }

    r = format(">%14d<, %s", 15, [1,2,3]);
    assert(r == ">            15<, [1, 2, 3]");

    assert(format("%8s", "bar") == "     bar");
    assert(format("%8s", "b\u00e9ll\u00f4") == "   b\u00e9ll\u00f4");
}

// https://issues.dlang.org/show_bug.cgi?id=18205
@safe pure unittest
{
    assert("|%8s|".format("abc")       == "|     abc|");
    assert("|%8s|".format("αβγ")       == "|     αβγ|");
    assert("|%8s|".format("   ")       == "|        |");
    assert("|%8s|".format("été"d)      == "|     été|");
    assert("|%8s|".format("été 2018"w) == "|été 2018|");

    assert("%2s".format("e\u0301"w) == " e\u0301");
    assert("%2s".format("a\u0310\u0337"d) == " a\u0310\u0337");
}

// https://issues.dlang.org/show_bug.cgi?id=3479
@safe unittest
{
    import std.array : appender;

    auto stream = appender!(char[])();
    formattedWrite(stream, "%2$.*1$d", 12, 10);
    assert(stream.data == "000000000010", stream.data);
}

// https://issues.dlang.org/show_bug.cgi?id=6893
@safe unittest
{
    import std.array : appender;

    enum E : ulong { A, B, C }
    auto stream = appender!(char[])();
    formattedWrite(stream, "%s", E.C);
    assert(stream.data == "C");
}

// Used to check format strings are compatible with argument types
package(std) static const checkFormatException(alias fmt, Args...) =
{
    import std.conv : text;

    try
    {
        auto n = .formattedWrite(NoOpSink(), fmt, Args.init);

        enforceFmt(n == Args.length, text("Orphan format arguments: args[", n, "..", Args.length, "]"));
    }
    catch (Exception e)
        return e;
    return null;
}();

/**
Converts its arguments according to a format string into a string.

The second version of `format` takes the format string as template
argument. In this case, it is checked for consistency at
compile-time and produces slightly faster code, because the length of
the output buffer can be estimated in advance.

Params:
    fmt = a $(MREF_ALTTEXT format string, std,format)
    args = a variadic list of arguments to be formatted
    Char = character type of `fmt`
    Args = a variadic list of types of the arguments

Returns:
    The formatted string.

Throws:
    A $(LREF FormatException) if formatting did not succeed.

See_Also:
    $(LREF sformat) for a variant, that tries to avoid garbage collection.
 */
immutable(Char)[] format(Char, Args...)(in Char[] fmt, Args args)
if (isSomeChar!Char)
{
    import std.array : appender;

    auto w = appender!(immutable(Char)[]);
    auto n = formattedWrite(w, fmt, args);
    version (all)
    {
        // In the future, this check will be removed to increase consistency
        // with formattedWrite
        import std.conv : text;
        enforceFmt(n == args.length, text("Orphan format arguments: args[", n, "..", args.length, "]"));
    }
    return w.data;
}

///
@safe pure unittest
{
    assert(format("Here are %d %s.", 3, "apples") == "Here are 3 apples.");

    assert("Increase: %7.2f %%".format(17.4285) == "Increase:   17.43 %");
}

@safe pure unittest
{
    import std.exception : assertCTFEable, assertThrown;

    assertCTFEable!(
    {
        assert(format("foo") == "foo");
        assert(format("foo%%") == "foo%");
        assert(format("foo%s", 'C') == "fooC");
        assert(format("%s foo", "bar") == "bar foo");
        assert(format("%s foo %s", "bar", "abc") == "bar foo abc");
        assert(format("foo %d", -123) == "foo -123");
        assert(format("foo %d", 123) == "foo 123");

        assertThrown!FormatException(format("foo %s"));
        assertThrown!FormatException(format("foo %s", 123, 456));

        assert(format("hel%slo%s%s%s", "world", -138, 'c', true) == "helworldlo-138ctrue");
    });

    assert(is(typeof(format("happy")) == string));
    assert(is(typeof(format("happy"w)) == wstring));
    assert(is(typeof(format("happy"d)) == dstring));
}

// https://issues.dlang.org/show_bug.cgi?id=16661
@safe pure unittest
{
    assert(format("%.2f"d, 0.4) == "0.40");
    assert("%02d"d.format(1) == "01"d);
}

/// ditto
typeof(fmt) format(alias fmt, Args...)(Args args)
if (isSomeString!(typeof(fmt)))
{
    import std.array : appender;
    import std.range.primitives : ElementEncodingType;
    import std.traits : Unqual;

    alias e = checkFormatException!(fmt, Args);
    alias Char = Unqual!(ElementEncodingType!(typeof(fmt)));

    static assert(!e, e.msg);
    auto w = appender!(immutable(Char)[]);

    // no need to traverse the string twice during compile time
    if (!__ctfe)
    {
        enum len = guessLength!Char(fmt);
        w.reserve(len);
    }
    else
    {
        w.reserve(fmt.length);
    }

    formattedWrite(w, fmt, args);
    return w.data;
}

/// The format string can be checked at compile-time:
@safe pure unittest
{
    auto s = format!"%s is %s"("Pi", 3.14);
    assert(s == "Pi is 3.14");

    // This line doesn't compile, because 3.14 cannot be formatted with %d:
    // s = format!"%s is %d"("Pi", 3.14);
}

@safe pure unittest
{
    string s;
    static assert(!__traits(compiles, {s = format!"%l"();}));     // missing arg
    static assert(!__traits(compiles, {s = format!""(404);}));    // surplus arg
    static assert(!__traits(compiles, {s = format!"%d"(4.03);})); // incompatible arg
}

// https://issues.dlang.org/show_bug.cgi?id=17381
@safe pure unittest
{
    static assert(!__traits(compiles, format!"%s"(1.5, 2)));
    static assert(!__traits(compiles, format!"%f"(1.5, 2)));
    static assert(!__traits(compiles, format!"%s"(1.5L, 2)));
    static assert(!__traits(compiles, format!"%f"(1.5L, 2)));
}

// called during compilation to guess the length of the
// result of format
private size_t guessLength(Char, S)(S fmtString)
{
    import std.array : appender;

    size_t len;
    auto output = appender!(immutable(Char)[])();
    auto spec = FormatSpec!Char(fmtString);
    while (spec.writeUpToNextSpec(output))
    {
        // take a guess
        if (spec.width == 0 && (spec.precision == spec.UNSPECIFIED || spec.precision == spec.DYNAMIC))
        {
            switch (spec.spec)
            {
                case 'c':
                    ++len;
                    break;
                case 'd':
                case 'x':
                case 'X':
                    len += 3;
                    break;
                case 'b':
                    len += 8;
                    break;
                case 'f':
                case 'F':
                    len += 10;
                    break;
                case 's':
                case 'e':
                case 'E':
                case 'g':
                case 'G':
                    len += 12;
                    break;
                default: break;
            }

            continue;
        }

        if ((spec.spec == 'e' || spec.spec == 'E' || spec.spec == 'g' ||
             spec.spec == 'G' || spec.spec == 'f' || spec.spec == 'F') &&
            spec.precision != spec.UNSPECIFIED && spec.precision != spec.DYNAMIC &&
            spec.width == 0
        )
        {
            len += spec.precision + 5;
            continue;
        }

        if (spec.width == spec.precision)
            len += spec.width;
        else if (spec.width > 0 && spec.width != spec.DYNAMIC &&
                 (spec.precision == spec.UNSPECIFIED || spec.width > spec.precision))
        {
            len += spec.width;
        }
        else if (spec.precision != spec.UNSPECIFIED && spec.precision > spec.width)
            len += spec.precision;
    }
    len += output.data.length;
    return len;
}

@safe pure
unittest
{
    assert(guessLength!char("%c") == 1);
    assert(guessLength!char("%d") == 3);
    assert(guessLength!char("%x") == 3);
    assert(guessLength!char("%b") == 8);
    assert(guessLength!char("%f") == 10);
    assert(guessLength!char("%s") == 12);
    assert(guessLength!char("%02d") == 2);
    assert(guessLength!char("%02d") == 2);
    assert(guessLength!char("%4.4d") == 4);
    assert(guessLength!char("%2.4f") == 4);
    assert(guessLength!char("%02d:%02d:%02d") == 8);
    assert(guessLength!char("%0.2f") == 7);
    assert(guessLength!char("%0*d") == 0);
}

/**
Converts its arguments according to a format string into a buffer.
The buffer has to be large enough to hold the formatted string.

The second version of `sformat` takes the format string as a template
argument. In this case, it is checked for consistency at
compile-time.

Params:
    buf = the buffer where the formatted string should go
    fmt = a $(MREF_ALTTEXT format string, std,format)
    args = a variadic list of arguments to be formatted
    Char = character type of `fmt`
    Args = a variadic list of types of the arguments

Returns:
    A slice of `buf` containing the formatted string.

Throws:
    A $(REF_ALTTEXT RangeError, RangeError, core, exception) if `buf`
    isn't large enough to hold the formatted string
    and a $(LREF FormatException) if formatting did not succeed.

Note:
    In theory this function should be `@nogc`. But with the current
    implementation there are some cases where allocations occur:

    $(UL
    $(LI An exception is thrown.)
    $(LI A floating point number of type `real` is formatted.)
    $(LI The representation of a floating point number exceeds 500 characters.)
    $(LI A custom `toString` function of a compound type allocates.))
 */
char[] sformat(Char, Args...)(return scope char[] buf, scope const(Char)[] fmt, Args args)
{
    import core.exception : RangeError;
    import std.range.primitives;
    import std.utf : encode;

    static struct Sink
    {
        char[] buf;
        size_t i;
        void put(dchar c)
        {
            char[4] enc;
            auto n = encode(enc, c);

            if (buf.length < i + n)
                throw new RangeError(__FILE__, __LINE__);

            buf[i .. i + n] = enc[0 .. n];
            i += n;
        }
        void put(scope const(char)[] s)
        {
            if (buf.length < i + s.length)
                throw new RangeError(__FILE__, __LINE__);

            buf[i .. i + s.length] = s[];
            i += s.length;
        }
        void put(scope const(wchar)[] s)
        {
            for (; !s.empty; s.popFront())
                put(s.front);
        }
        void put(scope const(dchar)[] s)
        {
            for (; !s.empty; s.popFront())
                put(s.front);
        }
    }
    auto sink = Sink(buf);
    auto n = formattedWrite(sink, fmt, args);
    version (all)
    {
        // In the future, this check will be removed to increase consistency
        // with formattedWrite
        import std.conv : text;
        enforceFmt(
            n == args.length,
            text("Orphan format arguments: args[", n, " .. ", args.length, "]")
        );
    }
    return buf[0 .. sink.i];
}

/// ditto
char[] sformat(alias fmt, Args...)(char[] buf, Args args)
if (isSomeString!(typeof(fmt)))
{
    alias e = checkFormatException!(fmt, Args);
    static assert(!e, e.msg);
    return .sformat(buf, fmt, args);
}

///
@safe pure unittest
{
    char[20] buf;
    assert(sformat(buf[], "Here are %d %s.", 3, "apples") == "Here are 3 apples.");

    assert(buf[].sformat("Increase: %7.2f %%", 17.4285) == "Increase:   17.43 %");
}

/// The format string can be checked at compile-time:
@safe pure unittest
{
    char[20] buf;

    assert(sformat!"Here are %d %s."(buf[], 3, "apples") == "Here are 3 apples.");

    // This line doesn't compile, because 3.14 cannot be formatted with %d:
    // writeln(sformat!"Here are %d %s."(buf[], 3.14, "apples"));
}

// checking, what is implicitly and explicitly stated in the public unittest
@system unittest
{
    import std.exception : assertThrown;

    char[20] buf;
    assertThrown!FormatException(sformat(buf[], "Here are %d %s.", 3.14, "apples"));
    assert(!__traits(compiles, sformat!"Here are %d %s."(buf[], 3.14, "apples")));
}

@system unittest
{
    import core.exception : RangeError;
    import std.exception : assertCTFEable, assertThrown;

    assertCTFEable!(
    {
        char[10] buf;

        assert(sformat(buf[], "foo") == "foo");
        assert(sformat(buf[], "foo%%") == "foo%");
        assert(sformat(buf[], "foo%s", 'C') == "fooC");
        assert(sformat(buf[], "%s foo", "bar") == "bar foo");
        assertThrown!RangeError(sformat(buf[], "%s foo %s", "bar", "abc"));
        assert(sformat(buf[], "foo %d", -123) == "foo -123");
        assert(sformat(buf[], "foo %d", 123) == "foo 123");

        assertThrown!FormatException(sformat(buf[], "foo %s"));
        assertThrown!FormatException(sformat(buf[], "foo %s", 123, 456));

        assert(sformat(buf[], "%s %s %s", "c"c, "w"w, "d"d) == "c w d");
    });
}

@system unittest // ensure that sformat avoids the GC
{
    import core.memory : GC;

    const a = ["foo", "bar"];
    const u = GC.stats().usedSize;
    char[20] buf;
    sformat(buf, "%d", 123);
    sformat(buf, "%s", a);
    sformat(buf, "%s", 'c');
    assert(u == GC.stats().usedSize);
}

/*
 * The .ptr is unsafe because it could be dereferenced and the length of the array may be 0.
 * Returns:
 *      the difference between the starts of the arrays
 */
package ptrdiff_t arrayPtrDiff(T)(const T[] array1, const T[] array2) @trusted pure nothrow @nogc
{
    return array1.ptr - array2.ptr;
}

@safe unittest
{
    import std.exception : assertCTFEable;

    assertCTFEable!(
    {
        auto tmp = format("%,d", 1000);
        assert(tmp == "1,000", "'" ~ tmp ~ "'");

        tmp = format("%,?d", 'z', 1234567);
        assert(tmp == "1z234z567", "'" ~ tmp ~ "'");

        tmp = format("%10,?d", 'z', 1234567);
        assert(tmp == " 1z234z567", "'" ~ tmp ~ "'");

        tmp = format("%11,2?d", 'z', 1234567);
        assert(tmp == " 1z23z45z67", "'" ~ tmp ~ "'");

        tmp = format("%11,*?d", 2, 'z', 1234567);
        assert(tmp == " 1z23z45z67", "'" ~ tmp ~ "'");

        tmp = format("%11,*d", 2, 1234567);
        assert(tmp == " 1,23,45,67", "'" ~ tmp ~ "'");

        tmp = format("%11,2d", 1234567);
        assert(tmp == " 1,23,45,67", "'" ~ tmp ~ "'");
    });
}

@safe unittest
{
    auto tmp = format("%,f", 1000.0);
    assert(tmp == "1,000.000000", "'" ~ tmp ~ "'");

    tmp = format("%,f", 1234567.891011);
    assert(tmp == "1,234,567.891011", "'" ~ tmp ~ "'");

    tmp = format("%,f", -1234567.891011);
    assert(tmp == "-1,234,567.891011", "'" ~ tmp ~ "'");

    tmp = format("%,2f", 1234567.891011);
    assert(tmp == "1,23,45,67.891011", "'" ~ tmp ~ "'");

    tmp = format("%18,f", 1234567.891011);
    assert(tmp == "  1,234,567.891011", "'" ~ tmp ~ "'");

    tmp = format("%18,?f", '.', 1234567.891011);
    assert(tmp == "  1.234.567.891011", "'" ~ tmp ~ "'");

    tmp = format("%,?.3f", 'ä', 1234567.891011);
    assert(tmp == "1ä234ä567.891", "'" ~ tmp ~ "'");

    tmp = format("%,*?.3f", 1, 'ä', 1234567.891011);
    assert(tmp == "1ä2ä3ä4ä5ä6ä7.891", "'" ~ tmp ~ "'");

    tmp = format("%,4?.3f", '_', 1234567.891011);
    assert(tmp == "123_4567.891", "'" ~ tmp ~ "'");

    tmp = format("%12,3.3f", 1234.5678);
    assert(tmp == "   1,234.568", "'" ~ tmp ~ "'");

    tmp = format("%,e", 3.141592653589793238462);
    assert(tmp == "3.141593e+00", "'" ~ tmp ~ "'");

    tmp = format("%15,e", 3.141592653589793238462);
    assert(tmp == "   3.141593e+00", "'" ~ tmp ~ "'");

    tmp = format("%15,e", -3.141592653589793238462);
    assert(tmp == "  -3.141593e+00", "'" ~ tmp ~ "'");

    tmp = format("%.4,*e", 2, 3.141592653589793238462);
    assert(tmp == "3.1416e+00", "'" ~ tmp ~ "'");

    tmp = format("%13.4,*e", 2, 3.141592653589793238462);
    assert(tmp == "   3.1416e+00", "'" ~ tmp ~ "'");

    tmp = format("%,.0f", 3.14);
    assert(tmp == "3", "'" ~ tmp ~ "'");

    tmp = format("%3,g", 1_000_000.123456);
    assert(tmp == "1e+06", "'" ~ tmp ~ "'");

    tmp = format("%19,?f", '.', -1234567.891011);
    assert(tmp == "  -1.234.567.891011", "'" ~ tmp ~ "'");
}

// Test for multiple indexes
@safe unittest
{
    auto tmp = format("%2:5$s", 1, 2, 3, 4, 5);
    assert(tmp == "2345", tmp);
}

// https://issues.dlang.org/show_bug.cgi?id=18047
@safe unittest
{
    auto cmp = "     123,456";
    assert(cmp.length == 12, format("%d", cmp.length));
    auto tmp = format("%12,d", 123456);
    assert(tmp.length == 12, format("%d", tmp.length));

    assert(tmp == cmp, "'" ~ tmp ~ "'");
}

// https://issues.dlang.org/show_bug.cgi?id=17459
@safe unittest
{
    auto cmp = "100";
    auto tmp  = format("%0d", 100);
    assert(tmp == cmp, tmp);

    cmp = "0100";
    tmp  = format("%04d", 100);
    assert(tmp == cmp, tmp);

    cmp = "0,000,000,100";
    tmp  = format("%012,3d", 100);
    assert(tmp == cmp, tmp);

    cmp = "0,000,001,000";
    tmp = format("%012,3d", 1_000);
    assert(tmp == cmp, tmp);

    cmp = "0,000,100,000";
    tmp = format("%012,3d", 100_000);
    assert(tmp == cmp, tmp);

    cmp = "0,001,000,000";
    tmp = format("%012,3d", 1_000_000);
    assert(tmp == cmp, tmp);

    cmp = "0,100,000,000";
    tmp = format("%012,3d", 100_000_000);
    assert(tmp == cmp, tmp);
}

// https://issues.dlang.org/show_bug.cgi?id=17459
@safe unittest
{
    auto cmp = "100,000";
    auto tmp  = format("%06,d", 100_000);
    assert(tmp == cmp, tmp);

    cmp = "100,000";
    tmp  = format("%07,d", 100_000);
    assert(tmp == cmp, tmp);

    cmp = "0,100,000";
    tmp  = format("%08,d", 100_000);
    assert(tmp == cmp, tmp);
}

// https://issues.dlang.org/show_bug.cgi?id=20288
@safe unittest
{
    string s = format("%,.2f", double.nan);
    assert(s == "nan", s);

    s = format("%,.2F", double.nan);
    assert(s == "NAN", s);

    s = format("%,.2f", -double.nan);
    assert(s == "-nan", s);

    s = format("%,.2F", -double.nan);
    assert(s == "-NAN", s);

    string g = format("^%13s$", "nan");
    string h = "^          nan$";
    assert(g == h, "\ngot:" ~ g ~ "\nexp:" ~ h);
    string a = format("^%13,3.2f$", double.nan);
    string b = format("^%13,3.2F$", double.nan);
    string c = format("^%13,3.2f$", -double.nan);
    string d = format("^%13,3.2F$", -double.nan);
    assert(a == "^          nan$", "\ngot:'"~ a ~ "'\nexp:'^          nan$'");
    assert(b == "^          NAN$", "\ngot:'"~ b ~ "'\nexp:'^          NAN$'");
    assert(c == "^         -nan$", "\ngot:'"~ c ~ "'\nexp:'^         -nan$'");
    assert(d == "^         -NAN$", "\ngot:'"~ d ~ "'\nexp:'^         -NAN$'");

    a = format("^%-13,3.2f$", double.nan);
    b = format("^%-13,3.2F$", double.nan);
    c = format("^%-13,3.2f$", -double.nan);
    d = format("^%-13,3.2F$", -double.nan);
    assert(a == "^nan          $", "\ngot:'"~ a ~ "'\nexp:'^nan          $'");
    assert(b == "^NAN          $", "\ngot:'"~ b ~ "'\nexp:'^NAN          $'");
    assert(c == "^-nan         $", "\ngot:'"~ c ~ "'\nexp:'^-nan         $'");
    assert(d == "^-NAN         $", "\ngot:'"~ d ~ "'\nexp:'^-NAN         $'");

    a = format("^%+13,3.2f$", double.nan);
    b = format("^%+13,3.2F$", double.nan);
    c = format("^%+13,3.2f$", -double.nan);
    d = format("^%+13,3.2F$", -double.nan);
    assert(a == "^         +nan$", "\ngot:'"~ a ~ "'\nexp:'^         +nan$'");
    assert(b == "^         +NAN$", "\ngot:'"~ b ~ "'\nexp:'^         +NAN$'");
    assert(c == "^         -nan$", "\ngot:'"~ c ~ "'\nexp:'^         -nan$'");
    assert(d == "^         -NAN$", "\ngot:'"~ d ~ "'\nexp:'^         -NAN$'");

    a = format("^%-+13,3.2f$", double.nan);
    b = format("^%-+13,3.2F$", double.nan);
    c = format("^%-+13,3.2f$", -double.nan);
    d = format("^%-+13,3.2F$", -double.nan);
    assert(a == "^+nan         $", "\ngot:'"~ a ~ "'\nexp:'^+nan         $'");
    assert(b == "^+NAN         $", "\ngot:'"~ b ~ "'\nexp:'^+NAN         $'");
    assert(c == "^-nan         $", "\ngot:'"~ c ~ "'\nexp:'^-nan         $'");
    assert(d == "^-NAN         $", "\ngot:'"~ d ~ "'\nexp:'^-NAN         $'");

    a = format("^%- 13,3.2f$", double.nan);
    b = format("^%- 13,3.2F$", double.nan);
    c = format("^%- 13,3.2f$", -double.nan);
    d = format("^%- 13,3.2F$", -double.nan);
    assert(a == "^ nan         $", "\ngot:'"~ a ~ "'\nexp:'^ nan         $'");
    assert(b == "^ NAN         $", "\ngot:'"~ b ~ "'\nexp:'^ NAN         $'");
    assert(c == "^-nan         $", "\ngot:'"~ c ~ "'\nexp:'^-nan         $'");
    assert(d == "^-NAN         $", "\ngot:'"~ d ~ "'\nexp:'^-NAN         $'");
}
