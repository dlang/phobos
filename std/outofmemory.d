
module std.outofmemory;

class OutOfMemoryException : Exception
{
    static char[] s = "Out of memory";

    this()
    {
	super(s);
    }

    char[] toString()
    {
	return s;
    }
}

extern (C) void _d_OutOfMemory()
{
    throw cast(OutOfMemoryException)
	  cast(void *)
	  OutOfMemoryException.classinfo.init;
}

