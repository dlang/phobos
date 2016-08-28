/*
*             Copyright Lodovico Giaretta 2016 - .
*  Distributed under the Boost Software License, Version 1.0.
*      (See accompanying file LICENSE_1_0.txt or copy at
*            http://www.boost.org/LICENSE_1_0.txt)
*/

/++
+   This module implements a simple SAX parser.
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

module std.experimental.xml.sax;

import std.experimental.xml.interfaces;
import std.experimental.xml.cursor;

/++
+   A SAX parser built on top of a cursor.
+
+   It delegates all handling to `H`, which must be either a type or a template
+   that can be instantiated to a type applying the underlying cursor type (`T`) as parameter.
+/
struct SAXParser(T, alias H)
    if (isCursor!T)
{
    static if (__traits(isTemplate, H))
        alias HandlerType = H!T;
    else
        alias HandlerType = H;

    private T cursor;
    public HandlerType handler;

    /++
    +   Initializes this parser (and the underlying low level one) with the given input.
    +/
    void setSource(T.InputType input)
    {
        cursor.setSource(input);
    }

    static if (isSaveableCursor!T)
    {
        auto save()
        {
            auto result = this;
            result.cursor = cursor.save;
            return result;
        }
    }

    /++
    +   Processes the entire document; every time a node of
    +   `XMLKind` XXX is found, the corresponding method `onXXX(underlyingCursor)`
    +   of the handler is called, if it exists.
    +/
    void processDocument()
    {
        import std.traits : hasMember;
        while (!cursor.documentEnd)
        {
            switch (cursor.kind)
            {
                static if(hasMember!(HandlerType, "onDocument"))
                {
                    case XMLKind.document:
                        handler.onDocument(cursor);
                        break;
                }
                static if (hasMember!(HandlerType, "onElementStart"))
                {
                    case XMLKind.elementStart:
                        handler.onElementStart(cursor);
                        break;
                }
                static if (hasMember!(HandlerType, "onElementEnd"))
                {
                    case XMLKind.elementEnd:
                        handler.onElementEnd(cursor);
                        break;
                }
                static if (hasMember!(HandlerType, "onElementEmpty"))
                {
                    case XMLKind.elementEmpty:
                        handler.onElementEmpty(cursor);
                        break;
                }
                static if (hasMember!(HandlerType, "onText"))
                {
                    case XMLKind.text:
                        handler.onText(cursor);
                        break;
                }
                static if (hasMember!(HandlerType, "onComment"))
                {
                    case XMLKind.comment:
                        handler.onComment(cursor);
                        break;
                }
                static if (hasMember!(HandlerType, "onProcessingInstruction"))
                {
                    case XMLKind.processingInstruction:
                        handler.onProcessingInstruction(cursor);
                        break;
                }
                static if (hasMember!(HandlerType, "onCDataSection"))
                {
                    case XMLKind.cdata:
                        handler.onCDataSection(cursor);
                        break;
                }
                default: break;
            }

            if (cursor.enter)
            {
            }
            else if (!cursor.next)
                cursor.exit;
        }
    }
}

/++
+   Instantiates a suitable SAX parser from the given `cursor` and `handler`.
+/
auto saxParser(alias HandlerType, CursorType)(auto ref CursorType cursor)
    if (isCursor!CursorType)
{
    auto res = SAXParser!(CursorType, HandlerType)();
    res.cursor = cursor;
    return res;
}
/// ditto
auto saxParser(alias HandlerType, CursorType)(auto ref CursorType cursor,
                                        auto ref SAXParser!(CursorType, HandlerType).HandlerType handler)
    if (isCursor!CursorType)
{
    auto res = SAXParser!(CursorType, HandlerType)();
    res.cursor = cursor;
    res.handler = handler;
    return res;
}

unittest
{
    import std.experimental.xml.parser;
    import std.experimental.xml.lexers;

    dstring xml = q{
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

    static struct MyHandler(T)
    {
        int max_nesting;
        int current_nesting;
        int total_invocations;

        void onElementStart(ref T node)
        {
            total_invocations++;
            current_nesting++;
            if (current_nesting > max_nesting)
                max_nesting = current_nesting;
        }
        void onElementEnd(ref T node)
        {
            total_invocations++;
            current_nesting--;
        }
        void onElementEmpty(ref T node) { total_invocations++; }
        void onProcessingInstruction(ref T node) { total_invocations++; }
        void onText(ref T node) { total_invocations++; }
        void onDocument(ref T node)
        {
            auto attrs = node.attributes;
            assert(attrs.front == Attribute!dstring("encoding", "utf-8"));
            attrs.popFront;
            assert(attrs.empty);
            total_invocations++;
        }
        void onComment(ref T node)
        {
            assert(node.content == " lol ");
            total_invocations++;
        }
    }

    auto parser =
         chooseLexer!xml
        .parse
        .cursor
        .saxParser!MyHandler;

    parser.setSource(xml);
    parser.processDocument();

    assert(parser.handler.max_nesting == 2);
    assert(parser.handler.current_nesting == 0);
    assert(parser.handler.total_invocations == 9);
}
