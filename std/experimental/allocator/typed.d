/**

High-level interface for allocators. Implements bundled allocation/creation
and destruction/deallocation of data including $(D struct)s and $(D class)es,
and also array primitives related to allocation.

---
// Allocate an int, initialize it with 42
int* p = theAllocator.make!int(42);
assert(*p == 42);
// Destroy and deallocate it
theAllocator.dispose(p);

// Allocate using the global process allocator
p = processAllocator.make!int(100);
assert(*p == 100);
// Destroy and deallocate
processAllocator.dispose(p);

// Create an array of 50 doubles initialized to -1.0
double[] arr = theAllocator.makeArray!double(50, -1.0);
// Append two zeros to it
theAllocator.growArray(arr, 2, 0.0);
// On second thought, take that back
theAllocator.shrinkArray(arr, 2);
// Destroy and deallocate
theAllocator.dispose(arr);
---

Macros:
T2=$(TR <td style="text-align:left">$(D $1)</td> $(TD $(ARGS $+)))
*/

module std.experimental.allocator.typed;

import std.experimental.allocator.common;
import std.traits : isPointer, hasElaborateDestructor;
import std.typecons : Flag, Yes, No;
import std.algorithm : min;
import std.range : isInputRange, isForwardRange, walkLength, save, empty,
    front, popFront;

/**
Allocation flags. These are deduced from the type being allocated.
*/
enum AllocFlag : uint
{
    init = 0,
    /**
    Fixed-size allocation (unlikely to get reallocated later). Examples: `int`,
    `double`, any `struct` or `class` type. By default it is assumed that the
    allocation is variable-size, i.e. susceptible to later reallocation
    (for example all array types). This flag is advisory, i.e. in-place resizing
    may be attempted for `fixedSize` allocations and may succeed. The flag is
    just a hint to the compiler it may use allocation strategies that work well
    with objects of fixed size.
    */
    fixedSize = 1,
    /**
    The type being allocated embeds no pointers. Examples: `int`, `int[]`, $(D
    Tuple!(int, float)). The implicit conservative assumption is that the type
    has members with indirections so it needs to be scanned if garbage
    collected. Example of types with pointers: `int*[]`, $(D Tuple!(int,
    string)).
    */
    hasNoPointers = 4,
    /**
    By default it is conservatively assumed that allocated memory may be `cast`
    to `shared`, passed across threads, and deallocated in a different thread
    than the one that allocated it. If that's not the case, there are two
    options. First, `immutableShared` means the memory is allocated for
    `immutable` data and will be deallocated in the same thread it was
    allocated in. Second, `threadLocal` means the memory is not to be shared
    across threads at all. The two flags cannot be simultaneously present.
    */
    immutableShared = 8,
    /// ditto
    threadLocal = 16,
}

/**
`TypedAllocator` acts like a chassis on which several specialized allocators
can be assembled. To let the system make a choice about a particular kind of
allocation, use `Default` for the respective parameters.

There is a hierarchy of allocation kinds. When an allocator is implemented for
a given combination of flags, it is used. Otherwise, the next down the list is
chosen.

$(BOOKTABLE ,

$(TR $(TH `AllocFlag` combination) $(TH Description))

$(T2 AllocFlag.threadLocal |$(NBSP)AllocFlag.hasNoPointers
|$(NBSP)AllocFlag.fixedSize,
This is the most specific allocation policy: the memory being allocated is
thread local, has no indirections at all, and will not be reallocated. Examples
of types fitting this description: `int`, `double`, $(D Tuple!(int, long)), but
not $(D Tuple!(int, string)), which contains an indirection.)

$(T2 AllocFlag.threadLocal |$(NBSP)AllocFlag.hasNoPointers,
As above, but may be reallocated later. Examples of types fitting this
description are $(D int[]), $(D double[]), $(D Tuple!(int, long)[]), but not
$(D Tuple!(int, string)[]), which contains an indirection.)

$(T2 AllocFlag.threadLocal,
As above, but may embed indirections. Examples of types fitting this
description are $(D int*[]), $(D Object[]), $(D Tuple!(int, string)[]).)

$(T2 AllocFlag.immutableShared |$(NBSP)AllocFlag.hasNoPointers
|$(NBSP)AllocFlag.fixedSize,
The type being allocated is `immutable` and has no pointers. The thread that
allocated it must also deallocate it. Example: `immutable(int)`.)

$(T2 AllocFlag.immutableShared |$(NBSP)AllocFlag.hasNoPointers,
As above, but the type may be appended to in the future. Example: `string`.)

$(T2 AllocFlag.immutableShared,
As above, but the type may embed references. Example: `immutable(Object)[]`.)

$(T2 AllocFlag.hasNoPointers |$(NBSP)AllocFlag.fixedSize,
The type being allocated may be shared across threads, embeds no indirections,
and has fixed size.)

$(T2 AllocFlag.hasNoPointers,
The type being allocated may be shared across threads, may embed indirections,
and has variable size.)

$(T2 AllocFlag.fixedSize,
The type being allocated may be shared across threads, may embed indirections,
and has fixed size.)

$(T2 0, The most conservative/general allocation: memory may be shared,
deallocated in a different thread, may or may not be resized, and may embed
references.)

)

Params:
PrimaryAllocator = The default allocator.
Policies = Zero or more pairs consisting of an `AllocFlag` and an allocator
type.
*/
struct TypedAllocator(PrimaryAllocator, Policies...)
{
    import std.typecons : Tuple;
    import std.meta : Arguments;
    import std.algorithm.sorting : isSorted;

    static assert(isSorted([Stride2!Policies]));

    template Stride2(T...)
    {
        static if (T.length >= 2)
        {
            alias Stride2 = Arguments!(T[0], Stride2!(T[2 .. $]));
        }
        else
        {
            alias Stride2 = Arguments!(T[0 .. $]);
        }
    }

    // state {
    static if (stateSize!PrimaryAllocator) PrimaryAllocator primary;
    else alias primary = PrimaryAllocator.it;
    Tuple!(Stride2!(Policies[1 .. $])) extras;
    // }

    //pragma(msg, "Allocators available: ", typeof(extras));

    private static bool match(uint have, uint want)
    {
        enum uint maskAway =
            ~(AllocFlag.immutableShared | AllocFlag.threadLocal);
        // Do we offer thread local?
        if (have & AllocFlag.threadLocal)
        {
            if (want & AllocFlag.threadLocal)
                return match(have & maskAway, want & maskAway);
            return false;
        }
        if (have & AllocFlag.immutableShared)
        {
            // Okay to ask for either thread local or immutable shared
            if (want & (AllocFlag.threadLocal
                    | AllocFlag.immutableShared))
                return match(have & maskAway, want & maskAway);
            return false;
        }
        // From here on we have full-blown thread sharing.
        if (have & AllocFlag.hasNoPointers)
        {
            if (want & AllocFlag.hasNoPointers)
                return match(have & ~AllocFlag.hasNoPointers,
                    want & ~AllocFlag.hasNoPointers);
            return false;
        }
        // Fixed size or variable size both match.
        return true;
    }

    auto ref allocatorFor(uint flags)()
    {
        static if (!match(Policies[0], flags))
        {
            return primary;
        }
        else static if (match(Policies[$ - 2], flags))
        {
            return extras[$ - 1];
        }
        else
        {
            foreach (i, choice; Stride2!Policies)
            {
                static if (!match(choice, flags))
                {
                    return extras[i - 1];
                }
            }
            assert(0);
        }
    }

    static uint type2flags(T)()
    {
        uint result;
        static if (is(T == immutable))
            result |= AllocFlag.immutableShared;
        else static if (is(T == shared))
            result |= AllocFlag.forSharing;
        static if (is(T == U[], U))
            result |= AllocFlag.variableSize;
        import std.traits : hasPointers;
        static if (hasPointers!T)
            result |= AllocFlag.hasPointers;
        return result;
    }
}

unittest
{
    import std.experimental.allocator.gc_allocator;
    import std.experimental.allocator.mallocator;
    import std.experimental.allocator.mmap_allocator;
    alias MyAllocator = TypedAllocator!(GCAllocator,
        AllocFlag.fixedSize | AllocFlag.threadLocal, Mallocator,
        AllocFlag.fixedSize | AllocFlag.threadLocal
                | AllocFlag.hasNoPointers,
            MmapAllocator,
    );
    MyAllocator a;
    auto b = &a.allocatorFor!0();
    static assert(is(typeof(*b) == shared GCAllocator));
    enum f1 = AllocFlag.fixedSize | AllocFlag.threadLocal;
    auto c = &a.allocatorFor!f1();
    static assert(is(typeof(*c) == Mallocator));
    enum f2 = AllocFlag.fixedSize | AllocFlag.threadLocal;
    static assert(is(typeof(a.allocatorFor!f2()) == Mallocator));
    // Partial match
    enum f3 = AllocFlag.threadLocal;
    static assert(is(typeof(a.allocatorFor!f3()) == Mallocator));
}
