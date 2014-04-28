// Written in the D programming language.

module std.typed_allocator;
import std.allocator, std.stdio, std.traits;

struct TypedAllocator
(
    ThreadLocalHeap,
    //ThreadLocalTracingHeap,
    //SharedHeap
)
{
    ThreadLocalHeap tlHeap;
    //ThreadLocalTracingHeap tlTracingHeap;
    //SharedHeap shHeap;

    // Header for data with no destructors
    struct Header
    {
        void function(TypedAllocator*) scan;
        ulong function(void* addr, uint action) dispatch;
        bool marked;
    }
    alias Heap = AffixAllocator!(ThreadLocalHeap, Header);
    Heap heap;

    struct DtorHeader
    {
        void function(void*) dtor;
    }

    auto make(T, A...)(auto ref A args) if (is(T == struct))
    {
        void[] m = void;
        static if (hasIndirections!T)
        {
            // Allocate on the tracing heap
            static if (hasElaborateDestructor!T)
            {
                m = heap.allocate(T.sizeof);
            }
            else
            {
                m = heap.allocate(T.sizeof);
            }
        }
        else
        {
            // Allocate on the non-tracing heap
            m = heap.allocate(T.sizeof);
        }
        auto p = &heap.prefix(m);
        p.marked = false;
        p.dispatch = dispatchImpl!T;
    }

    void scan(T)(T* p)
    {
        writefln("Scanning %s @ 0x%s", (T*).stringof, cast(void*) p);
        static if (hasIndirections!(typeof(*p)))
            foreach (ref f; (*p).tupleof)
            {
                static if (hasIndirections!(typeof(f))) scan(f);
            }
    }

    void scan(T)(T[] p)
    {
        writefln("Scanning %s @ 0x%s of length %s",
            (T[]).stringof, cast(void*) p.ptr, p.length);
    }

    void scanConservatively(size_t word)
    {

    }
}

private void scanImpl(T)(TypedAllocator!GCAllocator* allok, void* obj)
{
    allok.scan(cast(T*) obj);
}

unittest
{
    static struct A
    {
        int a;
        int* b;
    }

    TypedAllocator!GCAllocator allok;
    A obj = { 42, new int(43) };
    scanImpl!A(&allok, cast(void*) &obj);
}
