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

private struct InSituStringCore(C)
{
    enum size_t capacity = 64 / C.sizeof - 1;
    // state {
    C[capacity] _payload = void;
    ubyte _length = 0;
    // } state

    bool valid() const { return _length <= capacity; }
    void invalidate() { _length = _length.max; }
    size_t length() const { return _length; }
    auto payloadPtr() inout { return _payload.ptr; }

    void forceLength(size_t len)
    {
        assert(len <= capacity);
        _length = cast(ubyte) len;
    }
}

private struct CowStringCore(C)
{
    // state {
    void[] _support;
    C[] _payload;
    // } state

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
        assert(cap > oldCapacity);
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

    void incRef()
    {
        if (_support is null) return;
        ++*prefs;
    }

    void decRef()
    {
        if (_support is null) return;
        auto p = prefs;
        if (!*p) alloc.deallocate(_support);
        else --*p;
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

struct B
{
    int x;
    this(int y) immutable
    {
        x = y;
    }
}

unittest
{
    auto b = immutable(B)(42);
    assert(b.x == 42);
}

struct A
{
    B x;
    this(int y) immutable
    {
        x = immutable(B)(y);
    }
}

unittest
{
    auto a = immutable(A)(42);
    assert(a.x.x == 42);
}

/**
*/
struct RCStr(C)
if (isSomeChar!C)
{
    import std.conv, std.range, std.traits;
    alias K = Unqual!C;

    // state {
    private union
    {
        static assert(InSituStringCore!K.sizeof > CowStringCore!K.sizeof);
        InSituStringCore!K _small;
        CowStringCore!K _large = void;
    }
    // }

    this(S)(S str) if (isSomeString!S)
    {
        assert(isSmall && codeUnits == 0);
        this ~= str;
    }

    this(S)(S str) immutable if (isSomeString!S)
    {
        if (str.length <= _small.capacity)
        {
            /*_small.payloadPtr[0 .. str.length] = str[];
            _small.forceLength(str.length);*/
        }
        else
        {
            assert(0);
        }
    }

    this(this)
    {
        if (!isSmall) _large.incRef;
    }

    ~this()
    {
        if (!isSmall) _large.decRef;
    }

    void opAssign(RCStr!C rhs)
    {
        this.__dtor;
        if (rhs.isSmall)
        {
            _small.payloadPtr[0 .. rhs._small.length] = rhs.payload[];
            _small.forceLength(rhs._small.length);
        }
        else
        {
            _small.invalidate;
            emplace(&_large, rhs._large);
            _large.incRef;
        }
    }

    private bool isSmall() const { return _small.valid; }

    private auto payload() inout
    {
        return isSmall ? _small.payload : _large.payload;
    }

    /**
    Returns the number of code units (e.g. bytes for UTF8) in the string.
    */
    size_t codeUnits() const
    {
        return isSmall ? _small.length : _large.length;
    }

    /**
    Returns the number of code units (e.g. bytes for UTF8) in the string.
    */
    size_t capacity() const
    {
        return isSmall ? _small.capacity : _large.capacity;
    }

    /**
    */
    int opCmp(in RCStr!C rhs) const
    {
        return opCmp(rhs.payload);
    }

    /**
    */
    bool opEquals(in RCStr!C rhs)
    {
        return payload == rhs.payload;
    }

    /**
    */
    int opCmp(in K[] rhs) const
    {
        auto lhs = payload;
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
        return payload == rhs;
    }

    // Reserves at least `s` code units for this string.
    private void reserve(size_t s)
    {
        if (!isSmall)
        {
            // large to possibly larger
            _large.reserve(s);
            return;
        }
        if (s <= _small.capacity) return;
        // small to large
        typeof(_large) t;
        t.reserve(s);
        assert(t.capacity > _small.length);
        t.payloadPtr[0 .. _small.length] = _small.payload;
        t.forceLength(_small.length);
        import core.stdc.string;
        memcpy(&_large, &t, t.sizeof);
        emplace(&t);
        _small.invalidate;
    }

    auto opCast(T)() if (is(T == immutable RCStr!C))
    {
        if (isSmall)
        {
            return immutable(RCStr!C)(_small.payload);
        }
        assert(0);
        /*static if (is(C == immutable))
        {

        }*/
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
        this ~= rhs.payload;
    }

    void opCatAssign(C1)(C1 c)
    if (isSomeChar!C1)
    {
        static if (C1.sizeof > C.sizeof)
        {
            assert(0);
            static C[4] buf;
            import std.utf : encode;
            auto len = encode(buf, c);
            return this ~= buf[0 .. len];
        }
        else
        {
            if (isSmall)
            {
                if (_small.length < _small.capacity)
                {
                    // small to small
                    _small.payloadPtr[_small.length] = c;
                    _small.forceLength(_small.length + 1);
                    assert(isSmall);
                }
                else
                {
                    // small to large
                    reserve(_small.capacity + 1);
                    assert(!isSmall);
                    _large.payloadPtr[_large.length] = c;
                    _large.forceLength(_large.length + 1);
                }
            }
            else
            {
                // large to larger
                if (_large.capacity == _large.length)
                    _large.reserve(_large.capacity * 3 / 2);
                _large.payloadPtr[_large.length] = c;
                _large.forceLength(_large.length + 1);
            }
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
    assert(s.capacity == InSituStringCore!C.capacity);
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
}

version(unittest) private void test2(C)()
{
    /*static immutable(RCStr!C) fun(immutable RCStr!C s)
    {
        return s ~ s;
    }*/
    auto s1 = RCStr!C("1234");
    auto s2 = cast(immutable RCStr!C) s1;
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
