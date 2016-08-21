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

module std.experimental.xml.cursor;

import std.experimental.xml.interfaces;
import std.experimental.xml.faststrings;

import std.meta : staticIndexOf;
import std.range.primitives;
import std.typecons;

/++
+ Enumeration of non-fatal errors that applications can intercept by setting
+ an handler on a cursor instance.
+/
enum CursorError
{
    /// The document does not begin with an XML declaration
    MISSING_XML_DECLARATION,
    /// The attributes could not be parsed due to invalid syntax
    INVALID_ATTRIBUTE_SYNTAX,
}

package struct Attribute(StringType)
{
    StringType value;
    private StringType _name;
    private size_t colon;

    this(StringType qualifiedName, StringType value)
    {
        this.value = value;
        name = qualifiedName;
    }

    @property auto name() inout
    {
        return _name;
    }
    @property void name(StringType _name)
    {
        import std.experimental.xml.faststrings;
        this._name = _name;
        auto i = _name.fastIndexOf(':');
        if (i > 0)
            colon = i;
        else
            colon = 0;
    }
    @property auto prefix() inout
    {
        return name[0..colon];
    }
    @property StringType localName()
    {
        if (colon)
            return name[colon+1..$];
        else
            return name;
    }
}

/++
+   An implementation of the $(LINK2 ../interfaces/isCursor, `isCursor`) trait.
+
+   This is the only provided cursor that builds on top of a parser (and not on top of
+   another cursor), so it is part of virtually every parsing chain.
+   All documented methods are implementations of the specifications dictated by
+   $(LINK2 ../interfaces/isCursor, `isCursor`).
+/
struct Cursor(P, Flag!"conflateCDATA" conflateCDATA = Yes.conflateCDATA, ErrorHandler = void delegate(CursorError))
    if (isLowLevelParser!P)
{
    /++
    +   The type of input accepted by this parser,
    +   i.e., the one accepted by the underlying low level parser.
    +/
    alias InputType = P.InputType;

    /++ The type of characters in the input, as returned by the underlying low level parser. +/
    alias CharacterType = P.CharacterType;

    /++ The type of sequences of CharacterType, as returned by this parser +/
    alias StringType = CharacterType[];

    private P parser;
    private ElementType!P currentNode;
    private bool starting, _documentEnd, nextFailed;
    private ptrdiff_t colon;
    private size_t nameEnd;
    private ErrorHandler handler;

    /++ Generic constructor; forwards its arguments to the parser constructor +/
    this(Args...)(Args args)
    {
        parser = P(args);
    }

    static if (isSaveableLowLevelParser!P)
    {
        public auto save()
        {
            auto result = this;
            result.parser = parser.save;
            return result;
        }
    }

    private void callHandler(CursorError err)
    {
        if (handler != null)
            handler(err);
        else
            assert(0);
    }

    private bool advanceInput()
    {
        colon = colon.max;
        nameEnd = 0;
        parser.popFront();
        if (!parser.empty)
        {
            currentNode = parser.front;
            return true;
        }
        _documentEnd = true;
        return false;
    }

    /++
    +   Overrides the current error handler with a new one.
    +   It will be called whenever a non-fatal error occurs.
    +   The default handler abort parsing by throwing an exception.
    +/
    void setErrorHandler(ErrorHandler handler)
    {
        assert(handler, "Trying to set null error handler");
        this.handler = handler;
    }

    /++
    +   Initializes this cursor (and the underlying low level parser) with the given input.
    +/
    void setSource(InputType input)
    {
        // reset private fields
        nextFailed = false;
        _documentEnd = false;
        colon = colon.max;
        nameEnd = 0;

        parser.setSource(input);
        if (!parser.empty)
        {
            if (parser.front.kind == XMLKind.PROCESSING_INSTRUCTION &&
                parser.front.content.length >= 3 &&
                fastEqual(parser.front.content[0..3], "xml"))
            {
                currentNode = parser.front;
            }
            else
            {
                // document without xml declaration???
                callHandler(CursorError.MISSING_XML_DECLARATION);
                currentNode.kind = XMLKind.PROCESSING_INSTRUCTION;
                currentNode.content = "xml version = \"1.0\"";
            }
            starting = true;
        }
    }

    /++ Returns whether the cursor is at the end of the document. +/
    bool documentEnd()
    {
        return _documentEnd;
    }

    /++
    +   Returns whether the cursor is at the beginning of the document
    +   (i.e. whether no enter/next/exit has been performed successfully and thus
    +   the cursor points to the xml declaration)
    +/
    bool atBeginning()
    {
        return starting;
    }

    /++
    +   Advances to the first child of the current node and returns true.
    +   If it returns false, the cursor is either on the same node (it wasn't
    +   an element start) or it is at the close tag of the element it was called on
    +   (it was a pair open/close tag without any content)
    +/
    bool enter()
    {
        if (starting)
        {
            starting = false;
            if (currentNode.content is parser.front.content)
                return advanceInput();
            else
                nameEnd = 0;

            currentNode = parser.front;
            return true;
        }
        else if (currentNode.kind == XMLKind.ELEMENT_START)
        {
            return advanceInput() && currentNode.kind != XMLKind.ELEMENT_END;
        }
        else if (currentNode.kind == XMLKind.DTD_START)
        {
            return advanceInput() && currentNode.kind != XMLKind.DTD_END;
        }
        else
            return false;
    }

    /++ Advances to the end of the parent of the current node. +/
    void exit()
    {
        if (!nextFailed)
            while (next()) {}

        nextFailed = false;
    }

    /++
    +   Advances to the next sibling of the current node.
    +   Returns whether it succeded. If it fails, either the
    +   document has ended or the only meaningful operation is exit().
    +/
    bool next()
    {
        if (parser.empty || starting || nextFailed)
            return false;
        else if (currentNode.kind == XMLKind.DTD_START)
        {
            while (advanceInput && currentNode.kind != XMLKind.DTD_END) {}
        }
        else if (currentNode.kind == XMLKind.ELEMENT_START)
        {
            int count = 1;
            while (count > 0 && !parser.empty)
            {
                if (!advanceInput)
                    return false;
                if (currentNode.kind == XMLKind.ELEMENT_START)
                    count++;
                else if (currentNode.kind == XMLKind.ELEMENT_END)
                    count--;
            }
        }
        if (!advanceInput || currentNode.kind == XMLKind.ELEMENT_END || currentNode.kind == XMLKind.DTD_END)
        {
            nextFailed = true;
            return false;
        }
        return true;
    }

    /++ Returns the kind of the current node. +/
    XMLKind getKind() const
    {
        if (starting)
            return XMLKind.DOCUMENT;

        static if (conflateCDATA == Yes.conflateCDATA)
            if (currentNode.kind == XMLKind.CDATA)
                return XMLKind.TEXT;

        return currentNode.kind;
    }

    /++
    +   If the current node is an element or a doctype, return its complete name;
    +   it it is a processing instruction, return its target;
    +   otherwise, return an empty string;
    +/
    StringType getName()
    {
        switch (currentNode.kind)
        {
            case XMLKind.DOCUMENT:
            case XMLKind.TEXT:
            case XMLKind.CDATA:
            case XMLKind.COMMENT:
            case XMLKind.DECLARATION:
            case XMLKind.CONDITIONAL:
            case XMLKind.DTD_START:
            case XMLKind.DTD_EMPTY:
            case XMLKind.DTD_END:
                return [];
            default:
                if (!nameEnd)
                {
                    ptrdiff_t i;
                    if ((i = fastIndexOfAny(currentNode.content, " \r\n\t")) >= 0)
                        nameEnd = i;
                    else
                        nameEnd = currentNode.content.length;
                }
                return currentNode.content[0..nameEnd];
        }
    }

    /++
    +   If the current node is an element, return its local name (without namespace prefix);
    +   otherwise, return the same result as getName().
    +/
    StringType getLocalName()
    {
        auto name = getName();
        if (currentNode.kind == XMLKind.ELEMENT_START || currentNode.kind == XMLKind.ELEMENT_END)
        {
            if (colon == colon.max)
                colon = fastIndexOf(name, ':');
            return name[(colon+1)..$];
        }
        return name;
    }

    /++
    +   If the current node is an element, return its namespace prefix;
    +   otherwise, the result in unspecified;
    +/
    StringType getPrefix()
    {
        if (currentNode.kind == XMLKind.ELEMENT_START || currentNode.kind == XMLKind.ELEMENT_END)
        {
            auto name = getName;
            if (colon == colon.max)
                colon = fastIndexOf(name, ':');

            if (colon >= 0)
                return name[0..colon];
            else
                return [];
        }
        return [];
    }

    /++
    +   If the current node is an element, return its attributes as a range of triplets
    +   (prefix, name, value); if the current node is the document node, return the attributes
    +   of the xml declaration (encoding, version, ...); otherwise, return an empty array.
    +/
    auto getAttributes()
    {
        struct AttributesRange
        {
            private StringType content;
            private Attribute!StringType attr;
            private Cursor* cursor;
            private bool error;

            private this(StringType str, ref Cursor cur)
            {
                content = str;
                cursor = &cur;
            }

            bool empty()
            {
                if (error)
                    return true;

                auto i = content.fastIndexOfNeither(" \r\n\t");
                if (i >= 0)
                {
                    content = content[i..$];
                    return false;
                }
                return true;
            }

            auto front()
            {
                if (attr == attr.init)
                {
                    auto i = content.fastIndexOfNeither(" \r\n\t");
                    assert(i >= 0, "No more attributes...");
                    content = content[i..$];

                    auto sep = fastIndexOf(content[0..$], '=');
                    if (sep == -1)
                    {
                        // attribute without value???
                        cursor.callHandler(CursorError.INVALID_ATTRIBUTE_SYNTAX);
                        error = true;
                        return attr.init;
                    }

                    auto name = content[0..sep];
                    auto delta = fastIndexOfAny(name, " \r\n\t");
                    if (delta >= 0)
                    {
                        auto j = name[delta..$].fastIndexOfNeither(" \r\n\t");
                        if (j != -1)
                        {
                            // attribute name contains spaces???
                            cursor.callHandler(CursorError.INVALID_ATTRIBUTE_SYNTAX);
                            error = true;
                            return attr.init;
                        }
                        name = name[0..delta];
                    }
                    attr.name = name;

                    size_t attEnd;
                    size_t quote;
                    delta = (sep + 1 < content.length) ? fastIndexOfNeither(content[sep + 1..$], " \r\n\t") : -1;
                    if (delta >= 0)
                    {
                        quote = sep + 1 + delta;
                        if (content[quote] == '"' || content[quote] == '\'')
                        {
                            delta = fastIndexOf(content[(quote + 1)..$], content[quote]);
                            if (delta == -1)
                            {
                                // attribute quotes never closed???
                                cursor.callHandler(CursorError.INVALID_ATTRIBUTE_SYNTAX);
                                error = true;
                                return attr.init;
                            }
                            attEnd = quote + 1 + delta;
                        }
                        else
                        {
                            cursor.callHandler(CursorError.INVALID_ATTRIBUTE_SYNTAX);
                            error = true;
                            return attr.init;
                        }
                    }
                    else
                    {
                        // attribute without value???
                        cursor.callHandler(CursorError.INVALID_ATTRIBUTE_SYNTAX);
                        error = true;
                        return attr.init;
                    }
                    attr.value = content[(quote + 1)..attEnd];
                    content = content[attEnd+1..$];
                }
                return attr;
            }

            auto popFront()
            {
                front();
                attr = attr.init;
            }
        }

        auto kind = currentNode.kind;
        if (kind == XMLKind.ELEMENT_START || kind == XMLKind.ELEMENT_EMPTY || kind == XMLKind.PROCESSING_INSTRUCTION)
        {
            getName;
            return AttributesRange(currentNode.content[nameEnd..$], this);
        }
        else
            return AttributesRange();
    }

    /++
    +   Return the text content of a CDATA section, a comment or a text node;
    +   in all other cases, returns the entire node without the name
    +/
    StringType getContent()
    {
        return currentNode.content[nameEnd..$];
    }

    /++ Returns the entire text of the current node. +/
    StringType getAll() const
    {
        return currentNode.content;
    }
}

/++
+   Instantiates a specialized `Cursor` with the given underlying `parser` and
+   the given error handler (defaults to an error handler that just asserts 0).
+/
template cursor(Flag!"conflateCDATA" conflateCDATA = Yes.conflateCDATA)
{
    auto cursor(T, EH)(auto ref T parser, EH errorHandler = (CursorError err) { assert(0); })
        if(isLowLevelParser!T)
    {
        auto cursor = Cursor!(T, conflateCDATA, EH)();
        cursor.parser = parser;
        cursor.handler = errorHandler;
        return cursor;
    }
}

unittest
{
    import std.experimental.xml.lexers;
    import std.experimental.xml.parser;
    import std.string : lineSplitter, strip;
    import std.algorithm : map;
    import std.array : array;

    wstring xml = q{
    <?xml encoding = "utf-8" ?>
    <!DOCTYPE mydoc https://myUri.org/bla [
        <!ELEMENT myelem ANY>
        <!ENTITY   myent    "replacement text">
        <!ATTLIST myelem foo CDATA #REQUIRED >
        <!NOTATION PUBLIC 'h'>
        <!FOODECL asdffdsa >
    ]>
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

    auto cursor = chooseLexer!xml.parse.cursor;
    cursor.setSource(xml);

    assert(cursor.atBeginning);

    // <?xml encoding = "utf-8" ?>
    assert(cursor.getKind() == XMLKind.DOCUMENT);
    assert(cursor.getName() == "xml");
    assert(cursor.getPrefix() == "");
    assert(cursor.getLocalName() == "xml");
    assert(cursor.getAttributes().array == [Attribute!wstring("encoding", "utf-8")]);
    assert(cursor.getContent() == " encoding = \"utf-8\" ");

    assert(cursor.enter());
        assert(!cursor.atBeginning);

        // <!DOCTYPE mydoc https://myUri.org/bla [
        assert(cursor.getKind == XMLKind.DTD_START);
        assert(cursor.getAll == " mydoc https://myUri.org/bla ");

        assert(cursor.enter);
            // <!ELEMENT myelem ANY>
            assert(cursor.getKind == XMLKind.ELEMENT_DECL);
            assert(cursor.getAll == " myelem ANY");

            assert(cursor.next);
            // <!ENTITY   myent    "replacement text">
            assert(cursor.getKind == XMLKind.ENTITY_DECL);
            assert(cursor.getAll == "   myent    \"replacement text\"");

            assert(cursor.next);
            // <!ATTLIST myelem foo CDATA #REQUIRED >
            assert(cursor.getKind == XMLKind.ATTLIST_DECL);
            assert(cursor.getAll == " myelem foo CDATA #REQUIRED ");

            assert(cursor.next);
            // <!NOTATION PUBLIC 'h'>
            assert(cursor.getKind == XMLKind.NOTATION_DECL);
            assert(cursor.getAll == " PUBLIC 'h'");

            assert(cursor.next);
            // <!FOODECL asdffdsa >
            assert(cursor.getKind == XMLKind.DECLARATION);
            assert(cursor.getAll == "FOODECL asdffdsa ");

            assert(!cursor.next);
        cursor.exit;

        // ]>
        assert(cursor.getKind == XMLKind.DTD_END);
        assert(!cursor.getAll);
        assert(cursor.next);

        // <aaa xmlns:myns="something">
        assert(cursor.getKind() == XMLKind.ELEMENT_START);
        assert(cursor.getName() == "aaa");
        assert(cursor.getPrefix() == "");
        assert(cursor.getLocalName() == "aaa");
        assert(cursor.getAttributes().array == [Attribute!wstring("xmlns:myns", "something")]);
        assert(cursor.getContent() == " xmlns:myns=\"something\"");

        assert(cursor.enter());
            // <myns:bbb myns:att='>'>
            assert(cursor.getKind() == XMLKind.ELEMENT_START);
            assert(cursor.getName() == "myns:bbb");
            assert(cursor.getPrefix() == "myns");
            assert(cursor.getLocalName() == "bbb");
            assert(cursor.getAttributes().array == [Attribute!wstring("myns:att", ">")]);
            assert(cursor.getContent() == " myns:att='>'");

            assert(cursor.enter());
            cursor.exit();

            // </myns:bbb>
            assert(cursor.getKind() == XMLKind.ELEMENT_END);
            assert(cursor.getName() == "myns:bbb");
            assert(cursor.getPrefix() == "myns");
            assert(cursor.getLocalName() == "bbb");
            assert(cursor.getAttributes().empty);
            assert(cursor.getContent() == []);

            assert(cursor.next());
            // <<![CDATA[ Ciaone! ]]>
            assert(cursor.getKind() == XMLKind.TEXT);
            assert(cursor.getName() == "");
            assert(cursor.getPrefix() == "");
            assert(cursor.getLocalName() == "");
            assert(cursor.getAttributes().empty);
            assert(cursor.getContent() == " Ciaone! ");

            assert(cursor.next());
            // <ccc/>
            assert(cursor.getKind() == XMLKind.ELEMENT_EMPTY);
            assert(cursor.getName() == "ccc");
            assert(cursor.getPrefix() == "");
            assert(cursor.getLocalName() == "ccc");
            assert(cursor.getAttributes().empty);
            assert(cursor.getContent() == []);

            assert(!cursor.next());
        cursor.exit();

        // </aaa>
        assert(cursor.getKind() == XMLKind.ELEMENT_END);
        assert(cursor.getName() == "aaa");
        assert(cursor.getPrefix() == "");
        assert(cursor.getLocalName() == "aaa");
        assert(cursor.getAttributes().empty);
        assert(cursor.getContent() == []);

        assert(!cursor.next());
    cursor.exit();

    assert(cursor.documentEnd);
    assert(!cursor.atBeginning);
}

/++
+   Returns an input range of the children of the node currently pointed by `cursor`.
+
+   Advancing the range returned by this function also advances `cursor`. It is thus
+   not recommended to interleave usage of this function with raw usage of `cursor`.
+/
auto children(T)(ref T cursor)
    if (isCursor!T)
{
    struct XMLRange
    {
        T* cursor;
        bool endReached;

        bool empty() const { return endReached; }
        void popFront() { endReached = !cursor.next(); }
        ref T front() { return *cursor; }

        ~this() { cursor.exit; }
    }
    return XMLRange(&cursor, cursor.enter);
}

@nogc unittest
{
    import std.experimental.xml.lexers;
    import std.experimental.xml.parser;
    import std.string : lineSplitter, strip;
    import std.algorithm : map, equal;
    import std.array : array;

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

    import std.experimental.allocator.mallocator;

    auto handler = () { assert(0, "Some problem here..."); };
    auto lexer = RangeLexer!(string, typeof(handler), shared(Mallocator))(Mallocator.instance);
    lexer.errorHandler = handler;
    auto cursor = lexer.parse.cursor!(Yes.conflateCDATA);
    cursor.setSource(xml);

    // <?xml encoding = "utf-8" ?>
    assert(cursor.getKind() == XMLKind.DOCUMENT);
    assert(cursor.getName() == "xml");
    assert(cursor.getPrefix() == "");
    assert(cursor.getLocalName() == "xml");
    auto attrs = cursor.getAttributes;
    assert(attrs.front == Attribute!string("encoding", "utf-8"));
    attrs.popFront;
    assert(attrs.empty);
    assert(cursor.getContent() == " encoding = \"utf-8\" ");

    {
        auto range1 = cursor.children;
        // <aaa xmlns:myns="something">
        assert(range1.front.getKind() == XMLKind.ELEMENT_START);
        assert(range1.front.getName() == "aaa");
        assert(range1.front.getPrefix() == "");
        assert(range1.front.getLocalName() == "aaa");
        attrs = range1.front.getAttributes;
        assert(attrs.front == Attribute!string("xmlns:myns", "something"));
        attrs.popFront;
        assert(attrs.empty);
        assert(range1.front.getContent() == " xmlns:myns=\"something\"");

        {
            auto range2 = range1.front.children();
            // <myns:bbb myns:att='>'>
            assert(range2.front.getKind() == XMLKind.ELEMENT_START);
            assert(range2.front.getName() == "myns:bbb");
            assert(range2.front.getPrefix() == "myns");
            assert(range2.front.getLocalName() == "bbb");
            attrs = range2.front.getAttributes;
            assert(attrs.front == Attribute!string("myns:att", ">"));
            attrs.popFront;
            assert(attrs.empty);
            assert(range2.front.getContent() == " myns:att='>'");

            {
                auto range3 = range2.front.children();
                // <!-- lol -->
                assert(range3.front.getKind() == XMLKind.COMMENT);
                assert(range3.front.getName() == "");
                assert(range3.front.getPrefix() == "");
                assert(range3.front.getLocalName() == "");
                assert(range3.front.getAttributes.empty);
                assert(range3.front.getContent() == " lol ");

                range3.popFront;
                assert(!range3.empty);
                // Lots of Text!
                // On multiple lines!
                assert(range3.front.getKind() == XMLKind.TEXT);
                assert(range3.front.getName() == "");
                assert(range3.front.getPrefix() == "");
                assert(range3.front.getLocalName() == "");
                assert(range3.front.getAttributes().empty);
                // split and strip so the unittest does not depend on the newline policy or indentation of this file
                static immutable linesArr = ["Lots of Text!", "            On multiple lines!", "        "];
                assert(range3.front.getContent().lineSplitter.equal(linesArr));

                range3.popFront;
                assert(range3.empty);
            }

            range2.popFront;
            assert(!range2.empty);
            // <<![CDATA[ Ciaone! ]]>
            assert(range2.front.getKind() == XMLKind.TEXT);
            assert(range2.front.getName() == "");
            assert(range2.front.getPrefix() == "");
            assert(range2.front.getLocalName() == "");
            assert(range2.front.getAttributes().empty);
            assert(range2.front.getContent() == " Ciaone! ");

            range2.popFront;
            assert(!range2.empty());
            // <ccc/>
            assert(range2.front.getKind() == XMLKind.ELEMENT_EMPTY);
            assert(range2.front.getName() == "ccc");
            assert(range2.front.getPrefix() == "");
            assert(range2.front.getLocalName() == "ccc");
            assert(range2.front.getAttributes().empty);
            assert(range2.front.getContent() == []);

            range2.popFront;
            assert(range2.empty());
        }

        range1.popFront;
        assert(range1.empty);
    }

    assert(cursor.documentEnd());
}

import std.traits : isArray;
import std.experimental.allocator.gc_allocator;

/++
+   A cursor that wraps another cursor, copying all output strings.
+
+   The cursor specification ($(LINK2 ../interfaces/isCursor, `std.experimental.xml.interfaces.isCursor`))
+   clearly states that a cursor (as the underlying parser and lexer) is free to reuse
+   its internal buffers and thus invalidate every output. This wrapper returns freshly
+   allocated strings, thus allowing references to its outputs to outlive calls to advancing
+   methods.
+
+   This type should not be instantiated directly, but using the helper function
+   `copyingCursor`.
+/
struct CopyingCursor(CursorType, Alloc = shared(GCAllocator), Flag!"intern" intern = No.intern)
    if (isCursor!CursorType && isArray!(CursorType.StringType))
{
    alias StringType = CursorType.StringType;

    mixin UsesAllocator!Alloc;

    CursorType cursor;
    alias cursor this;

    static if (intern == Yes.intern)
    {
        import std.typecons: Rebindable;

        Rebindable!(immutable StringType)[const StringType] interned;
    }

    private auto copy(StringType str)
    {
        static if (intern == Yes.intern)
        {
            auto match = str in interned;
            if (match)
                return *match;
        }

        import std.traits : Unqual;
        import std.experimental.allocator;
        import std.range.primitives : ElementEncodingType;
        import core.stdc.string : memcpy;

        alias ElemType = ElementEncodingType!StringType;
        auto cp = cast(ElemType[]) allocator.makeArray!(Unqual!ElemType)(str.length);
        memcpy(cast(void*)cp.ptr, cast(void*)str.ptr, str.length * ElemType.sizeof);

        static if (intern == Yes.intern)
        {
            interned[str] = cp;
        }

        return cp;
    }

    auto getName()
    {
        return copy(cursor.getName);
    }
    auto getLocalName()
    {
        return copy(cursor.getLocalName);
    }
    auto getPrefix()
    {
        return copy(cursor.getPrefix);
    }
    auto getContent()
    {
        return copy(cursor.getContent);
    }
    auto getAll()
    {
        return copy(cursor.getAll);
    }

    auto getAttributes()
    {
        struct CopyRange
        {
            typeof(cursor.getAttributes()) attrs;
            alias attrs this;

            private CopyingCursor* parent;

            auto front()
            {
                auto attr = attrs.front;
                return Attribute!StringType(
                        parent.copy(attr.name),
                        parent.copy(attr.value),
                    );
            }
        }
        return CopyRange(cursor.getAttributes, &this);
    }
}

/++
+   Instantiates a suitable `CopyingCursor` on top of the given `cursor` and allocator.
+/
auto copyingCursor(Flag!"intern" intern = No.intern, CursorType, Alloc)(auto ref CursorType cursor, ref Alloc alloc)
{
    auto res = CopyingCursor!(CursorType, Alloc, intern)(alloc);
    res.cursor = cursor;
    return res;
}
/// ditto
auto copyingCursor(Alloc = shared(GCAllocator), Flag!"intern" intern = No.intern, CursorType)
                  (auto ref CursorType cursor)
    if (is(typeof(Alloc.instance)))
{
    auto res = CopyingCursor!(CursorType, Alloc, intern)(Alloc.instance);
    res.cursor = cursor;
    return res;
}

unittest
{
    import std.experimental.xml.lexers;
    import std.experimental.xml.parser;
    import std.experimental.allocator.mallocator;

    wstring xml = q{
    <?xml encoding = "utf-8" ?>
    <aaa>
        <bbb>
            <aaa>
            </aaa>
        </bbb>
        Hello, world!
    </aaa>
    };

    auto cursor =
         chooseLexer!xml
        .parse
        .cursor!(Yes.conflateCDATA)
        .copyingCursor!(Yes.intern)(Mallocator.instance);
    cursor.setSource(xml);

    assert(cursor.enter);
    auto a1 = cursor.getName;
    assert(cursor.enter);
    auto b1 = cursor.getName;
    assert(cursor.enter);
    auto a2 = cursor.getName;
    assert(!cursor.enter);
    auto a3 = cursor.getName;
    cursor.exit;
    auto b2 = cursor.getName;
    cursor.exit;
    auto a4 = cursor.getName;

    assert(a1 is a2);
    assert(a2 is a3);
    assert(a3 is a4);
    assert(b1 is b2);
}