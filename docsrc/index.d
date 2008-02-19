Ddoc

$(D_S D Programming Language 2.0,

$(BLOCKQUOTE
	"It seems to me that most of the "new" programming languages
	fall into one of two categories: Those from academia with radical
	new paradigms and those from large corporations with a focus on RAD
	and the web. Maybe it's time for a new language born out of
	practical experience implementing compilers." -- Michael
)

$(BLOCKQUOTE
"Great, just what I need.. another D in programming." -- Segfault
)

$(P The D book
	<a href="http://www.amazon.com/gp/product/1590599608?ie=UTF8&tag=classicempire&linkCode=as2&camp=1789&creative=9325&creativeASIN=1590599608">Learn to Tango with D</a><img src="http://www.assoc-amazon.com/e/ir?t=classicempire&l=as2&o=1&a=1590599608" width="1" height="1" border="0" alt="" style="border:none !important; margin:0px !important;" />
	by Kris Bell, Lars Ivar Igesund, Sean Kelly and Michael Parker
	is now out.
)

$(P The first
$(LINK2 http://d.puremagic.com/conference2007/, D Programming Language Conference)
took place in Seattle at Amazon, Aug 23..24, 2007.)

$(P
D is a systems programming language.
Its focus is on combining the power and high performance of C and C++ with
the programmer productivity of modern languages like Ruby and Python.
Special attention is given to the needs of quality assurance, documentation,
management, portability and reliability.
)

$(P The D language is statically typed and compiles directly to machine code.
It's multiparadigm, supporting many programming styles: 
imperative, object oriented, and metaprogramming. It's a member of the C 
syntax family, and its appearance is very similar to that of C++. For a 
quick comparison of the features, see
this $(LINK2 comparison.html, comparison)
of D with C, C++, C# and Java.)

$(P It is not governed by a corporate agenda or any overarching theory of
programming. The needs and contributions of the
$(LINK2 ../NewsGroup.html, D programming community) form the direction it
goes.
)

$(P There are currently two implementations, the
$(LINK2 dcompiler.html, Digital Mars DMD) package for Win32 and x86 Linux,
and the
$(LINK2 http://dgcc.sourceforge.net/, GCC D Compiler) package for
several platforms, including
$(LINK2 http://gdcwin.sourceforge.net/, Windows)
and
$(LINK2 http://gdcmac.sourceforge.net/, Mac OS X).
)

$(P A large and growing collection of D source code and projects
are at $(LINK2 http://www.dsource.org, dsource).
More links to innumerable D wikis, libraries, tools, media articles,
etc. are at $(LINK2 dlinks.html, dlinks).
)

$(P
This document is available as a
$(LINK2 http://www.prowiki.org/wiki4d/wiki.cgi?LanguageSpecification, pdf),
as well as in
$(LINK2 http://www.kmonos.net/alang/d/, Japanese)
and
$(LINK2 http://elderane.50webs.com/tuto/d/, Portugese)
translations.
A Japanese book
$(LINK2 http://www.gihyo.co.jp/books/syoseki-contents.php/4-7741-2208-4, D Language Perfect Guide)
is available.
)

$(COMMENT: Japanese by Kazuhiro Inaba, Portugese by Christian Hartung)

$(P This is an example D program illustrating some of the capabilities:)
----
#!/usr/bin/dmd -run
/* sh style script syntax is supported */

/* Hello World in D
   To compile:
     dmd hello.d
   or to optimize:
     dmd -O -inline -release hello.d
*/

import std.stdio;

void main(string[] args)
{
    writefln("Hello World, Reloaded");

    // auto type inference and built-in foreach
    foreach (argc, argv; args)
    {
        // Object Oriented Programming
        auto cl = new CmdLin(argc, argv);
        // Improved typesafe printf
        writeln(cl.argnum, cl.suffix, " arg: ", cl.argv);
        // Automatic or explicit memory management
        delete cl;
    }

    // Nested structs and classes
    struct specs
    {
        // all members automatically initialized
        int count, allocated;
    }

    // Nested functions can refer to outer
    // variables like args
    specs argspecs()
    {
        specs* s = new specs;
        // no need for '->'
        s.count = args.length;		   // get length of array with .length
        s.allocated = typeof(args).sizeof; // built-in native type properties
        foreach (argv; args)
            s.allocated += argv.length * typeof(argv[0]).sizeof;
        return *s;
    }

    // built-in string and common string operations
    writefln("argc = %d, " ~ "allocated = %d",
	argspecs().count, argspecs().allocated);
}

class CmdLin
{
    private int _argc;
    private string _argv;

public:
    this(int argc, string argv)	// constructor
    {
        _argc = argc;
        _argv = argv;
    }

    int argnum()
    {
        return _argc + 1;
    }

    string argv()
    {
        return _argv;
    }

    string suffix()
    {
        string suffix = "th";
        switch (_argc)
        {
          case 0:
            suffix = "st";
            break;
          case 1:
            suffix = "nd";
            break;
          case 2:
            suffix = "rd";
            break;
          default:
	    break;
        }
        return suffix;
    }
}
----


$(P $(B Note:) all D users agree that by downloading and using
D, or reading the D specs,
they will explicitly identify any claims to intellectual property
rights with a copyright or patent notice in any posted or emailed
feedback sent to Digital Mars.)

)

Macros:
	TITLE=Intro
	WIKI=Intro

