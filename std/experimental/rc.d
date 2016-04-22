module std.experimental.rc;
import std.traits : isSomeChar;

struct RCStr(C)
if (isSomeChar!C)
{
    import std.experimental.allocator.gc_allocator,
        std.experimental.allocator.building_blocks.affix_allocator,
        std.range;
    alias Alloc = AffixAllocator!(GCAllocator, uint);
    enum uint maxSmall = 64 / C.sizeof - 1;
    union
    {
        struct
        {
            C[maxSmall] small = void;
            ubyte smallLen = 0;
        }
        struct
        {
            C[] payload;
            size_t offset;
        }
    }

    private void reserve(size_t s)
    {
        immutable u = units;
        if (s <= u) return;
        if (u <= maxSmall)
        {
            if (s > maxSmall)
            {
                RCStr!C t;
            }
        }
        else
        {

        }
    }

    size_t units() const
    {
        if (smallLen <= maxSmall) return smallLen;
        return payload.length - offset;
    }

    RCStr!C opCat(C1)(C1 c)
    if (isSomeChar!C1)
    {
        assert(0);
    }

    void opCatAssign(C1)(C1 c)
    if (isSomeChar!C1)
    {
        static if (C1.sizeof > C.sizeof)
        {
            static C[4] buf;
            import std.utf : encode;
            auto l = encode(buf, c);
            return this ~= buf[0 .. l];
        }
        else
        {
            auto u = units;
            if (u < maxSmall)
            {
                small[u] = c;
                ++smallLen;
                return;
            }
            // Result is a large string
            if (u == maxSmall)
            {
                // Small to large conversion
                typeof(this) t;
                t.reserve(units + 1);
                t ~= this;
                t ~= c;
                import std.algorithm : move;
                move(t, this);
            }
            else
            {
                // Large stays large
                assert(0);
            }
        }
    }

    void opCatAssign(RCStr!C rhs)
    {
        reserve(units + rhs.units);
        assert(0);
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

unittest
{
    RCStr!char s;
    assert(s.units == 0);
    s ~= '1';
    assert(s.units == 1);
    s ~= "23456789012345678901234567890123456789012345678901234567890123";
    assert(s.units == 63);
    s ~= '4';
    assert(s.units == 64);
}
