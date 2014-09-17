/*
    Implementation of std.regex IR, an intermediate representation
    of a regular expression pattern.

    This is a common ground between frontend regex component (parser)
    and backend components - generators, matchers and other "filters".
*/
module std.regex.internal.ir;

package(std.regex):

import std.exception, std.uni, std.typetuple, std.traits, std.range;

// just a common trait, may be moved elsewhere
alias BasicElementOf(Range) = Unqual!(ElementEncodingType!Range);

// heuristic value determines maximum CodepointSet length suitable for linear search
enum maxCharsetUsed = 6;

// another variable to tweak behavior of caching generated Tries for character classes
enum maxCachedTries = 8;

alias CodepointSetTrie!(13, 8) Trie;
alias codepointSetTrie!(13, 8) makeTrie;

Trie[CodepointSet] trieCache;

//accessor with caching
@trusted Trie getTrie(CodepointSet set)
{// @@@BUG@@@ 6357 almost all properties of AA are not @safe
    if(__ctfe || maxCachedTries == 0)
        return makeTrie(set);
    else
    {
        auto p = set in trieCache;
        if(p)
            return *p;
        if(trieCache.length == maxCachedTries)
        {
            // flush entries in trieCache
            trieCache = null;
        }
        return (trieCache[set] = makeTrie(set));
    }
}

@trusted auto memoizeExpr(string expr)()
{
    if(__ctfe)
        return mixin(expr);
    alias T = typeof(mixin(expr));
    static T slot;
    static bool initialized;
    if(!initialized)
    {
        slot =  mixin(expr);
        initialized = true;
    }
    return slot;
}

//property for \w character class
@property CodepointSet wordCharacter()
{
    return memoizeExpr!("unicode.Alphabetic | unicode.Mn | unicode.Mc
        | unicode.Me | unicode.Nd | unicode.Pc")();
}

@property Trie wordTrie()
{
    return memoizeExpr!("makeTrie(wordCharacter)")();
}

// some special Unicode white space characters
private enum NEL = '\u0085', LS = '\u2028', PS = '\u2029';

//Regular expression engine/parser options:
// global - search  all nonoverlapping matches in input
// casefold - case insensitive matching, do casefolding on match in unicode mode
// freeform - ignore whitespace in pattern, to match space use [ ] or \s
// multiline - switch  ^, $ detect start and end of linesinstead of just start and end of input
enum RegexOption: uint {
    global = 0x1,
    casefold = 0x2,
    freeform = 0x4,
    nonunicode = 0x8,
    multiline = 0x10,
    singleline = 0x20
}
//do not reorder this list
alias RegexOptionNames = TypeTuple!('g', 'i', 'x', 'U', 'm', 's');
static assert( RegexOption.max < 0x80);
// flags that allow guide execution of engine
enum RegexInfo : uint { oneShot = 0x80 }

// IR bit pattern: 0b1_xxxxx_yy
// where yy indicates class of instruction, xxxxx for actual operation code
//     00: atom, a normal instruction
//     01: open, opening of a group, has length of contained IR in the low bits
//     10: close, closing of a group, has length of contained IR in the low bits
//     11 unused
//
// Loops with Q (non-greedy, with ? mark) must have the same size / other properties as non Q version
// Possible changes:
//* merge group, option, infinite/repeat start (to never copy during parsing of (a|b){1,2})
//* reorganize groups to make n args easier to find, or simplify the check for groups of similar ops
//  (like lookaround), or make it easier to identify hotspots.

enum IR:uint {
    Char              = 0b1_00000_00, //a character
    Any               = 0b1_00001_00, //any character
    CodepointSet      = 0b1_00010_00, //a most generic CodepointSet [...]
    Trie              = 0b1_00011_00, //CodepointSet implemented as Trie
    //match with any of a consecutive OrChar's in this sequence
    //(used for case insensitive match)
    //OrChar holds in upper two bits of data total number of OrChars in this _sequence_
    //the drawback of this representation is that it is difficult
    // to detect a jump in the middle of it
    OrChar            = 0b1_00100_00,
    Nop               = 0b1_00101_00, //no operation (padding)
    End               = 0b1_00110_00, //end of program
    Bol               = 0b1_00111_00, //beginning of a string ^
    Eol               = 0b1_01000_00, //end of a string $
    Wordboundary      = 0b1_01001_00, //boundary of a word
    Notwordboundary   = 0b1_01010_00, //not a word boundary
    Backref           = 0b1_01011_00, //backreference to a group (that has to be pinned, i.e. locally unique) (group index)
    GroupStart        = 0b1_01100_00, //start of a group (x) (groupIndex+groupPinning(1bit))
    GroupEnd          = 0b1_01101_00, //end of a group (x) (groupIndex+groupPinning(1bit))
    Option            = 0b1_01110_00, //start of an option within an alternation x | y (length)
    GotoEndOr         = 0b1_01111_00, //end of an option (length of the rest)
    //... any additional atoms here

    OrStart           = 0b1_00000_01, //start of alternation group  (length)
    OrEnd             = 0b1_00000_10, //end of the or group (length,mergeIndex)
    //with this instruction order
    //bit mask 0b1_00001_00 could be used to test/set greediness
    InfiniteStart     = 0b1_00001_01, //start of an infinite repetition x* (length)
    InfiniteEnd       = 0b1_00001_10, //end of infinite repetition x* (length,mergeIndex)
    InfiniteQStart    = 0b1_00010_01, //start of a non eager infinite repetition x*? (length)
    InfiniteQEnd      = 0b1_00010_10, //end of non eager infinite repetition x*? (length,mergeIndex)
    RepeatStart       = 0b1_00011_01, //start of a {n,m} repetition (length)
    RepeatEnd         = 0b1_00011_10, //end of x{n,m} repetition (length,step,minRep,maxRep)
    RepeatQStart      = 0b1_00100_01, //start of a non eager x{n,m}? repetition (length)
    RepeatQEnd        = 0b1_00100_10, //end of non eager x{n,m}? repetition (length,step,minRep,maxRep)
    //
    LookaheadStart    = 0b1_00101_01, //begin of the lookahead group (length)
    LookaheadEnd      = 0b1_00101_10, //end of a lookahead group (length)
    NeglookaheadStart = 0b1_00110_01, //start of a negative lookahead (length)
    NeglookaheadEnd   = 0b1_00110_10, //end of a negative lookahead (length)
    LookbehindStart   = 0b1_00111_01, //start of a lookbehind (length)
    LookbehindEnd     = 0b1_00111_10, //end of a lookbehind (length)
    NeglookbehindStart= 0b1_01000_01, //start of a negative lookbehind (length)
    NeglookbehindEnd  = 0b1_01000_10, //end of negative lookbehind (length)
}

//a shorthand for IR length - full length of specific opcode evaluated at compile time
template IRL(IR code)
{
    enum uint IRL =  lengthOfIR(code);
}
static assert (IRL!(IR.LookaheadStart) == 3);

//how many parameters follow the IR, should be optimized fixing some IR bits
int immediateParamsIR(IR i){
    switch (i){
    case IR.OrEnd,IR.InfiniteEnd,IR.InfiniteQEnd:
        return 1;
    case IR.RepeatEnd, IR.RepeatQEnd:
        return 4;
    case IR.LookaheadStart, IR.NeglookaheadStart, IR.LookbehindStart, IR.NeglookbehindStart:
        return 2;
    default:
        return 0;
    }
}

//full length of IR instruction inlcuding all parameters that might follow it
int lengthOfIR(IR i)
{
    return 1 + immediateParamsIR(i);
}

//full length of the paired IR instruction inlcuding all parameters that might follow it
int lengthOfPairedIR(IR i)
{
    return 1 + immediateParamsIR(pairedIR(i));
}

//if the operation has a merge point (this relies on the order of the ops)
bool hasMerge(IR i)
{
    return (i&0b11)==0b10 && i <= IR.RepeatQEnd;
}

//is an IR that opens a "group"
bool isStartIR(IR i)
{
    return (i&0b11)==0b01;
}

//is an IR that ends a "group"
bool isEndIR(IR i)
{
    return (i&0b11)==0b10;
}

//is a standalone IR
bool isAtomIR(IR i)
{
    return (i&0b11)==0b00;
}

//makes respective pair out of IR i, swapping start/end bits of instruction
IR pairedIR(IR i)
{
    assert(isStartIR(i) || isEndIR(i));
    return cast(IR)(i ^ 0b11);
}

//encoded IR instruction
struct Bytecode
{
    uint raw;
    //natural constraints
    enum maxSequence = 2+4;
    enum maxData = 1<<22;
    enum maxRaw = 1<<31;

    this(IR code, uint data)
    {
        assert(data < (1<<22) && code < 256);
        raw = code<<24 | data;
    }

    this(IR code, uint data, uint seq)
    {
        assert(data < (1<<22) && code < 256 );
        assert(seq >= 2 && seq < maxSequence);
        raw = code << 24 | (seq - 2)<<22 | data;
    }

    //store raw data
    static Bytecode fromRaw(uint data)
    {
        Bytecode t;
        t.raw = data;
        return t;
    }

    //bit twiddling helpers
    //0-arg template due to @@@BUG@@@ 10985
    @property uint data()() const { return raw & 0x003f_ffff; }

    //ditto
    //0-arg template due to @@@BUG@@@ 10985
    @property uint sequence()() const { return 2 + (raw >> 22 & 0x3); }

    //ditto
    //0-arg template due to @@@BUG@@@ 10985
    @property IR code()() const { return cast(IR)(raw>>24); }

    //ditto
    @property bool hotspot() const { return hasMerge(code); }

    //test the class of this instruction
    @property bool isAtom() const { return isAtomIR(code); }

    //ditto
    @property bool isStart() const { return isStartIR(code); }

    //ditto
    @property bool isEnd() const { return isEndIR(code); }

    //number of arguments for this instruction
    @property int args() const { return immediateParamsIR(code); }

    //mark this GroupStart or GroupEnd as referenced in backreference
    void setBackrefence()
    {
        assert(code == IR.GroupStart || code == IR.GroupEnd);
        raw = raw | 1 << 23;
    }

    //is referenced
    @property bool backreference() const
    {
        assert(code == IR.GroupStart || code == IR.GroupEnd);
        return cast(bool)(raw & 1 << 23);
    }

    //mark as local reference (for backrefs in lookarounds)
    void setLocalRef()
    {
        assert(code == IR.Backref);
        raw = raw | 1 << 23;
    }

    //is a local ref
    @property bool localRef() const
    {
        assert(code == IR.Backref);
        return cast(bool)(raw & 1 << 23);
    }

    //human readable name of instruction
    @trusted @property string mnemonic()() const
    {//@@@BUG@@@ to is @system
        import std.conv;
        return to!string(code);
    }

    //full length of instruction
    @property uint length() const
    {
        return lengthOfIR(code);
    }

    //full length of respective start/end of this instruction
    @property uint pairedLength() const
    {
        return lengthOfPairedIR(code);
    }

    //returns bytecode of paired instruction (assuming this one is start or end)
    @property Bytecode paired() const
    {//depends on bit and struct layout order
        assert(isStart || isEnd);
        return Bytecode.fromRaw(raw ^ 0b11 << 24);
    }

    //gets an index into IR block of the respective pair
    uint indexOfPair(uint pc) const
    {
        assert(isStart || isEnd);
        return isStart ? pc + data + length  : pc - data - lengthOfPairedIR(code);
    }
}

static assert(Bytecode.sizeof == 4);


//index entry structure for name --> number of submatch
struct NamedGroup
{
    string name;
    uint group;
}

//holds pair of start-end markers for a submatch
struct Group(DataIndex)
{
    DataIndex begin, end;
    @trusted string toString()() const
    {
        import std.format;
        auto a = appender!string();
        formattedWrite(a, "%s..%s", begin, end);
        return a.data;
    }
}

//debugging tool, prints out instruction along with opcodes
@trusted string disassemble(in Bytecode[] irb, uint pc, in NamedGroup[] dict=[])
{
    import std.array, std.format;
    auto output = appender!string();
    formattedWrite(output,"%s", irb[pc].mnemonic);
    switch(irb[pc].code)
    {
    case IR.Char:
        formattedWrite(output, " %s (0x%x)",cast(dchar)irb[pc].data, irb[pc].data);
        break;
    case IR.OrChar:
        formattedWrite(output, " %s (0x%x) seq=%d", cast(dchar)irb[pc].data, irb[pc].data, irb[pc].sequence);
        break;
    case IR.RepeatStart, IR.InfiniteStart, IR.Option, IR.GotoEndOr, IR.OrStart:
        //forward-jump instructions
        uint len = irb[pc].data;
        formattedWrite(output, " pc=>%u", pc+len+IRL!(IR.RepeatStart));
        break;
    case IR.RepeatEnd, IR.RepeatQEnd: //backward-jump instructions
        uint len = irb[pc].data;
        formattedWrite(output, " pc=>%u min=%u max=%u step=%u",
            pc - len, irb[pc + 3].raw, irb[pc + 4].raw, irb[pc + 2].raw);
        break;
    case IR.InfiniteEnd, IR.InfiniteQEnd, IR.OrEnd: //ditto
        uint len = irb[pc].data;
        formattedWrite(output, " pc=>%u", pc-len);
        break;
    case  IR.LookaheadEnd, IR.NeglookaheadEnd: //ditto
        uint len = irb[pc].data;
        formattedWrite(output, " pc=>%u", pc-len);
        break;
    case IR.GroupStart, IR.GroupEnd:
        uint n = irb[pc].data;
        string name;
        foreach(v;dict)
            if(v.group == n)
            {
                name = "'"~v.name~"'";
                break;
            }
        formattedWrite(output, " %s #%u " ~ (irb[pc].backreference ? "referenced" : ""),
                name, n);
        break;
    case IR.LookaheadStart, IR.NeglookaheadStart, IR.LookbehindStart, IR.NeglookbehindStart:
        uint len = irb[pc].data;
        uint start = irb[pc+1].raw, end = irb[pc+2].raw;
        formattedWrite(output, " pc=>%u [%u..%u]", pc + len + IRL!(IR.LookaheadStart), start, end);
        break;
    case IR.Backref: case IR.CodepointSet: case IR.Trie:
        uint n = irb[pc].data;
        formattedWrite(output, " %u",  n);
        if(irb[pc].code == IR.Backref)
            formattedWrite(output, " %s", irb[pc].localRef ? "local" : "global");
        break;
    default://all data-free instructions
    }
    if(irb[pc].hotspot)
        formattedWrite(output, " Hotspot %u", irb[pc+1].raw);
    return output.data;
}

//disassemble the whole chunk
@trusted void printBytecode()(in Bytecode[] slice, in NamedGroup[] dict=[])
{
    import std.stdio;
    for(uint pc=0; pc<slice.length; pc += slice[pc].length)
        writeln("\t", disassemble(slice, pc, dict));
}

/++
    $(D Regex) object holds regular expression pattern in compiled form.
    Instances of this object are constructed via calls to $(D regex).
    This is an intended form for caching and storage of frequently
    used regular expressions.
+/
struct Regex(Char)
{
    //temporary workaround for identifier lookup
    CodepointSet[] charsets; //
    Bytecode[] ir;      //compiled bytecode of pattern


    @safe @property bool empty() const nothrow {  return ir is null; }

    @safe @property auto namedCaptures()
    {
        static struct NamedGroupRange
        {
        private:
            NamedGroup[] groups;
            size_t start;
            size_t end;
        public:
            this(NamedGroup[] g, size_t s, size_t e)
            {
                assert(s <= e);
                assert(e <= g.length);
                groups = g;
                start = s;
                end = e;
            }

            @property string front() { return groups[start].name; }
            @property string back() { return groups[end-1].name; }
            @property bool empty() { return start >= end; }
            @property size_t length() { return end - start; }
            alias opDollar = length;
            @property NamedGroupRange save()
            {
                return NamedGroupRange(groups, start, end);
            }
            void popFront() { assert(!empty); start++; }
            void popBack() { assert(!empty); end--; }
            string opIndex()(size_t i)
            {
                assert(start + i < end,
                       "Requested named group is out of range.");
                return groups[start+i].name;
            }
            NamedGroupRange opSlice(size_t low, size_t high) {
                assert(low <= high);
                assert(start + high <= end);
                return NamedGroupRange(groups, start + low, start + high);
            }
            NamedGroupRange opSlice() { return this.save; }
        }
        return NamedGroupRange(dict, 0, dict.length);
    }

package:
    import std.regex.internal.kickstart; //TODO: get rid of this dependency
    NamedGroup[] dict;  //maps name -> user group number
    uint ngroup;        //number of internal groups
    uint maxCounterDepth; //max depth of nested {n,m} repetitions
    uint hotspotTableSize; //number of entries in merge table
    uint threadCount;
    uint flags;         //global regex flags
    public const(Trie)[]  tries; //
    uint[] backrefed; //bit array of backreferenced submatches
    Kickstart!Char kickstart;

    //bit access helper
    uint isBackref(uint n)
    {
        if(n/32 >= backrefed.length)
            return 0;
        return backrefed[n / 32] & (1 << (n & 31));
    }

    //check if searching is not needed
    void checkIfOneShot()
    {
        if(flags & RegexOption.multiline)
            return;
    L_CheckLoop:
        for(uint i = 0; i < ir.length; i += ir[i].length)
        {
            switch(ir[i].code)
            {
                case IR.Bol:
                    flags |= RegexInfo.oneShot;
                    break L_CheckLoop;
                case IR.GroupStart, IR.GroupEnd, IR.Eol, IR.Wordboundary, IR.Notwordboundary:
                    break;
                default:
                    break L_CheckLoop;
            }
        }
    }

    //print out disassembly a program's IR
    @trusted debug(std_regex_parser) void print() const
    {//@@@BUG@@@ write is system
        for(uint i = 0; i < ir.length; i += ir[i].length)
        {
            writefln("%d\t%s ", i, disassemble(ir, i, dict));
        }
        writeln("Total merge table size: ", hotspotTableSize);
        writeln("Max counter nesting depth: ", maxCounterDepth);
    }

}

//@@@BUG@@@ (unreduced) - public makes it inaccessible in std.regex.package (!)
/*public*/ struct StaticRegex(Char)
{
package:
    import std.regex.internal.backtracking;
    alias Matcher = BacktrackingMatcher!(true);
    alias MatchFn = bool function(ref Matcher!Char) @trusted;
    MatchFn nativeFn;
public:
    Regex!Char _regex;
    alias _regex this;
    this(Regex!Char re, MatchFn fn)
    {
        _regex = re;
        nativeFn = fn;

    }

}

// The stuff below this point is temporarrily part of IR module
// but may need better place in the future (all internals)
package:

//Simple UTF-string abstraction compatible with stream interface
struct Input(Char)
    if(is(Char :dchar))
{
    import std.utf;
    alias DataIndex = size_t;
    enum { isLoopback = false };
    alias String = const(Char)[];
    String _origin;
    size_t _index;

    //constructs Input object out of plain string
    this(String input, size_t idx = 0)
    {
        _origin = input;
        _index = idx;
    }

    //codepoint at current stream position
    bool nextChar(ref dchar res, ref size_t pos)
    {
        pos = _index;
        if(_index == _origin.length)
            return false;
        res = std.utf.decode(_origin, _index);
        return true;
    }
    @property bool atEnd(){
        return _index == _origin.length;
    }
    bool search(Kickstart)(ref Kickstart kick, ref dchar res, ref size_t pos)
    {
        size_t idx = kick.search(_origin, _index);
        _index = idx;
        return nextChar(res, pos);
    }

    //index of at End position
    @property size_t lastIndex(){   return _origin.length; }

    //support for backtracker engine, might not be present
    void reset(size_t index){   _index = index;  }

    String opSlice(size_t start, size_t end){   return _origin[start..end]; }

    struct BackLooper
    {
        alias DataIndex = size_t;
        enum { isLoopback = true };
        String _origin;
        size_t _index;
        this(Input input, size_t index)
        {
            _origin = input._origin;
            _index = index;
        }
        @trusted bool nextChar(ref dchar res,ref size_t pos)
        {
            pos = _index;
            if(_index == 0)
                return false;

            res = _origin[0.._index].back;
            _index -= std.utf.strideBack(_origin, _index);

            return true;
        }
        @property atEnd(){ return _index == 0 || _index == std.utf.strideBack(_origin, _index); }
        auto loopBack(size_t index){   return Input(_origin, index); }

        //support for backtracker engine, might not be present
        //void reset(size_t index){   _index = index ? index-std.utf.strideBack(_origin, index) : 0;  }
        void reset(size_t index){   _index = index;  }

        String opSlice(size_t start, size_t end){   return _origin[end..start]; }
        //index of at End position
        @property size_t lastIndex(){   return 0; }
    }
    auto loopBack(size_t index){   return BackLooper(this, index); }
}


//both helpers below are internal, on its own are quite "explosive"
//unsafe, no initialization of elements
@system T[] mallocArray(T)(size_t len)
{
    import core.stdc.stdlib;
    return (cast(T*)malloc(len * T.sizeof))[0 .. len];
}

//very unsafe, no initialization
@system T[] arrayInChunk(T)(size_t len, ref void[] chunk)
{
    auto ret = (cast(T*)chunk.ptr)[0..len];
    chunk = chunk[len * T.sizeof .. $];
    return ret;
}

//
@trusted uint lookupNamedGroup(String)(NamedGroup[] dict, String name)
{//equal is @system?
    import std.conv;
    import std.algorithm : map, equal;

    auto fnd = assumeSorted!"cmp(a,b) < 0"(map!"a.name"(dict)).lowerBound(name).length;
    enforce(fnd < dict.length && equal(dict[fnd].name, name),
        text("no submatch named ", name));
    return dict[fnd].group;
}

//whether ch is one of unicode newline sequences
//0-arg template due to @@@BUG@@@ 10985
bool endOfLine()(dchar front, bool seenCr)
{
    return ((front == '\n') ^ seenCr) || front == '\r'
    || front == NEL || front == LS || front == PS;
}

//
//0-arg template due to @@@BUG@@@ 10985
bool startOfLine()(dchar back, bool seenNl)
{
    return ((back == '\r') ^ seenNl) || back == '\n'
    || back == NEL || back == LS || back == PS;
}

//Test if bytecode starting at pc in program 're' can match given codepoint
//Returns: 0 - can't tell, -1 if doesn't match
int quickTestFwd(RegEx)(uint pc, dchar front, const ref RegEx re)
{
    static assert(IRL!(IR.OrChar) == 1);//used in code processing IR.OrChar
    for(;;)
        switch(re.ir[pc].code)
        {
        case IR.OrChar:
            uint len = re.ir[pc].sequence;
            uint end = pc + len;
            if(re.ir[pc].data != front && re.ir[pc+1].data != front)
            {
                for(pc = pc+2; pc < end; pc++)
                    if(re.ir[pc].data == front)
                        break;
                if(pc == end)
                    return -1;
            }
            return 0;
        case IR.Char:
            if(front == re.ir[pc].data)
                return 0;
            else
                return -1;
        case IR.Any:
            return 0;
        case IR.CodepointSet:
            if(re.charsets[re.ir[pc].data].scanFor(front))
                return 0;
            else
                return -1;
        case IR.GroupStart, IR.GroupEnd:
            pc += IRL!(IR.GroupStart);
            break;
        case IR.Trie:
            if(re.tries[re.ir[pc].data][front])
                return 0;
            else
                return -1;
        default:
            return 0;
        }
}

///Exception object thrown in case of errors during regex compilation.
public class RegexException : Exception
{
    ///
    @trusted this(string msg, string file = __FILE__, size_t line = __LINE__)
    {//@@@BUG@@@ Exception constructor is not @safe
        super(msg, file, line);
    }
}
