Ddoc

$(COMMUNITY D Strings vs C++ Strings,


Why have strings built-in to the core language of D rather than entirely in
a library as in C++ Strings? What's the point? Where's the improvement?

<h4>Concatenation Operator</h4>

$(P	C++ Strings are stuck with overloading existing operators. The
	obvious choice for concatenation is += and +.
	But someone just looking at the code will see + and think "addition".
	He'll have to look up the types (and types are frequently buried
	behind multiple typedef's) to see that it's a string type, and
	it's not adding strings but concatenating them.
)
$(P	Additionally, if one has an array of floats, is '+' overloaded to
	be the same as a vector addition, or an array concatenation?
)
$(P	In D, these problems are avoided by introducing a new binary
	operator ~ as the concatenation operator. It works with
	arrays (of which strings are a subset). ~= is the corresponding
	append operator. ~ on arrays of floats would concatenate them,
	+ would imply a vector add. Adding a new operator makes it possible
	for orthogonality and consistency in the treatment of arrays.
	(In D, strings are simply arrays of characters, not a special
	type.)
)

<h4>Interoperability With C String Syntax</h4>

$(P	Overloading of operators only really works if one of the operands
	is overloadable. So the C++ string class cannot consistently
	handle arbitrary expressions containing strings. Consider:
)

$(CCODE
const char abc[5] = "world";
string str = "hello" + abc;
)

$(P	That isn't going to work. But it does work when the core language
	knows about strings:
)

$(CCODE
const char[5] abc = "world";
char[] str = "hello" ~ abc;
)

<h4>Consistency With C String Syntax</h4>

$(P
	There are three ways to find the length of a string in C++:
)

$(CCODE
const char abc[] = "world";	:	sizeof(abc)/sizeof(abc[0])-1
				:	strlen(abc)
string str;			:	str.length()
)

$(P
	That kind of inconsistency makes it hard to write generic templates.
	Consider D:
)

-----------------------
char[5] abc = "world";	:	abc.length
char[] str		:	str.length
-----------------------

<h4>Checking For Empty Strings</h4>

$(P
	C++ strings use a function to determine if a string is empty:
)

$(CCODE
string str;
if (str.empty())
	// string is empty
)

$(P
	In D, an empty string has zero length:
)

-----------------------
char[] str;
if (!str.length)
	// string is empty
-----------------------


<h4>Resizing Existing String</h4>

$(P
	C++ handles this with the resize() member function:
)

$(CCODE
string str;
str.resize(newsize);
)

$(P
	D takes advantage of knowing that str is an array, and
	so resizing it is just changing the length property:
)

-----------------------
char[] str;
str.length = newsize;
-----------------------

<h4>Slicing a String</h4>

$(P
	C++ slices an existing string using a special constructor:
)

$(CCODE
string s1 = "hello world";
string s2(s1, 6, 5);		// s2 is "world"
)

$(P
	D has the array slice syntax, not possible with C++:
)

-----------------------
char[] s1 = "hello world";
char[] s2 = s1[6 .. 11];	// s2 is "world"
-----------------------

$(P
	Slicing, of course, works with any array in D, not just strings.
)

<h4>Copying a String</h4>

$(P
	C++ copies strings with the replace function:
)

$(CCODE
string s1 = "hello world";
string s2 = "goodbye      ";
s2.replace(8, 5, s1, 6, 5);	// s2 is "goodbye world"
)

$(P
	D uses the slice syntax as an lvalue:
)

-----------------------
char[] s1 = "hello world";
char[] s2 = "goodbye      ".dup;
s2[8..13] = s1[6..11];		// s2 is "goodbye world"
-----------------------

	$(P The $(CODE .dup) is needed because string literals are
	read-only in D, the $(CODE .dup) will create a copy
	that is writable.
	)


<h4>Conversions to C Strings</h4>

$(P
	This is needed for compatibility with C API's. In C++, this
	uses the c_str() member function:
)

$(CCODE
void foo(const char *);
string s1;
foo(s1.c_str());
)

$(P
	In D, strings can be converted to char* using the .ptr property:
)

-----------------------
void foo(char*);
char[] s1;
foo(s1.ptr);
-----------------------
	$(P although for this to work where $(TT foo) expects a 0 terminated
	string, $(TT s1) must have a terminating 0. Alternatively, the
	function $(TT std.string.toStringz) will ensure it:)

-----------------------
void foo(char*);
char[] s1;
foo(std.string.$(B toStringz)(s1));
-----------------------


<h4>Array Bounds Checking</h4>

$(P
	In C++, string array bounds checking for [] is not done.
	In D, array bounds checking is on by default and it can be turned off
	with a compiler switch after the program is debugged.
)

<h4>String Switch Statements</h4>

$(P
	Are not possible in C++, nor is there any way to add them
	by adding more to the library. In D, they take the obvious
	syntactical forms:
)

-----------------------
switch (str)
{
    case "hello":
    case "world":
	...
}
-----------------------

$(P
	where str can be any of literal "string"s, fixed string arrays
	like char[10], or dynamic strings like char[]. A quality implementation
	can, of course, explore many strategies of efficiently implementing
	this based on the contents of the case strings.
)

<h4>Filling a String</h4>

$(P
	In C++, this is done with the replace() member function:
)

$(CCODE
string str = "hello";
str.replace(1,2,2,'?');		// str is "h??lo"
)

$(P
	In D, use the array slicing syntax in the natural manner:
)

-----------------------
char[5] str = "hello";
str[1..3] = '?';		// str is "h??lo"
-----------------------

<h4>Value vs Reference</h4>

$(P
	C++ strings, as implemented by STLport, are by value and are
	0-terminated. [The latter is an implementation choice, but
	STLport seems to be the most popular implementation.]
	This, coupled with no garbage collection, has
	some consequences. First of all, any string created must make
	its own copy of the string data. The 'owner' of the string
	data must be kept track of, because when the owner is deleted
	all references become invalid. If one tries to avoid the
	dangling reference problem by treating strings as value types,
	there will be a lot of overhead of memory allocation,
	data copying, and memory deallocation. Next, the 0-termination
	implies that strings cannot refer to other strings. String
	data in the data segment, stack, etc., cannot
	be referred to.
)

$(P
	D strings are reference types, and the memory is garbage collected.
	This means that only references need to be copied, not the
	string data. D strings can refer to data in the static data
	segment, data on the stack, data inside other strings, objects,
	file buffers, etc. There's no need to keep track of the 'owner'
	of the string data.
)

$(P
	The obvious question is if multiple D strings refer to the same
	string data, what happens if the data is modified? All the
	references will now point to the modified data. This can have
	its own consequences, which can be avoided if the copy-on-write
	convention is followed. All copy-on-write is is that if
	a string is written to, an actual copy of the string data is made
	first.
)

$(P
	The result of D strings being reference only and garbage collected
	is that code that does a lot of string manipulating, such as
	an lzw compressor, can be a lot more efficient in terms of both
	memory consumption and speed.
)

<h2>Benchmark</h2>

$(P
	Let's take a look at a small utility, wordcount, that counts up
	the frequency of each word in a text file. In D, it looks like this:
)

-----------------------
import std.file;
import std.stdio;

int main (char[][] args)
{
    int w_total;
    int l_total;
    int c_total;
    int[char[]] dictionary;

    writefln("   lines   words   bytes file");
    for (int i = 1; i < args.length; ++i)
    {
	char[] input;
	int w_cnt, l_cnt, c_cnt;
	int inword;
	int wstart;

	input = cast(char[])std.file.read(args[i]);

	for (int j = 0; j < input.length; j++)
	{   char c;

	    c = input[j];
	    if (c == '\n')
		++l_cnt;
	    if (c >= '0' && c <= '9')
	    {
	    }
	    else if (c >= 'a' && c <= 'z' ||
		c >= 'A' && c <= 'Z')
	    {
		if (!inword)
		{
		    wstart = j;
		    inword = 1;
		    ++w_cnt;
		}
	    }
	    else if (inword)
	    {   char[] word = input[wstart .. j];

		dictionary[word]++;
		inword = 0;
	    }
	    ++c_cnt;
	}
	if (inword)
	{   char[] w = input[wstart .. input.length];
	    dictionary[w]++;
	}
	writefln("%8s%8s%8s %s", l_cnt, w_cnt, c_cnt, args[i]);
	l_total += l_cnt;
	w_total += w_cnt;
	c_total += c_cnt;
    }

    if (args.length > 2)
    {
	writefln("--------------------------------------%8s%8s%8s total",
	    l_total, w_total, c_total);
    }

    writefln("--------------------------------------");

    foreach (char[] word1; dictionary.keys.sort)
    {
	writefln("%3d %s", dictionary[word1], word1);
    }
    return 0;
}
-----------------------

	$(P (An $(LINK2 wc.html, alternate implementation) that 
	uses buffered file I/O to handle larger files.))

	$(P
	Two people have written C++ implementations using the C++ standard
	template library,
	<a href="http://groups.google.com/groups?q=g:thl953709878d&dq=&hl=en&lr=&ie=UTF-8&oe=UTF-8&selm=bjacrl%244un%2401%241%40news.t-online.com">wccpp1</a>
	and
	$(LINK2 #wccpp2, wccpp2).
	The input file
	$(LINK2 http://www.gutenberg.org/dirs/etext91/alice30.txt, alice30.txt)
	is the text of "Alice in Wonderland."
	The D compiler,
	<a HREF="http://ftp.digitalmars.com/dmd.zip" title="download D compiler">dmd</a>,
	and the C++ compiler,
	<a HREF="http://ftp.digitalmars.com/dmc.zip" title="download dmc.zip">dmc</a>,
	share the same
	optimizer and code generator, which provides a more apples to
	apples comparison of the efficiency of the semantics of the languages
	rather than the optimization and code generator sophistication.
	Tests were run on a Win XP machine. dmc uses STLport for the template
	implementation.
	)

	$(TABLE1
	$(TR
	$(TH Program)
	$(TH Compile)
	$(TH Compile Time)
	$(TH Run)
	$(TH Run Time)
	)
	$(TR
	$(TD D wc)
	$(TD dmd wc -O -release)
	$(TD 0.0719)
	$(TD wc alice30.txt &gt;log)
	$(TD 0.0326)
	)
	$(TR
	$(TD C++ wccpp1)
	$(TD dmc wccpp1 -o -I\dm\stlport\stlport)
	$(TD 2.1917)
	$(TD wccpp1 alice30.txt &gt;log)
	$(TD 0.0944)
	)
	$(TR
	$(TD C++ wccpp2)
	$(TD dmc wccpp2 -o -I\dm\stlport\stlport)
	$(TD 2.0463)
	$(TD wccpp2 alice30.txt &gt;log)
	$(TD 0.1012)
	)
	)

	$(P
	The following tests were run on linux, again comparing a D compiler
	($(LINK2 http://home.earthlink.net/~dvdfrdmn/d, gdc))
	and a C++ compiler ($(B g++)) that share a common optimizer and
	code generator. The system is Pentium III 800MHz running RedHat Linux 8.0
	and gcc 3.4.2.
	The Digital Mars D compiler for linux ($(B dmd))
	is included for comparison.
	)


	$(TABLE1
	$(TR
	$(TH Program)
	$(TH Compile)
	$(TH Compile Time)
	$(TH Run)
	$(TH Run Time)
	)
	$(TR
	$(TD D wc)
	$(TD gdc -O2 -frelease -o wc wc.d)
	$(TD 0.326)
	$(TD wc alice30.txt &gt; /dev/null)
	$(TD 0.041)
	)
	$(TR
	$(TD D wc)
	$(TD dmd wc -O -release)
	$(TD 0.235)
	$(TD wc alice30.txt &gt; /dev/null)
	$(TD 0.041)
	)
	$(TR
	$(TD C++ wccpp1)
	$(TD g++ -O2 -o wccpp1 wccpp1.cc)
	$(TD 2.874)
	$(TD wccpp1 alice30.txt &gt; /dev/null)
	$(TD 0.086)
	)
	$(TR
	$(TD C++ wccpp2)
	$(TD g++ -O2 -o wccpp2 wccpp2.cc)
	$(TD 2.886)
	$(TD wccpp2 alice30.txt &gt; /dev/null)
	$(TD 0.095)
	)
	)

	$(P
	These tests compare gdc with g++ on a PowerMac G5 2x2.0GHz
	running MacOS X 10.3.5 and gcc 3.4.2. (Timings are a little
	less accurate.)
	)

	$(TABLE1
	$(TR
	$(TH Program)
	$(TH Compile)
	$(TH Compile Time)
	$(TH Run)
	$(TH Run Time)
	)
	$(TR
	$(TD D wc)
	$(TD gdc -O2 -frelease -o wc wc.d)
	$(TD 0.28)
	$(TD wc alice30.txt &gt; /dev/null)
	$(TD 0.03)
	)
	$(TR
	$(TD C++ wccpp1)
	$(TD g++ -O2 -o wccpp1 wccpp1.cc)
	$(TD 1.90)
	$(TD wccpp1 alice30.txt &gt; /dev/null)
	$(TD 0.07)
	)
	$(TR
	$(TD C++ wccpp2)
	$(TD g++ -O2 -o wccpp2 wccpp2.cc)
	$(TD 1.88)
	$(TD wccpp2 alice30.txt &gt; /dev/null)
	$(TD 0.08)
	)
	)
<hr>
<h4><a name="wccpp2">wccpp2 by Allan Odgaard</a></h4>

$(CCODE
#include &lt;algorithm&gt;
#include &lt;cstdio&gt;
#include &lt;fstream&gt;
#include &lt;iterator&gt;
#include &lt;map&gt;
#include &lt;vector&gt;

bool isWordStartChar (char c)	{ return isalpha(c); }
bool isWordEndChar (char c)	{ return !isalnum(c); }

int main (int argc, char const* argv[])
{
    using namespace std;
    printf("Lines Words Bytes File:\n");

    map&lt;string, int&gt; dict;
    int tLines = 0, tWords = 0, tBytes = 0;
    for(int i = 1; i &lt; argc; i++)
    {
	ifstream file(argv[i]);
	istreambuf_iterator&lt;char&gt; from(file.rdbuf()), to;
	vector&lt;char&gt; v(from, to);
	vector&lt;char&gt;::iterator first = v.begin(), last = v.end(), bow, eow;

	int numLines = count(first, last, '\n');
	int numWords = 0;
	int numBytes = last - first;

	for(eow = first; eow != last; )
	{
	    bow = find_if(eow, last, isWordStartChar);
	    eow = find_if(bow, last, isWordEndChar);
	    if(bow != eow)
		++dict[string(bow, eow)], ++numWords;
	}

	printf("%5d %5d %5d %s\n", numLines, numWords, numBytes, argv[i]);

	tLines += numLines;
	tWords += numWords;
	tBytes += numBytes;
    }

    if(argc &gt; 2)
	    printf("-----------------------\n%5d %5d %5d\n", tLines, tWords, tBytes);
    printf("-----------------------\n\n");

    for(map&lt;string, int&gt;::const_iterator it = dict.begin(); it != dict.end(); ++it)
	    printf("%5d %s\n", it-&gt;second, it-&gt;first.c_str());

    return 0;
}
)

)

Macros:
	TITLE=D Strings vs C++ Strings
	WIKI=CPPstrings


