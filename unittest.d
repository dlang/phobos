
// This test program pulls in all the library modules in order
// to run the unit tests on them.
// Then, it prints out the arguments passed to main().

import object;
import stdio;
import string;
import path;
import math;
import outbuffer;

int main(char[][] args)
{
    cmp("foo", "bar");
    fncharmatch('a', 'b');
    isnan(1.0);
    OutBuffer b = new OutBuffer();

    printf("hello world\n");
    printf("args.length = %d\n", args.length);
    for (int i = 0; i < args.length; i++)
	printf("args[%d] = '%s'\n", i, (char *)args[i]);
    return 0;
}
