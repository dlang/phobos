module std.experimental.rc;
import std.traits : isSomeChar, isSomeString;

import std.experimental.allocator.gc_allocator, std.experimental.allocator.mallocator,
    std.experimental.allocator.building_blocks.affix_allocator;
version(unittest)
    import std.experimental.allocator.building_blocks.stats_collector,
        std.stdio;
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

private struct CowStringCore(C)
{
    import std.traits;
    // state {
    private Unqual!C[] _support;
    private C[] _payload;
    // } state

    // Constructs this as an immutable string containing the concatenation of
    // s1 and s2.
    this(C1, C2 = C)(C1[] s1, C2[] s2 = null) immutable
    if (isSomeChar!C1 && isSomeChar!C2)
    {
        // Strategy: build a mutable string, then move it.
        CowStringCore!C t;
        import std.conv, std.exception, std.range, std.utf;
        immutable len = byUTF!C(s1).walkLength + byUTF!C(s2).walkLength;
        t.reserve(len);
        size_t i = 0;
        foreach (c; byUTF!C(s1))
            t._support[i++] = c;
        foreach (c; byUTF!C(s2))
            t._support[i++] = c;
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
        // Need to create a whole new string
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
        static if (is(Q == immutable)) alias R = CowStringCore!(immutable C);
        else static if (is(Q == const)) alias R = CowStringCore!(const C);
        else alias R = CowStringCore!C;
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

    auto opCat(C1)(CowStringCore!C1 rhs)
    {
        alias R = typeof((new C[1] ~ new C1[1])[0]);
        //pragma(msg, "Core 3: " ~ R.stringof);
        CowStringCore!R result;
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

private auto payload(RCStr)(ref RCStr s)
{
    return s.payloadPtr()[0 .. s.length];
}

enum Iterate
{
    onDemand,
    byCodePoint,
    byCodeUnit,
    byIntegral
}

/**
*/
struct RCStr(C, Iterate iterate = Iterate.byCodePoint)
if (isSomeChar!C)
{
    import std.algorithm.comparison, std.algorithm.mutation, std.conv,
        std.range, std.traits;
    //private alias K = Unqual!C;

    //alias Core = SmallString!(CowStringCore!K);
    alias CoreT = CowStringCore;
    alias Core = CoreT!C;
    // state {
    Core _core;
    // }

    /**
    */
    private this(C1)(CoreT!C1 core) if (C.sizeof == C1.sizeof)
    {
        _core = core;
    }

    /// ditto
    this(S)(S str) if (isSomeString!S)
    {
        assert(codeUnits == 0);
        this ~= str;
    }

    /// ditto
    this(S)(S str) immutable if (isSomeString!S)
    {
        _core = immutable(Core)(str);
    }

    /**
    */
    void opAssign(RCStr!C rhs)
    {
        move(rhs._core, _core);
    }

    void opAssign(R)(R rhs)
    if (isInputRange!R && isSomeChar!(ElementEncodingType!R))
    {
        auto t = RCStr(rhs);
        move(t._core, _core);
    }

    /** */
    bool empty() const
    {
        return _core.length == 0;
    }

    // Range primitives
    static if (iterate != Iterate.onDemand)
    {
        static if (iterate == Iterate.byCodePoint)
            alias ElementType = dchar;
        else static if (iterate == Iterate.byCodeUnit)
            alias ElementType = Unqual!C;
        else static if (iterate == Iterate.byIntegral)
            static if (C.sizeof == 1) alias ElementType = ubyte;
            else static if (C.sizeof == 2) alias ElementType = ushort;
            else static if (C.sizeof == 4) alias ElementType = uint;
            else static assert(0);
        else static assert(0);

        ElementType front() const
        {
            assert(!empty);
            static if (iterate == Iterate.byCodePoint)
            {
                import std.utf;
                auto s = _core.payload;
                return decodeFront(s);
            }
            else
            {
                return *_core.payloadPtr;
            }
        }

        static if ((iterate == Iterate.byCodeUnit || iterate == Iterate.byIntegral)
            && is(Unqual!C == C))
        void front(in ElementType x)
        {
            assert(!empty);
            *_core.payloadPtr = x;
        }

        void popFront()
        {
            assert(!empty);
            static if (iterate != Iterate.byCodePoint)
            {
                _core.popFront;
            }
            else
            {
                immutable c = *_core.payloadPtr;
                if (c < 0x80) {
                  _core.popFront;
                } else {
                  import core.bitop;
                  uint i = 7u - bsr(~c | 1u);
                  import std.algorithm;
                  if (i > 6u) i = 1;
                  _core = _core[min(i, _core.length) .. _core.length];
                }
            }
        }
    }

    // Random access primitives
    static if (iterate == Iterate.byCodePoint || iterate == Iterate.byIntegral)
    {
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
            assert(b <= e && e <= codeUnits);
            auto slice = _core[b .. e];
            return RCStr!(typeof(slice).ElementEncodingType)(slice);
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

    alias opDollar = codeUnits;

    /**
    Returns the number of code units (e.g. bytes for UTF8) that this string may
    accommodate without a (re)allocation.
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
    bool opEquals(C1)(in RCStr!C1 rhs) const
    {
        return this == rhs._core.payload;
    }

    /**
    */
    bool opEquals(C1)(in C1[] rhs) const if (isSomeChar!C1)
    {
        return equal(_core.payload, rhs);
    }

    /**
    */
    int opCmp(C1)(in RCStr!C1 rhs) const if (isSomeChar!C1)
    {
        return opCmp(rhs._core.payload);
    }

    /**
    */
    int opCmp(C1)(in C1[] rhs) const if (isSomeChar!C1)
    {
        return cmp(_core.payload, rhs);
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

    void opCatAssign(RCStr!C rhs)
    {
        this ~= rhs._core.payload;
    }

    void opCatAssign(C1)(C1 c)
    if (isSomeChar!C1)
    {
        static if (C1.sizeof > C.sizeof)
        {
            Unqual!C[4 / C.sizeof] buf = void;
            import std.utf : encode;
            return this ~= buf[0 .. encode(buf, c)];
        }
        else
        {
            immutable cap = codeUnits + slackBack, len = _core.length;
            assert(len <= cap);
            if (len == cap)
            {
                _core.reserve((cap + 1) * 3 / 2);
            }
            assert(len < codeUnits + slackBack);
            (cast(Unqual!C*) _core.payloadPtr())[len] = c;
            _core.forceLength(len + 1);
        }
    }

    void opCatAssign(R)(R r)
    if (isInputRange!R && isSomeChar!(std.range.ElementType!R))
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

    /**
    */
    auto opCat(T, this Q)(T[] rhs)
    if (isSomeChar!T)
    {
        alias R = typeof((_core.payload ~ rhs)[0]);
        static if (is(Q == const) || is(Q == immutable))
        {
            // Nothing interesting to do, allocate a new string
            // TODO: optimize
            RCStr!R result;
            result.reserve(_core.length + rhs.length);
            result ~= _core.payload;
            result ~= rhs;
            return result;
        }
        else
        {
            // TODO: implement the following strategy:
            // "this" is mutable, maybe there's slack space after it
            RCStr!R result;
            result.reserve(_core.length + rhs.length);
            result ~= _core.payload;
            result ~= rhs;
            return result;
        }
    }

    /**
    */
    auto opCat_r(T, this Q)(T[] lhs)
    if (isSomeChar!T)
    {
        alias R = typeof((lhs ~ _core.payload)[0]);
        static if (is(Q == const) || is(Q == immutable))
        {
            // Nothing interesting to do, allocate a new string
            // TODO: optimize
            RCStr!R result;
            result.reserve(lhs.length + _core.length);
            result ~= lhs;
            result ~= _core.payload;
            return result;
        }
        else
        {
            // TODO: implement the following strategy:
            // "this" is mutable, maybe there's slack space before it
            RCStr!R result;
            result.reserve(lhs.length + _core.length);
            result ~= lhs;
            result ~= _core.payload;
            return result;
        }
    }

    /**
    */
    auto opCat(T, this Q)(T rhs)
    if (is(Unqual!T == RCStr!C1, C1))
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
            // Two mutable RCStrs!
            auto newCore = _core ~ rhs._core;
            return RCStr!(typeof(*newCore.payloadPtr))(newCore);
        }
    }
}

import std.traits;
enum bool isOurSister(T) = __traits(isSame, TemplateOf!T, RCStr);

unittest // concatenation types
{
    alias X = TemplateOf!(RCStr!char);
    //static assert(!isOurSister!int);
    static assert(isOurSister!(RCStr!char));
    /*char[] a;
    const(char)[] b;
    immutable(char)[] c;
    const char[] d;
    immutable char[] e;
    const (const(char)[]) f;*/

    auto a = RCStr!char("a");
    auto b = RCStr!(const(char))("b");
    auto c = RCStr!(immutable(char))("c");
    const d = RCStr!char("d");
    immutable e = immutable(RCStr!char)("e");
    const RCStr!(const char) f = RCStr!(const char)("f");

    auto x = a ~ "123";

    /*CowStringCore!char a;
    CowStringCore!(const(char)) b;
    CowStringCore!(immutable(char)) c;
    const CowStringCore!char d;
    immutable CowStringCore!char e;
    const CowStringCore!(const char) f;*/

    assert (is(typeof(a ~ a) == typeof(a)));
    assert(a ~ a == "aa");
    assert (is(typeof(a ~ b) == typeof(a)));
    assert(a ~ b == "ab");
    assert (is(typeof(a ~ c) == typeof(a)));
    assert(a ~ c == "ac");
    assert (is(typeof(a ~ d) == typeof(a)));
    assert(a ~ d == "ad");
    assert (is(typeof(a ~ e) == typeof(a)));
    assert(a ~ e == "ae");

    assert (is(typeof(b ~ a) == typeof(a) ));
    assert(b ~ a == "ba");
    assert (is(typeof(b ~ b) == typeof(b) ));
    assert(b ~ b == "bb");
    assert (is(typeof(b ~ c) == typeof(a) ));
    assert(b ~ c == "bc");
    assert (is(typeof(b ~ d) == typeof(b) ));
    assert(b ~ d == "bd");
    assert (is(typeof(b ~ e) == typeof(a) ));
    assert(b ~ e == "be");

    assert (is(typeof(c ~ a) == typeof(a) ));
    assert(c ~ a == "ca");
    assert (is(typeof(c ~ b) == typeof(a) ));
    assert(c ~ b == "cb");
    assert (is(typeof(c ~ c) == typeof(c) ));
    assert(c ~ c == "cc");
    assert (is(typeof(c ~ d) == typeof(a) ));
    assert(c ~ d == "cd");
    assert (is(typeof(c ~ e) == typeof(c) ));
    assert(c ~ e == "ce");

    assert (is(typeof(d ~ a) == typeof(a) ));
    assert(d ~ a == "da");
    assert (is(typeof(d ~ b) == typeof(b) ));
    assert(d ~ b == "db");
    assert (is(typeof(d ~ c) == typeof(a) ));
    assert(d ~ c == "dc");
    assert (is(typeof(d ~ d) == typeof(b) ));
    assert(d ~ d == "dd");
    assert (is(typeof(d ~ e) == typeof(a) ));
    assert(d ~ e == "de");

    assert (is(typeof(e ~ a) == typeof(a) ));
    assert(e ~ a == "ea");
    assert (is(typeof(e ~ b) == typeof(a) ));
    assert(e ~ a == "ea");
    assert (is(typeof(e ~ c) == typeof(c) ));
    assert(e ~ a == "ea");
    assert (is(typeof(e ~ d) == typeof(a) ));
    assert(e ~ a == "ea");
    assert (is(typeof(e ~ e) == typeof(c) ));
    assert(e ~ a == "ea");

    assert (is(typeof(f ~ a) == typeof(a) ));
    assert(f ~ a == "fa");
    assert (is(typeof(f ~ b) == typeof(b) ));
    assert(f ~ a == "fa");
    assert (is(typeof(f ~ c) == typeof(a) ));
    assert(f ~ a == "fa");
    assert (is(typeof(f ~ d) == typeof(b) ));
    assert(f ~ a == "fa");
    assert (is(typeof(f ~ e) == typeof(a) ));
    assert(f ~ a == "fa");
}

version(unittest) private void test(C)()
{
    RCStr!C s;
    assert(s == s);
    assert(s <= s);
    assert(!(s < s));
    assert(s.codeUnits == 0);
    assert(s.codeUnits + s.slackBack >= 0);
    s ~= '1';
    assert(s.codeUnits == 1);
    assert(s < "2");
    assert(s > "");
    assert(s > "0");
    string x = "23456789012345678901234567890123456789012345678901234567890123";
    s ~= x;
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
        ~ "12345678901234567890123456789012345678901234567890123456789012345");
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
    /*static immutable(RCStr!C) fun(immutable RCStr!C s)
    {
        return s ~ s;
    }*/
    auto s1 = RCStr!C("1234");
    auto s2 = cast(immutable RCStr!C) s1;
    assert(s2 == s1);
    auto s3 = immutable(RCStr!C)("5678");
    import std.conv;
    assert(s3 == "5678", text("asd", s3._core._payload));
    assert(s3 == "5678"w);
    assert(s3 == "5678"d);
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
    test2!(const char);
    test2!(immutable char);
    test2!wchar;
    test2!(const wchar);
    test2!(immutable wchar);
    test2!dchar;
    test2!(const dchar);
    test2!(immutable dchar);

    import std.stdio;
    writeln(alloc.bytesUsed);
}
