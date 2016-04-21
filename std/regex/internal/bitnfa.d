//Written in the D programming language
/*
    Implementation of a concept "NFA in a word" which is
    bit-parallel impementation of regex where each bit represents
    a state in an NFA. Execution is Thompson-style achieved via bit tricks.

    There is a great number of limitations inlcuding not tracking any state (captures)
    and not supporting even basic assertions such as ^, $  or \b.
*/
module std.regex.internal.bitnfa;

package(std.regex):

import std.regex.internal.ir;

debug(std_regex_bitnfa) import std.stdio;
import std.algorithm;


struct HashTab
{
    @disable this(this);

    uint opIndex()(uint key)
    {
        auto p = locate(key, table);
        assert(p.occupied);
        return p.value;
    }

    void opIndexAssign(uint value, uint key)
    {
        if(table.length == 0) grow();
        auto p = locate(key, table);
        if(!p.occupied)
        {
            items++;
            if(4*items >= table.length*3)
            {
                grow();
                p = locate(key, table);
            }
            p.occupied = true;
            p.key = key;
        }
        p.value = value;
    }

    auto keys()
    {
        auto app = appender!(uint[])();
        foreach(i, v; table)
        {
            if(v.occupied)
                app.put(v.key);
        }
        return app.data;
    }

    auto values()
    {
        auto app = appender!(uint[])();
        foreach(i, v; table)
        {
            if(v.occupied)
                app.put(v.value);
        }
        return app.data;
    }

private:
    static uint hashOf()(uint val)
    {
        return (val >> 20) ^ (val>>8) ^ val;
    }

    struct Node
    {
        uint key;
        uint value;
        bool occupied;
    }
    Node[] table;
    size_t items;

    static Node* locate()(uint key, Node[] table)
    {
        size_t slot = hashOf(key) & (table.length-1);
        while(table[slot].occupied)
        {
            if(table[slot].key == key)
                break;
            slot += 1;
            if(slot == table.length)
                slot = 0;
        }
        return table.ptr+slot;
    }

    void grow()
    {
        Node[] newTable = new Node[table.length ? table.length*2 : 4];
        foreach(i, v; table)
        {
            if(v.occupied)
            {
                auto p = locate(v.key, newTable);
                *p = v;
            }
        }
        table = newTable;
    }
}


// Specialized 2-level trie of uint masks for BitNfa.
// Uses the concept of CoW: a page gets modified in place
// if the block's ref-count is 1, else a newblock is allocated
// and ref count is decreased
struct UIntTrie2
{
    ushort[] index;                       // pages --> blocks
    ushort[] refCounts;                   // ref counts for each block
    uint[]   hashes;                      // hashes of blocks
    uint[]   blocks;                      // linear array with blocks
    uint[]   scratch;                     // temporary block
    enum     blockBits = 8;               // size of block in bits
    enum     blockSize = 1<<blockBits;    // size of block


    static uint hash(uint[] data)
    {
        uint h = 5183;
        foreach(v; data)
        {
            h = 31*h + v;
        }
        return h;
    }

    static UIntTrie2 opCall()
    {
        UIntTrie2 ut;
        ut.index.length = 2<<13;
        ut.blocks = new uint[blockSize];
        ut.blocks[] = uint.max; // all ones
        ut.scratch = new uint[blockSize];
        ut.refCounts = new ushort[1];
        ut.refCounts[0] = 2<<13;
        ut.hashes = new uint[1];
        ut.hashes[0] = hash(ut.blocks);
        return ut;
    }

    uint opIndex(dchar ch)
    {
        immutable blk = index[ch>>blockBits];
        //writeln(">blk = ", blk);
        return blocks.ptr[blk*blockSize + (ch & (blockSize-1))];
    }

    void setPageRange(string op)(uint val, uint low, uint high)
    {
        immutable blk = index[low>>blockBits];
        //writeln("<blk = ", blk);
        if(refCounts[blk] == 1) // modify in-place
        {
            immutable lowIdx = blk*blockSize + (low & (blockSize-1));
            immutable highIdx = high - low + lowIdx;
            mixin("blocks[lowIdx..highIdx] "~op~"= val;");
        }
        else        
        {
            // create a new page
            refCounts[blk]--;
            immutable lowIdx = low & (blockSize-1);
            immutable highIdx = high - low + lowIdx;
            scratch[] = blocks[blk*blockSize..(blk+1)*blockSize];
            mixin("scratch[lowIdx..highIdx] "~op~"= val;");
            uint h = hash(scratch);
            bool found = false;
            foreach(i,_; hashes.enumerate.filter!(x => x[1] == h))
            {
                if(scratch[] == blocks[i*blockSize .. (i+1)*blockSize])
                {
                    // re-route to existing page
                    index[low>>blockBits] = cast(ushort)i;
                    refCounts[i]++; // inc refs
                    found = true;
                    break;
                }
            }
            if(!found)
            {
                index[low>>blockBits] = cast(ushort)hashes.length;
                blocks ~= scratch[];
                refCounts ~= 1;
                hashes ~= h;
            }
        }
    }

    void opIndexOpAssign(string op)(uint val, dchar ch)
    {
        setPageRange!op(val, ch, ch+1);
    }

    void opSliceOpAssign(string op)(uint val, uint start, uint end)
    {
        uint startBlk  = start >> blockBits;
        uint endBlk = end >> blockBits;
        uint first = min(startBlk*blockSize+blockSize, end);
        setPageRange!op(val, start, first);
        foreach(blk; startBlk..endBlk)
            setPageRange!op(val, blk*blockSize, (blk+1)*blockSize);
        if(first != end)
        {
            setPageRange!op(val, endBlk*blockSize, end);
        }
    }
}

unittest
{
    UIntTrie2 trie = UIntTrie2();
    trie['d'] &= 3;
    assert(trie['d'] == 3);
    trie['\u0280'] &= 1;
    assert(trie['\u0280'] == 1);
    import std.uni;
    UIntTrie2 trie2 = UIntTrie2();
    auto letters = unicode("L");
    foreach(r; letters.byInterval)
        trie2[r.a..r.b] &= 1;
    foreach(ch; letters.byCodepoint)
        assert(trie2[ch] == 1);
    auto space = unicode("WhiteSpace");
    auto trie3 = UIntTrie2();
    foreach(r; space.byInterval)
        trie3[r.a..r.b] &= 2;
    foreach(ch; space.byCodepoint)
        assert(trie3[ch] == 2);
}

// Since there is no way to mark a starting position
// we need 2 instances of BitNfa: one to find the end, and the other
// to run backwards to find the start.
struct BitNfa
{
    uint[128]   asciiTab;         // state mask for ascii characters
    UIntTrie2   uniTab;           // state mask for unicode characters
    HashTab     controlFlow;      // maps each bit pattern to resulting jumps pattern
    uint        controlFlowMask;  // masks all control flow bits
    uint        finalMask;        // marks final states terminating the NFA
    bool        empty;            // if this engine is empty

    void combineControlFlow()
    {
        uint[] keys = controlFlow.keys;
        uint[] values = controlFlow.values;
        auto selection = new bool[keys.length];
        bool nextChoice()
        {
            uint i;
            for(i=0;i<selection.length; i++)
            {
                selection[i] ^= true;
                if(selection[i])
                    break;
            }
            return i != selection.length;
        }
        // first prepare full mask
        foreach(k; keys) controlFlowMask |= k;
        // next set all combinations in cf
        while(nextChoice())
        {
            uint kmask = 0, vmask = 0;
            foreach(i,v; selection)
                if(v)
                {
                    kmask |= keys[i];
                    vmask |= values[i];
                }
            controlFlow[kmask] = vmask;
        }
    }

    uint[] collectControlFlow(Bytecode[] ir, uint i)
    {
        uint[] result;
        Stack!uint paths;
        paths.push(i);
        while(!paths.empty())
        {
            uint j = paths.pop();
            switch(ir[j].code) with(IR)
            {
            case OrStart:
                j += IRL!OrStart;
                assert(ir[j].code == Option);
                while(ir[j].code == Option)
                {
                    //import std.stdio;
                    //writefln("> %d %s", j, ir[j].mnemonic);
                    paths.push(j+IRL!Option);
                    //writefln(">> %d", j+IRL!Option);
                    j = j + ir[j].data + IRL!Option;
                }
                break;
            case GotoEndOr:
                paths.push(j+IRL!GotoEndOr+ir[j].data);
                break;
            case OrEnd, Wordboundary, Notwordboundary, Bol, Eol, Nop, GroupStart, GroupEnd:
                paths.push(j+ir[j].length);
                break;
            case LookaheadStart, NeglookaheadStart, LookbehindStart,
                NeglookbehindStart:
                paths.push(j + IRL!LookaheadStart + ir[j].data + IRL!LookaheadEnd);
                break;
            case InfiniteStart, InfiniteQStart:
                paths.push(j+IRL!InfiniteStart);
                paths.push(j+ir[j].data+IRL!InfiniteEnd);
                break;
            case InfiniteBloomStart:
                paths.push(j+IRL!InfiniteStart);
                paths.push(j+ir[j].data+IRL!InfiniteBloomEnd);
                break;
            case InfiniteEnd, InfiniteQEnd:
                paths.push(j-ir[j].data);
                paths.push(j+IRL!InfiniteEnd);
                break;
            case InfiniteBloomEnd:
                paths.push(j-ir[j].data);
                paths.push(j+IRL!InfiniteBloomEnd);
                break;
            default:
                result ~= j;
            }
        }
        return result;
    }

    this(Char)(auto ref Regex!Char re)
    {
        asciiTab[] = uint.max; // all ones
        uniTab = UIntTrie2();
        controlFlow[0] = 0;
        // pc -> bit number
        uint[] bitMapping = new uint[re.ir.length];
        uint bitCount = 0, nesting=0, lastNonnested=0;
        bool stop = false;
        with(re)
outer:  for(uint i=0; i<ir.length; i += ir[i].length) with(IR)
        {
            if(nesting == 0) lastNonnested = i;
            if(ir[i].isStart) nesting++;
            if(ir[i].isEnd) nesting--;
            switch(ir[i].code)
            {
            case Option, OrEnd, Nop, Bol,
            GroupStart, GroupEnd,
            Eol, Wordboundary, Notwordboundary:
                bitMapping[i] = bitCount;
                break;
            // skipover complex assertions
            case LookaheadStart, NeglookaheadStart, LookbehindStart,
                NeglookbehindStart:
                bitMapping[i] = bitCount;
                nesting--;
                i += IRL!LookbehindStart + ir[i].data; // IRL end gets skiped by 'for'
                break;
            // unsupported instructions
            case RepeatStart, RepeatQStart, Backref:
                stop = true;
                break outer;
            case OrChar:
                uint s = ir[i].sequence;
                for(uint j=i; j<i+s; j++)
                    bitMapping[j] = bitCount;
                i += (s-1)*IRL!OrChar;
                bitCount++;
                if(bitCount == 32)
                    break outer;
                break;
            default:
                bitMapping[i] = bitCount++;
                if(bitCount == 32)
                    break outer;
            }
        }
        if(bitCount == 0)
            empty = true;
        debug(std_regex_bitnfa) writeln("LEN:", lastNonnested);
        // the total processable length
        uint length=lastNonnested;
        finalMask |= 1u<<bitMapping[length];
        if(stop)
            finalMask <<= 1;
        with(re)
        for(uint i=0; i<length; i += ir[i].length)
        {
            switch(ir[i].code) with (IR)
            {
            case OrStart,GotoEndOr, InfiniteStart,
            InfiniteBloomStart, InfiniteBloomEnd,
            InfiniteEnd, InfiniteQEnd, InfiniteQStart:
                // collect stops across all paths
                auto rets = collectControlFlow(ir, i);
                uint mask = 0;
                debug(std_regex_bitnfa) writeln(rets);
                foreach(pc; rets) mask |= 1u<<bitMapping[pc];
                // map this individual c-f to all possible stops
                controlFlow[1u<<bitMapping[i]] = mask;
                break;
            case Option, OrEnd, Nop, Bol,
                GroupStart, GroupEnd,
                Eol, Wordboundary, Notwordboundary:
                break;
            case LookaheadStart, NeglookaheadStart, LookbehindStart,
                NeglookbehindStart:
                i += IRL!LookaheadStart + ir[i].data;
                break;
            case End:
                finalMask |= 1u<<bitMapping[i];
                break;
            case Char:
                uint mask = 1u<<bitMapping[i];
                auto ch = ir[i].data;
                //import std.stdio;
                //writefln("Char %c - %b", cast(dchar)ch, mask);
                if(ch < 0x80)
                    asciiTab[ch] &= ~mask;
                else
                    uniTab[ch] &= ~mask;
                break;
            case OrChar:
                uint s = ir[i].sequence;
                for(size_t j=i; j<i+s; j++)
                {
                    uint mask = 1u<<bitMapping[i];
                    auto ch = ir[j].data;
                    //import std.stdio;
                    //writefln("OrChar %c - %b", cast(dchar)ch, mask);
                    if(ch < 0x80)
                        asciiTab[ch] &= ~mask;
                    else
                        uniTab[ch] &= ~mask;
                }
                i += s-1;
                break;
            case CodepointSet, Trie:
                auto cset = charsets[ir[i].data];
                uint mask = 1u<<bitMapping[i];
                foreach(ival; cset.byInterval)
                {
                    if(ival.b < 0x80)
                        asciiTab[ival.a..ival.b] &= ~mask;
                    else
                    {
                        if(ival.a < 0x80)
                            asciiTab[ival.a..0x80] &= ~mask;
                        uniTab[ival.a..ival.b] &= ~mask;
                    }
                }
                break;
            default:
                assert(0, "Unexpected instruction in BitNFA: "~ir[i].mnemonic);
            }
        }
        combineControlFlow();
    }

    bool opCall(Input)(ref Input r)
    {
        bool matched = false;
        size_t mIdx = 0;
        dchar ch;
        size_t idx;
        uint word = ~0u;
        for(;;)
        {
            word <<= 1; // shift - create a state
            // cfMask has 1 for each control-flow op
            uint cflow = ~word  & controlFlowMask;
            word = word | controlFlowMask; // kill cflow
            word &= ~controlFlow[cflow]; // map normal ops
            debug(std_regex_bitnfa) writefln("%b %b %b %b", word, finalMask, cflow, controlFlowMask);
            if((word & finalMask) != finalMask)
            {
                matched = true; // keep running to see if there is longer match
                mIdx = r._index;
            }
            else if(matched)
                break;
            if(!r.nextChar(ch, idx))
                break;
            // mask away failing states
            if(ch < 0x80)
                word |= asciiTab[ch];
            else
                word |= uniTab[ch];
        }
        if(matched)
        {
            r.reset(mIdx);
        }
        return matched;
    }
}

final class BitMatcher
{
    BitNfa forward, backward;

    this(Char)(auto ref Regex!Char re)
    {
        forward = BitNfa(re);
        //reverse Bytecode
        auto re2 = re;
        re2.ir = re2.ir.dup;
        // keep the end where it belongs
        reverseBytecode(re2.ir[0..$-1]);
        // check for the case of multiple patterns as one alternation
        with(IR) with(re2) if(ir[0].code == OrStart)
        {
            size_t pc = IRL!OrStart;
            while(ir[pc].code == Option)
            {
                size_t size = ir[pc].data;
                if(ir[pc+size-IRL!GotoEndOr].code == GotoEndOr)
                    size -= IRL!GotoEndOr;
                size_t j = pc + IRL!Option;
                if(ir[j].code == End)
                {
                    auto save = ir[j];
                    foreach(k; j+1..j+size)
                        ir[k-1] = ir[k];
                    ir[j+size-1] = save;
                }
                pc = j + ir[pc].data;
            }
        }
        backward = BitNfa(re2);
    }

    bool opCall(Input)(ref Input r)
    {
        bool res = forward(r);
        if(res){
            auto back = r.loopBack(r._index);
            assert(backward(back));
            r.reset(back._index);
        }
        return res;
    }
}

version(unittest)
{
    template check(alias make)
    {
        private void check(T)(string input, T re, size_t idx=uint.max)
        {
            import std.regex, std.conv;
            import std.stdio;
            auto rex = regex(re);
            auto m = make(rex);
            auto s = Input!char(input);
            assert(m(s), "Failed "~input~" with "~to!string(re));
            assert(s._index == idx || (idx ==uint.max && s._index == input.length));
        }
    }

    template checkFail(alias make)
    {
        private void checkFail(T)(string input, T re, size_t idx=uint.max)
        {
            import std.regex, std.conv;
            import std.stdio;
            auto rex = regex(re);
            auto m = make(rex);
            auto s = Input!char(input);
            assert(!m(s), "Should have failed "~input~" with "~to!string(re));
            assert(s._index == idx || (idx ==uint.max && s._index == input.length));
        }
    }

    alias checkBit = check!BitNfa;
    alias checkBitFail = checkFail!BitNfa;
    auto makeMatcher(R)(R regex){ return new BitMatcher(regex); }
    alias checkM = check!makeMatcher;
    alias checkMFail = checkFail!makeMatcher;
}

unittest
{
    "xabcd".checkBit("abc", 4);
    "xabbbcdyy".checkBit("a[b-c]*c", 6);
    "abc1".checkBit("([a-zA-Z_0-9]*)1");
    "abbabc".checkBit("(a|b)*",5);
    "abd".checkBitFail("abc");
    // check truncation
    "0123456789_0123456789_0123456789_012"
        .checkBit("0123456789_0123456789_0123456789_0123456789", 31);
    "0123456789_0123456789_0123456789_012"
        .checkBit("0123456789(0123456789_0123456789_0123456789_0123456789|01234)",10);
    // assertions ignored
    "0abc1".checkBit("(?<![0-9])[a-c]*$", 4);
    // stop on repetition
    "abcdef1".checkBit("a[a-z]{5}", 1);
    "ads@email.com".checkBit(`\S+@\S+`);
    //"abc".checkBit(`([^ ]*)?`);
}

unittest
{
    "xxabcy".checkM("abc", 2);
    "_10bcy".checkM([`\d+`, `[a-z]+`], 1);
}