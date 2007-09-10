
// Implementation is in internal\object.d

module object;

//alias bit bool;
alias bool bit;

alias typeof(int.sizeof) size_t;
alias typeof(cast(void*)0 - cast(void*)0) ptrdiff_t;
alias size_t hash_t;

extern (C)
{   int printf(char *, ...);
}

class Object
{
    void print();
    char[] toString();
    hash_t toHash();
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
    hash_t getHash(void *p);
    int equals(void *p1, void *p2);
    int compare(void *p1, void *p2);
    size_t tsize();
    void swap(void *p1, void *p2);
}

class TypeInfo_Typedef : TypeInfo
{
    TypeInfo base;
    char[] name;
}

class TypeInfo_Enum : TypeInfo_Typedef
{
}

class TypeInfo_Pointer : TypeInfo
{
    TypeInfo next;
}

class TypeInfo_Array : TypeInfo
{
    TypeInfo next;
}

class TypeInfo_StaticArray : TypeInfo
{
    TypeInfo next;
    size_t len;
}

class TypeInfo_AssociativeArray : TypeInfo
{
    TypeInfo next;
    TypeInfo key;
}

class TypeInfo_Function : TypeInfo
{
    TypeInfo next;
}

class TypeInfo_Delegate : TypeInfo
{
    TypeInfo next;
}

class TypeInfo_Class : TypeInfo
{
    ClassInfo info;
}

class TypeInfo_Struct : TypeInfo
{
    char[] name;
    size_t xsize;

    uint function(void*) xtoHash;
    int function(void*,void*) xopEquals;
    int function(void*,void*) xopCmp;
    char[] function(void*) xtoString;
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

