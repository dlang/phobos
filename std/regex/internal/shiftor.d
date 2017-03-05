/*
    ShiftOr is a kickstart engine, a coarse-grained "filter" engine that finds
    potential matches to be verified by a full-blown matcher.
*/
module std.regex.internal.shiftor;

package(std.regex):

import std.regex.internal.ir;
import std.range.primitives, std.utf;

//utility for shiftOr, returns a minimum number of bytes to test in a Char
uint effectiveSize(Char)()
{
    static if (is(Char == char))
        return 1;
    else static if (is(Char == wchar))
        return 2;
    else static if (is(Char == dchar))
        return 3;
    else
        static assert(0);
}

/*
    Kickstart engine using ShiftOr algorithm,
    a bit parallel technique for inexact string searching.
*/
class ShiftOr(Char)
{
private:
pure:
    uint[] table;
    uint fChar;
    uint n_length;
    enum charSize =  effectiveSize!Char();
    //maximum number of chars in CodepointSet to process
    enum uint charsetThreshold = 32_000;
    static struct ShiftThread
    {
        uint[] tab;
        uint mask;
        uint idx;
        uint pc, counter, hops;
        this(uint newPc, uint newCounter, uint[] table)
        {
            pc = newPc;
            counter = newCounter;
            mask = 1;
            idx = 0;
            hops = 0;
            tab = table;
        }

        void setMask(uint idx, uint mask)
        {
            tab[idx] |= mask;
        }

        void setInvMask(uint idx, uint mask)
        {
            tab[idx] &= ~mask;
        }

        void set(alias setBits = setInvMask)(dchar ch)
        {
            static if (charSize == 3)
            {
                uint val = ch, tmask = mask;
                setBits(val&0xFF, tmask);
                tmask <<= 1;
                val >>= 8;
                setBits(val&0xFF, tmask);
                tmask <<= 1;
                val >>= 8;
                assert(val <= 0x10);
                setBits(val, tmask);
                tmask <<= 1;
            }
            else
            {
                Char[dchar.sizeof/Char.sizeof] buf;
                uint tmask = mask;
                size_t total = encode(buf, ch);
                for (size_t i = 0; i < total; i++, tmask<<=1)
                {
                    static if (charSize == 1)
                        setBits(buf[i], tmask);
                    else static if (charSize == 2)
                    {
                        setBits(buf[i]&0xFF, tmask);
                        tmask <<= 1;
                        setBits(buf[i]>>8, tmask);
                    }
                }
            }
        }
        void add(dchar ch){ return set!setInvMask(ch); }
        void advance(uint s)
        {
            mask <<= s;
            idx += s;
        }
        @property bool full(){    return !mask; }
    }

    static ShiftThread fork(ShiftThread t, uint newPc, uint newCounter)
    {
        ShiftThread nt = t;
        nt.pc = newPc;
        nt.counter = newCounter;
        return nt;
    }

    @trusted static ShiftThread fetch(ref ShiftThread[] worklist)
    {
        auto t = worklist[$-1];
        worklist.length -= 1;
        //if (!__ctfe)
        //    cast(void)worklist.assumeSafeAppend();
        return t;
    }

    static uint charLen(uint ch)
    {
        assert(ch <= 0x10FFFF);
        return codeLength!Char(cast(dchar)ch)*charSize;
    }

public:
    @trusted this(ref Regex!Char re)
    {
        static import std.algorithm.comparison;
        import std.algorithm.searching : countUntil;
        import std.conv : text;
        import std.range : assumeSorted;
        uint[] memory = new uint[256];
        fChar = uint.max;
        // FNV-1a flavored hash (uses 32bits at a time)
        ulong hash(uint[] tab)
        {
            ulong h = 0xcbf29ce484222325;
            foreach (v; tab)
            {
                h ^= v;
                h *= 0x100000001b3;
            }
            return h;
        }
    L_FindChar:
        for (size_t i = 0;;)
        {
            switch (re.ir[i].code)
            {
                case IR.Char:
                    fChar = re.ir[i].data;
                    static if (charSize != 3)
                    {
                        Char[dchar.sizeof/Char.sizeof] buf;
                        encode(buf, fChar);
                        fChar = buf[0];
                    }
                    fChar = fChar & 0xFF;
                    break L_FindChar;
                case IR.GroupStart, IR.GroupEnd:
                    i += IRL!(IR.GroupStart);
                    break;
                case IR.Bof, IR.Bol, IR.Wordboundary, IR.Notwordboundary:
                    i += IRL!(IR.Bol);
                    break;
                default:
                    break L_FindChar;
            }
        }
        table = memory;
        table[] =  uint.max;
        alias MergeTab = bool[ulong];
        // use reasonably complex hash to identify equivalent tables
        auto merge = new MergeTab[re.hotspotTableSize];
        ShiftThread[] trs;
        ShiftThread t = ShiftThread(0, 0, table);
        //locate first fixed char if any
        n_length = 32;
        for (;;)
        {
        L_Eval_Thread:
            for (;;)
            {
                switch (re.ir[t.pc].code)
                {
                case IR.Char:
                    uint s = charLen(re.ir[t.pc].data);
                    if (t.idx+s > n_length)
                        goto L_StopThread;
                    t.add(re.ir[t.pc].data);
                    t.advance(s);
                    t.pc += IRL!(IR.Char);
                    break;
                case IR.OrChar://assumes IRL!(OrChar) == 1
                    uint len = re.ir[t.pc].sequence;
                    uint end = t.pc + len;
                    uint[Bytecode.maxSequence] s;
                    uint numS;
                    for (uint i = 0; i < len; i++)
                    {
                        auto x = charLen(re.ir[t.pc+i].data);
                        if (countUntil(s[0..numS], x) < 0)
                           s[numS++] = x;
                    }
                    for (uint i = t.pc; i < end; i++)
                    {
                        t.add(re.ir[i].data);
                    }
                    for (uint i = 0; i < numS; i++)
                    {
                        auto tx = fork(t, t.pc + len, t.counter);
                        if (tx.idx + s[i] <= n_length)
                        {
                            tx.advance(s[i]);
                            trs ~= tx;
                        }
                    }
                    if (!trs.empty)
                        t = fetch(trs);
                    else
                        goto L_StopThread;
                    break;
                case IR.CodepointSet:
                case IR.Trie:
                    auto set = re.charsets[re.ir[t.pc].data];
                    uint[4] s;
                    uint numS;
                    static if (charSize == 3)
                    {
                        s[0] = charSize;
                        numS = 1;
                    }
                    else
                    {

                        static if (charSize == 1)
                            static immutable codeBounds = [0x0, 0x7F, 0x80, 0x7FF, 0x800, 0xFFFF, 0x10000, 0x10FFFF];
                        else //== 2
                            static immutable codeBounds = [0x0, 0xFFFF, 0x10000, 0x10FFFF];
                        uint[] arr = new uint[set.byInterval.length * 2];
                        size_t ofs = 0;
                        foreach (ival; set.byInterval)
                        {
                            arr[ofs++] = ival.a;
                            arr[ofs++] = ival.b;
                        }
                        auto srange = assumeSorted!"a <= b"(arr);
                        for (uint i = 0; i < codeBounds.length/2; i++)
                        {
                            auto start = srange.lowerBound(codeBounds[2*i]).length;
                            auto end = srange.lowerBound(codeBounds[2*i+1]).length;
                            if (end > start || (end == start && (end & 1)))
                               s[numS++] = (i+1)*charSize;
                        }
                    }
                    if (numS == 0 || t.idx + s[numS-1] > n_length)
                        goto L_StopThread;
                    auto  chars = set.length;
                    if (chars > charsetThreshold)
                        goto L_StopThread;
                    foreach (ch; set.byCodepoint)
                    {
                        //avoid surrogate pairs
                        if (0xD800 <= ch && ch <= 0xDFFF)
                            continue;
                        t.add(ch);
                    }
                    for (uint i = 0; i < numS; i++)
                    {
                        auto tx =  fork(t, t.pc + IRL!(IR.CodepointSet), t.counter);
                        tx.advance(s[i]);
                        trs ~= tx;
                    }
                    if (!trs.empty)
                        t = fetch(trs);
                    else
                        goto L_StopThread;
                    break;
                case IR.Any:
                    goto L_StopThread;

                case IR.GotoEndOr:
                    t.pc += IRL!(IR.GotoEndOr)+re.ir[t.pc].data;
                    assert(re.ir[t.pc].code == IR.OrEnd);
                    goto case;
                case IR.OrEnd:
                    auto slot = re.ir[t.pc+1].raw+t.counter;
                    auto val = hash(t.tab);
                    if (val in merge[slot])
                        goto L_StopThread; // merge equivalent
                    merge[slot][val] = true;
                    t.pc += IRL!(IR.OrEnd);
                    break;
                case IR.OrStart:
                    t.pc += IRL!(IR.OrStart);
                    goto case;
                case IR.Option:
                    uint next = t.pc + re.ir[t.pc].data + IRL!(IR.Option);
                    //queue next Option
                    if (re.ir[next].code == IR.Option)
                    {
                        trs ~= fork(t, next, t.counter);
                    }
                    t.pc += IRL!(IR.Option);
                    break;
                case IR.RepeatStart:case IR.RepeatQStart:
                    t.pc += IRL!(IR.RepeatStart)+re.ir[t.pc].data;
                    goto case IR.RepeatEnd;
                case IR.RepeatEnd:
                case IR.RepeatQEnd:
                    auto slot = re.ir[t.pc+1].raw+t.counter;
                    auto val = hash(t.tab);
                    if (val in merge[slot])
                        goto L_StopThread; // merge equivalent
                    merge[slot][val] = true;
                    uint len = re.ir[t.pc].data;
                    uint step = re.ir[t.pc+2].raw;
                    uint min = re.ir[t.pc+3].raw;
                    if (t.counter < min)
                    {
                        t.counter += step;
                        t.pc -= len;
                        break;
                    }
                    uint max = re.ir[t.pc+4].raw;
                    if (t.counter < max)
                    {
                        trs ~= fork(t, t.pc - len, t.counter + step);
                        t.counter = t.counter%step;
                        t.pc += IRL!(IR.RepeatEnd);
                    }
                    else
                    {
                        t.counter = t.counter%step;
                        t.pc += IRL!(IR.RepeatEnd);
                    }
                    break;
                case IR.GroupStart, IR.GroupEnd:
                    t.pc += IRL!(IR.GroupStart);
                    break;
                case IR.Bof, IR.Bol, IR.Wordboundary, IR.Notwordboundary:
                    t.pc += IRL!(IR.Bol);
                    break;
                case IR.LookaheadStart, IR.NeglookaheadStart, IR.LookbehindStart, IR.NeglookbehindStart:
                    t.pc += IRL!(IR.LookaheadStart) + IRL!(IR.LookaheadEnd) + re.ir[t.pc].data;
                    break;
                default:
                L_StopThread:
                    assert(re.ir[t.pc].code >= 0x80, text(re.ir[t.pc].code));
                    n_length = std.algorithm.comparison.min(t.idx, n_length);
                    break L_Eval_Thread;
                }
            }
            if (trs.empty)
                break;
            t = fetch(trs);
        }
        debug(std_regex_search)
        {
            writeln("Min length: ", n_length);
        }
    }

    final @property bool empty() const {  return n_length < 3 && fChar == uint.max; }

    final @property uint length() const{ return n_length/charSize; }

    // lookup compatible bit pattern in haystack, return starting index
    // has a useful trait: if supplied with valid UTF indexes,
    // returns only valid UTF indexes
    // (that given the haystack in question is valid UTF string)
    final @trusted bool search(ref Input!Char s) const
    {//@BUG: apparently assumes little endian machines
        import std.conv : text;
        import core.stdc.string : memchr;
        assert(!empty);
        auto haystack = s._origin;
        uint state = uint.max;
        uint limit = 1u<<(n_length - 1u);
        auto p = cast(const(ubyte)*)(haystack.ptr+s._index);
        debug(std_regex_search) writefln("Limit: %32b",limit);
        if (fChar != uint.max)
        {
            const(ubyte)* end = cast(ubyte*)(haystack.ptr + haystack.length);
            const orginalAlign = cast(size_t)p & (Char.sizeof-1);
            while (p != end)
            {
                if (!~state)
                {//speed up seeking first matching place
                    for (;;)
                    {
                        assert(p <= end, text(p," vs ", end));
                        p = cast(ubyte*)memchr(p, fChar, end - p);
                        if (!p)
                        {
                            s._index = haystack.length;
                            return false;
                        }
                        if ((cast(size_t)p & (Char.sizeof-1)) == orginalAlign)
                            break;
                        if (++p == end)
                        {
                            s._index = haystack.length;
                            return false;
                        }
                    }
                    state = ~1u;
                    assert((cast(size_t)p & (Char.sizeof-1)) == orginalAlign);
                    static if (charSize == 3)
                    {
                        state = (state<<1) | table[p[1]];
                        state = (state<<1) | table[p[2]];
                        p += 4;
                    }
                    else
                        p++;
                    //first char is tested, see if that's all
                    if (!(state & limit))
                    {
                        s._index =  (p-cast(ubyte*)haystack.ptr)/Char.sizeof-length;
                        return true;
                    }
                }
                else
                {//have some bits/states for possible matches,
                 //use the usual shift-or cycle
                    static if (charSize == 3)
                    {
                        state = (state<<1) | table[p[0]];
                        state = (state<<1) | table[p[1]];
                        state = (state<<1) | table[p[2]];
                        p += 4;
                    }
                    else
                    {
                        state = (state<<1) | table[p[0]];
                        p++;
                    }
                    if (!(state & limit))
                    {
                        s._index = (p-cast(ubyte*)haystack.ptr)/Char.sizeof-length;
                        return true;
                    }
                }
                debug(std_regex_search) writefln("State: %32b", state);
            }
        }
        else
        {
            //normal path, partially unrolled for char/wchar
            static if (charSize == 3)
            {
                const(ubyte)* end = cast(ubyte*)(haystack.ptr + haystack.length);
                while (p != end)
                {
                    state = (state<<1) | table[p[0]];
                    state = (state<<1) | table[p[1]];
                    state = (state<<1) | table[p[2]];
                    p += 4;
                    if (!(state & limit))//division rounds down for dchar
                    {
                        s._index = (p-cast(ubyte*)haystack.ptr)/Char.sizeof-length;
                        return true;
                    }
                }
            }
            else
            {
                auto len = cast(ubyte*)(haystack.ptr + haystack.length) - p;
                size_t i  = 0;
                if (len & 1)
                {
                    state = (state<<1) | table[p[i++]];
                    if (!(state & limit))
                    {
                        s._index += i/Char.sizeof-length;
                        return true;
                    }
                }
                while (i < len)
                {
                    state = (state<<1) | table[p[i++]];
                    if (!(state & limit))
                    {
                        s._index += i/Char.sizeof-length;
                        return true;
                    }
                    state = (state<<1) | table[p[i++]];
                    if (!(state & limit))
                    {
                        s._index += i/Char.sizeof-length;
                        return true;
                    }
                    debug(std_regex_search) writefln("State: %32b", state);
                }
            }
        }
        s._index = haystack.length;
        return false;
    }

    final @trusted bool match(ref Input!Char s) const
    {
        //TODO: stub
        return false;
    }

    @system debug static void dump(uint[] table)
    {//@@@BUG@@@ writef(ln) is @system
        import std.stdio : writefln;
        for (size_t i = 0; i < table.length; i += 4)
        {
            debug writefln("%32b %32b %32b %32b",table[i], table[i+1], table[i+2], table[i+3]);
        }
    }
}

unittest
{
    import std.conv, std.regex;
    auto shiftOrLength(C)(const(C)[] pat, uint length)
    {
        auto r = regex(pat, "s");
        auto kick = new ShiftOr!C(r);
        assert(kick.length == length, text(C.stringof, " == ", kick.length));
        return kick;
    }
    void searches(C)(const (C)[] source, ShiftOr!C kick, uint[] results...)
    {
        auto inp = Input!C(source);
        foreach (r; results)
        {
            kick.search(inp);
            dchar ch;
            size_t idx;
            assert(inp._index == r, text(inp._index, " vs ", r));
            inp.nextChar(ch, idx);
        }
    }


    foreach (i, Char; AliasSeq!(char, wchar, dchar))
    {
        alias String = immutable(Char)[];
        shiftOrLength(`abc`.to!String, 3);
        shiftOrLength(`abc$`.to!String, 3);
        shiftOrLength(`(abc){2}a+`.to!String, 7);
        shiftOrLength(`\b(a{2}b{3}){2,4}`.to!String, 10);
        shiftOrLength(`\ba{2}c\bxyz`.to!String, 6);
        auto kick = shiftOrLength(`\ba{2}c\b`.to!String, 3);
        auto inp = Input!Char("aabaacaa");
        assert(kick.search(inp));
        assert(inp._index == 3, text(Char.stringof," == ", kick.length));
        dchar ch;
        size_t idx;
        inp.nextChar(ch, idx);
        assert(!kick.search(inp));
        assert(inp._index == 8, text(Char.stringof," == ", kick.length));
    }

    foreach (i, Char; AliasSeq!(char, wchar, dchar))
    {
        alias String = immutable(Char)[];
        auto kick = shiftOrLength(`abc[a-z]`.to!String, 4);
        searches("abbabca".to!String, kick, 3);
        kick = shiftOrLength(`(axx|bdx|cdy)`.to!String, 3);
        searches("abdcdxabax".to!String, kick, 3);

        shiftOrLength(`...`.to!String, 0);
        kick = shiftOrLength(`a(b{1,2}|c{1,2})x`.to!String, 3);
        searches("ababx".to!String, kick, 2);
        searches("abaacba".to!String, kick, 3); //expected inexact
    }

}

