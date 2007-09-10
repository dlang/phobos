
import object;
import stdio;

class OutOfMemory : Object
{
    void print()
    {
	printf("Out of memory\n");
    }

    extern (C) static void _d_OutOfMemory()
    {
	throw (OutOfMemory)(void *)OutOfMemory.classinfo.init;
    }
}
