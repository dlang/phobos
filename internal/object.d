
module object;

extern (C)
{   int printf(char *, ...);
}

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
	printf("%.*s\n", toString());
    }

    char[] toString()
    {
	return this.classinfo.name;
    }

    uint toHash()
    {
	// BUG: this prevents a compacting GC from working, needs to be fixed
	return cast(uint)cast(void *)this;
    }

    int opCmp(Object o)
    {
	// BUG: this prevents a compacting GC from working, needs to be fixed
	return cast(int)cast(void *)this - cast(int)cast(void *)o;
    }

    int opEquals(Object o)
    {
	return this is o;
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

private import std.string;

class TypeInfo
{
    uint toHash()
    {	uint hash;

	foreach (char c; this.classinfo.name)
	    hash = hash * 9 + c;
	return hash;
    }

    int opCmp(Object o)
    {
	return std.string.cmp(this.classinfo.name, o.classinfo.name);
    }

    int opEquals(Object o)
    {
	/* TypeInfo instances are singletons, but duplicates can exist
	 * across DLL's. Therefore, comparing for a name match is
	 * sufficient.
	 */
	return this is o || this.classinfo.name == o.classinfo.name;
    }

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

class TypeInfo_Typedef : TypeInfo
{
    uint getHash(void *p) { return base.getHash(p); }
    int equals(void *p1, void *p2) { return base.equals(p1, p2); }
    int compare(void *p1, void *p2) { return base.compare(p1, p2); }
    int tsize() { return base.tsize(); }
    void swap(void *p1, void *p2) { return base.swap(p1, p2); }

    TypeInfo base;
}

class TypeInfo_Class : TypeInfo
{
    char[] toString() { return info.name; }

    uint getHash(void *p)
    {
	Object o = *cast(Object*)p;
	assert(o);
	return o.toHash();
    }

    int equals(void *p1, void *p2)
    {
	Object o1 = *cast(Object*)p1;
	Object o2 = *cast(Object*)p2;

	return o1 == o2 || (o1 && o1.opCmp(o2) == 0);
    }

    int compare(void *p1, void *p2)
    {
	Object o1 = *cast(Object*)p1;
	Object o2 = *cast(Object*)p2;
	int c = 0;

	// Regard null references as always being "less than"
	if (o1 != o2)
	{
	    if (o1)
	    {	if (!o2)
		    c = 1;
		else
		    c = o1.opCmp(o2);
	    }
	    else
		c = -1;
	}
	return c;
    }

    int tsize()
    {
	return Object.sizeof;
    }

    ClassInfo info;
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

