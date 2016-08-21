/*
*             Copyright Lodovico Giaretta 2016 - .
*  Distributed under the Boost Software License, Version 1.0.
*      (See accompanying file LICENSE_1_0.txt or copy at
*            http://www.boost.org/LICENSE_1_0.txt)
*/

/++
+   This module implements a low level XML parser.
+
+   The methods a parser should implement are documented in
+   $(LINK2 ../interfaces/isParser, `std.experimental.xml.interfaces.isParser`);
+
+   Authors:
+   Lodovico Giaretta
+
+   License:
+   <a href="http://www.boost.org/LICENSE_1_0.txt">Boost License 1.0</a>.
+
+   Copyright:
+   Copyright Lodovico Giaretta 2016 --
+/

module std.experimental.xml.parser;

import std.experimental.xml.interfaces;
import std.experimental.xml.faststrings;

import std.typecons : Flag, Yes, No;

/++
+   A low level XML parser.
+
+   The methods a parser should implement are documented in
+   $(LINK2 ../interfaces/isLexer, `std.experimental.xml.interfaces.isLexer`);
+
+   Params:
+       L = the underlying lexer type
+       ErrorHandler = a delegate type, used to report the impossibility to parse
+                      the file due to syntax errors
+       preserveWhitespace = if set to `Yes` (default is `No`), the parser will not remove
+       element content whitespace (i.e. the whitespace that separates tags), but will
+       report it as text
+/
struct Parser(L, ErrorHandler, Flag!"preserveWhitespace" preserveWhitespace = No.preserveWhitespace)
    if (isLexer!L)
{
    import std.meta : staticIndexOf;

    /++
    +   The structure returned in output from the low level parser.
    +   Represents an XML token, delimited by specific patterns, based on its kind.
    +   This delimiters are not present in the content field.
    +/
    struct XMLToken
    {
        /++ The content of the token, delimiters excluded +/
        L.CharacterType[] content;

        /++ Represents the kind of token +/
        XMLKind kind;
    }

    private L lexer;
    private bool ready, insideDTD;
    private XMLToken next;

    mixin UsesErrorHandler!ErrorHandler;

    /++ Generic constructor; forwards its arguments to the lexer constructor +/
    this(Args...)(Args args)
    {
        lexer = L(args);
    }

    alias InputType = L.InputType;
    alias CharacterType = L.CharacterType;

    /++
    +   See detailed documentation in
    +   $(LINK2 ../interfaces/isParser, `std.experimental.xml.interfaces.isParser`)
    +/
    void setSource(InputType input)
    {
        lexer.setSource(input);
        ready = false;
        insideDTD = false;
    }

    static if (isSaveableLexer!L)
    {
        auto save()
        {
            Parser result = this;
            result.lexer = lexer.save;
            return result;
        }
    }

    private CharacterType[] fetchContent(size_t start = 0, size_t stop = 0)
    {
        return lexer.get[start..($ - stop)];
    }

    /++
    +   See detailed documentation in
    +   $(LINK2 ../interfaces/isParser, `std.experimental.xml.interfaces.isParser`)
    +/
    bool empty()
    {
        static if (preserveWhitespace == No.preserveWhitespace)
            lexer.dropWhile(" \r\n\t");

        return !ready && lexer.empty;
    }

    /// ditto
    auto front()
    {
        if (!ready)
            fetchNext();
        return next;
    }

    /// ditto
    void popFront()
    {
        front();
        ready = false;
    }

    private void fetchNext()
    {
        if (!preserveWhitespace || insideDTD)
            lexer.dropWhile(" \r\n\t");

        assert(!lexer.empty);

        lexer.start();

        // dtd end
        if (insideDTD && lexer.testAndAdvance(']'))
        {
            lexer.dropWhile(" \r\n\t");
            if (!lexer.testAndAdvance('>'))
            {
                handler();
            }
            next.kind = XMLKind.DTD_END;
            next.content = null;
            insideDTD = false;
        }

        // text element
        else if (!lexer.testAndAdvance('<'))
        {
            lexer.advanceUntil('<', false);
            next.kind = XMLKind.TEXT;
            next.content = fetchContent();
        }

        // tag end
        else if (lexer.testAndAdvance('/'))
        {
            lexer.advanceUntil('>', true);
            next.content = fetchContent(2, 1);
            next.kind = XMLKind.ELEMENT_END;
        }
        // processing instruction
        else if (lexer.testAndAdvance('?'))
        {
            do
                lexer.advanceUntil('?', true);
            while (!lexer.testAndAdvance('>'));
            next.content = fetchContent(2, 2);
            next.kind = XMLKind.PROCESSING_INSTRUCTION;
        }
        // tag start
        else if (!lexer.testAndAdvance('!'))
        {
            size_t c;
            while ((c = lexer.advanceUntilAny("\"'/>", true)) < 2)
                if (c == 0)
                    lexer.advanceUntil('"', true);
                else
                    lexer.advanceUntil('\'', true);

            if (c == 2)
            {
                lexer.advanceUntil('>', true); // should be the first character after '/'
                next.content = fetchContent(1, 2);
                next.kind = XMLKind.ELEMENT_EMPTY;
            }
            else
            {
                next.content = fetchContent(1, 1);
                next.kind = XMLKind.ELEMENT_START;
            }
        }

        // cdata or conditional
        else if (lexer.testAndAdvance('['))
        {
            lexer.advanceUntil('[', true);
            // cdata
            if (lexer.get.length == 9 && fastEqual(lexer.get()[3..$], "CDATA["))
            {
                do
                    lexer.advanceUntil('>', true);
                while (!fastEqual(lexer.get()[($-3)..$], "]]>"));
                next.content = fetchContent(9, 3);
                next.kind = XMLKind.CDATA;
            }
            // conditional
            else
            {
                int count = 1;
                do
                {
                    lexer.advanceUntilAny("[>", true);
                    if (lexer.get()[($-3)..$] == "]]>")
                        count--;
                    else if (lexer.get()[($-3)..$] == "<![")
                        count++;
                }
                while (count > 0);
                next.content = fetchContent(3, 3);
                next.kind = XMLKind.CONDITIONAL;
            }
        }
        // comment
        else if (lexer.testAndAdvance('-'))
        {
            lexer.testAndAdvance('-'); // second '-'
            do
                lexer.advanceUntil('>', true);
            while (!fastEqual(lexer.get()[($-3)..$], "-->"));
            next.content = fetchContent(4, 3);
            next.kind = XMLKind.COMMENT;
        }
        // declaration or doctype
        else
        {
            size_t c;
            while ((c = lexer.advanceUntilAny("\"'[>", true)) < 2)
                if (c == 0)
                    lexer.advanceUntil('"', true);
                else
                    lexer.advanceUntil('\'', true);

            // doctype
            if (lexer.get.length>= 9 && fastEqual(lexer.get()[2..9], "DOCTYPE"))
            {
                next.content = fetchContent(9, 1);
                if (c == 2)
                {
                    next.kind = XMLKind.DTD_START;
                    insideDTD = true;
                }
                else next.kind = XMLKind.DTD_EMPTY;
            }
            // declaration
            else
            {
                if (c == 2)
                {
                    size_t cc;
                    while ((cc = lexer.advanceUntilAny("\"'>", true)) < 2)
                        if (cc == 0)
                            lexer.advanceUntil('"', true);
                        else
                            lexer.advanceUntil('\'', true);
                }
                auto len = lexer.get().length;
                if (len > 8 && fastEqual(lexer.get()[2..9], "ATTLIST"))
                {
                    next.content = fetchContent(9, 1);
                    next.kind = XMLKind.ATTLIST_DECL;
                }
                else if (len > 8 && fastEqual(lexer.get()[2..9], "ELEMENT"))
                {
                    next.content = fetchContent(9, 1);
                    next.kind = XMLKind.ELEMENT_DECL;
                }
                else if (len > 9 && fastEqual(lexer.get()[2..10], "NOTATION"))
                {
                    next.content = fetchContent(10, 1);
                    next.kind = XMLKind.NOTATION_DECL;
                }
                else if (len > 7 && fastEqual(lexer.get()[2..8], "ENTITY"))
                {
                    next.content = fetchContent(8, 1);
                    next.kind = XMLKind.ENTITY_DECL;
                }
                else
                {
                    next.content = fetchContent(2, 1);
                    next.kind = XMLKind.DECLARATION;
                }
            }
        }

        ready = true;
    }
}

/++
+   Returns an instance of `Parser` from the given lexer.
+
+   Params:
+       preserveWhitespace = whether the returned `Parser` shall skip element content
+                            whitespace or return it as text nodes
+       lexer = the _lexer to build this `Parser` from
+
+   Returns:
+   A `Parser` instance initialized with the given lexer
+/
auto parse(Flag!"preserveWhitespace" preserveWhitespace = No.preserveWhitespace, T, ErrorHandler)
          (auto ref T lexer, ErrorHandler handler = () { assert(0, "XML syntax error"); })
    if (isLexer!T)
{
    auto parser = Parser!(T, ErrorHandler, preserveWhitespace)();
    parser.errorHandler = handler;
    parser.lexer = lexer;
    return parser;
}

import std.experimental.xml.lexers;
import std.experimental.allocator.gc_allocator;

/++
+   Instantiates a parser suitable for the given `InputType`.
+
+   This is completely equivalent to
+   ---
+   auto parser = 
+        chooseLexer!(InputType, reuseBuffer)(alloc, handler)
+       .parse!(preserveWhitespace)(handler)
+   ---
+/
auto chooseParser(InputType,
                  Flag!"preserveWhitespace" preserveWhitespace = No.preserveWhitespace,
                  Flag!"reuseBuffer" reuseBuffer = Yes.reuseBuffer,
                  Alloc, ErrorHandler)
                 (ref Alloc alloc, ErrorHandler handler = () { assert(0, "XML syntax error"); })
{
    return chooseLexer!(InputType, reuseBuffer, Alloc, ErrorHandler)(alloc, handler)
          .parse!(preserveWhitespace)(handler);
}
/// ditto
auto chooseParser(alias InputType,
                  Flag!"preserveWhitespace" preserveWhitespace = No.preserveWhitespace,
                  Flag!"reuseBuffer" reuseBuffer = Yes.reuseBuffer,
                  Alloc, ErrorHandler)
                 (ref Alloc alloc, ErrorHandler handler = () { assert(0, "XML syntax error"); })
{
    return chooseParser!(typeof(InputType), preserveWhitespace, reuseBuffer, Alloc, ErrorHandler)(alloc, handler);
}
/// ditto
auto chooseParser(InputType, Alloc = shared(GCAllocator),
                  Flag!"preserveWhitespace" preserveWhitespace = No.preserveWhitespace,
                  Flag!"reuseBuffer" reuseBuffer = Yes.reuseBuffer,
                  ErrorHandler)
                 (ErrorHandler handler = () { assert(0, "XML syntax error"); })
    if (is(typeof(Alloc.instance)))
{
    return chooseParser!(InputType, preserveWhitespace, reuseBuffer, Alloc, ErrorHandler)(Alloc.instance, handler);
}
/// ditto
auto chooseParser(alias InputType, Alloc = shared(GCAllocator),
                  Flag!"preserveWhitespace" preserveWhitespace = No.preserveWhitespace,
                  Flag!"reuseBuffer" reuseBuffer = Yes.reuseBuffer,
                  ErrorHandler)
                 (ErrorHandler handler = () { assert(0, "XML syntax error"); })
    if (is(typeof(Alloc.instance)))
{
    return chooseParser!(typeof(InputType), preserveWhitespace, reuseBuffer, Alloc, ErrorHandler)
                        (Alloc.instance, handler);
}

@nogc unittest
{
    import std.experimental.xml.lexers;
    import std.experimental.allocator.mallocator;
    import std.string : lineSplitter;
    import std.algorithm : equal;

    string xml = q{
    <?xml encoding = "utf-8" ?>
    <aaa xmlns:myns="something">
        <myns:bbb myns:att='>'>
            <!-- lol -->
            Lots of Text!
            On multiple lines!
        </myns:bbb>
        <![CDATA[ Ciaone! ]]>
        <ccc/>
    </aaa>
    };

    auto handler = () { assert(0, "Oopss..."); };
    auto lexer = RangeLexer!(string, typeof(handler), shared(Mallocator))(Mallocator.instance);
    lexer.errorHandler = handler;
    auto parser = lexer.parse;
    parser.setSource(xml);

    alias XMLKind = typeof(parser.front.kind);

    assert(parser.front.kind == XMLKind.PROCESSING_INSTRUCTION);
    assert(parser.front.content == "xml encoding = \"utf-8\" ");
    parser.popFront();

    assert(parser.front.kind == XMLKind.ELEMENT_START);
    assert(parser.front.content == "aaa xmlns:myns=\"something\"");
    parser.popFront();

    assert(parser.front.kind == XMLKind.ELEMENT_START);
    assert(parser.front.content == "myns:bbb myns:att='>'");
    parser.popFront();

    assert(parser.front.kind == XMLKind.COMMENT);
    assert(parser.front.content == " lol ");
    parser.popFront();

    assert(parser.front.kind == XMLKind.TEXT);
    // use lineSplitter so the unittest does not depend on the newline policy of this file
    static immutable linesArr = ["Lots of Text!", "            On multiple lines!", "        "];
    assert(parser.front.content.lineSplitter.equal(linesArr));
    parser.popFront();

    assert(parser.front.kind == XMLKind.ELEMENT_END);
    assert(parser.front.content == "myns:bbb");
    parser.popFront();

    assert(parser.front.kind == XMLKind.CDATA);
    assert(parser.front.content == " Ciaone! ");
    parser.popFront();

    assert(parser.front.kind == XMLKind.ELEMENT_EMPTY);
    assert(parser.front.content == "ccc");
    parser.popFront();

    assert(parser.front.kind == XMLKind.ELEMENT_END);
    assert(parser.front.content == "aaa");
    parser.popFront();

    assert(parser.empty);
}

unittest
{
    import std.experimental.xml.lexers;
    import std.algorithm : find;
    import std.string : stripRight;

    string xml = q{
    <!DOCTYPE mydoc https://myUri.org/bla [
        <!ELEMENT myelem ANY>
        <!ENTITY   myent    "replacement text">
        <!ATTLIST myelem foo CDATA #REQUIRED >
        <!NOTATION PUBLIC 'h'>
        <!FOODECL asdffdsa >
    ]>
    };

    auto parser = chooseParser!xml;
    parser.setSource(xml);

    alias XMLKind = typeof(parser.front.kind);

    assert(parser.front.kind == XMLKind.DTD_START);
    assert(parser.front.content == " mydoc https://myUri.org/bla ");
    parser.popFront;

    assert(parser.front.kind == XMLKind.ELEMENT_DECL);
    assert(parser.front.content == " myelem ANY");
    parser.popFront;

    assert(parser.front.kind == XMLKind.ENTITY_DECL);
    assert(parser.front.content == "   myent    \"replacement text\"");
    parser.popFront;

    assert(parser.front.kind == XMLKind.ATTLIST_DECL);
    assert(parser.front.content == " myelem foo CDATA #REQUIRED ");
    parser.popFront;

    assert(parser.front.kind == XMLKind.NOTATION_DECL);
    assert(parser.front.content == " PUBLIC 'h'");
    parser.popFront;

    assert(parser.front.kind == XMLKind.DECLARATION);
    assert(parser.front.content == "FOODECL asdffdsa ");
    parser.popFront;

    assert(parser.front.kind == XMLKind.DTD_END);
    assert(!parser.front.content);
    parser.popFront;

    assert(parser.empty);
}