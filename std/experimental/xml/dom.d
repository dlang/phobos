/*
*             Copyright Lodovico Giaretta 2016 - .
*  Distributed under the Boost Software License, Version 1.0.
*      (See accompanying file LICENSE_1_0.txt or copy at
*            http://www.boost.org/LICENSE_1_0.txt)
*/

/++
+   This module declares the DOM Level 3 interfaces as stated in the W3C DOM
+   specification.
+
+   For a more complete reference, see the
+   $(LINK2 https://www.w3.org/TR/DOM-Level-3-Core/, official specification),
+   from which all documentation in this module is taken.
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

module std.experimental.xml.dom;

import std.typecons : BitFlags;
import std.variant : Variant;

/++
+   The DOMUserData type is used to store application data inside DOM nodes.
+/
alias UserData = Variant;

/++
+   When associating an object to a key on a node using Node.setUserData() the
+   application can provide a handler that gets called when the node the object
+   is associated to is being cloned, imported, or renamed. This can be used by
+   the application to implement various behaviors regarding the data it associates
+   to the DOM nodes.
+/
alias UserDataHandler(DOMString) =
        void delegate(UserDataOperation, DOMString, UserData, Node!DOMString, Node!DOMString);

/++
+   An integer indicating which type of node this is.
+
+   Note:
+   Numeric codes up to 200 are reserved to W3C for possible future use.
+/
enum NodeType: ushort
{
    element = 1,
    attribute,
    text,
    cdataSection,
    entityReference,
    entity,
    processingInstruction,
    comment,
    document,
    documentType,
    documentFragment,
    notation,
}

/++
+   A bitmask indicating the relative document position of a node with respect to another node.
+   Returned by `Node.compareDocumentPosition`.
+/
enum DocumentPosition: ushort
{
    /// Set when the two nodes are in fact the same
    none         = 0,
    /// Set when the two nodes are not in the same tree
    disconnected = 1,
    /// Set when the second node precedes the first
    preceding    = 2,
    /// Set when the second node follows the first
    following    = 4,
    /// Set when the second node _contains the first
    contains     = 8,
    /// Set when the second node is contained by the first
    containedBy = 16,
    /++
    +   Set when the returned ordering of the two nodes may be different across
    +   DOM implementations; for example, for two attributes of the same node,
    +   an implementation may return `preceding | implementationSpecific` and another
    +   may return `following | implementationSpecific`, because at the DOM level
    +   the attributes ordering is unspecified
    +/
    implementationSpecific = 32,
}

/++
+   An integer indicating the type of operation being performed on a node.
+/
enum UserDataOperation: ushort
{
    /// The node is cloned, using `Node.cloneNode()`.
    nodeCloned = 1,
    /// The node is imported, using `Document.importNode()`.
    nodeImported,
    /++
    +   The node is deleted.
    +
    +   Note:
    +   This may not be supported or may not be reliable in certain environments,
    +   where the implementation has no real control over when objects are actually deleted.
    +/
    nodeDeleted,
    /// The node is renamed, using `Document.renameNode()`.
    nodeRenamed,
    /// The node is adopted, using `Document.adoptNode()`.
    nodeAdopted,
}

/++
+   An integer indicating the type of error generated.
+
+   Note:
+   Other numeric codes are reserved for W3C for possible future use.
+/
enum ExceptionCode: ushort
{
    /// If index or size is negative, or greater than the allowed value.
    indexSize,
    /// If the specified range of text does not fit into a `DOMString`.
    domStringSize,
    /// If any `Node` is inserted somewhere it doesn't belong.
    hierarchyRequest,
    /// If a `Node` is used in a different document than the one that created it (that doesn't support it).
    wrongDocument,
    /// If an invalid or illegal character is specified, such as in an XML name.
    invalidCharacter,
    /// If data is specified for a `Node` which does not support data.
    noDataAllowed,
    /// If an attempt is made to modify an object where modifications are not allowed.
    noModificationAllowed,
    /// If an attempt is made to reference a `Node` in a context where it does not exist.
    notFound,
    /// If the implementation does not support the requested type of object or operation.
    notSupported,
    /// If an attempt is made to add an attribute that is already in use elsewhere.
    inuseAttribute,
    /// If an attempt is made to use an object that is not, or is no longer, usable.
    invalidState,
    /// If an invalid or illegal string is specified.
    syntax,
    /// If an attempt is made to modify the type of the underlying object.
    invalidModification,
    /// If an attempt is made to create or change an object in a way which is incorrect with regard to namespaces.
    namespace,
    /// If a parameter or an operation is not supported by the underlying object.
    invalidAccess,
    /// If a call to a method such as insertBefore or removeChild would make the `Node` invalid.
    validation,
    /// If the type of an object is incompatible with the expected type of the parameter associated to the object.
    typeMismatch,
}

/// An integer indicating the severity of a `DOMError`.
enum ErrorSeverity: ushort
{
    /++
    +   The severity of the error described by the `DOMError` is warning. A `WARNING`
    +   will not cause the processing to stop, unless the call of the `DOMErrorHandler`
    +   returns `false`.
    +/
    warning,
    /++
    +   The severity of the error described by the `DOMError` is error. A `ERROR`
    +   may not cause the processing to stop if the error can be recovered, unless
    +   the call of the `DOMErrorHandler` returns `false`.
    +/
    error,
    /++
    +   The severity of the error described by the `DOMError` is fatal error. A `FATAL_ERROR`
    +   will cause the normal processing to stop. The return value of calling the `DOMErrorHandler`
    +   is ignored unless the implementation chooses to continue, in which case
    +   the behavior becomes undefined.
    +/
    fatalError,
}

enum DerivationMethod: ulong
{
    restriction = 0x00000001,
    extension   = 0x00000002,
    union_      = 0x00000004,
    list        = 0x00000008,
}

/++
+   DOM operations only raise exceptions in "exceptional" circumstances, i.e.,
+   when an operation is impossible to perform (either for logical reasons, because
+   data is lost, or because the implementation has become unstable). In general,
+   DOM methods return specific error values in ordinary processing situations,
+   such as out-of-bound errors when using `NodeList`.
+
+   Implementations should raise other exceptions under other circumstances. For
+   example, implementations should raise an implementation-dependent exception
+   if a `null` argument is passed when `null` was not expected.
+/
abstract class DOMException: Exception
{
    ///
    @property ExceptionCode code();

    ///
    pure nothrow @nogc @safe this(string msg, string file = __FILE__, size_t line = __LINE__)
    {
        super(msg, file, line);
    }
}

/++
+   The `DOMStringList` interface provides the abstraction of an ordered collection
+   of `DOMString` values, without defining or constraining how this collection is
+   implemented. The items in the DOMStringList are accessible via an integral index,
+   starting from `0`.
+/
interface DOMStringList(DOMString)
{
    DOMString item(size_t index);
    @property size_t length();
    bool contains(DOMString str);
};

/++
+   The `DOMImplementationList` interface provides the abstraction of an ordered
+   collection of DOM implementations, without defining or constraining how this
+   collection is implemented. The items in the `DOMImplementationList` are accessible
+   via an integral index, starting from `0`.
+/
interface DOMImplementationList(DOMString)
{
    DOMImplementation!DOMString item(size_t index);
    @property size_t length();
}

/++
+   This interface permits a DOM implementer to supply one or more implementations,
+   based upon requested features and versions, as specified in DOM Features.
+   Each implemented DOMImplementationSource object is listed in the binding-specific
+   list of available sources so that its `DOMImplementation` objects are made available.
+/
interface DOMImplementationSource(DOMString)
{
    /// A method to request the first DOM implementation that supports the specified features.
    DOMImplementation!DOMString getDOMImplementation(DOMString features);
    /// A method to request a list of DOM implementations that support the specified features and versions, as specified in DOM Features.
    DOMImplementationList!DOMString getDOMImplementationList(DOMString features);
}

/++
+   The DOMImplementation interface provides a number of methods for performing
+   operations that are independent of any particular instance of the document object model.
+/
interface DOMImplementation(DOMString)
{
    /++
    +   Creates an empty DocumentType node. Entity declarations and notations are not
    +   made available. Entity reference expansions and default attribute additions do not occur.
    +/
    DocumentType!DOMString createDocumentType(DOMString qualifiedName, DOMString publicId, DOMString systemId);

    /++
    +   Creates a DOM Document object of the specified type with its document element.
    +
    +   Note that based on the DocumentType given to create the document, the implementation
    +   may instantiate specialized Document objects that support additional features than the "Core",
    +   such as "HTML". On the other hand, setting the DocumentType after the document
    +   was created makes this very unlikely to happen.
    +/
    Document!DOMString createDocument(DOMString namespaceURI, DOMString qualifiedName, DocumentType!DOMString doctype);

    bool hasFeature(string feature, string version_);
    Object getFeature(string feature, string version_);
}

/++
+   `DocumentFragment` is a "lightweight" or "minimal" `Document` object. It is very
+   common to want to be able to extract a portion of a document's tree or to create
+   a new fragment of a document. Imagine implementing a user command like cut or
+   rearranging a document by moving fragments around. It is desirable to have an
+   object which can hold such fragments and it is quite natural to use a `Node`
+   for this purpose. While it is true that a `Document` object could fulfill this
+   role, a `Document` object can potentially be a heavyweight object, depending
+   on the underlying implementation. What is really needed for this is a very lightweight
+   object. `DocumentFragment` is such an object.
+
+   Furthermore, various operations -- such as inserting nodes as children of another
+   `Node` -- may take `DocumentFragment` objects as arguments; this results in
+   all the child nodes of the `DocumentFragment` being moved to the child list of this node.
+
+   The children of a `DocumentFragment` node are zero or more nodes representing
+   the tops of any sub-trees defining the structure of the document. `DocumentFragment`
+   nodes do not need to be well-formed XML documents (although they do need to follow
+   the rules imposed upon well-formed XML parsed entities, which can have multiple
+   top nodes). For example, a `DocumentFragment` might have only one child and that
+   child node could be a `Text` node. Such a structure model represents neither
+   an HTML document nor a well-formed XML document.
+
+   When a `DocumentFragment` is inserted into a `Document` (or indeed any other
+   `Node` that may take children) the children of the `DocumentFragment` and not
+   the `DocumentFragment` itself are inserted into the `Node`. This makes the `DocumentFragment`
+   very useful when the user wishes to create nodes that are siblings; the `DocumentFragment`
+   acts as the parent of these nodes so that the user can use the standard methods
+   from the `Node` interface, such as `Node.insertBefore` and `Node.appendChild`.
+/
interface DocumentFragment(DOMString): Node!DOMString
{
}

/++
+   The `Document` interface represents the entire HTML or XML document. Conceptually,
+   it is the root of the document tree, and provides the primary access to the document's data.
+
+   Since elements, text nodes, comments, processing instructions, etc. cannot exist
+   outside the context of a `Document`, the `Document` interface also contains the
+   factory methods needed to create these objects. The `Node` objects created have
+   a `ownerDocument` attribute which associates them with the `Document` within
+   whose context they were created.
+/
interface Document(DOMString): Node!DOMString
{
    /++
    +   The `DocumentType` associated with this document. For XML documents without a
    +   document type declaration this returns `null`.
    +
    +   This provides direct access to the `DocumentType` node, child node of this
    +   `Document`. This node can be set at document creation time and later changed
    +   through the use of child nodes manipulation methods, such as `Node.insertBefore`,
    +   or `Node.replaceChild`.
    +/
    @property DocumentType!DOMString doctype();
    /++
    +   The `DOMImplementation` object that handles this document. A DOM application
    +   may use objects from multiple implementations.
    +/
    @property DOMImplementation!DOMString implementation();
    /++
    +   This is a convenience attribute that allows direct access to the child node
    +   that is the document element of the document.
    +/
    @property Element!DOMString documentElement();

    /++
    +   Creates an `Element` of the type specified.
    +   In addition, if there are known attributes with default values, `Attr` nodes
    +   representing them are automatically created and attached to the element.
    +   To create an `Element` with a qualified name and namespace URI, use the
    +   `createElementNS` method.
    +/
    Element!DOMString createElement(DOMString tagName);
    /++
    +   Creates an `Element` of the given qualified name and namespace URI.
    +   Per the XML Namespaces specification, applications must use the value `null`
    +   as the `namespaceURI` parameter for methods if they wish to have no namespace.
    +/
    Element!DOMString createElementNS(DOMString namespaceURI, DOMString qualifiedName);
    /// Creates an empty `DocumentFragment` object.
    DocumentFragment!DOMString createDocumentFragment();
    /// Creates a `Text` node given the specified string.
    Text!DOMString createTextNode(DOMString data);
    /// Creates a `Comment` node given the specified string.
    Comment!DOMString createComment(DOMString data);
    /// Creates a `CDATASection` node whose value is the specified string.
    CDATASection!DOMString createCDATASection(DOMString data);
    /// Creates a `ProcessingInstruction` node given the specified name and data strings.
    ProcessingInstruction!DOMString createProcessingInstruction(DOMString target, DOMString data);
    /++
    +   Creates an `Attr` of the given name. Note that the `Attr` instance can
    +   then be set on an `Element` using the `setAttributeNode` method.
    +   To create an attribute with a qualified name and namespace URI, use the
    +   `createAttributeNS` method.
    +/
    Attr!DOMString createAttribute(DOMString name);
    /++
    +   Creates an attribute of the given qualified name and namespace URI.
    +   Per the XML Namespaces specification, applications must use the value `null`
    +   as the `namespaceURI` parameter for methods if they wish to have no namespace.
    +/
    Attr!DOMString createAttributeNS(DOMString namespaceURI, DOMString qualifiedName);
    /++
    +   Creates an `EntityReference` object. In addition, if the referenced entity
    +   is known, the child list of the `EntityReference` node is made the same as
    +   that of the corresponding `Entity` node.
    +/
    EntityReference!DOMString createEntityReference(DOMString name);

    /++
    +   Returns a `NodeList` of all the `Element`s in document order with a given
    +   tag name and are contained in the document.
    +/
    NodeList!DOMString getElementsByTagName(DOMString tagname);
    /++
    +   Returns a `NodeList` of all the `Element`s with a given local name and
    +   namespace URI in document order.
    +/
    NodeList!DOMString getElementsByTagNameNS(DOMString namespaceURI, DOMString localName);
    /++
    +   Returns the `Element` that has an ID attribute with the given value. If no
    +   such element exists, this returns `null`. If more than one element has an
    +   ID attribute with that value, what is returned is undefined.
    +   The DOM implementation is expected to use the attribute `Attr.isId` to
    +   determine if an attribute is of type ID.
    +
    +   Note: Attributes with the name "ID" or "id" are not of type ID unless so defined.
    +/
    Element!DOMString getElementById(DOMString elementId);

    /++
    +   Imports a node from another document to this document, without altering or
    +   removing the source node from the original document; this method creates a
    +   new copy of the source node. The returned node has no parent; (`parentNode` is `null`).
    +
    +   For all nodes, importing a node creates a node object owned by the importing
    +   document, with attribute values identical to the source node's `nodeName` and
    +   `nodeType`, plus the attributes related to namespaces (`prefix`, `localName`,
    +   and `namespaceURI`). As in the `cloneNode` operation, the source node is
    +   not altered. User data associated to the imported node is not carried over.
    +   However, if any `UserData` handlers has been specified along with the associated
    +   data these handlers will be called with the appropriate parameters before this
    +   method returns.
    +/
    Node!DOMString importNode(Node!DOMString importedNode, bool deep);
    Node!DOMString adoptNode(Node!DOMString source);

    /++
    +   An attribute specifying the encoding used for this document at the time of
    +   the parsing. This is `null` when it is not known, such as when the `Document`
    +   was created in memory.
    +/
    @property DOMString inputEncoding();
    /++
    +   An attribute specifying, as part of the XML declaration, the encoding of
    +   this document. This is `null` when unspecified or when it is not known,
    +   such as when the Document was created in memory.
    +/
    @property DOMString xmlEncoding();

    /++
    +   An attribute specifying, as part of the XML declaration, whether this document
    +   is standalone. This is `false` when unspecified.
    +/
    @property bool xmlStandalone();
    /// ditto
    @property void xmlStandalone(bool);

    /++
    +   An attribute specifying, as part of the XML declaration, the version number
    +   of this document. If there is no declaration and if this document supports
    +   the "XML" feature, the value is "1.0". If this document does not support
    +   the "XML" feature, the value is always `null`.
    +/
    @property DOMString xmlVersion();
    /// ditto
    @property void xmlVersion(DOMString);

    /++
    +   An attribute specifying whether error checking is enforced or not.
    +   When set to `false`, the implementation is free to not test every possible
    +   error case normally defined on DOM operations, and not raise any `DOMException`
    +   on DOM operations or report errors while using `Document.normalizeDocument()`.
    +   In case of error, the behavior is undefined. This attribute is `true` by default.
    +/
    @property bool strictErrorChecking();
    /// ditto
    @property void strictErrorChecking(bool);

    /++
    +   The location of the document or `null` if undefined or if the `Document`
    +   was created using `DOMImplementation.createDocument`. No lexical checking
    +   is performed when setting this attribute; this could result in a `null`
    +   value returned when using `Node.baseURI`.
    +/
    @property DOMString documentURI();
    /// ditto
    @property void documentURI(DOMString);

    /// The configuration used when `Document.normalizeDocument()` is invoked.
    @property DOMConfiguration!DOMString domConfig();
    /++
    +   This method acts as if the document was going through a save and load cycle,
    +   putting the document in a "normal" form. As a consequence, this method
    +   updates the replacement tree of `EntityReference` nodes and normalizes `Text`
    +   nodes, as defined in the method Node.normalize().
    +/
    void normalizeDocument();
    /++
    +   Rename an existing node of type `ELEMENT` or `ATTRIBUTE`.
    +
    +   When possible this simply changes the name of the given node, otherwise
    +   this creates a new node with the specified name and replaces the existing
    +   node with the new node as described below.
    +   If simply changing the name of the given node is not possible, the following
    +   operations are performed: a new node is created, any registered event
    +   listener is registered on the new node, any user data attached to the old
    +   node is removed from that node, the old node is removed from its parent
    +   if it has one, the children are moved to the new node, if the renamed node
    +   is an `Element` its attributes are moved to the new node, the new node is
    +   inserted at the position the old node used to have in its parent's child
    +   nodes list if it has one, the user data that was attached to the old node
    +   is attached to the new node.
    +/
    Node!DOMString renameNode(Node!DOMString n, DOMString namespaceURI, DOMString qualifiedName);
}

/++
+   The `Node` interface is the primary datatype for the entire Document Object Model.
+   It represents a single node in the document tree. While all objects implementing
+   the `Node` interface expose methods for dealing with children, not all objects
+   implementing the `Node` interface may have children. For example, `Text` nodes
+   may not have children, and adding children to such nodes results in a `DOMException`
+   being raised.
+
+   The attributes `nodeName`, `nodeValue` and `attributes` are included as a mechanism
+   to get at node information without casting down to the specific derived interface.
+   In cases where there is no obvious mapping of these attributes for a specific `nodeType`
+   (e.g., `nodeValue` for an `Element` or attributes for a `Comment`), this returns `null`.
+   Note that the specialized interfaces may contain additional and more convenient
+   mechanisms to get and set the relevant information.
+/
interface Node(DOMString)
{
    /// A code representing the type of the underlying object.
    @property NodeType nodeType();
    /// The name of this node, depending on its type.
    @property DOMString nodeName();
    /++
    +   Returns the local part of the qualified name of this node.
    +
    +   For nodes of any type other than `ELEMENT` and `ATTRIBUTE` and nodes created
    +   with a DOM Level 1 method, such as `Document.createElement`, this is always `null`.
    +/
    @property DOMString localName();
    /++
    +   The namespace prefix of this node, or `null` if it is unspecified.
    +   When it is defined to be `null`, setting it has no effect, including if
    +   the node is read-only.
    +   Note that setting this attribute, when permitted, changes the `nodeName`
    +   attribute, which holds the qualified name, as well as the `tagName` and
    +   `name` attributes of the `Element` and `Attr` interfaces, when applicable.
    +   Setting the prefix to `null` makes it unspecified, setting it to an empty
    +   string is implementation dependent.
    +   Note also that changing the prefix of an attribute that is known to have a
    +   default value, does not make a new attribute with the default value and the
    +   original prefix appear, since the `namespaceURI` and `localName` do not change.
    +   For nodes of any type other than `ELEMENT` and `ATTRIBUTE` and nodes created
    +   with a DOM Level 1 method, such as `createElement` from the `Document`
    +   interface, this is always `null`.
    +/
    @property DOMString prefix();
    /// ditto
    @property void prefix(DOMString);
    /++
    +   The namespace URI of this node, or `null` if it is unspecified.
    +   This is not a computed value that is the result of a namespace lookup based
    +   on an examination of the namespace declarations in scope. It is merely the
    +   namespace URI given at creation time.
    +   For nodes of any type other than `ELEMENT` and `ATTRIBUTE` and nodes created
    +   with a DOM Level 1 method, such as `Document.createElement`, this is always `null`.
    +/
    @property DOMString namespaceURI();
    /// The absolute base URI of this node or null if the implementation wasn't able to obtain an absolute URI
    @property DOMString baseURI();

    /// The value of this node, depending on its type.
    @property DOMString nodeValue();
    /// ditto
    @property void nodeValue(DOMString);
    @property DOMString textContent();
    @property void textContent(DOMString);

    /++
    +   The parent of this node. All nodes, except `Attr`, `Document`, `DocumentFragment`,
    +   `Entity`, and `Notation` may have a parent. However, if a node has just been
    +   created and not yet added to the tree, or if it has been removed from the tree,
    +   this is `null`.
    +/
    @property Node!DOMString parentNode();
    /// A `NodeList` that contains all children of this node. If there are no children, this is a `NodeList` containing no nodes.
    @property NodeList!DOMString childNodes();
    /// The first child of this node. If there is no such node, this returns `null`.
    @property Node!DOMString firstChild();
    /// The last child of this node. If there is no such node, this returns `null`.
    @property Node!DOMString lastChild();
    /// The node immediately preceding this node. If there is no such node, this returns `null`.
    @property Node!DOMString previousSibling();
    /// The node immediately following this node. If there is no such node, this returns `null`.
    @property Node!DOMString nextSibling();
    /++
    +   The `Document` object associated with this node. This is also the `Document`
    +   object used to create new nodes. When this node is a `Document` or a `DocumentType`
    +   which is not used with any `Document` yet, this is `null`.
    +/
    @property Document!DOMString ownerDocument();

    /// A `NamedNodeMap` containing the attributes of this node (if it is an `Element`) or `null` otherwise.
    @property NamedNodeMap!DOMString attributes();
    /// Returns whether this node (if it is an element) has any attributes.
    bool hasAttributes();

    /++
    +   Inserts the node `newChild` before the existing child node `refChild`.
    +   If `refChild` is `null`, insert `newChild` at the end of the list of children.
    +   If `newChild` is a `DocumentFragment` object, all of its children are inserted,
    +   in the same order, before `refChild`. If the `newChild` is already in the
    +   tree, it is first removed.
    +/
    Node!DOMString insertBefore(Node!DOMString newChild, Node!DOMString refChild);
    /++
    +   Replaces the child node `oldChild` with `newChild` in the list of children,
    +   and returns the `oldChild` node.
    +   If `newChild` is a `DocumentFragment` object, `oldChild` is replaced by
    +   all of the `DocumentFragment` children, which are inserted in the same
    +   order. If the `newChild` is already in the tree, it is first removed.
    +/
    Node!DOMString replaceChild(Node!DOMString newChild, Node!DOMString oldChild);
    /// Removes the child node indicated by `oldChild` from the list of children, and returns it.
    Node!DOMString removeChild(Node!DOMString oldChild);
    Node!DOMString appendChild(Node!DOMString newChild);
    /// Returns whether this node has any children.
    bool hasChildNodes();

    /++
    +   Returns a duplicate of this node, i.e., serves as a generic copy constructor
    +   for nodes. The duplicate node has no parent (`parentNode` is `null`) and no
    +   user data. User data associated to the imported node is not carried over.
    +   However, if any `UserData` handlers has been specified along with the
    +   associated data these handlers will be called with the appropriate parameters
    +   before this method returns.
    +/
    Node!DOMString cloneNode(bool deep);
    bool isSameNode(Node!DOMString other);
    bool isEqualNode(Node!DOMString arg);

    /++
    +   Puts all `Text` nodes in the full depth of the sub-tree underneath this
    +   `Node`, including attribute nodes, into a "normal" form where only structure
    +   (e.g., elements, comments, processing instructions, CDATA sections, and entity
    +   references) separates `Text` nodes, i.e., there are neither adjacent `Text`
    +   nodes nor empty `Text` nodes. This can be used to ensure that the DOM view
    +   of a document is the same as if it were saved and re-loaded.
    +/
    void normalize();

    /// Tests whether the DOM implementation implements a specific feature and that feature is supported by this node.
    bool isSupported(string feature, string version_);
    Object getFeature(string feature, string version_);

    /++
    +   Retrieves the object associated to a key on a this node. The object must
    +   first have been set to this node by calling `setUserData` with the same key.
    +/
    UserData getUserData(string key);
    /++
    +   Associate an object to a key on this node.
    +   The object can later be retrieved from this node by calling `getUserData` with the same key.
    +/
    UserData setUserData(string key, UserData data, UserDataHandler!DOMString handler);

    /++
    +   Compares the reference node, i.e. the node on which this method is being
    +   called, with a node, i.e. the one passed as a parameter, with regard to
    +   their position in the document and according to the document order.
    +/
    BitFlags!DocumentPosition compareDocumentPosition(Node!DOMString other);

    /++
    +   Look up the prefix associated to the given namespace URI, starting from this node.
    +   The default namespace declarations are ignored by this method.
    +/
    DOMString lookupPrefix(DOMString namespaceURI);
    /// Look up the namespace URI associated to the given `prefix`, starting from this node.
    DOMString lookupNamespaceURI(DOMString prefix);
    /// This method checks if the specified `namespaceURI` is the default namespace or not.
    bool isDefaultNamespace(DOMString namespaceURI);
}

/++
+   The `NodeList` interface provides the abstraction of an ordered collection of
+   nodes, without defining or constraining how this collection is implemented.
+   `NodeList` objects in the DOM are live.
+
+   The items in the `NodeList` are accessible via an integral index, starting from `0`.
+/
interface NodeList(DOMString)
{
    /++
    +   Returns the `index`th item in the collection. If `index` is greater than
    +   or equal to the number of nodes in the list, this returns `null`.
    +/
    Node!DOMString item(size_t index);
    /++
    +   The number of nodes in the list. The range of valid child node indices is
    +   `0` to `length-1` inclusive.
    +/
    @property size_t length();
}

/++
+   Objects implementing the `NamedNodeMap` interface are used to represent collections
+   of nodes that can be accessed by name. Note that `NamedNodeMap` does not inherit
+   from `NodeList`; `NamedNodeMaps` are not maintained in any particular order.
+   Objects contained in an object implementing `NamedNodeMap` may also be accessed
+   by an ordinal index, but this is simply to allow convenient enumeration of the
+   contents of a `NamedNodeMap`, and does not imply that the DOM specifies an order
+   to these `Node`s.
+
+   `NamedNodeMap` objects in the DOM are live.
+/
interface NamedNodeMap(DOMString)
{
    /++
    +   Returns the `index`th item in the collection. If `index` is greater than
    +   or equal to the number of nodes in the list, this returns `null`.
    +/
    Node!DOMString item(size_t index);
    /++
    +   The number of nodes in the list. The range of valid child node indices is
    +   `0` to `length-1` inclusive.
    +/
    @property size_t length();

    /// Retrieves a node specified by name.
    Node!DOMString getNamedItem(DOMString name);
    /++
    +   Adds a node using its `nodeName` attribute. If a node with that name is
    +   already present in this map, it is replaced by the new one. Replacing a
    +   node by itself has no effect.
    +   As the `nodeName` attribute is used to derive the name which the node must
    +   be stored under, multiple nodes of certain types (those that have a "special"
    +   string value) cannot be stored as the names would clash. This is seen as
    +   preferable to allowing nodes to be aliased.
    +/
    Node!DOMString setNamedItem(Node!DOMString arg);
    /++
    +   Removes a node specified by name. When this map contains the attributes
    +   attached to an element, if the removed attribute is known to have a default
    +   value, an attribute immediately appears containing the default value as
    +   well as the corresponding namespace URI, local name, and prefix when applicable.
    +/
    Node!DOMString removeNamedItem(DOMString name);

    /++
    +   Retrieves a node specified by local name and namespace URI.
    +   Per the XML Namespaces specification, applications must use the value `null`
    +   as the `namespaceURI` parameter for methods if they wish to have no namespace.
    +/
    Node!DOMString getNamedItemNS(DOMString namespaceURI, DOMString localName);
    /++
    +   Adds a node using its `namespaceURI` and `localName`. If a node with that
    +   namespace URI and that local name is already present in this map, it is
    +   replaced by the new one. Replacing a node by itself has no effect.
    +   Per the XML Namespaces specification, applications must use the value `null`
    +   as the namespaceURI parameter for methods if they wish to have no namespace.
    +/
    Node!DOMString setNamedItemNS(Node!DOMString arg);
    /++
    +   Removes a node specified by local name and namespace URI. A removed attribute
    +   may be known to have a default value when this map contains the attributes attached
    +   to an element, as returned by the attributes attribute of the `Node` interface.
    +   If so, an attribute immediately appears containing the default value as well
    +   as the corresponding namespace URI, local name, and prefix when applicable.
    +   Per the XML Namespaces specification, applications must use the value `null`
    +   as the `namespaceURI` parameter for methods if they wish to have no namespace.
    +/
    Node!DOMString removeNamedItemNS(DOMString namespaceURI, DOMString localName);
}

/++
+   The `CharacterData` interface extends `Node` with a set of attributes and methods
+   for accessing character data in the DOM. For clarity this set is defined here
+   rather than on each object that uses these attributes and methods. No DOM objects
+   correspond directly to `CharacterData`, though `Text` and others do inherit
+   the interface from it. All offsets in this interface start from `0`.
+/
interface CharacterData(DOMString): Node!DOMString
{
    @property DOMString data();
    @property void data(DOMString);

    @property size_t length();

    /// Extracts a substring of `data` starting at `offset`, with length `count`.
    DOMString substringData(size_t offset, size_t count);
    /++
    +   Append the string to the end of the character data of the node. Upon success,
    +   data provides access to the concatenation of data and the DOMString specified.
    +/
    void appendData(DOMString arg);
    /// Insert a string at the specified offset.
    void insertData(size_t offset, DOMString arg);
    /// Remove a range of characters from the node. Upon success, `data` and `length` reflect the change.
    void deleteData(size_t offset, size_t count);
    /// Replace `count` characters starting at the specified offset with the specified string.
    void replaceData(size_t offset, size_t count, DOMString arg);
}

/++
+   The `Attr` interface represents an attribute in an `Element` object. Typically
+   the allowable values for the attribute are defined in a schema associated with the document.
+
+   `Attr` objects inherit the `Node` interface, but since they are not actually
+   child nodes of the element they describe, the DOM does not consider them part
+   of the document tree. Thus, the `Node` attributes `parentNode`, `previousSibling`
+   and `nextSibling` have a `null` value for `Attr` objects. The DOM takes the
+   view that attributes are properties of elements rather than having a separate
+   identity from the elements they are associated with; this should make it more
+   efficient to implement such features as default attributes associated with all
+   elements of a given type. Furthermore, `Attr` nodes may not be immediate children
+   of a `DocumentFragment`. However, they can be associated with `Element` nodes
+   contained within a `DocumentFragment`. In short, users and implementors of the
+   DOM need to be aware that `Attr` nodes have some things in common with other
+   objects inheriting the `Node` interface, but they also are quite distinct.
+/
interface Attr(DOMString): Node!DOMString
{
    /++
    +   Returns the _name of this attribute. If `Node.localName` is different from
    +   `null`, this attribute is a qualified name.
    +/
    @property DOMString name();
    /++
    +   `true` if this attribute was explicitly given a value in the instance document,
    +   `false` otherwise. If the application changed the value of this attribute
    +   node (even if it ends up having the same value as the default value) then
    +   it is set to `true`. The implementation may handle attributes with default
    +   values from other schemas similarly but applications should use `Document.normalizeDocument`
    +   to guarantee this information is up-to-date.
    +/
    @property bool specified();
    /++
    +   On retrieval, the value of the attribute is returned as a `DOMString`.
    +   Character and general entity references are replaced with their values.
    +   See also the method `getAttribute` on the `Element` interface.
    +   On setting, this creates a `Text` node with the unparsed contents of the
    +   string, i.e. any characters that an XML processor would recognize as markup
    +   are instead treated as literal text.
    +   See also the method `Element.setAttribute`.
    +/
    @property DOMString value();
    /// ditto
    @property void value(DOMString);

    /// The `Element` node this attribute is attached to or `null` if this attribute is not in use.
    @property Element!DOMString ownerElement();
    /++
    +   The type information associated with this attribute. While the type information
    +   contained in this attribute is guarantee to be correct after loading the
    +   document or invoking `Document.normalizeDocument`, `schemaTypeInfo` may
    +   not be reliable if the node was moved.
    +/
    @property XMLTypeInfo!DOMString schemaTypeInfo();
    /++
    +   Returns whether this attribute is known to be of type ID (i.e. to contain
    +   an identifier for its owner element) or not. When it is and its value is
    +   unique, the ownerElement of this attribute can be retrieved using the method
    +   `Document.getElementById`.
    +/
    @property bool isId();
}

interface Element(DOMString): Node!DOMString
{
    /// The name of the element. If `Node.localName` is different from `null`, this attribute is a qualified name.
    @property DOMString tagName();

    /// Retrieves an attribute value by name.
    DOMString getAttribute(DOMString name);
    /++
    +   Adds a new attribute. If an attribute with that name is already present in
    +   the element, its value is changed to be that of the value parameter. This
    +   value is a simple string; it is not parsed as it is being set. So any markup
    +   (such as syntax to be recognized as an entity reference) is treated as
    +   literal text, and needs to be appropriately escaped by the implementation
    +   when it is written out. In order to assign an attribute value that contains
    +   entity references, the user must create an `Attr` node plus any `Text` and
    +   `EntityReference` nodes, build the appropriate subtree, and use `setAttributeNode`
    +   to assign it as the value of an attribute.
    +   To set an attribute with a qualified name and namespace URI, use the `setAttributeNS` method.
    +/
    void setAttribute(DOMString name, DOMString value);
    /++
    +   Removes an attribute by name. If a default value for the removed attribute
    +   is defined in the DTD, a new attribute immediately appears with the default
    +   value as well as the corresponding namespace URI, local name, and prefix
    +   when applicable.
    +   To remove an attribute by local name and namespace URI, use the `removeAttributeNS` method.
    +/
    void removeAttribute(DOMString name);

    /// Retrieves an attribute node by name.
    Attr!DOMString getAttributeNode(DOMString name);
    /++
    +   Adds a new attribute node. If an attribute with that name (`nodeName`) is
    +   already present in the element, it is replaced by the new one. Replacing an
    +   attribute node by itself has no effect.
    +   To add a new attribute node with a qualified name and namespace URI, use
    +   the `setAttributeNodeNS` method.
    +/
    Attr!DOMString setAttributeNode(Attr!DOMString newAttr);
    /++
    +   Removes the specified attribute node. If a default value for the removed attribute
    +   is defined in the DTD, a new attribute immediately appears with the default
    +   value as well as the corresponding namespace URI, local name, and prefix
    +   when applicable.
    +/
    Attr!DOMString removeAttributeNode(Attr!DOMString oldAttr);

    /++
    +   Retrieves an attribute value by local name and namespace URI.
    +   Per the XML Namespaces specification, applications must use the value `null`
    +   as the `namespaceURI` parameter for methods if they wish to have no namespace.
    +/
    DOMString getAttributeNS(DOMString namespaceURI, DOMString localName);
    /++
    +   Adds a new attribute. If an attribute with the same local name and namespace
    +   URI is already present on the element, its prefix is changed to be the prefix
    +   part of the qualifiedName, and its value is changed to be the value parameter.
    +   This value is a simple string; it is not parsed as it is being set. So any markup
    +   (such as syntax to be recognized as an entity reference) is treated as
    +   literal text, and needs to be appropriately escaped by the implementation
    +   when it is written out. In order to assign an attribute value that contains
    +   entity references, the user must create an `Attr` node plus any `Text` and
    +   `EntityReference` nodes, build the appropriate subtree, and use `setAttributeNode`
    +   to assign it as the value of an attribute.
    +   Per the XML Namespaces specification, applications must use the value `null`
    +   as the `namespaceURI` parameter for methods if they wish to have no namespace.
    +/
    void setAttributeNS(DOMString namespaceURI, DOMString qualifiedName, DOMString value);
    /++
    +   Removes an attribute by local name and namespace URI. If a default value
    +   for the removed attribute is defined in the DTD, a new attribute immediately
    +   appears with the default value as well as the corresponding namespace URI,
    +   local name, and prefix when applicable.
    +   Per the XML Namespaces specification, applications must use the value `null`
    +   as the `namespaceURI` parameter for methods if they wish to have no namespace.
    +/
    void removeAttributeNS(DOMString namespaceURI, DOMString localName);

    /++
    +   Retrieves an `Attr` node by local name and namespace URI.
    +   Per the XML Namespaces specification, applications must use the value `null`
    +   as the `namespaceURI` parameter for methods if they wish to have no namespace.
    +/
    Attr!DOMString getAttributeNodeNS(DOMString namespaceURI, DOMString localName);
    /++
    +   Adds a new attribute. If an attribute with that local name and that namespace
    +   URI is already present in the element, it is replaced by the new one. Replacing
    +   an attribute node by itself has no effect.
    +   Per the XML Namespaces specification, applications must use the value `null`
    +   as the `namespaceURI` parameter for methods if they wish to have no namespace.
    +/
    Attr!DOMString setAttributeNodeNS(Attr!DOMString newAttr);

    /// Returns `true` when an attribute with a given `name` is specified on this element or has a default value, `false` otherwise.
    bool hasAttribute(DOMString name);
    /++
    +   Returns `true` when an attribute with a given `localName` and `namespaceURI`
    +   is specified on this element or has a default value, `false` otherwise.
    +   Per the XML Namespaces specification, applications must use the value `null`
    +   as the `namespaceURI` parameter for methods if they wish to have no namespace.
    +/
    bool hasAttributeNS(DOMString namespaceURI, DOMString localName);

    /++
    +   If the parameter `isId` is `true`, this method declares the specified
    +   attribute to be a user-determined ID attribute. This affects the value of
    +   `Attr.isId` and the behavior of `Document.getElementById`, but does not
    +   change any schema that may be in use, in particular this does not affect
    +   the `Attr.schemaTypeInfo` of the specified `Attr` node. Use the value `false`
    +   for the parameter `isId` to undeclare an attribute for being a user-determined ID attribute.
    +/
    void setIdAttribute(DOMString name, bool isId);
    /// ditto
    void setIdAttributeNS(DOMString namespaceURI, DOMString localName, bool isId);
    /// ditto
    void setIdAttributeNode(Attr!DOMString idAttr, bool isId);

    /// Returns a `NodeList` of all descendant `Element`s with a given tag name, in document order.
    NodeList!DOMString getElementsByTagName(DOMString name);
    /// Returns a `NodeList` of all the descendant `Element`s with a given local name and namespace URI in document order.
    NodeList!DOMString getElementsByTagNameNS(DOMString namespaceURI, DOMString localName);

    /// The type information associated with this element.
    @property XMLTypeInfo!DOMString schemaTypeInfo();
}

/++
+   The `Text` interface inherits from `CharacterData` and represents the textual
+   content (termed character data in XML) of an `Element` or `Attr`. If there is
+   no markup inside an element's content, the text is contained in a single object
+   implementing the `Text` interface that is the only child of the element. If
+   there is markup, it is parsed into the information items (elements, comments,
+   etc.) and `Text` nodes that form the list of children of the element.
+/
interface Text(DOMString): CharacterData!DOMString
{
    /++
    +   Breaks this node into two nodes at the specified `offset`, keeping both
    +   in the tree as siblings. After being split, this node will contain all
    +   the content up to the `offset` point. A new node of the same type, which
    +   contains all the content at and after the `offset` point, is returned.
    +   If the original node had a parent node, the new node is inserted as the
    +   next sibling of the original node. When the `offset` is equal to the length
    +   of this node, the new node has no data.
    +/
    Text!DOMString splitText(size_t offset);

    /// Returns whether this text node contains element content whitespace, often abusively called "ignorable whitespace".
    @property bool isElementContentWhitespace();

    @property DOMString wholeText();
    Text!DOMString replaceWholeText(DOMString content);
}

/++
+   This interface inherits from `CharacterData` and represents the content of a
+   comment, i.e., all the characters between the starting '<!--' and ending '-->'.
+/
interface Comment(DOMString): CharacterData!DOMString
{
}

/++
+   The `TypeInfo` interface represents a type referenced from `Element` or `Attr`
+   nodes, specified in the schemas associated with the document. The type is a
+   pair of a namespace URI and name properties, and depends on the document's schema.
+/
interface XMLTypeInfo(DOMString)
{
    @property DOMString typeName();
    @property DOMString typeNamespace();

    bool isDerivedFrom(DOMString typeNamespaceArg, DOMString typeNameArg, DerivationMethod derivationMethod);
}

/// DOMError is an interface that describes an error.
interface DOMError(DOMString)
{
    @property ErrorSeverity severity();
    @property DOMString message();
    @property DOMString type();
    @property Object relatedException();
    @property Object relatedData();
    @property DOMLocator!DOMString location();
}

/// `DOMLocator` is an interface that describes a location (e.g. where an error occurred).
interface DOMLocator(DOMString)
{
    @property long lineNumber();
    @property long columnNumber();
    @property long byteOffset();
    @property Node!DOMString relatedNode();
    @property DOMString uri();
}

/++
+   The `DOMConfiguration` interface represents the configuration of a document
+   and maintains a table of recognized parameters. Using the configuration, it
+   is possible to change `Document.normalizeDocument` behavior, such as replacing
+   the `CDATASection` nodes with `Text` nodes or specifying the type of the schema
+   that must be used when the validation of the `Document` is requested.
+/
interface DOMConfiguration(DOMString)
{
    void setParameter(string name, UserData value);
    UserData getParameter(string name);
    bool canSetParameter(string name, UserData value);
    @property DOMStringList!string parameterNames();
}

/++
+   CDATA sections are used to escape blocks of text containing characters that would
+   otherwise be regarded as markup. The only delimiter that is recognized in a CDATA
+   section is the "]]>" string that ends the CDATA section. CDATA sections cannot be nested.
+   Their primary purpose is for including material such as XML fragments, without
+   needing to escape all the delimiters.
+
+   The `CDATASection` interface inherits from the `CharacterData` interface through
+   the `Text` interface. Adjacent `CDATASection` nodes are not merged by use of the
+   normalize method of the `Node` interface.
+/
interface CDATASection(DOMString): Text!DOMString
{
}

/++
+   Each `Document` has a `doctype` attribute whose value is either `null` or a
+   `DocumentType` object. The `DocumentType` interface in the DOM Core provides
+   an interface to the list of entities that are defined for the document, and
+   little else because the effect of namespaces and the various XML schema efforts
+   on DTD representation are not clearly understood as of this writing.
+
+   DOM Level 3 doesn't support editing `DocumentType` nodes. `DocumentType` nodes are read-only.
+/
interface DocumentType(DOMString): Node!DOMString
{
    /// The name of DTD; i.e., the name immediately following the `DOCTYPE` keyword.
    @property DOMString name();
    /++
    +   A `NamedNodeMap` containing the general entities, both external and internal,
    +   declared in the DTD. Parameter entities are not contained. Duplicates are discarded.
    +/
    @property NamedNodeMap!DOMString entities();
    /++
    +   A `NamedNodeMap` containing the notations declared in the DTD. Duplicates are discarded.
    +   Every node in this map also implements the `Notation` interface.
    +/
    @property NamedNodeMap!DOMString notations();
    /// The public identifier of the external subset.
    @property DOMString publicId();
    /// The system identifier of the external subset. This may be an absolute URI or not.
    @property DOMString systemId();
    /++
    +   The internal subset as a string, or `null` if there is none.
    +   This is does not contain the delimiting square brackets.
    +
    +   Note:
    +   The actual content returned depends on how much information is available
    +   to the implementation. This may vary depending on various parameters,
    +   including the XML processor used to build the document.
    +/
    @property DOMString internalSubset();
}

/++
+   This interface represents a notation declared in the DTD. A notation either
+   declares, by name, the format of an unparsed entity or is used for formal
+   declaration of processing instruction targets. The `nodeName` attribute
+   inherited from `Node` is set to the declared name of the notation.
+
+   The DOM Core does not support editing `Notation` nodes; they are therefore readonly.
+
+   A `Notation` node does not have any parent.
+/
interface Notation(DOMString): Node!DOMString
{
    /// The public identifier of this notation. If the public identifier was not specified, this is `null`.
    @property DOMString publicId();
    /++
    +   The system identifier of this notation. If the system identifier was not
    +   specified, this is `null`. This may be an absolute URI or not.
    +/
    @property DOMString systemId();
}

/++
+   This interface represents a known entity, either parsed or unparsed, in an XML
+   document. Note that this models the entity itself not the entity declaration.
+
+   The `nodeName` attribute that is inherited from `Node` contains the name of the entity.
+
+   An XML processor may choose to completely expand entities before the structure
+   model is passed to the DOM; in this case there will be no `EntityReference`
+   nodes in the document tree.
+
+   DOM Level 3 does not support editing `Entity` nodes; if a user wants to make
+   changes to the contents of an `Entity`, every related `EntityReference` node
+   has to be replaced in the structure model by a clone of the `Entity`'s contents,
+   and then the desired changes must be made to each of those clones instead.
+   `Entity` nodes and all their descendants are readonly.
+
+   An `Entity` node does not have any parent.
+/
interface Entity(DOMString): Node!DOMString
{
    /// The public identifier associated with the entity if specified, and `null` otherwise.
    @property DOMString publicId();
    /++
    +   The system identifier associated with the entity if specified, and `null` otherwise.
    +   This may be an absolute URI or not.
    +/
    @property DOMString systemId();
    /// For unparsed entities, the name of the `Notation` for the entity. For parsed entities, this is `null`.
    @property DOMString notationName();
    /++
    +   An attribute specifying the encoding used for this entity at the time of
    +   parsing, when it is an external parsed entity. This is `null` if it an
    +   entity from the internal subset or if it is not known.
    +/
    @property DOMString inputEncoding();
    /++
    +   An attribute specifying, as part of the text declaration, the encoding of
    +   this entity, when it is an external parsed entity. This is `null` otherwise.
    +/
    @property DOMString xmlEncoding();
    /++
    +   An attribute specifying, as part of the text declaration, the version
    +   number of this entity, when it is an external parsed entity. This is
    +   `null` otherwise.
    +/
    @property DOMString xmlVersion();
}

/++
+   `EntityReference` nodes may be used to represent an entity reference in the tree.
+   When an `EntityReference` node represents a reference to an unknown entity, the
+   node has no children and its replacement value, when used by `Attr.value` for example, is empty.
+
+   As for `Entity` nodes, `EntityReference` nodes and all their descendants are readonly.
+/
interface EntityReference(DOMString): Node!DOMString
{
}

/++
+   The `ProcessingInstruction` interface represents a "processing instruction",
+   used in XML as a way to keep processor-specific information in the text of the document.
+/
interface ProcessingInstruction(DOMString): Node!DOMString
{
    /++
    +   The target of this processing instruction. XML defines this as being the
    +   first token following the markup that begins the processing instruction.
    +/
    @property DOMString target();
    /++
    +   The content of this processing instruction. This is from the first non white
    +   space character after the target to the character immediately preceding the `?>`.
    +/
    @property DOMString data();
    /// ditto
    @property void data(DOMString);
}