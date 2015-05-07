// Written in the D programming language.

module std.experimental.allocator.typed;
import std.algorithm, std.experimental.allocator, std.range, std.stdio, std.traits, std.conv;

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
        if (!block.ptr) return;
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
        if (!m.ptr) return null;
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
        if (!hunk.ptr) return;
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
