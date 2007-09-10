
import std.c.stdio;

class OutOfMemory : Object
{
    void print()
    {
	printf("Out of memory\n");
    }
}

extern (C) void _d_OutOfMemory()
{
    throw (OutOfMemory)(void *)OutOfMemory.classinfo.init;
}

