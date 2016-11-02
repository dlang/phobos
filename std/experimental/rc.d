module std.experimental.rc;
import std.range : ElementType;
import std.traits : TemplateOf, Unqual;
import std.experimental.allocator.gc_allocator,
    std.experimental.allocator.mallocator,
    std.experimental.allocator.building_blocks.affix_allocator;
version(unittest)
{
    import std.string : representation;
    import std.experimental.allocator.building_blocks.stats_collector,
        std.stdio;
}

// Allocator used by the refcounted buffer
version(unittest)
{
    private alias Alloc = StatsCollector!(
        AffixAllocator!(Mallocator, uint),
        Options.bytesUsed
    );
    Alloc alloc;
}
else
{
    private alias Alloc = AffixAllocator!(GCAllocator, uint);
    alias alloc = Alloc.instance;
}

private enum isSomeUbyte(T) = is(Unqual!T == ubyte);

private struct CowCore(C)
{
    // state {
    private Unqual!C[] _support;
    private C[] _payload;
    // } state

    // Constructs this as an immutable buffer containing the concatenation of
    // s1 and s2.
    this(C1, C2 = C)(C1[] s1, C2[] s2 = null) immutable
    if (isSomeUbyte!C1 && isSomeUbyte!C2)
    {
        // Strategy: build a mutable buffer, then move it.
        CowCore!C t;
        import std.conv, std.exception, std.range, std.utf;
        immutable len = s1.length + s2.length;
        t.reserve(len);
        size_t i = 0;
        t._support[0 .. s1.length] = s1[];
        t._support[s1.length .. len] = s2[];
        t.forceLength(len);
        _support = t._support.assumeUnique;
        _payload = t._payload.assumeUnique;
        emplace(&t);
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

    void popFront()
    {
        assert(length);
        _payload = _payload[1 .. $];
    }

    size_t length() const
    {
        return _payload.length;
    }

    private @system auto payloadPtr() inout { return _payload.ptr; }

    void forceLength(size_t len)
    {
        assert(len <= length + slackBack);
        _payload = _payload.ptr[0 .. len];
    }

    void reserve(size_t cap)
    out
    {
        assert(length + slackBack >= cap);
    }
    body
    {
        auto oldCapacity = length + slackBack;
        if (cap <= oldCapacity) return;
        if (_support && *prefs == 0)
        {
            void[] buf = _support;
            if (alloc.expand(buf, C.sizeof * (cap - oldCapacity)))
            {
                _support = cast(Unqual!C[]) buf;
                return;
            }
        }
        // Need to create a whole new buffer
        auto t = cast(Unqual!C[]) alloc.allocate(C.sizeof * cap);
        t || assert(0);
        assert(alloc.parent.prefix(t) == 0);
        t[0 .. _payload.length] = _payload[];
        // Kansas shuffle
        __dtor;
        _payload = cast(C[]) t[0 .. _payload.length];
        _support = t;
    }

    private uint* prefs() const
    {
        assert(_support !is null);
        return cast(uint*) &alloc.parent.prefix(_support);
    }

    auto opSlice(this Q)(size_t b, size_t e) const
    {
        assert(b <= e && e <= length);
        static if (is(Q == immutable)) alias R = CowCore!(immutable C);
        else static if (is(Q == const)) alias R = CowCore!(const C);
        else alias R = CowCore!C;
        R result = void;
        result._support = cast(typeof(result._support)) _support;
        result._payload = cast(typeof(result._payload)) _payload[b .. e];
        ++*prefs;
        return result;
    }

    private size_t slackFront() const
    {
        return _payload.ptr - _support.ptr;
    }

    private size_t slackBack() const
    {
        return _support.ptr + _support.length - _payload.ptr - _payload.length;
    }

    void opCatAssign(in C[] rhs)
    {
        immutable newLen = length + rhs.length;
        reserve(length + rhs.length);
        immutable appendStart = slackFront + length;
        _support[appendStart .. appendStart + rhs.length] = rhs;
        forceLength(newLen);
    }

    auto opCat(C1)(CowCore!C1 rhs)
    {
        alias R = typeof((new C[1] ~ new C1[1])[0]);
        CowCore!R result;
        static if (is(C == Unqual!C))
        {
            // Try to find slack space after this, but only if unique
            if (_support.ptr && *prefs == 0 && slackBack >= rhs.length)
            {
                immutable newLen = _payload.length + rhs.length;
                result._support = _support;
                result._payload = _payload.ptr[0 .. newLen];
                ++*result.prefs;
                result._payload[_payload.length .. newLen] = rhs._payload;
                return result;
            }
        }
        static if (is(C1 == Unqual!C1))
        {
            // Try to find slack space before rhs, if rhs is unique
            if (_support.ptr && *prefs == 0 && rhs.slackFront >= length)
            {
                immutable newLen = _payload.length + rhs.length;
                result._support = rhs._support;
                result._payload = (rhs._payload.ptr - length)[0 .. newLen];
                ++*result.prefs;
                result._payload[0 .. length] = _payload;
                return result;
            }
        }
        // Both parts are qualified and therefore untouchable
        result.reserve(length + rhs.length);
        result ~= _payload;
        result ~= rhs._payload;
        return result;
    }

    ref C opIndex(size_t n)
    {
        return _payload[n];
    }
}

private auto payload(RCBuffer)(ref RCBuffer s)
{
    return s.payloadPtr()[0 .. s.length];
}

/**
*/
struct RCBuffer(C)
if (isSomeUbyte!C)
{
    import std.algorithm.comparison, std.algorithm.mutation, std.conv,
        std.range, std.traits;

    alias CoreT = CowCore;
    alias Core = CoreT!C;
    // state {
    Core _core;
    // }

    /**
    */
    private this(C1)(CoreT!C1 core)
    {
        _core = core;
    }

    /// ditto
    this(S)(S str) if (isInputRange!S && isSomeUbyte!(.ElementType!S))
    {
        assert(length == 0);
        this ~= str;
    }

    /// ditto
    this(S)(S str) immutable if (isInputRange!S && isSomeUbyte!(.ElementType!S))
    {
        _core = immutable(Core)(str);
    }

    /**
    */
    void opAssign(RCBuffer!C rhs)
    {
        move(rhs._core, _core);
    }

    void opAssign(R)(R rhs)
    if (isInputRange!R && isSomeUbyte!(ElementType!R))
    {
        auto t = RCBuffer(rhs);
        move(t._core, _core);
    }

    /** */
    bool empty() const
    {
        return _core.length == 0;
    }

    // Range primitives
    alias ElementType = Unqual!C;

    ElementType front() const
    {
        assert(!empty);
        return *_core.payloadPtr;
    }

    static if (!is(C == const) && !is(C == immutable))
    void front(in ElementType x)
    {
        assert(!empty);
        *_core.payloadPtr = x;
    }

    void popFront()
    {
        assert(!empty);
        _core.popFront;
    }

    // Random access primitives
    ref ElementType opIndex(size_t i) return
    {
        return *cast(ElementType*) &_core[i];
    }

    C opIndex(size_t n) const
    {
        return _core.payload[n];
    }

    static if (is(C == Unqual!C))
    void opIndex(C x, size_t n)
    {
        _core.payload[n] = x;
    }

    auto opSlice() inout
    {
        return this;
    }

    auto opSlice(this _)(size_t b, size_t e)
    {
        assert(b <= e && e <= length);
        auto slice = _core[b .. e];
        return RCBuffer!(typeof(slice).ElementType)(slice);
    }

    /**
    */
    void clear()
    {
        _core.forceLength(0);
    }

    /**
    Returns the number of bytes in the buffer.
    */
    size_t length() const
    {
        return _core.length;
    }

    alias opDollar = length;

    /**
    Returns the number of bytes that this buffer may accommodate without a
    (re)allocation.
    */
    size_t slackFront() const
    {
        return _core.slackFront;
    }

    /// ditto
    size_t slackBack() const
    {
        return _core.slackBack;
    }

    /**
    */
    bool opEquals(C1)(in RCBuffer!C1 rhs) const
    {
        return this == rhs._core.payload;
    }

    /**
    */
    bool opEquals(C1)(in C1[] rhs) const if (isSomeUbyte!C1)
    {
        return equal(_core.payload, rhs);
    }

    /**
    */
    int opCmp(C1)(in RCBuffer!C1 rhs) const if (isSomeUbyte!C1)
    {
        return opCmp(rhs._core.payload);
    }

    /**
    */
    int opCmp(C1)(in C1[] rhs) const if (isSomeUbyte!C1)
    {
        return cmp(_core.payload, rhs);
    }

    /// Reserves at least `s` bytes for this buffer.
    void reserve(size_t s)
    {
        _core.reserve(s);
    }

    auto opCast(T)() if (is(T == immutable RCBuffer!C))
    {
        return immutable(RCBuffer!C)(_core.payload);
    }

    void opCatAssign(RCBuffer!C rhs)
    {
        this ~= rhs._core.payload;
    }

    void opCatAssign(C1)(C1 c)
    if (isSomeUbyte!C1)
    {
        immutable cap = length + slackBack, len = _core.length;
        assert(len <= cap);
        if (len == cap)
        {
            _core.reserve((cap + 1) * 3 / 2);
        }
        assert(len < length + slackBack);
        (cast(Unqual!C*) _core.payloadPtr())[len] = c;
        _core.forceLength(len + 1);
    }

    void opCatAssign(R)(R r)
    if (isInputRange!R && isSomeUbyte!(std.range.ElementType!R))
    {
        // TODO: optimize
        for (; !r.empty; r.popFront)
            this ~= r.front;
    }

    /**
    */
    auto opCat(T, this Q)(T[] rhs)
    if (isSomeUbyte!T)
    {
        alias R = typeof((_core.payload ~ rhs)[0]);
        static if (is(Q == const) || is(Q == immutable))
        {
            // Nothing interesting to do, allocate a new buffer
            // TODO: optimize
            RCBuffer!R result;
            result.reserve(_core.length + rhs.length);
            result ~= _core.payload;
            result ~= rhs;
            return result;
        }
        else
        {
            // TODO: implement the following strategy:
            // "this" is mutable, maybe there's slack space after it
            RCBuffer!R result;
            result.reserve(_core.length + rhs.length);
            result ~= _core.payload;
            result ~= rhs;
            return result;
        }
    }

    /**
    */
    auto opCat_r(T, this Q)(T[] lhs)
    if (isSomeUbyte!T)
    {
        alias R = typeof((lhs ~ _core.payload)[0]);
        static if (is(Q == const) || is(Q == immutable))
        {
            // Nothing interesting to do, allocate a new buffer
            // TODO: optimize
            RCBuffer!R result;
            result.reserve(lhs.length + _core.length);
            result ~= lhs;
            result ~= _core.payload;
            return result;
        }
        else
        {
            // TODO: implement the following strategy:
            // "this" is mutable, maybe there's slack space before it
            RCBuffer!R result;
            result.reserve(lhs.length + _core.length);
            result ~= lhs;
            result ~= _core.payload;
            return result;
        }
    }

    /**
    */
    auto opCat(T, this Q)(T rhs)
    if (is(Unqual!T == RCBuffer!C1, C1))
    {
        // Get rid of the cases when at least one side is qualified
        static if (is(T == const) || is(T == immutable))
        {
            // Rationale: rhs may be shared, we can't store lhs in the slack
            // space before it.
            return this ~ rhs._core.payload;
        }
        else static if (is(Q == const) || is(Q == immutable))
        {
            // Rationale: this may be shared, we can't store rhs in the slack
            // space after it.
            return _core.payload ~ rhs;
        }
        else
        {
            // Two mutable RCBuffers!
            auto newCore = _core ~ rhs._core;
            return RCBuffer!(typeof(*newCore.payloadPtr))(newCore);
        }
    }
}

unittest // concatenation types
{
    alias X = TemplateOf!(RCBuffer!ubyte);
    //static assert(!isOurSister!int);
    /*char[] a;
    const(char)[] b;
    immutable(char)[] c;
    const char[] d;
    immutable char[] e;
    const (const(char)[]) f;*/

    auto a = RCBuffer!ubyte([ubyte('a')]);
    auto b = RCBuffer!(const(ubyte))("b".representation);
    auto c = RCBuffer!(immutable(ubyte))("c".representation);
    const d = RCBuffer!ubyte("d".representation);
    immutable e = immutable(RCBuffer!ubyte)("e".representation);
    const RCBuffer!(const ubyte) f = RCBuffer!(const ubyte)("f".representation);

    auto x = a ~ "123".representation;

    /*CowCore!char a;
    CowCore!(const(char)) b;
    CowCore!(immutable(char)) c;
    const CowCore!char d;
    immutable CowCore!char e;
    const CowCore!(const char) f;*/

    assert (is(typeof(a ~ a) == typeof(a)));
    assert(a ~ a == "aa".representation);
    assert (is(typeof(a ~ b) == typeof(a)));
    assert(a ~ b == "ab".representation);
    assert (is(typeof(a ~ c) == typeof(a)));
    assert(a ~ c == "ac".representation);
    assert (is(typeof(a ~ d) == typeof(a)));
    assert(a ~ d == "ad".representation);
    assert (is(typeof(a ~ e) == typeof(a)));
    assert(a ~ e == "ae".representation);

    assert (is(typeof(b ~ a) == typeof(a) ));
    assert(b ~ a == "ba".representation);
    assert (is(typeof(b ~ b) == typeof(b) ));
    assert(b ~ b == "bb".representation);
    assert (is(typeof(b ~ c) == typeof(a) ));
    assert(b ~ c == "bc".representation);
    assert (is(typeof(b ~ d) == typeof(b) ));
    assert(b ~ d == "bd".representation);
    assert (is(typeof(b ~ e) == typeof(a) ));
    assert(b ~ e == "be".representation);

    assert (is(typeof(c ~ a) == typeof(a) ));
    assert(c ~ a == "ca".representation);
    assert (is(typeof(c ~ b) == typeof(a) ));
    assert(c ~ b == "cb".representation);
    assert (is(typeof(c ~ c) == typeof(c) ));
    assert(c ~ c == "cc".representation);
    assert (is(typeof(c ~ d) == typeof(a) ));
    assert(c ~ d == "cd".representation);
    assert (is(typeof(c ~ e) == typeof(c) ));
    assert(c ~ e == "ce".representation);

    assert (is(typeof(d ~ a) == typeof(a) ));
    assert(d ~ a == "da".representation);
    assert (is(typeof(d ~ b) == typeof(b) ));
    assert(d ~ b == "db".representation);
    assert (is(typeof(d ~ c) == typeof(a) ));
    assert(d ~ c == "dc".representation);
    assert (is(typeof(d ~ d) == typeof(b) ));
    assert(d ~ d == "dd".representation);
    assert (is(typeof(d ~ e) == typeof(a) ));
    assert(d ~ e == "de".representation);

    assert (is(typeof(e ~ a) == typeof(a) ));
    assert(e ~ a == "ea".representation);
    assert (is(typeof(e ~ b) == typeof(a) ));
    assert(e ~ a == "ea".representation);
    assert (is(typeof(e ~ c) == typeof(c) ));
    assert(e ~ a == "ea".representation);
    assert (is(typeof(e ~ d) == typeof(a) ));
    assert(e ~ a == "ea".representation);
    assert (is(typeof(e ~ e) == typeof(c) ));
    assert(e ~ a == "ea".representation);

    assert (is(typeof(f ~ a) == typeof(a) ));
    assert(f ~ a == "fa".representation);
    assert (is(typeof(f ~ b) == typeof(b) ));
    assert(f ~ a == "fa".representation);
    assert (is(typeof(f ~ c) == typeof(a) ));
    assert(f ~ a == "fa".representation);
    assert (is(typeof(f ~ d) == typeof(b) ));
    assert(f ~ a == "fa".representation);
    assert (is(typeof(f ~ e) == typeof(a) ));
    assert(f ~ a == "fa".representation);
}

version(unittest) private void test(C)()
{
    RCBuffer!C s;
    assert(s == s);
    assert(s <= s);
    assert(!(s < s));
    assert(s.length == 0);
    assert(s.length + s.slackBack >= 0);
    s ~= ubyte('1');
    assert(s.length == 1);
    assert(s < "2".representation);
    assert(s > "".representation);
    assert(s > "0".representation);
    auto x = "23456789012345678901234567890123456789012345678901234567890123"
        .representation;
    s ~= x;
    assert(s.length == 63);
    assert(s ==
        "123456789012345678901234567890123456789012345678901234567890123".representation);
    s ~= ubyte('4');
    assert(s.length == 64);
    s ~= ubyte('5');
    assert(s.length == 65);
    auto s1 = s;
    s ~= s;
    assert(s.length == 130);
    assert(s ==
        "12345678901234567890123456789012345678901234567890123456789012345".representation
        ~ "12345678901234567890123456789012345678901234567890123456789012345".representation);
    //auto s2 = s1 ~ s1;
    //assert(s2 == s);
    /*s2 = s;
    assert(s2 == s);
    s = "123";
    assert(s == "123");
    s = "123"w;
    assert(s == "123");
    s = "123"d;
    assert(s == "123");

    auto s3 = s[];
    assert(s3 == "123");
    auto s4 = s[0 .. $];
    assert(s4 == s);
    s4 = s[1 .. $];
    assert(s4 == "23");
    s4 = s[0 .. $ - 1];
    assert(s4 == "12");
    s4 = s[1 .. $ - 1];
    assert(s4 == "2");*/
}

version(unittest) private void test2(C)()
{
    /*static immutable(RCBuffer!C) fun(immutable RCBuffer!C s)
    {
        return s ~ s;
    }*/
    auto s1 = RCBuffer!C("1234".representation);
    auto s2 = cast(immutable RCBuffer!C) s1;
    assert(s2 == s1);
    auto s3 = immutable(RCBuffer!C)("5678".representation);
    import std.conv;
    assert(s3 == "5678".representation, text("asd", s3._core._payload));
}

unittest
{
    test!ubyte;
    test!(const ubyte);
    test!(immutable ubyte);

    test2!ubyte;
    test2!(const ubyte);
    test2!(immutable ubyte);

    import std.stdio;
    writeln(alloc.bytesUsed);
}

// Not yet finished, ignore
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

    auto ref large() inout
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
            large.__ctor(data);
            _length = _length.max;
        }
    }

    this(this)
    {
        if (!isSmall) large.__postblit;
    }

    ~this()
    {
        if (!isSmall) large.__dtor;
    }

    private bool isSmall() const { return _length <= smallCapacity; }
    private void forceLarge() { _length = _length.max; }
    size_t length() const { return isSmall ? _length : large.length; }
    size_t capacity() const
    {
        return isSmall ? smallCapacity : large.capacity;
    }
    auto payloadPtr() inout { return isSmall ? _small.ptr : large.payloadPtr; }

    void forceLength(size_t len)
    {
        assert(len <= capacity);
        if (isSmall) _length = cast(ubyte) len;
        else large.forceLength(len);
    }

    void reserve(size_t newCapacity)
    {
        if (!isSmall)
        {
            // large to possibly larger
            large.reserve(newCapacity);
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
        memcpy(&large(), &t, t.sizeof);
        import std.conv;
        emplace(&t);
        forceLarge;
    }
}
