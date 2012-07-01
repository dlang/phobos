//Written in the D programming language
/**
    Codepoint set and trie for efficient character class manipulation,
    currently for internal use only.
*/
module std.internal.uni;

import std.algorithm, std.range, std.uni, std.format;
import std.internal.uni_tab;
import core.bitop;

@safe:
public:

//wrappers for CTFE
@trusted void insertInPlaceAlt(T)(ref T[] arr, size_t idx, T[] items...)
{
    if(__ctfe)
        arr = arr[0..idx] ~ items ~ arr[idx..$];
    else
        insertInPlace(arr, idx, items);
}

//ditto
@trusted void replaceInPlaceAlt(T)(ref T[] arr, size_t from, size_t to, T[] items...)
in
{
    assert(to >= from);
}
body
{
    if(__ctfe)
        arr = arr[0..from]~items~arr[to..$];
    else //@@@BUG@@@ in replaceInPlace? symptoms being sudden ZEROs in array
    {
        //replaceInPlace(arr, from, to, items);
        size_t window = to - from, ilen = items.length;
        if(window >= ilen)
        {
            size_t delta = window - ilen;
            arr[from .. from+ilen] = items[0..$];
            if(delta)
            {//arrayops won't do - aliasing
                for(size_t i = from+ilen; i < arr.length-delta; i++)
                    arr[i] = arr[i+delta];
                arr.length -= delta;
            }
        }
        else
        {
            size_t delta = ilen - window, old = arr.length;
            arr.length += delta;
            //arrayops won't do - aliasing
            for(size_t i = old - 1; i != to-1; i--)
                arr[i+delta] = arr[i];
            arr[from .. from+ilen] = items[0..$];
        }
    }
}

//$(D Interval)  represents an interval of codepoints: [a,b).
struct Interval
{
    uint begin, end;

    ///Create interval containig a single character $(D ch).
    this(dchar ch)
    {
        begin = ch;
        end = ch+1;
    }

    /++
        Create Interval from inclusive range [$(D a),$(D b)]. Contrary to internal structure, inclusive is chosen for interface.
        The reason for this is usability e.g. it's would force user to type the unwieldy Interval('a','z'+1) all over the place.
    +/
    this(dchar a, dchar b)
    {
        assert(a <= b);
        begin = a;
        end = b+1;
    }

    ///
    @trusted string toString()const
    {
        auto s = appender!string();
        formattedWrite(s,"%s..%s", begin, end);
        return s.data;
    }

}

/+
    $(D CodepointSet) is a data structure for manipulating sets
    of Unicode codepoints in an efficient manner.
    Instances of CodepointSet have half-reference semantics akin to dynamic arrays,
    to obtain a unique copy use $(D dup).
+/
struct CodepointSet
{
    enum uint endOfRange = 0x110000;
    uint[] ivals;

    //Add an $(D interval) of codepoints to this set.
    @trusted ref CodepointSet add(Interval inter)
    {
        debug(fred_charset) writeln("Inserting ",inter);
        if(ivals.empty)
        {
            insertInPlaceAlt(ivals, 0, inter.begin, inter.end);
            return this;
        }//assumeSorted is @system
        auto svals = assumeSorted(ivals);
        auto s = svals.lowerBound(inter.begin).length;
        auto e = s+svals[s..svals.length].lowerBound(inter.end).length;
        debug(fred_charset)  writeln("Indexes: ", s,"  ", e);
        if(s & 1)
        {
            inter.begin = ivals[s-1];
            s ^= 1;
        }
        if(e & 1)
        {
            inter.end = ivals[e];
            e += 1;
        }
        else //e % 2 == 0
        {
            if(e < ivals.length && inter.end == ivals[e])
            {
                    inter.end = ivals[e+1];
                    e+=2;
            }
        }
        debug(fred_charset)
            for(size_t i=1;i<ivals.length; i++)
                assert(ivals[i-1] < ivals[i]);
        replaceInPlaceAlt(ivals, s, e, inter.begin ,inter.end);
        return this;
    }

    //Add a codepoint $(D ch) to this set.
    ref CodepointSet add(dchar ch){ add(Interval(cast(uint)ch)); return this; }

    //Add $(D set) in this set.
    //Algebra: this = this | set.
    ref CodepointSet add(in CodepointSet set)
    {
        debug(fred_charset) writef ("%s || %s --> ", ivals, set.ivals);
        for(size_t i=0; i<set.ivals.length; i+=2)
            add(Interval(set.ivals[i], set.ivals[i+1]-1));
        debug(fred_charset) writeln(ivals);
        return this;
    }

    //Exclude $(D set) from this set.
    //Algebra: this = this - set.
    @trusted ref CodepointSet sub(in CodepointSet set)
    {
        if(empty)
        {
            ivals = [];
            return this;
        }
        if(set.empty)
            return this;
        auto a = cast(Interval[])ivals;
        auto b = cast(const(Interval)[])set.ivals;
        Interval[] result;
        while(!a.empty && !b.empty)
        {
            if(a.front.end < b.front.begin)
            {
                result ~= a.front;
                a.popFront();
            }
            else if(a.front.begin > b.front.end)
            {
                b.popFront();
            }
            else //there is an intersection
            {
                if(a.front.begin < b.front.begin)
                {
                    result ~= Interval(a.front.begin, b.front.begin-1);
                    if(a.front.end < b.front.end)
                    {
                        a.popFront();
                    }
                    else if(a.front.end > b.front.end)
                    {
                        //adjust a in place
                        a.front.begin = b.front.end;
                        if(a.front.begin >= a.front.end)
                            a.popFront();
                        b.popFront();
                    }
                    else //==
                    {
                        a.popFront();
                        b.popFront();
                    }
                }
                else //a.front.begin > b.front.begin
                {//adjust in place
                    if(a.front.end < b.front.end)
                    {
                        a.popFront();
                    }
                    else
                    {
                        a.front.begin = b.front.end;
                        if(a.front.begin >= a.front.end)
                            a.popFront();
                        b.popFront();
                    }
                }
            }
        }
        result ~= a;//+ leftover of original
        ivals = cast(uint[])result;
        return this;
    }

    //Make this set a symmetric difference with $(D set).
    //Algebra: this = this ~ set (i.e. (this || set) -- (this && set)).
    @trusted ref CodepointSet symmetricSub(in CodepointSet set)
    {
        auto a = CodepointSet(ivals.dup);
        a.intersect(set);
        this.add(set);
        this.sub(a);
        return this;
    }

    //Intersect this set with $(D set).
    //Algebra: this = this & set
    @trusted ref CodepointSet intersect(in CodepointSet set)
    {
        if(empty || set.empty)
        {
            ivals = [];
            return this;
        }
        Interval[] intersection;
        auto a = cast(const(Interval)[])ivals;
        auto b = cast(const(Interval)[])set.ivals;
        for(;;)
        {
            if(a.front.end < b.front.begin)
            {
                a.popFront();
                if(a.empty)
                    break;
            }
            else if(a.front.begin > b.front.end)
            {
                b.popFront();
                if(b.empty)
                    break;
            }
            else //there is an intersection
            {
                if(a.front.end < b.front.end)
                {
                    intersection ~= Interval(max(a.front.begin, b.front.begin), a.front.end);
                    a.popFront();
                    if(a.empty)
                        break;
                }
                else if(a.front.end > b.front.end)
                {
                    intersection ~= Interval(max(a.front.begin, b.front.begin), b.front.end);
                    b.popFront();
                    if(b.empty)
                        break;
                }
                else //==
                {
                    intersection ~= Interval(max(a.front.begin, b.front.begin), a.front.end);
                    a.popFront();
                    b.popFront();
                    if(a.empty || b.empty)
                        break;
                }
            }
        }
        ivals = cast(uint[])intersection;
        return this;
    }

    //this = !this (i.e. [^...] in regex syntax)
    @trusted ref CodepointSet negate()
    {
        if(empty)
        {
            insertInPlaceAlt(ivals, 0, 0u, endOfRange);
            return this;
        }
        if(ivals[0] != 0)
            insertInPlaceAlt(ivals, 0, 0u);
        else
        {
            for(size_t i=1; i<ivals.length; i++)
                ivals[i-1] = ivals[i];//moveAll(ivals[1..$], ivals[0..$-1]);
            ivals = ivals[0..$-1];
            if(!__ctfe)
                assumeSafeAppend(ivals);
        }
        if(ivals[$-1] != endOfRange)
            insertInPlaceAlt(ivals, ivals.length, endOfRange);
        else
        {
            ivals = ivals[0..$-1] ;
            if(!__ctfe)
                assumeSafeAppend(ivals);
        }
        assert(!(ivals.length & 1));
        return this;
    }

    /+
        Test if ch is present in this set, linear search done in $(BIGOH N) operations
        on number of $(U intervals) in this set.
        In practice linear search outperforms binary search until a certain threshold.
        Unless number of elements is known to be small in advance it's recommended
        to use overloaded indexing operator.
    +/
    bool scanFor(dchar ch) const
    {
        //linear search is in fact faster (given that length is fixed under threshold)
        for(size_t i=1; i<ivals.length; i+=2)
            if(ch < ivals[i])
                return ch >= ivals[i-1];
        return false;
    }

    /+
        Test if ch is present in this set, in $(BIGOH LogN) operations on number
        of $(U intervals) in this set.
    +/
    @trusted bool opIndex(dchar ch)const
    {
        auto svals = assumeSorted!"a <= b"(ivals);
        auto s = svals.lowerBound(cast(uint)ch).length;
        return s & 1;
    }

    //Test if this set is empty.
    @property bool empty() const pure nothrow {   return ivals.empty; }

    //Write out in regular expression style [\uxxxx-\uyyyy...].
    @trusted void printUnicodeSet(R)(R sink) const
        if(isOutputRange!(R, const(char)[]))
    {
        sink("[");
        for(uint i=0;i<ivals.length; i+=2)
            if(ivals[i] + 1 == ivals[i+1])
                formattedWrite(sink, "\\U%08x", ivals[i]);
            else
                formattedWrite(sink, "\\U%08x-\\U%08x", ivals[i], ivals[i+1]-1);
        sink("]");
    }

    //Deep copy this set.
    @property CodepointSet dup() const
    {
        return CodepointSet(ivals.dup);
    }

    //Full covered length from first codepoint to the last one.
    @property uint extent() const
    {
        return ivals.empty ? 0 : ivals[$-1] - ivals[0];
    }

    //Number of codepoints stored in this set.
    @property uint chars() const
    {
        //CTFE workaround
        uint ret;
        for(uint i=0; i<ivals.length; i+=2)
            ret += ivals[i+1] - ivals[i];
        return ret;
    }

    //Troika for built-in hash maps.
    bool opEquals(ref const CodepointSet set) const
    {
        return ivals == set.ivals;
    }

    //ditto
    int opCmp(ref const CodepointSet set) const
    {
        return cmp(cast(const(uint)[])ivals, cast(const(uint)[])set.ivals);
    }

    //ditto
    hash_t toHash() const pure nothrow @safe
    {
        hash_t hash = 5381+7*ivals.length;
        if(!empty)
            hash = 31*ivals[0] + 17*ivals[$-1];
        return hash;
    }

    struct ByCodepoint
    {
        const(uint)[] ivals;
        uint j;
        this(in CodepointSet set)
        {
            ivals = set.ivals;
            if(!empty)
                j = ivals[0];
        }
        @property bool empty() const { return ivals.empty; }
        @property uint front() const
        {
            assert(!empty);
            return j;
        }
        void popFront()
        {
            assert(!empty);
            if(++j >= ivals[1])
            {
                ivals = ivals[2..$];
                if(!empty)
                    j = ivals[0];
            }
        }
        @property auto ref save() const { return this; }
    }
    static assert(isForwardRange!ByCodepoint);

    //Forward range of all codepoints in this set.
    auto opSlice() const
    {
        return ByCodepoint(this);
    }

    //Random access range of intervals in this set.
    @trusted @property auto byInterval() const
    {
        const(uint)[] hack = ivals;
        return cast(const(Interval)[])hack;
    }
    //eaten alive by @@@BUG@@@s
    /+invariant()
    {
        assert(ivals.length % 2 == 0);
        for(size_t i=1; i<ivals.length; i++)
            assert(ivals[i-1] < ivals[i]);
    }+/
}

/*
    $(D CodepointTrie) is 1-level  $(LUCKY Trie) of codepoints.
    Primary use case is to convert a previously obtained CodepointSet
    in order to speed up subsequent element lookup.

    ---
        auto input = ...;
        Charset set;
        set.add(unicodeAlphabetic).add('$').add('#');
        auto lookup = CodepointTrie!8(set);
        int count;
        foreach(dchar ch; input)
            if(lookup[ch])
                count++;
    ---
    $(D prefixBits) parameter controls number of bits used to index last level
    and provided for tuning to a specific applications.
    A default parameter of 8 works best in common cases though.
*/
struct CodepointTrie(uint prefixBits)
    if(prefixBits > 4)
{
    static if(size_t.sizeof == 4)
        enum unitBits = 2;
    else static if(size_t.sizeof == 8)
        enum unitBits = 3;
    else
        static assert(0);
    enum prefixWordBits = prefixBits-unitBits, prefixSize=1<<prefixBits,
        prefixWordSize = 1<<(prefixWordBits),
        bitTestShift = prefixBits+3, prefixMask = (1<<prefixBits)-1;
    size_t[] data;
    ushort[] indexes;
    bool negative;

    //debugging tool
    @trusted debug(fred_trie) static void printBlock(in size_t[] block)
    {//@@@BUG@@@ write is @system
        for(uint k=0; k<prefixSize; k++)
        {
            if((k & 15) == 0)
                write(" ");
            if((k & 63) == 0)
                writeln();
            writef("%d", bt(block.ptr, k) != 0);
        }
        writeln();
    }

    //ditto
    @trusted debug(fred_trie) void desc() const
    {//@@@BUG@@@ writeln is @system
        writeln(indexes);
        writeln("***Blocks***");
        for(uint i=0; i<data.length; i+=prefixWordSize)
        {
            printBlock(data[i .. i+prefixWordSize]);
            writeln("---");
        }
    }

public:
    //Create a trie from CodepointSet $(D set).
    @trusted this(in CodepointSet s)
    {
        if(s.empty)
            return;
        const(CodepointSet) set = s.chars > 500_000 ? (negative=true, s.dup.negate()) : s;
        uint bound = 0;//set up on first iteration
        ushort emptyBlock = ushort.max;
        auto ivals  = set.ivals;
        size_t[prefixWordSize] page;
        for(uint i=0; i<CodepointSet.endOfRange; i+= prefixSize)
        {
            if(i+prefixSize > ivals[bound] || emptyBlock == ushort.max)//avoid empty blocks if we have one already
            {
                bool flag = true;
            L_Prefix_Loop:
                for(uint j=0; j<prefixSize; j++)
                {
                    while(i+j >= ivals[bound+1])
                    {
                        bound += 2;
                        if(bound == ivals.length)
                        {
                            bound = uint.max;
                            if(flag)//not a single one set so far
                                return;
                            //no more bits in the whole set, but need to add the last bucket
                            break L_Prefix_Loop;
                        }
                    }
                    if(i+j >= ivals[bound])
                    {
                        enum mask = (1<<(3+unitBits))-1;
                        page[j>>(3+unitBits)]
                            |=  cast(size_t)1<<(j & mask);
                        flag = false;
                    }
                }

                debug(fred_trie)
                {
                   printBlock(page);
                }
                uint npos;
                for(npos=0;npos<data.length;npos+=prefixWordSize)
                    if(equal(page[], data[npos .. npos+prefixWordSize]))
                    {
                        indexes ~= cast(ushort)(npos>>prefixWordBits);
                        break;
                    }
                if(npos == data.length)
                {
                    indexes ~= cast(ushort)(data.length>>prefixWordBits);
                    data ~= page;
                    if(flag)
                        emptyBlock = indexes[$-1];
                }
                if(bound == uint.max)
                    break;
                page[] = 0;
            }
            else//fast reroute whole blocks to an empty one
            {
                indexes ~= emptyBlock;
            }
        }
    }

    //Test if contains $(D ch).
    @trusted bool opIndex(dchar ch) const
    {
        assert(ch < 0x110000);
        uint ind = ch>>prefixBits;
        if(ind >= indexes.length)
            return negative;
        return cast(bool)bt(data.ptr, (indexes[ind]<<bitTestShift)+(ch&prefixMask)) ^ negative;
        version(none)//is in fact slower (on AMD Phenom)
        {
            auto ptr = cast(const(ubyte)*)data.ptr;
            return ((ptr[(cast(size_t)indexes[ind]<<prefixBits) + ((ch&prefixMask)>>3)]>>(ch&7))&1) ^ negative;
        }
    }

    //invert trie (trick internal for regular expressions, has aliasing problem)
    @trusted private auto negated() const
    {
        CodepointTrie t = cast(CodepointTrie)this;//shallow copy, need to subvert type system?
        t.negative = !negative;
        return t;
    }
}


unittest
{
    auto wordSet =
        CodepointSet.init.add(unicodeAlphabetic).add(unicodeMn).add(unicodeMc)
        .add(unicodeMe).add(unicodeNd).add(unicodePc);
    auto t = CodepointTrie!8(wordSet);
    assert(t['a']);
    assert(!t[' ']);
}

unittest
{
    CodepointSet set;
    set.add(unicodeAlphabetic);
    for(size_t i=1;i<set.ivals.length; i++)
        assert(set.ivals[i-1] < set.ivals[i]);
}

@system unittest
{
    import std.conv, std.random, std.range;
    immutable seed = unpredictableSeed();
    auto rnd = Random(seed);

    auto testCases = randomSample(unicodeProperties, 10, rnd);

    // test trie using ~2000 codepoints
    foreach(up; testCases.save)
    {
        void test(in CodepointSet set, scope void delegate(uint ch) dg)
        {
            foreach (_; 0 .. 10)
            {
                immutable idx = uniform(0, set.ivals.length / 2, rnd);
                immutable lo = set.ivals[2*idx], hi = set.ivals[2*idx+1];
                foreach (_2; 0 .. min(10, hi - lo))
                    dg(uniform(lo, hi, rnd));
            }
        }

        auto neg = up.set.dup.negate();
        auto trie = CodepointTrie!8(up.set);
        test(up.set, ch => assert(trie[ch], text("on ch == ", ch, " seed was ", seed)));
        test(neg, ch => assert(!trie[ch], text("negative on ch == ", ch, " seed was ", seed)));
    }

    // test that negate is reversible
    foreach(up; testCases.save)
    {
        auto neg = up.set.dup.negate().negate();
        assert(equal(up.set.ivals, neg.ivals));
    }

    // test codepoint forward iterator
    auto set = testCases.front.set;
    auto rng = set[];
    foreach (idx; 0 .. set.ivals.length / 2)
    {
        immutable lo = set.ivals[2*idx], hi = set.ivals[2*idx+1];
        foreach (val; lo .. hi)
        {
            assert(rng.front == val, text("on val == ", val, " seed was ", seed));
            rng.popFront();
        }
    }
}


//fussy compare for unicode property names as per UTS-18
int comparePropertyName(Char)(const(Char)[] a, const(Char)[] b)
{
    for(;;)
    {
        while(!a.empty && (isWhite(a.front) || a.front == '-' || a.front =='_'))
        {
            a.popFront();
        }
        while(!b.empty && (isWhite(b.front) || b.front == '-' || b.front =='_'))
        {
            b.popFront();
        }
        if(a.empty)
            return b.empty ? 0 : -1;
        if(b.empty)
            return 1;
        auto ca = toLower(a.front), cb = toLower(b.front);
        if(ca > cb)
            return 1;
        else if( ca < cb)
            return -1;
        a.popFront();
        b.popFront();
    }
}

//ditto (workaround for internal tools)
public bool propertyNameLess(Char)(const(Char)[] a, const(Char)[] b)
{
    return comparePropertyName(a, b) < 0;
}

unittest
{
    assert(comparePropertyName("test","test") == 0);
    assert(comparePropertyName("Al chemical Symbols", "Alphabetic Presentation Forms") == -1);
    assert(comparePropertyName("Basic Latin","basic-LaTin") == 0);
}

//Gets array of all of common case eqivalents of given codepoint
//(fills provided array & returns a slice of it)
@trusted dchar[] getCommonCasing(dchar ch, dchar[] range)
{
    CommonCaseEntry cs;
    size_t i=1, j=0;
    range[0] = ch;
    while(j < i)
    {
        ch = range[j++];
        cs.start = ch;
        cs.end = ch;
        auto idx = assumeSorted!"a.end <= b.end"(commonCaseTable)
            .lowerBound(cs).length;
        immutable(CommonCaseEntry)[] slice = commonCaseTable[idx..$];
        idx = assumeSorted!"a.start <= b.start"(slice).lowerBound(cs).length;
        slice = slice[0..idx];
        foreach(v; slice)
            if(ch < v.end)
            {
                if(v.xor)
                {
                    auto t = ch ^ v.delta;
                    if(countUntil(range[0..i], t) < 0)
                        range[i++] = t;
                }
                else
                {
                    auto t =  v.neg ? ch - v.delta : ch + v.delta;
                    if(countUntil(range[0..i], t) < 0)
                        range[i++] = t;
                }
            }
    }
    return range[0..i];
}

unittest
{
    dchar[6] data;
    //these values give 100% code coverage for getCommonCasing
    assert(getCommonCasing(0x01BC, data) == [0x01bc, 0x01bd]);
    assert(getCommonCasing(0x03B9, data) == [0x03b9, 0x0399, 0x1fbe, 0x0345]);
    assert(getCommonCasing(0x10402, data) == [0x10402, 0x1042a]);
}

//
@trusted CodepointSet caseEnclose(in CodepointSet set)
{
    CodepointSet n;
    for(size_t i=0;i<set.ivals.length; i+=2)
    {
        CommonCaseEntry cs;
        cs.start = set.ivals[i+1]-1;
        cs.end = set.ivals[i];
        auto idx = assumeSorted!"a.end <= b.end"(commonCaseTable)
            .lowerBound(cs).length;
        immutable(CommonCaseEntry)[] slice = commonCaseTable[idx..$];
        idx = assumeSorted!"a.start <= b.start"(slice)
            .lowerBound(cs).length;
        slice = slice[0..idx];
        if(!slice.empty)
        {
            dchar[6] r;
            for(uint ch = set.ivals[i]; ch <set.ivals[i+1]; ch++)
            {
                auto rng = getCommonCasing(ch, r[]);
                foreach(v; rng)
                    n.add(v);
            }
        }
        else
            n.add(Interval(cs.end,cs.start));
    }
    return n;
}
