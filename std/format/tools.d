// Written in the D programming language.

/**
   This is a submodule of $(MREF std, format).
   It provides some helpful tools.

   Copyright: Copyright The D Language Foundation 2000-2013.

   License: $(HTTP boost.org/LICENSE_1_0.txt, Boost License 1.0).

   Authors: $(HTTP walterbright.com, Walter Bright), $(HTTP erdani.com,
   Andrei Alexandrescu), and Kenji Hara

   Source: $(PHOBOSSRC std/format/tools.d)
 */
module std.format.tools;

import std.format;
import std.traits;
import std.range.primitives;
import std.exception;

package enum ctfpMessage = "Cannot format floating point types at compile-time";

/**
Signals a mismatch between a format and its corresponding argument.
 */
class FormatException : Exception
{
    @safe @nogc pure nothrow
    this()
    {
        super("format error");
    }

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


template FormatSpec(Char)
if (!is(Unqual!Char == Char))
{
    alias FormatSpec = FormatSpec!(Unqual!Char);
}

/**
 * A General handler for `printf` style format specifiers. Used for building more
 * specific formatting functions.
 */
struct FormatSpec(Char)
if (is(Unqual!Char == Char))
{
    import std.algorithm.searching : startsWith;
    import std.ascii : isDigit, isPunctuation, isAlpha;
    import std.conv : parse, text, to;

    /**
       Minimum _width, default `0`.
     */
    int width = 0;

    /**
       Precision. Its semantics depends on the argument type. For
       floating point numbers, _precision dictates the number of
       decimals printed.
     */
    int precision = UNSPECIFIED;

    /**
       Number of digits printed between _separators.
    */
    int separators = UNSPECIFIED;

    /**
       Set to `DYNAMIC` when the separator character is supplied at runtime.
    */
    int separatorCharPos = UNSPECIFIED;

    /**
       Character to insert between digits.
    */
    dchar separatorChar = ',';

    /**
       Special value for width and precision. `DYNAMIC` width or
       precision means that they were specified with `'*'` in the
       format string and are passed at runtime through the varargs.
     */
    enum int DYNAMIC = int.max;

    /**
       Special value for precision, meaning the format specifier
       contained no explicit precision.
     */
    enum int UNSPECIFIED = DYNAMIC - 1;

    /**
       The actual format specifier, `'s'` by default.
    */
    char spec = 's';

    /**
       Index of the argument for positional parameters, from `1` to
       `ubyte.max`. (`0` means not used).
    */
    ubyte indexStart;

    /**
       Index of the last argument for positional parameter range, from
       `1` to `ubyte.max`. (`0` means not used).
    */
    ubyte indexEnd;

    version (StdDdoc)
    {
        /**
         The format specifier contained a `'-'` (`printf`
         compatibility).
         */
        bool flDash;

        /**
         The format specifier contained a `'0'` (`printf`
         compatibility).
         */
        bool flZero;

        /**
         The format specifier contained a $(D ' ') (`printf`
         compatibility).
         */
        bool flSpace;

        /**
         The format specifier contained a `'+'` (`printf`
         compatibility).
         */
        bool flPlus;

        /**
         The format specifier contained a `'#'` (`printf`
         compatibility).
         */
        bool flHash;

        /**
         The format specifier contained a `','`
         */
        bool flSeparator;

        // Fake field to allow compilation
        ubyte allFlags;
    }
    else
    {
        union
        {
            import std.bitmanip : bitfields;
            mixin(bitfields!(
                        bool, "flDash", 1,
                        bool, "flZero", 1,
                        bool, "flSpace", 1,
                        bool, "flPlus", 1,
                        bool, "flHash", 1,
                        bool, "flSeparator", 1,
                        ubyte, "", 2));
            ubyte allFlags;
        }
    }

    /**
       In case of a compound format specifier starting with $(D
       "%$(LPAREN)") and ending with `"%$(RPAREN)"`, `_nested`
       contains the string contained within the two separators.
     */
    const(Char)[] nested;

    /**
       In case of a compound format specifier, `_sep` contains the
       string positioning after `"%|"`.
       `sep is null` means no separator else `sep.empty` means 0 length
        separator.
     */
    const(Char)[] sep;

    /**
       `_trailing` contains the rest of the format string.
     */
    const(Char)[] trailing;

    /*
       This string is inserted before each sequence (e.g. array)
       formatted (by default `"["`).
     */
    enum immutable(Char)[] seqBefore = "[";

    /*
       This string is inserted after each sequence formatted (by
       default `"]"`).
     */
    enum immutable(Char)[] seqAfter = "]";

    /*
       This string is inserted after each element keys of a sequence (by
       default `":"`).
     */
    enum immutable(Char)[] keySeparator = ":";

    /*
       This string is inserted in between elements of a sequence (by
       default $(D ", ")).
     */
    enum immutable(Char)[] seqSeparator = ", ";

    /**
       Construct a new `FormatSpec` using the format string `fmt`, no
       processing is done until needed.
     */
    this(in Char[] fmt) @safe pure
    {
        trailing = fmt;
    }

    /**
       Write the format string to an output range until the next format
       specifier is found and parse that format specifier.

       See $(LREF FormatSpec) for an example, how to use `writeUpToNextSpec`.

       Params:
           writer = the $(REF_ALTTEXT output range, isOutputRange, std, range, primitives)

       Returns:
           True, when a format specifier is found.

       Throws:
           A $(LREF FormatException) when the found format specifier
           could not be parsed.
     */
    bool writeUpToNextSpec(OutputRange)(ref OutputRange writer) scope
    {
        if (trailing.empty)
            return false;
        for (size_t i = 0; i < trailing.length; ++i)
        {
            if (trailing[i] != '%') continue;
            put(writer, trailing[0 .. i]);
            trailing = trailing[i .. $];
            enforceFmt(trailing.length >= 2, `Unterminated format specifier: "%"`);
            trailing = trailing[1 .. $];

            if (trailing[0] != '%')
            {
                // Spec found. Fill up the spec, and bailout
                fillUp();
                return true;
            }
            // Doubled! Reset and Keep going
            i = 0;
        }
        // no format spec found
        put(writer, trailing);
        trailing = null;
        return false;
    }

    private void fillUp() scope
    {
        // Reset content
        if (__ctfe)
        {
            flDash = false;
            flZero = false;
            flSpace = false;
            flPlus = false;
            flHash = false;
            flSeparator = false;
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
                // Get the matching balanced paren
                for (uint innerParens;;)
                {
                    enforceFmt(j + 1 < trailing.length,
                        text("Incorrect format specifier: %", trailing[i .. $]));
                    if (trailing[j++] != '%')
                    {
                        // skip, we're waiting for %( and %)
                        continue;
                    }
                    if (trailing[j] == '-') // for %-(
                    {
                        ++j;    // skip
                        enforceFmt(j < trailing.length,
                            text("Incorrect format specifier: %", trailing[i .. $]));
                    }
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
                            throw new FormatException(
                                text("Incorrect format specifier: %",
                                        trailing[j .. $]));
                    }
                    nested = trailing[i + 1 .. k - 1];
                    sep = trailing[k + 1 .. j - 1];
                }
                else
                {
                    nested = trailing[i + 1 .. j - 1];
                    sep = null; // no separator
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
                    width = -parse!(typeof(width))(trailing);
                    i = 0;
                    enforceFmt(trailing[i++] == '$',
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
                const widthOrArgIndex = parse!uint(tmp);
                enforceFmt(tmp.length,
                    text("Incorrect format specifier %", trailing[i .. $]));
                i = arrayPtrDiff(tmp, trailing);
                if (tmp.startsWith('$'))
                {
                    // index of the form %n$
                    indexEnd = indexStart = to!ubyte(widthOrArgIndex);
                    ++i;
                }
                else if (tmp.startsWith(':'))
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
                        indexEnd = parse!(typeof(indexEnd))(tmp);
                    }
                    i = arrayPtrDiff(tmp, trailing);
                    enforceFmt(trailing[i++] == '$',
                        "$ expected");
                }
                else
                {
                    // width
                    width = to!int(widthOrArgIndex);
                }
                break;
            case ',':
                // Precision
                ++i;
                flSeparator = true;

                if (trailing[i] == '*')
                {
                    ++i;
                    // read result
                    separators = DYNAMIC;
                }
                else if (isDigit(trailing[i]))
                {
                    auto tmp = trailing[i .. $];
                    separators = parse!int(tmp);
                    i = arrayPtrDiff(tmp, trailing);
                }
                else
                {
                    // "," was specified, but nothing after it
                    separators = 3;
                }

                if (trailing[i] == '?')
                {
                    separatorCharPos = DYNAMIC;
                    ++i;
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
                        precision = -parse!int(trailing);
                        enforceFmt(trailing[i++] == '$',
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
                    parse!int(tmp); // skip digits
                    i = arrayPtrDiff(tmp, trailing);
                }
                else if (isDigit(trailing[i]))
                {
                    auto tmp = trailing[i .. $];
                    precision = parse!int(tmp);
                    i = arrayPtrDiff(tmp, trailing);
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
        throw new FormatException(text("Incorrect format specifier: ", trailing));
    }

    //--------------------------------------------------------------------------
    package bool readUpToNextSpec(R)(ref R r) scope
    {
        import std.ascii : isLower, isWhite;
        import std.utf : stride;

        // Reset content
        if (__ctfe)
        {
            flDash = false;
            flZero = false;
            flSpace = false;
            flPlus = false;
            flHash = false;
            flSeparator = false;
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
            const c = trailing[0];
            if (c == '%' && trailing.length > 1)
            {
                const c2 = trailing[1];
                if (c2 == '%')
                {
                    assert(!r.empty, "Required at least one more input");
                    // Require a '%'
                    if (r.front != '%') break;
                    trailing = trailing[2 .. $];
                    r.popFront();
                }
                else
                {
                    enforceFmt(isLower(c2) || c2 == '*' ||
                            c2 == '(',
                            text("'%", c2,
                                    "' not supported with formatted read"));
                    trailing = trailing[1 .. $];
                    fillUp();
                    return true;
                }
            }
            else
            {
                if (c == ' ')
                {
                    while (!r.empty && isWhite(r.front)) r.popFront();
                    //r = std.algorithm.find!(not!(isWhite))(r);
                }
                else
                {
                    enforceFmt(!r.empty,
                            text("parseToFormatSpec: Cannot find character '",
                                    c, "' in the input string."));
                    if (r.front != trailing.front) break;
                    r.popFront();
                }
                trailing = trailing[stride(trailing, 0) .. $];
            }
        }
        return false;
    }

    package string getCurFmtStr() const
    {
        import std.array : appender;
        auto w = appender!string();
        auto f = FormatSpec!Char("%s"); // for stringnize

        put(w, '%');
        if (indexStart != 0)
        {
            formatValue(w, indexStart, f);
            put(w, '$');
        }
        if (flDash)  put(w, '-');
        if (flZero)  put(w, '0');
        if (flSpace) put(w, ' ');
        if (flPlus)  put(w, '+');
        if (flHash)  put(w, '#');
        if (flSeparator)  put(w, ',');
        if (width != 0)
            formatValue(w, width, f);
        if (precision != FormatSpec!Char.UNSPECIFIED)
        {
            put(w, '.');
            formatValue(w, precision, f);
        }
        put(w, spec);
        return w.data;
    }

    private const(Char)[] headUpToNextSpec()
    {
        import std.array : appender;
        auto w = appender!(typeof(return))();
        auto tr = trailing;

        while (tr.length)
        {
            if (tr[0] == '%')
            {
                if (tr.length > 1 && tr[1] == '%')
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

    /**
     * Gives a string containing all of the member variables on their own
     * line.
     *
     * Params:
     *     writer = A `char` accepting
     *     $(REF_ALTTEXT output range, isOutputRange, std, range, primitives)
     * Returns:
     *     A `string` when not using an output range; `void` otherwise.
     */
    string toString() const @safe pure
    {
        import std.array : appender;
        auto app = appender!string();
        app.reserve(200 + trailing.length);
        toString(app);
        return app.data;
    }

    /// ditto
    void toString(OutputRange)(ref OutputRange writer) const
    if (isOutputRange!(OutputRange, char))
    {
        auto s = singleSpec("%s");

        put(writer, "address = ");
        formatValue(writer, &this, s);
        put(writer, "\nwidth = ");
        formatValue(writer, width, s);
        put(writer, "\nprecision = ");
        formatValue(writer, precision, s);
        put(writer, "\nspec = ");
        formatValue(writer, spec, s);
        put(writer, "\nindexStart = ");
        formatValue(writer, indexStart, s);
        put(writer, "\nindexEnd = ");
        formatValue(writer, indexEnd, s);
        put(writer, "\nflDash = ");
        formatValue(writer, flDash, s);
        put(writer, "\nflZero = ");
        formatValue(writer, flZero, s);
        put(writer, "\nflSpace = ");
        formatValue(writer, flSpace, s);
        put(writer, "\nflPlus = ");
        formatValue(writer, flPlus, s);
        put(writer, "\nflHash = ");
        formatValue(writer, flHash, s);
        put(writer, "\nflSeparator = ");
        formatValue(writer, flSeparator, s);
        put(writer, "\nnested = ");
        formatValue(writer, nested, s);
        put(writer, "\ntrailing = ");
        formatValue(writer, trailing, s);
        put(writer, '\n');
    }
}

@safe unittest
{
    import std.array;
    import std.conv : text;
    auto w = appender!(char[])();
    auto f = FormatSpec!char("abc%sdef%sghi");
    f.writeUpToNextSpec(w);
    assert(w.data == "abc", w.data);
    assert(f.trailing == "def%sghi", text(f.trailing));
    f.writeUpToNextSpec(w);
    assert(w.data == "abcdef", w.data);
    assert(f.trailing == "ghi");
    // test with embedded %%s
    f = FormatSpec!char("ab%%cd%%ef%sg%%h%sij");
    w.clear();
    f.writeUpToNextSpec(w);
    assert(w.data == "ab%cd%ef" && f.trailing == "g%%h%sij", w.data);
    f.writeUpToNextSpec(w);
    assert(w.data == "ab%cd%efg%h" && f.trailing == "ij");
    // https://issues.dlang.org/show_bug.cgi?id=4775
    f = FormatSpec!char("%%%s");
    w.clear();
    f.writeUpToNextSpec(w);
    assert(w.data == "%" && f.trailing == "");
    f = FormatSpec!char("%%%%%s%%");
    w.clear();
    while (f.writeUpToNextSpec(w)) continue;
    assert(w.data == "%%%");

    f = FormatSpec!char("a%%b%%c%");
    w.clear();
    assertThrown!FormatException(f.writeUpToNextSpec(w));
    assert(w.data == "a%b%c" && f.trailing == "%");
}

// https://issues.dlang.org/show_bug.cgi?id=5237
@safe unittest
{
    import std.array;
    auto w = appender!string();
    auto f = FormatSpec!char("%.16f");
    f.writeUpToNextSpec(w); // dummy eating
    assert(f.spec == 'f');
    auto fmt = f.getCurFmtStr();
    assert(fmt == "%.16f");
}

///
@safe pure unittest
{
    import std.array;
    auto a = appender!(string)();
    auto fmt = "Number: %6.4e\nString: %s";
    auto f = FormatSpec!char(fmt);

    assert(f.writeUpToNextSpec(a) == true);

    assert(a.data == "Number: ");
    assert(f.trailing == "\nString: %s");
    assert(f.spec == 'e');
    assert(f.width == 6);
    assert(f.precision == 4);

    assert(f.writeUpToNextSpec(a) == true);

    assert(a.data == "Number: \nString: ");
    assert(f.trailing == "");
    assert(f.spec == 's');

    assert(f.writeUpToNextSpec(a) == false);
    assert(a.data == "Number: \nString: ");
}

// https://issues.dlang.org/show_bug.cgi?id=14059
@safe unittest
{
    import std.array : appender;
    auto a = appender!(string)();

    auto f = FormatSpec!char("%-(%s%"); // %)")
    assertThrown!FormatException(f.writeUpToNextSpec(a));

    f = FormatSpec!char("%(%-"); // %)")
    assertThrown!FormatException(f.writeUpToNextSpec(a));
}

@safe unittest
{
    import std.array : appender;
    auto a = appender!(string)();

    auto f = FormatSpec!char("%,d");
    f.writeUpToNextSpec(a);

    assert(f.spec == 'd', format("%s", f.spec));
    assert(f.precision == FormatSpec!char.UNSPECIFIED);
    assert(f.separators == 3);

    f = FormatSpec!char("%5,10f");
    f.writeUpToNextSpec(a);
    assert(f.spec == 'f', format("%s", f.spec));
    assert(f.separators == 10);
    assert(f.width == 5);

    f = FormatSpec!char("%5,10.4f");
    f.writeUpToNextSpec(a);
    assert(f.spec == 'f', format("%s", f.spec));
    assert(f.separators == 10);
    assert(f.width == 5);
    assert(f.precision == 4);
}

@safe pure unittest
{
    import std.algorithm.searching : canFind, findSplitBefore;
    auto expected = "width = 2" ~
        "\nprecision = 5" ~
        "\nspec = f" ~
        "\nindexStart = 0" ~
        "\nindexEnd = 0" ~
        "\nflDash = false" ~
        "\nflZero = false" ~
        "\nflSpace = false" ~
        "\nflPlus = false" ~
        "\nflHash = false" ~
        "\nflSeparator = false" ~
        "\nnested = " ~
        "\ntrailing = \n";
    auto spec = singleSpec("%2.5f");
    auto res = spec.toString();
    // make sure the address exists, then skip it
    assert(res.canFind("address"));
    assert(res.findSplitBefore("width")[1] == expected);
}

/**
Helper function that returns a `FormatSpec` for a single specifier given
in `fmt`.

Params:
    fmt = A format specifier.

Returns:
    A `FormatSpec` with the specifier parsed.
Throws:
    A `FormatException` when more than one specifier is given or the specifier
    is malformed.
  */
FormatSpec!Char singleSpec(Char)(Char[] fmt)
{
    import std.conv : text;
    enforceFmt(fmt.length >= 2, "fmt must be at least 2 characters long");
    enforceFmt(fmt.front == '%', "fmt must start with a '%' character");

    static struct DummyOutputRange {
        void put(C)(scope const C[] buf) {} // eat elements
    }
    auto a = DummyOutputRange();
    auto spec = FormatSpec!Char(fmt);
    //dummy write
    spec.writeUpToNextSpec(a);

    enforceFmt(spec.trailing.empty,
            text("Trailing characters in fmt string: '", spec.trailing));

    return spec;
}

///
@safe pure unittest
{
    import std.exception : assertThrown;
    auto spec = singleSpec("%2.3e");

    assert(spec.trailing == "");
    assert(spec.spec == 'e');
    assert(spec.width == 2);
    assert(spec.precision == 3);

    assertThrown!FormatException(singleSpec(""));
    assertThrown!FormatException(singleSpec("2.3e"));
    assertThrown!FormatException(singleSpec("%2.3eTest"));
}

/*****************************
 * The .ptr is unsafe because it could be dereferenced and the length of the array may be 0.
 * Returns:
 *      the difference between the starts of the arrays
 */
@trusted private pure nothrow @nogc
    ptrdiff_t arrayPtrDiff(T)(const T[] array1, const T[] array2)
{
    return array1.ptr - array2.ptr;
}

// Like NullSink, but toString() isn't even called at all. Used to test the format string.
package struct NoOpSink
{
    void put(E)(scope const E) pure @safe @nogc nothrow {}
}

/**
 * Format arguments into a string.
 *
 * If the format string is fixed, passing it as a template parameter checks the
 * type correctness of the parameters at compile-time. This also can result in
 * better performance.
 *
 * Params: fmt  = Format string. For detailed specification, see $(REF_ALTTEXT formattedWrite, formattedWrite, format,write).
 *         args = Variadic list of arguments to format into returned string.
 *
 * Throws:
 *     $(LREF, FormatException) if the number of arguments doesn't match the number
 *     of format parameters and vice-versa.
 */
typeof(fmt) format(alias fmt, Args...)(Args args)
if (isSomeString!(typeof(fmt)))
{
    import std.array : appender;

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

/// Type checking can be done when fmt is known at compile-time:
@safe unittest
{
    auto s = format!"%s is %s"("Pi", 3.14);
    assert(s == "Pi is 3.14");

    static assert(!__traits(compiles, {s = format!"%l"();}));     // missing arg
    static assert(!__traits(compiles, {s = format!""(404);}));    // surplus arg
    static assert(!__traits(compiles, {s = format!"%d"(4.03);})); // incompatible arg
}

/// ditto
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

@safe unittest
{
    assertCTFEable!({
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

@system unittest
{
    import std.conv : octal;

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

version (TestComplex)
deprecated
@system unittest
{
        string s = format("%s", 1.2 + 3.4i);
        assert(s == "1.2+3.4i", s);
}

@system unittest
{
    import std.conv : octal;

    string s;
    int i;

    s = format("%#06.*f",2,12.345);
    assert(s == "012.35");

    s = format("%#0*.*f",6,2,12.345);
    assert(s == "012.35");

    s = format("%7.4g:", 12.678);
    assert(s == "  12.68:");

    s = format("%7.4g:", 12.678L);
    assert(s == "  12.68:");

    s = format("%04f|%05d|%#05x|%#5x",-4.0,-10,1,1);
    assert(s == "-4.000000|-0010|0x001|  0x1");

    i = -10;
    s = format("%d|%3d|%03d|%1d|%01.4f",i,i,i,i,cast(double) i);
    assert(s == "-10|-10|-10|-10|-10.0000");

    i = -5;
    s = format("%d|%3d|%03d|%1d|%01.4f",i,i,i,i,cast(double) i);
    assert(s == "-5| -5|-05|-5|-5.0000");

    i = 0;
    s = format("%d|%3d|%03d|%1d|%01.4f",i,i,i,i,cast(double) i);
    assert(s == "0|  0|000|0|0.0000");

    i = 5;
    s = format("%d|%3d|%03d|%1d|%01.4f",i,i,i,i,cast(double) i);
    assert(s == "5|  5|005|5|5.0000");

    i = 10;
    s = format("%d|%3d|%03d|%1d|%01.4f",i,i,i,i,cast(double) i);
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
    assert("|%8s|".format("abc")        == "|     abc|");
    assert("|%8s|".format("αβγ")        == "|     αβγ|");
    assert("|%8s|".format("   ")        == "|        |");
    assert("|%8s|".format("été"d)       == "|     été|");
    assert("|%8s|".format("été 2018"w)  == "|été 2018|");

    assert("%2s".format("e\u0301"w) == " e\u0301");
    assert("%2s".format("a\u0310\u0337"d) == " a\u0310\u0337");
}

@safe pure unittest
{
    import core.exception;
    import std.exception;
    assertCTFEable!(
    {
//  assert(format(null) == "");
    assert(format("foo") == "foo");
    assert(format("foo%%") == "foo%");
    assert(format("foo%s", 'C') == "fooC");
    assert(format("%s foo", "bar") == "bar foo");
    assert(format("%s foo %s", "bar", "abc") == "bar foo abc");
    assert(format("foo %d", -123) == "foo -123");
    assert(format("foo %d", 123) == "foo 123");

    assertThrown!FormatException(format("foo %s"));
    assertThrown!FormatException(format("foo %s", 123, 456));

    assert(format("hel%slo%s%s%s", "world", -138, 'c', true) ==
                  "helworldlo-138ctrue");
    });

    assert(is(typeof(format("happy")) == string));
    assert(is(typeof(format("happy"w)) == wstring));
    assert(is(typeof(format("happy"d)) == dstring));
}

// https://issues.dlang.org/show_bug.cgi?id=16661
@safe unittest
{
    assert(format("%.2f"d, 0.4) == "0.40");
    assert("%02d"d.format(1) == "01"d);
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

/*****************************************************
 * Format arguments into buffer $(I buf) which must be large
 * enough to hold the result.
 *
 * Returns:
 *     The slice of `buf` containing the formatted string.
 *
 * Throws:
 *     A `RangeError` if `buf` isn't large enough to hold the
 *     formatted string.
 *
 *     A $(LREF FormatException) if the length of `args` is different
 *     than the number of format specifiers in `fmt`.
 */
char[] sformat(alias fmt, Args...)(char[] buf, Args args)
if (isSomeString!(typeof(fmt)))
{
    alias e = checkFormatException!(fmt, Args);
    static assert(!e, e.msg);
    return .sformat(buf, fmt, args);
}

/// ditto
char[] sformat(Char, Args...)(return scope char[] buf, scope const(Char)[] fmt, Args args)
{
    import core.exception : RangeError;
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

/// The format string can be checked at compile-time (see $(LREF format) for details):
@system unittest
{
    char[10] buf;

    assert(buf[].sformat!"foo%s"('C') == "fooC");
    assert(sformat(buf[], "%s foo", "bar") == "bar foo");
}

@system unittest
{
    import core.exception;
    import std.exception;
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
        return (e.msg == ctfpMessage) ? null : e;
    return null;
}();


version (StdUnittest)
private void formatReflectTest(T)(ref T val, string fmt, string formatted, string fn = __FILE__, size_t ln = __LINE__)
{
    import core.exception : AssertError;
    import std.array : appender;
    auto w = appender!string();
    formattedWrite(w, fmt, val);

    auto input = w.data;
    enforce!AssertError(
            input == formatted,
            input, fn, ln);

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
    enforce!AssertError(
            val == val2,
            input, fn, ln);
}

version (StdUnittest)
private void formatReflectTest(T)(ref T val, string fmt, string[] formatted, string fn = __FILE__, size_t ln = __LINE__)
{
    import core.exception : AssertError;
    import std.array : appender;
    auto w = appender!string();
    formattedWrite(w, fmt, val);

    auto input = w.data;

    foreach (cur; formatted)
    {
        if (input == cur) return;
    }
    enforce!AssertError(
            false,
            input,
            fn,
            ln);

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
    enforce!AssertError(
            val == val2,
            input, fn, ln);
}

@system unittest
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
        version (MinGW)
            formatReflectTest(f, "%e",  `3.140000e+000`);
        else
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
        formatReflectTest(aa, "%s",                     [`[1:"hello", 2:"world"]`, `[2:"world", 1:"hello"]`]);
        formatReflectTest(aa, "[%(%s->%s, %)]",         [`[1->"hello", 2->"world"]`, `[2->"world", 1->"hello"]`]);
        formatReflectTest(aa, "{%([%s=%(%c%)]%|; %)}",  [`{[1=hello]; [2=world]}`, `{[2=world]; [1=hello]}`]);
    }

    import std.exception;
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

