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

        if (spec.separatorCharPos == spec.DYNAMIC)
        {
            auto separatorChar =
                getNth!("separator character", isSomeChar, dchar)(currentArg, args);
            spec.separatorChar = separatorChar;
            spec.separatorCharPos = spec.UNSPECIFIED;
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
    import std.format : enforceFmt;

    enforceFmt(f.width != f.DYNAMIC && f.precision != f.DYNAMIC
               && f.separators != f.DYNAMIC && f.separatorCharPos != f.DYNAMIC,
               "Dynamic argument not allowed for `formatValue`");

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
