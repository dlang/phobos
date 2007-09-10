
extern (C) int printf(char *, ...);
extern (C) int wprintf(wchar *, ...);

alias bit bool;

version (AMD64)
{
    alias ulong size_t;
    alias long ptrdiff_t;
}
else
{
    alias uint size_t;
    alias int ptrdiff_t;
}

class Object
{
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
	return cast(uint)cast(void *)this;
    }

    int opCmp(Object o)
    {
	return cast(int)cast(void *)this - cast(int)cast(void *)o;
    }

    int opEquals(Object o)
    {
	return this === o;
    }
}

struct Interface
{
    ClassInfo classinfo;
    void *[] vtbl;
    int offset;			// offset to Interface 'this' from Object 'this'
}

class ClassInfo : Object
{
    byte[] init;		// class static initializer
    char[] name;		// class name
    void *[] vtbl;		// virtual function pointer table
    Interface[] interfaces;
    ClassInfo base;
    void *destructor;
    void (*classInvariant)(Object);
    uint flags;
    //	1:			// IUnknown
    void *deallocator;
}

class TypeInfo
{
    uint getHash(void *p) { return cast(uint)p; }
    int equals(void *p1, void *p2) { return p1 == p2; }
    int compare(void *p1, void *p2) { return 0; }
    int tsize() { return 0; }
    void swap(void *p1, void *p2)
    {
	int i;
	int n = tsize();
	for (i = 0; i < n; i++)
	{   byte t;

	    t = (cast(byte *)p1)[i];
	    (cast(byte *)p1)[i] = (cast(byte *)p2)[i];
	    (cast(byte *)p2)[i] = t;
	}
    }
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

