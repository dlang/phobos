Ddoc

$(D_S D Programming Language News,

Here is the D blog of things of general interest to D enthusiasts.
Most of these appeared originally in the D newsgroup at
<a href="http://www.digitalmars.com/NewsGroup.html">news.digitalmars.com</a>.

<hr><h4><a href="http://www.ddj.com/articles/2005/0501/">Jan 2005 issue</a> of <a href="http://www.ddj.com/">Dr. Dobb's</a>:</h4>

	"printf Revisited"
	by Walter Bright

<hr><h4>6/30/04 Sam McCall <a href="http://www.digitalmars.com/drn-bin/wwwnews?digitalmars.D/5077">writes</a>:</h4>

	Okay, I got sick of dealing with UTF-8 :-$(RPAREN)
	I've got a proof-of-concept of a class-based String with a bunch of 
	operations. All data manipulation is character-based, you manipulate 
	unicode codepoints (characters) and don't worry about encodings.
	It's fairly slow at the moment, the proof-of-concept version stores 
	strings internally as dchar arrays, and it hasn't been optimised. 
	Barring any killer bugs, it should be usable anywhere that string 
	performance isn't a bottleneck.
	It's probably only useful to you if you're not entirely happy with d's 
	strings and/or arrays.
	I plan to do some optimisations and write a backend that uses UTF-8 
	(internally only), which should be faster (I hope).
	Interaction with libraries should be easy, char[]/wchar[]/dchar[] to 
	String is just String(data) (or String.valueOf(data)), String to the 
	array form is s.toUTF8/16/32().
	I'll write up a pretty-looking example sometime that isn't 3am ;-$(RPAREN)
	<p>

	A simple reference is here:
	<a href="http://tunah.net/~tunah/d-string/doc.txt">
	http://tunah.net/~tunah/d-string/doc.txt</a><br>
	And the code is here:
	<a href="http://tunah.net/~tunah/d-string/string.d">
	http://tunah.net/~tunah/d-string/string.d</a>
	<p>

	If you try it, let me know what you think or any suggestions you have.<br>
	Sam

<hr><h4><a href="http://www.slashdot.org">Slashdot</a></h4>

	<a href="http://developers.slashdot.org/developers/04/04/19/1124204.shtml?tid=108&tid=126&tid=156">
	C, Objective-C, C++... D! Future Or failure?</a>

<hr><h4><a href="http://www.osnews.com">OS News</a> 2004-04-19</h4>

	<a href="http://www.osnews.com/story.php?news_id=6761">A, B, C, ... D! The Programming Language</a>
	by Owen Anderson

<hr><h4>4/8/04 Deja Augustine <a href="http://www.digitalmars.com/drn-bin/wwwnews?D/27267">writes</a>:</h4>

	Well, I've managed to port over 90% of the Python/C API to D so now you
	can extend or embed python using D (the other 10% are threads, some
	unicode stuff and several macros, but those'll be put in shortly).
	<p>

	Check it out at
	<a href="http://www.scratch-ware.net/D/">
	http://www.scratch-ware.net/D/</a>


<hr><h4>May 2004 issue of C/C++ User's Journal</h4>

	"Nested Functions" by Walter Bright, pg. 36

<hr><h4>3/22/04 David Friedman <a href="http://www.digitalmars.com/drn-bin/wwwnews?D.gnu/518">writes</a>:</h4>

	Hi All!
	<p>

	A few months ago, I started working on a D front end for GCC.  I didn't 
	want to make any announcements until I was sure it was feasible.  Well,
	I finally got it working.  This first release is almost a complete 
	implementation -- the only major features missing are inline assembler 
	and volatile statements.  Supported systems are x86 Linux and MacOS X 
	with gcc 3.3 and 3.4.
	<p>

	You can download the files here:
	<p>

	<a href="http://home.earthlink.net/~dvdfrdmn/d">
	http://home.earthlink.net/~dvdfrdmn/d</a>
	<p>

	I'll post more about the implementation soon.
	<p>

	Enjoy!
	<p>

	David Friedman


<hr>
	Walter Bright's SDWest 2004
	<a href="http://www.digitalmars.com/d/sdwest/index.html" target="_top">
	presentation on D</a>.

<hr><h4>Mar 2004 issue of C/C++ User's Journal</h4>

	"Positive Integration: D and Java" by Matthew Wilson, pg. 48

<hr><h4><a href="http://www.ddj.com/articles/2004/0403/">Mar 2004 issue</a> of <a href="http://www.ddj.com/">Dr. Dobb's</a>:</h4>

	"Collection Enumeration: Loops, Iterators, & Nested Functions"
	by Matthew Wilson and Walter Bright

<hr><h4>1/9/04 yaneurao <a href="http://www.digitalmars.com/drn-bin/wwwnews?D/21501">writes</a>:</h4>

glExcess is a famous visual demo used openGL.

	glExcess:<br>
	<a href="http://www.glexcess.com/">http://www.glexcess.com/</a>
	<p>

	I've ported glExcess into D.<br>
	<a href="http://yaneurao.zive.net/yaneSDK4D/glexcess002.zip">http://yaneurao.zive.net/yaneSDK4D/glexcess002.zip</a>
	<p>

	The latest version of 'glExcess into D' can download here:<br>
	<a href="http://www.sun-inet.or.jp/~yaneurao/dlang/english.html">http://www.sun-inet.or.jp/~yaneurao/dlang/english.html</a><br>
	(including source , opengl.d , glu.d , glut.d etc..)
	<p>

	yaneurao.


<hr><h4>1/9/04 J C Calvarese <a href="http://www.digitalmars.com/drn-bin/wwwnews?D/21497">writes</a>:</h4>

	I've created a Yahoo! group called "D Lab" for discussing the dig
	library (and hopefully other projects, too).
	<p>

	<a href="http://groups.yahoo.com/group/d_lab">http://groups.yahoo.com/group/d_lab</a>
	<p>

	You can read messages without joining.  You have to join to post a
	message (I think there will be very little spam that way).
	<p>

	I've posted an updated version of dig that compiles with DMD 0.77.  If 
	you have suggestions for improvements, you can join and post messages 
	and upload files.
	<p>

	If you want a place to upload some D source files, projects, etc. 
	without the bother of creating a webpage, please feel free. (I'd prefer 
	the material to be D-related, but it certainly doesn't have to be 
	dig-related.)
	<p>

	--<br>
	Justin<br>
	<a href="http://jcc_7.tripod.com/d/">http://jcc_7.tripod.com/d/</a>

<hr><h4>1/3/04 Hauke Duden <a href="http://www.digitalmars.com/drn-bin/wwwnews?D/21032">writes</a>:</h4>

	Yaneurao (another D-fan from Japan) was kind enough to put a ZIP file on 
	his web site that contains the Doxygen and dfilter binaries, as well as 
	the dfilter source code.
	<p>

	Here's a link:
	<p>

	<a href="http://www.sun-inet.or.jp/~yaneurao/dlang/lib/ddoc.zip">
	http://www.sun-inet.or.jp/~yaneurao/dlang/lib/ddoc.zip</a>
	<p>

	Hauke

<hr><h4>12/29/03 John Reimer <a href="http://www.digitalmars.com/drn-bin/wwwnews?D/20879">writes</a>:</h4>

	&gt;Would it be possible to write a OS / Kernel using D? I'm justing thinking<br>
	&gt;about how to bootstrap this... does anybody has some ideas?<br>
	&gt;<br>
	&gt;--<br>
	&gt;Robert M. Muench<br>
	&gt;Management & IT Freelancer<br>
	&gt;http://www.robertmuench.de
	<p>

	Several weeks ago, I posted a link to one D based kernel I came across.  I don't
	believe it's on Digitalmars D language Links page so it's not easy to come
	across.  You have to search through the volumes of posts in this newsgroup to
	find it.
	<p>

	here it is:
	<p>

	<a href="http://www.geocities.com/one_mad_alien/dkernel.html">
	http://www.geocities.com/one_mad_alien/dkernel.html</a>
	<p>

	I haven't actually looked too much into this one, but the author seems to have a
	good base for an OS going (written using mostly D).
	<p>

	I think it would be great to have an OS with integrated garbage collection.  And
	D would be a great language to program it in.
	<p>

	Later,
	<p>

	John


<hr><h4>11/4/03 Matthew Wilson <a href="http://www.digitalmars.com/drn-bin/wwwnews?D/18911">writes</a>:</h4>

	"Ben Hinkle" <bhinkle4@juno.com> wrote:<br>
	&gt; I seem to remember someone saying they were working on getting doxygen to<br>
	&gt; work with D files. What's the status on that? I can't find the posts. I'd<br>
	&gt; love to be able to extract some doc from my code - I keep bumping up against<br>
	&gt; my own poor memory and having to sift through code.<br>
	&gt; thanks,<br>
	&gt; -Ben<br>
	<p>

	I've been doing it for ages. It's pretty straightforward.
	<p>

	The only thing is that it needs a filter - one slightly improved from
	Burton's original - used for the INPUT_FILTER, which I've attached.
	<p>
	Other than that, it's just like using it for C/C++

<hr><h4>Nov 2003 issue of <a href="http://www.cuj.com/">C/C++ User's Journal</a>:</h4>

	Matthew Wilson in the article "Introducing recls" writes about
	implementing recls in $(B D).

<hr><h4>10/10/03 Andy Friesen <a href="http://www.digitalmars.com/drn-bin/wwwnews?D/18200">writes</a>:</h4>

	Matthew Wilson wrote:<br>
	&gt; Have you any tips on how to get syntax highlighting working?<br>
	&gt; <br>
	&gt; I've copied the C/C++ settings to a D key under<br>
	&gt; HKCU\Software\Microsoft\Visual Studio\7.0\Text Editor but that's had no<br>
	&gt; effect. :(<br>
	<p>

	Add a key '.d' to 
	HKLM/Software/Microsoft/VisualStudio/7.x/Languages/File Extensions and 
	copy the value from .c into it.  That'll make VS treat D as if it were C++.
	<p>

	To add user keywords, create a file called UserType.dat and put it in 
	the same directory as msdev.exe.  You can set the colour for the 
	keywords in this file in the 'User Defined Keywords' subsection of the 
	syntax highlighting settings.


<hr><h4>Oct 2003 issue of <a href="http://www.cuj.com/">C/C++ User's Journal</a>:</h4>

	Matthew Wilson in the article
	"Identity and Equality: Syntax and Semantics"
	compares D's design of these operations vs other languages.

<hr><h4>9/30/03 Andrew Edwards <a href="http://www.digitalmars.com/drn-bin/wwwnews?D/17878">writes</a>:</h4>

Gentlemen, (Are there any ladies here?)

	I've successfully compiled the Mersenne Twister RNG in D.  In it's current
	state, it is simply a C program modified to compile in D. I would like to
	make it a true "D" program and would appreciate some suggestions on how to
	improve upon it! As pointed out by the original authors
	(<a href="http://www.math.keio.ac.jp/matumoto/emt.html">
	http://www.math.keio.ac.jp/matumoto/emt.html</a>),
	MT is "NOT SECURE for
	CRYPTOGRAPHY", I would like to remedy this situation and eventually provide
	an OO version of the RNG.
	<p>

	All guidance and suggestions will be greatly appreciated.
	Code is attached.

<hr><h4>9/19/03 Andy Friesen <a href="http://www.digitalmars.com/drn-bin/wwwnews?D/17402">writes</a>:</h4>

	D's shiny new opCall overload gave me a chance to improve the interface 
	of my printf-workalike.

-----------
import formatter;

/*
  * the trailing () is needed to convert the formatter object to a
  * string, since implicit conversions are not possible
  */
char[] result = format("{0} + {1} = {2}") (5) (2) ("Spam") ();
-----------

	You can grab it at
	<a href="http://ikagames.com/andy/d/console-19-sep-2003.zip">http://ikagames.com/andy/d/console-19-sep-2003.zip</a>

<hr><h4>9/18/03 Benji Smith <a href="http://www.digitalmars.com/drn-bin/wwwnews?D/17274">writes</a>:</h4>

	Holy cow. I just downloaded the SWIG sources and I've been looking around at
	what it would take to write a SWIG extension for D. And this is the answer:
	<p>

	NOT VERY MUCH
	<p>

	In order to customize SWIG for any given language, there is only one source file
	that needs to be created. For Java, it's a file called "java.cxx" for C#, it's a
	file called "csharp.cxx". Each of these files is moderately complex. The java
	file, with all of the comments and newlines stripped out, is about 1400 lines of
	code (in C++). The csharp file is about 1600 lines.
	<p>

	That's not very much code.
	<p>

	Plus, I'm guessing that much of the code for the D extension would look an awful
	lot like the code for the Java and C# extensions, so we could borrow heavily
	from the existing implementation.
	<p>

	However, this project is not for the faint of heart. Even if it only requires
	writing 1500 or so lines of code, the author will have to have a pretty good
	command of C++ (I'm already out of the running) and an excellent understanding
	of D semantics (that eliminately most of us).
	<p>

	But, on the upside, once it's done we'll have access to millions of lines of C++
	code to use as imports and libraries for our own projects. I'm just giddy at the
	notion that we could suddenly have access to the entire wxWindows library, after
	writing only 1500 lines of code.


<hr><h4>9/18/03 Benji Smith <a href="http://www.digitalmars.com/drn-bin/wwwnews?D/17256">writes</a>:</h4>

	In article <bkcbf8$2r06$1@digitaldaemon.com>, Andy Friesen says...<br>
	&gt;wxWindows uses SWIG to generate all those other language bindings.  It<br>
	&gt;would probably be worthwhile to look into getting SWIG to make D<br>
	&gt;bindings as well.
	<p>

	I've just spent the last 20 minutes or so reading up about swig (
	<a href="http://www.swig.org">http://www.swig.org</a> ) and I'm impressed. Since there are already language
	bindings connecting C/C++ to Java, C#, Perl, Python, PHP, OCaml (and a few other
	languages), it shouldn't be too difficult to use those implementations as a
	reference for creating a D SWIG extension.
	<p>

	In my opinion, this is the most important project for D in the upcoming year.
	Because if we can assemble a general purpose method for creating bindings
	between C++ and D, we'll open up access to lots of existing libraries that we
	can't use now.
	<p>

	As soon as I've got the repository site up and running, this is one of the
	projects I'g going to create.

<hr><h4>9/16/03 Matthew Wilson <a href="http://www.digitalmars.com/drn-bin/wwwnews?D/17087">writes</a>:</h4>

	The SynSoft.D libraries 1.2 are now available from
	<a href="http://synsoft.org/d.html">
	http://synsoft.org/d.html</a>
	<p>

	There are several new small housekeeping modules, along with the
	synsoft.win32.reg module that does registry stuff.
	<p>

	I've also changed the names of several methods in previous modules (I've
	decided to standardise on ThisKindOfMethodName, rather than
	this_kind_of_method_name()), but because of a linker weirdness  - it
	wouldn't link when there were start() and Start() methods in the same
	class - the deprecated functions with the old names have had to be removed.
	Apologies if this causes problems. ;/
	<p>

	The registry library, like the other ones, is a header-only from a
	source-perspective (i.e. the method bodies are stripped). This is not
	because I'm being precious, just that I only want any attention you may give
	on the module's API, not the implementation. Once this module is matured, it
	may be going into Phobos, at which point, obviously, all source will be
	available.
	<p>

	Note that the reg module only does enumeration for the moment. I've not yet
	decided on the format for adding/deleting keys/values, and am happy to hear
	some suggestions from anyone.
	<p>

	Alas, there are still no test programs, but I'm including my test program
	for the registry module here. Version 1.3 of the libraries will have test
	and sample progs, I promise.
	<p>

	(I've got to toddle off and do some other things - deadlines, deadlines -
	but I'll be keeping an eye on the ng, and will try to respond to
	feedback/questions/abuse. ;) )
	<p>

	Enjoy!


<hr><h4>9/13/03 Carlos Santander <a href="http://www.digitalmars.com/drn-bin/wwwnews?D/16958">writes</a>:</h4>

	If you are interested in the very first prototype (note it's not even
	pre-pre-pre-pre-alpha ;$(RPAREN) $(RPAREN) of a rad tool for DMD, go to
	<a href="http://earth.prohosting.com/carlos3/">
	http://earth.prohosting.com/carlos3/</a>,
	under the Designer section. I really
	want suggestions, ideas, etc., especially about the way it's designed.
	Right now, it just adds buttons and lets you change the caption of both
	buttons and the frame, and the size of the frame (something happens with the
	size of the button), but if I'm doing something wrong I'd like to know it
	soon.


<hr><h4>9/10/03 Carlos Santander <a href="http://www.digitalmars.com/drn-bin/wwwnews?D/16796">writes</a>:</h4>

	If you happen to know someone who speaks spanish and would like to know
	something about D, tell them to go to
	<a href="http://earth.prohosting.com/carlos3/">
	http://earth.prohosting.com/carlos3/</a>.

<hr><h4>9/9/03 Ant <a href="http://www.digitalmars.com/drn-bin/wwwnews?D/16720">writes</a>:</h4>

	DUI is now listed on the GtkGLExt page.
	<p>
	GtkGLExt<br>
	<a href="http://gtkglext.sourceforge.net/">
	http://gtkglext.sourceforge.net/</a>
	<p>
	(I need to put a big digital mars logo on DUI home page,
	maybe a D logo...)
	<p>
	DUI<br>
	<a href="http://ca.geocities.com/duitoolkit/">
	http://ca.geocities.com/duitoolkit/</a>

<hr><h4>9/6/03 Simon J Mackenzie <a href="http://www.digitalmars.com/drn-bin/wwwnews?D/16594">writes</a>:</h4>

	Hi guys,<br>
	I've updated d.xml for Kate D Syntax Highlighting to support D 0.71.
	The update is available at
	<a href="http://users.tpg.com.au/smackoz/projects/d/d.0.03.tar.bz2">
	http://users.tpg.com.au/smackoz/projects/d/d.0.03.tar.bz2</a>


<hr><h4>9/4/03 Kazuhiro Inaba writes:</h4>

	I translated the reference document for D to Japanese:
	<a href="http://www.kmonos.net/alang/d/">
	http://www.kmonos.net/alang/d/</a>
	to make the D language more popular among all programmers in japan. :)
	<p>

	A few pages ( D String/Complex/DbC vs C++'s ) are not done yet,
	but i'll finish them soon.


<hr><h4>8/25/03 Ben Hinkle <a href="http://www.digitalmars.com/drn-bin/wwwnews?D/16152">writes</a>:</h4>

	I've put a first cut at an emacs mode for D in the uploads section of
	<p>
	<a href="http://dlanguage.netunify.com/38">
	http://dlanguage.netunify.com/38</a>
	<p>
	The basic support is for most of the syntax and keywords and font-lock for
	highlighting. Some D-specific constructs aren't supported like nested
	comments (I've been wrestling with cc-engine.el to figure out how cc-mode
	parses comments -ugh!), but in general I've found it does a reasonable job
	with most of the sample files and phobos.
	<p>
	Hopefully I'm not sucking up too much of the upload space. If I am I'll find
	another spot to park it. I also added an entry to that wiki for emacs. I've
	only tried it on Windows but I don't imagine linux emacs would have any
	problem.
	<p>
	enjoy,<br>
	-Ben Hinkle

<hr><h4>8/25/03 Helmut Leitner <a href="http://www.digitalmars.com/drn-bin/wwwnews?D/16123">writes</a>:</h4>

	You may have noticed, that I changed a few things on Wiki4D:
	<p>
	- The link bar now contains Index and Folder links.
	<p>
	- I changed "Members" and "FolderMembers" to "Contributors"
	  and "FolderContributors" which seems more approriate.
	<p>
	I may be a bit disappointing for some that Wikis grow slowly
	but in fact a Wiki is an invitation to join in for common writing
	and not the presentation of a sparkling and ready "product".
	<p>
	Some pages slowly begin to show shape, like e.g.:
	   <a href="http://www.prowiki.org/wiki4d/wiki.cgi?FaqRoadmap">
	   http://www.prowiki.org/wiki4d/wiki.cgi?FaqRoadmap</a>
	<p>
	Things that would be needed but havn't yet evolved:
	<p>
	   - a page for ongoing projects (although there is an incomplete
	     list on the FrontPage)
	<p>
	   - a page for wanted projects, although there is
	     <a href="http://www.prowiki.org/wiki4d/wiki.cgi?SuggestedProjects">
	     http://www.prowiki.org/wiki4d/wiki.cgi?SuggestedProjects</a>
	<p>
	   - a page for library design considerations and standards
	<p>
	Please take the Wiki as a public space that you are a co-owner of.
 


<hr><h4>8/13/03 Jussi Jumppanen adds D support to Zeus:</h4>

	The latest version of
	<a href="http://www.zeusedit.com">Zeus for Windows</a> is finally out.
	This release comes with D compiler (*) and keywords predefined and it
	also has a ctags program (xtags.exe) that supports the D language.
	(*) For the D compiler to work within Zeus the user will need 
	to download and install the compiler from www.digitalmars.com/d/. If 
	it is already installed it should be automatic.


<hr><h4>8/10/03 Ant <a href="http://www.digitalmars.com/drn-bin/wwwnews?D/15425">writes</a>:</h4>

Well, there you have it, it's the first and second DUI releases!
<p>
home page (temporary I hope):
<p>

<a href="http://ca.geocities.com/duitoolkit/index.html">
http://ca.geocities.com/duitoolkit/index.html</a>.
<p>

download page:
<p>

<a href="http://ca.geocities.com/duitoolkit/downloadPage.html">
http://ca.geocities.com/duitoolkit/downloadPage.html</a>
<p>

Some notes:
<p>

This is a very early alpha release to let interested people
look at the options an directions DUI is taking.
Comments and suggestions are welcome, if you are interested
in using DUI this is the time to influence it's devel.
<p>

This is Linux only
(other Un*x flavors might be easy to use)
<p>

My Makefiles knowleadge is limited so probably
you have to change the Makefile to suit your environment


<hr><h4>8/10/03 Mike Wynn <a href="http://www.digitalmars.com/drn-bin/wwwnews?D/15360">writes</a>:</h4>

Sean Palmer has kindly send me his Direct3D code. which I've put online for
all to use at
<a href="http://www.geocities.com/one_mad_alien/dcom_not_dcom.html">
http://www.geocities.com/one_mad_alien/dcom_not_dcom.html</a>
<p>

I see from microsofts site that a Quake2 in C#  have just released (source
and all) anyone fancy porting it to D ?


<hr><h4>8/7/03 Simon J Mackenzie <a href="http://www.digitalmars.com/drn-bin/wwwnews?D/15153">writes</a>:</h4>

Hi Guys,
<p>
D syntax highlighting is to be incorporated with KDE as part of the Kate 
editor in the future.

<hr><h4>7/30/03 Charles Sanders <a href="http://www.digitalmars.com/drn-bin/wwwnews?D/14795">writes</a>:</h4>

Hey all, lots of changes to DIDE its getting close to useable now.  Its at a
new site at
<p>
<a href="http://www.atari-soldiers.com">www.atari-soldiers.com</a>
<p>
Im planning on adding code browser soon (thanks to keith's great idea of
CTAGS! ), and then a dialog editor.
<p>
I'm waiting on approval from sourceforge for DublN (CPAN like tool ), but
they are taking a suspiciously long time to respond.  I would host it but my
hosting company doesnt offer mysql, does anyone have any room somewhere so
we can get started on this ?
<p>
I noticed a link called D journal on the DM page, I have room to host it if
someone wants to write it ?
<p>
Charles


<hr><h4>7/30/03 Burton Radons <a href="http://www.digitalmars.com/drn-bin/wwwnews?D/14780">writes</a>:</h4>

Frank Wills wrote:<br>
&gt; Vathix wrote:<br>
&gt;&gt; I need a database, I'm sure others will too. Does anyone know of one that<br>
&gt;&gt; could be easily used in D? I need it to be efficient and able to be fairly<br>
&gt;&gt; large. I attempted to write my own, it failed. I got sick of my data<br>
&gt;&gt; corrupting. I did learn from it, though.<br>
&gt;&gt;<br>
&gt;&gt; If there are no existing databases for use with D, I'll try writing my  own<br>
&gt;&gt; again that anyone could use freely, but I'd like some tips and ideas for it.<br>
&gt;&gt; What kind of interface would be best for it, etc.<br>
&gt;&gt;<br>
&gt; You might take a look at <a href="http://www.sqlite.org">www.sqlite.org</a> It's an embeddable sql database<br>
&gt; engine that I have used with C++, but have not yet figured out how to<br>
&gt; use it directly with D. It may need an intermediate library in C.<br>
<p>

That's a nice little library.  The last one I tried to work with was 
Berkeley's in Python, and that soured me so bad on small database 
libraries (the format wasn't portable between Windows and Linux!) that I 
didn't think there could be a useful one.
<p>
So I'm working on a wrapper for SQLite that uses the DLL and supplies a 
class, including little niceties like buffered table modifications.  A 
beta should be done in a couple of hours.
<p>
I've attached the <a href="http://www.digitalmars.com/drn-bin/wwwnews?D/14780">import library and import headers</a> for them.  You'll 
need the DLL from the SQLite site.  This should also work on the Linux 
side using the .so.


<hr><h4>7/30/03 Jon Frechette <a href="http://www.digitalmars.com/drn-bin/wwwnews?D/14716">writes</a>:</h4>

Hi folks,
<p>
I've just started trying to learn the D language and I really like it so
far. It seems that the example code included with the compiler is pretty
short on language features and uses no OOP at all. So, I created another
version of the wordcount program that uses every D feature I could learn.
<p>
I have <a href="http://www.digitalmars.com/drn-bin/wwwnews?D/14718">attached</a> the source code in case it might be of some value to
Walter's effort.
<p>
Ps:  I may have recreated the wheel in places, so any comments would be
welcomed by this newbie.
<p>
Thanks



<hr><h4>7/29/03 Simon J Mackenzie writes:</h4>

Walter,<br>
can you please provide an updated list of key words (reserved 
identifiers) and I'll update d.xml to reflect the changes.
<p>
Here's a <a href="http://www.digitalmars.com/drn-bin/wwwnews?D/14713">1st cut</a>
at systax highlighting for the KDE Advance Text Editor.
<p>
d.xml needs to be placed in $HOME/.kde/share/apps/katepart/syntax
<p>
Simon


<hr><h4>7/27/03 Marten Ask writes:</h4>

Hello,
<p>
I've written a very basic cgi module. It parses headers, querystrings and
forms as well as getting and settings cookies. It needs lots of more work,
but is quite useful already. Anyway, I've tested it a little and was hoping
that others might test it aswell so I can add useful stuff. I've only used
PHP before and all this strong typing really hurts my brain! :-$(RPAREN) So I could
use some help..
<p>
Anyway, I'll send the
<a href="http://www.digitalmars.com/drn-bin/wwwnews?D/14633">module</a>
along and here's a small test program I wrote:

-----------
import cgi;

void main()
{
 Request req = new Request();
 Response res = new Response();

 if(req.serverVariable("REQUEST_METHOD") == "POST")
 {
  char[] name = req.formString("name"); // returns formfield value as string
  char[] comment = req.formString("comment");
  res.cookie("name", name, "", "", "", 0);
  res.write("&lt;html>\n&lt;head>\n&lt;title>CGI-test&lt;/title>\n&lt;/head>\n");
  res.write("&lt;body>\n");
  res.write("Hello &lt;b>"~name~"&lt;/b>&lt;p>\n");
  res.write("You wrote:\n");
  res.write("&lt;blockquote>&lt;b>\""~comment~"\"&lt;/b>&lt;/blockquote>\n");
  res.write("&lt;a href='cgitest.exe'>Back to form&lt;/a>");
  res.write("&lt;/body>&lt;/html>");
  res.flush();
 }
 else
 {
  char[] cookie;
  try
  {
   cookie = req.cookie("name");
  }
  catch(CGIError) // cookie wasn't set!
  {
   cookie = "";
  }

  printf(res.getHeaders()~"\n\n");
  printf("&lt;html>\n&lt;head>\n&lt;title>CGI-test&lt;/title>\n&lt;/head>\n");
  printf("&lt;body>\n");
  printf("&lt;form method='post' action='cgitest.exe'>\n");
  printf("Name: &lt;input type='text' name='name' value='%.*s'>&lt;br>\n",cookie);
  printf("Comment: &lt;input type='text' name='comment'>&lt;br>\n");
  printf("&lt;input type='submit' value='Send!'>\n");
  printf("&lt;/form>&lt;/body>&lt;/html");
 }
}
-----------

<hr><h4>7/24/03 Burton Radons <a href="http://www.digitalmars.com/drn-bin/wwwnews?D/14520">writes</a>:</h4>

    Terry Bayne wrote:<br>
    &gt; Just to avoid confusion, by "singleton" I mean an object of which only one <br>
    &gt; instance can be instanciated, and any subsequent attempts to create an <br>
    &gt; instance of the object return a reference to the first one created.<br>
    <p>

    Not through direct syntax.  You can synthesize one using a static member 
    and function.  You can also force memory recycling:

-----------
class Singleton
{
    static Singleton singleton;

    new (uint size)
    {
	if (singleton === null)
	{
	    singleton = (Singleton) new void * [(size + 3) / 4];
	    singleton.init ();
	}
	return singleton;
    }

    /* This is used instead of a constructor to avoid having the 
       constructor called multiple times. */
    void init ()
    {
	/* Prepare the singleton. */
    }
}

Singleton a = new Singleton (); /* Create the new singleton. */
Singleton b = new Singleton (); /* Recycle the old singleton. */
-----------

    Unfortunately one can't create a Singleton base class that would have 
    the inherited property, because "new" isn't passed the ClassInfo.
    <p>

    One might ask what I'm doing using "new void * [size / 4]" instead of 
    "new ubyte [size]".  Once the GC is type-aware, casting between an array 
    of values and an object reference will result in any pointers in the 
    object being collected.  I think I've advocated putting in casting 
    limitations to prevent the problem before, but in any case I am now; you 
    should not be able to cast between a value array and a pointer.


<hr><h4>7/18/03 Simon J Mackenzie <a href="http://www.digitalmars.com/drn-bin/wwwnews?D/14437">writes</a>:</h4>

Updated - Added README, D Icons and added x-dsrc.desktop for KDE D file 
extension support.
<p>

Link is now
<a href="http://users.tpg.com.au/smackoz/projects/d/d_kde_support.tar.bz2">
http://users.tpg.com.au/smackoz/projects/d/d_kde_support.tar.bz2</a>
<p>

Simon J Mackenzie wrote:<br>
&gt; I've created some Linux mime type images for D.  You can download the <br>
&gt; tar.bz2 files with all requred images, 16x16, 22x22, 32x32, 48x48, <br>
&gt; 64x64, 128x128 from <a href="http://users.tpg.com.au/smackoz/">http://users.tpg.com.au/smackoz/</a><br>
&gt; <br>
&gt; Use the dmd.png image to impove the appearance of your folder image for <br>
&gt; DMD (works with KDE, ??other desktops??).<br>
&gt; <br>
&gt; Simon<br>
&gt; 


<hr><h4>7/8/03 Burton Radons writes:</h4>

Andrew Edwards wrote:
<p>

&gt; Is it possible to download a file from the internet through a D program?<br>
&gt; Where might I find instructions on how to do such a thing?
<p>

I put up a library for doing this back in March.  Here's a copy of the 
release notes:
<p>

I've put up a simple URL loading library at 
(http://www.opend.org/urllib.zip).  It requires dig to be installed, 
although it doesn't use it, just digc.  Comes with the documentation. It 
has the functions:
<p>

urlopen: Open a URL as a stream (http, file, ftp, nntp, and dict schema 
supported).<br>
urlread: Open a URL and read its contents.<br>
urllistdir: List a directory, return an array of URLStat (file and ftp 
schema supported).<br>
urlencode, urldecode: Encode and decode the URL.  The above functions 
expect a decoded URL.
<p>

There's also a small, simple, not-thought-out sockets library.


<hr><h4>6/27/03 Vathix writes:</h4>

I have a dedicated IRC network up and running, which will be perfect for D
projects and discussion in real-time.
You're all welcome to connect irc.dprogramming.com or d-irc.vathix.com and
you'll probably want to /join #D
Some of the features: bot friendly, low ping time, reliable, free, open to
developers of all levels, experienced developers available, exciting
hangout.
There aren't any nickname or channel registration services yet, I'm
currently working on that in D.
If anyone doesn't know about IRC just reply and I'll explain.

<hr><h4>6/25/03 Benji Smith writes:</h4>

<pre>
I may be missing something, but I haven't found any information in the D
documentation for how to declare associative array literal values all at once.

For example, once I've declared an array as:

char[char[]][] myArray;

I can now only add values to that array one at a time, as follows:

myArray["red"] = "ff0000";
myArray["green"] = "00ff00";
myArray["green"] = "0000ff";

What I'd like to be able to do (especially in cases where I have lots of values
to add to the array) would look something like this:

myArray = {

"red" => "ff0000",
"green" => "00ff00",
"blue" => "0000ff"

};

 ..or something like that. I don't really care about the {} braces or the =>
 operator, but I would like something that lets me declare an associative array
 literal, just like I can declare a static array using the code:

int[] def = { 1, 2, 3 };
</pre>


<hr><h4>6/19/03 Mark Evans writes:</h4>

    Since D aspires to be a systems language, more attention
    should be paid to novel architectures, especially those
    targeting D's favorite topic, runtime performance.
    This group is working on novel memory controllers and
    associated compiler tools.
    <p>
    http://www.cs.utah.edu/impulse/
    <p>
    "Von Neumann's prediction of 1945 continues to hold true -
    memory is the primary system bottleneck."


<hr><h4>6/17/03 Daniel Yokomiso writes:</h4>

    Hi,<p>

	The ICFP 2003 is coming ( http://icfpcontest.org/ ), going from
    2003-06-28 to 2003-06-30. Are people here interested in losing a weekend for
    it. I know I am ;$(RPAREN)<br>
	As usual we have no idea about this year's task, but I think a team of 3
    to 6 developers should be enough. Also if we give it a shot and get
    ourselves a nice place we could get some attention for D.

<hr><h4>5/30/03 Alisdair Meredith writes:</h4>

    Following up some recent debate in the Borland Delphi newsgroups about 
    this page [http://www.digitalmars.com/d/index.html] I would like to
    query a couple of items in the list.  (I expect you will get a message
    or two with Delphi's capabilities shortly <g>) 
    <p>

    i/ Huge play is made on the versatility of array type, which seems
    somewhat unfair to languages that explictly support the listed behaviour
    in their STANDARD libraries that are expected as part of a conforming
    implementation.
    <p>

    Specifically, C++ does not have 'resizable arrays' as a langauge
    feature because they are in the standard library, std::vector.  There is
    no likelihood any proposal to add such a feature to the language would
    ever pass committee because it is already required to be present (in the
    library) in any conforming C++ implementation.
    <p>

    While I can understand your desire to show your own product in the best
    possible light, I would like to at least see a 3rd option between 'yes'
    and 'no' for features implemented in the standard library of other
    languages (rather than 3rd party libraries, no matter how common)
    <p>

    Suggest a 'LIB' cell coloured yellow.
    <p>

    [otherwise such clear bias on something I do know well will give me
    doubts about other items I am less clear on, see below]
    <p>

    Under OOP you say C++ has module support.  News to me, this is one of
    the most requested extensions to the library and I still don't know
    anyone with a clear idea how to approach it!  I suggest you change this
    to 'No'
    <p>

    Also, Covariant return types is duplicated in OOP and functions
    sections, is that intentional?
    <p>

    Under reliablility I am very surprised that only 'D' rates as unit
    testable.  I would at least like a link to some material explaining why
    only 'D' qualifies here.  A good opportunity for a sales pitch if ever I
    saw one, this is the detail that caught my attention most!!  [Although I
    don't use Java, I was surprised that its extensive reflection API and
    unit-testing community did not qualify]
    <p>

    Again, a footnote explaining why C++ does not support all 'C' types
    would be useful.  Do you mean C99 here, or are there even more obvious
    cases I am missing?
    <p>

    I would be happy to see 'struct member alignment control' dropped from
    C++ (and presumably C) as this relies on common compiler extensions,
    rather than true features of the language itself.  If we are going to
    permit extensions, there are several popular C++ variants supporting
    delegates, but I would not suggest you add that to the list either <g>
    Rather, be stricter and say 'no' to struct layout control.
    <p>

    Last but not least, it would be really nice to turn the logic on the
    Macro Preprocessor.  The presence of this mis-feature is the cause of
    endless annoyance to C++, and its lack is certainly another score for
    'D'.
    <p>

    Oh, and as a cheeky new feature you might want to add 'reference
    implementation available' given that I am not yet aware of a conforming
    C++ implementation [although EDG-based solutions are getting very close
    now]
    <p>

    Interesting chart though.  If you can find the people to contribute I
    would be interested in seeing how Eiffel, Python, Smalltalk and Haskell
    score as well.

<hr><h4>5/23/03 Jon Frechette writes:</h4>

    I have been trying to see how far one could go in creating source code
    documentation by mixing D and DHTML. The idea is to turn the source code
    into its own dynamic 'Table of Contents'.
    <p>

    You can see an example of this here:
    <a href="http://home.mindspring.com/~jonf4/d_docs/base.html">http://home.mindspring.com/~jonf4/d_docs/base.html</a>
    <p>

    As I am not a D programmer, I used one of Daniel Yukio Yokomiso's Deimos
    library files as an example.
    <p>

    So, is this a good idea ?
    <p>

    It seems like too much work to write the required HTML by hand. It ought to
    be possible to use the D parser to create a d2html program that uses the
    parse tree generate the HTML.
    <p>

    Any thoughts ?

<hr><h4>February 2002 issue</a> of <a href="http://www.ddj.com/">Dr. Dobb's</a>:</h4>

	"The D Programming Language"
	by Walter Bright

)

Macros:
	TITLE=News
	WIKI=DNews

