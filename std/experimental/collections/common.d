/**
Utility and ancillary artifacts of `std.experimental.collections`.
*/
module std.experimental.collections.common;
import std.range : isInputRange;

package auto tail(Collection)(Collection collection)
if (isInputRange!Collection)
{
    collection.popFront();
    return collection;
}

package auto threadAllocatorObject()
{
    import std.experimental.allocator : RCIAllocator;

    static @nogc nothrow
    RCIAllocator wrapAllocatorObject()
    {
        import std.experimental.allocator.mallocator : Mallocator;
        import std.experimental.allocator : allocatorObject;

        return allocatorObject(Mallocator.instance);
    }
    auto fn = (() @trusted =>
            cast(RCIAllocator function() @nogc nothrow pure @safe)(&wrapAllocatorObject))();
    return fn();
}

package auto processAllocatorObject()
{
    import std.experimental.allocator : RCISharedAllocator;

    static @nogc nothrow
    RCISharedAllocator wrapAllocatorObject()
    {
        import std.experimental.allocator.mallocator : Mallocator;
        import std.experimental.allocator : sharedAllocatorObject;

        return sharedAllocatorObject(Mallocator.instance);
    }
    auto fn = (() @trusted =>
            cast(RCISharedAllocator function() @nogc nothrow pure @safe)(&wrapAllocatorObject))();
    return fn();
}

// Returns an instance of the default allocator
package auto defaultAllocator(Q)()
{
    static if (is(Q == immutable) || is(Q == const))
        return processAllocatorObject();
    else
        return threadAllocatorObject();
}

package struct AllocatorHandler
{
    import std.experimental.allocator : RCIAllocator, RCISharedAllocator,
           dispose, stateSize, theAllocator, processAllocator;
    import std.experimental.allocator.building_blocks.affix_allocator : AffixAllocator;
    import std.conv : emplace;
    import core.atomic : atomicOp;
    import std.algorithm.mutation : move;
    debug(AllocatorHandler) import std.stdio : writefln;

    private union
    {
        void *_;
        size_t _pMeta;
    }

    alias LocalAllocT = AffixAllocator!(RCIAllocator, size_t);
    alias SharedAllocT = shared AffixAllocator!(RCISharedAllocator, size_t);

    private static struct Metadata
    {
        union LAllocator
        {
            LocalAllocT alloc;
        }
        union SAllocator
        {
            SharedAllocT alloc;
        }

        LAllocator _localAlloc;
        SAllocator _sharedAlloc;
        bool _isShared;
        size_t _rc = 1;
    }

    pragma(inline, true)
    pure nothrow @trusted @nogc
    bool isNull() const
    {
        return (cast(void*) _pMeta) is null;
    }

    pragma(inline, true)
    pure nothrow @safe @nogc
    bool isShared() const
    {
        return isSharedMeta(_pMeta);
    }

    nothrow pure @trusted
    this(A, this Q)(A alloc)
    if (!is(Q == shared)
        && (is(A == RCISharedAllocator) || !is(Q == immutable))
        && (is(A == RCIAllocator) || is(A == RCISharedAllocator)))
    {
        //assert(alloc.alignment >= Metadata.alignof);

        // Allocate mem for metadata
        //auto state = alloc.allocate(stateSize!Metadata);

        auto dg = cast(void[] delegate(size_t, TypeInfo) nothrow pure)(&alloc.allocate);
        auto state = dg(stateSize!Metadata, null);
        assert(state !is null, "Invalid state.");

        auto meta = emplace!Metadata(state);
        assert(state.ptr == meta, "Emplacing state into meta failed.");
        assert(meta._rc == 1, "Reference-count should be 1.");

        static if (is(A == RCISharedAllocator))
        {
            auto shAlloc = SharedAllocT(alloc);
            auto sz = stateSize!SharedAllocT;
            (cast(void*) &meta._sharedAlloc.alloc)[0 .. sz] = (cast(void*) &shAlloc)[0 .. sz];
            meta._isShared = true;
            SharedAllocT init;
            (cast(void*) &shAlloc)[0 .. sz] = (cast(void*) &init)[0 .. sz];
        }
        else
        {
            auto lcAlloc = LocalAllocT(alloc);
            move(lcAlloc, meta._localAlloc.alloc);
        }
        _pMeta = cast(size_t) state.ptr;
    }

    pure nothrow @safe @nogc
    //this(this Q)(ref Q rhs)
    this(const ref typeof(this) rhs)
    {
        assert((() @trusted => (cast(void*) _pMeta) is null)(), "Initialization already happend.");
        _pMeta = rhs._pMeta;
        incRef(_pMeta);
    }

    pure nothrow @safe /*@nogc*/
    ref typeof(this) opAssign(const ref typeof(this) rhs) return
    {
        debug(AllocatorHandler)
        {
            writefln("AllocatorHandler.opAssign: begin");
            scope(exit) writefln("AllocatorHandler.opAssign: end");
        }

        auto pMeta = (() @trusted => cast(void*) _pMeta)();
        auto rhspMeta = (() @trusted => cast(void*) rhs._pMeta)();
        if (rhspMeta !is null && _pMeta == rhs._pMeta)
        {
            return this;
        }
        if (rhspMeta !is null)
        {
            rhs.incRef(rhs._pMeta);
            debug(AllocatorHandler) writefln(
                    "AllocatorHandler.opAssign: AllocatorHandler %s has refcount: %s",
                    &this, rhs.getRC);
        }
        if (pMeta) decRef(_pMeta);
        _pMeta = rhs._pMeta;
        return this;
    }

    pure nothrow @safe @nogc
    void bootstrap(this Q)()
    {
        // TODO: it's possible that the _pMeta payload is empty
        //assert((() @trusted => cast(void*) _pMeta)(), "Invalid _pMeta payload.");
        if (_pMeta)
            incRef(_pMeta);
    }

    pure nothrow @safe /*@nogc*/
    ~this()
    {
        auto pMeta = (() @trusted => cast(void*) _pMeta)();
        if (pMeta is null)
        {
            debug(AllocatorHandler) writeln("META IS NULL");
            return;
        }
        decRef(_pMeta);
    }

    //debug(AllocatorHandler)
    pragma(inline, true)
    private pure nothrow @trusted @nogc
    size_t getRC(this _)()
    {
        auto meta = cast(Metadata*) _pMeta;
        return meta._rc;
    }

    pragma(inline, true)
    static private pure nothrow @trusted @nogc
    bool isSharedMeta(const size_t pMeta)
    {
        assert(cast(void*) pMeta, "Invalid _pMeta payload.");
        auto meta = cast(Metadata*) pMeta;
        return meta._isShared;
    }

    pragma(inline, true)
    static private pure nothrow @trusted @nogc
    ref auto localAllocator(const size_t pMeta)
    {
        assert(cast(void*) pMeta, "Invalid _pMeta payload.");
        auto meta = cast(Metadata*) pMeta;
        assert(!meta._isShared, "Meta can't be shared.");
        return meta._localAlloc.alloc;
    }

    pragma(inline, true)
    static private pure nothrow @trusted @nogc
    ref auto sharedAllocator(const size_t pMeta)
    {
        assert(cast(void*) pMeta, "Invalid _pMeta payload.");
        auto meta = cast(Metadata*) pMeta;
        assert(meta._isShared, "Meta has to be shared.");
        return meta._sharedAlloc.alloc;
    }

    static private @nogc nothrow pure @trusted
    void incRef(const size_t pMeta)
    {
        auto tmeta = cast(Metadata*) pMeta;
        if (tmeta._isShared)
        {
            auto meta = cast(shared Metadata*) pMeta;
            atomicOp!"+="(meta._rc, 1);
        }
        else
        {
            auto meta = cast(Metadata*) pMeta;
            ++meta._rc;
        }
    }

    static private @nogc nothrow pure @trusted
    void decRef(const size_t pMeta)
    {
        auto tmeta = cast(Metadata*) pMeta;
        void[] origState = (cast(void*) tmeta)[0 .. stateSize!Metadata];

        if (tmeta._isShared)
        {
            auto meta = cast(shared Metadata*) pMeta;
            debug(AllocatorHandler) writeln("is shared");
            if (atomicOp!"-="(meta._rc, 1) == 0)
            {
                debug(AllocatorHandler) writeln("Here 2");
                SharedAllocT a;
                // Bitblast the allocator on the stack copy; this will ensure that the
                // dtor inside the union will be called
                // Workaround for move
                auto sz = stateSize!SharedAllocT;
                (cast(void*) &a)[0 .. sz] = (cast(void*) &meta._sharedAlloc.alloc)[0 .. sz];
                SharedAllocT init;
                (cast(void*) &meta._sharedAlloc.alloc)[0 .. sz] = (cast(void*) &init)[0 .. sz];
                //a.parent.deallocate(origState);
                (cast(bool delegate(void[]) @nogc nothrow pure)(&a.parent.deallocate))(origState);
            }
        }
        else
        {
            debug(AllocatorHandler) writeln("is not shared");
            auto meta = cast(Metadata*) pMeta;
            if (--meta._rc == 0)
            {
                debug(AllocatorHandler) writeln("Here 3");
                LocalAllocT a;
                move(meta._localAlloc.alloc, a);
                //assert(meta._localAlloc.alloc == LocalAllocT.init);
                //a.parent.deallocate(origState);
                (cast(bool delegate(void[]) @nogc nothrow pure)(&a.parent.deallocate))(origState);
            }
        }
    }

nothrow:

    pure @trusted
    void[] allocate(size_t n) const
    {
        return (cast(void[] delegate(size_t) const nothrow pure)(&_allocate))(n);
    }

    void[] _allocate(size_t n) const
    {
        assert(cast(void*) _pMeta, "Invalid _pMeta payload.");
        return isSharedMeta(_pMeta) ?
            sharedAllocator(_pMeta).allocate(n) :
            localAllocator(_pMeta).allocate(n);
    }

    pure @trusted
    bool expand(ref void[] b, size_t delta) const
    {
        return (cast(bool delegate(ref void[], size_t) const nothrow pure)(&_expand))(b, delta);
    }

    bool _expand(ref void[] b, size_t delta) const
    {
        assert(cast(void*) _pMeta, "Invalid _pMeta payload.");
        return isSharedMeta(_pMeta) ?
            sharedAllocator(_pMeta).expand(b, delta) :
            localAllocator(_pMeta).expand(b, delta);
    }

    pure
    bool deallocate(void[] b) const
    {
        return (cast(bool delegate(void[]) const nothrow pure)(&_deallocate))(b);
    }

    bool _deallocate(void[] b) const
    {
        assert(cast(void*) _pMeta, "Invalid _pMeta payload.");
        return isSharedMeta(_pMeta) ?
            sharedAllocator(_pMeta).deallocate(b) :
            localAllocator(_pMeta).deallocate(b);
    }

    @nogc nothrow pure @trusted
    private size_t prefix(T)(const T[] b) const
    {
        assert(cast(void*) _pMeta, "Invalid _pMeta payload.");
        return isSharedMeta(_pMeta) ?
            cast(size_t)&sharedAllocator(_pMeta).prefix(b) :
            cast(size_t)&localAllocator(_pMeta).prefix(b);
    }

    @nogc nothrow pure @trusted
    size_t opPrefix(string op, T)(const T[] support, size_t val) const
    if ((op == "+=") || (op == "-="))
    {
        assert(cast(void*) _pMeta, "Invalid _pMeta payload.");
        if (isSharedMeta(_pMeta))
        {
            return cast(size_t)(atomicOp!op(*cast(shared size_t *)prefix(support), val));
        }
        else
        {
            mixin("return cast(size_t)(*cast(size_t *)prefix(support)" ~ op ~ "val);");
        }
    }

    @nogc nothrow pure @trusted
    size_t opCmpPrefix(string op, T)(const T[] support, size_t val) const
    if ((op == "==") || (op == "<=") || (op == "<") || (op == ">=") || (op == ">"))
    {
        assert(cast(void*) _pMeta, "Invalid _pMeta payload.");
        if (isSharedMeta(_pMeta))
        {
            return cast(size_t)(atomicOp!op(*cast(shared size_t *)prefix(support), val));
        }
        else
        {
            mixin("return cast(size_t)(*cast(size_t *)prefix(support)" ~ op ~ "val);");
        }
    }

    /*@nogc*/ nothrow pure @safe
    AllocatorHandler getSharedAlloc() const
    {
        if (isNull || !isShared)
        {
            return AllocatorHandler(processAllocatorObject());
        }
        return AllocatorHandler(this);
    }

    @nogc nothrow pure @safe
    RCIAllocator getLocalAlloc() const
    {
        if (isNull || isShared)
        {
            return threadAllocatorObject();
        }
        return localAllocator(_pMeta).parent;
    }
}

version(unittest)
{
    // Structs used to test the type system inference
    package static struct Unsafe()
    {
        int _x;
        @system this(int x) {}
    }

    package static struct UnsafeDtor()
    {
        int _x;
        @nogc nothrow pure @safe this(int x) {}
        @system ~this() {}
    }

    package static struct Impure()
    {
        import std.experimental.allocator : RCIAllocator, theAllocator;
        RCIAllocator _a;
        @safe this(int id) { _a = theAllocator; }
    }

    package static struct ImpureDtor()
    {
        import std.experimental.allocator : RCIAllocator, theAllocator;
        RCIAllocator _a;
        @nogc nothrow pure @safe this(int x) {}
        @safe ~this() { _a = theAllocator; }
    }

    package static struct Throws()
    {
        import std.exception : enforce;
        int _x;
        this(int id) { enforce(id > 0, "Id must be non-zero."); }
    }

    package static struct ThrowsDtor()
    {
        import std.exception : enforce;
        int _x;
        @nogc nothrow pure @safe this(int x) {}
        ~this() { enforce(_x > 0, "_x must be non-zero."); }
    }
}

@system unittest
{
    import std.experimental.allocator.mallocator;
    import std.experimental.allocator.building_blocks.stats_collector;
    import std.experimental.allocator : RCIAllocator, RCISharedAllocator,
           allocatorObject, sharedAllocatorObject, processAllocator, theAllocator;
    import std.conv : to;
    import std.stdio;
    import std.traits;

    struct MyA(A)
    {
        A a;
        alias a this;

        pure nothrow @nogc
        bool deallocate(void[] b)
        {
            return (cast(bool delegate(void[]) pure nothrow @nogc)(&a.deallocate))(b);
        }

        bool forceAttDealloc(void[] b)
        {
            return a.deallocate(b);
        }
    }

    //alias SCAlloc = MyA!(StatsCollector!(Mallocator, Options.bytesUsed));
    alias SCAlloc = StatsCollector!(Mallocator, Options.bytesUsed);
    SCAlloc statsCollectorAlloc;
    size_t bytesUsed = statsCollectorAlloc.bytesUsed;
    assert(bytesUsed == 0);
    {
        auto _allocator = allocatorObject(&statsCollectorAlloc);
        auto sca = AllocatorHandler(_allocator);
        auto buf = sca.allocate(10);
        assert(buf.length == 10);

        auto t = cast(size_t*)(sca.prefix(buf));
        assert(*t == 0);
        *t += 1;
        assert(*t == *cast(size_t*)sca.prefix(buf));
        sca.deallocate(buf);
    }
    bytesUsed = statsCollectorAlloc.bytesUsed;
    assert(bytesUsed == 0, "MutableDualAlloc ref count leaks memory; leaked "
            ~ to!string(bytesUsed) ~ " bytes");

    // Test immutable allocator
    auto ia = immutable AllocatorHandler(processAllocator);
    auto buf = ia.allocate(10);
    assert(buf.length == 10);
    ia.deallocate(buf);

    static assert(!__traits(compiles, { auto ia2 = immutable AllocatorHandler(theAllocator); }));
    const ca = const AllocatorHandler(theAllocator);
}

@system unittest
{
    import std.experimental.allocator : RCIAllocator, RCISharedAllocator,
           allocatorObject, sharedAllocatorObject, processAllocator, theAllocator;
    import std.stdio;

    auto sca = immutable AllocatorHandler(processAllocator);
    auto buf = sca.allocate(10);
    assert(buf.length == 10);
    sca.deallocate(buf);

    const al = sca.getSharedAlloc;
    const al2 = al.getSharedAlloc;
    assert(al._pMeta == al2._pMeta);
}

package enum allocatorHandler = q{
    AllocatorHandler _allocator;

    /*
    Constructs the ouroboros allocator from allocator if the ouroboros
    allocator wasn't previously set
    */
    import std.traits : Unqual;
    package(std)
    /*@nogc*/ nothrow pure @safe
    bool setAllocator(A)(ref A allocator)
    if (is(Unqual!A == RCIAllocator) || is(Unqual!A == RCISharedAllocator))
    {
        if (_allocator.isNull)
        {
            auto a = typeof(_allocator)(allocator);
            move(a, _allocator);
            return true;
        }
        return false;
    }

};
