/*
 *  Copyright (C) 1999-2006 by Digital Mars, www.digitalmars.com
 *  Written by Walter Bright
 *
 *  This software is provided 'as-is', without any express or implied
 *  warranty. In no event will the authors be held liable for any damages
 *  arising from the use of this software.
 *
 *  Permission is granted to anyone to use this software for any purpose,
 *  including commercial applications, and to alter it and redistribute it
 *  freely, in both source and binary form, subject to the following
 *  restrictions:
 *
 *  o  The origin of this software must not be misrepresented; you must not
 *     claim that you wrote the original software. If you use this software
 *     in a product, an acknowledgment in the product documentation would be
 *     appreciated but is not required.
 *  o  Altered source versions must be plainly marked as such, and must not
 *     be misrepresented as being the original software.
 *  o  This notice may not be removed or altered from any source
 *     distribution.
 */

// This test program pulls in all the library modules in order
// to run the unit tests on them.
// Then, it prints out the arguments passed to main().

public import std.array;
public import std.asserterror;
public import std.base64;
public import std.bind;
public import std.bitarray;
public import std.boxer;
public import std.compiler;
public import std.contracts;
public import std.conv;
public import std.cover;
public import std.cpuid;
public import std.cstream;
public import std.ctype;
public import std.date;
public import std.dateparse;
public import std.demangle;
public import std.file;
public import std.format;
public import std.gc;
public import std.getopt;
public import std.hiddenfunc;
public import std.intrinsic;
public import std.loader;
public import std.math;
public import std.md5;
public import std.metastrings;
public import std.mmfile;
public import std.moduleinit;
public import std.openrj;
public import std.outbuffer;
public import std.outofmemory;
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
public import std.switcherr;
public import std.syserror;
public import std.system;
public import std.thread;
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
    // Bring in unit test for module by referencing function in it

    cmp("foo", "bar");			// string
    fncharmatch('a', 'b');		// path
    isnan(1.0);				// math
    std.conv.toDouble("1.0");		// std.conv
    OutBuffer b = new OutBuffer();	// outbuffer
    std.ctype.tolower('A');		// ctype
    RegExp r = new RegExp(null, null);	// regexp
    std.random.rand();
    int a[];
    a.reverse;				// adi
    a.sort;				// qsort
    std.date.getUTCtime();			// date
    Exception e = new ReadException(""); // stream
    din.eof();                           // cstream
    isValidDchar(cast(dchar)0);			// utf
    std.uri.ascii2hex(0);			// uri
    std.zlib.adler32(0,null);			// D.zlib

    ubyte[16] buf;
    std.md5.sum(buf,"");

    Box abox;

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

    std.math.tgamma(3);
    std.math.lgamma(3);

    std.demangle.demangle("hello");

    BitArray ba;			// std.bitarray
    ba.length = 3;
    ba[0] = true;

    std.uni.isUniAlpha('A');

    std.file.exists("foo");

    foreach_reverse (dchar d; "hello"c) { ; }
    foreach_reverse (k, dchar d; "hello"c) { ; }

    std.signals.linkin();

    writefln(std.cpuid.toString());

    printf("Success!\n");
    return 0;
}
