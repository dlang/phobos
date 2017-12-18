///
module std.experimental.allocator.building_blocks.null_allocator;

/**
$(D NullAllocator) is an emphatically empty implementation of the allocator
interface. Although it has no direct use, it is useful as a "terminator" in
composite allocators.
*/
struct NullAllocator
{
    import std.typecons : Ternary;
    /**
    $(D NullAllocator) advertises a relatively large _alignment equal to 64 KB.
    This is because $(D NullAllocator) never actually needs to honor this
    alignment and because composite allocators using $(D NullAllocator)
    shouldn't be unnecessarily constrained.
    */
    enum uint alignment = 64 * 1024;
    // /// Returns $(D n).
    //size_t goodAllocSize(size_t n) shared const
    //{ return .goodAllocSize(this, n); }
    /// Always returns $(D null).
    void[] allocate(size_t) shared { return null; }
    /// Always returns $(D null).
    void[] alignedAllocate(size_t, uint) shared { return null; }
    /// Always returns $(D null).
    void[] allocateAll() shared { return null; }
    /**
    These methods return $(D false).
    Precondition: $(D b is null). This is because there is no other possible
    legitimate input.
    */
    pure nothrow @safe @nogc
    bool expand(ref void[] b, size_t s) shared
    { assert(b is null); return s == 0; }
    /// Ditto
    pure nothrow @nogc
    bool reallocate(ref void[] b, size_t) shared
    { assert(b is null); return false; }
    /// Ditto
    pure nothrow @nogc
    bool alignedReallocate(ref void[] b, size_t, uint) shared
    { assert(b is null); return false; }
    /// Returns $(D Ternary.no).
    pure nothrow @safe @nogc
    Ternary owns(const void[]) shared const { return Ternary.no; }
    /**
    Returns $(D Ternary.no).
    */
    pure nothrow @safe @nogc
    Ternary resolveInternalPointer(const void*, ref void[]) shared const
    { return Ternary.no; }
    /**
    No-op.
    Precondition: $(D b is null)
    */
    pure nothrow @nogc
    bool deallocate(void[] b) shared { assert(b is null); return true; }
    /**
    No-op.
    */
    pure nothrow @safe @nogc
    bool deallocateAll() shared { return true; }
    /**
    Returns $(D Ternary.yes).
    */
    pure nothrow @safe @nogc
    Ternary empty() shared const { return Ternary.yes; }
    /**
    Returns the $(D shared) global instance of the $(D NullAllocator).
    */
    static shared NullAllocator instance;
}

@system unittest
{
    assert(NullAllocator.instance.alignedAllocate(100, 0) is null);
    assert(NullAllocator.instance.allocateAll() is null);
    auto b = NullAllocator.instance.allocate(100);
    assert(b is null);
    assert((() nothrow @safe @nogc => NullAllocator.instance.expand(b, 0))());
    assert((() nothrow @safe @nogc => !NullAllocator.instance.expand(b, 42))());
    assert((() nothrow @nogc => !NullAllocator.instance.reallocate(b, 42))());
    assert((() nothrow @nogc => !NullAllocator.instance.alignedReallocate(b, 42, 0))());
    assert((() nothrow @nogc => NullAllocator.instance.deallocate(b))());
    assert((() nothrow @nogc => NullAllocator.instance.deallocateAll())());

    import std.typecons : Ternary;
    assert((() nothrow @safe @nogc => NullAllocator.instance.empty)() == Ternary.yes);
    assert((() nothrow @safe @nogc => NullAllocator.instance.owns(null))() == Ternary.no);

    void[] p;
    assert((() nothrow @safe @nogc => NullAllocator.instance.resolveInternalPointer(null, p))() == Ternary.no);
}
