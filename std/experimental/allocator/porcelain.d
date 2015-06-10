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

*/

module std.experimental.allocator.porcelain;

// Example in intro above
unittest
{
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
}

import std.experimental.allocator.common;
import std.traits : isPointer, hasElaborateDestructor;
import std.typecons : Flag, Yes, No;
import std.algorithm : min;
import std.range : isInputRange, isForwardRange, walkLength, save, empty,
    front, popFront;

// fixedSize vs. variableSize
// threadLocal vs. forSharing vs. forImmutable
// hasPointers vs. hasNoPointers

enum SizePolicy : uint
{
    variableSize = 0,
    fixedSize = 1,
}

enum SharingPolicy : uint
{
    threadShared = 0,
    threadLocal = 4,
    immutableShared = 8,
}

enum DepthPolicy
{
    hasPointers = 0,
    hasNoPointers = 16
}

unittest
{
    auto a = SizePolicy.fixedSize | DepthPolicy.hasNoPointers;
    assert(a & SizePolicy.fixedSize);
    assert(a & DepthPolicy.hasNoPointers);
}

/**
`TypedAllocator` acts like a chassis on which several specialized allocators
can be assembled. To let the system make a choice about a particular kind of
allocation, use `Default` for the respective parameters.

Params:
Fixed = Allocator to use for fixed-size allocations. These are unklikely to
change size during the data's lifetime, so an allocator with poor resizing
performance but good fixed-size performance would be indicated.

FixedLeaf = Allocator to use for fixed-size allocations of data that has no
indirections (for example, `int` or $(D Tuple!(int, float))). This means
tracing collectors do not need to scan data allocated with this allocator for
further indirections.

Resizable = Allocator to use for allocating resizable data, such as arrays.
Following allocation, the data may grow or shrink during its lifetime. A
quantized allocator that overallocates to offer expansion and contraction
without moving memory would be a good fit.

ResizableLeaf = Allocator to use for allocating resizable data that contains no
pointers (for example, `int[]` or $(D Algebraic!(int, double))).

Shared = Allocator to use for memory that may be shared or transferred across
threads. Data allocated within one thread can be deallocated from a different
thread. All other allocators may assume they allocate thread-local data.

Immutable = Allocator to use for memory that will become immutable after
initialization. Immutable data may be shared across threads without
interlocking, but must always be deallocated in the same thread it was
allocated in.
*/
struct TypedAllocator(PrimaryAllocator, Policies...)
{
    import std.typecons : Tuple;
    import std.meta : Arguments;
    import std.algorithm.sorting : isSorted;

    static assert(isSorted([Stride2!Policies]));

    PrimaryAllocator primary;
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
    Tuple!(Stride2!(Policies[1 .. $])) extras;
    pragma(msg, typeof(extras));

    auto ref allocatorFor(uint flags)()
    {
        import std.algorithm.comparison : among;
        static if (flags.among(Stride2!Policies))
        {
            foreach (i, choice; Stride2!Policies)
            {
                static if (choice == flags) return extras[i];
            }
            assert(0);
        }
        else
        {
            return primary;
        }
    }
}

unittest
{
    import std.experimental.allocator.gc_allocator;
    import std.experimental.allocator.mallocator;
    import std.experimental.allocator.mmap_allocator;
    alias MyAllocator = TypedAllocator!(GCAllocator,
        SizePolicy.fixedSize | SharingPolicy.threadLocal, Mallocator,
        SizePolicy.fixedSize | SharingPolicy.threadLocal
                | DepthPolicy.hasNoPointers,
            MmapAllocator,
    );
    MyAllocator a;
    static assert(is(typeof(a.allocatorFor!0()) == GCAllocator));
    enum f1 = SizePolicy.fixedSize | SharingPolicy.threadLocal;
    static assert(is(typeof(a.allocatorFor!f1()) == Mallocator));
    enum f2 = SizePolicy.fixedSize | SharingPolicy.threadLocal
                | DepthPolicy.hasNoPointers;
    static assert(is(typeof(a.allocatorFor!f1()) == Mallocator));
}

/**
Dynamically allocates (using $(D alloc)) and then creates in the memory
allocated an object of type $(D T), using $(D args) (if any) for its
initialization. Initialization occurs in the memory allocated and is otherwise
semantically the same as $(D T(args)).
(Note that using $(D alloc.make!(T[])) creates a pointer to an (empty) array
of $(D T)s, not an array. To use an allocator to allocate and initialize an
array, use $(D alloc.makeArray!T) described below.)

Params:
T = Type of the object being created.
alloc = The allocator used for getting the needed memory. It may be an object
implementing the static interface for allocators, or an $(D IAllocator)
reference.
args = Optional arguments used for initializing the created object. If not
present, the object is default constructed.

Returns: If $(D T) is a class type, returns a reference to the created $(D T)
object. Otherwise, returns a $(D T*) pointing to the created object. In all
cases, returns $(D null) if allocation failed.

Throws: If $(D T)'s constructor throws, deallocates the allocated memory and
propagates the exception.
*/
auto make(T, Allocator, A...)(auto ref Allocator alloc, auto ref A args)
{
    import std.algorithm : max;
    import std.conv : emplace;
    auto m = alloc.allocate(max(stateSize!T, 1));
    if (!m.ptr) return null;
    scope(failure) alloc.deallocate(m);
    static if (is(T == class)) return emplace!T(m, args);
    else return emplace(cast(T*) m.ptr, args);
}

///
unittest
{
    // Dynamically allocate one integer
    int* p1 = theAllocator.make!int;
    // It's implicitly initialized with its .init value
    assert(*p1 == 0);
    // Dynamically allocate one double, initialize to 42.5
    double* p2 = theAllocator.make!double(42.5);
    assert(*p2 == 42.5);

    // Dynamically allocate a struct
    static struct Point
    {
        int x, y, z;
    }
    // Use the generated constructor taking field values in order
    Point* p = theAllocator.make!Point(1, 2);
    assert(p.x == 1 && p.y == 2 && p.z == 0);

    // Dynamically allocate a class object
    static class Customer
    {
        uint id = uint.max;
        this() {}
        this(uint id) { this.id = id; }
        // ...
    }
    Customer cust = theAllocator.make!Customer;
    assert(cust.id == uint.max); // default initialized
    cust = theAllocator.make!Customer(42);
    assert(cust.id == 42);
}

unittest
{
    void test(Allocator)(auto ref Allocator alloc)
    {
        int* a = alloc.make!int(10);
        assert(*a == 10);

        struct A
        {
            int x;
            string y;
            double z;
        }

        A* b = alloc.make!A(42);
        assert(b.x == 42);
        assert(b.y is null);
        import std.math;
        assert(b.z.isNaN);

        b = alloc.make!A(43, "44", 45);
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

        B c = alloc.make!B(42);
        assert(c.x == 42);
        assert(c.y is null);
        import std.math;
        assert(c.z.isNaN);

        c = alloc.make!B(43, "44", 45);
        assert(c.x == 43);
        assert(c.y == "44");
        assert(c.z == 45);

        auto parray = alloc.make!(int[]);
        assert((*parray).empty);
    }

    import std.experimental.allocator.gc_allocator : GCAllocator;
    test(GCAllocator.it);
    test(theAllocator);
}

private void fillWithMemcpy(T)(void[] array, auto ref T filler) nothrow
{
    import core.stdc.string : memcpy;
    if (!array.length) return;
    memcpy(array.ptr, &filler, T.sizeof);
    // Fill the array from the initialized portion of itself exponentially.
    for (size_t offset = T.sizeof; offset < array.length; )
    {
        size_t extent = min(offset, array.length - offset);
        memcpy(array.ptr + offset, array.ptr, extent);
        offset += extent;
    }
}

unittest
{
    int[] a;
    fillWithMemcpy(a, 42);
    assert(a.length == 0);
    a = [ 1, 2, 3, 4, 5 ];
    fillWithMemcpy(a, 42);
    assert(a == [ 42, 42, 42, 42, 42]);
}

private T[] uninitializedFillDefault(T)(T[] array) nothrow
{
    static immutable __gshared T t;
    fillWithMemcpy(array, t);
    return array;
}

unittest
{
    int[] a = [1, 2, 4];
    uninitializedFillDefault(a);
    assert(a == [0, 0, 0]);
}

/**
Create an array of $(D T) with $(D length) elements using $(D alloc). The array is either default-initialized, filled with copies of $(D init), or initialized with values fetched from $(R range).

Params:
T = element type of the array being created
alloc = the allocator used for getting memory
length = length of the newly created array
init = element used for filling the array
range = range used for initializing the array elements

Returns:
The newly-created array, or $(D null) if either $(D length) was $(D 0) or
allocation failed.

Throws:
The first two overloads throw only if $(T alloc)'s primitives do. The
overloads that involve copy initialization deallocate memory and propagate the
exception if the copy operation throws.
*/
T[] makeArray(T, Allocator)(auto ref Allocator alloc, size_t length)
{
    if (!length) return null;
    auto m = alloc.allocate(T.sizeof * length);
    if (!m.ptr) return null;
    return uninitializedFillDefault(cast(T[]) m);
}

unittest
{
    void test(A)(auto ref A alloc)
    {
        int[] a = alloc.makeArray!int(0);
        assert(a.length == 0 && a.ptr is null);
        a = alloc.makeArray!int(5);
        assert(a.length == 5);
        assert(a == [ 0, 0, 0, 0, 0]);
    }
    import std.experimental.allocator.gc_allocator : GCAllocator;
    test(GCAllocator.it);
    test(theAllocator);
}

/// Ditto
T[] makeArray(T, Allocator)(auto ref Allocator alloc, size_t length,
    auto ref T init)
{
    if (!length) return null;
    auto m = alloc.allocate(T.sizeof * length);
    if (!m.ptr) return null;
    auto result = cast(T[]) m;
    import std.traits : hasElaborateCopyConstructor;
    static if (hasElaborateCopyConstructor!T)
    {
        scope(failure) alloc.deallocate(m);
        size_t i = 0;
        static if (hasElaborateDestructor!T)
        {
            scope (failure)
            {
                foreach (j; 0 .. i)
                {
                    destroy(result[j]);
                }
            }
        }
        for (; i < length; ++i)
        {
            emplace!T(result.ptr + i, init);
        }
    }
    else
    {
        fillWithMemcpy(result, init);
    }
    return result;
}

///
unittest
{
    int[] a = theAllocator.makeArray!int(2);
    assert(a == [0, 0]);
    a = theAllocator.makeArray!int(3, 42);
    assert(a == [42, 42, 42]);
    import std.range : only;
    a = theAllocator.makeArray!int(only(42, 43, 44));
    assert(a == [42, 43, 44]);
}

unittest
{
    void test(A)(auto ref A alloc)
    {
        long[] a = alloc.makeArray!long(0, 42);
        assert(a.length == 0 && a.ptr is null);
        a = alloc.makeArray!long(5, 42);
        assert(a.length == 5);
        assert(a == [ 42, 42, 42, 42, 42 ]);
    }
    import std.experimental.allocator.gc_allocator : GCAllocator;
    test(GCAllocator.it);
    test(theAllocator);
}

/// Ditto
T[] makeArray(T, Allocator, R)(auto ref Allocator alloc, R range)
if (isInputRange!R)
{
    static if (isForwardRange!R)
    {
        size_t length = walkLength(range.save);
        if (!length) return null;
        auto m = alloc.allocate(T.sizeof * length);
        if (!m.ptr) return null;
        auto result = cast(T[]) m;

        size_t i = 0;
        scope (failure)
        {
            foreach (j; 0 .. i)
            {
                destroy(result[j]);
            }
            alloc.deallocate(m);
        }

        for (; !range.empty; range.popFront, ++i)
        {
            import std.conv : emplace;
            emplace!T(result.ptr + i, range.front);
        }

        return result;
    }
    else
    {
        // Estimated size
        size_t estimated = 8;
        auto m = alloc.allocate(T.sizeof * estimated);
        if (!m.ptr) return null;
        auto result = cast(T[]) m;

        size_t initialized = 0;
        void bailout()
        {
            foreach (i; 0 .. initialized)
            {
                destroy(result[i]);
            }
            alloc.deallocate(m);
        }
        scope (failure) bailout;

        for (; !range.empty; range.popFront, ++initialized)
        {
            if (initialized == estimated)
            {
                // Need to reallocate
                if (!alloc.reallocate(m, T.sizeof * (estimated *= 2)))
                {
                    bailout;
                    return null;
                }
                result = cast(T[]) m;
            }
            import std.conv : emplace;
            emplace!T(result.ptr + initialized, range.front);
        }

        // Try to shrink memory, no harm if not possible
        if (initialized < estimated
            && alloc.reallocate(m, T.sizeof * initialized))
        {
            result = cast(T[]) m;
        }

        return result[0 .. initialized];
    }
}

unittest
{
    void test(A)(auto ref A alloc)
    {
        long[] a = alloc.makeArray!long((int[]).init);
        assert(a.length == 0 && a.ptr is null);
        a = alloc.makeArray!long([5, 42]);
        assert(a.length == 2);
        assert(a == [ 5, 42]);
    }
    import std.experimental.allocator.gc_allocator : GCAllocator;
    test(GCAllocator.it);
    test(theAllocator);
}

version(unittest)
{
    private struct ForcedInputRange
    {
        int[]* array;
        bool empty() { return !array || (*array).empty; }
        ref int front() { return (*array)[0]; }
        void popFront() { *array = (*array)[1 .. $]; }
    }
}

unittest
{
    import std.array, std.range;
    int[] arr = iota(10).array;

    void test(A)(auto ref A alloc)
    {
        ForcedInputRange r;
        long[] a = alloc.makeArray!long(r);
        assert(a.length == 0 && a.ptr is null);
        auto arr2 = arr;
        r.array = &arr2;
        a = alloc.makeArray!long(r);
        assert(a.length == 10);
        assert(a == iota(10).array);
    }
    import std.experimental.allocator.gc_allocator : GCAllocator;
    test(GCAllocator.it);
    test(theAllocator);
}

/**
Grows $(D array) by appending $(D delta) more elements. The needed memory is
allocated using $(D alloc). The extra elements added are either default-initialized, filled with copies of $(D init), or initialized with values fetched from $(R range).

Params:
T = element type of the array being created
alloc = the allocator used for getting memory
array = a reference to the array being grown
delta = number of elements to add (upon success the new length of $(D array) is $(D array.length + delta))
init = element used for filling the array
range = range used for initializing the array elements

Returns:
$(D true) upon success, $(D false) if memory could not be allocated. In the latter case $(D array) is left unaffected.

Throws:
The first two overloads throw only if $(T alloc)'s primitives do. The
overloads that involve copy initialization deallocate memory and propagate the
exception if the copy operation throws.
*/
bool growArray(T, Allocator)(auto ref Allocator alloc, ref T[] array,
        size_t delta)
{
    if (!delta) return true;
    immutable oldLength = array.length;
    void[] buf = array;
    if (!alloc.reallocate(buf, buf.length + T.sizeof * delta)) return false;
    array = cast(T[]) buf;
    array[oldLength .. $].uninitializedFillDefault;
    return true;
}

unittest
{
    void test(A)(auto ref A alloc)
    {
        auto arr = alloc.makeArray!int([1, 2, 3]);
        assert(alloc.growArray(arr, 3));
        assert(arr == [1, 2, 3, 0, 0, 0]);
    }
    import std.experimental.allocator.gc_allocator : GCAllocator;
    test(GCAllocator.it);
    test(theAllocator);
}

/// Ditto
auto growArray(T, Allocator)(auto ref Allocator alloc, T[] array,
    size_t delta, auto ref T init)
{
    if (!delta) return true;
    void[] buf = array;
    if (!alloc.reallocate(buf, buf.length + T.sizeof * delta)) return false;
    immutable oldLength = array.length;
    array = cast(T[]) buf;
    scope(failure) array[oldLength .. $].uninitializedFillDefault;
    import std.algorithm : uninitializedFill;
    array[oldLength .. $].uninitializedFill(init);
    return true;
}

/// Ditto
auto growArray(T, Allocator, R)(auto ref Allocator alloc, ref T[] array,
        R range)
if (isInputRange!R)
{
    static if (isForwardRange!R)
    {
        immutable delta = walkLength(range.save);
        if (!delta) return true;
        immutable oldLength = array.length;

        // Reallocate support memory
        void[] buf = array;
        if (!alloc.reallocate(buf, buf.length + T.sizeof * delta))
        {
            return false;
        }
        array = cast(T[]) buf;
        // At this point we're committed to the new length.

        auto toFill = array[oldLength .. $];
        scope (failure)
        {
            // Fill the remainder with default-constructed data
            toFill.uninitializedFillDefault;
        }

        for (; !range.empty; range.popFront, toFill.popFront)
        {
            assert(!toFill.empty);
            import std.conv : emplace;
            emplace!T(&toFill.front, range.front);
        }
        assert(toFill.empty);
    }
    else
    {
        scope(failure)
        {
            // The last element didn't make it, fill with default
            array[$ - 1 .. $].uninitializedFillDefault;
        }
        void[] buf = array;
        for (; !range.empty; range.popFront)
        {
            if (!alloc.reallocate(buf, buf.length + T.sizeof))
            {
                array = cast(T[]) buf;
                return false;
            }
            import std.conv : emplace;
            emplace!T(buf[$ - T.sizeof .. $], range.front);
        }

        array = cast(T[]) buf;
    }
    return true;
}

///
unittest
{
    auto arr = theAllocator.makeArray!int([1, 2, 3]);
    assert(theAllocator.growArray(arr, 2));
    assert(arr == [1, 2, 3, 0, 0]);
    import std.range : only;
    assert(theAllocator.growArray(arr, only(4, 5)));
    assert(arr == [1, 2, 3, 0, 0, 4, 5]);

    ForcedInputRange r;
    int[] b = [ 1, 2, 3, 4 ];
    auto temp = b;
    r.array = &temp;
    assert(theAllocator.growArray(arr, r));
    assert(arr == [1, 2, 3, 0, 0, 4, 5, 1, 2, 3, 4]);
}

/**
Shrinks an array by $(D delta) elements.

If $(D array.length < delta), does nothing and returns false. Otherwise,
destroys the last $(D array.length - delta) elements in the array and then
reallocates the array's buffer. If reallocation fails, fills the array with
default-initialized data.

Params:
T = element type of the array being created
alloc = the allocator used for getting memory
array = a reference to the array being shrunk
delta = number of elements to remove (upon success the new length of $(D array) is $(D array.length - delta))

Returns:
$(D true) upon success, $(D false) if memory could not be reallocated. In the latter case $(D array) is left with all elements default-initialized.

Throws:
The first two overloads throw only if $(T alloc)'s primitives do. The
overloads that involve copy initialization deallocate memory and propagate the
exception if the copy operation throws.
*/
bool shrinkArray(T, Allocator)(auto ref Allocator alloc,
        ref T[] array, size_t delta)
{
    if (delta > array.length) return false;

    // Destroy elements. If a destructor throws, fill the already destroyed
    // stuff with the default initializer.
    {
        size_t destroyed;
        scope(failure)
        {
            array[$ - delta .. $][0 .. destroyed].uninitializedFillDefault;
        }
        foreach (ref e; array[$ - delta .. $])
        {
            e.destroy;
            ++destroyed;
        }
    }

    if (delta == array.length)
    {
        alloc.deallocate(array);
        array = null;
        return true;
    }

    void[] buf = array;
    if (!alloc.reallocate(buf, buf.length - T.sizeof * delta))
    {
        // urgh, at least fill back with default
        array[$ - delta .. $].uninitializedFillDefault;
        return false;
    }
    array = cast(T[]) buf;
    return true;
}

///
unittest
{
    int[] a = theAllocator.makeArray!int(100, 42);
    assert(a.length == 100);
    assert(theAllocator.shrinkArray(a, 98));
    assert(a.length == 2);
    assert(a == [42, 42]);
}

unittest
{
    void test(A)(auto ref A alloc)
    {
        long[] a = alloc.makeArray!long((int[]).init);
        assert(a.length == 0 && a.ptr is null);
        a = alloc.makeArray!long(100, 42);
        assert(alloc.shrinkArray(a, 98));
        assert(a.length == 2);
        assert(a == [ 42, 42]);
    }
    import std.experimental.allocator.gc_allocator : GCAllocator;
    test(GCAllocator.it);
    test(theAllocator);
}

/**

Destroys and then deallocates (using $(D alloc)) the object pointed to by a
pointer, the class object referred to by a $(D class) or $(D interface)
reference, or an entire array. It is assumed the respective entities had been
allocated with the same allocator.

*/
void dispose(A, T)(auto ref A alloc, T* p)
{
    static if (hasElaborateDestructor!T)
    {
        destroy(*p);
    }
    alloc.deallocate(p[0 .. T.sizeof]);
}

/// Ditto
void dispose(A, T)(auto ref A alloc, T p)
if (is(T == class) || is(T == interface))
{
    if (!p) return;
    auto support = (cast(void*) p)[0 .. typeid(p).init.length];
    destroy(p);
    alloc.deallocate(support);
}

/// Ditto
void dispose(A, T)(auto ref A alloc, T[] array)
{
    static if (hasElaborateDestructor!(typeof(array[0])))
    {
        foreach (ref e; array)
        {
            destroy(e);
        }
    }
    alloc.deallocate(array);
}

unittest
{
    static int x;
    static interface I
    {
        void method();
    }
    static class A : I
    {
        int y;
        override void method() { x = 21; }
        ~this() { x = 42; }
    }
    static class B : A
    {
    }
    auto a = theAllocator.make!A;
    a.method();
    assert(x == 21);
    theAllocator.dispose(a);
    assert(x == 42);

    B b = theAllocator.make!B;
    b.method();
    assert(x == 21);
    theAllocator.dispose(b);
    assert(x == 42);

    I i = theAllocator.make!B;
    i.method();
    assert(x == 21);
    theAllocator.dispose(i);
    assert(x == 42);

    int[] arr = theAllocator.makeArray!int(43);
    theAllocator.dispose(arr);
}

/**
Dynamic version of an allocator. This should be used wherever a uniform type is
required for encapsulating various allocator implementations.

Methods returning $(D Ternary) return $(D Ternary.yes) upon success,
$(D Ternary.no) upon failure, and $(D Ternary.unknown) if the primitive is not
implemented by the allocator instance.
*/
interface IAllocator
{
    /**
    Returns the alignment offered.
    */
    @property uint alignment();

    /**
    Returns the good allocation size that guarantees zero internal
    fragmentation.
    */
    size_t goodAllocSize(size_t s);

    /**
    Allocates memory.
    */
    void[] allocate(size_t, TypeInfo ti = null);

    /**
    Allocates memory with specified alignment.
    */
    Ternary alignedAllocate(size_t, uint, ref void[], TypeInfo ti = null);

    /**
    Allocates and returns all memory available to this allocator. $(COMMENT By
    default returns $(D null).)
    */
    Ternary allocateAll(ref void[] result);

    /**
    Expands a memory block in place. If expansion not supported
    by the allocator, returns $(D Ternary.unknown). If implemented, returns $(D
    Ternary.yes) if expansion succeeded, $(D Ternary.no) otherwise.
    */
    Ternary expand(ref void[], size_t);

    /// Reallocates a memory block.
    bool reallocate(ref void[], size_t);

    /// Reallocates a memory block with specified alignment.
    Ternary alignedReallocate(ref void[] b, size_t size, uint alignment);

    /**
    Returns $(D Ternary.yes) if the allocator owns $(D b), $(D Ternary.no) if
    the allocator doesn't own $(D b), and $(D Ternary.unknown) if ownership not
    supported by the allocator. $(COMMENT By default returns $(D
    Ternary.unknown).)
    */
    Ternary owns(void[] b);

    /**
    Resolves an internal pointer to the full block allocated.
    */
    Ternary resolveInternalPointer(void* p, ref void[] result);

    /**
    Deallocates a memory block. Returns $(D Ternary.unknown) if deallocation is
    not supported. A simple way to check that an allocator supports
    deallocation is to call $(D deallocate(null)).
    */
    Ternary deallocate(void[] b);

    /**
    Deallocates all memory. Returns $(D Ternary.unknown) if deallocation is
    not supported.
    */
    Ternary deallocateAll();

    /**
    Returns $(D Ternary.yes) if no memory is currently allocated from this
    allocator, $(D Ternary.no) if some allocations are currently active, or
    $(D Ternary.unknown) if not supported.
    */
    Ternary empty();
}

__gshared IAllocator _processAllocator;
IAllocator _threadAllocator;

shared static this()
{
    assert(!_processAllocator);
    import std.experimental.allocator.gc_allocator : GCAllocator;
    _processAllocator = allocatorObject(GCAllocator.it);
}

static this()
{
    assert(!_threadAllocator);
    _threadAllocator = _processAllocator;
}

/**
Gets/sets the allocator for the current thread. This is the default allocator
that should be used for allocating thread-local memory. For allocating memory
to be shared across threads, use $(D processAllocator) (below). By default,
$(D theAllocator) ultimately fetches memory from $(D processAllocator), which
in turn uses the garbage collected heap.
*/
@property IAllocator theAllocator()
{
    return _threadAllocator;
}

/// Ditto
@property void theAllocator(IAllocator a)
{
    assert(a);
    _threadAllocator = a;
}

///
unittest
{
    // Install a new allocator that is faster for 128-byte allocations.
    import std.experimental.allocator.free_list,
        std.experimental.allocator.gc_allocator;
    auto oldAllocator = theAllocator;
    scope(exit) theAllocator = oldAllocator;
    theAllocator = allocatorObject(FreeList!(GCAllocator, 128)());
    // Use the now changed allocator to allocate an array
    ubyte[] arr = theAllocator.makeArray!ubyte(128);
    assert(arr.ptr);
    //...
}

/**
Gets/sets the allocator for the current process. This allocator must be used
for allocating memory shared across threads. Objects created using this
allocator can be cast to $(D shared).
*/
@property IAllocator processAllocator()
{
    return _processAllocator;
}

/// Ditto
@property void processAllocator(IAllocator a)
{
    assert(a);
    _processAllocator = a;
}

unittest
{
    assert(processAllocator);
    assert(processAllocator is theAllocator);
}

/**

Returns a dynamically-typed $(D CAllocator) built around a given statically-
typed allocator $(D a) of type $(D A). Passing a pointer to the allocator
creates a dynamic allocator around the allocator pointed to by the pointer,
without attempting to copy or move it. Passing the allocator by value or
reference behaves as follows.

$(UL
$(LI If $(D A) has no state, the resulting object is allocated in static
shared storage.)
$(LI If $(D A) has state and is copyable, the result will store a copy of it
within. The result itself is allocated in its own statically-typed allocator.)
$(LI If $(D A) has state and is not copyable, the result will move the
passed-in argument into the result. The result itself is allocated in its own
statically-typed allocator.)
)

*/
CAllocatorImpl!A allocatorObject(A)(auto ref A a)
if (!isPointer!A)
{
    import std.conv : emplace;
    static if (stateSize!A == 0)
    {
        enum s = stateSize!(CAllocatorImpl!A).divideRoundUp(ulong.sizeof);
        static __gshared ulong[s] state;
        static __gshared CAllocatorImpl!A result;
        if (!result)
        {
            // Don't care about a few races
            result = emplace!(CAllocatorImpl!A)(state[]);
        }
        assert(result);
        return result;
    }
    else static if (is(typeof({ A b = a; A c = b; }))) // copyable
    {
        auto state = a.allocate(stateSize!(CAllocatorImpl!A));
        import std.traits : hasMember;
        static if (hasMember!(A, "deallocate"))
        {
            scope(failure) a.deallocate(state);
        }
        return cast(CAllocatorImpl!A) emplace!(CAllocatorImpl!A)(state);
    }
    else // the allocator object is not copyable
    {
        // This is sensitive... create on the stack and then move
        enum s = stateSize!(CAllocatorImpl!A).divideRoundUp(ulong.sizeof);
        ulong[s] state;
        import std.algorithm : move;
        emplace!(CAllocatorImpl!A)(state[], move(a));
        auto dynState = a.allocate(stateSize!(CAllocatorImpl!A));
        // Bitblast the object in its final destination
        dynState[] = state[];
        return cast(CAllocatorImpl!A) dynState.ptr;
    }
}

/// Ditto
CAllocatorImpl!(A, Yes.indirect) allocatorObject(A)(A* pa)
{
    assert(pa);
    import std.conv : emplace;
    auto state = pa.allocate(stateSize!(CAllocatorImpl!(A, Yes.indirect)));
    import std.traits : hasMember;
    static if (hasMember!(A, "deallocate"))
    {
        scope(failure) pa.deallocate(state);
    }
    return emplace!(CAllocatorImpl!(A, Yes.indirect))
        (state, pa);
}

///
unittest
{
    import std.experimental.allocator.mallocator;
    IAllocator a = allocatorObject(Mallocator.it);
    auto b = a.allocate(100);
    assert(b.length == 100);
    assert(a.deallocate(b) == Ternary.yes);

    // The in-situ region must be used by pointer
    import std.experimental.allocator.region;
    auto r = InSituRegion!1024();
    a = allocatorObject(&r);
    b = a.allocate(200);
    assert(b.length == 200);
    // In-situ regions can't deallocate
    assert(a.deallocate(b) == Ternary.unknown);
}

/**

Implementation of $(D IAllocator) using $(D Allocator). This adapts a
statically-built allocator type to $(D IAllocator) that is directly usable by
non-templated code.

Usually $(D CAllocatorImpl) is used indirectly by calling
$(LREF theAllocator).
*/
class CAllocatorImpl(Allocator, Flag!"indirect" indirect = No.indirect)
    : IAllocator
{
    import std.traits : hasMember;

    /**
    The implementation is available as a public member.
    */
    static if (indirect)
    {
        private Allocator* pimpl;
        ref Allocator impl()
        {
            return *pimpl;
        }
        this(Allocator* pa)
        {
            pimpl = pa;
        }
    }
    else
    {
        static if (stateSize!Allocator) Allocator impl;
        else alias impl = Allocator.it;
    }

    /// Returns $(D impl.alignment).
    override @property uint alignment()
    {
        return impl.alignment;
    }

    /**
    Returns $(D impl.goodAllocSize(s)).
    */
    override size_t goodAllocSize(size_t s)
    {
        return impl.goodAllocSize(s);
    }

    /**
    Returns $(D impl.allocate(s)).
    */
    override void[] allocate(size_t s, TypeInfo ti = null)
    {
        return impl.allocate(s);
    }

    /**
    If $(D impl.alignedAllocate) exists, calls it, puts the result in $(D r),
    and returns $(D Ternary.yes) or $(D Ternary.no) indicating whether
    allocation succeded.

    If $(D impl.alignedAllocate) is not defined, returns $(D Ternary.unknown).
    */
    override Ternary alignedAllocate(size_t s, uint a, ref void[] r,
        TypeInfo ti = null)
    {
        static if (!hasMember!(Allocator, "alignedAllocate"))
        {
            return Ternary.unknown;
        }
        else
        {
            r = impl.alignedAllocate(s, a);
            return Ternary(r.ptr !is null);
        }
    }

    /**
    Overridden only if $(D Allocator) implements $(D owns). In that case,
    returns $(D impl.owns(b)).
    */
    override Ternary owns(void[] b)
    {
        static if (hasMember!(Allocator, "owns")) return Ternary(impl.owns(b));
        else return Ternary.unknown;
    }

    /// Returns $(D impl.expand(b, s)) if defined, $(D false) otherwise.
    override Ternary expand(ref void[] b, size_t s)
    {
        static if (hasMember!(Allocator, "expand"))
            return Ternary(impl.expand(b, s));
        else
            return Ternary.unknown;
    }

    /// Returns $(D impl.reallocate(b, s)).
    override bool reallocate(ref void[] b, size_t s)
    {
        return impl.reallocate(b, s);
    }

    /// Forwards to $(D impl.alignedReallocate).
    Ternary alignedReallocate(ref void[] b, size_t s, uint a)
    {
        static if (!hasMember!(Allocator, "alignedAllocate"))
        {
            return Ternary.unknown;
        }
        else
        {
            return Ternary(impl.alignedReallocate(b, s, a));
        }
    }

    Ternary resolveInternalPointer(void* p, ref void[] result)
    {
        static if (hasMember!(Allocator, "resolveInternalPointer"))
        {
            result = impl.resolveInternalPointer(p);
            return Ternary(result.ptr !is null);
        }
        else
        {
            return Ternary.unknown;
        }
    }

    /**
    If $(D impl.deallocate) is not defined, returns $(D Ternary.unknown). If
    $(D impl.deallocate) returns $(D void) (the common case), calls it and
    returns $(D Ternary.yes). If $(D impl.deallocate) returns $(D bool), calls
    it and returns $(D Ternary.yes) for $(D true), $(D Ternary.no) for $(D
    false).
    */
    override Ternary deallocate(void[] b)
    {
        static if (hasMember!(Allocator, "deallocate"))
        {
            static if (is(typeof(impl.deallocate(b)) == bool))
            {
                return Ternary(impl.deallocate(b));
            }
            else
            {
                impl.deallocate(b);
                return Ternary.yes;
            }
        }
        else
        {
            return Ternary.unknown;
        }
    }

    /**
    Calls $(D impl.deallocateAll()) and returns $(D Ternary.yes) if defined,
    otherwise returns $(D Ternary.unknown).
    */
    override Ternary deallocateAll()
    {
        static if (hasMember!(Allocator, "deallocateAll"))
        {
            impl.deallocateAll();
            return Ternary.yes;
        }
        else
        {
            return Ternary.unknown;
        }
    }

    /**
    Forwards to $(D impl.empty()) if defined, otherwise returns
    $(D Ternary.unknown).
    */
    override Ternary empty()
    {
        static if (hasMember!(Allocator, "empty"))
        {
            return Ternary(impl.empty);
        }
        else
        {
            return Ternary.unknown;
        }
    }

    /**
    Returns $(D impl.allocateAll()) if present, $(D null) otherwise.
    */
    override Ternary allocateAll(ref void[] result)
    {
        static if (hasMember!(Allocator, "allocateAll"))
        {
            result = impl.allocateAll();
            return Ternary(result.ptr !is null);
        }
        else
        {
            return Ternary.unknown;
        }
    }
}
