/*
*             Copyright Lodovico Giaretta 2016 - .
*  Distributed under the Boost Software License, Version 1.0.
*      (See accompanying file LICENSE_1_0.txt or copy at
*            http://www.boost.org/LICENSE_1_0.txt)
*/

// TODO: write an in-depth explanation of this module, how to create validations,
// how validations should behave, etc...

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

module std.experimental.xml.validation;

import std.experimental.xml.interfaces;

/**
*   Wrapper around a cursor that checks whether elements are correctly nested.
*
*   It will call `ErrorHandler` whenever it finds a closing tag that does not match
*   the last start tag. `ErrorHandler` will be called with the first matching tuple
*   from the following:
*   $(UL
*       $(LI `(CursorType, std.container.Array!(CursorType.StringType))`)
*       $(LI `(CursorType)`)
*       $(LI `(std.container.Array!(CursorType.StringType))`)
*       $(LI `()`)
*   )
*   Any of these parameters can be taken by `ref`. The second parameter, of type
*   `std.container.Array!(CursorType.StringType)` represents the stack of currently
*   open tags. The handler is free to modify it (to implement erro recovery with
*   automatic XML fixing).
*
*   This type should not be instantiated directly, but with the helper function
*   `elementNestingValidator`.
*/
struct ElementNestingValidator(CursorType, alias ErrorHandler)
    if (isCursor!CursorType)
{
    import std.experimental.xml.interfaces;

    alias StringType = CursorType.StringType;

    import std.container.array;
    private Array!StringType stack;

    private CursorType cursor;
    alias cursor this;

    this(Args...)(Args args)
    {
        cursor = CursorType(args);
    }

    private void callHandler()
    {
        static if (__traits(compiles, ErrorHandler(cursor, stack)))
            ErrorHandler(cursor, stack);
        else static if (__traits(compiles, ErrorHandler(cursor)))
            ErrorHandler(cursor);
        else static if (__traits(compiles, ErrorHandler(stack)))
            ErrorHandler(stack);
        else
            ErrorHandler();
    }

    bool enter()
    {
        if (cursor.kind == XMLKind.elementStart)
        {
            stack.insertBack(cursor.name);
            if (!cursor.enter)
            {
                stack.removeBack;
                return false;
            }
            return true;
        }
        return cursor.enter;
    }
    void exit()
    {
        cursor.exit();
        if (cursor.kind == XMLKind.elementEnd)
        {
            if (stack.empty)
            {
                if (!cursor.documentEnd)
                    callHandler();
            }
            else
            {
                import std.experimental.xml.faststrings : fastEqual;

                if (!fastEqual(stack.back, cursor.name))
                {
                    callHandler();
                }
                else
                    stack.removeBack();
            }
        }
    }
}
/**
*   Instantiates an `ElementNestingValidator` with the given `cursor` and `ErrorHandler`
*/
auto elementNestingValidator(alias ErrorHandler = (){ assert(0); }, CursorType) (auto ref CursorType cursor)
{
    auto res = ElementNestingValidator!(CursorType, ErrorHandler)();
    res.cursor = cursor;
    return res;
}

unittest
{
    import std.experimental.xml.lexers;
    import std.experimental.xml.parser;
    import std.experimental.xml.cursor;

    auto xml = q{
        <?xml?>
        <aaa>
            <eee>
                <bbb>
                    <ccc>
                </bbb>
                <ddd>
                </ddd>
            </eee>
            <fff>
            </fff>
        </aaa>
    };

    int count = 0;

    auto validator =
         xml
        .lexer
        .parser
        .cursor
        .elementNestingValidator!(
            (ref cursor, ref stack)
            {
                import std.algorithm: canFind;
                count++;
                if (canFind(stack[], cursor.name()))
                    do
                    {
                        stack.removeBack();
                    }
                    while (stack.back != cursor.name());
                stack.removeBack();
            });

    validator.setSource(xml);

    void inspectOneLevel(T)(ref T cursor)
    {
        do
        {
            if (cursor.enter)
            {
                inspectOneLevel(cursor);
                cursor.exit();
            }
        }
        while (cursor.next());
    }
    inspectOneLevel(validator);

    assert(count == 1);
}

/**
*   Checks whether a character can appear in an XML 1.0 document.
*/
pure nothrow @nogc @safe bool isValidXMLCharacter10(dchar c)
{
    return c == '\r' || c == '\n' || c == '\t'
        || (0x20 <= c && c <= 0xD7FF)
        || (0xE000 <= c && c <= 0xFFFD)
        || (0x10000 <= c && c <= 0x10FFFF);
}

/**
*   Checks whether a character can appear in an XML 1.1 document.
*/
pure nothrow @nogc @safe bool isValidXMLCharacter11(dchar c)
{
    return (1 <= c && c <= 0xD7FF)
        || (0xE000 <= c && c <= 0xFFFD)
        || (0x10000 <= c && c <= 0x10FFFF);
}

/**
*   Checks whether a character can start an XML name (tag name or attribute name).
*/
pure nothrow @nogc @safe bool isValidXMLNameStart(dchar c)
{
    return c == ':'
        || ('A' <= c && c <= 'Z')
        || c == '_'
        || ('a' <= c && c <= 'z')
        || (0xC0 <= c && c <= 0x2FF && c != 0xD7 && c != 0xF7)
        || (0x370 <= c && c <= 0x1FFF && c != 0x37E)
        || c == 0x200C
        || c == 0x200D
        || (0x2070 <= c && c <= 0x218F)
        || (0x2C00 <= c && c <= 0x2FEF)
        || (0x3001 <= c && c <= 0xD7FF)
        || (0xF900 <= c && c <= 0xFDCF)
        || (0xFDF0 <= c && c <= 0xEFFFF && c != 0xFFFE && c != 0xFFFF);
}

/**
*   Checks whether a character can appear inside an XML name (tag name or attribute name).
*/
pure nothrow @nogc @safe bool isValidXMLNameChar(dchar c)
{
    return isValidXMLNameStart(c)
        || c == '-'
        || c == '.'
        || ('0' <= c && c <= '9')
        || c == 0xB7
        || (0x300 <= c && c <= 0x36F)
        || (0x203F <= c && c <= 2040);
}

/**
*   Checks whether a character can appear in an XML public ID.
*/
pure nothrow @nogc @safe bool isValidXMLPublicIdCharacter(dchar c)
{
    import std.string: indexOf;
    return c == ' '
        || c == '\n'
        || c == '\r'
        || ('a' <= c && c <= 'z')
        || ('A' <= c && c <= 'Z')
        || ('0' <= c && c <= '9')
        || "-'()+,./:=?;!*#@$_%".indexOf(c) != -1;
}

/**
*   Wrapper around a cursor that checks whether tag names and attribute names
*   are well-formed with respect to the specification.
*
*   Will call `InvalidTagHandler` every time it encounters an ill-formed tag name
*   and `InvalidAttrHandler` every time it encounters an ill-formed attribute name.
*
*   This type should not be instantiated directly, but with the helper function
*   `checkXMLNames`.
*/
struct CheckXMLNames(CursorType, InvalidTagHandler, InvalidAttrHandler)
    if (isCursor!CursorType)
{
    alias StringType = CursorType.StringType;
    InvalidTagHandler onInvalidTagName;
    InvalidAttrHandler onInvalidAttrName;

    CursorType cursor;
    alias cursor this;

    auto name()
    {
        import std.algorithm : all;

        auto name = cursor.name;
        if (cursor.kind != XMLKind.elementEnd)
            if (!name[0].isValidXMLNameStart || !name.all!isValidXMLNameChar)
                onInvalidTagName(name);
        return name;
    }

    auto attributes()
    {
        struct CheckedAttributes
        {
            typeof(onInvalidAttrName) callback;
            typeof(cursor.attributes()) attrs;
            alias attrs this;

            auto front()
            {
                import std.algorithm : all;
                auto attr = attrs.front;
                if (!attr.name[0].isValidXMLNameStart || !attr.name.all!isValidXMLNameChar)
                    callback(attr.name);
                return attr;
            }
        }
        return CheckedAttributes(onInvalidAttrName, cursor.attributes);
    }
}

/**
*   Returns an instance of `CheckXMLNames` specialized for the given `cursor`,
*   with the given error handlers;
*/
auto checkXMLNames(CursorType, InvalidTagHandler, InvalidAttrHandler)
                  (auto ref CursorType cursor,
                   InvalidTagHandler tagHandler = (CursorType.StringType s) {},
                   InvalidAttrHandler attrHandler = (CursorType.StringType s) {})
{
    auto res = CheckXMLNames!(CursorType, InvalidTagHandler, InvalidAttrHandler)();
    res.cursor = cursor;
    res.onInvalidTagName = tagHandler;
    res.onInvalidAttrName = attrHandler;
    return res;
}

unittest
{
    import std.experimental.xml.lexers;
    import std.experimental.xml.parser;
    import std.experimental.xml.cursor;

    auto xml = q{
        <?xml?>
        <aa.a at;t = "hi!">
            <bbb>
                <-ccc>
            </bbb>
            <dd-d xmlns:,="http://foo.bar/baz">
            </dd-d>
        </aa.a>
    };

    int count = 0;

    auto cursor =
         xml
        .lexer
        .parser
        .cursor
        .checkXMLNames((string s) { count++; }, (string s) { count++; });

    void inspectOneLevel(T)(ref T cursor)
    {
        import std.array;
        do
        {
            auto name = cursor.name;
            auto attrs = cursor.attributes.array;
            if (cursor.enter)
            {
                inspectOneLevel(cursor);
                cursor.exit();
            }
        }
        while (cursor.next);
    }
    inspectOneLevel(cursor);

    assert(count == 3);
}