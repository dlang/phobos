// Written in the D programming language.

module std.typed_allocator;
import std.algorithm, std.allocator, std.range, std.stdio, std.traits, std.conv;

/**
*/
auto make(T, Allok, A...)(auto ref Allok allok, auto ref A args)
if (!isDynamicArray!T)
{
    auto m = allok.allocate(max(stateSize!T, 1));
    if (!m) return null;
    static if (is(T == class)) return emplace!T(m, args);
    else return emplace(cast(T*) m.ptr, args);
}

unittest
{
    alias Al = GCAllocator;

    int* a = Al.it.make!int(10);
    assert(*a == 10);

    struct A
    {
        int x;
        string y;
        double z;
    }

    A* b = Al.it.make!A(42);
    assert(b.x == 42);
    assert(b.y is null);
    import std.math;
    assert(b.z.isnan);

    b = Al.it.make!A(43, "44", 45);
    assert(b.x == 43);
    assert(b.y == "44");
    assert(b.z == 45);

    static class B
    {
        int x;
        string y;
        double z;
        this(int _x, string _y = null, double _z = double.init)
        {
            x = _x;
            y = _y;
            z = _z;
        }
    }

    B c = Al.it.make!B(42);
    assert(c.x == 42);
    assert(c.y is null);
    import std.math;
    assert(c.z.isnan);

    c = Al.it.make!B(43, "44", 45);
    assert(c.x == 43);
    assert(c.y == "44");
    assert(c.z == 45);

    //int[] arr = Al.it.make!(int[])(42, 43);
}

auto makeArray(T, Allok, A...)(auto ref Allok allok, auto ref A args)
//if (isDynamicArray!T)
{
    size_t len = 0;
    foreach (i, ref e; args)
    {
        static if (is(typeof({ int x = e; }))) ++len;
        else len += e.save.walkLength;
    }
    auto m = allok.allocate(T.sizeof * len);
    if (!m) return null;
    auto result = cast(T[]) m;
    size_t i = 0;
    scope (failure)
    {
        foreach (j; 0 .. i)
        {
            destroy(result[j]);
        }
        allok.deallocate(m);
    }
    foreach (ref e; args)
    {
        static if (is(typeof({ int x = e; })))
        {
            emplace!T(result.ptr + i, e);
            ++i;
        }
        else
        {
            for (; !e.empty; e.popFront)
            {
                emplace!T(result.ptr + i, e.front);
                ++i;
            }
        }
    }
    return result;
}

unittest
{
    alias Al = GCAllocator;
    auto a = Al.it.makeArray!int(1, 2, 3, 4);
    assert(a.equal([1, 2, 3, 4]));
    a = Al.it.makeArray!int(1, repeat(2).take(3), 4);
    assert(a.equal([1, 2, 2, 2, 4]));
}

/**
*/
struct TypedAllocator
(
    ThreadLocalHeap,
    // More to follow
)
{
    // Header for data with no destructors
    private struct Header
    {
        void function(TypedAllocator*, void* p, void[] hunk) scan;
    }
    private alias Heap = AffixAllocator!(ThreadLocalHeap, Header);
    static if (stateSize!Heap) private Heap heap;
    else private alias heap = Heap.it;

    private void scanIndirect(T)(void* p, void[] block) if (is(T == struct))
    {
        if (!block) return;
        assert(p);
        //assert(block.ptr <= p && p < block.ptr + block.length);

        // obj refers to the full object inside which p was found
        auto obj = cast(T*) block.ptr;

        // For now let's mark the entire block as used regardless of where p is
        // sitting
        if (!heap.markAsUsed(block))
        {
            // Not falling for it.
            writefln("Already scanned %s @ 0x%s", T.stringof, cast(void*) obj);
            return;
        }

        writefln("Scanning %s @ 0x%s conservatively", T.stringof, block.ptr);
        foreach (ref f; obj.tupleof)
        {
            static if (hasIndirections!(typeof(f)))
                scanDirect!(typeof(f))(f);
        }
    }

    private void scanIndirect(T)(void* p, void[] block) if (is(T == class))
    {
        if (!block) return;
        assert(p);
        assert(block.ptr <= p && p < block.ptr + block.length);

        // obj refers to the full object inside which p was found
        auto obj = cast(T) block.ptr;

        // For now let's mark the entire block as used regardless of where p is
        // sitting
        if (!heap.markAsUsed(block))
        {
            // Not falling for it.
            writefln("Already scanned %s @ 0x%s", T.stringof, cast(void*) obj);
            return;
        }

        writefln("Scanning %s @ 0x%s conservatively",
            T.stringof, cast(void*) obj);
        foreach (ref f; obj.tupleof)
        {
            static if (hasIndirections!(typeof(f)))
                scanDirect!(typeof(f))(f);
        }
    }

    // Scan is precise if block is null, conservative otherwise
    private void scanIndirect(T)(void* p, void[] block)
    if (isDynamicArray!T)
    {
        if (!array) return;
        assert(block);
        writefln("Scanning %s @ 0x%s of length %s",
            T.stringof, cast(void*) block.ptr, block.length);
        static if (hasIndirections!T)
            foreach (ref e; p)
            {
                static if (hasIndirections!(typeof(f))) scan(f);
            }
    }

    private void scanDirect(T)(ref T p)
    {
        writefln("Scanning %s @ 0x%s directly",
            T.stringof, cast(void*) &p);
    }

    this(ThreadLocalHeap h)
    {
        heap = Heap(h);
    }

    auto make(T, A...)(auto ref A args) if (is(T == struct))
    {
        auto m = heap.allocate(T.sizeof);
        if (!m) return null;
        auto p = &heap.prefix(m);

        static void scanImpl(TypedAllocator* allok, void* p, void[] obj)
        {
            writeln(__FUNCTION__ ," {");
            scope(exit) writeln("}");
            allok.scanIndirect!T(p, obj);
        }

        p.scan = &scanImpl;
        return emplace(cast(T*) m.ptr, args);
    }

    void scanConservatively(size_t word)
    {
        if (!word) return;
        auto hunk = heap.resolveInternalPointer(cast(void*) word);
        if (!hunk) return;
        auto p = &heap.prefix(hunk);
        p.scan(&this, p, hunk);
    }
}

unittest
{
    static struct A
    {
        int a;
        int* b;
        double[] c;
        A* next;
    }

    auto heap = HeapBlockWithInternalPointers!128(new void[1024 * 1024]);
    auto allok = TypedAllocator!(HeapBlockWithInternalPointers!128)(heap);
    //A obj = { 42, new int(43), new double[100] };
    //allok.scanConservatively(cast(size_t) &obj);
    auto p = allok.make!A(42, new int(43), new double[100]);
    assert(p);
    // Create a pointer to self (cycle)
    p.next = p;

    // Start tracing
    allok.heap.markAllAsUnused();
    allok.scanConservatively(cast(size_t) p);
    allok.heap.doneMarking();
}
