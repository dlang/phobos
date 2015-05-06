//Written in the D programming language
/*
    Regular expression pattern parser.
*/
module std.regex.internal.parser;

import std.regex.internal.ir;
import std.algorithm, std.range, std.uni, std.typetuple,
    std.traits, std.typecons, std.exception;

// package relevant info from parser into a regex object
auto makeRegex(S)(Parser!S p)
{
    Regex!(BasicElementOf!S) re;
    with(re)
    {
        ir = p.ir;
        dict = p.dict;
        ngroup = p.groupStack.top;
        maxCounterDepth = p.counterDepth;
        flags = p.re_flags;
        charsets = p.charsets;
        tries = p.tries;
        backrefed = p.backrefed;
        re.lightPostprocess();
        debug(std_regex_parser)
        {
            print();
        }
        //@@@BUG@@@ (not reduced)
        //somehow just using validate _collides_ with std.utf.validate (!)
        version(assert) re.validateRe();
    }
    return re;
}

// helper for unittest
auto makeRegex(S)(S arg)
    if(isSomeString!S)
{
    return makeRegex(Parser!S(arg, ""));
}

unittest
{
    auto re = makeRegex(`(?P<name>\w+) = (?P<var>\d+)`);
    auto nc = re.namedCaptures;
    static assert(isRandomAccessRange!(typeof(nc)));
    assert(!nc.empty);
    assert(nc.length == 2);
    assert(nc.equal(["name", "var"]));
    assert(nc[0] == "name");
    assert(nc[1..$].equal(["var"]));

    re = makeRegex(`(\w+) (?P<named>\w+) (\w+)`);
    nc = re.namedCaptures;
    assert(nc.length == 1);
    assert(nc[0] == "named");
    assert(nc.front == "named");
    assert(nc.back == "named");

    re = makeRegex(`(\w+) (\w+)`);
    nc = re.namedCaptures;
    assert(nc.empty);

    re = makeRegex(`(?P<year>\d{4})/(?P<month>\d{2})/(?P<day>\d{2})/`);
    nc = re.namedCaptures;
    auto cp = nc.save;
    assert(nc.equal(cp));
    nc.popFront();
    assert(nc.equal(cp[1..$]));
    nc.popBack();
    assert(nc.equal(cp[1 .. $ - 1]));
}


@trusted void reverseBytecode()(Bytecode[] code)
{
    Bytecode[] rev = new Bytecode[code.length];
    uint revPc = cast(uint)rev.length;
    Stack!(Tuple!(uint, uint, uint)) stack;
    uint start = 0;
    uint end = cast(uint)code.length;
    for(;;)
    {
        for(uint pc = start; pc < end; )
        {
            uint len = code[pc].length;
            if(code[pc].code == IR.GotoEndOr)
                break; //pick next alternation branch
            if(code[pc].isAtom)
            {
                rev[revPc - len .. revPc] = code[pc .. pc + len];
                revPc -= len;
                pc += len;
            }
            else if(code[pc].isStart || code[pc].isEnd)
            {
                //skip over other embedded lookbehinds they are reversed
                if(code[pc].code == IR.LookbehindStart
                    || code[pc].code == IR.NeglookbehindStart)
                {
                    uint blockLen = len + code[pc].data
                         + code[pc].pairedLength;
                    rev[revPc - blockLen .. revPc] = code[pc .. pc + blockLen];
                    pc += blockLen;
                    revPc -= blockLen;
                    continue;
                }
                uint second = code[pc].indexOfPair(pc);
                uint secLen = code[second].length;
                rev[revPc - secLen .. revPc] = code[second .. second + secLen];
                revPc -= secLen;
                if(code[pc].code == IR.OrStart)
                {
                    //we pass len bytes forward, but secLen in reverse
                    uint revStart = revPc - (second + len - secLen - pc);
                    uint r = revStart;
                    uint i = pc + IRL!(IR.OrStart);
                    while(code[i].code == IR.Option)
                    {
                        if(code[i - 1].code != IR.OrStart)
                        {
                            assert(code[i - 1].code == IR.GotoEndOr);
                            rev[r - 1] = code[i - 1];
                        }
                        rev[r] = code[i];
                        auto newStart = i + IRL!(IR.Option);
                        auto newEnd = newStart + code[i].data;
                        auto newRpc = r + code[i].data + IRL!(IR.Option);
                        if(code[newEnd].code != IR.OrEnd)
                        {
                            newRpc--;
                        }
                        stack.push(tuple(newStart, newEnd, newRpc));
                        r += code[i].data + IRL!(IR.Option);
                        i += code[i].data + IRL!(IR.Option);
                    }
                    pc = i;
                    revPc = revStart;
                    assert(code[pc].code == IR.OrEnd);
                }
                else
                    pc += len;
            }
        }
        if(stack.empty)
            break;
        start = stack.top[0];
        end = stack.top[1];
        revPc = stack.top[2];
        stack.pop();
    }
    code[] = rev[];
}


alias Escapables = TypeTuple!('[', ']', '\\', '^', '$', '.', '|', '?', ',', '-',
    ';', ':', '#', '&', '%', '/', '<', '>', '`',  '*', '+', '(', ')', '{', '}',  '~');

//test if a given string starts with hex number of maxDigit that's a valid codepoint
//returns it's value and skips these maxDigit chars on success, throws on failure
dchar parseUniHex(Char)(ref Char[] str, size_t maxDigit)
{
    //std.conv.parse is both @system and bogus
    enforce(str.length >= maxDigit,"incomplete escape sequence");
    uint val;
    for(int k = 0; k < maxDigit; k++)
    {
        auto current = str[k];//accepts ascii only, so it's OK to index directly
        if('0' <= current && current <= '9')
            val = val * 16 + current - '0';
        else if('a' <= current && current <= 'f')
            val = val * 16 + current -'a' + 10;
        else if('A' <= current && current <= 'F')
            val = val * 16 + current - 'A' + 10;
        else
            throw new Exception("invalid escape sequence");
    }
    enforce(val <= 0x10FFFF, "invalid codepoint");
    str = str[maxDigit..$];
    return val;
}

@system unittest //BUG canFind is system
{
    string[] non_hex = [ "000j", "000z", "FffG", "0Z"];
    string[] hex = [ "01", "ff", "00af", "10FFFF" ];
    int[] value = [ 1, 0xFF, 0xAF, 0x10FFFF ];
    foreach(v; non_hex)
        assert(collectException(parseUniHex(v, v.length)).msg
          .canFind("invalid escape sequence"));
    foreach(i, v; hex)
        assert(parseUniHex(v, v.length) == value[i]);
    string over = "0011FFFF";
    assert(collectException(parseUniHex(over, over.length)).msg
      .canFind("invalid codepoint"));
}

//heuristic value determines maximum CodepointSet length suitable for linear search
enum maxCharsetUsed = 6;

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


auto caseEnclose(CodepointSet set)
{
    auto cased = set & unicode.LC;
    foreach (dchar ch; cased.byCodepoint)
    {
        foreach(c; simpleCaseFoldings(ch))
            set |= c;
    }
    return set;
}

/+
    fetch codepoint set corresponding to a name (InBlock or binary property)
+/
@trusted CodepointSet getUnicodeSet(in char[] name, bool negated,  bool casefold)
{
    CodepointSet s = unicode(name);
    //FIXME: caseEnclose for new uni as Set | CaseEnclose(SET && LC)
    if(casefold)
       s = caseEnclose(s);
    if(negated)
        s = s.inverted;
    return s;
}

//basic stack, just in case it gets used anywhere else then Parser
@trusted struct Stack(T)
{
    T[] data;
    @property bool empty(){ return data.empty; }

    @property size_t length(){ return data.length; }

    void push(T val){ data ~= val;  }

    T pop()
    {
        assert(!empty);
        auto val = data[$ - 1];
        data = data[0 .. $ - 1];
        if(!__ctfe)
            cast(void)data.assumeSafeAppend();
        return val;
    }

    @property ref T top()
    {
        assert(!empty);
        return data[$ - 1];
    }
}

//safety limits
enum maxGroupNumber = 2^^19;
enum maxLookaroundDepth = 16;
// *Bytecode.sizeof, i.e. 1Mb of bytecode alone
enum maxCompiledLength = 2^^18;
//amounts to up to 4 Mb of auxilary table for matching
enum maxCumulativeRepetitionLength = 2^^20;

struct Parser(R)
    if (isForwardRange!R && is(ElementType!R : dchar))
{
    enum infinite = ~0u;
    dchar _current;
    bool empty;
    R pat, origin;       //keep full pattern for pretty printing error messages
    Bytecode[] ir;       //resulting bytecode
    uint re_flags = 0;   //global flags e.g. multiline + internal ones
    Stack!(uint) fixupStack;  //stack of opened start instructions
    NamedGroup[] dict;   //maps name -> user group number
    //current num of group, group nesting level and repetitions step
    Stack!(uint) groupStack;
    uint nesting = 0;
    uint lookaroundNest = 0;
    uint counterDepth = 0; //current depth of nested counted repetitions
    CodepointSet[] charsets;  //
    const(Trie)[] tries; //
    uint[] backrefed; //bitarray for groups

    @trusted this(S)(R pattern, S flags)
        if(isSomeString!S)
    {
        pat = origin = pattern;
        //reserve slightly more then avg as sampled from unittests
        if(!__ctfe)
            ir.reserve((pat.length*5+2)/4);
        parseFlags(flags);
        _current = ' ';//a safe default for freeform parsing
        next();
        try
        {
            parseRegex();
        }
        catch(Exception e)
        {
            error(e.msg);//also adds pattern location
        }
        put(Bytecode(IR.End, 0));
    }

    //mark referenced groups for latter processing
    void markBackref(uint n)
    {
        if(n/32 >= backrefed.length)
            backrefed.length = n/32 + 1;
        backrefed[n / 32] |= 1 << (n & 31);
    }

    bool isOpenGroup(uint n)
    {
        // walk the fixup stack and see if there are groups labeled 'n'
        // fixup '0' is reserved for alternations
        return fixupStack.data[1..$].
            canFind!(fix => ir[fix].code == IR.GroupStart && ir[fix].data == n)();
    }

    @property dchar current(){ return _current; }

    bool _next()
    {
        if(pat.empty)
        {
            empty =  true;
            return false;
        }
        _current = pat.front;
        pat.popFront();
        return true;
    }

    void skipSpace()
    {
        while(isWhite(current) && _next()){ }
    }

    bool next()
    {
        if(re_flags & RegexOption.freeform)
        {
            bool r = _next();
            skipSpace();
            return r;
        }
        else
            return _next();
    }

    void put(Bytecode code)
    {
        enforce(ir.length < maxCompiledLength,
            "maximum compiled pattern length is exceeded");
        ir ~= code;
    }

    void putRaw(uint number)
    {
        enforce(ir.length < maxCompiledLength,
            "maximum compiled pattern length is exceeded");
        ir ~= Bytecode.fromRaw(number);
    }

    //parsing number with basic overflow check
    uint parseDecimal()
    {
        uint r = 0;
        while(std.ascii.isDigit(current))
        {
            if(r >= (uint.max/10))
                error("Overflow in decimal number");
            r = 10*r + cast(uint)(current-'0');
            if(!next())
                break;
        }
        return r;
    }

    //parse control code of form \cXXX, c assumed to be the current symbol
    dchar parseControlCode()
    {
        enforce(next(), "Unfinished escape sequence");
        enforce(('a' <= current && current <= 'z') || ('A' <= current && current <= 'Z'),
            "Only letters are allowed after \\c");
        return current & 0x1f;
    }

    //
    @trusted void parseFlags(S)(S flags)
    {//@@@BUG@@@ text is @system
        import std.conv;
        foreach(ch; flags)//flags are ASCII anyway
        {
        L_FlagSwitch:
            switch(ch)
            {

                foreach(i, op; __traits(allMembers, RegexOption))
                {
                    case RegexOptionNames[i]:
                            if(re_flags & mixin("RegexOption."~op))
                                throw new RegexException(text("redundant flag specified: ",ch));
                            re_flags |= mixin("RegexOption."~op);
                            break L_FlagSwitch;
                }
                default:
                    throw new RegexException(text("unknown regex flag '",ch,"'"));
            }
        }
    }

    //parse and store IR for regex pattern
    @trusted void parseRegex()
    {
        fixupStack.push(0);
        groupStack.push(1);//0 - whole match
        auto maxCounterDepth = counterDepth;
        uint fix;//fixup pointer

        while(!empty)
        {
            debug(std_regex_parser)
                writeln("*LR*\nSource: ", pat, "\nStack: ",fixupStack.stack.data);
            switch(current)
            {
            case '(':
                next();
                nesting++;
                uint nglob;
                fixupStack.push(cast(uint)ir.length);
                if(current == '?')
                {
                    next();
                    switch(current)
                    {
                    case ':':
                        put(Bytecode(IR.Nop, 0));
                        next();
                        break;
                    case '=':
                        genLookaround(IR.LookaheadStart);
                        next();
                        break;
                    case '!':
                        genLookaround(IR.NeglookaheadStart);
                        next();
                        break;
                    case 'P':
                        next();
                        if(current != '<')
                            error("Expected '<' in named group");
                        string name;
                        if(!next() || !(isAlpha(current) || current == '_'))
                            error("Expected alpha starting a named group");
                        name ~= current;
                        while(next() && (isAlpha(current) ||
                            current == '_' || std.ascii.isDigit(current)))
                        {
                            name ~= current;
                        }
                        if(current != '>')
                            error("Expected '>' closing named group");
                        next();
                        nglob = groupStack.top++;
                        enforce(groupStack.top <= maxGroupNumber, "limit on submatches is exceeded");
                        auto t = NamedGroup(name, nglob);
                        auto d = assumeSorted!"a.name < b.name"(dict);
                        auto ind = d.lowerBound(t).length;
                        insertInPlace(dict, ind, t);
                        put(Bytecode(IR.GroupStart, nglob));
                        break;
                    case '<':
                        next();
                        if(current == '=')
                            genLookaround(IR.LookbehindStart);
                        else if(current == '!')
                            genLookaround(IR.NeglookbehindStart);
                        else
                            error("'!' or '=' expected after '<'");
                        next();
                        break;
                    default:
                        error(" ':', '=', '<', 'P' or '!' expected after '(?' ");
                    }
                }
                else
                {
                    nglob = groupStack.top++;
                    enforce(groupStack.top <= maxGroupNumber, "limit on number of submatches is exceeded");
                    put(Bytecode(IR.GroupStart, nglob));
                }
                break;
            case ')':
                enforce(nesting, "Unmatched ')'");
                nesting--;
                next();
                fix = fixupStack.pop();
                switch(ir[fix].code)
                {
                case IR.GroupStart:
                    put(Bytecode(IR.GroupEnd,ir[fix].data));
                    parseQuantifier(fix);
                    break;
                case IR.LookaheadStart, IR.NeglookaheadStart, IR.LookbehindStart, IR.NeglookbehindStart:
                    assert(lookaroundNest);
                    fixLookaround(fix);
                    lookaroundNest--;
                    break;
                case IR.Option: //| xxx )
                    //two fixups: last option + full OR
                    finishAlternation(fix);
                    fix = fixupStack.top;
                    switch(ir[fix].code)
                    {
                    case IR.GroupStart:
                        fixupStack.pop();
                        put(Bytecode(IR.GroupEnd,ir[fix].data));
                        parseQuantifier(fix);
                        break;
                    case IR.LookaheadStart, IR.NeglookaheadStart, IR.LookbehindStart, IR.NeglookbehindStart:
                        assert(lookaroundNest);
                        lookaroundNest--;
                        fix = fixupStack.pop();
                        fixLookaround(fix);
                        break;
                    default://(?:xxx)
                        fixupStack.pop();
                        parseQuantifier(fix);
                    }
                    break;
                default://(?:xxx)
                    parseQuantifier(fix);
                }
                break;
            case '|':
                next();
                fix = fixupStack.top;
                if(ir.length > fix && ir[fix].code == IR.Option)
                {
                    ir[fix] = Bytecode(ir[fix].code, cast(uint)ir.length - fix);
                    put(Bytecode(IR.GotoEndOr, 0));
                    fixupStack.top = cast(uint)ir.length; //replace latest fixup for Option
                    put(Bytecode(IR.Option, 0));
                    break;
                }
                uint len, orStart;
                //start a new option
                if(fixupStack.length == 1)
                {//only root entry, effectively no fixup
                    len = cast(uint)ir.length + IRL!(IR.GotoEndOr);
                    orStart = 0;
                }
                else
                {//IR.lookahead, etc. fixups that have length > 1, thus check ir[x].length
                    len = cast(uint)ir.length - fix - (ir[fix].length - 1);
                    orStart = fix + ir[fix].length;
                }
                insertInPlace(ir, orStart, Bytecode(IR.OrStart, 0), Bytecode(IR.Option, len));
                assert(ir[orStart].code == IR.OrStart);
                put(Bytecode(IR.GotoEndOr, 0));
                fixupStack.push(orStart); //fixup for StartOR
                fixupStack.push(cast(uint)ir.length); //for second Option
                put(Bytecode(IR.Option, 0));
                break;
            default://no groups or whatever
                uint start = cast(uint)ir.length;
                parseAtom();
                parseQuantifier(start);
            }
        }

        if(fixupStack.length != 1)
        {
            fix = fixupStack.pop();
            enforce(ir[fix].code == IR.Option, "no matching ')'");
            finishAlternation(fix);
            enforce(fixupStack.length == 1, "no matching ')'");
        }
    }

    //helper function, finalizes IR.Option, fix points to the first option of sequence
    void finishAlternation(uint fix)
    {
        enforce(ir[fix].code == IR.Option, "no matching ')'");
        ir[fix] = Bytecode(ir[fix].code, cast(uint)ir.length - fix - IRL!(IR.OrStart));
        fix = fixupStack.pop();
        enforce(ir[fix].code == IR.OrStart, "no matching ')'");
        ir[fix] = Bytecode(IR.OrStart, cast(uint)ir.length - fix - IRL!(IR.OrStart));
        put(Bytecode(IR.OrEnd, cast(uint)ir.length - fix - IRL!(IR.OrStart)));
        uint pc = fix + IRL!(IR.OrStart);
        while(ir[pc].code == IR.Option)
        {
            pc = pc + ir[pc].data;
            if(ir[pc].code != IR.GotoEndOr)
                break;
            ir[pc] = Bytecode(IR.GotoEndOr, cast(uint)(ir.length - pc - IRL!(IR.OrEnd)));
            pc += IRL!(IR.GotoEndOr);
        }
        put(Bytecode.fromRaw(0));
    }

    //parse and store IR for atom-quantifier pair
    @trusted void parseQuantifier(uint offset)
    {//copy is @system
        uint replace = ir[offset].code == IR.Nop;
        if(empty && !replace)
            return;
        uint min, max;
        switch(current)
        {
        case '*':
            min = 0;
            max = infinite;
            break;
        case '?':
            min = 0;
            max = 1;
            break;
        case '+':
            min = 1;
            max = infinite;
            break;
        case '{':
            enforce(next(), "Unexpected end of regex pattern");
            enforce(std.ascii.isDigit(current), "First number required in repetition");
            min = parseDecimal();
            if(current == '}')
                max = min;
            else if(current == ',')
            {
                next();
                if(std.ascii.isDigit(current))
                    max = parseDecimal();
                else if(current == '}')
                    max = infinite;
                else
                    error("Unexpected symbol in regex pattern");
                skipSpace();
                if(current != '}')
                    error("Unmatched '{' in regex pattern");
            }
            else
                error("Unexpected symbol in regex pattern");
            if(min > max)
                error("Illegal {n,m} quantifier");
            break;
        default:
            if(replace)
            {
                copy(ir[offset + 1 .. $], ir[offset .. $ - 1]);
                ir.length -= 1;
            }
            return;
        }
        uint len = cast(uint)ir.length - offset - replace;
        bool greedy = true;
        //check only if we managed to get new symbol
        if(next() && current == '?')
        {
            greedy = false;
            next();
        }
        if(max != infinite)
        {
            if(min != 1 || max != 1)
            {
                Bytecode op = Bytecode(greedy ? IR.RepeatStart : IR.RepeatQStart, len);
                if(replace)
                    ir[offset] = op;
                else
                    insertInPlace(ir, offset, op);
                put(Bytecode(greedy ? IR.RepeatEnd : IR.RepeatQEnd, len));
                put(Bytecode.init); //hotspot
                putRaw(1);
                putRaw(min);
                putRaw(max);
                counterDepth = std.algorithm.max(counterDepth, nesting+1);
            }
        }
        else if(min) //&& max is infinite
        {
            if(min != 1)
            {
                Bytecode op = Bytecode(greedy ? IR.RepeatStart : IR.RepeatQStart, len);
                if(replace)
                    ir[offset] = op;
                else
                    insertInPlace(ir, offset, op);
                offset += 1;//so it still points to the repeated block
                put(Bytecode(greedy ? IR.RepeatEnd : IR.RepeatQEnd, len));
                put(Bytecode.init); //hotspot
                putRaw(1);
                putRaw(min);
                putRaw(min);
                counterDepth = std.algorithm.max(counterDepth, nesting+1);
            }
            else if(replace)
            {
                copy(ir[offset+1 .. $], ir[offset .. $-1]);
                ir.length -= 1;
            }
            put(Bytecode(greedy ? IR.InfiniteStart : IR.InfiniteQStart, len));
            enforce(ir.length + len < maxCompiledLength,  "maximum compiled pattern length is exceeded");
            ir ~= ir[offset .. offset+len];
            //IR.InfinteX is always a hotspot
            put(Bytecode(greedy ? IR.InfiniteEnd : IR.InfiniteQEnd, len));
            put(Bytecode.init); //merge index
        }
        else//vanila {0,inf}
        {
            Bytecode op = Bytecode(greedy ? IR.InfiniteStart : IR.InfiniteQStart, len);
            if(replace)
                ir[offset] = op;
            else
                insertInPlace(ir, offset, op);
            //IR.InfinteX is always a hotspot
            put(Bytecode(greedy ? IR.InfiniteEnd : IR.InfiniteQEnd, len));
            put(Bytecode.init); //merge index

        }
    }

    //parse and store IR for atom
    void parseAtom()
    {
        if(empty)
            return;
        switch(current)
        {
        case '*', '?', '+', '|', '{', '}':
            error("'*', '+', '?', '{', '}' not allowed in atom");
            break;
        case '.':
            put(Bytecode(IR.Any, 0));
            next();
            break;
        case '[':
            parseCharset();
            break;
        case '\\':
            enforce(_next(), "Unfinished escape sequence");
            parseEscape();
            break;
        case '^':
            put(Bytecode(IR.Bol, 0));
            next();
            break;
        case '$':
            put(Bytecode(IR.Eol, 0));
            next();
            break;
        default:
            //FIXME: getCommonCasing in new std uni
            if(re_flags & RegexOption.casefold)
            {
                auto range = simpleCaseFoldings(current);
                assert(range.length <= 5);
                if(range.length == 1)
                    put(Bytecode(IR.Char, range.front));
                else
                    foreach(v; range)
                        put(Bytecode(IR.OrChar, v, cast(uint)range.length));
            }
            else
                put(Bytecode(IR.Char, current));
            next();
        }
    }

    //generate code for start of lookaround: (?= (?! (?<= (?<!
    void genLookaround(IR opcode)
    {
        put(Bytecode(opcode, 0));
        put(Bytecode.fromRaw(0));
        put(Bytecode.fromRaw(0));
        groupStack.push(0);
        lookaroundNest++;
        enforce(lookaroundNest <= maxLookaroundDepth,
            "maximum lookaround depth is exceeded");
    }

    //fixup lookaround with start at offset fix and append a proper *-End opcode
    void fixLookaround(uint fix)
    {
        ir[fix] = Bytecode(ir[fix].code,
            cast(uint)ir.length - fix - IRL!(IR.LookaheadStart));
        auto g = groupStack.pop();
        assert(!groupStack.empty);
        ir[fix+1] = Bytecode.fromRaw(groupStack.top);
        //groups are cumulative across lookarounds
        ir[fix+2] = Bytecode.fromRaw(groupStack.top+g);
        groupStack.top += g;
        if(ir[fix].code == IR.LookbehindStart || ir[fix].code == IR.NeglookbehindStart)
        {
            reverseBytecode(ir[fix + IRL!(IR.LookbehindStart) .. $]);
    }
        put(ir[fix].paired);
    }

    //CodepointSet operations relatively in order of priority
    enum Operator:uint {
        Open = 0, Negate,  Difference, SymDifference, Intersection, Union, None
    }

    //parse unit of CodepointSet spec, most notably escape sequences and char ranges
    //also fetches next set operation
    Tuple!(CodepointSet,Operator) parseCharTerm()
    {
        enum State{ Start, Char, Escape, CharDash, CharDashEscape,
            PotentialTwinSymbolOperator }
        Operator op = Operator.None;
        dchar last;
        CodepointSet set;
        State state = State.Start;

        static void addWithFlags(ref CodepointSet set, uint ch, uint re_flags)
        {
            if(re_flags & RegexOption.casefold)
            {
                auto range = simpleCaseFoldings(ch);
                foreach(v; range)
                    set |= v;
            }
            else
                set |= ch;
        }

        static Operator twinSymbolOperator(dchar symbol)
        {
            switch(symbol)
            {
            case '|':
                return Operator.Union;
            case '-':
                return Operator.Difference;
            case '~':
                return Operator.SymDifference;
            case '&':
                return Operator.Intersection;
            default:
                assert(false);
            }
        }

        L_CharTermLoop:
        for(;;)
        {
            final switch(state)
            {
            case State.Start:
                switch(current)
                {
                case '|':
                case '-':
                case '~':
                case '&':
                    state = State.PotentialTwinSymbolOperator;
                    last = current;
                    break;
                case '[':
                    op = Operator.Union;
                    goto case;
                case ']':
                    break L_CharTermLoop;
                case '\\':
                    state = State.Escape;
                    break;
                default:
                    state = State.Char;
                    last = current;
                }
                break;
            case State.Char:
                // xxx last current xxx
                switch(current)
                {
                case '|':
                case '~':
                case '&':
                    // then last is treated as normal char and added as implicit union
                    state = State.PotentialTwinSymbolOperator;
                    addWithFlags(set, last, re_flags);
                    last = current;
                    break;
                case '-': // still need more info
                    state = State.CharDash;
                    break;
                case '\\':
                    set |= last;
                    state = State.Escape;
                    break;
                case '[':
                    op = Operator.Union;
                    goto case;
                case ']':
                    set |= last;
                    break L_CharTermLoop;
                default:
                    addWithFlags(set, last, re_flags);
                    last = current;
                }
                break;
            case State.PotentialTwinSymbolOperator:
                // xxx last current xxxx
                // where last = [|-&~]
                if(current == last)
                {
                    op = twinSymbolOperator(last);
                    next();//skip second twin char
                    break L_CharTermLoop;
                }
                //~~~WORKAROUND~~~
                //It's a copy of State.Char, should be goto case but see @@@BUG12603
                switch(current)
                {
                case '|':
                case '~':
                case '&':
                    // then last is treated as normal char and added as implicit union
                    state = State.PotentialTwinSymbolOperator;
                    addWithFlags(set, last, re_flags);
                    last = current;
                    break;
                case '-': // still need more info
                    state = State.CharDash;
                    break;
                case '\\':
                    set |= last;
                    state = State.Escape;
                    break;
                case '[':
                    op = Operator.Union;
                    goto case;
                case ']':
                    set |= last;
                    break L_CharTermLoop;
                default:
                    addWithFlags(set, last, re_flags);
                    state = State.Char;
                    last = current;
                }
                break;
                //~~~END OF WORKAROUND~~~
                //goto case State.Char;// it's not a twin lets re-run normal logic
            case State.Escape:
                // xxx \ current xxx
                switch(current)
                {
                case 'f':
                    last = '\f';
                    state = State.Char;
                    break;
                case 'n':
                    last = '\n';
                    state = State.Char;
                    break;
                case 'r':
                    last = '\r';
                    state = State.Char;
                    break;
                case 't':
                    last = '\t';
                    state = State.Char;
                    break;
                case 'v':
                    last = '\v';
                    state = State.Char;
                    break;
                case 'c':
                    last = parseControlCode();
                    state = State.Char;
                    break;
                foreach(val; Escapables)
                {
                case val:
                }
                    last = current;
                    state = State.Char;
                    break;
                case 'p':
                    set.add(parseUnicodePropertySpec(false));
                    state = State.Start;
                    continue L_CharTermLoop; //next char already fetched
                case 'P':
                    set.add(parseUnicodePropertySpec(true));
                    state = State.Start;
                    continue L_CharTermLoop; //next char already fetched
                case 'x':
                    last = parseUniHex(pat, 2);
                    state = State.Char;
                    break;
                case 'u':
                    last = parseUniHex(pat, 4);
                    state = State.Char;
                    break;
                case 'U':
                    last = parseUniHex(pat, 8);
                    state = State.Char;
                    break;
                case 'd':
                    set.add(unicode.Nd);
                    state = State.Start;
                    break;
                case 'D':
                    set.add(unicode.Nd.inverted);
                    state = State.Start;
                    break;
                case 's':
                    set.add(unicode.White_Space);
                    state = State.Start;
                    break;
                case 'S':
                    set.add(unicode.White_Space.inverted);
                    state = State.Start;
                    break;
                case 'w':
                    set.add(wordCharacter);
                    state = State.Start;
                    break;
                case 'W':
                    set.add(wordCharacter.inverted);
                    state = State.Start;
                    break;
                default:
                    enforce(false, "invalid escape sequence");
                }
                break;
            case State.CharDash:
                // xxx last - current xxx
                switch(current)
                {
                case '[':
                    op = Operator.Union;
                    goto case;
                case ']':
                    //means dash is a single char not an interval specifier
                    addWithFlags(set, last, re_flags);
                    addWithFlags(set, '-', re_flags);
                    break L_CharTermLoop;
                 case '-'://set Difference again
                    addWithFlags(set, last, re_flags);
                    op = Operator.Difference;
                    next();//skip '-'
                    break L_CharTermLoop;
                case '\\':
                    state = State.CharDashEscape;
                    break;
                default:
                    enforce(last <= current, "inverted range");
                    if(re_flags & RegexOption.casefold)
                    {
                        for(uint ch = last; ch <= current; ch++)
                            addWithFlags(set, ch, re_flags);
                    }
                    else
                        set.add(last, current + 1);
                    state = State.Start;
                }
                break;
            case State.CharDashEscape:
            //xxx last - \ current xxx
                uint end;
                switch(current)
                {
                case 'f':
                    end = '\f';
                    break;
                case 'n':
                    end = '\n';
                    break;
                case 'r':
                    end = '\r';
                    break;
                case 't':
                    end = '\t';
                    break;
                case 'v':
                    end = '\v';
                    break;
                foreach(val; Escapables)
                {
                case val:
                }
                    end = current;
                    break;
                case 'c':
                    end = parseControlCode();
                    break;
                case 'x':
                    end = parseUniHex(pat, 2);
                    break;
                case 'u':
                    end = parseUniHex(pat, 4);
                    break;
                case 'U':
                    end = parseUniHex(pat, 8);
                    break;
                default:
                    error("invalid escape sequence");
                }
                enforce(last <= end,"inverted range");
                set.add(last, end + 1);
                state = State.Start;
                break;
            }
            enforce(next(), "unexpected end of CodepointSet");
        }
        return tuple(set, op);
    }

    alias ValStack = Stack!(CodepointSet);
    alias OpStack = Stack!(Operator);

    //parse and store IR for CodepointSet
    void parseCharset()
    {
        ValStack vstack;
        OpStack opstack;
        import std.functional : unaryFun;
        //
        static bool apply(Operator op, ref ValStack stack)
        {
            switch(op)
            {
            case Operator.Negate:
                stack.top = stack.top.inverted;
                break;
            case Operator.Union:
                auto s = stack.pop();//2nd operand
                enforce(!stack.empty, "no operand for '||'");
                stack.top.add(s);
                break;
            case Operator.Difference:
                auto s = stack.pop();//2nd operand
                enforce(!stack.empty, "no operand for '--'");
                stack.top.sub(s);
                break;
            case Operator.SymDifference:
                auto s = stack.pop();//2nd operand
                enforce(!stack.empty, "no operand for '~~'");
                stack.top ~= s;
                break;
            case Operator.Intersection:
                auto s = stack.pop();//2nd operand
                enforce(!stack.empty, "no operand for '&&'");
                stack.top.intersect(s);
                break;
            default:
                return false;
            }
            return true;
        }
        static bool unrollWhile(alias cond)(ref ValStack vstack, ref OpStack opstack)
        {
            while(cond(opstack.top))
            {
                if(!apply(opstack.pop(),vstack))
                    return false;//syntax error
                if(opstack.empty)
                    return false;
            }
            return true;
        }

        L_CharsetLoop:
        do
        {
            switch(current)
            {
            case '[':
                opstack.push(Operator.Open);
                enforce(next(), "unexpected end of character class");
                if(current == '^')
                {
                    opstack.push(Operator.Negate);
                    enforce(next(), "unexpected end of character class");
                }
                //[] is prohibited
                enforce(current != ']', "wrong character class");
                goto default;
            case ']':
                enforce(unrollWhile!(unaryFun!"a != a.Open")(vstack, opstack),
                    "character class syntax error");
                enforce(!opstack.empty, "unmatched ']'");
                opstack.pop();
                next();
                if(opstack.empty)
                    break L_CharsetLoop;
                auto pair  = parseCharTerm();
                if(!pair[0].empty)//not only operator e.g. -- or ~~
                {
                    vstack.top.add(pair[0]);//apply union
                }
                if(pair[1] != Operator.None)
                {
                    if(opstack.top == Operator.Union)
                        unrollWhile!(unaryFun!"a == a.Union")(vstack, opstack);
                    opstack.push(pair[1]);
                }
                break;
            //
            default://yet another pair of term(op)?
                auto pair = parseCharTerm();
                if(pair[1] != Operator.None)
                {
                    if(opstack.top == Operator.Union)
                        unrollWhile!(unaryFun!"a == a.Union")(vstack, opstack);
                    opstack.push(pair[1]);
                }
                vstack.push(pair[0]);
            }

        }while(!empty || !opstack.empty);
        while(!opstack.empty)
            apply(opstack.pop(),vstack);
        assert(vstack.length == 1);
        charsetToIr(vstack.top);
    }
    //try to generate optimal IR code for this CodepointSet
    @trusted void charsetToIr(CodepointSet set)
    {//@@@BUG@@@ writeln is @system
        uint chars = cast(uint)set.length;
        if(chars < Bytecode.maxSequence)
        {
            switch(chars)
            {
                case 1:
                    put(Bytecode(IR.Char, set.byCodepoint.front));
                    break;
                case 0:
                    error("empty CodepointSet not allowed");
                    break;
                default:
                    foreach(ch; set.byCodepoint)
                        put(Bytecode(IR.OrChar, ch, chars));
            }
        }
        else
        {
            import std.algorithm : countUntil;
            auto ivals = set.byInterval;
            auto n = charsets.countUntil(set);
            if(n >= 0)
            {
                if(ivals.length*2 > maxCharsetUsed)
                    put(Bytecode(IR.Trie, cast(uint)n));
                else
                    put(Bytecode(IR.CodepointSet, cast(uint)n));
                return;
            }
            if(ivals.length*2 > maxCharsetUsed)
            {
                auto t  = getTrie(set);
                put(Bytecode(IR.Trie, cast(uint)tries.length));
                tries ~= t;
                debug(std_regex_allocation) writeln("Trie generated");
            }
            else
            {
                put(Bytecode(IR.CodepointSet, cast(uint)charsets.length));
                tries ~= Trie.init;
            }
            charsets ~= set;
            assert(charsets.length == tries.length);
        }
    }

    //parse and generate IR for escape stand alone escape sequence
    @trusted void parseEscape()
    {//accesses array of appender

        switch(current)
        {
        case 'f':   next(); put(Bytecode(IR.Char, '\f')); break;
        case 'n':   next(); put(Bytecode(IR.Char, '\n')); break;
        case 'r':   next(); put(Bytecode(IR.Char, '\r')); break;
        case 't':   next(); put(Bytecode(IR.Char, '\t')); break;
        case 'v':   next(); put(Bytecode(IR.Char, '\v')); break;

        case 'd':
            next();
            charsetToIr(unicode.Nd);
            break;
        case 'D':
            next();
            charsetToIr(unicode.Nd.inverted);
            break;
        case 'b':   next(); put(Bytecode(IR.Wordboundary, 0)); break;
        case 'B':   next(); put(Bytecode(IR.Notwordboundary, 0)); break;
        case 's':
            next();
            charsetToIr(unicode.White_Space);
            break;
        case 'S':
            next();
            charsetToIr(unicode.White_Space.inverted);
            break;
        case 'w':
            next();
            charsetToIr(wordCharacter);
            break;
        case 'W':
            next();
            charsetToIr(wordCharacter.inverted);
            break;
        case 'p': case 'P':
            auto CodepointSet = parseUnicodePropertySpec(current == 'P');
            charsetToIr(CodepointSet);
            break;
        case 'x':
            uint code = parseUniHex(pat, 2);
            next();
            put(Bytecode(IR.Char,code));
            break;
        case 'u': case 'U':
            uint code = parseUniHex(pat, current == 'u' ? 4 : 8);
            next();
            put(Bytecode(IR.Char, code));
            break;
        case 'c': //control codes
            Bytecode code = Bytecode(IR.Char, parseControlCode());
            next();
            put(code);
            break;
        case '0':
            next();
            put(Bytecode(IR.Char, 0));//NUL character
            break;
        case '1': .. case '9':
            uint nref = cast(uint)current - '0';
            uint maxBackref = sum(groupStack.data);
            enforce(nref < maxBackref, "Backref to unseen group");
            //perl's disambiguation rule i.e.
            //get next digit only if there is such group number
            while(nref < maxBackref && next() && std.ascii.isDigit(current))
            {
                nref = nref * 10 + current - '0';
            }
            if(nref >= maxBackref)
                nref /= 10;
            enforce(!isOpenGroup(nref), "Backref to open group");
            uint localLimit = maxBackref - groupStack.top;
            if(nref >= localLimit)
            {
                put(Bytecode(IR.Backref, nref-localLimit));
                ir[$-1].setLocalRef();
            }
            else
                put(Bytecode(IR.Backref, nref));
            markBackref(nref);
            break;
        default:
            auto op = Bytecode(IR.Char, current);
            next();
            put(op);
        }
    }

    //parse and return a CodepointSet for \p{...Property...} and \P{...Property..},
    //\ - assumed to be processed, p - is current
    CodepointSet parseUnicodePropertySpec(bool negated)
    {
        enum MAX_PROPERTY = 128;
        char[MAX_PROPERTY] result;
        uint k = 0;
        enforce(next());
        if(current == '{')
        {
            while(k < MAX_PROPERTY && next() && current !='}' && current !=':')
                if(current != '-' && current != ' ' && current != '_')
                    result[k++] = cast(char)std.ascii.toLower(current);
            enforce(k != MAX_PROPERTY, "invalid property name");
            enforce(current == '}', "} expected ");
        }
        else
        {//single char properties e.g.: \pL, \pN ...
            enforce(current < 0x80, "invalid property name");
            result[k++] = cast(char)current;
        }
        auto s = getUnicodeSet(result[0..k], negated,
            cast(bool)(re_flags & RegexOption.casefold));
        enforce(!s.empty, "unrecognized unicode property spec");
        next();
        return s;
    }

    //
    @trusted void error(string msg)
    {
        import std.format;
        auto app = appender!string();
        ir = null;
        formattedWrite(app, "%s\nPattern with error: `%s` <--HERE-- `%s`",
                       msg, origin[0..$-pat.length], pat);
        throw new RegexException(app.data);
    }

    alias Char = BasicElementOf!R;

    @property program()
    {
        return makeRegex(this);
    }
}

/+
    lightweight post process step,
    only essentials
+/
@trusted void lightPostprocess(Char)(ref Regex!Char zis)
{//@@@BUG@@@ write is @system
    with(zis)
    {
        struct FixedStack(T)
        {
            T[] arr;
            uint _top;
            //this(T[] storage){   arr = storage; _top = -1; }
            @property ref T top(){  assert(!empty); return arr[_top]; }
            void push(T x){  arr[++_top] = x; }
            T pop() { assert(!empty);   return arr[_top--]; }
            @property bool empty(){   return _top == -1; }
        }
        auto counterRange = FixedStack!uint(new uint[maxCounterDepth+1], -1);
        counterRange.push(1);
        ulong cumRange = 0;
        for(uint i = 0; i < ir.length; i += ir[i].length)
        {
            if(ir[i].hotspot)
            {
                assert(i + 1 < ir.length,
                    "unexpected end of IR while looking for hotspot");
                ir[i+1] = Bytecode.fromRaw(hotspotTableSize);
                hotspotTableSize += counterRange.top;
            }
            switch(ir[i].code)
            {
            case IR.RepeatStart, IR.RepeatQStart:
                uint repEnd = cast(uint)(i + ir[i].data + IRL!(IR.RepeatStart));
                assert(ir[repEnd].code == ir[i].paired.code);
                uint max = ir[repEnd + 4].raw;
                ir[repEnd+2].raw = counterRange.top;
                ir[repEnd+3].raw *= counterRange.top;
                ir[repEnd+4].raw *= counterRange.top;
                ulong cntRange = cast(ulong)(max)*counterRange.top;
                cumRange += cntRange;
                enforce(cumRange < maxCumulativeRepetitionLength,
                    "repetition length limit is exceeded");
                counterRange.push(cast(uint)cntRange + counterRange.top);
                threadCount += counterRange.top;
                break;
            case IR.RepeatEnd, IR.RepeatQEnd:
                threadCount += counterRange.top;
                counterRange.pop();
                break;
            case IR.GroupStart:
                if(isBackref(ir[i].data))
                    ir[i].setBackrefence();
                threadCount += counterRange.top;
                break;
            case IR.GroupEnd:
                if(isBackref(ir[i].data))
                    ir[i].setBackrefence();
                threadCount += counterRange.top;
                break;
            default:
                threadCount += counterRange.top;
            }
        }
        checkIfOneShot();
        if(!(flags & RegexInfo.oneShot))
            kickstart = Kickstart!Char(zis, new uint[](256));
        debug(std_regex_allocation) writefln("IR processed, max threads: %d", threadCount);
    }
}

//IR code validator - proper nesting, illegal instructions, etc.
@trusted void validateRe(Char)(ref Regex!Char zis)
{//@@@BUG@@@ text is @system
    import std.conv;
    with(zis)
    {
        for(uint pc = 0; pc < ir.length; pc += ir[pc].length)
        {
            if(ir[pc].isStart || ir[pc].isEnd)
            {
                uint dest = ir[pc].indexOfPair(pc);
                assert(dest < ir.length, text("Wrong length in opcode at pc=",
                    pc, " ", dest, " vs ", ir.length));
                assert(ir[dest].paired ==  ir[pc],
                    text("Wrong pairing of opcodes at pc=", pc, "and pc=", dest));
            }
            else if(ir[pc].isAtom)
            {

            }
            else
               assert(0, text("Unknown type of instruction at pc=", pc));
        }
    }
}
