Ddoc

$(SPEC_S Embedded Documentation,

$(P
The D programming language enables embedding both contracts and test
code along side the actual code, which helps to keep them all
consistent with each other. One thing lacking is the documentation,
as ordinary comments are usually unsuitable for automated extraction
and formatting into manual pages.
Embedding the user documentation into the source code has important
advantages, such as not having to write the documentation twice, and
the likelihood of the documentation staying consistent with the code.
)

$(P
Some existing approaches to this are:
)

$(UL 
$(LI <a href="http://www.stack.nl/~dimitri/doxygen/">Doxygen</a> which already has some support for D)
$(LI Java's <a href="http://java.sun.com/j2se/javadoc/">Javadoc</a>,
 probably the most well-known)
$(LI C#'s <a href="http://msdn.microsoft.com/library/default.asp?url=/library/en-us/csref/html/vcoriXMLDocumentation.asp">embedded XML</a>)
$(LI Other <a href="http://www.python.org/sigs/doc-sig/otherlangs.html">documentation tools</a>)
)

$(P
D's goals for embedded documentation are:
)

$(OL 
	$(LI It looks good as embedded documentation, not just after it
	is extracted and processed.)
	$(LI It's easy and natural to write,
	i.e. minimal reliance on &lt;tags&gt; and other clumsy forms one
	would never see in a finished document.)
	$(LI It does not repeat information that the compiler already
	knows from parsing the code.)
	$(LI It doesn't rely on embedded HTML, as such will impede
	extraction and formatting for other purposes.)
	$(LI It's based on existing D comment forms, so it
	is completely independent of parsers only interested in D code.)
	$(LI It should look and feel different from code, so it won't
	be visually confused with code.)
	$(LI It should be possible for the user to use Doxygen or other
	documentation extractor if desired.)
)

<h2>Specification</h2>

$(P
The specification for the form of embedded documentation comments only
specifies how information is to be presented to the compiler.
It is implementation-defined how that information is used and the form
of the final presentation. Whether the final presentation form is an
HTML web page, a man page, a PDF file, etc. is not specified as part of the
D Programming Language.
)

<h3>Phases of Processing</h3>

$(P
Embedded documentation comments are processed in a series of phases:
)

$(OL 
	$(LI Lexical - documentation comments are identified and attached
	to tokens.)
	$(LI Parsing - documentation comments are associated with
	specific declarations and combined.)
	$(LI Sections - each documentation comment is divided up into
	a sequence of sections.)
	$(LI Special sections are processed.)
	$(LI Highlighting of non-special sections is done.)
	$(LI All sections for the module are combined.)
	$(LI Macro text substitution is performed to produce the final result.)
)

<h3>Lexical</h3>

$(P
Embedded documentation comments are one of the following forms:
)

$(OL 
	$(LI $(D_COMMENT /** ... */) The two *'s after the opening /)
	$(LI $(D_COMMENT /++ ... +/) The two +'s after the opening /)
	$(LI $(D_COMMENT ///) The three slashes)
)

$(P The following are all embedded documentation comments:)

---------------------------
/// This is a one line documentation comment.

/** So is this. */

/++ And this. +/

/**
   This is a brief documentation comment.
 */

/**
 * The leading * on this line is not part of the documentation comment.
 */

/*********************************
   The extra *'s immediately following the /** are not
   part of the documentation comment.
 */

/++
   This is a brief documentation comment.
 +/

/++
 + The leading + on this line is not part of the documentation comment.
 +/

/+++++++++++++++++++++++++++++++++
   The extra +'s immediately following the / ++ are not
   part of the documentation comment.
 +/

/**************** Closing *'s are not part *****************/
---------------------------

$(P
The extra *'s and +'s on the comment opening, closing and left margin are
ignored and are not part
of the embedded documentation.
Comments not following one of those forms are not documentation comments.
)

<h3>Parsing</h3>

$(P
Each documentation comment is associated with a declaration.
If the documentation comment is on a line by itself or with only whitespace
to the left, it refers to the next
declaration.
Multiple documentation comments applying to the same declaration
are concatenated.
Documentation comments not associated with a declaration are ignored.
Documentation comments preceding the $(I ModuleDeclaration) apply to the
entire module.
If the documentation comment appears on the same line to the right of a
declaration, it applies to that.
)

$(P
If a documentation comment for a declaration consists only of the
identifier $(TT ditto)
then the documentation comment for the previous declaration at the same
declaration scope is applied to this declaration as well.
)

$(P
If there is no documentation comment for a declaration, that declaration
may not appear in the output. To ensure it does appear in the output,
put an empty declaration comment for it.
)

------------------------------------
int a;  /// documentation for a; b has no documentation
int b;

/** documentation for c and d */
/** more documentation for c and d */
int c;
/** ditto */
int d;

/** documentation for e and f */ int e;
int f;	/// ditto

/** documentation for g */
int g; /// more documentation for g

/// documentation for C and D
class C
{
    int x;    /// documentation for C.x

    /** documentation for C.y and C.z */
    int y;
    int z;    /// ditto
}

/// ditto
class D
{
}
------------------------------------

<h3>Sections</h3>

$(P
The document comment is a series of $(I Section)s.
A $(I Section) is a name that is the first non-blank character on
a line immediately followed by a ':'. This name forms the section name.
The section name is not case sensitive.
)

<h4>Summary</h4>

$(P
The first section is the $(I Summary), and does not have a section name.
It is first paragraph, up to a blank line or a section name.
While the summary can be any length, try to keep it to one line.
The $(I Summary) section is optional.
)

<h4>Description</h4>

$(P
The next unnamed section is the $(I Description).
It consists of all the paragraphs following the $(I Summary) until
a section name is encountered or the end of the comment.
)

$(P
While the $(I Description) section is optional,
there cannot be a $(I Description) without a $(I Summary) section.
)

------------------------------------
/***********************************
 * Brief summary of what
 * myfunc does, forming the summary section.
 *
 * First paragraph of synopsis description.
 *
 * Second paragraph of
 * synopsis description.
 */

void myfunc() { }
------------------------------------

$(P
Named sections follow the $(I Summary) and $(I Description) unnamed sections.
)

<h3>Standard Sections</h3>

$(P
For consistency and predictability, there are several standard sections.
None of these are required to be present.
)

<dl>

<dt> $(B Authors:)
<dd> Lists the author(s) of the declaration.
------------------------------------
/**
 * Authors: Melvin D. Nerd, melvin@mailinator.com
 */
------------------------------------

<dt> $(B Bugs:)
<dd> Lists any known bugs.
------------------------------------
/**
 * Bugs: Doesn't work for negative values.
 */
------------------------------------

<dt> $(B Date:)
<dd> Specifies the date of the current revision. The date should be in a form
     parseable by std.date.

------------------------------------
/**
 * Date: March 14, 2003
 */
------------------------------------

<dt> $(B Deprecated:)
<dd> Provides an explanation for and corrective action to take if the associated
     declaration is marked as deprecated.

------------------------------------
/**
 * Deprecated: superseded by function bar().
 */

deprecated void foo() { ... }
------------------------------------

<dt> $(B Examples:)
<dd> Any usage examples
------------------------------------
/**
 * Examples:
 * --------------------
 * writefln("3"); // writes '3' to stdout
 * --------------------
 */
------------------------------------

<dt> $(B History:)
<dd> Revision history.
------------------------------------
/**
 * History:
 *	V1 is initial version
 *
 *	V2 added feature X
 */
------------------------------------

<dt> $(B License:)
<dd> Any license information for copyrighted code.
------------------------------------
/**
 * License: use freely for any purpose
 */

void bar() { ... }
------------------------------------

<dt> $(B Returns:)
<dd> Explains the return value of the function.
     If the function returns $(B void), don't redundantly document it.
------------------------------------
/**
 * Read the file.
 * Returns: The contents of the file.
 */

void[] readFile(char[] filename) { ... }
------------------------------------

<dt> $(B See_Also:)
<dd> List of other symbols and URL's to related items.
------------------------------------
/**
 * See_Also:
 *    foo, bar, http://www.digitalmars.com/d/phobos/index.html
 */
------------------------------------

<dt> $(B Standards:)
<dd> If this declaration is compliant with any particular standard,
the description of it goes here.
------------------------------------
/**
 * Standards: Conforms to DSPEC-1234
 */
------------------------------------

<dt> $(B Throws:)
<dd> Lists exceptions thrown and under what circumstances they are thrown.
------------------------------------
/**
 * Write the file.
 * Throws: WriteException on failure.
 */

void writeFile(char[] filename) { ... }
------------------------------------

<dt> $(B Version:)
<dd> Specifies the current version of the declaration.
------------------------------------
/**
 * Version: 1.6a
 */
------------------------------------
</dl>

<h3>Special Sections</h3>

$(P
Some sections have specialized meanings and syntax.
)

<dl>

<dt> $(B Copyright:)
<dd> This contains the copyright notice. The macro COPYRIGHT is set to
     the contents of the section when it documents the module declaration.
     The copyright section only gets this special treatment when it
     is for the module declaration.

------------------------------------
/** Copyright: Public Domain */

module foo;
------------------------------------

<dt> $(B Params:)
<dd> Function parameters can be documented by listing them in a params
     section. Each line that starts with an identifier followed by
     an '=' starts a new parameter description. A description can
     span multiple lines.

------------------------
/***********************************
 * foo does this.
 * Params:
 *	x =	is for this
 *		and not for that
 *	y =	is for that
 */

void foo(int x, int y)
{
}
-------------------------

<dt> $(B Macros:) </dt>
<dd> The macros section follows the same syntax as the $(B Params:) section.
     It's a series of $(I NAME)=$(I value) pairs.
     The $(I NAME) is the macro name, and $(I value) is the replacement
     text.
------------------------------------
/**
 * Macros:
 *	FOO =	now is the time for
 *		all good men
 *	BAR =	bar
 *	MAGENTA =   &lt;font color=magenta&gt;$0&lt;/font&gt;
 */
------------------------------------
</dl>

<h2>Highlighting</h2>

<h4>Embedded Comments</h4>

$(P
	The documentation comments can themselves be commented using
	the &#36;(DDOC_COMMENT comment text) syntax. These comments do not
	nest.
)

<h4>Embedded Code</h4>

$(P
	D code can be embedded using lines with at least three hyphens
	in them to delineate the code section:
)

------------------------------------
 /++++++++++++++++++++++++
  + Our function.
  + Example:
  + --------------------------
  +  import std.stdio;
  +
  +  void foo()
  +  {
  +	writefln("foo!");  /* print the string */
  +  }
  + --------------------------
  +/
------------------------------------

$(P
	Note that the documentation comment uses the $(D_COMMENT /++ ... +/)
	form
	so that $(D_COMMENT /* ... */) can be used inside the code section.
)

<h4>Embedded HTML</h4>

$(P
HTML can be embedded into the documentation comments, and it will
be passed through to the HTML output unchanged.
However, since it is not necessarily true that HTML will be the desired
output format of the embedded documentation comment extractor, it is
best to avoid using it where practical.
)

------------------------------------
/** Example of embedded HTML:
 *   $(OL 
 *      <li> <a href="http://www.digitalmars.com">Digital Mars</a> </li>
 *      <li> <a href="http://www.classicempire.com">Empire</a> </li>
 *   )
 */
------------------------------------

<h4>Emphasis</h4>

$(P
Identifiers in documentation comments that are function parameters or are
names that are in scope at the associated declaration are emphasized in
the output.
This emphasis can take the form of italics, boldface, a hyperlink, etc.
How it is emphasized depends on what it is - a function parameter, type,
D keyword, etc.
To prevent unintended emphasis of an identifier, it can be preceded by
an underscore (_). The underscore will be stripped from the output.
)

<h4>Character Entities</h4>

$(P
	Some characters have special meaning
	to the documentation processor, to avoid confusion it can be best
	to replace them with their corresponding character entities:
)

	$(TABLE1
	$(TR $(TH Character) $(TH Entity))
	$(TR $(TD &lt;  )$(TD &amp;lt; ))
	$(TR $(TD &gt;  )$(TD &amp;gt; ))
	$(TR $(TD &amp; )$(TD &amp;amp; ))
	)

$(P
	It is not necessary to do this inside a code section, or if the
	special character is not immediately followed by a # or a letter.
)

<h2>Macros</h2>

$(P
	The documentation comment processor includes a simple macro
	text preprocessor.
	When a &#36;($(I NAME)) appears
	in section text it is replaced with $(I NAME)'s corresponding
	replacement text.
	The replacement text is then recursively scanned for more macros.
	If a macro is recursively encountered, with no argument or with
	the same argument text as the enclosing macro, it is replaced
	with no text.
	Macro invocations that cut across replacement text boundaries are
	not expanded.
	If the macro name is undefined, the replacement text has no characters
	in it.
	If a &#36;(NAME) is desired to exist in the output without being
	macro expanded, the $ should be replaced with &amp;#36;.
)

$(P
	Macros can have arguments. Any text from the end of the identifier
	to the closing '$(RPAREN)' is the &#36;0 argument.
	A &#36;0 in the replacement text is
	replaced with the argument text.
	If there are commas in the argument text, &#36;1 will represent the
	argument text up to the first comma, &#36;2 from the first comma to
	the second comma, etc., up to &#36;9.
	&#36;+ represents the text from the first comma to the closing '$(RPAREN)'.
	The argument text can contain nested parentheses, "" or '' strings,
	<!-- ... --> comments, or tags.
	If stray, unnested parentheses are used, they can be replaced with
	the entity &amp;#40; for ( and &amp;#41; for ).
)

$(P
	Macro definitions come from the following sources,
	in the specified order:
)

	$(OL 
	$(LI Predefined macros.)
	$(LI Definitions from file specified by <a href="dcompiler.html#sc_ini">sc.ini</a>'s DDOCFILE setting.)
	$(LI Definitions from *.ddoc files specified on the command line.)
	$(LI Runtime definitions generated by Ddoc.)
	$(LI Definitions from any Macros: sections.)
	)

$(P
	Macro redefinitions replace previous definitions of the same name.
	This means that the sequence of macro definitions from the various
	sources forms a hierarchy.
)

$(P
	Macro names beginning with "D_" and "DDOC_" are reserved.
)

<h3>Predefined Macros</h3>

$(P
	These are hardwired into Ddoc, and represent the
	minimal definitions needed by Ddoc to format and highlight
	the presentation.
	The definitions are for simple HTML.
)

$(DDOCCODE
B =	&lt;b&gt;&#36;0&lt;/b&gt;
I =	&lt;i&gt;&#36;0&lt;/i&gt;
U =	&lt;u&gt;&#36;0&lt;/u&gt;
P =	&lt;p&gt;&#36;0&lt;/p&gt;
DL =	&lt;dl&gt;&#36;0&lt;/dl&gt;
DT =	&lt;dt&gt;&#36;0&lt;/dt&gt;
DD =	&lt;dd&gt;&#36;0&lt;/dd&gt;
TABLE =	&lt;table&gt;&#36;0&lt;/table&gt;
TR =	&lt;tr&gt;&#36;0&lt;/tr&gt;
TH =	&lt;th&gt;&#36;0&lt;/th&gt;
TD =	&lt;td&gt;&#36;0&lt;/td&gt;
OL =	&lt;ol&gt;&#36;0&lt;/ol&gt;
UL =	&lt;ul&gt;&#36;0&lt;/ul&gt;
LI =	&lt;li&gt;&#36;0&lt;/li&gt;
BIG =	&lt;big&gt;&#36;0&lt;/big&gt;
SMALL =	&lt;small&gt;&#36;0&lt;/small&gt;
BR =	&lt;br&gt;
LINK =	&lt;a href="&#36;0"&gt;&#36;0&lt;/a&gt;
LINK2 =	&lt;a href="&#36;1"&gt;&#36;+&lt;/a&gt;

RED =	&lt;font color=red&gt;&#36;0&lt;/font&gt;
BLUE =	&lt;font color=blue&gt;&#36;0&lt;/font&gt;
GREEN =	&lt;font color=green&gt;&#36;0&lt;/font&gt;
YELLOW =&lt;font color=yellow&gt;&#36;0&lt;/font&gt;
BLACK =	&lt;font color=black&gt;&#36;0&lt;/font&gt;
WHITE =	&lt;font color=white&gt;&#36;0&lt;/font&gt;

D_CODE = &lt;pre class="d_code"&gt;&#36;0&lt;/pre&gt;
D_COMMENT = &#36;(GREEN &#36;0)
D_STRING  = &#36;(RED &#36;0)
D_KEYWORD = &#36;(BLUE &#36;0)
D_PSYMBOL = &#36;(U &#36;0)
D_PARAM	  = &#36;(I &#36;0)

DDOC =	&lt;html&gt;&lt;head&gt;
	&lt;META http-equiv="content-type" content="text/html; charset=utf-8"&gt;
	&lt;title&gt;&#36;(TITLE)&lt;/title&gt;
	&lt;/head&gt;&lt;body&gt;
	&lt;h1&gt;&#36;(TITLE)&lt;/h1&gt;
	&#36;(BODY)
	&lt;/body&gt;&lt;/html&gt;

DDOC_COMMENT   = &lt;!-- &#36;0 --&gt;
DDOC_DECL      = &#36;(DT &#36;(BIG &#36;0))
DDOC_DECL_DD   = &#36;(DD &#36;0)
DDOC_DITTO     = &#36;(BR)&#36;0
DDOC_SECTIONS  = &#36;0
DDOC_SUMMARY   = &#36;0&#36;(BR)&#36;(BR)
DDOC_DESCRIPTION = &#36;0&#36;(BR)&#36;(BR)
DDOC_AUTHORS   = &#36;(B Authors:)&#36;(BR)
		&#36;0&#36;(BR)&#36;(BR)
DDOC_BUGS      = &#36;(RED BUGS:)&#36;(BR)
		&#36;0&#36;(BR)&#36;(BR)
DDOC_COPYRIGHT = &#36;(B Copyright:)&#36;(BR)
		&#36;0&#36;(BR)&#36;(BR)
DDOC_DATE      = &#36;(B Date:)&#36;(BR)
		&#36;0&#36;(BR)&#36;(BR)
DDOC_DEPRECATED = &#36;(RED Deprecated:)&#36;(BR)
		&#36;0&#36;(BR)&#36;(BR)
DDOC_EXAMPLES  = &#36;(B Examples:)&#36;(BR)
		&#36;0&#36;(BR)&#36;(BR)
DDOC_HISTORY   = &#36;(B History:)&#36;(BR)
		&#36;0&#36;(BR)&#36;(BR)
DDOC_LICENSE   = &#36;(B License:)&#36;(BR)
		&#36;0&#36;(BR)&#36;(BR)
DDOC_RETURNS   = &#36;(B Returns:)&#36;(BR)
		&#36;0&#36;(BR)&#36;(BR)
DDOC_SEE_ALSO  = &#36;(B See Also:)&#36;(BR)
		&#36;0&#36;(BR)&#36;(BR)
DDOC_STANDARDS = &#36;(B Standards:)&#36;(BR)
		&#36;0&#36;(BR)&#36;(BR)
DDOC_THROWS    = &#36;(B Throws:)&#36;(BR)
		&#36;0&#36;(BR)&#36;(BR)
DDOC_VERSION   = &#36;(B Version:)&#36;(BR)
		&#36;0&#36;(BR)&#36;(BR)
DDOC_SECTION_H = &#36;(B &#36;0)&#36;(BR)&#36;(BR)
DDOC_SECTION   = &#36;0&#36;(BR)&#36;(BR)
DDOC_MEMBERS   = &#36;(DL &#36;0)
DDOC_MODULE_MEMBERS   = &#36;(DDOC_MEMBERS &#36;0)
DDOC_CLASS_MEMBERS    = &#36;(DDOC_MEMBERS &#36;0)
DDOC_STRUCT_MEMBERS   = &#36;(DDOC_MEMBERS &#36;0)
DDOC_ENUM_MEMBERS     = &#36;(DDOC_MEMBERS &#36;0)
DDOC_TEMPLATE_MEMBERS = &#36;(DDOC_MEMBERS &#36;0)
DDOC_PARAMS    = &#36;(B Params:)&#36;(BR)\n&#36;(TABLE &#36;0)&#36;(BR)
DDOC_PARAM_ROW = &#36;(TR &#36;0)
DDOC_PARAM_ID  = &#36;(TD &#36;0)
DDOC_PARAM_DESC  = &#36;(TD &#36;0)
DDOC_BLANKLINE	= &#36;(BR)&#36;(BR)

DDOC_PSYMBOL	= &#36;(U &#36;0)
DDOC_KEYWORD	= &#36;(B &#36;0)
DDOC_PARAM	= &#36;(I &#36;0)
)

$(P
	Ddoc does not generate HTML code. It formats into the basic
	formatting macros, which (in their predefined form)
	are then expanded into HTML.
	If output other than HTML is desired, then these macros
	need to be redefined.
)

	$(TABLE1
	<caption>Basic Formatting Macros</caption>
	$(TR $(TD $(B B)) $(TD boldface the argument))
	$(TR $(TD $(B I)) $(TD italicize the argument))
	$(TR $(TD $(B U)) $(TD underline the argument))
	$(TR $(TD $(B P)) $(TD argument is a paragraph))
	$(TR $(TD $(B DL)) $(TD argument is a definition list))
	$(TR $(TD $(B DT)) $(TD argument is a definition in a definition list))
	$(TR $(TD $(B DD)) $(TD argument is a description of a definition))
	$(TR $(TD $(B TABLE)) $(TD argument is a table))
	$(TR $(TD $(B TR)) $(TD argument is a row in a table))
	$(TR $(TD $(B TH)) $(TD argument is a header entry in a row))
	$(TR $(TD $(B TD)) $(TD argument is a data entry in a row))
	$(TR $(TD $(B OL)) $(TD argument is an ordered list))
	$(TR $(TD $(B UL)) $(TD argument is an unordered list))
	$(TR $(TD $(B LI)) $(TD argument is an item in a list))
	$(TR $(TD $(B BIG)) $(TD argument is one font size bigger))
	$(TR $(TD $(B SMALL)) $(TD argument is one font size smaller))
	$(TR $(TD $(B BR)) $(TD start new line))
	$(TR $(TD $(B LINK)) $(TD generate clickable link on argument))
	$(TR $(TD $(B LINK2)) $(TD generate clickable link, first arg is address))
	$(TR $(TD $(B RED)) $(TD argument is set to be red))
	$(TR $(TD $(B BLUE)) $(TD argument is set to be blue))
	$(TR $(TD $(B GREEN)) $(TD argument is set to be green))
	$(TR $(TD $(B YELLOW)) $(TD argument is set to be yellow))
	$(TR $(TD $(B BLACK)) $(TD argument is set to be black))
	$(TR $(TD $(B WHITE)) $(TD argument is set to be white))
	$(TR $(TD $(B D_CODE)) $(TD argument is D code))
	$(TR $(TD $(B DDOC)) $(TD overall template for output))
	)

$(P
	$(B DDOC) is special in that it specifies the boilerplate into
	which the entire generated text is inserted (represented by the
	Ddoc generated macro $(B BODY)). For example, in order
	to use a style sheet, $(B DDOC) would be redefined as:
)

$(DDOCCODE
DDOC =	&lt;!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01//EN" "http://www.w3.org/TR/html4/strict.dtd"&gt;
	&lt;html&gt;&lt;head&gt;
	&lt;META http-equiv="content-type" content="text/html; charset=utf-8"&gt;
	&lt;title&gt;&#36;(TITLE)&lt;/title&gt;
	&lt;link rel="stylesheet" type="text/css" href="$(B style.css)"&gt;
	&lt;/head&gt;&lt;body&gt;
	&lt;h1&gt;&#36;(TITLE)&lt;/h1&gt;
	&#36;(BODY)
	&lt;/body&gt;&lt;/html&gt;
)

$(P
	$(B DDOC_COMMENT) is used to insert comments into the output
	file.
)

$(P
	Highlighting of D code is performed by the following macros:
)

	$(TABLE1
	<caption>D Code Formatting Macros</caption>
	$(TR $(TD $(B D_COMMENT)) $(TD Highlighting of comments))
	$(TR $(TD $(B D_STRING)) $(TD Highlighting of string literals))
	$(TR $(TD $(B D_KEYWORD)) $(TD Highlighting of D keywords))
	$(TR $(TD $(B D_PSYMBOL)) $(TD Highlighting of current declaration name))
	$(TR $(TD $(B D_PARAM)) $(TD Highlighting of current function declaration parameters))
	)

$(P
	The highlighting macros start with $(B DDOC_).
	They control the formatting of individual parts of the presentation.
)

	$(TABLE1
	<caption>Ddoc Section Formatting Macros</caption>
	$(TR $(TD $(B DDOC_DECL)) $(TD Highlighting of the declaration.))
	$(TR $(TD $(B DDOC_DECL_DD)) $(TD Highlighting of the description of a declaration.))
	$(TR $(TD $(B DDOC_DITTO)) $(TD Highlighting of ditto declarations.))
	$(TR $(TD $(B DDOC_SECTIONS)) $(TD Highlighting of all the sections.))
	$(TR $(TD $(B DDOC_SUMMARY)) $(TD Highlighting of the summary section.))
	$(TR $(TD $(B DDOC_DESCRIPTION)) $(TD Highlighting of the description section.))
	$(TR $(TD $(B DDOC_AUTHORS .. DDOC_VERSION)) $(TD Highlighting of the corresponding standard section.))
	$(TR $(TD $(B DDOC_SECTION_H)) $(TD Highlighting of the section name of a non-standard section.))
	$(TR $(TD $(B DDOC_SECTION)) $(TD Highlighting of the contents of a non-standard section.))
	$(TR $(TD $(B DDOC_MEMBERS)) $(TD Default highlighting of all the members of a class, struct, etc.))
	$(TR $(TD $(B DDOC_MODULE_MEMBERS)) $(TD Highlighting of all the members of a module.))
	$(TR $(TD $(B DDOC_CLASS_MEMBERS)) $(TD Highlighting of all the members of a class.))
	$(TR $(TD $(B DDOC_STRUCT_MEMBERS)) $(TD Highlighting of all the members of a struct.))
	$(TR $(TD $(B DDOC_ENUM_MEMBERS)) $(TD Highlighting of all the members of an enum.))
	$(TR $(TD $(B DDOC_TEMPLATE_MEMBERS)) $(TD Highlighting of all the members of a template.))
	$(TR $(TD $(B DDOC_PARAMS)) $(TD Highlighting of a function parameter section.))
	$(TR $(TD $(B DDOC_PARAM_ROW)) $(TD Highlighting of a name=value function parameter.))
	$(TR $(TD $(B DDOC_PARAM_ID)) $(TD Highlighting of the parameter name.))
	$(TR $(TD $(B DDOC_PARAM_DESC)) $(TD Highlighting of the parameter value.))
	$(TR $(TD $(B DDOC_PSYMBOL)) $(TD Highlighting of declaration name to which a particular section is referring.))
	$(TR $(TD $(B DDOC_KEYWORD)) $(TD Highlighting of D keywords.))
	$(TR $(TD $(B DDOC_PARAM)) $(TD Highlighting of function parameters.))
	$(TR $(TD $(B DDOC_BLANKLINE)) $(TD Inserts a blank line.))
	)

$(P
	For example, one could redefine $(B DDOC_SUMMARY):
)

$(DDOCCODE
DDOC_SUMMARY = &#36;(GREEN &#36;0)
)

$(P
	And all the summary sections will now be green.
)

<h3>Macro Definitions from <a href="dcompiler.html#sc_ini">sc.ini</a>'s DDOCFILE</h3>

$(P
	A text file of macro definitions can be created,
	and specified in <a href="dcompiler.html#sc_ini">sc.ini</a>:
)

$(DDOCCODE
DDOCFILE=myproject.ddoc
)

<h3>Macro Definitions from .ddoc Files on the Command Line</h3>

$(P
	File names on the DMD command line with the extension
	.ddoc are text files that are read and processed in order.
)

<h3>Macro Definitions Generated by Ddoc</h3>

	$(TABLE1
	$(TR
	$(TD $(B BODY))
	$(TD Set to the generated document text.)
	)
	$(TR
	$(TD $(B TITLE))
	$(TD Set to the module name.)
	)
	$(TR
	$(TD $(B DATETIME))
	$(TD Set to the current date and time.)
	)
	$(TR
	$(TD $(B YEAR))
	$(TD Set to the current year.)
	)
	$(TR
	$(TD $(B COPYRIGHT))
	$(TD Set to the contents of any $(B Copyright:) section that is part
	of the module comment.)
	)
	$(TR
	$(TD $(B DOCFILENAME))
	$(TD Set to the name of the generated output file.)
	)
	)

<h2>Using Ddoc for other Documentation</h2>

$(P
	Ddoc is primarily designed for use in producing documentation
	from embedded comments. It can also, however, be used for
	processing other general documentation.
	The reason for doing this would be to take advantage of the
	macro capability of Ddoc and the D code syntax highlighting
	capability.
)

$(P
	If the .d source file starts with the string "Ddoc" then it
	is treated as general purpose documentation, not as a D
	code source file. From immediately after the "Ddoc" string
	to the end of the file or any "Macros:" section forms
	the document. No automatic highlighting is done to that text,
	other than highlighting of D code embedded between lines
	delineated with --- lines. Only macro processing is done.
)

$(P
	Much of the D documentation itself is generated this way,
	including this page.
	Such documentation is marked at the bottom as being
	generated by Ddoc.
)

<h2>References</h2>

$(P
	$(LINK2 http://www.dsource.org/projects/helix/wiki/CandyDoc, CandyDoc)
	is a very nice example of how
	one can customize the Ddoc results with macros
	and style sheets.
)

)

Macros:
	TITLE=Documentation Generator
	WIKI=Ddoc
	RPAREN=)
