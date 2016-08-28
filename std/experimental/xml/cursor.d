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
    missingXMLDeclaration,
    /// The attributes could not be parsed due to invalid syntax
    invalidAttributeSyntax,
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
        {
            static if (__traits(compiles, handler(err)))
                handler(err);
            else
                handler();
        }
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
            if (parser.front.kind == XMLKind.processingInstruction &&
                parser.front.content.length >= 3 &&
                fastEqual(parser.front.content[0..3], "xml"))
            {
                currentNode = parser.front;
            }
            else
            {
                // document without xml declaration???
                callHandler(CursorError.missingXMLDeclaration);
                currentNode.kind = XMLKind.processingInstruction;
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
    +   (i.e. whether no `enter`/`next`/`exit` has been performed successfully and thus
    +   the cursor points to the xml declaration)
    +/
    bool atBeginning()
    {
        return starting;
    }

    /++
    +   Advances to the first child of the current node and returns `true`.
    +   If it returns `false`, the cursor is either on the same node (it wasn't
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
        else if (currentNode.kind == XMLKind.elementStart)
        {
            return advanceInput() && currentNode.kind != XMLKind.elementEnd;
        }
        else if (currentNode.kind == XMLKind.dtdStart)
        {
            return advanceInput() && currentNode.kind != XMLKind.dtdEnd;
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
    +   Advances to the _next sibling of the current node.
    +   Returns whether it succeded. If it fails, either the
    +   document has ended or the only meaningful operation is `exit`.
    +/
    bool next()
    {
        if (parser.empty || starting || nextFailed)
            return false;
        else if (currentNode.kind == XMLKind.dtdStart)
        {
            while (advanceInput && currentNode.kind != XMLKind.dtdEnd) {}
        }
        else if (currentNode.kind == XMLKind.elementStart)
        {
            int count = 1;
            while (count > 0 && !parser.empty)
            {
                if (!advanceInput)
                    return false;
                if (currentNode.kind == XMLKind.elementStart)
                    count++;
                else if (currentNode.kind == XMLKind.elementEnd)
                    count--;
            }
        }
        if (!advanceInput || currentNode.kind == XMLKind.elementEnd || currentNode.kind == XMLKind.dtdEnd)
        {
            nextFailed = true;
            return false;
        }
        return true;
    }

    /++ Returns the _kind of the current node. +/
    XMLKind kind() const
    {
        if (starting)
            return XMLKind.document;

        static if (conflateCDATA == Yes.conflateCDATA)
            if (currentNode.kind == XMLKind.cdata)
                return XMLKind.text;

        return currentNode.kind;
    }

    /++
    +   If the current node is an element or a doctype, returns its complete _name;
    +   it it is a processing instruction, return its target;
    +   otherwise, returns an empty string;
    +/
    StringType name()
    {
        switch (currentNode.kind)
        {
            case XMLKind.document:
            case XMLKind.text:
            case XMLKind.cdata:
            case XMLKind.comment:
            case XMLKind.declaration:
            case XMLKind.conditional:
            case XMLKind.dtdStart:
            case XMLKind.dtdEmpty:
            case XMLKind.dtdEnd:
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
    +   If the current node is an element, returns its local name (without namespace prefix);
    +   otherwise, returns the same result as `name`.
    +/
    StringType localName()
    {
        auto name = name();
        if (currentNode.kind == XMLKind.elementStart || currentNode.kind == XMLKind.elementEnd)
        {
            if (colon == colon.max)
                colon = fastIndexOf(name, ':');
            return name[(colon+1)..$];
        }
        return name;
    }

    /++
    +   If the current node is an element, returns its namespace _prefix;
    +   otherwise, the result in unspecified;
    +/
    StringType prefix()
    {
        if (currentNode.kind == XMLKind.elementStart || currentNode.kind == XMLKind.elementEnd)
        {
            auto name = name;
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
    +   If the current node is an element, return its _attributes as a range of triplets
    +   (`prefix`, `name`, `value`); if the current node is the document node, return the _attributes
    +   of the xml declaration (encoding, version, ...); otherwise, returns an empty array.
    +/
    auto attributes()
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
                        cursor.callHandler(CursorError.invalidAttributeSyntax);
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
                            cursor.callHandler(CursorError.invalidAttributeSyntax);
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
                                cursor.callHandler(CursorError.invalidAttributeSyntax);
                                error = true;
                                return attr.init;
                            }
                            attEnd = quote + 1 + delta;
                        }
                        else
                        {
                            cursor.callHandler(CursorError.invalidAttributeSyntax);
                            error = true;
                            return attr.init;
                        }
                    }
                    else
                    {
                        // attribute without value???
                        cursor.callHandler(CursorError.invalidAttributeSyntax);
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
        if (kind == XMLKind.elementStart || kind == XMLKind.elementEmpty || kind == XMLKind.processingInstruction)
        {
            name;
            return AttributesRange(currentNode.content[nameEnd..$], this);
        }
        else
            return AttributesRange();
    }

    /++
    +   Return the text content of a cdata section, a comment or a text node;
    +   in all other cases, returns the entire node without the name
    +/
    StringType content()
    {
        return currentNode.content[nameEnd..$];
    }

    /++ Returns the entire text of the current node. +/
    StringType wholeContent() const
    {
        return currentNode.content;
    }
}

private void defaultCursorHandler(CursorError err)
{
    final switch (err) with (CursorError)
    {
        case missingXMLDeclaration:
            throw new XMLException("XML document does not start with an XML declaration");
        case invalidAttributeSyntax:
            throw new XMLException("Found invalid syntax while parsing attributes");
    }
    assert(0, "This instruction should not be reached; if it happens, please file a bug report");
}

/++
+   Instantiates a specialized `Cursor` with the given underlying `parser` and
+   the given error handler (defaults to an error handler that just asserts 0).
+/
template cursor(Flag!"conflateCDATA" conflateCDATA = Yes.conflateCDATA)
{
    auto cursor(T)(auto ref T parser)
        if(isLowLevelParser!T)
    {
        return cursor(parser, &defaultCursorHandler);
    }
    auto cursor(T, EH)(auto ref T parser, EH errorHandler)
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
        <!ATTLIST myelem foo cdata #REQUIRED >
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
    assert(cursor.kind() == XMLKind.document);
    assert(cursor.name() == "xml");
    assert(cursor.prefix() == "");
    assert(cursor.localName() == "xml");
    assert(cursor.attributes().array == [Attribute!wstring("encoding", "utf-8")]);
    assert(cursor.content() == " encoding = \"utf-8\" ");

    assert(cursor.enter());
        assert(!cursor.atBeginning);

        // <!DOCTYPE mydoc https://myUri.org/bla [
        assert(cursor.kind == XMLKind.dtdStart);
        assert(cursor.wholeContent == " mydoc https://myUri.org/bla ");

        assert(cursor.enter);
            // <!ELEMENT myelem ANY>
            assert(cursor.kind == XMLKind.elementDecl);
            assert(cursor.wholeContent == " myelem ANY");

            assert(cursor.next);
            // <!ENTITY   myent    "replacement text">
            assert(cursor.kind == XMLKind.entityDecl);
            assert(cursor.wholeContent == "   myent    \"replacement text\"");

            assert(cursor.next);
            // <!ATTLIST myelem foo cdata #REQUIRED >
            assert(cursor.kind == XMLKind.attlistDecl);
            assert(cursor.wholeContent == " myelem foo cdata #REQUIRED ");

            assert(cursor.next);
            // <!NOTATION PUBLIC 'h'>
            assert(cursor.kind == XMLKind.notationDecl);
            assert(cursor.wholeContent == " PUBLIC 'h'");

            assert(cursor.next);
            // <!FOODECL asdffdsa >
            assert(cursor.kind == XMLKind.declaration);
            assert(cursor.wholeContent == "FOODECL asdffdsa ");

            assert(!cursor.next);
        cursor.exit;

        // ]>
        assert(cursor.kind == XMLKind.dtdEnd);
        assert(!cursor.wholeContent);
        assert(cursor.next);

        // <aaa xmlns:myns="something">
        assert(cursor.kind() == XMLKind.elementStart);
        assert(cursor.name() == "aaa");
        assert(cursor.prefix() == "");
        assert(cursor.localName() == "aaa");
        assert(cursor.attributes().array == [Attribute!wstring("xmlns:myns", "something")]);
        assert(cursor.content() == " xmlns:myns=\"something\"");

        assert(cursor.enter());
            // <myns:bbb myns:att='>'>
            assert(cursor.kind() == XMLKind.elementStart);
            assert(cursor.name() == "myns:bbb");
            assert(cursor.prefix() == "myns");
            assert(cursor.localName() == "bbb");
            assert(cursor.attributes().array == [Attribute!wstring("myns:att", ">")]);
            assert(cursor.content() == " myns:att='>'");

            assert(cursor.enter());
            cursor.exit();

            // </myns:bbb>
            assert(cursor.kind() == XMLKind.elementEnd);
            assert(cursor.name() == "myns:bbb");
            assert(cursor.prefix() == "myns");
            assert(cursor.localName() == "bbb");
            assert(cursor.attributes().empty);
            assert(cursor.content() == []);

            assert(cursor.next());
            // <![CDATA[ Ciaone! ]]>
            assert(cursor.kind() == XMLKind.text);
            assert(cursor.name() == "");
            assert(cursor.prefix() == "");
            assert(cursor.localName() == "");
            assert(cursor.attributes().empty);
            assert(cursor.content() == " Ciaone! ");

            assert(cursor.next());
            // <ccc/>
            assert(cursor.kind() == XMLKind.elementEmpty);
            assert(cursor.name() == "ccc");
            assert(cursor.prefix() == "");
            assert(cursor.localName() == "ccc");
            assert(cursor.attributes().empty);
            assert(cursor.content() == []);

            assert(!cursor.next());
        cursor.exit();

        // </aaa>
        assert(cursor.kind() == XMLKind.elementEnd);
        assert(cursor.name() == "aaa");
        assert(cursor.prefix() == "");
        assert(cursor.localName() == "aaa");
        assert(cursor.attributes().empty);
        assert(cursor.content() == []);

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
    auto cursor = lexer.parse.cursor!(Yes.conflateCDATA)((){});
    cursor.setSource(xml);

    // <?xml encoding = "utf-8" ?>
    assert(cursor.kind() == XMLKind.document);
    assert(cursor.name() == "xml");
    assert(cursor.prefix() == "");
    assert(cursor.localName() == "xml");
    auto attrs = cursor.attributes;
    assert(attrs.front == Attribute!string("encoding", "utf-8"));
    attrs.popFront;
    assert(attrs.empty);
    assert(cursor.content() == " encoding = \"utf-8\" ");

    {
        auto range1 = cursor.children;
        // <aaa xmlns:myns="something">
        assert(range1.front.kind() == XMLKind.elementStart);
        assert(range1.front.name() == "aaa");
        assert(range1.front.prefix() == "");
        assert(range1.front.localName() == "aaa");
        attrs = range1.front.attributes;
        assert(attrs.front == Attribute!string("xmlns:myns", "something"));
        attrs.popFront;
        assert(attrs.empty);
        assert(range1.front.content() == " xmlns:myns=\"something\"");

        {
            auto range2 = range1.front.children();
            // <myns:bbb myns:att='>'>
            assert(range2.front.kind() == XMLKind.elementStart);
            assert(range2.front.name() == "myns:bbb");
            assert(range2.front.prefix() == "myns");
            assert(range2.front.localName() == "bbb");
            attrs = range2.front.attributes;
            assert(attrs.front == Attribute!string("myns:att", ">"));
            attrs.popFront;
            assert(attrs.empty);
            assert(range2.front.content() == " myns:att='>'");

            {
                auto range3 = range2.front.children();
                // <!-- lol -->
                assert(range3.front.kind() == XMLKind.comment);
                assert(range3.front.name() == "");
                assert(range3.front.prefix() == "");
                assert(range3.front.localName() == "");
                assert(range3.front.attributes.empty);
                assert(range3.front.content() == " lol ");

                range3.popFront;
                assert(!range3.empty);
                // Lots of Text!
                // On multiple lines!
                assert(range3.front.kind() == XMLKind.text);
                assert(range3.front.name() == "");
                assert(range3.front.prefix() == "");
                assert(range3.front.localName() == "");
                assert(range3.front.attributes().empty);
                // split and strip so the unittest does not depend on the newline policy or indentation of this file
                static immutable linesArr = ["Lots of Text!", "            On multiple lines!", "        "];
                assert(range3.front.content().lineSplitter.equal(linesArr));

                range3.popFront;
                assert(range3.empty);
            }

            range2.popFront;
            assert(!range2.empty);
            // <<![CDATA[ Ciaone! ]]>
            assert(range2.front.kind() == XMLKind.text);
            assert(range2.front.name() == "");
            assert(range2.front.prefix() == "");
            assert(range2.front.localName() == "");
            assert(range2.front.attributes().empty);
            assert(range2.front.content() == " Ciaone! ");

            range2.popFront;
            assert(!range2.empty());
            // <ccc/>
            assert(range2.front.kind() == XMLKind.elementEmpty);
            assert(range2.front.name() == "ccc");
            assert(range2.front.prefix() == "");
            assert(range2.front.localName() == "ccc");
            assert(range2.front.attributes().empty);
            assert(range2.front.content() == []);

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

    auto name()
    {
        return copy(cursor.name);
    }
    auto localName()
    {
        return copy(cursor.localName);
    }
    auto prefix()
    {
        return copy(cursor.prefix);
    }
    auto content()
    {
        return copy(cursor.content);
    }
    auto wholeContent()
    {
        return copy(cursor.wholeContent);
    }

    auto attributes()
    {
        struct CopyRange
        {
            typeof(cursor.attributes()) attrs;
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
        return CopyRange(cursor.attributes, &this);
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
    auto a1 = cursor.name;
    assert(cursor.enter);
    auto b1 = cursor.name;
    assert(cursor.enter);
    auto a2 = cursor.name;
    assert(!cursor.enter);
    auto a3 = cursor.name;
    cursor.exit;
    auto b2 = cursor.name;
    cursor.exit;
    auto a4 = cursor.name;

    assert(a1 is a2);
    assert(a2 is a3);
    assert(a3 is a4);
    assert(b1 is b2);
}