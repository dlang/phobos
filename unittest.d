// Written in the D programming language.

/**
 * This test program pulls in all the library modules in order to run the unit
 * tests on them.  Then, it prints out the arguments passed to main().
 *
 * Copyright: Copyright Digital Mars 2000 - 2009.
 * License:   <a href="http://www.boost.org/LICENSE_1_0.txt">Boost License 1.0</a>.
 * Authors:   $(WEB digitalmars.com, Walter Bright)
 *
 *          Copyright Digital Mars 2000 - 2009.
 * Distributed under the Boost Software License, Version 1.0.
 *    (See accompanying file LICENSE_1_0.txt or copy at
 *          http://www.boost.org/LICENSE_1_0.txt)
 */
public import std.base64;
public import std.bind;
public import std.compiler;
public import std.concurrency;
public import std.contracts;
public import std.conv;
public import std.cpuid;
public import std.cstream;
public import std.ctype;
public import std.date;
public import std.dateparse;
public import std.demangle;
public import std.file;
public import std.format;
public import std.getopt;
public import std.loader;
public import std.math;
public import std.mathspecial;
public import std.md5;
public import std.metastrings;
public import std.mmfile;
public import std.outbuffer;
public import std.parallelism;
public import std.path;
public import std.perf;
public import std.process;
public import std.random;
public import std.regexp;
public import std.signals;
//public import std.slist;
public import std.socket;
public import std.socketstream;
public import std.stdint;
public import std.stdio;
public import std.stream;
public import std.string;
public import std.syserror;
public import std.system;
public import std.traits;
public import std.typetuple;
public import std.uni;
public import std.uri;
public import std.utf;
public import std.variant;
public import std.zip;
public import std.zlib;

int main(char[][] args)
{

version (all)
{
    // Bring in unit test for module by referencing function in it

    cmp("foo", "bar");			// string
    fncharmatch('a', 'b');		// path
    isNaN(1.0);				// math
    std.conv.to!double("1.0");		// std.conv
    OutBuffer b = new OutBuffer();	// outbuffer
    std.ctype.tolower('A');		// ctype
    RegExp r = new RegExp(null, null);	// regexp
    uint ranseed = std.random.unpredictableSeed();
    thisTid();
    int a[];
    a.reverse;				// adi
    a.sort;				// qsort
    std.date.getUTCtime();			// date
    Exception e = new ReadException(""); // stream
    din.eof();                           // cstream
    isValidDchar(cast(dchar)0);			// utf
    std.uri.ascii2hex(0);			// uri
    std.zlib.adler32(0,null);			// D.zlib
    auto t = task!cmp("foo", "bar");  // parallelism

    ubyte[16] buf;
    std.md5.sum(buf,"");

    creal c = 3.0 + 4.0i;
    c = sqrt(c);
    assert(c.re == 2);
    assert(c.im == 1);

    printf("args.length = %d\n", args.length);
    for (int i = 0; i < args.length; i++)
	printf("args[%d] = '%s'\n", i, cast(char *)args[i]);

    int[3] x;
    x[0] = 3;
    x[1] = 45;
    x[2] = -1;
    x.sort;
    assert(x[0] == -1);
    assert(x[1] == 3);
    assert(x[2] == 45);

    std.math.sin(3.0);
    std.mathspecial.gamma(6.2);

    std.demangle.demangle("hello");

    std.uni.isUniAlpha('A');

    std.file.exists("foo");

    foreach_reverse (dchar d; "hello"c) { ; }
    foreach_reverse (k, dchar d; "hello"c) { ; }

    std.signals.linkin();

    writefln(std.cpuid.toString());
}
    printf("Success!\n");
    return 0;
}
