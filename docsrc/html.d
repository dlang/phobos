Ddoc

$(SPEC_S Embedding D in HTML,

	The D compiler is designed to be able to extract and compile D code
	embedded within HTML files. This capability means that D code can
	be written to be displayed within a browser utilizing the full formatting
	and display capability of HTML.
<p>
	For example, it is possible to make all uses of a class name actually be
	hyperlinks to where the class is defined. There's nothing new to learn for
	the person browsing the code, he just uses the normal features of an
	HTML browser. Strings can be displayed in <font color=green>green</font>,
	comments in <font color=red>red</font>, and
	keywords in $(B boldface), for one possibility. It is even possible
	to embed pictures in the code, as normal HTML image tags.
<p>
	Embedding D in HTML makes it possible to put the documentation for code and
	the code itself all together in one file. It is no longer necessary to
	relegate documentation in comments, to be extracted later by a tech writer.
	The code and the documentation for it can be maintained simultaneously,
	with no duplication of effort.
<p>
	How it works is straightforward. If the source file to the compiler ends
	in .htm or .html, the code is assumed to be embedded in HTML. The source
	is then preprocessed by stripping all text outside of &lt;code&gt; and
	&lt;/code&gt; tags. Then, all other HTML tags are stripped, and embedded
	character encodings are converted to ASCII.
	The processing does not attempt to diagnose errors in the HTML itself.
	All newlines in the original
	HTML remain in their corresponding positions in the preprocessed text,
	so the debug line numbers remain consistent. The resulting text is then
	fed to the D compiler.
<p>
	Here's an example of the D program "hello world" embedded in
	this very HTML file. This file can be compiled and run.

<pre>
<code>
import std.stdio;

int <font size=+1>$(B main)</font>()
{
&nbsp;$(RED writefln)(<u>&quot;hello world&quot;</u>);
&nbsp;return 0;
}
</code>
</pre>

)

Macros:
	TITLE=Embedding D in HTML
	WIKI=HTML
META_KEYWORDS=D Programming Language, html
META_DESCRIPTION=Extracting D code from HTML files.

