
// Copyright (c) 1999-2002 by Digital Mars
// All Rights Reserved
// written by Walter Bright
// www.digitalmars.com

// This test program pulls in all the library modules in order
// to run the unit tests on them.
// Then, it prints out the arguments passed to main().

import object;
import c.stdio;
import string;
import path;
import math;
import math2;
import outbuffer;
import ctype;
import regexp;
import random;
import date;
import dateparse;
import stream;

int main(char[][] args)
{

    // Bring in unit test for module by referencing function in it

    cmp("foo", "bar");			// string
    fncharmatch('a', 'b');		// path
    isnan(1.0);				// math
    feq(1.0, 2.0);			// math2
    OutBuffer b = new OutBuffer();	// outbuffer
    ctype.tolower('A');			// ctype
    RegExp r = new RegExp(null, null);	// regexp
    random.rand();
    int a[];
    a.reverse;				// adi
    a.sort;				// qsort
    date.getUTCtime();			// date
    StreamError se = new StreamError("");	// stream

    printf("hello world\n");
    printf("args.length = %d\n", args.length);
    for (int i = 0; i < args.length; i++)
	printf("args[%d] = '%s'\n", i, (char *)args[i]);
    return 0;
}
