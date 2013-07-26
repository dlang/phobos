// Written in the D programming language.

/**
Macros:
WIKI = Phobos/StdAllocator
MYREF = <font face='Consolas, "Bitstream Vera Sans Mono", "Andale Mono", Monaco, "DejaVu Sans Mono", "Lucida Console", monospace'><a href="#$1">$1</a>&nbsp;</font>

Copyright: Andrei Alexandrescu 2012-.

License: $(WEB boost.org/LICENSE_1_0.txt, Boost License 1.0).

Authors: $(WEB erdani.com, Andrei Alexandrescu)

Source: $(PHOBOSSRC std/_allocator.d)

Allocation models supported:

$(UL
$(LI $(D malloc)/$(D free), unsafe)
$(LI region-based)
$(LI garbage collected)
)
 */
module std.allocator;
import std.conv, std.traits;

/**
Returns the size in bytes of the state that needs to be allocated to hold an
object of type $(D T). $(D stateSize!T) is zero for $(D struct)s that are not
nested and have no nonstatic member variables.
 */
private template stateSize(T)
{
    static if (is(T == class) || is(T == interface))
        enum stateSize = __traits(classInstanceSize, T);
    else
        enum stateSize = FieldTypeTuple!T.length || isNested!T ? T.sizeof : 0;
}

unittest
{
    struct A {}
    static assert(stateSize!A == 0);
    struct B { int x; }
    static assert(stateSize!B == 4);
    interface I1 {}
    static assert(stateSize!I1 == 2 * size_t.sizeof);
    class C1 {}
    static assert(stateSize!C1 == 3 * size_t.sizeof);
    class C2 { char c; }
    static assert(stateSize!C2 == 4 * size_t.sizeof);
    static class C3 { char c; }
    static assert(stateSize!C3 == 2 * size_t.sizeof + char.sizeof);
}

/**
   The safe, garbage-collected allocation model. All pointers and
   references are native.
 */
struct SafeGC
{
    /**
       Pointer to object of type $(D T). If $(D T) has $(D class)
       type, $(D Pointer!T) is $(D T*), not $(D T).
     */
    template OwningPointer(T) { alias T* OwningPointer; }

    /**
       Pointer to object of type $(D T). If $(D T) has $(D class)
       type, $(D Pointer!T) is $(D T*), not $(D T).
     */
    template Pointer(T) { alias T* Pointer; }

    /**
       Reference to object of class type $(D T).
     */
    template OwningRef(T) if (is(T == class)) { alias T Ref; }

    /**
       Reference to object of class type $(D T).
     */
    template Ref(T) if (is(T == class)) { alias T Ref; }

    ubyte[] allocate(size_t bytes)
    {
        import core.memory;
        return (cast(ubyte*) GC.malloc(bytes))[0 .. bytes];
    }
}

unittest
{
    class A { int x = 5; double y = 6; string z = "7"; }
    SafeGC.Ref!A a = SafeGC().create!A();
    assert(a.x == 5 && a.y == 6 && a.z == "7");
}

/**
   The unsafe, $(D malloc)-based allocation model. All pointers and
   references are native, and there is a $(D dispose) primitive.
 */
struct Mallocator
{
    import core.stdc.stdlib;

    /**
       Pointer to object of type $(D T).
     */
    template Pointer(T) { alias Pointer = T*; }

    /**
       Reference to object of class type $(D T).
     */
    template OwningRef(T) if (is(T == class)) { alias Ref = T; }

    /**
       Reference to object of class type $(D T).
     */
    template Ref(T) if (is(T == class)) { alias T Ref; }

    static ubyte[] allocate(size_t bytes)
    {
        return (cast(ubyte*) malloc(bytes))[0 .. bytes];
    }

    static void deallocate(void* p)
    {
        import core.stdc.stdlib;
        free(p);
    }

    static if (is(typeof(malloc_usable_size(null)) : size_t))
    size_t allocatedSize(void* p)
    {
        return malloc_usable_size(p);
    }

    /**
     * Destroy object referred to by $(D handle) (which may be either
     * a pointer or a class reference), and then frees the memory
     * underlying the object. This is by necessity a $(D @system)
     * function.
     */
    @system static void dispose(T)(T* handle)
    {
        clear(handle);
        deallocate(handle);
    }
    @system static void dispose(T)(T handle)
    if (is(T == class) || is(T == interface))
    {
        clear(handle);
        deallocate(cast(void*) handle);
    }
}

unittest
{
    static void test(A)()
    {
        A.Pointer!int p = null;
        p = new int;
        *p = 42;
        assert(*p == 42);
    }

    test!SafeGC();
    test!Mallocator();
}

unittest
{
    static void test(A)()
    {
        SafeGC.Ref!Object p = null;
        p = new Object;
        assert(p !is null);
    }

    test!SafeGC();
    test!Mallocator();
}

unittest
{
    static void test(A)()
    {
        SafeGC a;
        auto p = a.create!Test(42);
        assert(p.a == 43);

        auto p1 = a.create!int(42);
        assert(*p1 == 42);
    }

    test!SafeGC();
    test!Mallocator();
}

unittest
{
    Mallocator a;
    int* p = a.create!int(42);
    a.dispose(p);
    class A {}
    A obj = a.create!A();
    a.dispose(obj);
}

/**
Size tracker on top of any allocator
*/
struct SizeTrackingAllocator(Allocator)
{
    private enum hasState = FieldTypeTuple!(Allocator).length == 0;
    static if (hasState) Allocator _parent;
    else alias _parent = Allocator;

    static ubyte[] allocate(size_t bytes)
    {
        auto result = _parent.allocate(bytes + size_t.sizeof);
        *(cast(size_t*) result.ptr) = bytes;
        return result[size_t.sizeof .. $];
    }

    static void deallocate(void* p)
    {
        _parent.deallocate(cast(size_t*) p - 1);
    }

    static size_t allocatedSize(void* p)
    {
        assert(p);
        return *(cast(size_t*)p - 1);
    }
}

unittest
{
    SizeTrackingAllocator!(Mallocator) a;
    auto p = a.create!int(42);
    assert(a.allocatedSize(p) == 4);
}

struct A { int a; double b; }
struct B { int x; A y; string z; }
pragma(msg, FieldTypeTuple!B);

/**
Freelist allocator, stackable on top of another allocator
*/
struct FreelistAllocator(BaseAlloc, size_t allocUnit)
{
    private enum hasState = FieldTypeTuple!(BaseAlloc).length == 0;
    private struct Node { Node* next; }
    private Node* _freeList;

    static if (hasState) BaseAlloc _parent;
    else alias _parent = BaseAlloc;

    static if (hasState)
        this(BaseAlloc parent)
        {
            _parent = parent;
        }

    /**
       Pointer to object of type $(D T).
     */
    template Pointer(T) { alias Pointer = T*; }

    /**
       Reference to object of class type $(D T).
     */
    template OwningRef(T) if (is(T == class)) { alias Ref = T; }

    /**
       Reference to object of class type $(D T).
     */
    template Ref(T) if (is(T == class)) { alias Ref = T; }

    ubyte[] allocate(size_t bytes)
    {
        if (bytes == allocUnit && _freeList)
        {
            // Pop off the freelist
            auto result = (cast(ubyte*) _freeList)[0 .. allocUnit];
            _freeList = _freeList.next;
            return result;
        }
        // Need to use the parent allocator
        return _parent.allocate(bytes);
    }

    //static if (is(typeof(_parent.allocatedSize(nullptr)) : size_t))
    void deallocate(void* p)
    {
        if (_parent.allocatedSize(p) == allocUnit)
        {
            auto t = _freeList;
            _freeList = cast(Node*) p;
            _freeList.next = t;
        }
        else
        {
            _parent.deallocate(p);
        }
    }

    /**
     * Destroy object referred to by $(D handle) (which may be either
     * a pointer or a class reference), and then frees the memory
     * underlying the object. This is by necessity a $(D @system)
     * function.
     */
    @system void dispose(T)(T* handle)
    {
        auto p = handle;
        clear(p);
        deallocate(handle);
    }
    @system void dispose(T)(T handle)
    if (is(T == class) || is(T == interface))
    {
        void* p = cast(void*) handle;
        clear(handle);
        deallocate(p);
    }
}

unittest
{
    FreelistAllocator!(SizeTrackingAllocator!Mallocator, int.sizeof) a;
    auto p = a.create!int(42);
    assert(*p == 42);
    a.dispose(p);
}

/**  Allocate memory for an object of type $(D T) using allocator $(D alloc)
and then creates it there. Returns a $(D Ref!T) for class objects and a $(D
Pointer!T) otherwise.
 */
auto create(T, Alloc, A...)(auto ref Alloc alloc, auto ref A args)
{
    static if (is(T == class) || is(T == interface))
        enum size = __traits(classInstanceSize, T);
    else
        enum size = T.sizeof;
    auto address = Alloc().allocate(size);
    return emplace!T(cast(void[]) address, args);
}

unittest
{
    int* p = Mallocator().create!int(42);
}

/**
   A doubly-linked list intended as checker for the validity of the
   allocator abstraction. Will migrate to $(D std.container).
 */
struct DList(T, A = SafeGC)
{
    static auto make()
    {
        return DList();
    }

    static struct Node
    {
        private T payload;
        private A.Pointer!Node next, prev;
    }

    @property auto dup()
    {
        if (!_root) return NodePtr.init;
        auto result = A().create!Node(_root.payload, NodePtr.init, NodePtr.init);
        auto last = result;
        for (auto i = _root.next; i; i = i.next)
        {
            auto copy = A().create!Node(i.payload, last, NodePtr.init);
            last.next = copy;
            last = copy;
        }
        // Close the circle
        result.prev = last;
        last.next = result;
        return result;
    }

    static struct Range
    {
        private NodePtr _front, _back;
        @property bool empty()
        {
            return _front == _back;
        }
        @property auto ref front() inout
        {
            return _front.payload;
        }
        @property auto ref back() inout
        {
            return _back.payload;
        }
        void popFront()
        {
            assert(!empty);
            _front = _front.next;
        }
        void popBack()
        {
            assert(!empty);
            _back = _back.prev;
        }
    }

    Range opSlice()
    {
        return Range(_root, _root ? _root.prev : _root);
    }

    @property bool empty() const
    {
        return !_root;
    }

    @property auto ref front()
    {
        assert(!empty);
        return _root.payload;
    }

    unittest
    {
        auto list = DList!T.make();
        assert(list.empty);
    }

    void insert(T obj)
    {
    }

    private alias A.Pointer!Node NodePtr;
    // State
    private A.OwningPointer!Node _root;
}

version(unittest) private class Test
{
    this(int x) { a = x + 1; }
    int a;
}

unittest
{
    static void test(T)()
    {
        auto list = DList!T.make();
        assert(list.empty);
        assert(list[].empty);
        auto copy = list.dup;
    }

    test!int();
    test!Test();
}
