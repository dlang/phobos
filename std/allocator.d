// Written in the D programming language.

/**
Macros:
WIKI = Phobos/StdAllocator
MYREF = <font face='Consolas, "Bitstream Vera Sans Mono", "Andale Mono", Monaco, "DejaVu Sans Mono", "Lucida Console", monospace'><a href="#$1">$1</a>&nbsp;</font>

Copyright: Andrei Alexandrescu 2012-.

License: $(WEB boost.org/LICENSE_1_0.txt, Boost License 1.0).

Authors: $(WEB erdani.com, Andrei Alexandrescu)

Source: $(PHOBOSSRC std/_allocator.d)
 */
module std.allocator;
import std.conv, std.traits;

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
    template OwningPointer(T) { alias T* Pointer; }

    /**
       Pointer to object of type $(D T). If $(D T) has $(D class)
       type, $(D Pointer!T) is $(D T*), not $(D T).
     */
    template Pointer(T) { alias T* Pointer; }

    /**
       Reference to object of class type $(D T).
     */
    template Ref(T) if (is(T == class)) { alias T Ref; }

    /**
       Allocate memory for an object of type $(D T) and then creates
       it there. Returns a $(D Ref!T) for class objects and a $(D
       Pointer!T) otherwise.
    */
    @trusted static auto create(T, A...)(auto ref A args)
    {
        import core.memory;
        static if (is(T == class))
        {
            enum size = __traits(classInstanceSize, T);
            auto raw = (cast(void*) GC.malloc(size))[0 .. size];
        }
        else
        {
            auto raw = cast(T*) GC.malloc(T.sizeof);
        }
        return emplace!T(raw, args);
    }
}

/**
   The unsafe, $(D malloc)-based allocation model. All pointers and
   references are native, and there is a $(D dispose) primitive.
 */
struct Mallocator
{
    /**
       Pointer to object of type $(D T).
     */
    template Pointer(T) { alias T* Pointer; }

    /**
       Reference to object of class type $(D T).
     */
    template Ref(T) if (is(T == class)) { alias T Ref; }

    /**
       Allocateemplace memory for an object of type $(D T) and then creates
       it there. Returns a $(D Ref!T) for class objects and a $(D
       Pointer!T) otherwise.
    */
    static auto create(T, A...)(auto ref A args)
    {
        enum size = is(T == class) ? __traits(classInstanceSize, T) : T.sizeof;
        auto address = malloc(T.sizeof);
        return emplace(address, args);
    }

    /**
     * Destroy object referred to by $(D handle) (which may be either
     * a pointer or a class reference), and then frees the memory
     * underlying the object. This is by necessity a $(D @system)
     * function.
     */
    @system void dispose(T)(Pointer!T handle)
    {
        clear(handle);
        free(handle);
    }
    @system void dispose(T)(Ref!T handle)
    {
        clear(handle);
        free(handle);
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

    private alias A.Pointer!Node NodePtr;

    private A.OwningPointer!Node _root;

    @property auto dup()
    {
        if (!_root) return NodePtr.init;
        auto result = A.create!Node(_root.payload, NodePtr.init, NodePtr.init);
        auto last = result;
        for (auto i = _root.next; i; i = i.next)
        {
            auto copy = A.create!Node(i.payload, last, NodePtr.init);
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
