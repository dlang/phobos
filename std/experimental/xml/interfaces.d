/*
*             Copyright Lodovico Giaretta 2016 - .
*  Distributed under the Boost Software License, Version 1.0.
*      (See accompanying file LICENSE_1_0.txt or copy at
*            http://www.boost.org/LICENSE_1_0.txt)
*/

/++
+   This module contains some templates to check whether a type exposes the correct
+   interface to be an xml lexer, parser or cursor; it also contains some simple
+   types used in various parts of the library;
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

module std.experimental.xml.interfaces;

import std.range.primitives;
import std.traits;

// LEVEL 1: LEXERS

/++
+   Checks whether its argument fulfills all requirements to be used as an XML lexer.
+
+   An XML lexer is the first component in the parsing chain. It masks from the parser
+   the shape of the input and the type of the characters in it. The slices returned by
+   the lexer are ephemeral: every reference to them may or may not be invalidated when a
+   new slice is requested by the parser. It is thus responsibility of the user to copy the
+   output if necessary.
+
+   Params:
+       L = the type to be tested
+
+   Returns:
+   `true` if L satisfies the XML lexer specification here stated; `false` otherwise
+
+   Specification:
+   A lexer shall support at least these methods and aliases:
+   $(UL
+       $(LI `alias CharacterType`: the type of a single source character; most
+             methods will deal with slices of this type;)
+       $(LI `alias InputType`: the type of the input which is used to feed this
+             lexer;)
+       $(LI `void setSource(InputType)`: sets the input source for this lexer;
+             the lexer may perform other initialization work and even consume
+             part of the input during this operation; after (partial or complete)
+             usage, a lexer may be reinitialized and used with another input
+             by calling this function;)
+       $(LI `bool empty()`: returns `true` if the entire input has been consumed;
+            `false` otherwise;)
+       $(LI `void start()`: instructs the lexer that a new token starts at the
+             current positions; the next calls to `get` will retrive the input
+             from the current position; this call may invalidate any reference
+             to any slice previosly returned from `get`)
+       $(LI `CharacterType[] get()`: returns the contents of the input going from
+             the last call to `start` till the current position;)
+       $(LI `bool testAndAdvance(CharacterType)`: tests whether the input character
+             at the current position matches the one passed as parameter; if
+             it is the case, this method returns `true` and advances the input
+             past the said character; otherwise, it returns `false` and no action
+             is performed;)
+       $(LI `void advanceUntil(CharacterType, bool)`: advances the input until
+             the given character is found; if the second parameter is true, the
+             input is then advanced past the found character;)
+       $(LI `void advanceUntilAny(CharacterType[], bool)`: advances the input
+             until any of the given characters is found; if the second parameter
+             is true, the input is then advanced past the found character;)
+       $(LI `void dropWhile(CharacterType[])`: advances the input until a character
+             different from the given ones is found; the characters advanced by
+             this method may or may not be included in the output of a subsequent
+             `get`; for this reason, this method should only be called immediately
+             before `start`, to skip unneeded characters between two tokens.)
+   )
+
+   Examples:
+   ---
+   /* extract a word surrounded by whitespaces */
+   auto getWord(L)(ref L lexer)
+       if (isLexer!L)
+   {
+       // drop leading whitespaces
+       lexer.dropWhile(" \n\r\t");
+
+       // start building the word
+       lexer.start;
+
+       // keep advancing until you find the trailing whitespaces
+       lexer.advanceUntilAny(" \n\r\t", false);
+
+       // return what you found
+       return lexer.get;
+   }
+
+   /* extract a key/value pair from a string like " key : value " */
+   auto getKeyValuePair(ref L lexer)
+       if (isLexer!L)
+   {
+       // drop leading whitespaces
+       lexer.dropWhile(" \n\r\t");
+
+       // here starts the key, which ends with either a whitespace or a colon
+       lexer.start;
+       lexer.advanceUntilAny(" \n\r\t:", false);
+       auto key = lexer.get;
+
+       // skip any spaces after the key
+       lexer.dropWhile(" \n\r\t");
+       // now there must be a colon
+       assert(lexer.testAndAdvance(':'));
+       // skip all space after the colon
+       lexer.dropWhile(" \n\r\t");
+
+       // here starts the value, which ends at the first whitespace
+       lexer.start;
+       lexer.advanceUntilAny(" \n\r\t", false);
+       auto value = lexer.get;
+
+       // return the pair
+       return tuple(key, value);
+   }
+   ---
+/
template isLexer(L)
{
    enum bool isLexer = is(typeof(
    (inout int = 0)
    {
        alias C = L.CharacterType;

        L lexer;
        char c;
        bool b;
        string s;
        C[] cs;

        b = lexer.empty;
        lexer.start();
        cs = lexer.get();
        b = lexer.testAndAdvance(c);
        lexer.advanceUntil(c, b);
        lexer.advanceUntilAny(s, b);
        lexer.dropWhile(s);
    }));
}

/++
+   Checks whether its argument is a saveable lexer.
+
+   A saveable lexer is a lexer enhanced with a `save` method analogous to the `save`
+   method of `ForwardRange`s.
+
+   Params:
+       L = the type to be tested
+
+   Returns:
+   `true` if L is a lexer (as specified by `isLexer`) and also supports the `save`
+   method as specified here; `false` otherwise
+
+   Specification:
+   The type shall support at least:
+   $(UL
+       $(LI all methods and aliases specified by `isLexer`)
+       $(LI `L save()`: returns an independent copy of the current lexer; the
+             copy must start at the position the original lexer was when this method
+             was called; the two copies shall be independent, in that advancing one
+             does not advance the other.)
+   )
+/
template isSaveableLexer(L)
{
    enum bool isSaveableLexer = isLexer!L && is(typeof(
    (inout int = 0)
    {
        L lexer1;
        L lexer2 = lexer1.save();
    }));
}

// LEVEL 2: PARSERS

/++
+   Enumeration of XML events/nodes, used by various components.
+/
enum XMLKind
{
    /++ The `<?xml` `?>` declaration at the beginning of the entire document +/
    document,

    /++ The beginning of a document type declaration `<!DOCTYPE ... [` +/
    dtdStart,
    /++ The end of a document type declaration `] >` +/
    dtdEnd,
    /++ A document type declaration without an internal subset +/
    dtdEmpty,

    /++ A start tag, delimited by `<` and `>` +/
    elementStart,

    /++ An end tag, delimited by `</` and `>` +/
    elementEnd,

    /++ An empty tag, delimited by `<` and `/>` +/
    elementEmpty,

    /++ A text element, without any specific delimiter +/
    text,

    /++ A cdata section, delimited by `<![cdata` and `]]>` +/
    cdata,

    /++ A comment, delimited by `<!--` and `-->` +/
    comment,

    /++ A processing instruction, delimited by `<?` and `?>` +/
    processingInstruction,

    /++ An attlist declaration, delimited by `<!ATTLIST` and `>` +/
    attlistDecl,
    /++ An element declaration, delimited by `<!ELEMENT` and `>` +/
    elementDecl,
    /++ An entity declaration, delimited by `<!ENTITY` and `>` +/
    entityDecl,
    /++ A notation declaration, delimited by `<!NOTATION` and `>` +/
    notationDecl,
    /++ Any unrecognized kind of declaration, delimited by `<!` and `>` +/
    declaration,

    /++ A conditional section, delimited by `<![` `[` and `]]>` +/
    conditional,
}

/++
+   Checks whether its argument fulfills all requirements to be used as XML parser.
+
+   An XML parser is the second component in the parsing chain. It is usually built
+   on top of a lexer and used to feed a cursor.
+   The slices contained in the tokens returned by the parser are ephemeral: every
+   reference to them may or may not be invalidated by subsequent calls to `popFront`.
+   If the caller needs them, it has to copy them somewhere else.
+
+   Params:
+       P = the type to be tested
+
+   Returns:
+   `true` if P satisfies the XML parser specification here stated; `false` otherwise
+
+   Specification:
+   The parser shall at least:
+   $(UL
+       $(LI have `alias CharacterType`: the type of a single source character;)
+       $(LI have `alias InputType`: the type of the input which is used to feed this
+            parser;)
+       $(LI be an `InputRange`, whose elements shall support at least the following fields:
+            $(UL
+               $(LI `XMLKind kind`: the kind of this node;)
+               $(LI `P.CharacterType[] content`: the contents of this node, excluding
+                     the delimiters specified in the documentation of `XMLKind`;)
+            ))
+       $(LI have `void setSource(InputType)`: sets the input source for this parser
+            and eventual underlying components; the parser may perform other
+            initialization work and even consume part of the input during this
+            operation; after (partial or complete) usage, a parser may be reinitialized
+            and used with another input by calling this function;)
+   )
+/
template isLowLevelParser(P)
{
    enum bool isLowLevelParser = isInputRange!P && is(typeof(ElementType!P.kind) == XMLKind)
                                 && is(typeof(ElementType!P.content) == P.CharacterType[]);
}

/++
+   Checks whether its argument is a saveable parser.
+
+   A saveable parser is a parser enhanced with a `save` method analogous to the `save`
+   method of `ForwardRange`s.
+
+   Params:
+       P = the type to be tested
+
+   Returns:
+   `true` if P is a parser (as specified by `isLowLevelParser`) and also supports the
+   `save` method as specified here; `false` otherwise
+
+   Specification:
+   The type shall support at least:
+   $(UL
+       $(LI all methods and aliases specified by `isLowLevelParser`)
+       $(LI `P save()`: returns an independent copy of the current parser; the
+             copy must start at the position the original parser was when this method
+             was called; the two copies shall be independent, in that advancing one
+             does not advance the other.)
+   )
+/
template isSaveableLowLevelParser(P)
{
    enum bool isSaveableLowLevelParser = isLowLevelParser!P && isForwardRange!P;
}

// LEVEL 3: CURSORS

/++
+   Checks whether its argument fulfills all requirements to be used as XML cursor.
+
+   The cursor is the hearth of the XML parsing chain. Every higher level component
+   (SAX, DOM, validations) builds on top of this concept.
+   A cursor is a logical pointer inside a stream of XML nodes. It can be queried
+   for properties of the current node (kind, name, attributes, ...) and it can be
+   advanced in the stream. It cannot move backwards. Any reference to the outputs
+   of a cursor may or may not be invalidated by advancing operations.
+
+   Params:
+       CursorType = the type to be tested
+
+   Returns:
+   `true` if CursorType satisfies the XML cursor specification here stated;
+   `false` otherwise
+
+   Specification:
+   A cursor shall support at least these methods and aliases:
+   $(UL
+       $(LI `alias StringType`: the type of an output string; most methods will
+             return instances of this type;)
+       $(LI `alias InputType`: the type of the input which is used to feed this
+             cursor;)
+       $(LI `void setSource(InputType)`: sets the input source for this cursor and
+             eventual underlying components; the cursor may perform other initialization
+             work and even consume part of the input during this operation; after
+            (partial or complete) usage, a cursor may be reinitialized and used with
+             another input by calling this function;)
+       $(LI `bool atBeginning()`: returns true if the cursor has never been advanced;
+             it is thus pointing to the node of type `XMLKind.document` representing
+             the XML declaration of the document;)
+       $(LI `bool documentEnd()`: returns `true` if the input has been completely
+             consumed; if it is the case, any advancing operation will perform no action)
+       $(LI  the following methods can be used to query the current node properties:
+             $(UL
+               $(LI `XMLKind kind()`: returns the `XMLKind` of the current node;)
+               $(LI `StringType name()`: returns the qualified name of the current
+                     element or the target of the current processing instruction;
+                     the empty string in all other cases;)
+               $(LI `StringType localName()`: returns the local name of the
+                     current element, if it has a prefix; the empty string in all
+                     other cases;)
+               $(LI `StringType prefix()`: returns the prefix of the current element,
+                     if it has any; the empty string in all other cases;)
+               $(LI `auto attributes()`: returns a range of all attributes defined
+                     on the current element; if the current node is a processing
+                     instruction, its data section is parsed as if it was the attributes
+                     list of an element (which is quite common); for all other node
+                     kinds, an empty range is returned.
+                     The type returned by this range `front` method shall at least support
+                     the following fields:
+                     $(UL
+                       $(LI `StringType name`: the qualified name of the attribute;)
+                       $(LI `StringType prefix`: the prefix of the attribute, if it
+                             has any; the empty string otherwise;)
+                       $(LI `StringType localName`: the local name of the attribute,
+                             if it has any prefix; the empty string otherwise;)
+                       $(LI `StringType value`: the value of the attribute;)
+                     ))
+               $(LI `StringType content()`: returns the text content of the current
+                     comment, text node or cdata section or the data of the current
+                     processing instruction; the empty string in all other cases;)
+               $(LI `StringType wholeContent()`: returns the entire content of the node;)
+             ))
+       $(LI  the following methods can be used to advance the cursor in the stream
+             of XML nodes:
+             $(UL
+               $(LI `bool enter()`: tries to advance the cursor to the first child
+                     of the current node; returns `true` if the operation succeeded;
+                     otherwise, if the cursor was positioned on the start tag of an
+                     element, it is now positioned on its closing tag; otherwise,
+                     the cursor did not advance;)
+               $(LI `bool next()`: tries to advance the cursor to the next sibling
+                     of the current node; returns `true` if the operation succeded;
+                     otherwise (i.e. the cursor was positioned on the last child
+                     of an element) it is now positioned on the closing tag of the
+                     parent element;)
+               $(LI `void exit()`: advances the cursor to the closing tag of the
+                     element containing the current node;)
+             ))
+   )
+
+   Examples:
+   ---
+   /* recursively prints the kind of each node */
+   void recursivePrint(CursorType)(ref CursorType cursor)
+       if (isCursor!CursorType)
+   {
+       do
+       {
+           // print the kind of the current node
+           writeln(cursor.kind);
+           // if the node has children
+           if (cursor.enter)
+           {
+               // recursively print them
+               recursivePrint(cursor);
+               // back to the current level
+               cursor.exit;
+           }
+       }
+       // iterate on every sibling
+       while (cursor.next)
+   }
+   ---
+/
template isCursor(CursorType)
{
    enum bool isCursor = is(typeof(
    (inout int = 0)
    {
        alias S = CursorType.StringType;

        CursorType cursor;
        bool b;

        b = cursor.atBeginning;
        b = cursor.documentEnd;
        b = cursor.next;
        b = cursor.enter;
        cursor.exit;
        XMLKind kind = cursor.kind;
        auto s = cursor.name;
        s = cursor.localName;
        s = cursor.prefix;
        s = cursor.content;
        s = cursor.wholeContent;
        auto attrs = cursor.attributes;
        s = attrs.front.prefix;
        s = attrs.front.localName;
        s = attrs.front.name;
        s = attrs.front.value;
    }
    ));
}

/++
+   Checks whether its argument is a saveable cursor.
+
+   A saveable cursor is a cursor enhanced with a `save` method analogous to the `save`
+   method of `ForwardRange`s.
+
+   Params:
+       CursorType = the type to be tested
+
+   Returns:
+   `true` if CursorType is a cursor (as specified by `isCursor`) and also supports the
+   `save` method as specified here; `false` otherwise
+
+   Specification:
+   The type shall support at least:
+   $(UL
+       $(LI all methods and aliases specified by `isCursor`)
+       $(LI `CursorType save()`: returns an independent copy of the current cursor; the
+             copy must start at the position the original cursor was when this method
+             was called; the two copies shall be independent, in that advancing one
+             does not advance the other.)
+   )
+/
template isSaveableCursor(CursorType)
{
    enum bool isSaveableCursor = isCursor!CursorType && is(typeof(
    (inout int = 0)
    {
        CursorType cursor1;
        CursorType cursor2 = cursor1.save();
    }));
}

// WRITERS

template isWriter(WriterType)
{
    enum bool isWriter = is(typeof(
    (inout int = 0)
    {
        alias StringType = WriterType.StringType;

        WriterType writer;
        StringType s;

        writer.writeXMLDeclaration(10, s, true);
        writer.writeComment(s);
        writer.writeText(s);
        writer.writeCDATA(s);
        writer.writeProcessingInstruction(s, s);
        writer.startElement(s);
        writer.closeElement(s);
        writer.writeAttribute(s, s);
    }));
}

// COMMON

template needSource(T)
{
    enum bool needSource = is(typeof(
    (inout int = 0)
    {
        alias InputType = T.InputType;

        T component;
        InputType input;

        component.setSource(input);
    }));
}

/++
+   Generic XML exception; thrown whenever a component experiences an error, unless
+   the user provided a custom error handler.
+/
class XMLException: Exception
{
    this(string msg, string file = __FILE__, size_t line = __LINE__)
    {
        super(msg, file, line);
    }
}

// PRIVATE STUFF

package mixin template UsesAllocator(Alloc, bool genDefaultCtor = false)
{
    static if (is(Alloc == class))
        private alias TrueAlloc = Alloc;
    else
        private alias TrueAlloc = Alloc*;

    static if (is(typeof(Alloc.instance) == Alloc))
    {
        static if (is(Alloc == class))
            private TrueAlloc allocator = Alloc.instance;
        else
            private TrueAlloc allocator = &(Alloc.instance);

        static if (genDefaultCtor)
            this() {}
    }
    else
    {
        private TrueAlloc allocator;
        @disable this();
    }

    this(TrueAlloc allocator)
    {
        this.allocator = allocator;
    }

    static if (!is(Alloc == class))
        this(ref Alloc allocator)
        {
            this.allocator = &allocator;
        }
}

package mixin template UsesErrorHandler(ErrorHandler)
{
    private ErrorHandler handler;
    @property auto errorHandler() { return &handler; }
    @property void errorHandler(ErrorHandler eh)
    {
        assert(eh, "Null errorHandler on setting");
        handler = eh;
    }
}