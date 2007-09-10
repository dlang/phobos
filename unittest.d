
/*
 *  Copyright (C) 1999-2005 by Digital Mars, www.digitalmars.com
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

import std.c.stdio;
import std.string;
import std.path;
import std.math;
import std.math2;
import std.outbuffer;
import std.ctype;
import std.regexp;
import std.random;
import std.date;
import std.dateparse;
import std.demangle;
import std.cstream;
import std.stream;
import std.utf;
import std.uri;
import std.zlib;
import std.md5;
import std.stdio;
import std.conv;
import std.boxer;
import std.bitarray;
import std.uni;
import std.file;

int main(char[][] args)
{

    // Bring in unit test for module by referencing function in it

    cmp("foo", "bar");			// string
printf("test1\n");
    fncharmatch('a', 'b');		// path
    isnan(1.0);				// math
    std.math2.feq(1.0, 2.0);		// math2
    std.conv.toDouble("1.0");		// std.conv
printf("test1\n");
    OutBuffer b = new OutBuffer();	// outbuffer
    std.ctype.tolower('A');		// ctype
    RegExp r = new RegExp(null, null);	// regexp
    std.random.rand();
printf("test2\n");
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

    writefln("hello world!");			// std.format

    Box abox;
{
    creal c = 3.0 + 4.0i;
    c = sqrt(c);
    printf("re = %Lg, im = %Lg\n", c.re, c.im);
}

    printf("hello world\n");
    printf("args.length = %d\n", args.length);
    for (int i = 0; i < args.length; i++)
	printf("args[%d] = '%s'\n", i, cast(char *)args[i]);

    int[3] x;
    x[0] = 3;
    x[1] = 45;
    x[2] = -1;
    x.sort;

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

    printf("Success\n!");
    return 0;
}
