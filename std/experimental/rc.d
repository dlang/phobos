module std.experimental.rc;
import std.traits : isSomeChar, isSomeString;

import std.experimental.allocator.gc_allocator,
    std.experimental.allocator.building_blocks.affix_allocator;
version(unittest)
    import std.experimental.allocator.building_blocks.stats_collector;
version(unittest)
{
    private alias Alloc = StatsCollector!(
        AffixAllocator!(GCAllocator, uint),
        Options.bytesUsed
    );
    Alloc alloc;
}
else
{
    private alias Alloc = AffixAllocator!(GCAllocator, uint);
    alias alloc = Alloc.instance;
}

struct A1
{
    this(int) immutable;
    //~this();
}

struct A2
{
    this(int) immutable;
}

struct B
{
    union
    {
        A1 a1;
        A2 a2;
    }
    bool itsA2;
    this(int x) immutable
    {
        if (x < 0)
        {
            a1 = immutable(A1)(x);
        }
        else
        {
            a2 = immutable(A2)(x);
            itsA2 = true;
        }
    }
}

private struct SmallString(BaseStringCore)
{
    import std.traits;

    enum size_t smallCapacity = 64 / C.sizeof - 1;
    static assert(smallCapacity * C.sizeof >= BaseStringCore.sizeof);
    alias C = typeof(*(BaseStringCore.init.payloadPtr));
    alias K = Unqual!C;

    // state {
    union
    {
        size_t[64 / size_t.sizeof] _buffer_ = void;
        struct
        {
            K[64 / K.sizeof - 1] _small = void;
            ubyte _length = 0;
        }
    }
    // } state

    auto ref _large() inout
    {
        return *cast(inout BaseStringCore*) &this;
    }

    this(const K[] data) immutable
    {
        if (data.length <= smallCapacity)
        {
            _small[0 .. data.length] = data;
            _length = cast(ubyte) data.length;
        }
        else
        {
            import std.conv;
            //_large() = BaseStringCore(data);
            emplace(&_large(), immutable(BaseStringCore)(data));
            forceLarge;
        }
    }

    this(this)
    {
        if (!isSmall) _large.__postblit;
    }

    ~this()
    {
        if (!isSmall) _large.__dtor;
    }

    private bool isSmall() const { return _length <= smallCapacity; }
    private void forceLarge() { _length = _length.max; }
    size_t length() const { return isSmall ? _length : _large.length; }
    size_t capacity() const
    {
        return isSmall ? smallCapacity : _large.capacity;
    }
    auto payloadPtr() inout { return isSmall ? _small.ptr : _large.payloadPtr; }

    void forceLength(size_t len)
    {
        assert(len <= capacity);
        if (isSmall) _length = cast(ubyte) len;
        else _large.forceLength(len);
    }

    void reserve(size_t newCapacity)
    {
        if (!isSmall)
        {
            // large to possibly larger
            _large.reserve(newCapacity);
            return;
        }
        if (newCapacity <= smallCapacity) return;
        // small to large
        BaseStringCore t;
        t.reserve(newCapacity);
        assert(t.capacity > _small.length);
        t.payloadPtr[0 .. _small.length] = _small[0 .. _small.length];
        t.forceLength(_small.length);
        import core.stdc.string;
        memcpy(&_large(), &t, t.sizeof);
        import std.conv;
        emplace(&t);
        forceLarge;
    }
}

private struct CowStringCore(C)
{
    // state {
    void[] _support;
    C[] _payload;
    // } state

    this(K)(K[]) immutable
    {
        assert(0);
    }

    this(this)
    {
        if (_support is null) return;
        ++*prefs;
    }

    ~this()
    {
        if (_support is null) return;
        auto p = prefs;
        if (!*p) alloc.deallocate(_support);
        else --*p;
    }

    size_t length() const
    {
        return _payload.length;
    }

    size_t capacity() const
    {
        return cast(C*) (_support.ptr + _support.length) - _payload.ptr;
    }

    unittest
    {
        CowStringCore t;
        assert(t.capacity == 0);
    }

    auto payloadPtr() inout { return _payload.ptr; }

    void forceLength(size_t len)
    {
        assert(len <= capacity);
        _payload = _payload.ptr[0 .. len];
    }

    void reserve(size_t cap)
    {
        auto oldCapacity = capacity;
        if (cap <= oldCapacity) return;
        if (_support
            && *prefs == 0
            && alloc.expand(_support, C.sizeof * (cap - oldCapacity)))
        {
            return;
        }
        // Need to create a whole new string
        auto t = cast(C[]) alloc.allocate(C.sizeof * cap);
        t || assert(0);
        assert(alloc.parent.prefix(t) == 0);
        t[0 .. _payload.length] = _payload[];
        if (_support !is null)
        {
            auto p = prefs;
            if (!*p) alloc.deallocate(_support);
            else --*p;
        }
        _payload = t[0 .. _payload.length];
        _support = t;
    }

    private uint* prefs()
    {
        assert(_support !is null);
        return &alloc.parent.prefix(_support);
    }

}

private auto payload(RCStr)(ref RCStr s)
{
    return s.payloadPtr()[0 .. s.length];
}

private auto slack(RCStr)(ref RCStr s)
{
    return s.payloadPtr[s.length .. s.capacity];
}

/**
*/
struct RCStr(C)
if (isSomeChar!C)
{
    import std.conv, std.range, std.traits;
    alias K = Unqual!C;

    // state {
    alias Core = SmallString!(CowStringCore!K);
    Core _core;
    // }

    this(S)(S str) if (isSomeString!S)
    {
        assert(codeUnits == 0);
        this ~= str;
    }

    this(S)(S str) immutable if (isSomeString!S)
    {
        _core = immutable(Core)(str);
    }

    void opAssign(RCStr!C rhs)
    {
        opAssign(rhs._core.payload);
    }

    void opAssign(R)(R rhs)
    if (isInputRange!R && isSomeChar!(ElementEncodingType!R))
    {
        static if (isSomeString!R)
        {
            static if (rhs[0].sizeof == C.sizeof)
            {
                _core.reserve(rhs.length);
                // TODO: optimize case when rhs and this have same support
                _core.payloadPtr[0 .. rhs.length] = rhs[];
                _core.forceLength(rhs.length);
            }
            else
            {
                // Transcode using autodecoding
                clear;
                for (; !rhs.empty; rhs.popFront)
                {
                    this ~= rhs.front;
                }
            }
        }
        else
        {
            assert(0);
        }
    }

    /**
    */
    void clear()
    {
        _core.forceLength(0);
    }

    /**
    Returns the number of code units (e.g. bytes for UTF8) in the string.
    */
    size_t codeUnits() const
    {
        return _core.length;
    }

    /**
    Returns the maximum number of code units (e.g. bytes for UTF8) that this
    string may contain without a (re)allocation.
    */
    size_t capacity() const
    {
        return _core.capacity;
    }

    /**
    */
    int opCmp(in RCStr!C rhs) const
    {
        return opCmp(rhs._core.payload);
    }

    /**
    */
    bool opEquals(in RCStr!C rhs) const
    {
        return _core.payload == rhs._core.payload;
    }

    /**
    */
    int opCmp(in K[] rhs) const
    {
        auto lhs = _core.payload;
        import std.algorithm.comparison : mismatch;
        import std.string : representation;
        auto r = mismatch(lhs.representation, rhs.representation);
        if (r[0].empty) return r[1].empty ? 0 : -1;
        if (r[1].empty) return 1;
        // Both are non-empty
        auto c0 = r[0][0], c1 = r[1][0];
        return c0 < c1 ? -1 : (c0 > c1);
    }

    /**
    */
    bool opEquals(in C[] rhs)
    {
        return _core.payload == rhs;
    }

    /// Reserves at least `s` code units for this string.
    void reserve(size_t s)
    {
        _core.reserve(s);
    }

    auto opCast(T)() if (is(T == immutable RCStr!C))
    {
        return immutable(RCStr!C)(_core.payload);
    }

    auto opCat(X)(X x)
    if (is(typeof(this ~= x)))
    {
        // TODO: optimize
        auto result = this;
        result ~= x;
        return result;
    }

    void opCatAssign(RCStr!C rhs)
    {
        this ~= rhs._core.payload;
    }

    void opCatAssign(C1)(C1 c)
    if (isSomeChar!C1)
    {
        static if (C1.sizeof > C.sizeof)
        {
            K[4 / C.sizeof] buf = void;
            import std.utf : encode;
            return this ~= buf[0 .. encode(buf, c)];
        }
        else
        {
            immutable cap = _core.capacity, len = _core.length;
            if (len == cap)
            {
                _core.reserve(cap * 3 / 2);
            }
            _core.payloadPtr[len] = c;
            _core.forceLength(len + 1);
        }
    }

    void opCatAssign(R)(R r)
    if (isInputRange!R && isSomeChar!(ElementType!R))
    {
        // TODO: optimize
        import std.traits : isSomeString;
        static if (isSomeString!R)
        {
            import std.utf : byChar;
            auto p = r.byChar;
        }
        else
        {
            alias p = r;
        }
        for (; !p.empty; p.popFront)
            this ~= p.front;
    }
}

version(unittest) private void test(C)()
{
    RCStr!C s;
    assert(s == s);
    assert(s <= s);
    assert(!(s < s));
    assert(s.codeUnits == 0);
    assert(s.capacity > 0);
    s ~= '1';
    assert(s.codeUnits == 1);
    assert(s < "2");
    assert(s > "");
    assert(s > "0");
    string x = "23456789012345678901234567890123456789012345678901234567890123";
    s ~= x;
    //import std.stdio;
    //writeln(s.codeUnits);
    assert(s.codeUnits == 63);
    assert(s ==
        "123456789012345678901234567890123456789012345678901234567890123");
    s ~= '4';
    assert(s.codeUnits == 64);
    s ~= '5';
    assert(s.codeUnits == 65);
    auto s1 = s;
    s ~= s;
    assert(s.codeUnits == 130);
    assert(s ==
        "12345678901234567890123456789012345678901234567890123456789012345"
        "12345678901234567890123456789012345678901234567890123456789012345");
    auto s2 = s1 ~ s1;
    assert(s2 == s);
    s2 = s;
    assert(s2 == s);
    s = "123";
    assert(s == "123");
    s = "123"w;
    assert(s == "123");
    s = "123"d;
    assert(s == "123");
}

version(unittest) private void test2(C)()
{
    /*static immutable(RCStr!C) fun(immutable RCStr!C s)
    {
        return s ~ s;
    }*/
    auto s1 = RCStr!C("1234");
    auto s2 = cast(immutable RCStr!C) s1;
    assert(s2 == s1);
}

unittest
{
    test!char;
    test!(const char);
    test!(immutable char);
    test!wchar;
    test!(const wchar);
    test!(immutable wchar);
    test!dchar;
    test!(const dchar);
    test!(immutable dchar);

    test2!char;

    import std.stdio;
    writeln(alloc.bytesUsed);
}
