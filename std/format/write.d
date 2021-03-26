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

        if (spec.dynamicSeparatorChar)
        {
            auto separatorChar =
                getNth!("separator character", isSomeChar, dchar)(currentArg, args);
            spec.separatorChar = separatorChar;
            spec.dynamicSeparatorChar = false;
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
