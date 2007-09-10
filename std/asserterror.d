
module std.asserterror;

import std.c.stdio;
import std.c.stdlib;

class AssertError : Error
{
  private:

    uint linnum;
    char[] filename;

    this(char[] filename, uint linnum)
    {
	this.linnum = linnum;
	this.filename = filename;

	char* buffer;
	size_t len;
	int count;

	/* This code is careful to not use gc allocated memory,
	 * as that may be the source of the problem.
	 * Instead, stick with C functions.
	 */

	len = 22 + filename.length + uint.sizeof * 3 + 1;
	buffer = cast(char*)std.c.stdlib.malloc(len);
	if (buffer == null)
	    super("AssertError internal failure");
	else
	{
	    version (Win32) alias _snprintf snprintf;
	    count = snprintf(buffer, len, "AssertError Failure %.*s(%u)",
		filename, linnum);
	    if (count >= len || count == -1)
		super("AssertError internal failure");
	    else
		super(buffer[0 .. count]);
	}
    }

    ~this()
    {
	if (msg.ptr)
	{   std.c.stdlib.free(msg.ptr);
	    msg = null;
	}
    }
}


/********************************************
 * Called by the compiler generated module assert function.
 * Builds an AssertError exception and throws it.
 */

extern (C) static void _d_assert(char[] filename, uint line)
{
    //printf("_d_assert(%s, %d)\n", cast(char *)filename, line);
    AssertError a = new AssertError(filename, line);
    //printf("assertion %p created\n", a);
    throw a;
}
