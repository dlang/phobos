
// This test program pulls in all the library modules in order
// to run the unit tests on them.
// Then, it prints out the arguments passed to main().

import object;
import c.stdio;
import string;
import path;
import math;
import outbuffer;
import ctype;
import regexp;
import random;

int main(char[][] args)
{

    // Bring in unit test for module by referencing function in it

    cmp("foo", "bar");			// string
    fncharmatch('a', 'b');		// path
    isnan(1.0);				// math
    OutBuffer b = new OutBuffer();	// outbuffer
    ctype.tolower('A');			// ctype
    RegExp r = new RegExp(null, null);	// regexp
    rand();

    printf("hello world\n");
    printf("args.length = %d\n", args.length);
    for (int i = 0; i < args.length; i++)
	printf("args[%d] = '%s'\n", i, (char *)args[i]);
    return 0;
}
