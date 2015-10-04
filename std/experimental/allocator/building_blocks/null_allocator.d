module std.experimental.allocator.building_blocks.null_allocator;

/*
  _   _       _ _          _ _                 _
 | \ | |     | | |   /\   | | |               | |
 |  \| |_   _| | |  /  \  | | | ___   ___ __ _| |_ ___  _ __
 | . ` | | | | | | / /\ \ | | |/ _ \ / __/ _` | __/ _ \| '__|
 | |\  | |_| | | |/ ____ \| | | (_) | (_| (_| | || (_) | |
 |_| \_|\__,_|_|_/_/    \_\_|_|\___/ \___\__,_|\__\___/|_|
*/

/**
$(D NullAllocator) is an emphatically empty implementation of the allocator
interface. Although it has no direct use, it is useful as a "terminator" in
composite allocators.
*/
struct NullAllocator
{
    import std.experimental.allocator.common : Ternary;
    /**
    $(D NullAllocator) advertises a relatively large _alignment equal to 64 KB.
    This is because $(D NullAllocator) never actually needs to honor this
    alignment and because composite allocators using $(D NullAllocator)
    shouldn't be unnecessarily constrained.
    */
    enum uint alignment = 64 * 1024;
    /// Returns $(D n).
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
    bool expand(ref void[] b, size_t) shared
    { assert(b is null); return false; }
    /// Ditto
    bool reallocate(ref void[] b, size_t) shared
    { assert(b is null); return false; }
    /// Ditto
    bool alignedReallocate(ref void[] b, size_t, uint) shared
    { assert(b is null); return false; }
    /// Returns $(D Ternary.no).
    Ternary owns(void[]) shared const { return Ternary.no; }
    /**
    Returns $(D null).
    */
    void[] resolveInternalPointer(void*) shared const { return null; }
    /**
    No-op.
    Precondition: $(D b is null)
    */
    bool deallocate(void[] b) shared { assert(b is null); return true; }
    /**
    No-op.
    */
    bool deallocateAll() shared { return true; }
    /**
    Returns $(D Ternary.yes).
    */
    Ternary empty() shared const { return Ternary.yes; }
    /**
    Returns the $(D shared) global instance of the $(D NullAllocator).
    */
    static shared NullAllocator instance;
}

unittest
{
    auto b = NullAllocator.instance.allocate(100);
    assert(b is null);
    NullAllocator.instance.deallocate(b);
    NullAllocator.instance.deallocateAll();
    import std.experimental.allocator.common : Ternary;
    assert(NullAllocator.instance.owns(null) == Ternary.no);
}
