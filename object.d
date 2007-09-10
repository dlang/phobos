

class Object
{
    extern (C) static int printf(char *, ...);

    void print()
    {
	printf("Object %p\n", this);
    }

    char[] toString()
    {
	return "Object";
    }

    uint toHash()
    {
	return (uint)(void *)this;
    }

    int cmp(Object o)
    {
	return 0; (char *)(void *)this - (char *)(void *)o;
    }
}

struct Interface
{
    ClassInfo classinfo;
    void *[] vtbl;
}

class ClassInfo : Object
{
    byte[] init;		// class static initializer
    char[] name;		// class name
    void *[] vtbl;		// virtual function pointer table
    Interface[] interfaces;
    ClassInfo base;
    void *destructor;
    void (*_invariant)(Object);
}

class Exception : Object
{
    char[] msg;

    this(char[] msg)
    {
	this.msg = msg;
    }

    void print()
    {
	printf("%.*s\n", msg);
    }

    char[] toString() { return msg; }
}

class Error : Exception
{
    Error next;

    this(char[] msg)
    {
	super(msg);
    }

    this(char[] msg, Error next)
    {
	super(msg);
	this.next = next;
    }
}

extern (C)
{
    // These are helper functions internal to the D runtime library (phobos.lib)
    void*[]  _aaRehashAh(void*[] paa);
    char[][] _aaKeys8(void*[] paa);
    int[]    _aaValues8_4(void*[] paa);
}

int[char[]] rehash(int[char[]] aa)
{
    return (int[char[]]) _aaRehashAh((void*[])aa);
}

char[][] keys(int[char[]] aa)
{
    return (char[][]) _aaKeys8((void*[])aa);
}

int[] values(int[char[]] aa)
{
    return (int[]) _aaValues8_4((void*[])aa);
}


