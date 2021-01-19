// Written in the D programming language.

module std.format.read;

import std.format;
import std.exception;
import std.range.primitives;
import std.traits;

//debug=format;                // uncomment to turn on debugging printf's

/**
Reads characters from $(REF_ALTTEXT input range, isInputRange, std,range,primitives)
`r`, converts them according to `fmt`, and writes them to `args`.

Params:
    r = The range to read from.
    fmt = The format of the data to read.
    args = The drain of the data read.

Returns:

On success, the function returns the number of variables filled. This count
can match the expected number of readings or fewer, even zero, if a
matching failure happens.

Throws:
    A `FormatException` if `S.length == 0` and `fmt` has format specifiers.
 */
uint formattedRead(alias fmt, R, S...)(auto ref R r, auto ref S args)
if (isSomeString!(typeof(fmt)))
{
    alias e = checkFormatException!(fmt, S);
    static assert(!e, e.msg);
    return .formattedRead(r, fmt, args);
}

/// ditto
uint formattedRead(R, Char, S...)(auto ref R r, const(Char)[] fmt, auto ref S args)
{
    import std.typecons : isTuple;

    auto spec = FormatSpec!Char(fmt);
    static if (!S.length)
    {
        spec.readUpToNextSpec(r);
        enforceFmt(spec.trailing.empty, "Trailing characters in formattedRead format string");
        return 0;
    }
    else
    {
        enum hasPointer = isPointer!(typeof(args[0]));

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
        static if (hasPointer)
            alias A = typeof(*args[0]);
        else
            alias A = typeof(args[0]);

        static if (isTuple!A)
        {
            foreach (i, T; A.Types)
            {
                static if (hasPointer)
                    (*args[0])[i] = unformatValue!(T)(r, spec);
                else
                    args[0][i] = unformatValue!(T)(r, spec);
                skipUnstoredFields();
            }
        }
        else
        {
            static if (hasPointer)
                *args[0] = unformatValue!(A)(r, spec);
            else
                args[0] = unformatValue!(A)(r, spec);
        }
        return 1 + formattedRead(r, spec.trailing, args[1 .. $]);
    }
}

/// The format string can be checked at compile-time (see $(LREF format) for details):
@safe pure unittest
{
    string s = "hello!124:34.5";
    string a;
    int b;
    double c;
    s.formattedRead!"%s!%s:%s"(a, b, c);
    assert(a == "hello" && b == 124 && c == 34.5);
}

@safe unittest
{
    import std.math;
    string s = " 1.2 3.4 ";
    double x, y, z;
    assert(formattedRead(s, " %s %s %s ", x, y, z) == 2);
    assert(s.empty);
    assert(approxEqual(x, 1.2));
    assert(approxEqual(y, 3.4));
    assert(isNaN(z));
}

// for backwards compatibility
@system pure unittest
{
    string s = "hello!124:34.5";
    string a;
    int b;
    double c;
    formattedRead(s, "%s!%s:%s", &a, &b, &c);
    assert(a == "hello" && b == 124 && c == 34.5);

    // mix pointers and auto-ref
    s = "world!200:42.25";
    formattedRead(s, "%s!%s:%s", a, &b, &c);
    assert(a == "world" && b == 200 && c == 42.25);

    s = "world1!201:42.5";
    formattedRead(s, "%s!%s:%s", &a, &b, c);
    assert(a == "world1" && b == 201 && c == 42.5);

    s = "world2!202:42.75";
    formattedRead(s, "%s!%s:%s", a, b, &c);
    assert(a == "world2" && b == 202 && c == 42.75);
}

// for backwards compatibility
@system pure unittest
{
    import std.math;
    string s = " 1.2 3.4 ";
    double x, y, z;
    assert(formattedRead(s, " %s %s %s ", &x, &y, &z) == 2);
    assert(s.empty);
    assert(approxEqual(x, 1.2));
    assert(approxEqual(y, 3.4));
    assert(isNaN(z));
}

@system pure unittest
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

@system pure unittest
{
     union B
     {
         char[int.sizeof] untyped;
         int typed;
     }
     B b;
     b.typed = 5;
     char[] input = b.untyped[];
     int witness;
     formattedRead(input, "%r", &witness);
     assert(witness == b.typed);
}

@system pure unittest
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

@system pure unittest
{
    import std.typecons;
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

@system pure unittest
{
    string line;

    char c1, c2;

    line = "abc";
    formattedRead(line, "%s%c", &c1, &c2);
    assert(c1 == 'a' && c2 == 'b');
    assert(line == "c");
}

@system pure unittest
{
    string line;

    line = "[1,2,3]";
    int[] s1;
    formattedRead(line, "%s", &s1);
    assert(s1 == [1,2,3]);
}

@system pure unittest
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

@system pure unittest
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

@system pure unittest
{
    string input;

    int[4] sa1;
    input = `[1,2,3,4]`;
    formattedRead(input, "[%(%s,%)]", &sa1);
    assert(sa1 == [1,2,3,4]);

    int[4] sa2;
    input = `[1,2,3]`;
    assertThrown!FormatException(formattedRead(input, "[%(%s,%)]", &sa2));
}

@system pure unittest
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

@system pure unittest
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

// test rvalue using
@system pure unittest
{
    string[int] aa1;
    formattedRead!("%s")(`[1:"hello", 2:"world"]`, aa1);
    assert(aa1 == [1:"hello", 2:"world"]);

    int[string] aa2;
    formattedRead(`{"hello"=1; "world"=2}`, "{%(%s=%s; %)}", aa2);
    assert(aa2 == ["hello":1, "world":2]);
}

package void skipData(Range, Char)(ref Range input, scope const ref FormatSpec!Char spec)
{
    import std.ascii : isDigit;
    import std.conv : text;

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
 * Reads a value from the given _input range according to spec
 * and returns it as type `T`.
 *
 * Params:
 *     T = the type to return
 *     input = the _input range to read from
 *     spec = the `FormatSpec` to use when reading from `input`
 * Returns:
 *     A value from `input` of type `T`
 * Throws:
 *     A `FormatException` if `spec` cannot read a type `T`
 * See_Also:
 *     $(REF parse, std, conv) and $(REF to, std, conv)
 */
T unformatValue(T, Range, Char)(ref Range input, scope const ref FormatSpec!Char spec)
{
    return unformatValueImpl!T(input, spec);
}

/// Booleans
@safe pure unittest
{
    import std.format;

    auto str = "false";
    auto spec = singleSpec("%s");
    assert(unformatValue!bool(str, spec) == false);

    str = "1";
    spec = singleSpec("%d");
    assert(unformatValue!bool(str, spec));
}

/// Null values
@safe pure unittest
{
    import std.format;

    auto str = "null";
    auto spec = singleSpec("%s");
    assert(str.unformatValue!(typeof(null))(spec) == null);
}

/// Integrals
@safe pure unittest
{
    import std.format;

    auto str = "123";
    auto spec = singleSpec("%s");
    assert(str.unformatValue!int(spec) == 123);

    str = "ABC";
    spec = singleSpec("%X");
    assert(str.unformatValue!int(spec) == 2748);

    str = "11610";
    spec = singleSpec("%o");
    assert(str.unformatValue!int(spec) == 5000);
}

/// Floating point numbers
@safe pure unittest
{
    import std.format;
    import std.math : approxEqual;

    auto str = "123.456";
    auto spec = singleSpec("%s");
    assert(str.unformatValue!double(spec).approxEqual(123.456));
}

/// Character input ranges
@safe pure unittest
{
    import std.format;

    auto str = "aaa";
    auto spec = singleSpec("%s");
    assert(str.unformatValue!char(spec) == 'a');

    // Using a numerical format spec reads a Unicode value from a string
    str = "65";
    spec = singleSpec("%d");
    assert(str.unformatValue!char(spec) == 'A');

    str = "41";
    spec = singleSpec("%x");
    assert(str.unformatValue!char(spec) == 'A');

    str = "10003";
    spec = singleSpec("%d");
    assert(str.unformatValue!dchar(spec) == '✓');
}

/// Arrays and static arrays
@safe pure unittest
{
    import std.format;

    string str = "aaa";
    auto spec = singleSpec("%s");
    assert(str.unformatValue!(dchar[])(spec) == "aaa"d);

    str = "aaa";
    spec = singleSpec("%s");
    dchar[3] ret = ['a', 'a', 'a'];
    assert(str.unformatValue!(dchar[3])(spec) == ret);

    str = "[1, 2, 3, 4]";
    spec = singleSpec("%s");
    assert(str.unformatValue!(int[])(spec) == [1, 2, 3, 4]);

    str = "[1, 2, 3, 4]";
    spec = singleSpec("%s");
    int[4] ret2 = [1, 2, 3, 4];
    assert(str.unformatValue!(int[4])(spec) == ret2);
}

/// Associative arrays
@safe pure unittest
{
    import std.format;

    auto str = `["one": 1, "two": 2]`;
    auto spec = singleSpec("%s");
    assert(str.unformatValue!(int[string])(spec) == ["one": 1, "two": 2]);
}

// https://issues.dlang.org/show_bug.cgi?id=7241
@safe pure unittest
{
    string input = "a";
    auto spec = FormatSpec!char("%s");
    spec.readUpToNextSpec(input);
    auto result = unformatValue!(dchar[1])(input, spec);
    assert(result[0] == 'a');
}

private T unformatValueImpl(T, Range, Char)(ref Range input, scope const ref FormatSpec!Char spec)
if (isInputRange!Range && is(immutable T == immutable bool))
{
    import std.algorithm.searching : find;
    import std.conv : parse, text;

    if (spec.spec == 's') return parse!T(input);

    enforceFmt(find(acceptedSpecs!long, spec.spec).length,
            text("Wrong unformat specifier '%", spec.spec , "' for ", T.stringof));

    return unformatValue!long(input, spec) != 0;
}

private T unformatValueImpl(T, Range, Char)(ref Range input, scope const ref FormatSpec!Char spec)
if (isInputRange!Range && is(T == typeof(null)))
{
    import std.conv : parse, text;
    enforceFmt(spec.spec == 's',
            text("Wrong unformat specifier '%", spec.spec , "' for ", T.stringof));

    return parse!T(input);
}

/// ditto
private T unformatValueImpl(T, Range, Char)(ref Range input, scope const ref FormatSpec!Char spec)
if (isInputRange!Range && isIntegral!T && !is(T == enum) && isSomeChar!(ElementType!Range))
{

    import std.algorithm.searching : find;
    import std.conv : parse, text;

    if (spec.spec == 'r')
    {
        static if (is(immutable ElementEncodingType!Range == immutable char)
                || is(immutable ElementEncodingType!Range == immutable byte)
                || is(immutable ElementEncodingType!Range == immutable ubyte))
            return rawRead!T(input);
        else
            throw new FormatException(
                "The raw read specifier %r may only be used with narrow strings and ranges of bytes."
            );
    }

    enforceFmt(find(acceptedSpecs!T, spec.spec).length,
            text("Wrong unformat specifier '%", spec.spec , "' for ", T.stringof));

    enforceFmt(spec.width == 0, "Parsing integers with a width specification is not implemented");   // TODO

    immutable uint base =
        spec.spec == 'x' || spec.spec == 'X' ? 16 :
        spec.spec == 'o' ? 8 :
        spec.spec == 'b' ? 2 :
        spec.spec == 's' || spec.spec == 'd' || spec.spec == 'u' ? 10 : 0;
    assert(base != 0, "base must be not equal to zero");

    return parse!T(input, base);

}

/// ditto
private T unformatValueImpl(T, Range, Char)(ref Range input, scope const ref FormatSpec!Char spec)
if (isFloatingPoint!T && !is(T == enum) && isInputRange!Range
    && isSomeChar!(ElementType!Range)&& !is(Range == enum))
{
    import std.algorithm.searching : find;
    import std.conv : parse, text;

    if (spec.spec == 'r')
    {
        static if (is(immutable ElementEncodingType!Range == immutable char)
                || is(immutable ElementEncodingType!Range == immutable byte)
                || is(immutable ElementEncodingType!Range == immutable ubyte))
            return rawRead!T(input);
        else
            throw new FormatException(
                "The raw read specifier %r may only be used with narrow strings and ranges of bytes."
            );
    }

    enforceFmt(find(acceptedSpecs!T, spec.spec).length,
            text("Wrong unformat specifier '%", spec.spec , "' for ", T.stringof));

    return parse!T(input);
}

/// ditto
private T unformatValueImpl(T, Range, Char)(ref Range input, scope const ref FormatSpec!Char spec)
if (isInputRange!Range && isSomeChar!T && !is(T == enum) && isSomeChar!(ElementType!Range))
{
    import std.algorithm.searching : find;
    import std.conv : to, text;
    if (spec.spec == 's' || spec.spec == 'c')
    {
        auto result = to!T(input.front);
        input.popFront();
        return result;
    }
    enforceFmt(find(acceptedSpecs!T, spec.spec).length,
            text("Wrong unformat specifier '%", spec.spec , "' for ", T.stringof));

    static if (T.sizeof == 1)
        return unformatValue!ubyte(input, spec);
    else static if (T.sizeof == 2)
        return unformatValue!ushort(input, spec);
    else static if (T.sizeof == 4)
        return unformatValue!uint(input, spec);
    else
        static assert(false, T.stringof ~ ".sizeof must be 1, 2, or 4 not " ~
                to!string(T.sizeof));
}

/// ditto
private T unformatValueImpl(T, Range, Char)(ref Range input, scope const ref FormatSpec!Char fmt)
if (isInputRange!Range && is(StringTypeOf!T) && !isAggregateType!T && !is(T == enum))
{
    import std.conv : text;

    const spec = fmt.spec;
    if (spec == '(')
    {
        return unformatRange!T(input, fmt);
    }
    enforceFmt(spec == 's',
            text("Wrong unformat specifier '%", spec , "' for ", T.stringof));

    static if (isStaticArray!T)
    {
        T result;
        auto app = result[];
    }
    else
    {
        import std.array : appender;
        auto app = appender!T();
    }
    if (fmt.trailing.empty)
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
        immutable end = fmt.trailing.front;
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
        enforceFmt(app.empty, "need more input");
        return result;
    }
    else
        return app.data;
}

/// ditto
private T unformatValueImpl(T, Range, Char)(ref Range input, scope const ref FormatSpec!Char fmt)
if (isInputRange!Range && isArray!T && !is(StringTypeOf!T) && !isAggregateType!T && !is(T == enum))
{
    import std.conv : parse, text;
    const spec = fmt.spec;
    if (spec == '(')
    {
        return unformatRange!T(input, fmt);
    }
    enforceFmt(spec == 's',
            text("Wrong unformat specifier '%", spec , "' for ", T.stringof));

    return parse!T(input);
}

/// ditto
private T unformatValueImpl(T, Range, Char)(ref Range input, scope const ref FormatSpec!Char fmt)
if (isInputRange!Range && isAssociativeArray!T && !is(T == enum))
{
    import std.conv : parse, text;
    const spec = fmt.spec;
    if (spec == '(')
    {
        return unformatRange!T(input, fmt);
    }
    enforceFmt(spec == 's',
            text("Wrong unformat specifier '%", spec , "' for ", T.stringof));

    return parse!T(input);
}

/**
 * Function that performs raw reading. Used by unformatValue
 * for integral and float types.
 */
private T rawRead(T, Range)(ref Range input)
if (is(immutable ElementEncodingType!Range == immutable char)
    || is(immutable ElementEncodingType!Range == immutable byte)
    || is(immutable ElementEncodingType!Range == immutable ubyte))
{
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
            x.raw[i] = input.front;
            input.popFront();
        }
    }
    return x.typed;
}

//debug = unformatRange;

private T unformatRange(T, Range, Char)(ref Range input, scope const ref FormatSpec!Char spec)
in
{
    const char ss = spec.spec;
    assert(ss == '(', "spec.spec must be '(' not " ~ ss);
}
do
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
    debug (unformatRange) printf("cont = %.*s\n", cast(int) cont.length, cont.ptr);

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
            enforceFmt(!input.empty, "Unexpected end of input when parsing range");

            debug (unformatRange) printf("\t) spec = %c, front = %c ", fmt.spec, input.front);
            static if (isStaticArray!T)
            {
                result[i++] = unformatElement!(typeof(T.init[0]))(input, fmt);
            }
            else static if (isDynamicArray!T)
            {
                import std.conv : WideElementType;
                result ~= unformatElement!(WideElementType!T)(input, fmt);
            }
            else static if (isAssociativeArray!T)
            {
                auto key = unformatElement!(typeof(T.init.keys[0]))(input, fmt);
                fmt.readUpToNextSpec(input);        // eat key separator

                result[key] = unformatElement!(typeof(T.init.values[0]))(input, fmt);
            }
            debug (unformatRange) {
            if (input.empty) printf("-> front = [empty] ");
            else             printf("-> front = %c ", input.front);
            }

            static if (isStaticArray!T)
            {
                debug (unformatRange) printf("i = %u < %u\n", i, T.length);
                enforceFmt(i <= T.length, "Too many format specifiers for static array of length %d".format(T.length));
            }

            if (spec.sep !is null)
                fmt.readUpToNextSpec(input);
            auto sep = spec.sep !is null ? spec.sep
                         : fmt.trailing;
            debug (unformatRange) {
            if (!sep.empty && !input.empty) printf("-> %c, sep = %.*s\n", input.front, cast(int) sep.length, sep.ptr);
            else                            printf("\n");
            }

            if (checkEnd())
                break;

            if (!sep.empty && input.front == sep.front)
            {
                while (!sep.empty)
                {
                    enforceFmt(!input.empty, "Unexpected end of input when parsing range separator");
                    enforceFmt(input.front == sep.front, "Unexpected character when parsing range separator");
                    input.popFront();
                    sep.popFront();
                }
                debug (unformatRange) printf("input.front = %c\n", input.front);
            }
        }
    }
    static if (isStaticArray!T)
    {
        enforceFmt(i == T.length, "Too few (%d) format specifiers for static array of length %d".format(i, T.length));
    }
    return result;
}

// Undocumented
T unformatElement(T, Range, Char)(ref Range input, scope const ref FormatSpec!Char spec)
if (isInputRange!Range)
{
    import std.conv : parseElement;
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

