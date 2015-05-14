module std.experimental.allocator.common;
import std.algorithm, std.traits;

/*
Ternary by Timon Gehr and Andrei Alexandrescu.
*/
struct Ternary
{
    package ubyte value = 6;
    package static Ternary make(ubyte b)
    {
        Ternary r = void;
        r.value = b;
        return r;
    }

    enum no = make(0), yes = make(2), unknown = make(6);

    this(bool b) { value = b << 1; }

    void opAssign(bool b) { value = b << 1; }

    Ternary opUnary(string s)() if (s == "~")
    {
        return make(386 >> value & 6);
    }

    Ternary opBinary(string s)(Ternary rhs) if (s == "|")
    {
        return make(25512 >> value + rhs.value & 6);
    }

    Ternary opBinary(string s)(Ternary rhs) if (s == "&")
    {
        return make(26144 >> value + rhs.value & 6);
    }

    Ternary opBinary(string s)(Ternary rhs) if (s == "^")
    {
        return make(26504 >> value + rhs.value & 6);
    }
}

unittest
{
    alias f = Ternary.no, t = Ternary.yes, u = Ternary.unknown;
    auto truthTableAnd =
    [
        t, t, t,
        t, u, u,
        t, f, f,
        u, t, u,
        u, u, u,
        u, f, f,
        f, t, f,
        f, u, f,
        f, f, f,
    ];

    auto truthTableOr =
    [
        t, t, t,
        t, u, t,
        t, f, t,
        u, t, t,
        u, u, u,
        u, f, u,
        f, t, t,
        f, u, u,
        f, f, f,
    ];

    auto truthTableXor =
    [
        t, t, f,
        t, u, u,
        t, f, t,
        u, t, u,
        u, u, u,
        u, f, u,
        f, t, t,
        f, u, u,
        f, f, f,
    ];

    for (auto i = 0; i != truthTableAnd.length; i += 3)
    {
        assert((truthTableAnd[i] & truthTableAnd[i + 1])
            == truthTableAnd[i + 2]);
        assert((truthTableOr[i] | truthTableOr[i + 1])
            == truthTableOr[i + 2]);
        assert((truthTableXor[i] ^ truthTableXor[i + 1])
            == truthTableXor[i + 2]);
    }

    Ternary a;
    assert(a == Ternary.unknown);
    static assert(!is(typeof({ if (a) {} })));
    assert(!is(typeof({ auto b = Ternary(3); })));
    a = true;
    assert(a == Ternary.yes);
    a = false;
    assert(a == Ternary.no);
    a = Ternary.unknown;
    assert(a == Ternary.unknown);
    Ternary b;
    b = a;
    assert(b == a);
    assert(~Ternary.yes == Ternary.no);
    assert(~Ternary.no == Ternary.yes);
    assert(~Ternary.unknown == Ternary.unknown);
}

/**
Returns the size in bytes of the state that needs to be allocated to hold an
object of type $(D T). $(D stateSize!T) is zero for $(D struct)s that are not
nested and have no nonstatic member variables.
 */
template stateSize(T)
{
    static if (is(T == class) || is(T == interface))
        enum stateSize = __traits(classInstanceSize, T);
    else static if (is(T == struct) || is(T == union))
        enum stateSize = FieldTypeTuple!T.length || isNested!T ? T.sizeof : 0;
    else static if (is(T == void))
        enum size_t stateSize = 0;
    else
        enum stateSize = T.sizeof;
}

unittest
{
    static assert(stateSize!void == 0);
    struct A {}
    static assert(stateSize!A == 0);
    struct B { int x; }
    static assert(stateSize!B == 4);
    interface I1 {}
    //static assert(stateSize!I1 == 2 * size_t.sizeof);
    class C1 {}
    static assert(stateSize!C1 == 3 * size_t.sizeof);
    class C2 { char c; }
    static assert(stateSize!C2 == 4 * size_t.sizeof);
    static class C3 { char c; }
    static assert(stateSize!C3 == 2 * size_t.sizeof + char.sizeof);
}

/**
$(D chooseAtRuntime) is a compile-time constant of type $(D size_t) that several
parameterized structures in this module recognize to mean deferral to runtime of
the exact value. For example, $(D HeapBlock!(Allocator, 4096)) (described in
detail below) defines a block allocator with block size of 4096 bytes, whereas
$(D HeapBlock!(Allocator, chooseAtRuntime)) defines a block allocator that has a
field storing the block size, initialized by the user.
*/
enum chooseAtRuntime = size_t.max - 1;

/**
$(D unbounded) is a compile-time constant of type $(D size_t) that several
parameterized structures in this module recognize to mean "infinite" bounds for
the parameter. For example, $(D Freelist) (described in detail below) accepts a
$(D maxNodes) parameter limiting the number of freelist items. If $(D unbounded)
is passed for $(D maxNodes), then there is no limit and no checking for the
number of nodes.
*/
enum unbounded = size_t.max;

/**
The alignment that is guaranteed to accommodate any D object allocation on the
current platform.
*/
enum uint platformAlignment = std.algorithm.max(double.alignof, real.alignof);

/**
The default good size allocation is deduced as $(D n) rounded up to the
allocator's alignment.
*/
size_t goodAllocSize(A)(auto ref A a, size_t n)
{
    return n.roundUpToMultipleOf(a.alignment);
}

/**
Returns s rounded up to a multiple of base.
*/
package size_t roundUpToMultipleOf(size_t s, uint base)
{
    assert(base);
    auto rem = s % base;
    return rem ? s + base - rem : s;
}

unittest
{
    assert(10.roundUpToMultipleOf(11) == 11);
    assert(11.roundUpToMultipleOf(11) == 11);
    assert(12.roundUpToMultipleOf(11) == 22);
    assert(118.roundUpToMultipleOf(11) == 121);
}

package size_t divideRoundUp(size_t a, size_t b)
{
    assert(b);
    return (a + b - 1) / b;
}

/**
Returns s rounded up to a multiple of base.
*/
package void[] roundStartToMultipleOf(void[] s, uint base)
{
    assert(base);
    auto p = cast(void*) roundUpToMultipleOf(
        cast(size_t) s.ptr, base);
    auto end = s.ptr + s.length;
    return p[0 .. end - p];
}

unittest
{
    void[] p;
    assert(roundStartToMultipleOf(p, 16) is null);
    p = new ulong[10];
    assert(roundStartToMultipleOf(p, 16) is p);
}

/**
Returns $(D s) rounded up to the nearest power of 2.
*/
package size_t roundUpToPowerOf2(size_t s)
{
    import std.typetuple;
    assert(s <= (size_t.max >> 1) + 1);
    --s;
    static if (size_t.sizeof == 4)
        alias Shifts = TypeTuple!(1, 2, 4, 8, 16);
    else
        alias Shifts = TypeTuple!(1, 2, 4, 8, 16, 32);
    foreach (i; Shifts)
    {
        s |= s >> i;
    }
    return s + 1;
}

unittest
{
    assert(0.roundUpToPowerOf2 == 0);
    assert(1.roundUpToPowerOf2 == 1);
    assert(2.roundUpToPowerOf2 == 2);
    assert(3.roundUpToPowerOf2 == 4);
    assert(7.roundUpToPowerOf2 == 8);
    assert(8.roundUpToPowerOf2 == 8);
    assert(10.roundUpToPowerOf2 == 16);
    assert(11.roundUpToPowerOf2 == 16);
    assert(12.roundUpToPowerOf2 == 16);
    assert(118.roundUpToPowerOf2 == 128);
    assert((size_t.max >> 1).roundUpToPowerOf2 == (size_t.max >> 1) + 1);
    assert(((size_t.max >> 1) + 1).roundUpToPowerOf2 == (size_t.max >> 1) + 1);
}

/**
Returns the number of trailing zeros of $(D x).
*/
package uint trailingZeros(ulong x)
{
    uint result;
    while (result < 64 && !(x & (1UL << result)))
    {
        ++result;
    }
    return result;
}

unittest
{
    assert(trailingZeros(0) == 64);
    assert(trailingZeros(1) == 0);
    assert(trailingZeros(2) == 1);
    assert(trailingZeros(3) == 0);
    assert(trailingZeros(4) == 2);
}

/*
*/
bool alignedAt(void* ptr, uint alignment)
{
    return cast(size_t) ptr % alignment == 0;
}

/*
*/
package uint effectiveAlignment(void* ptr)
{
    return 1U << trailingZeros(cast(size_t) ptr);
}

unittest
{
    int x;
    assert(effectiveAlignment(&x) >= int.alignof);
}

/*
Aligns a pointer down to a specified alignment. The resulting pointer is less
than or equal to the given pointer.
*/
void* alignDownTo(void* ptr, uint alignment)
{
    assert(alignment.isPowerOf2);
    return cast(void*) (cast(size_t) ptr & ~(alignment - 1UL));
}

/*
Aligns a pointer up to a specified alignment. The resulting pointer is greater
than or equal to the given pointer.
*/
void* alignUpTo(void* ptr, uint alignment)
{
    assert(alignment.isPowerOf2);
    immutable uint slack = cast(size_t) ptr & (alignment - 1U);
    return slack ? ptr + alignment - slack : ptr;
}

package bool isPowerOf2(uint x)
{
    return (x & (x - 1)) == 0;
}

package bool isGoodStaticAlignment(uint x)
{
    return x.isPowerOf2 && x > 0;
}

package bool isGoodDynamicAlignment(uint x)
{
    return x.isPowerOf2 && x >= (void*).sizeof;
}

/**
The default $(D reallocate) function first attempts to use $(D expand). If $(D
Allocator.expand) is not defined or returns $(D false), $(D reallocate)
allocates a new block of memory of appropriate size and copies data from the old
block to the new block. Finally, if $(D Allocator) defines $(D deallocate), $(D
reallocate) uses it to free the old memory block.

$(D reallocate) does not attempt to use $(D Allocator.reallocate) even if
defined. This is deliberate so allocators may use it internally within their own
implementation of $(D reallocate).

*/
bool reallocate(Allocator)(ref Allocator a, ref void[] b, size_t s)
{
    if (b.length == s) return true;
    static if (hasMember!(Allocator, "expand"))
    {
        if (b.length <= s && a.expand(b, s - b.length)) return true;
    }
    auto newB = a.allocate(s);
    if (newB.length <= b.length) newB[] = b[0 .. newB.length];
    else newB[0 .. b.length] = b[];
    static if (hasMember!(Allocator, "deallocate"))
        a.deallocate(b);
    b = newB;
    return true;
}

/**

The default $(D alignedReallocate) function first attempts to use $(D expand).
If $(D Allocator.expand) is not defined or returns $(D false),  $(D
alignedReallocate) allocates a new block of memory of appropriate size and
copies data from the old block to the new block. Finally, if $(D Allocator)
defines $(D deallocate), $(D alignedReallocate) uses it to free the old memory
block.

$(D alignedReallocate) does not attempt to use $(D Allocator.reallocate) even if
defined. This is deliberate so allocators may use it internally within their own
implementation of $(D reallocate).

*/
bool alignedReallocate(Allocator)(ref Allocator alloc,
        ref void[] b, size_t s, uint a)
{
    static if (hasMember!(Allocator, "expand"))
    {
        if (b.length <= s && b.ptr.alignedAt(a)
            && alloc.expand(b, s - b.length)) return true;
    }
    else
    {
        if (b.length == s) return true;
    }
    auto newB = alloc.alignedAllocate(s, a);
    if (newB.length <= b.length) newB[] = b[0 .. newB.length];
    else newB[0 .. b.length] = b[];
    static if (hasMember!(Allocator, "deallocate"))
        alloc.deallocate(b);
    b = newB;
    return true;
}

/*
Forwards each of the methods in "funs" (if defined) to "member".
*/
package string forwardToMember(string member, string[] funs...)
{
    string result = "    import std.traits : hasMember, ParameterTypeTuple;\n";
    foreach (fun; funs)
    {
        result ~= "
    static if (hasMember!(typeof("~member~"), `"~fun~"`))
    auto ref "~fun~"(ParameterTypeTuple!(typeof("~member~"."~fun~")) args)
    {
        return "~member~"."~fun~"(args);
    }\n";
    }
    return result;
}

package void testAllocator(alias make)()
{
    import std.conv : text;
    alias A = typeof(make());
    auto a = make();

    // Test alignment
    static assert(A.alignment.isPowerOf2);

    // Test goodAllocSize
    assert(a.goodAllocSize(1) >= A.alignment);
    assert(a.goodAllocSize(11) >= 11.roundUpToMultipleOf(A.alignment));
    assert(a.goodAllocSize(111) >= 111.roundUpToMultipleOf(A.alignment));

    // Test allocate
    auto b1 = a.allocate(1);
    assert(b1.length == 1);
    static if (hasMember!(A, "zeroesAllocations"))
    {
        assert((cast(byte*) b1.ptr) == 0);
    }
    auto b2 = a.allocate(2);
    assert(b2.length == 2);
    assert(b2.ptr + b2.length <= b1.ptr || b1.ptr + b1.length <= b2.ptr);

    // Test alignedAllocate
    static if (hasMember!(A, "alignedAllocate"))
    {{
        auto b3 = a.alignedAllocate(1, 256);
        assert(b3.length <= 1);
        assert(b3.ptr.alignedAt(256));
        assert(a.alignedReallocate(b3, 2, 512));
        assert(b3.ptr.alignedAt(512));
        static if (hasMember!(A, "alignedDeallocate"))
        {
            a.alignedDeallocate(b3);
        }
    }}
    else
    {
        static assert(!hasMember!(A, "alignedDeallocate"));
        static assert(!hasMember!(A, "alignedReallocate"));
    }

    static if (hasMember!(A, "allocateAll"))
    {{
        auto aa = make();
        if (aa.allocateAll().ptr)
        {
            // Can't get any more memory
            assert(!aa.allocate(1).ptr);
        }
        auto ab = make();
        auto b4 = ab.allocateAll();
        assert(b4.length);
        // Can't get any more memory
        assert(!ab.allocate(1).ptr);
    }}

    static if (hasMember!(A, "expand"))
    {{
        assert(a.expand(b1, 0));
        auto len = b1.length;
        if (a.expand(b1, 102))
        {
            assert(b1.length == len + 102, text(b1.length, " != ", len + 102));
        }
        auto aa = make();
        void[] b5 = null;
        assert(aa.expand(b5, 0));
        assert(b5 is null);
        assert(aa.expand(b5, 1));
        assert(b5.length == 1);
    }}

    void[] b6 = null;
    assert(a.reallocate(b6, 0));
    assert(b6.length == 0);
    assert(a.reallocate(b6, 1));
    assert(b6.length == 1, text(b6.length));

    // Test owns
    static if (hasMember!(A, "owns"))
    {{
        assert(!a.owns(null));
        assert(a.owns(b1));
        assert(a.owns(b2));
        assert(a.owns(b6));
    }}

    static if (hasMember!(A, "resolveInternalPointer"))
    {{
        assert(a.resolveInternalPointer(null) is null);
        auto p = a.resolveInternalPointer(b1.ptr);
        assert(p.ptr is b1.ptr && p.length >= b1.length);
        p = a.resolveInternalPointer(b1.ptr + b1.length / 2);
        assert(p.ptr is b1.ptr && p.length >= b1.length);
        p = a.resolveInternalPointer(b2.ptr);
        assert(p.ptr is b2.ptr && p.length >= b2.length);
        p = a.resolveInternalPointer(b2.ptr + b2.length / 2);
        assert(p.ptr is b2.ptr && p.length >= b2.length);
        p = a.resolveInternalPointer(b6.ptr);
        assert(p.ptr is b6.ptr && p.length >= b6.length);
        p = a.resolveInternalPointer(b6.ptr + b6.length / 2);
        assert(p.ptr is b6.ptr && p.length >= b6.length);
        static int[10] b7 = [ 1, 2, 3 ];
        assert(a.resolveInternalPointer(b7.ptr) is null);
        assert(a.resolveInternalPointer(b7.ptr + b7.length / 2) is null);
        assert(a.resolveInternalPointer(b7.ptr + b7.length) is null);
        int[3] b8 = [ 1, 2, 3 ];
        assert(a.resolveInternalPointer(b8.ptr).ptr is null);
        assert(a.resolveInternalPointer(b8.ptr + b8.length / 2) is null);
        assert(a.resolveInternalPointer(b8.ptr + b8.length) is null);
    }}
}
