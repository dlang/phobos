
// Implementation is in internal\object.d

module object;

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
    void print();
    char[] toString();
    uint toHash();
    int opCmp(Object o);
    int opEquals(Object o);
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
    uint getHash(void *p);
    int equals(void *p1, void *p2);
    int compare(void *p1, void *p2);
    int tsize();
    void swap(void *p1, void *p2);
}

class TypeInfoTypedef : TypeInfo
{
    TypeInfo base;
}

class TypeInfoClass : TypeInfo
{
    ClassInfo info;
}

// Recoverable errors

class Exception : Object
{
    char[] msg;

    this(char[] msg);
    void print();
    char[] toString();
}

// Non-recoverable errors

class Error : Exception
{
    Error next;

    this(char[] msg);
    this(char[] msg, Error next);
}

