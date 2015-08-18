/**
Utility and ancillary artifacts of `std.experimental.allocator`. This module
shouldn't be used directly; its functionality will be migrated into more
appropriate parts of `std`.

Authors: $(WEB erdani.com, Andrei Alexandrescu), Timon Gehr (`Ternary`)
*/
module std.experimental.allocator.common;
import std.algorithm, std.traits;

/**
Ternary type with three thruth values.
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

    /**
    In addition to `false` and `true`, `Ternary` offers `unknown`.
    */
    enum no = make(0);
    /// ditto
    enum yes = make(2);
    /// ditto
    enum unknown = make(6);

    /**
     Construct and assign from a `bool`, receiving `no` for `false` and `yes`
     for `true`.
    */
    this(bool b) { value = b << 1; }

    /// ditto
    void opAssign(bool b) { value = b << 1; }

    /**
    Construct a ternary value from another ternary value
    */
    this(const Ternary b) { value = b.value; }

    /**
    $(TABLE Truth table for logical operations,
      $(TR $(TH `a`) $(TH `b`) $(TH `$(TILDE)a`) $(TH `a | b`) $(TH `a & b`) $(TH `a ^ b`))
      $(TR $(TD `no`) $(TD `no`) $(TD `yes`) $(TD `no`) $(TD `no`) $(TD `no`))
      $(TR $(TD `no`) $(TD `yes`) $(TD) $(TD `yes`) $(TD `no`) $(TD `yes`))
      $(TR $(TD `no`) $(TD `unknown`) $(TD) $(TD `unknown`) $(TD `no`) $(TD `unknown`))
      $(TR $(TD `yes`) $(TD `no`) $(TD `no`) $(TD `yes`) $(TD `no`) $(TD `yes`))
      $(TR $(TD `yes`) $(TD `yes`) $(TD) $(TD `yes`) $(TD `yes`) $(TD `no`))
      $(TR $(TD `yes`) $(TD `unknown`) $(TD) $(TD `yes`) $(TD `unknown`) $(TD `unknown`))
      $(TR $(TD `unknown`) $(TD `no`) $(TD `unknown`) $(TD `unknown`) $(TD `no`) $(TD `unknown`))
      $(TR $(TD `unknown`) $(TD `yes`) $(TD) $(TD `yes`) $(TD `unknown`) $(TD `unknown`))
      $(TR $(TD `unknown`) $(TD `unknown`) $(TD) $(TD `unknown`) $(TD `unknown`) $(TD `unknown`))
    )
    */
    Ternary opUnary(string s)() if (s == "~")
    {
        return make(386 >> value & 6);
    }

    /// ditto
    Ternary opBinary(string s)(Ternary rhs) if (s == "|")
    {
        return make(25_512 >> value + rhs.value & 6);
    }

    /// ditto
    Ternary opBinary(string s)(Ternary rhs) if (s == "&")
    {
        return make(26_144 >> value + rhs.value & 6);
    }

    /// ditto
    Ternary opBinary(string s)(Ternary rhs) if (s == "^")
    {
        return make(26_504 >> value + rhs.value & 6);
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
the exact value. For example, $(D BitmappedBlock!(Allocator, 4096)) (described in
detail below) defines a block allocator with block size of 4096 bytes, whereas
$(D BitmappedBlock!(Allocator, chooseAtRuntime)) defines a block allocator that has a
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

/**
Returns `n` rounded up to a multiple of alignment, which must be a power of 2.
*/
package size_t roundUpToAlignment(size_t n, uint alignment)
{
    assert(alignment.isPowerOf2);
    immutable uint slack = cast(uint) n & (alignment - 1);
    const result = slack
        ? n + alignment - slack
        : n;
    assert(result >= n);
    return result;
}

unittest
{
    assert(10.roundUpToAlignment(4) == 12);
    assert(11.roundUpToAlignment(2) == 12);
    assert(12.roundUpToAlignment(8) == 16);
    assert(118.roundUpToAlignment(64) == 128);
}

/**
Returns `n` rounded down to a multiple of alignment, which must be a power of 2.
*/
package size_t roundDownToAlignment(size_t n, uint alignment)
{
    assert(alignment.isPowerOf2);
    return n & ~size_t(alignment - 1);
}

unittest
{
    assert(10.roundDownToAlignment(4) == 8);
    assert(11.roundDownToAlignment(2) == 10);
    assert(12.roundDownToAlignment(8) == 8);
    assert(63.roundDownToAlignment(64) == 0);
}

/**
Advances the beginning of `b` to start at alignment `a`. The resulting buffer
may therefore be shorter. Returns the adjusted buffer, or null if obtaining a
non-empty buffer is impossible.
*/
package void[] roundUpToAlignment(void[] b, uint a)
{
    auto e = b.ptr + b.length;
    auto p = cast(void*) roundUpToAlignment(cast(size_t) b.ptr, a);
    if (e <= p) return null;
    return p[0 .. e - p];
}

unittest
{
    void[] empty;
    assert(roundUpToAlignment(empty, 4) == null);
    char[128] buf;
    // At least one pointer inside buf is 128-aligned
    assert(roundUpToAlignment(buf, 128) !is null);
}

/**
Like `a / b` but rounds the result up, not down.
*/
package size_t divideRoundUp(size_t a, size_t b)
{
    assert(b);
    return (a + b - 1) / b;
}

/**
Returns `s` rounded up to a multiple of `base`.
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
    import std.meta : AliasSeq;
    assert(s <= (size_t.max >> 1) + 1);
    --s;
    static if (size_t.sizeof == 4)
        alias Shifts = AliasSeq!(1, 2, 4, 8, 16);
    else
        alias Shifts = AliasSeq!(1, 2, 4, 8, 16, 32);
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

/**
Returns `true` if `ptr` is aligned at `alignment`.
*/
package bool alignedAt(void* ptr, uint alignment)
{
    return cast(size_t) ptr % alignment == 0;
}

/**
Returns the effective alignment of `ptr`, i.e. the largest power of two that is
a divisor of `ptr`.
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

/**
Aligns a pointer down to a specified alignment. The resulting pointer is less
than or equal to the given pointer.
*/
package void* alignDownTo(void* ptr, uint alignment)
{
    assert(alignment.isPowerOf2);
    return cast(void*) (cast(size_t) ptr & ~(alignment - 1UL));
}

/**
Aligns a pointer up to a specified alignment. The resulting pointer is greater
than or equal to the given pointer.
*/
package void* alignUpTo(void* ptr, uint alignment)
{
    assert(alignment.isPowerOf2);
    immutable uint slack = cast(size_t) ptr & (alignment - 1U);
    return slack ? ptr + alignment - slack : ptr;
}

// Credit: Matthias Bentrup
/**
Returns `true` if `x` is a nonzero power of two.
*/
package bool isPowerOf2(uint x)
{
    return (x & -x) > (x - 1);
}

unittest
{
    assert(!isPowerOf2(0));
    assert(isPowerOf2(1));
    assert(isPowerOf2(2));
    assert(!isPowerOf2(3));
    assert(isPowerOf2(4));
    assert(!isPowerOf2(5));
    assert(!isPowerOf2(6));
    assert(!isPowerOf2(7));
    assert(isPowerOf2(8));
    assert(!isPowerOf2(9));
    assert(!isPowerOf2(10));
    assert(isPowerOf2(1UL << 31));
}

package bool isGoodStaticAlignment(uint x)
{
    return x.isPowerOf2;
}

package bool isGoodDynamicAlignment(uint x)
{
    return x.isPowerOf2 && x >= (void*).sizeof;
}

/*
If $(D b.length + delta <= a.goodAllocSize(b.length)), $(D expand) just adjusts
$(D b) and returns $(D true). Otherwise, returns $(D false).

$(D expand) does not attempt to use $(D Allocator.reallocate) even if
defined. This is deliberate so allocators may use it internally within their own
implementation of $(D expand).

*/
//bool expand(Allocator)(ref Allocator a, ref void[] b, size_t delta)
//{
//    if (!b.ptr)
//    {
//        b = a.allocate(delta);
//        return b.length == delta;
//    }
//    if (delta == 0) return true;
//    immutable length = b.length + delta;
//    if (length <= a.goodAllocSize(b.length))
//    {
//        b = b.ptr[0 .. length];
//        return true;
//    }
//    return false;
//}

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
    if (newB.length != s) return false;
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

/**
Forwards each of the methods in `funs` (if defined) to `member`.
*/
/*package*/ string forwardToMember(string member, string[] funs...)
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
    import std.stdio : writeln, stderr;
    alias A = typeof(make());
    scope(failure) stderr.writeln("testAllocator failed for ", A.stringof);

    auto a = make();

    // Test alignment
    static assert(A.alignment.isPowerOf2);

    // Test goodAllocSize
    assert(a.goodAllocSize(1) >= A.alignment,
        text(a.goodAllocSize(1), " < ", A.alignment));
    assert(a.goodAllocSize(11) >= 11.roundUpToMultipleOf(A.alignment));
    assert(a.goodAllocSize(111) >= 111.roundUpToMultipleOf(A.alignment));

    // Test allocate
    assert(a.allocate(0) is null);

    auto b1 = a.allocate(1);
    assert(b1.length == 1);
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
        // This seems to be a bug in the compiler:
        //static assert(!hasMember!(A, "alignedReallocate"), A.stringof);
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
        const b4 = ab.allocateAll();
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
        assert(a.owns(null) == Ternary.no);
        assert(a.owns(b1) == Ternary.yes);
        assert(a.owns(b2) == Ternary.yes);
        assert(a.owns(b6) == Ternary.yes);
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
