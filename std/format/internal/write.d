// Written in the D programming language.

/*
   Copyright: Copyright The D Language Foundation 2000-2013.

   License: $(HTTP boost.org/LICENSE_1_0.txt, Boost License 1.0).

   Authors: $(HTTP walterbright.com, Walter Bright), $(HTTP erdani.com,
   Andrei Alexandrescu), and Kenji Hara

   Source: $(PHOBOSSRC std/format/internal/write.d)
 */
module std.format.internal.write;

import std.exception;
import std.meta;
import std.range.primitives;
import std.traits;

import std.format;

/*
    `bool`s are formatted as `"true"` or `"false"` with `%s` and as `1` or
    `0` with integral-specific format specs.
 */
package(std.format) void formatValueImpl(Writer, T, Char)(auto ref Writer w, T obj, scope const ref FormatSpec!Char f)
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
        formatTest(false, "false");
        formatTest(true,  "true");
    });
}

@system unittest
{
    class C1
    {
        bool val;
        alias val this;
        this(bool v){ val = v; }
    }

    class C2 {
        bool val;
        alias val this;
        this(bool v){ val = v; }
        override string toString() const { return "C"; }
    }

    formatTest(new C1(false), "false");
    formatTest(new C1(true),  "true");
    formatTest(new C2(false), "C");
    formatTest(new C2(true),  "C");

    struct S1
    {
        bool val;
        alias val this;
    }

    struct S2
    {
        bool val;
        alias val this;
        string toString() const { return "S"; }
    }

    formatTest(S1(false), "false");
    formatTest(S1(true),  "true");
    formatTest(S2(false), "S");
    formatTest(S2(true),  "S");
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
package(std.format) void formatValueImpl(Writer, T, Char)(auto ref Writer w, T obj, scope const ref FormatSpec!Char f)
if (is(immutable T == immutable typeof(null)) && !is(T == enum) && !hasToString!(T, Char))
{
    const spec = f.spec;
    enforceFmt(spec == 's', "null literal cannot match %" ~ spec);

    writeAligned(w, "null", f);
}

@safe pure unittest
{
    assert(collectExceptionMsg!FormatException(format("%p", null)).back == 'p');

    assertCTFEable!(
    {
        formatTest(null, "null");
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
package(std.format) void formatValueImpl(Writer, T, Char)(auto ref Writer w, T obj, scope const ref FormatSpec!Char f)
if (is(IntegralTypeOf!T) && !is(T == enum) && !hasToString!(T, Char))
{
    alias U = IntegralTypeOf!T;
    U val = obj;    // Extracting alias this may be impure/system/may-throw

    const spec = f.spec;
    if (spec == 'r')
    {
        // raw write, skip all else and write the thing
        auto raw = (ref val) @trusted {
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

        separatorsCount = (padChar == '0')
            ? (finalWidth - prefixWidth - 1) / (fs.separators + 1)
            : ((digits.length > 0) ? (digits.length - 1) / fs.separators : 0);
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
        formatTest(10, "10");
    });
}

@system unittest
{
    class C1
    {
        long val;
        alias val this;
        this(long v){ val = v; }
    }

    class C2
    {
        long val;
        alias val this;
        this(long v){ val = v; }
        override string toString() const { return "C"; }
    }

    formatTest(new C1(10), "10");
    formatTest(new C2(10), "C");

    struct S1
    {
        long val;
        alias val this;
    }

    struct S2
    {
        long val;
        alias val this;
        string toString() const { return "S"; }
    }

    formatTest(S1(10), "10");
    formatTest(S2(10), "S");
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
    void put(scope const char[] s) { result ~= s; }

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

/*
    Floating-point values are formatted like $(REF printf, core, stdc, stdio)
 */
package(std.format) void formatValueImpl(Writer, T, Char)(auto ref Writer w, T obj, scope const ref FormatSpec!Char f)
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
        auto raw = (ref val) @trusted {
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
    if (fs.spec=='a' || fs.spec=='A' || fs.spec=='e' || fs.spec=='E' || fs.spec=='f' || fs.spec=='F')
    {
        static if (is(T == float) || is(T == double) || (is(T == real) && T.mant_dig == double.mant_dig))
        {
            import std.math;
            import std.format.internal.floats : RoundingMode, printFloat;

            auto mode = RoundingMode.toNearestTiesToEven;

            if (!__ctfe)
            {
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
            }

            buf = printFloat(buf2[], val, fs, mode);
            len = buf.length;
        }
        else
            goto useSnprintf;
    }
    else
    {
useSnprintf:
        import std.format.internal.floats : ctfpMessage;
        enforceFmt(!__ctfe, ctfpMessage);

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

        immutable n = () @trusted {
            import core.stdc.stdio : snprintf;
            return snprintf(buf2.ptr, buf2.length,
                            sprintfSpec.ptr,
                            fs.width,
                            // negative precision is same as no precision specified
                            fs.precision == fs.UNSPECIFIED ? -1 : fs.precision,
                            tval);
        }();

        enforceFmt(n >= 0, "floating point formatting failure");

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

    assert(collectExceptionMsg!FormatException(format("%d", 5.1)).back == 'd');

    static foreach (T; AliasSeq!(float, double, real))
    {
        formatTest(to!(          T)(5.5), "5.5");
        formatTest(to!(    const T)(5.5), "5.5");
        formatTest(to!(immutable T)(5.5), "5.5");

        formatTest(T.nan, "nan");
    }
}

@system unittest
{
    formatTest(2.25, "2.25");

    class C1
    {
        double val;
        alias val this;
        this(double v){ val = v; }
    }

    class C2
    {
        double val;
        alias val this;
        this(double v){ val = v; }
        override string toString() const { return "C"; }
    }

    formatTest(new C1(2.25), "2.25");
    formatTest(new C2(2.25), "C");

    struct S1
    {
        double val;
        alias val this;
    }
    struct S2
    {
        double val;
        alias val this;
        string toString() const { return "S"; }
    }

    formatTest(S1(2.25), "2.25");
    formatTest(S2(2.25), "S");
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
    import std.math;

    // std.math's FloatingPointControl isn't available on all target platforms
    static if (is(FloatingPointControl))
    {
        assert(FloatingPointControl.rounding == FloatingPointControl.roundToNearest);
    }

    // issue 20320
    real a = 0.16;
    real b = 0.016;
    assert(format("%.1f", a) == "0.2");
//    assert(format("%.2f", b) == "0.02"); // Windows still fails here...

    double a1 = 0.16;
    double b1 = 0.016;
    assert(format("%.1f", a1) == "0.2");
    assert(format("%.2f", b1) == "0.02");

    // issue 9889
    assert(format("%.1f", 0.09) == "0.1");
    assert(format("%.1f", -0.09) == "-0.1");
    assert(format("%.1f", 0.095) == "0.1");
    assert(format("%.1f", -0.095) == "-0.1");
    assert(format("%.1f", 0.094) == "0.1");
    assert(format("%.1f", -0.094) == "-0.1");
}

@safe unittest
{
    double a = 123.456;
    double b = -123.456;
    double c = 123.0;

    assert(format("%10.4f",a)  == "  123.4560");
    assert(format("%-10.4f",a) == "123.4560  ");
    assert(format("%+10.4f",a) == " +123.4560");
    assert(format("% 10.4f",a) == "  123.4560");
    assert(format("%010.4f",a) == "00123.4560");
    assert(format("%#10.4f",a) == "  123.4560");

    assert(format("%10.4f",b)  == " -123.4560");
    assert(format("%-10.4f",b) == "-123.4560 ");
    assert(format("%+10.4f",b) == " -123.4560");
    assert(format("% 10.4f",b) == " -123.4560");
    assert(format("%010.4f",b) == "-0123.4560");
    assert(format("%#10.4f",b) == " -123.4560");

    assert(format("%10.0f",c)  == "       123");
    assert(format("%-10.0f",c) == "123       ");
    assert(format("%+10.0f",c) == "      +123");
    assert(format("% 10.0f",c) == "       123");
    assert(format("%010.0f",c) == "0000000123");
    assert(format("%#10.0f",c) == "      123.");

    assert(format("%+010.4f",a) == "+0123.4560");
    assert(format("% 010.4f",a) == " 0123.4560");
    assert(format("% +010.4f",a) == "+0123.4560");
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
    assert(format!"%.1000a"(1.0).length == 1007);
    assert(format!"%.600f"(0.1).length == 602);
}

@safe unittest
{
    import std.math;

    // std.math's FloatingPointControl isn't available on all target platforms
    static if (is(FloatingPointControl))
    {
        FloatingPointControl fpctrl;

        fpctrl.rounding = FloatingPointControl.roundUp;
        assert(format!"%.0e"(3.5) == "4e+00");
        assert(format!"%.0e"(4.5) == "5e+00");
        assert(format!"%.0e"(-3.5) == "-3e+00");
        assert(format!"%.0e"(-4.5) == "-4e+00");

        fpctrl.rounding = FloatingPointControl.roundDown;
        assert(format!"%.0e"(3.5) == "3e+00");
        assert(format!"%.0e"(4.5) == "4e+00");
        assert(format!"%.0e"(-3.5) == "-4e+00");
        assert(format!"%.0e"(-4.5) == "-5e+00");

        fpctrl.rounding = FloatingPointControl.roundToZero;
        assert(format!"%.0e"(3.5) == "3e+00");
        assert(format!"%.0e"(4.5) == "4e+00");
        assert(format!"%.0e"(-3.5) == "-3e+00");
        assert(format!"%.0e"(-4.5) == "-4e+00");

        fpctrl.rounding = FloatingPointControl.roundToNearest;
        assert(format!"%.0e"(3.5) == "4e+00");
        assert(format!"%.0e"(4.5) == "4e+00");
        assert(format!"%.0e"(-3.5) == "-4e+00");
        assert(format!"%.0e"(-4.5) == "-4e+00");
    }
}

@safe pure unittest
{
    static assert(format("%e",1.0) == "1.000000e+00");
    static assert(format("%e",-1.234e156) == "-1.234000e+156");
    static assert(format("%a",1.0) == "0x1p+0");
    static assert(format("%a",-1.234e156) == "-0x1.7024c96ca3ce4p+518");
    static assert(format("%f",1.0) == "1.000000");
    static assert(format("%f",-1.234e156) ==
                  "-123399999999999990477495546305353609103201879173427886566531" ~
                  "0740685826234179310516880117527217443004051984432279880308552" ~
                  "009640198043032289366552939010719744.000000");
    static assert(format("%e",1.0f) == "1.000000e+00");
    static assert(format("%e",-1.234e23f) == "-1.234000e+23");
    static assert(format("%a",1.0f) == "0x1p+0");
    static assert(format("%a",-1.234e23f) == "-0x1.a2187p+76");
    static assert(format("%f",1.0f) == "1.000000");
    static assert(format("%f",-1.234e23f) == "-123399998884238311030784.000000");
}

/*
    Formatting a `creal` is deprecated but still kept around for a while.
 */
deprecated("Use of complex types is deprecated. Use std.complex")
package(std.format) void formatValueImpl(Writer, T, Char)(auto ref Writer w, T obj, scope const ref FormatSpec!Char f)
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

/*
    Formatting an `ireal` is deprecated but still kept around for a while.
 */
deprecated("Use of imaginary types is deprecated. Use std.complex")
package(std.format) void formatValueImpl(Writer, T, Char)(auto ref Writer w, T obj, scope const ref FormatSpec!Char f)
if (is(immutable T : immutable ireal) && !is(T == enum) && !hasToString!(T, Char))
{
    immutable ireal val = obj;

    formatValueImpl(w, val.im, f);
    put(w, 'i');
}

/*
    Individual characters are formatted as Unicode characters with `%s`
    and as integers with integral-specific format specs
 */
package(std.format) void formatValueImpl(Writer, T, Char)(auto ref Writer w, T obj, scope const ref FormatSpec!Char f)
if (is(CharTypeOf!T) && !is(T == enum) && !hasToString!(T, Char))
{
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
        formatTest('c', "c");
    });
}

@system unittest
{
    class C1
    {
        char val;
        alias val this;
        this(char v){ val = v; }
    }

    class C2
    {
        char val;
        alias val this;
        this(char v){ val = v; }
        override string toString() const { return "C"; }
    }

    formatTest(new C1('c'), "c");
    formatTest(new C2('c'), "C");

    struct S1
    {
        char val;
        alias val this;
    }

    struct S2
    {
        char val;
        alias val this;
        string toString() const { return "S"; }
    }

    formatTest(S1('c'), "c");
    formatTest(S2('c'), "S");
}

@safe unittest
{
    //Little Endian
    formatTest("%-r", cast( char)'c', ['c'         ]);
    formatTest("%-r", cast(wchar)'c', ['c', 0      ]);
    formatTest("%-r", cast(dchar)'c', ['c', 0, 0, 0]);
    formatTest("%-r", '本', ['\x2c', '\x67'] );

    //Big Endian
    formatTest("%+r", cast( char)'c', [         'c']);
    formatTest("%+r", cast(wchar)'c', [0,       'c']);
    formatTest("%+r", cast(dchar)'c', [0, 0, 0, 'c']);
    formatTest("%+r", '本', ['\x67', '\x2c']);
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
package(std.format) void formatValueImpl(Writer, T, Char)(auto ref Writer w, scope T obj,
                                                          scope const ref FormatSpec!Char f)
if (is(StringTypeOf!T) && !is(StaticArrayTypeOf!T) && !is(T == enum) && !hasToString!(T, Char))
{
    Unqual!(StringTypeOf!T) val = obj;  // for `alias this`, see bug5371
    formatRange(w, val, f);
}

@safe unittest
{
    formatTest("abc", "abc");
}

@system unittest
{
    // Test for bug 5371 for classes
    class C1
    {
        const string var;
        alias var this;
        this(string s){ var = s; }
    }

    class C2
    {
        string var;
        alias var this;
        this(string s){ var = s; }
    }

    formatTest(new C1("c1"), "c1");
    formatTest(new C2("c2"), "c2");

    // Test for bug 5371 for structs
    struct S1
    {
        const string var;
        alias var this;
    }

    struct S2
    {
        string var;
        alias var this;
    }

    formatTest(S1("s1"), "s1");
    formatTest(S2("s2"), "s2");
}

@system unittest
{
    class C3
    {
        string val;
        alias val this;
        this(string s){ val = s; }
        override string toString() const { return "C"; }
    }

    formatTest(new C3("c3"), "C");

    struct S3
    {
        string val; alias val this;
        string toString() const { return "S"; }
    }

    formatTest(S3("s3"), "S");
}

@safe pure unittest
{
    //Little Endian
    formatTest("%-r", "ab"c, ['a'         , 'b'         ]);
    formatTest("%-r", "ab"w, ['a', 0      , 'b', 0      ]);
    formatTest("%-r", "ab"d, ['a', 0, 0, 0, 'b', 0, 0, 0]);
    formatTest("%-r", "日本語"c, ['\xe6', '\x97', '\xa5', '\xe6', '\x9c', '\xac', '\xe8', '\xaa', '\x9e']);
    formatTest("%-r", "日本語"w, ['\xe5', '\x65', '\x2c', '\x67', '\x9e', '\x8a']);
    formatTest("%-r", "日本語"d, ['\xe5', '\x65', '\x00', '\x00', '\x2c', '\x67',
                                  '\x00', '\x00', '\x9e', '\x8a', '\x00', '\x00']);

    //Big Endian
    formatTest("%+r", "ab"c, [         'a',          'b']);
    formatTest("%+r", "ab"w, [      0, 'a',       0, 'b']);
    formatTest("%+r", "ab"d, [0, 0, 0, 'a', 0, 0, 0, 'b']);
    formatTest("%+r", "日本語"c, ['\xe6', '\x97', '\xa5', '\xe6', '\x9c', '\xac', '\xe8', '\xaa', '\x9e']);
    formatTest("%+r", "日本語"w, ['\x65', '\xe5', '\x67', '\x2c', '\x8a', '\x9e']);
    formatTest("%+r", "日本語"d, ['\x00', '\x00', '\x65', '\xe5', '\x00', '\x00',
                                  '\x67', '\x2c', '\x00', '\x00', '\x8a', '\x9e']);
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
package(std.format) void formatValueImpl(Writer, T, Char)(auto ref Writer w, auto ref T obj,
                                                          scope const ref FormatSpec!Char f)
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

    char[2] getTwo() { return two; }
    formatValue(w, getTwo(), f);
}

/*
    Dynamic arrays are formatted as input ranges.
 */
package(std.format) void formatValueImpl(Writer, T, Char)(auto ref Writer w, T obj, scope const ref FormatSpec!Char f)
if (is(DynamicArrayTypeOf!T) && !is(StringTypeOf!T) && !is(T == enum) && !hasToString!(T, Char))
{
    static if (is(immutable(ArrayTypeOf!T) == immutable(void[])))
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

// bug 20848
@safe unittest
{
    class C
    {
        immutable(void)[] data;
    }
    import std.typecons : Nullable;
    Nullable!C c;
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
            void popFront() { arr = arr[1 .. $]; }
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
            void popFront() { arr = arr[1 .. $]; }
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
    formatTest(val0, "[]");

    void[] val = cast(void[]) cast(ubyte[])[1, 2, 3];
    formatTest(val, "[1, 2, 3]");

    void[0] sval0 = [];
    formatTest(sval0, "[]");

    void[3] sval = cast(void[3]) cast(ubyte[3])[1, 2, 3];
    formatTest(sval, "[1, 2, 3]");
}

@safe unittest
{
    // const(T[]) -> const(T)[]
    const short[] a = [1, 2, 3];
    formatTest(a, "[1, 2, 3]");

    struct S
    {
        const(int[]) arr;
        alias arr this;
    }

    auto s = S([1,2,3]);
    formatTest(s, "[1, 2, 3]");
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
    // string literal from valid UTF sequence is encoding free.
    static foreach (StrType; AliasSeq!(string, wstring, dstring))
    {
        // Valid and printable (ASCII)
        formatTest([cast(StrType)"hello"],
                   `["hello"]`);

        // 1 character escape sequences (' is not escaped in strings)
        formatTest([cast(StrType)"\"'\0\\\a\b\f\n\r\t\v"],
                   `["\"'\0\\\a\b\f\n\r\t\v"]`);

        // 1 character optional escape sequences
        formatTest([cast(StrType)"\'\?"],
                   `["'?"]`);

        // Valid and non-printable code point (<= U+FF)
        formatTest([cast(StrType)"\x10\x1F\x20test"],
                   `["\x10\x1F test"]`);

        // Valid and non-printable code point (<= U+FFFF)
        formatTest([cast(StrType)"\u200B..\u200F"],
                   `["\u200B..\u200F"]`);

        // Valid and non-printable code point (<= U+10FFFF)
        formatTest([cast(StrType)"\U000E0020..\U000E007F"],
                   `["\U000E0020..\U000E007F"]`);
    }

    // invalid UTF sequence needs hex-string literal postfix (c/w/d)
    {
        // U+FFFF with UTF-8 (Invalid code point for interchange)
        formatTest([cast(string)[0xEF, 0xBF, 0xBF]],
                   `[x"EF BF BF"c]`);

        // U+FFFF with UTF-16 (Invalid code point for interchange)
        formatTest([cast(wstring)[0xFFFF]],
                   `[x"FFFF"w]`);

        // U+FFFF with UTF-32 (Invalid code point for interchange)
        formatTest([cast(dstring)[0xFFFF]],
                   `[x"FFFF"d]`);
    }
}

@safe unittest
{
    // nested range formatting with array of string
    formatTest("%({%(%02x %)}%| %)", ["test", "msg"],
               `{74 65 73 74} {6d 73 67}`);
}

@safe unittest
{
    // stop auto escaping inside range formatting
    auto arr = ["hello", "world"];
    formatTest("%(%s, %)",  arr, `"hello", "world"`);
    formatTest("%-(%s, %)", arr, `hello, world`);

    auto aa1 = [1:"hello", 2:"world"];
    formatTest("%(%s:%s, %)",  aa1, [`1:"hello", 2:"world"`, `2:"world", 1:"hello"`]);
    formatTest("%-(%s:%s, %)", aa1, [`1:hello, 2:world`, `2:world, 1:hello`]);

    auto aa2 = [1:["ab", "cd"], 2:["ef", "gh"]];
    formatTest("%-(%s:%s, %)",        aa2, [`1:["ab", "cd"], 2:["ef", "gh"]`, `2:["ef", "gh"], 1:["ab", "cd"]`]);
    formatTest("%-(%s:%(%s%), %)",    aa2, [`1:"ab""cd", 2:"ef""gh"`, `2:"ef""gh", 1:"ab""cd"`]);
    formatTest("%-(%s:%-(%s%)%|, %)", aa2, [`1:abcd, 2:efgh`, `2:efgh, 1:abcd`]);
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
package(std.format) void formatChar(Writer)(ref Writer w, in dchar c, in char quote)
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

/*
    Associative arrays are formatted by using `':'` and $(D ", ") as
    separators, and enclosed by `'['` and `']'`.
 */
package(std.format) void formatValueImpl(Writer, T, Char)(auto ref Writer w, T obj, scope const ref FormatSpec!Char f)
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
    // Bug #17269. Behavior similar to `struct A { Nullable!string B; }`
    struct StringAliasThis
    {
        @property string value() const { assert(0); }
        alias value this;
        string toString() { return "helloworld"; }
        private string _value;
    }
    struct TestContainer
    {
        StringAliasThis testVar;
    }

    import std.array : appender;
    auto w = appender!string();
    auto spec = singleSpec("%s");
    formatElement(w, TestContainer(), spec);

    assert(w.data == "TestContainer(helloworld)", w.data);
}

// https://issues.dlang.org/show_bug.cgi?id=17269
@safe unittest
{
    import std.typecons : Nullable;

    struct Foo
    {
        Nullable!string bar;
    }

    Foo f;
    formatTest(f, "Foo(Nullable.null)");
}

@safe unittest
{
    assert(collectExceptionMsg!FormatException(format("%d", [0:1])).back == 'd');

    int[string] aa0;
    formatTest(aa0, `[]`);

    // elements escaping
    formatTest(["aaa":1, "bbb":2],
               [`["aaa":1, "bbb":2]`, `["bbb":2, "aaa":1]`]);
    formatTest(['c':"str"],
               `['c':"str"]`);
    formatTest(['"':"\"", '\'':"'"],
               [`['"':"\"", '\'':"'"]`, `['\'':"'", '"':"\""]`]);

    // range formatting for AA
    auto aa3 = [1:"hello", 2:"world"];
    // escape
    formatTest("{%(%s:%s $ %)}", aa3,
               [`{1:"hello" $ 2:"world"}`, `{2:"world" $ 1:"hello"}`]);
    // use range formatting for key and value, and use %|
    formatTest("{%([%04d->%(%c.%)]%| $ %)}", aa3,
               [`{[0001->h.e.l.l.o] $ [0002->w.o.r.l.d]}`, `{[0002->w.o.r.l.d] $ [0001->h.e.l.l.o]}`]);

    // https://issues.dlang.org/show_bug.cgi?id=12135
    formatTest("%(%s:<%s>%|,%)", [1:2], "1:<2>");
    formatTest("%(%s:<%s>%|%)" , [1:2], "1:<2>");
}

@system unittest
{
    class C1
    {
        int[char] val;
        alias val this;
        this(int[char] v){ val = v; }
    }

    class C2
    {
        int[char] val;
        alias val this;
        this(int[char] v){ val = v; }
        override string toString() const { return "C"; }
    }

    formatTest(new C1(['c':1, 'd':2]), [`['c':1, 'd':2]`, `['d':2, 'c':1]`]);
    formatTest(new C2(['c':1, 'd':2]), "C");

    struct S1
    {
        int[char] val;
        alias val this;
    }

    struct S2
    {
        int[char] val;
        alias val this;
        string toString() const { return "S"; }
    }

    formatTest(S1(['c':1, 'd':2]), [`['c':1, 'd':2]`, `['d':2, 'c':1]`]);
    formatTest(S2(['c':1, 'd':2]), "S");
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

package(std.format) enum HasToStringResult
{
    none,
    hasSomeToString,
    inCharSink,
    inCharSinkFormatString,
    inCharSinkFormatSpec,
    constCharSink,
    constCharSinkFormatString,
    constCharSinkFormatSpec,
    customPutWriter,
    customPutWriterFormatSpec,
}

private enum hasPreviewIn = !is(typeof(mixin(q{(in ref int a) => a})));

package(std.format) template hasToString(T, Char)
{
    static if (isPointer!T)
    {
        // X* does not have toString, even if X is aggregate type has toString.
        enum hasToString = HasToStringResult.none;
    }
    else static if (is(typeof(
        {
            T val = void;
            const FormatSpec!Char f;
            static struct S {void put(scope Char s){}}
            S s;
            val.toString(s, f);
            // force toString to take parameters by ref
            static assert(!__traits(compiles, val.toString(s, FormatSpec!Char())));
            static assert(!__traits(compiles, val.toString(S(), f)));
        })))
    {
        enum hasToString = HasToStringResult.customPutWriterFormatSpec;
    }
    else static if (is(typeof(
        {
            T val = void;
            static struct S {void put(scope Char s){}}
            S s;
            val.toString(s);
            // force toString to take parameters by ref
            static assert(!__traits(compiles, val.toString(S())));
        })))
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

    else static if (hasPreviewIn &&
                    is(typeof({ T val = void; FormatSpec!Char f; val.toString((in char[] s){}, f); })))
    {
        enum hasToString = HasToStringResult.inCharSinkFormatSpec;
    }
    else static if (hasPreviewIn &&
                    is(typeof({ T val = void; val.toString((in char[] s){}, "%s"); })))
    {
        enum hasToString = HasToStringResult.inCharSinkFormatString;
    }
    else static if (hasPreviewIn &&
                    is(typeof({ T val = void; val.toString((in char[] s){}); })))
    {
        enum hasToString = HasToStringResult.inCharSink;
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
    static struct M
    {
        void toString(scope void delegate(in char[]) sink, in FormatSpec!char fmt) {}
    }
    static struct N
    {
        void toString(scope void delegate(in char[]) sink, string fmt) {}
    }
    static struct O
    {
        void toString(scope void delegate(in char[]) sink) {}
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
        static if (hasPreviewIn)
        {
            static assert(hasToString!(M, char) == inCharSinkFormatSpec);
            static assert(hasToString!(N, char) == inCharSinkFormatString);
            static assert(hasToString!(O, char) == inCharSink);
        }
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
    else static if (overload == HasToStringResult.inCharSinkFormatSpec)
    {
        static if (!noop) val.toString((in char[] s) { put(w, s); }, f);
    }
    else static if (overload == HasToStringResult.inCharSinkFormatString)
    {
        static if (!noop) val.toString((in char[] s) { put(w, s); }, f.getCurFmtStr());
    }
    else static if (overload == HasToStringResult.inCharSink)
    {
        static if (!noop) val.toString((in char[] s) { put(w, s); });
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
package(std.format) void formatValueImpl(Writer, T, Char)(auto ref Writer w, T val, scope const ref FormatSpec!Char f)
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
            // string delegate() dg = &val.toString;
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
    formatTest(c, "[1, 2, 3, 4]");
    assert(c.empty);
    c = null;
    formatTest(c, "null");
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
        void popFront(){ arr = arr[1 .. $]; }
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

    formatTest(new C1([0, 1, 2]), "[012]");
    formatTest(new C2([0, 1, 2]), "[012]");
    formatTest(new C3([0, 1, 2]), "[012]");
    formatTest(new C4([0, 1, 2]), "[012]");
    formatTest(new C5([0, 1, 2]), "[0, 1, 2]");
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
    assert(s == "immutable(std.format.internal.write.C)");

    const(C) c3 = new C();
    s = format("%s", c3);
    assert(s == "const(std.format.internal.write.C)");

    shared(C) c4 = new C();
    s = format("%s", c4);
    assert(s == "shared(std.format.internal.write.C)");
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
package(std.format) void formatValueImpl(Writer, T, Char)(auto ref Writer w, T val, scope const ref FormatSpec!Char f)
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
    formatTest(i, "[1, 2, 3, 4]");
    assert(i.empty);
    i = null;
    formatTest(i, "null");

    // interface (downcast to Object)
    interface Whatever {}
    class C : Whatever
    {
        override @property string toString() const { return "ab"; }
    }
    Whatever val = new C;
    formatTest(val, "ab");

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
package(std.format) void formatValueImpl(Writer, T, Char)(auto ref Writer w, auto ref T val,
                                                          scope const ref FormatSpec!Char f)
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
                    put(w, separator~val.tupleof[i].stringof[4 .. $]~"}");
                else
                    put(w, separator~val.tupleof[i].stringof[4 .. $]);
            }
            else static if (i+1 < val.tupleof.length && val.tupleof[i].offsetof == val.tupleof[i+1].offsetof)
                put(w, (i > 0 ? separator : "")~"#{overlap "~val.tupleof[i].stringof[4 .. $]);
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
    formatTest(S(), "S(0)");
}

// https://issues.dlang.org/show_bug.cgi?id=4638
@safe unittest
{
    struct U8  {  string toString() const { return "blah"; } }
    struct U16 { wstring toString() const { return "blah"; } }
    struct U32 { dstring toString() const { return "blah"; } }
    formatTest(U8(), "blah");
    formatTest(U16(), "blah");
    formatTest(U32(), "blah");
}

// https://issues.dlang.org/show_bug.cgi?id=3890
@safe unittest
{
    struct Int{ int n; }
    struct Pair{ string s; Int i; }
    formatTest(Pair("hello", Int(5)),
               `Pair("hello", Int(5))`);
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
    formatTest(u1, "U1");

    // union formatting with toString
    union U2
    {
        int n;
        string s;
        string toString() const { return s; }
    }
    U2 u2;
    u2.s = "hello";
    formatTest(u2, "hello");
}

@system unittest
{
    import std.array;
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
package(std.format) void formatValueImpl(Writer, T, Char)(auto ref Writer w, T val, scope const ref FormatSpec!Char f)
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
    formatTest(A.second, "second");
    formatTest(cast(A) 72, "cast(A)72");
}
@safe unittest
{
    enum A : string { one = "uno", two = "dos", three = "tres" }
    formatTest(A.three, "three");
    formatTest(cast(A)"mill\&oacute;n", "cast(A)mill\&oacute;n");
}
@safe unittest
{
    enum A : bool { no, yes }
    formatTest(A.yes, "yes");
    formatTest(A.no, "no");
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
package(std.format) void formatValueImpl(Writer, T, Char)(auto ref Writer w, scope T val,
                                                          scope const ref FormatSpec!Char f)
if (isPointer!T && !is(T == enum) && !hasToString!(T, Char))
{
    static if (is(typeof({ shared const void* p = val; })))
        alias SharedOf(T) = shared(T);
    else
        alias SharedOf(T) = T;

    const SharedOf!(void*) p = val;
    const pnum = () @trusted { return cast(ulong) p; }();

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
package(std.format) void formatValueImpl(Writer, V, Char)(auto ref Writer w, V val, scope const ref FormatSpec!Char f)
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
    formatTest(p, "null");

    auto q = () @trusted { return cast(void*) 0xFFEECCAA; }();
    formatTest(q, "FFEECCAA");
}

// https://issues.dlang.org/show_bug.cgi?id=11782
@safe pure unittest
{
    import std.range : iota;

    auto a = iota(0, 10);
    auto b = iota(0, 10);
    auto p = () @trusted { auto p = &a; return p; }();

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
    formatTest(p, "null");

    S* q = cast(S*) 0xFFEECCAA;
    formatTest(q, "FFEECCAA");
}

// https://issues.dlang.org/show_bug.cgi?id=8186
@system unittest
{
    class B
    {
        int* a;
        this() { a = new int; }
        alias a this;
    }
    formatTest(B.init, "null");
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
    formatTest("%08X", p, "00000000");
}

/*
    Delegates are formatted by `ReturnType delegate(Parameters) FunctionAttributes`

    Known bug: Because of issue https://issues.dlang.org/show_bug.cgi?id=18269
               the FunctionAttributes might be wrong.
 */
package(std.format) void formatValueImpl(Writer, T, Char)(auto ref Writer w, scope T, scope const ref FormatSpec!Char f)
if (isDelegate!T)
{
    formatValueImpl(w, T.stringof, f);
}

@safe unittest
{
    void func() @system { __gshared int x; ++x; throw new Exception("msg"); }
    version (linux)
    {
        import std.array : appender;
        FormatSpec!char f;
        auto w = appender!string();
        formatValue(w, &func, f);
        assert(w.data.length >= 15 && w.data[0 .. 15] == "void delegate()");
    }
}

@safe pure unittest
{
    int[] a = [ 1, 3, 2 ];
    formatTest("testing %(%s & %) embedded", a,
               "testing 1 & 3 & 2 embedded");
    formatTest("testing %((%s) %)) wyda3", a,
               "testing (1) (3) (2) wyda3");

    int[0] empt = [];
    formatTest("(%s)", empt, "([])");
}

// Fix for https://issues.dlang.org/show_bug.cgi?id=1591
package(std.format) int getNthInt(string kind, A...)(uint index, A args)
{
    return getNth!(kind, isIntegral,int)(index, args);
}

package(std.format) T getNth(string kind, alias Condition, T, A...)(uint index, A args)
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
            throw new FormatException(text("Missing ", kind, " argument"));
    }
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
