// Written in the D programming language.

/*
   Copyright: Copyright The D Language Foundation 2000-2013.

   License: $(HTTP boost.org/LICENSE_1_0.txt, Boost License 1.0).

   Authors: $(HTTP walterbright.com, Walter Bright), $(HTTP erdani.com,
   Andrei Alexandrescu), and Kenji Hara

   Source: $(PHOBOSSRC std/format/internal/read.d)
 */
module std.format.internal.read;

import std.range.primitives;
import std.traits;

import std.format;

package(std.format) void skipData(Range, Char)(ref Range input, scope const ref FormatSpec!Char spec)
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
    static if (isIntegral!T)
        enum acceptedSpecs = "bdosuxX";
    else static if (isFloatingPoint!T)
        enum acceptedSpecs = "seEfgG";
    else static if (isSomeChar!T)
        enum acceptedSpecs = "bcdosuxX";    // integral + 'c'
    else
        enum acceptedSpecs = "";
}

package(std.format) T unformatValueImpl(T, Range, Char)(ref Range input, scope const ref FormatSpec!Char spec)
if (isInputRange!Range && is(immutable T == immutable bool))
{
    import std.algorithm.searching : find;
    import std.conv : parse, text;

    if (spec.spec == 's') return parse!T(input);

    enforceFmt(find(acceptedSpecs!long, spec.spec).length,
               text("Wrong unformat specifier '%", spec.spec , "' for ", T.stringof));

    return unformatValue!long(input, spec) != 0;
}

package(std.format) T unformatValueImpl(T, Range, Char)(ref Range input, scope const ref FormatSpec!Char spec)
if (isInputRange!Range && is(T == typeof(null)))
{
    import std.conv : parse, text;
    enforceFmt(spec.spec == 's',
               text("Wrong unformat specifier '%", spec.spec , "' for ", T.stringof));

    return parse!T(input);
}

/// ditto
package(std.format) T unformatValueImpl(T, Range, Char)(ref Range input, scope const ref FormatSpec!Char spec)
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
package(std.format) T unformatValueImpl(T, Range, Char)(ref Range input, scope const ref FormatSpec!Char spec)
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
package(std.format) T unformatValueImpl(T, Range, Char)(ref Range input, scope const ref FormatSpec!Char spec)
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
package(std.format) T unformatValueImpl(T, Range, Char)(ref Range input, scope const ref FormatSpec!Char fmt)
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
package(std.format) T unformatValueImpl(T, Range, Char)(ref Range input, scope const ref FormatSpec!Char fmt)
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
package(std.format) T unformatValueImpl(T, Range, Char)(ref Range input, scope const ref FormatSpec!Char fmt)
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

/*
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
            debug (unformatRange)
            {
                if (input.empty)
                    printf("-> front = [empty] ");
                else
                    printf("-> front = %c ", input.front);
            }

            static if (isStaticArray!T)
            {
                debug (unformatRange) printf("i = %u < %u\n", i, T.length);
                enforceFmt(i <= T.length, "Too many format specifiers for static array of length %d".format(T.length));
            }

            if (spec.sep !is null)
                fmt.readUpToNextSpec(input);
            auto sep = spec.sep !is null ? spec.sep : fmt.trailing;
            debug (unformatRange)
            {
                if (!sep.empty && !input.empty)
                    printf("-> %c, sep = %.*s\n", input.front, cast(int) sep.length, sep.ptr);
                else
                    printf("\n");
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
