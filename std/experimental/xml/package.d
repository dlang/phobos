/*
*             Copyright Lodovico Giaretta 2016 - .
*  Distributed under the Boost Software License, Version 1.0.
*      (See accompanying file LICENSE_1_0.txt or copy at
*            http://www.boost.org/LICENSE_1_0.txt)
*/

/++
+   An xml processing library.
+
+   $(H Quick start)
+   The library offers a simple fluid interface to build an XML parsing chain.
+   Let's see a first example: we want to change the name of an author in our book
+   catalogue, using DOM.
+   ---
+   string input = q"{
+   <?xml version = "1.0"?>
+   <books>
+       <book ISBN = "078-5342635362">
+           <title>The D Programming Language</title>
+           <author>A. Alexandrescu</author>
+       </book>
+       <book ISBN = "978-1515074601">
+           <title>Programming in D</title>
+           <author>Ali Çehreli</author>
+       </book>
+       <book ISBN = "978-0201704310">
+           <title>Modern C++ Design</title>
+           <author>A. Alexandrescu</author>
+       </book>
+   </books>
+   }";
+
+   // the following steps are all configurable
+   auto domBuilder =
+        chooseLexer!input  // instantiate the best lexer based on the type of input
+       .parser             // instantiate a parser on top of the lexer
+       .cursor             // instantiate a cursor on top of the parser
+       .domBuilder;        // and finally the DOM builder on top of the cursor
+
+   // the source is forwarded down the parsing chain and everything is initialized
+   domBuilder.setSource(input);
+
+   // recursively build the entire DOM tree
+   domBuilder.buildRecursive;
+   auto dom = domBuilder.getDocument;
+
+   // find and substitute all matching authors
+   foreach (author; dom.getElementsByTagName("author"))
+       if (author.textContent == "A. Alexandrescu")
+           author.textContent = "Andrei Alexandrescu";
+
+   // write it out to "catalogue.xml"
+   auto file = File("catalogue.xml", "w");
+   file.lockingTextWriter
+       .writerFor!string   // instatiates an xml writer on top of an output range
+       .writeDOM(dom);     // write the document with all of its children
+   ---
+   Also available is a SAX parser, which we will use to find all text nodes containing
+   a specific word:
+   ---
+   // don't bother about the type of a node: the library will do the right instantiations
+   static struct MyHandler(NodeType)
+   {
+       void onText(ref NodeType node)
+       {
+           if (node.content.splitter.find.canFind("D"))
+               writeln("Match found: ", node.content);
+       }
+   }
+
+   auto saxParser =
+        chooseParser!input     // this is a shorthand for chooseLexer!Input.parse
+       .cursor
+       .saxParser!MyHandler;   // only this call changed from the previous example chain
+
+   saxParser.setSource(input);
+   saxParser.processDocument;  // this call triggers the actual work
+
+   // With the same input of the first example, the output would be:
+   // Match found: The D Programming Language
+   // Match found: Programming in D
+   ---
+   You may want to perform extra checks on the input, to guarantee correctness;
+   this is achieved by plugging custom components in the chain.
+   Let's use this feature to validate our input and write it to a file
+   ---
+   // the basic cursor only detects missing xml declarations and unparseable attributes
+   auto callback1 = (CursorError err)
+   {
+       if (err == CursorError.missingXMLDeclaration)
+           assert(0, "Missing XML declaration");
+       else
+           assert(0, "Invalid attributes syntax");
+   }
+
+   // used by checkXMLNames, a pluggable validator
+   auto callback2 = (string s) { assert(0, "Invalid XML element name"); }
+   auto callback3 = (string s) { assert(0, "Invalid XML attribute name"); }
+
+   auto cursor =
+       .chooseParser!input((){ assert(0, "Parser error") })    // most components take an
+       .cursor(callback1)                                      // optional error handler
+        // time to plug-in a validator
+       .elementNestingValidator!(
+           (){ assert(0, "Wrong nesting of xml tags"); }       // called if tags are not well nested
+       );
+
+   auto writer =
+        myOutputRange                                          // a writer builds on top of an output range
+       .writerFor!(cursor.StringType)
+       .withValidation!checkXMLNames(callback2, callback3)     // we can also apply validations while writing back
+       .writeCursor(cursor)                                    // write the entire contents of the cursor
+   ---
+   While DOM and SAX are simple, standardized APIs, you may want to directly use
+   the underlying Cursor API, which provides great control, flexibility and speed,
+   at the price of a slightly lower abstraction level:
+   ---
+   // A function to inspect the entire document recursively, writing the kind of nodes encountered
+   void writeRecursive(T)(ref T cursor)
+   {
+       // cycle the current node and all its siblings
+       do
+       {
+           writeln(cursor.kind);
+           // if the current node has children, inspect them recursively
+           if (cursor.enter)
+           {
+               writeRecursive(cursor);
+               cursor.exit;
+           }
+       }
+       while (cursor.next);
+   }
+
+   auto cursor =
+        chooseParser!input
+       .cursor;                // this time we stop here and use the cursor directly
+
+   cursor.setSource(input);
+   writeRecursive(cursor);     // call our function
+   ---
+
+   $(H Library overview)
+
+   $(HH The parsing chain)
+
+   The xml input may come into different forms: a big string, a range of smaller
+   strings, a range of characters, and so on. The first layer of the chain, the
+   lexer, has the purpose of hiding the input details from the higher levels.
+
+   Then comes the parser, which does the hard job of tokenizing the input, without
+   caring about the details, so that it is suitable for parsing many XML-like languages,
+   like HTML.
+
+   The third component is the cursor, the heart of this library. A cursor can be seen
+   as a pointer into the stream of xml nodes. It points to a single node, and provides
+   methods to access the details of that node. The cursor is forward-only: it cannot
+   get back to a previous node. But it can advance in smart ways: for example, it
+   knows how to skip all children of a node, if the user doesn't care about them.
+   The cursor API is the "intermediate language" of the library: many transformations
+   and validations happen at this stage, whose output is then used by all higher level
+   APIs (e.g. DOM and SAX).
+
+   Each component in this chain can be substituted with a custom one, providing high
+   flexibility. The entire library is built as a collection of small components with
+   standardized APIs that can easily be composed together as needed.
+
+   To allow fast and memory-light parsing, the parsing chain does not provide any
+   guarantee about the lifetime of its output: in general, every string returned
+   by any component must be considered invalidated by the advancement to another
+   component, unless stated otherwise. This allows lexers to reuse their buffers
+   for each input token, and every component that needs to store some data for later
+   use must copy it.
+
+   $(HH The cursor wrappers)
+
+   Transformations and validations of the xml nodes happen at the cursor level,
+   via a number of optional, pluggable and configurable components. These are constructed
+   on top of a cursor, and expose the cursor API themselves, thus being completely
+   transparent to higher levels that simply expect a cursor.
+
+   These components work by forwarding every API call to the underlying cursor,
+   applying custom operations, before and after, when needed. This is another area
+   in which the user is free to provide his own implementations with custom functionality,
+   but the library already provides a set of useful operations, ranging from
+   copying/interning strings for later use to checking the well-formedness of some
+   parts of the document.
+
+   $(HH The DOM)
+
+   The DOM, as described in the official specification, is purely object-oriented,
+   based on interfaces and runtime polymorphism. This library doesn't want to
+   change this approach, and provides a the set of interfaces specified by the
+   DOM Level 3 specification, so that the other libraries can provide custom implementations
+   that can still interact with this library (e.g. use the DOMBuilder provided here).
+
+   But D also provides powerful template programming facilities, and this libraries
+   uses them extensively; the DOMBuilder is templated on the DOM Implementation:
+   choosing to instantiate it with the generic interface will give a builder that can
+   construct any possible implementation, while instantiating it with a concrete
+   class will give a specialized builder that can work in `@safe`, `@nogc`, `pure`,
+   `nothrow` contexts (depending on the characterstics of the concrete implementation).
+   The default DOM implementation provided by this library is thought for @nogc usage,
+   with the ability to specify a custom allocator.
+
+   $(HH The writer API)
+
+   The writer API allows to output xml data to any OutputRange. Despite being simpler
+   than the input API, it is still very flexible and customizable. The user can
+   apply custom validations (built with the cursor API, so the same components
+   used for validating on input can be reused) and define custom pretty-printers
+   to write nicer or shorter xml.
+
+   The library also provides some custom higher level wrappers to directly write
+   the contents of cursors or entire DOM trees.
+
+   Macros:
+       H = <h2>$1</h2>
+       HH = <h3>$1</h3>
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

module std.experimental.xml;

public import std.experimental.xml.interfaces;
public import std.experimental.xml.lexers;
public import std.experimental.xml.parser;
public import std.experimental.xml.cursor;
public import std.experimental.xml.validation;
public import std.experimental.xml.writer;
public import std.experimental.xml.domparser;
public import std.experimental.xml.domimpl;
public import std.experimental.xml.sax;
public import std.experimental.xml.faststrings;

public import dom = std.experimental.xml.dom;

@nogc unittest
{
    import std.typecons : Yes, No;

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

    auto cursor =
         xml
        .lexer((){})
        .parser!(No.preserveWhitespace)
        .cursor!(Yes.conflateCDATA)((){})
        .checkXMLNames;

    assert(cursor.kind == XMLKind.document);
}