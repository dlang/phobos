
// Copyright (c) 1999-2003 by Digital Mars
// All Rights Reserved
// written by Walter Bright
// www.digitalmars.com

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
import std.stream;
import std.utf;
import std.uri;
import std.zlib;

int main(char[][] args)
{

    // Bring in unit test for module by referencing function in it

    cmp("foo", "bar");			// string
    fncharmatch('a', 'b');		// path
    isnan(1.0);				// math
    feq(1.0, 2.0);			// math2
    OutBuffer b = new OutBuffer();	// outbuffer
    std.ctype.tolower('A');		// ctype
    RegExp r = new RegExp(null, null);	// regexp
    std.random.rand();
    int a[];
    a.reverse;				// adi
    a.sort;				// qsort
    std.date.getUTCtime();			// date
    StreamError se = new StreamError("");	// stream
    isValidDchar((dchar)0);			// utf
    std.uri.ascii2hex(0);			// uri
    std.zlib.adler32(0,null);			// D.zlib

{
    creal c = 3.0 + 4.0i;
    c = sqrt(c);
    printf("re = %Lg, im = %Lg\n", c.re, c.im);
}

    printf("hello world\n");
    printf("args.length = %d\n", args.length);
    for (int i = 0; i < args.length; i++)
	printf("args[%d] = '%s'\n", i, (char *)args[i]);
    printf("Success\n!");
    return 0;
}
