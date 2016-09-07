/*
*             Copyright Lodovico Giaretta 2016 - .
*  Distributed under the Boost Software License, Version 1.0.
*      (See accompanying file LICENSE_1_0.txt or copy at
*            http://www.boost.org/LICENSE_1_0.txt)
*/

/++
+   Authors:
+   Lodovico Giaretta
+
+   License:
+   <a href="http://www.boost.org/LICENSE_1_0.txt">Boost License 1.0</a>.
+
+   Copyright:
+   Copyright Lodovico Giaretta 2016 --
+/

module std.experimental.xml.domparser;

import std.experimental.xml.interfaces;
import std.experimental.xml.cursor;

import dom = std.experimental.xml.dom;

/++
+   Built on top of Cursor, the DOM builder adds to it the ability to
+   build the DOM tree of the document; as the cursor advances, nodes can be
+   selectively added to the tree, allowing to built a small representation
+   containing only the needed parts of the document.
+
+   This type should not be instantiated directly. Instead, the helper function
+   `domBuilder` should be used.
+/
struct DOMBuilder(T, DOMImplementation = dom.DOMImplementation!(T.StringType))
    if (isCursor!T && is(DOMImplementation : dom.DOMImplementation!(T.StringType)))
{
    import std.traits : ReturnType;

    /++
    +   The underlying Cursor methods are exposed, so that one can, query the properties
    +   of the current node before deciding if building it or not.
    +/
    T cursor;
    alias cursor this;

    alias StringType = T.StringType;

    alias DocumentType = ReturnType!(DOMImplementation.createDocument);
    alias NodeType = typeof(DocumentType.firstChild);

    private NodeType currentNode;
    private DocumentType document;
    private DOMImplementation domImpl;
    private bool already_built;

    this(Args...)(DOMImplementation impl, auto ref Args args)
    {
        cursor = typeof(cursor)(args);
        domImpl = impl;
    }

    /++
    +   Initializes this builder and the underlying components.
    +/
    void setSource(T.InputType input)
    {
        cursor.setSource(input);
        document = domImpl.createDocument(null, null, null);

        if (cursor.kind == XMLKind.document)
            foreach (attr; cursor.attributes)
                switch (attr.name)
                {
                    case "version":
                        document.xmlVersion = attr.value;
                        break;
                    case "standalone":
                        document.xmlStandalone = attr.value == "yes";
                        break;
                    default:
                        break;
                }

        currentNode = document;
    }

    /++
    +   Same as `cursor.enter`. When entering a node, that node is automatically
    +   built into the DOM, so that its children can then be safely built if needed.
    +/
    bool enter()
    {
        if (cursor.atBeginning)
            return cursor.enter;

        if (cursor.kind != XMLKind.elementStart)
            return false;

        if (!already_built)
        {
            auto elem = createCurrent;

            if (cursor.enter)
            {
                currentNode.appendChild(elem);
                currentNode = elem;
                return true;
            }
        }
        else if (cursor.enter)
        {
            already_built = false;
            currentNode = currentNode.lastChild;
            return true;
        }
        return false;
    }

    /++
    +   Same as `cursor.exit`
    +/
    void exit()
    {
        if (currentNode)
            currentNode = currentNode.parentNode;
        already_built = false;
        cursor.exit;
    }

    /++
    +   Same as `cursor.next`.
    +/
    bool next()
    {
        already_built = false;
        return cursor.next;
    }

    /++
    +   Adds the current node to the DOM. This operation does not advance the input.
    +   Calling it more than once does not change the result.
    +/
    void build()
    {
        if (already_built || cursor.atBeginning)
            return;

        auto cur = createCurrent;
        if (cur)
            currentNode.appendChild(createCurrent);

        already_built = true;
    }

    /++
    +   Recursively adds the current node and all its children to the DOM tree.
    +   Behaves as `cursor.next`: it advances the input to the next sibling, returning
    +   `true` if and only if there exists such next sibling.
    +/
    bool buildRecursive()
    {
        if (enter)
        {
            while (buildRecursive) {}
            exit;
        }
        else
            build;

        return next;
    }

    private NodeType createCurrent()
    // TODO: namespace handling
    {
        switch (cursor.kind)
        {
            case XMLKind.elementStart:
            case XMLKind.elementEmpty:
                auto elem = document.createElement(cursor.name);
                foreach (attr; cursor.attributes)
                {
                    elem.setAttribute(attr.name, attr.value);
                }
                return elem;
            case XMLKind.text:
                return document.createTextNode(cursor.content);
            case XMLKind.cdata:
                return document.createCDATASection(cursor.content);
            case XMLKind.processingInstruction:
                return document.createProcessingInstruction(cursor.name, cursor.content);
            case XMLKind.comment:
                return document.createComment(cursor.content);
            default:
                return null;
        }
    }

    /++
    +   Returns the Document being built by this builder.
    +/
    auto getDocument() { return document; }
}

/++
+   Instantiates a suitable `DOMBuilder` on top of the given `cursor` and `DOMImplementation`.
+/
auto domBuilder(CursorType, DOMImplementation)(auto ref CursorType cursor, DOMImplementation impl)
    if (isCursor!CursorType && is(DOMImplementation : dom.DOMImplementation!(CursorType.StringType)))
{
    auto res = DOMBuilder!(CursorType, DOMImplementation)();
    res.cursor = cursor;
    res.domImpl = impl;
    return res;
}

unittest
{
    import std.stdio;

    import std.experimental.xml.lexers;
    import std.experimental.xml.parser;
    import std.experimental.xml.cursor;
    import std.experimental.allocator.gc_allocator;
    import domimpl = std.experimental.xml.domimpl;

    alias DOMImplType = domimpl.DOMImplementation!string;

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

    auto builder =
         xml
        .lexer
        .parser
        .cursor
        .copyingCursor
        .domBuilder(new DOMImplType());

    builder.setSource(xml);
    builder.buildRecursive;
    auto doc = builder.getDocument;

    assert(doc.getElementsByTagName("ccc").length == 1);
    assert(doc.documentElement.getAttribute("xmlns:myns") == "something");
}