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
