/*
*             Copyright Lodovico Giaretta 2016 - .
*  Distributed under the Boost Software License, Version 1.0.
*      (See accompanying file LICENSE_1_0.txt or copy at
*            http://www.boost.org/LICENSE_1_0.txt)
*/

/++
+   This module implements fast search and compare
+   functions on slices. In the future, these may be
+   optimized by means of aggressive specialization,
+   inline assembly and SIMD instructions.
+/

module std.experimental.xml.faststrings;

/++ Compares for equality; input slices must have equal length. +/
bool fastEqual(T, S)(T[] t, S[] s) pure @nogc nothrow
in
{
    assert(t.length == s.length);
}
body
{
    import std.traits;
    static if (is(Unqual!S == Unqual!T))
    {
        import core.stdc.string : memcmp;
        return memcmp(t.ptr, s.ptr, t.length * T.sizeof) == 0;
    }
    else
    {
        foreach (i; 0 .. t.length)
            if (t[i] != s[i])
                return false;
        return true;
    }
}
unittest
{
    assert( fastEqual("ciao"w, "ciao"w));
    assert(!fastEqual("ciao", "ciAo"));
    assert( fastEqual([1, 2], [1, 2]));
    assert(!fastEqual([1, 2], [1, 3]));
}

/++ Returns the index of the first occurrence of a value in a slice. +/
package ptrdiff_t fastIndexOf(T, S)(T[] t, S s) pure @nogc nothrow
{
    foreach (i; 0 .. t.length)
        if (t[i] == s)
            return i;
    return -1;
}
unittest
{
    assert(fastIndexOf("FoO"w, 'O') == 2);
    assert(fastIndexOf([1, 2], 3.14) == -1);
}

package ptrdiff_t fastLastIndexOf(T, S)(T[] t, S s)
{
    foreach_reverse (i; 0.. t.length)
        if (t[i] == s)
            return i;
    return -1;
}
unittest
{
    assert(fastLastIndexOf("FoOo"w, 'o') == 3);
    assert(fastLastIndexOf([1, 2], 3.14) == -1);
}

/++
+ Returns the index of the first occurrence of any of the values in the second
+ slice inside the first one.
+/
package ptrdiff_t fastIndexOfAny(T, S)(T[] t, S[] s) pure @nogc nothrow
{
    foreach (i; 0 .. t.length)
        if (fastIndexOf(s, t[i]) != -1)
            return i;
    return -1;
}
unittest
{
    assert(fastIndexOfAny([1, 2, 3, 4], [5, 4, 3]) == 2);
    assert(fastIndexOfAny("Foo", "baz") == -1);
}

/++
+ Returns the index of the first occurrence of a value of the first slice that
+ does not appear in the second.
+/
package ptrdiff_t fastIndexOfNeither(T, S)(T[] t, S[] s) pure @nogc nothrow
{
    foreach (i; 0 .. t.length)
        if (fastIndexOf(s, t[i]) == -1)
            return i;
    return -1;
}
unittest
{
    assert(fastIndexOfNeither("lulublubla", "luck") == 4);
    assert(fastIndexOfNeither([1, 3, 2], [2, 3, 1]) == -1);
}

import std.experimental.allocator.gc_allocator;

/++
+   Returns a copy of the input string, after escaping all XML reserved characters.
+
+   If the string does not contain any reserved character, it is returned unmodified;
+   otherwise, a copy is made using the specified allocator.
+/
T[] xmlEscape(T, Alloc)(T[] str)
{
    return xmlEscape(str, Alloc.instance);
}
/// ditto
T[] xmlEscape(T, Alloc)(T[] str, ref Alloc alloc)
{
    if (str.fastIndexOfAny("&<>'\"") >= 0)
    {
        import std.experimental.xml.appender;

        auto app = Appender!(T, Alloc)(alloc);
        app.reserve(str.length + 3);

        app.xmlEscapedWrite(str);
        return app.data;
    }
    return str;
}

/++
+   Writes the input string to the given output range, after escaping all XML reserved characters.
+/
void xmlEscapedWrite(Out, T)(ref Out output, T[] str)
{
    import std.conv : to;
    static immutable amp = to!(T[])("&amp;");
    static immutable lt = to!(T[])("&lt;");
    static immutable gt = to!(T[])("&gt;");
    static immutable apos = to!(T[])("&apos;");
    static immutable quot = to!(T[])("&quot;");

    ptrdiff_t i;
    while ((i = str.fastIndexOfAny("&<>'\"")) >= 0)
    {
        output.put(str[0..i]);

        if (str[i] == '&')
            output.put(amp);
        else if (str[i] == '<')
            output.put(lt);
        else if (str[i] == '>')
            output.put(gt);
        else if (str[i] == '\'')
            output.put(apos);
        else if (str[i] == '"')
            output.put(quot);

        str = str[i+1..$];
    }
    output.put(str);
}

struct xmlPredefinedEntities(T)
{
    static immutable T[] amp = "&";
    static immutable T[] lt = "<";
    static immutable T[] gt = ">";
    static immutable T[] apos = "'";
    static immutable T[] quot = "\"";

    auto opBinaryRight(string op, U)(U key) const @nogc
        if (op == "in")
    {
        switch (key)
        {
            case "amp":
                return &amp;
            case "lt":
                return &lt;
            case "gt":
                return &gt;
            case "apos":
                return &apos;
            case "quot":
                return &quot;
            default:
                return null;
        }
    }
}

import std.typecons: Flag, Yes;

/++
+   Returns a copy of the input string, after unescaping all known entity references.
+
+   If the string does not contain any entity reference, it is returned unmodified;
+   otherwise, a copy is made using the specified allocator.
+
+   The set of known entities can be specified with the last parameter, which must support
+   the `in` operator (it is treated as an associative array).
+/
T[] xmlUnescape(Flag!"strict" strict = Yes.strict, T, Alloc, U)(T[] str, U replacements = xmlPredefinedEntities!T())
    if (is(typeof(Alloc.instance)))
{
    return xmlUnescape!strict(str, Alloc.instance, replacements);
}
/// ditto
T[] xmlUnescape(Flag!"strict" strict = Yes.strict, T, Alloc, U)
               (T[] str, ref Alloc alloc, U replacements = xmlPredefinedEntities!T())
{
    if (str.fastIndexOf('&') >= 0)
    {
        import std.experimental.xml.appender;

        auto app = Appender!(T, Alloc)(alloc);
        app.reserve(str.length);

        app.xmlUnescapedWrite!strict(str, replacements);
        return app.data;
    }
    return str;
}

/++
+   Outputs the input string to the given output range, after unescaping all known entity references.
+
+   The set of known entities can be specified with the last parameter, which must support
+   the `in` operator (it is treated as an associative array).
+/
void xmlUnescapedWrite(Flag!"strict" strict = Yes.strict, Out, T, U)
                      (ref Out output, T[] str, U replacements = xmlPredefinedEntities!T())
{
    ptrdiff_t i;
    while ((i = str.fastIndexOf('&')) >= 0)
    {
        output.put(str[0..i]);

        ptrdiff_t j = str[(i+1)..$].fastIndexOf(';');
        static if (strict == Yes.strict)
            assert (j > 0, "Missing ';' ending XML entity");
        else
            if (j < 0) break;
        auto ent = str[(i+1)..(i+j+1)];

        // character entities
        if (ent[0] == '#')
        {
            assert(ent.length > 1);
            uint num;
            // hex number
            if (ent.length > 2 && ent[1] == 'x')
            {
                foreach(digit; ent[2..$])
                {
                    if ('0' <= digit && digit <= '9')
                        num = (num << 4) + (digit - '0');
                    else if ('a' <= digit && digit <= 'f')
                        num = (num << 4) + (digit - 'a' + 10);
                    else if ('A' <= digit && digit <= 'F')
                        num = (num << 4) + (digit - 'A' + 10);
                    else
                        assert(0);
                }
            }
            // decimal number
            else
            {
                foreach(digit; ent[1..$])
                {
                    if ('0' <= digit && digit <= '9')
                        num = (num * 10) + (digit - '0');
                    else
                        assert(0);
                }
            }
            assert(num <= 0x10FFFF);
            output.put(cast(dchar)num);
        }
        // named entities
        else
        {
            auto repl = ent in replacements;
            static if (strict == Yes.strict)
                assert (repl, cast(string)str[(i+1)..(i+j+1)]);
            else
                if (!repl)
                {
                    app.put(str[i]);
                    str = str[(i+1)..$];
                    continue;
                }
            output.put(*repl);
        }

        str = str[(i+j+2)..$];
    }
    output.put(str);
}

@nogc unittest
{
    import std.experimental.allocator.mallocator;
    auto alloc = Mallocator.instance;
    assert(xmlEscape("some standard string"d, alloc) == "some standard string"d);
    assert(xmlEscape("& \"some\" <standard> 'string'", alloc) ==
                     "&amp; &quot;some&quot; &lt;standard&gt; &apos;string&apos;");
    assert(xmlEscape("<&'>>>\"'\"<&&"w, alloc) ==
                     "&lt;&amp;&apos;&gt;&gt;&gt;&quot;&apos;&quot;&lt;&amp;&amp;"w);
}

@nogc unittest
{
    import std.experimental.allocator.mallocator;
    auto alloc = Mallocator.instance;
    assert(xmlUnescape("some standard string"d, alloc) == "some standard string"d);
    assert(xmlUnescape("some s&#116;range&#x20;string", alloc) == "some strange string");
    assert(xmlUnescape("&amp; &quot;some&quot; &lt;standard&gt; &apos;string&apos;", alloc)
                       == "& \"some\" <standard> 'string'");
    assert(xmlUnescape("&lt;&amp;&apos;&gt;&gt;&gt;&quot;&apos;&quot;&lt;&amp;&amp;"w, alloc)
                       == "<&'>>>\"'\"<&&"w);
}
