// Written in the D programming language.

/**
This is a submodule of $(MREF std, format).

It provides two functions for writing formatted output: $(LREF
formatValue) and $(LREF formattedWrite). The former writes a single
value. The latter writes several values at once, interspersed with
unformatted text.

The following combinations of format characters and types are
available:

$(BOOKTABLE ,
$(TR $(TH) $(TH s) $(TH c) $(TH d, u, b, o) $(TH x, X) $(TH e, E, f, F, g, G, a, A) $(TH r) $(TH compound))
$(TR $(TD `bool`) $(TD yes) $(TD $(MDASH)) $(TD yes) $(TD yes) $(TD $(MDASH)) $(TD yes) $(TD $(MDASH)))
$(TR $(TD `null`) $(TD yes) $(TD $(MDASH)) $(TD $(MDASH)) $(TD $(MDASH)) $(TD $(MDASH)) $(TD $(MDASH)) $(TD $(MDASH)))
$(TR $(TD $(I integer)) $(TD yes) $(TD $(MDASH)) $(TD yes) $(TD yes) $(TD $(MDASH)) $(TD yes) $(TD $(MDASH)))
$(TR $(TD $(I floating point)) $(TD yes) $(TD $(MDASH)) $(TD $(MDASH)) $(TD $(MDASH)) $(TD yes) $(TD yes) $(TD $(MDASH)))
$(TR $(TD $(I character)) $(TD yes) $(TD yes) $(TD yes) $(TD yes) $(TD $(MDASH)) $(TD yes) $(TD $(MDASH)))
$(TR $(TD $(I string)) $(TD yes) $(TD $(MDASH)) $(TD $(MDASH)) $(TD $(MDASH)) $(TD $(MDASH)) $(TD yes) $(TD yes))
$(TR $(TD $(I array)) $(TD yes) $(TD $(MDASH)) $(TD $(MDASH)) $(TD $(MDASH)) $(TD $(MDASH)) $(TD yes) $(TD yes))
$(TR $(TD $(I associative array)) $(TD yes) $(TD $(MDASH)) $(TD $(MDASH)) $(TD $(MDASH)) $(TD $(MDASH)) $(TD $(MDASH)) $(TD yes))
$(TR $(TD $(I pointer)) $(TD yes) $(TD $(MDASH)) $(TD $(MDASH)) $(TD yes) $(TD $(MDASH)) $(TD $(MDASH)) $(TD $(MDASH)))
$(TR $(TD $(I SIMD vectors)) $(TD yes) $(TD $(MDASH)) $(TD $(MDASH)) $(TD $(MDASH)) $(TD $(MDASH)) $(TD yes) $(TD yes))
$(TR $(TD $(I delegates)) $(TD yes) $(TD $(MDASH)) $(TD $(MDASH)) $(TD $(MDASH)) $(TD $(MDASH)) $(TD yes) $(TD yes))
)

Enums can be used with all format characters of the base type.

$(SECTION3 Structs$(COMMA) Unions$(COMMA) Classes$(COMMA) and Interfaces)

Aggregate types can define various `toString` functions. If this
function takes a $(REF_ALTTEXT FormatSpec, FormatSpec, std, format,
spec) as argument, the function decides which format characters are
accepted. If no `toString` is defined and the aggregate is an
$(REF_ALTTEXT input range, isInputRange, std, range, primitives), it
is treated like a range, that is $(B 's'), $(B 'r') and a compound
specifier are accepted. In all other cases aggregate types only
accept $(B 's').

Copyright: Copyright The D Language Foundation 2000-2013.

License: $(HTTP boost.org/LICENSE_1_0.txt, Boost License 1.0).

Authors: $(HTTP walterbright.com, Walter Bright), $(HTTP erdani.com,
Andrei Alexandrescu), and Kenji Hara

Source: $(PHOBOSSRC std/format/write.d)
 */
module std.format.write;

/**
`bool`s are formatted as `"true"` or `"false"` with `%s` and like the
`byte`s 1 and 0 with all other format characters.
 */
@safe pure unittest
{
    import std.array : appender;
    import std.format.spec : singleSpec;

    auto w1 = appender!string();
    auto spec1 = singleSpec("%s");
    formatValue(w1, true, spec1);

    assert(w1.data == "true");

    auto w2 = appender!string();
    auto spec2 = singleSpec("%#x");
    formatValue(w2, true, spec2);

    assert(w2.data == "0x1");
}

/// The `null` literal is formatted as `"null"`.
@safe pure unittest
{
    import std.array : appender;
    import std.format.spec : singleSpec;

    auto w = appender!string();
    auto spec = singleSpec("%s");
    formatValue(w, null, spec);

    assert(w.data == "null");
}

/**
Integrals are formatted in (signed) every day notation with `%s` and
`%d` and as an (unsigned) image of the underlying bit representation
with `%b` (binary), `%u` (decimal), `%o` (octal), and `%x` (hexadecimal).
 */
@safe pure unittest
{
    import std.array : appender;
    import std.format.spec : singleSpec;

    auto w1 = appender!string();
    auto spec1 = singleSpec("%d");
    formatValue(w1, -1337, spec1);

    assert(w1.data == "-1337");

    auto w2 = appender!string();
    auto spec2 = singleSpec("%x");
    formatValue(w2, -1337, spec2);

    assert(w2.data == "fffffac7");
}

/**
Floating-point values are formatted in natural notation with `%f`, in
scientific notation with `%e`, in short notation with `%g`, and in
hexadecimal scientific notation with `%a`. If a rounding mode is
available, they are rounded according to this rounding mode, otherwise
they are rounded to the nearest value, ties to even.
 */
@safe unittest
{
    import std.array : appender;
    import std.format.spec : singleSpec;

    auto w1 = appender!string();
    auto spec1 = singleSpec("%.3f");
    formatValue(w1, 1337.7779, spec1);

    assert(w1.data == "1337.778");

    auto w2 = appender!string();
    auto spec2 = singleSpec("%.3e");
    formatValue(w2, 1337.7779, spec2);

    assert(w2.data == "1.338e+03");

    auto w3 = appender!string();
    auto spec3 = singleSpec("%.3g");
    formatValue(w3, 1337.7779, spec3);

    assert(w3.data == "1.34e+03");

    auto w4 = appender!string();
    auto spec4 = singleSpec("%.3a");
    formatValue(w4, 1337.7779, spec4);

    assert(w4.data == "0x1.4e7p+10");
}

/**
Individual characters (`char`, `wchar`, or `dchar`) are formatted as
Unicode characters with `%s` and `%c` and as integers (`ubyte`,
`ushort`, `uint`) with all other format characters. With
$(MREF_ALTTEXT compound specifiers, std,format) characters are
treated differently.
 */
@safe pure unittest
{
    import std.array : appender;
    import std.format.spec : singleSpec;

    auto w1 = appender!string();
    auto spec1 = singleSpec("%c");
    formatValue(w1, 'ì', spec1);

    assert(w1.data == "ì");

    auto w2 = appender!string();
    auto spec2 = singleSpec("%#x");
    formatValue(w2, 'ì', spec2);

    assert(w2.data == "0xec");
}

/**
Strings are formatted as a sequence of characters with `%s`.
Non-printable characters are not escaped. With a compound specifier
the string is treated like a range of characters. With $(MREF_ALTTEXT
compound specifiers, std,format) strings are treated differently.
 */
@safe pure unittest
{
    import std.array : appender;
    import std.format.spec : singleSpec;

    auto w1 = appender!string();
    auto spec1 = singleSpec("%s");
    formatValue(w1, "hello", spec1);

    assert(w1.data == "hello");

    auto w2 = appender!string();
    auto spec2 = singleSpec("%(%#x%|/%)");
    formatValue(w2, "hello", spec2);

    assert(w2.data == "0x68/0x65/0x6c/0x6c/0x6f");
}

/// Static arrays are formatted as dynamic arrays.
@safe pure unittest
{
    import std.array : appender;
    import std.format.spec : singleSpec;

    auto w = appender!string();
    auto spec = singleSpec("%s");
    int[2] two = [1, 2];
    formatValue(w, two, spec);

    assert(w.data == "[1, 2]");
}

/**
Dynamic arrays are formatted as input ranges.
 */
@system pure unittest
{
    import std.array : appender;
    import std.format.spec : singleSpec;

    auto w1 = appender!string();
    auto spec1 = singleSpec("%s");
    auto two = [1, 2];
    formatValue(w1, two, spec1);

    assert(w1.data == "[1, 2]");

    auto w2 = appender!string();
    auto spec2 = singleSpec("%(%g%|, %)");
    auto consts = [3.1415926, 299792458, 6.67430e-11];
    formatValue(w2, consts, spec2);

    assert(w2.data == "3.14159, 2.99792e+08, 6.6743e-11");

    // void[] is treated like ubyte[]
    auto w3 = appender!string();
    auto spec3 = singleSpec("%s");
    void[] val = cast(void[]) cast(ubyte[])[1, 2, 3];
    formatValue(w3, val, spec3);

    assert(w3.data == "[1, 2, 3]");
}

/**
Associative arrays are formatted by using `':'` and `", "` as
separators, enclosed by `'['` and `']'` when used with `%s`. It's
also possible to use a compound specifier for better control.

Please note, that the order of the elements is not defined, therefore
the result of this function might differ.
 */
@safe pure unittest
{
    import std.array : appender;
    import std.format.spec : singleSpec;

    auto aa = [10:17.5, 20:9.99];

    auto w1 = appender!string();
    auto spec1 = singleSpec("%s");
    formatValue(w1, aa, spec1);

    assert(w1.data == "[10:17.5, 20:9.99]" || w1.data == "[20:9.99, 10:17.5]");

    auto w2 = appender!string();
    auto spec2 = singleSpec("%(%x = %.0e%| # %)");
    formatValue(w2, aa, spec2);

    assert(w2.data == "a = 2e+01 # 14 = 1e+01" || w2.data == "14 = 1e+01 # a = 2e+01");
}

/**
`enum`s are formatted as their name when used with `%s` and like
their base value else.
 */
@safe pure unittest
{
    import std.array : appender;
    import std.format.spec : singleSpec;

    enum A { first, second, third }

    auto w1 = appender!string();
    auto spec1 = singleSpec("%s");
    formatValue(w1, A.second, spec1);

    assert(w1.data == "second");

    auto w2 = appender!string();
    auto spec2 = singleSpec("%d");
    formatValue(w2, A.second, spec2);

    assert(w2.data == "1");

    // values of an enum that have no name are formatted with %s using a cast
    A a = A.third;
    a++;

    auto w3 = appender!string();
    auto spec3 = singleSpec("%s");
    formatValue(w3, a, spec3);

    assert(w3.data == "cast(A)3");
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

/// Pointers are formatted as hexadecimal integers.
@system pure unittest
{
    import std.array : appender;
    import std.format.spec : singleSpec;

    auto w1 = appender!string();
    auto spec1 = singleSpec("%s");
    auto p1 = cast(void*) 0xFFEECCAA;
    formatValue(w1, p1, spec1);

    assert(w1.data == "FFEECCAA");

    // null pointers are printed as `"null"` when used with `%s` and as hexadecimal integer else
    auto w2 = appender!string();
    auto spec2 = singleSpec("%s");
    auto p2 = cast(void*) 0x00000000;
    formatValue(w2, p2, spec2);

    assert(w2.data == "null");

    auto w3 = appender!string();
    auto spec3 = singleSpec("%x");
    formatValue(w3, p2, spec3);

    assert(w3.data == "0");
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

import std.format.internal.write;

import std.format.spec : FormatSpec;
import std.traits : isSomeString;

/**
Converts its arguments according to a format string and writes
the result to an output range.

The second version of `formattedWrite` takes the format string as a
template argument. In this case, it is checked for consistency at
compile-time.

Params:
    w = an $(REF_ALTTEXT output range, isOutputRange, std, range, primitives),
        where the formatted result is written to
    fmt = a $(MREF_ALTTEXT format string, std,format)
    args = a variadic list of arguments to be formatted
    Writer = the type of the writer `w`
    Char = character type of `fmt`
    Args = a variadic list of types of the arguments

Returns:
    The index of the last argument that was formatted. If no positional
    arguments are used, this is the number of arguments that where formatted.

Throws:
    A $(REF_ALTTEXT FormatException, FormatException, std, format)
    if formatting did not succeed.

Note:
    In theory this function should be `@nogc`. But with the current
    implementation there are some cases where allocations occur.
    See $(REF_ALTTEXT $(D sformat), sformat, std, format) for more details.
 */
uint formattedWrite(Writer, Char, Args...)(auto ref Writer w, const scope Char[] fmt, Args args)
{
    import std.conv : text;
    import std.format : enforceFmt, FormatException;
    import std.traits : isSomeChar;

    auto spec = FormatSpec!Char(fmt);

    // Are we already done with formats? Then just dump each parameter in turn
    uint currentArg = 0;
    while (spec.writeUpToNextSpec(w))
    {
        if (currentArg == Args.length && !spec.indexStart)
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

        if (spec.dynamicSeparatorChar)
        {
            auto separatorChar =
                getNth!("separator character", isSomeChar, dchar)(currentArg, args);
            spec.separatorChar = separatorChar;
            spec.dynamicSeparatorChar = false;
            ++currentArg;
        }

        if (currentArg == Args.length && !spec.indexStart)
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
            foreach (i, Tunused; Args)
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
                    static if (i + 1 < Args.length)
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
                     " index exceeds ", Args.length));
        }
    }
    return currentArg;
}

///
@safe pure unittest
{
    import std.array : appender;

    auto writer1 = appender!string();
    formattedWrite(writer1, "%s is the ultimate %s.", 42, "answer");
    assert(writer1[] == "42 is the ultimate answer.");

    auto writer2 = appender!string();
    formattedWrite(writer2, "Increase: %7.2f %%", 17.4285);
    assert(writer2[] == "Increase:   17.43 %");
}

/// ditto
uint formattedWrite(alias fmt, Writer, Args...)(auto ref Writer w, Args args)
if (isSomeString!(typeof(fmt)))
{
    import std.format : checkFormatException;

    alias e = checkFormatException!(fmt, Args);
    static assert(!e, e.msg);
    return .formattedWrite(w, fmt, args);
}

/// The format string can be checked at compile-time:
@safe pure unittest
{
    import std.array : appender;

    auto writer = appender!string();
    writer.formattedWrite!"%d is the ultimate %s."(42, "answer");
    assert(writer[] == "42 is the ultimate answer.");

    // This line doesn't compile, because 3.14 cannot be formatted with %d:
    // writer.formattedWrite!"%d is the ultimate %s."(3.14, "answer");
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
Formats a value of any type according to a format specifier and
writes the result to an output range.

More details about how types are formatted, and how the format
specifier influences the outcome, can be found in the definition of a
$(MREF_ALTTEXT format string, std,format).

Params:
    w = an $(REF_ALTTEXT output range, isOutputRange, std, range, primitives) where
        the formatted value is written to
    val = the value to write
    f = a $(REF_ALTTEXT FormatSpec, FormatSpec, std, format, spec) defining the
        format specifier
    Writer = the type of the output range `w`
    T = the type of value `val`
    Char = the character type used for `f`

Throws:
    A $(LREF FormatException) if formatting did not succeed.

Note:
    In theory this function should be `@nogc`. But with the current
    implementation there are some cases where allocations occur.
    See $(REF_ALTTEXT $(D sformat), sformat, std, format) for more details.

See_Also:
    $(LREF formattedWrite) which formats several values at once.
 */
void formatValue(Writer, T, Char)(auto ref Writer w, auto ref T val, scope const ref FormatSpec!Char f)
{
    import std.format : enforceFmt;

    enforceFmt(f.width != f.DYNAMIC && f.precision != f.DYNAMIC
               && f.separators != f.DYNAMIC && !f.dynamicSeparatorChar,
               "Dynamic argument not allowed for `formatValue`");

    formatValueImpl(w, val, f);
}

///
@safe pure unittest
{
    import std.array : appender;
    import std.format.spec : singleSpec;

    auto writer = appender!string();
    auto spec = singleSpec("%08b");
    writer.formatValue(42, spec);
    assert(writer.data == "00101010");

    spec = singleSpec("%2s");
    writer.formatValue('=', spec);
    assert(writer.data == "00101010 =");

    spec = singleSpec("%+14.6e");
    writer.formatValue(42.0, spec);
    assert(writer.data == "00101010 = +4.200000e+01");
}

// https://issues.dlang.org/show_bug.cgi?id=15386
@safe pure unittest
{
    import std.array : appender;
    import std.format.spec : FormatSpec;
    import std.format : FormatException;
    import std.exception : assertThrown;

    auto w = appender!(char[])();
    auto dor = appender!(char[])();
    auto fs = FormatSpec!char("%.*s");
    fs.writeUpToNextSpec(dor);
    assertThrown!FormatException(formatValue(w, 0, fs));

    fs = FormatSpec!char("%*s");
    fs.writeUpToNextSpec(dor);
    assertThrown!FormatException(formatValue(w, 0, fs));

    fs = FormatSpec!char("%,*s");
    fs.writeUpToNextSpec(dor);
    assertThrown!FormatException(formatValue(w, 0, fs));

    fs = FormatSpec!char("%,?s");
    fs.writeUpToNextSpec(dor);
    assertThrown!FormatException(formatValue(w, 0, fs));

    assertThrown!FormatException(formattedWrite(w, "%(%0*d%)", new int[1]));
}
