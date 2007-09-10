
module std.outofmemory;

class OutOfMemory : Object
{
    void print()
    {
	printf("Out of memory\n");
    }
}

extern (C) void _d_OutOfMemory()
{
    throw cast(OutOfMemory)cast(void *)OutOfMemory.classinfo.init;
}

