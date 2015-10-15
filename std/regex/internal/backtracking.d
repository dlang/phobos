/*
    Implementation of backtracking std.regex engine.
    Contains both compile-time and run-time versions.
*/
module std.regex.internal.backtracking;

package(std.regex):

import std.regex.internal.ir;
import std.range, std.typecons, std.traits, core.stdc.stdlib;

/+
    BacktrackingMatcher implements backtracking scheme of matching
    regular expressions.
+/
template BacktrackingMatcher(bool CTregex)
{
    @trusted struct BacktrackingMatcher(Char, Stream = Input!Char)
        if(is(Char : dchar))
    {
        alias DataIndex = Stream.DataIndex;
        struct State
        {//top bit in pc is set if saved along with matches
            DataIndex index;
            uint pc, counter, infiniteNesting;
        }
        static assert(State.sizeof % size_t.sizeof == 0);
        enum stateSize = State.sizeof / size_t.sizeof;
        enum initialStack = 1<<11; // items in a block of segmented stack
        alias String = const(Char)[];
        alias RegEx = Regex!Char;
        alias MatchFn = bool function (ref BacktrackingMatcher!(Char, Stream));
        RegEx re;      //regex program
        static if(CTregex)
            MatchFn nativeFn; //native code for that program
        //Stream state
        Stream s;
        bool exhausted;
        //backtracking machine state
        uint pc, counter;
        DataIndex lastState = 0;    //top of state stack
        DataIndex[] trackers;
        static if(!CTregex)
            uint infiniteNesting;
        size_t[] memory;
        //local slice of matches, global for backref
        Group!DataIndex[] matches, backrefed;

        static if(__traits(hasMember,Stream, "search"))
        {
            enum kicked = true;
        }
        else
            enum kicked = false;

        static size_t initialMemory(const ref RegEx re)
        {
            return (re.ngroup+1)*DataIndex.sizeof //trackers
                + stackSize(re)*size_t.sizeof;
        }

        static size_t stackSize(const ref RegEx re)
        {
            return initialStack*(stateSize + re.ngroup*(Group!DataIndex).sizeof/size_t.sizeof)+1;
        }

        @property bool atStart(){ return s._index == 0; }

        @property bool atEnd(){ return s.atEnd; }

        void search()
        {
            static if(kicked)
                s._index = re.kickstart.search(s._origin, s._index);
            else
                s.skipChar();
        }

        //
        void newStack()
        {
            auto chunk = mallocArray!(size_t)(stackSize(re));
            chunk[0] = cast(size_t)(memory.ptr);
            memory = chunk[1..$];
        }

        void initExternalMemory(void[] memBlock)
        {
            trackers = arrayInChunk!(DataIndex)(re.ngroup+1, memBlock);
            memory = cast(size_t[])memBlock;
            memory[0] = 0; //hidden pointer
            memory = memory[1..$];
        }

        void initialize(ref RegEx program, Stream stream, void[] memBlock)
        {
            re = program;
            s = stream;
            exhausted = false;
            initExternalMemory(memBlock);
            backrefed = null;
        }

        auto dupTo(void[] memory)
        {
            typeof(this) tmp = this;
            tmp.initExternalMemory(memory);
            return tmp;
        }

        this(ref RegEx program, Stream stream, void[] memBlock)
        {
            initialize(program, stream, memBlock);
        }

        auto fwdMatcher(ref BacktrackingMatcher matcher, void[] memBlock)
        {
            alias BackMatcherTempl = .BacktrackingMatcher!(CTregex);
            alias BackMatcher = BackMatcherTempl!(Char, Stream);
            auto fwdMatcher = BackMatcher(matcher.re, s, memBlock);
            return fwdMatcher;
        }

        auto bwdMatcher(ref BacktrackingMatcher matcher, void[] memBlock)
        {
            alias BackMatcherTempl = .BacktrackingMatcher!(CTregex);
            alias BackMatcher = BackMatcherTempl!(Char, typeof(s.loopBack(s._index)));
            auto fwdMatcher =
                BackMatcher(matcher.re, s.loopBack(s._index), memBlock);
            return fwdMatcher;
        }

        //
        bool matchFinalize()
        {
            size_t start = s._index;
            if(matchImpl())
            {//stream is updated here
                matches[0].begin = start;
                matches[0].end = s._index;
                if(!(re.flags & RegexOption.global) || atEnd)
                    exhausted = true;
                if(start == s._index && !s.atEnd)//empty match advances input
                    s.skipChar();
                return true;
            }
            else
                return false;
        }

        //lookup next match, fill matches with indices into input
        bool match(Group!DataIndex[] matches)
        {
            debug(std_regex_matcher)
            {
                writeln("------------------------------------------");
            }
            if(exhausted) //all matches collected
                return false;
            this.matches = matches;
            if(re.flags & RegexInfo.oneShot)
            {
                exhausted = true;
                DataIndex start = s._index;
                auto m = matchImpl();
                if(m)
                {
                    matches[0].begin = start;
                    matches[0].end = s._index;
                }
                return m;
            }
            static if(kicked)
            {
                if(!re.kickstart.empty)
                {
                    for(;;)
                    {
                        search();
                        if(atEnd) // non-empty kickstart => no match at end of input
                            break;
                        if(matchFinalize())
                            return true;
                        s.skipChar();
                    }
                }
            }
            //no search available - skip a char at a time
            for(;;)
            {
                if(matchFinalize())
                    return true;
                else
                {
                    if(atEnd)
                        break;
                    s.skipChar();
                    if(atEnd)
                    {
                        exhausted = true;
                        return matchFinalize();
                    }
                }
            }
            exhausted = true;
            return false;
        }

        /+
            match subexpression against input,
            results are stored in matches
        +/
        bool matchImpl()
        {
            static if(CTregex && is(typeof(nativeFn(this))))
            {
                debug(std_regex_ctr) writeln("using C-T matcher");
                return nativeFn(this);
            }
            else
            {
                pc = 0;
                counter = 0;
                lastState = 0;
                infiniteNesting = -1;//intentional
                auto start = s._index;
                debug(std_regex_matcher)
                    writeln("Try match starting at ", s.slice(s._index, s.lastIndex),
                         is(typeof(s) == Input!Char) ? " " : " backwards");
                for(;;)
                {
                    debug(std_regex_matcher)
                        writefln("PC: %s\tCNT: %s\t%s \t src: %s",
                            pc, counter, disassemble(re.ir, pc, re.dict),
                            s.slice(s._index, s.lastIndex));
                    switch(re.ir[pc].code)
                    {
                    case IR.OrChar://assumes IRL!(OrChar) == 1
                        if(atEnd)
                            goto L_backtrack;
                        uint len = re.ir[pc].sequence;
                        uint end = pc + len;
                        if(!s.matchDChar(re.ir[pc].data) && !s.matchDChar(re.ir[pc+1].data))
                        {
                            for(pc = pc+2; pc < end; pc++)
                                if(s.matchDChar(re.ir[pc].data))
                                    break;
                            if(pc == end)
                                goto L_backtrack;
                        }
                        pc = end;
                        break;
                    case IR.Char:
                        if(atEnd || !s.matchDChar(re.ir[pc].data))
                            goto L_backtrack;
                        pc += IRL!(IR.Char);
                    break;
                    case IR.Any:
                        if(atEnd || (!(re.flags & RegexOption.singleline)
                                && (s.front == '\r' || s.front == '\n')))
                            goto L_backtrack;
                        s.skipChar();
                        pc += IRL!(IR.Any);
                        break;
                    case IR.CodepointSet:
                    case IR.Trie:
                        if(atEnd || !s.matchClass(re.matchers[re.ir[pc].data]))
                            goto L_backtrack;
                        pc += IRL!(IR.Trie);
                        break;
                    case IR.Wordboundary:
                        //at start & end of input
                        if(atStart)
                        {
                            if(!atEnd && !s.testWordClass())
                                goto L_backtrack;
                        }
                        else if(atEnd)
                        {
                            if(!s.loopBack(s._index).testWordClass())
                                goto L_backtrack;
                        }
                        else
                        {
                            bool af = s.testWordClass();
                            bool ab = s.loopBack(s._index).testWordClass();
                            if((af ^ ab) == false)
                                goto L_backtrack;
                        }
                        pc += IRL!(IR.Wordboundary);
                        break;
                    case IR.Notwordboundary:
                        //at start & end of input
                        if(atStart)
                        {
                            if(atEnd || s.testWordClass())
                                goto L_backtrack;
                        }
                        else if(atEnd)
                        {
                            if(s.loopBack(s._index).testWordClass())
                                goto L_backtrack;
                        }
                        else
                        {
                            bool af = s.testWordClass();
                            bool ab = s.loopBack(s._index).testWordClass();
                            if((af ^ ab) == true)
                                goto L_backtrack;
                        }
                        pc += IRL!(IR.Wordboundary);
                        break;
                    case IR.Bol:
                        if(atStart)
                        {
                            pc += IRL!(IR.Bol);
                            break;
                        }
                        else if(re.flags & RegexOption.multiline)
                        {
                            bool seenNl = !atEnd && s.front == '\n';
                            if(startOfLine(s.loopBack(s._index), seenNl))
                            {
                                pc += IRL!(IR.Eol);
                                break;
                            }
                        }
                        goto L_backtrack;
                    case IR.Eol:
                        //no matching inside \r\n
                        if(atEnd)
                        {
                            pc += IRL!(IR.Eol);
                            break;
                        }
                        else if(re.flags & RegexOption.multiline)
                        {
                            bool seenCr = !atStart && s.loopBack(s._index).front == '\r';
                            if(endOfLine(s, seenCr))
                            {
                                pc += IRL!(IR.Eol);
                                break;
                            }
                        }
                        goto L_backtrack;
                    case IR.InfiniteStart, IR.InfiniteQStart:
                        trackers[infiniteNesting+1] = s._index;
                        pc += re.ir[pc].data + IRL!(IR.InfiniteStart);
                        //now pc is at end IR.Infininite(Q)End
                        uint len = re.ir[pc].data;
                        int test;
                        if(re.ir[pc].code == IR.InfiniteEnd)
                        {
                            test = quickTestNonDec(pc+IRL!(IR.InfiniteEnd), s, re);
                            if(test >= 0)
                                pushState(pc+IRL!(IR.InfiniteEnd), counter);
                            infiniteNesting++;
                            pc -= len;
                        }
                        else
                        {
                            test = quickTestNonDec(pc - len, s, re);
                            if(test >= 0)
                            {
                                infiniteNesting++;
                                pushState(pc - len, counter);
                                infiniteNesting--;
                            }
                            pc += IRL!(IR.InfiniteEnd);
                        }
                        break;
                    case IR.RepeatStart, IR.RepeatQStart:
                        pc += re.ir[pc].data + IRL!(IR.RepeatStart);
                        break;
                    case IR.RepeatEnd:
                    case IR.RepeatQEnd:
                        //len, step, min, max
                        uint len = re.ir[pc].data;
                        uint step =  re.ir[pc+2].raw;
                        uint min = re.ir[pc+3].raw;
                        uint max = re.ir[pc+4].raw;
                        if(counter < min)
                        {
                            counter += step;
                            pc -= len;
                        }
                        else if(counter < max)
                        {
                            if(re.ir[pc].code == IR.RepeatEnd)
                            {
                                pushState(pc + IRL!(IR.RepeatEnd), counter%step);
                                counter += step;
                                pc -= len;
                            }
                            else
                            {
                                pushState(pc - len, counter + step);
                                counter = counter%step;
                                pc += IRL!(IR.RepeatEnd);
                            }
                        }
                        else
                        {
                            counter = counter%step;
                            pc += IRL!(IR.RepeatEnd);
                        }
                        break;
                    case IR.InfiniteEnd:
                    case IR.InfiniteQEnd:
                        uint len = re.ir[pc].data;
                        debug(std_regex_matcher) writeln("Infinited nesting:", infiniteNesting);
                        assert(infiniteNesting < trackers.length);

                        if(trackers[infiniteNesting] == s._index)
                        {//source not consumed
                            pc += IRL!(IR.InfiniteEnd);
                            infiniteNesting--;
                            break;
                        }
                        else
                            trackers[infiniteNesting] = s._index;
                        int test;
                        if(re.ir[pc].code == IR.InfiniteEnd)
                        {
                            test = quickTestNonDec(pc+IRL!(IR.InfiniteEnd), s, re);
                            if(test >= 0)
                            {
                                infiniteNesting--;
                                pushState(pc + IRL!(IR.InfiniteEnd), counter);
                                infiniteNesting++;
                            }
                            pc -= len;
                        }
                        else
                        {
                            test = quickTestNonDec(pc-len, s, re);
                            if(test >= 0)
                                pushState(pc-len, counter);
                            pc += IRL!(IR.InfiniteEnd);
                            infiniteNesting--;
                        }
                        break;
                    case IR.OrEnd:
                        pc += IRL!(IR.OrEnd);
                        break;
                    case IR.OrStart:
                        pc += IRL!(IR.OrStart);
                        goto case;
                    case IR.Option:
                        uint len = re.ir[pc].data;
                        if(re.ir[pc+len].code == IR.GotoEndOr)//not a last one
                        {
                            pushState(pc + len + IRL!(IR.Option), counter); //remember 2nd branch
                        }
                        pc += IRL!(IR.Option);
                        break;
                    case IR.GotoEndOr:
                        pc = pc + re.ir[pc].data + IRL!(IR.GotoEndOr);
                        break;
                    case IR.GroupStart:
                        uint n = re.ir[pc].data;
                        matches[n].begin = s._index;
                        debug(std_regex_matcher)  writefln("IR group #%u starts at %u", n, s._index);
                        pc += IRL!(IR.GroupStart);
                        break;
                    case IR.GroupEnd:
                        uint n = re.ir[pc].data;
                        matches[n].end = s._index;
                        debug(std_regex_matcher) writefln("IR group #%u ends at %u", n, s._index);
                        pc += IRL!(IR.GroupEnd);
                        break;
                    case IR.LookaheadStart:
                    case IR.NeglookaheadStart:
                        uint len = re.ir[pc].data;
                        auto save = s._index;
                        uint ms = re.ir[pc+1].raw, me = re.ir[pc+2].raw;
                        auto mem = malloc(initialMemory(re))[0..initialMemory(re)];
                        scope(exit) free(mem.ptr);
                        static if(Stream.isLoopback)
                        {
                            auto matcher = bwdMatcher(this, mem);
                        }
                        else
                        {
                            auto matcher = fwdMatcher(this, mem);
                        }
                        matcher.matches = matches[ms .. me];
                        matcher.backrefed = backrefed.empty ? matches : backrefed;
                        matcher.re.ir = re.ir[pc+IRL!(IR.LookaheadStart) .. pc+IRL!(IR.LookaheadStart)+len+IRL!(IR.LookaheadEnd)];
                        bool match = matcher.matchImpl() ^ (re.ir[pc].code == IR.NeglookaheadStart);
                        s._index = save;
                        if(!match)
                            goto L_backtrack;
                        else
                        {
                            pc += IRL!(IR.LookaheadStart)+len+IRL!(IR.LookaheadEnd);
                        }
                        break;
                    case IR.LookbehindStart:
                    case IR.NeglookbehindStart:
                        uint len = re.ir[pc].data;
                        uint ms = re.ir[pc+1].raw, me = re.ir[pc+2].raw;
                        auto mem = malloc(initialMemory(re))[0..initialMemory(re)];
                        scope(exit) free(mem.ptr);
                        static if(Stream.isLoopback)
                        {
                            alias Matcher = BacktrackingMatcher!(Char, Stream);
                            auto matcher = Matcher(re, s, mem);
                        }
                        else
                        {
                            alias Matcher = BacktrackingMatcher!(Char, typeof(s.loopBack(s._index)));
                            auto matcher = Matcher(re, s.loopBack(s._index), mem);
                        }
                        matcher.matches = matches[ms .. me];
                        matcher.re.ir = re.ir[pc + IRL!(IR.LookbehindStart) .. pc + IRL!(IR.LookbehindStart) + len + IRL!(IR.LookbehindEnd)];
                        matcher.backrefed  = backrefed.empty ? matches : backrefed;
                        bool match = matcher.matchImpl() ^ (re.ir[pc].code == IR.NeglookbehindStart);
                        if(!match)
                            goto L_backtrack;
                        else
                        {
                            pc += IRL!(IR.LookbehindStart)+len+IRL!(IR.LookbehindEnd);
                        }
                        break;
                    case IR.Backref:
                        uint n = re.ir[pc].data;
                        auto referenced = re.ir[pc].localRef
                                ? s.slice(matches[n].begin, matches[n].end)
                                : s.slice(backrefed[n].begin, backrefed[n].end);
                        import std.string, std.algorithm;
                        static if(Stream.isLoopback)
                        {
                            import std.range;
                            if(skipOver(s, referenced.representation.retro))
                                pc++;
                            else
                                goto L_backtrack;
                        }
                        else
                        {
                            if(skipOver(s, referenced.representation))
                                pc++;
                            else
                                goto L_backtrack;
                        }
                        break;
                    case IR.Nop:
                        pc += IRL!(IR.Nop);
                        break;
                    case IR.LookaheadEnd:
                    case IR.NeglookaheadEnd:
                    case IR.LookbehindEnd:
                    case IR.NeglookbehindEnd:
                    case IR.End:
                        return true;
                    default:
                        debug printBytecode(re.ir[0..$]);
                        assert(0);
                    L_backtrack:
                        if(!popState())
                        {
                            s.reset(start);
                            return false;
                        }
                    }
                }
            }
            assert(0);
        }

        @property size_t stackAvail()
        {
            return memory.length - lastState;
        }

        bool prevStack()
        {
            import core.stdc.stdlib;
            size_t* prev = memory.ptr-1;
            prev = cast(size_t*)*prev;//take out hidden pointer
            if(!prev)
                return false;
            free(memory.ptr);//last segment is freed in RegexMatch
            immutable size = initialStack*(stateSize + 2*re.ngroup);
            memory = prev[0..size];
            lastState = size;
            return true;
        }

        void stackPush(T)(T val)
            if(!isDynamicArray!T)
        {
            *cast(T*)&memory[lastState] = val;
            enum delta = (T.sizeof+size_t.sizeof/2)/size_t.sizeof;
            lastState += delta;
            debug(std_regex_matcher) writeln("push element SP= ", lastState);
        }

        void stackPush(T)(T[] val)
        {
            static assert(T.sizeof % size_t.sizeof == 0);
            (cast(T*)&memory[lastState])[0..val.length]
                = val[0..$];
            lastState += val.length*(T.sizeof/size_t.sizeof);
            debug(std_regex_matcher) writeln("push array SP= ", lastState);
        }

        void stackPop(T)(ref T val)
            if(!isDynamicArray!T)
        {
            enum delta = (T.sizeof+size_t.sizeof/2)/size_t.sizeof;
            lastState -= delta;
            val = *cast(T*)&memory[lastState];
            debug(std_regex_matcher) writeln("pop element SP= ", lastState);
        }

        void stackPop(T)(T[] val)
        {
            stackPop(val);  // call ref version
        }
        void stackPop(T)(ref T[] val)
        {
            lastState -= val.length*(T.sizeof/size_t.sizeof);
            val[0..$] = (cast(T*)&memory[lastState])[0..val.length];
            debug(std_regex_matcher) writeln("pop array SP= ", lastState);
        }

        static if(!CTregex)
        {
            //helper function, saves engine state
            void pushState(uint pc, uint counter)
            {
                if(stateSize + trackers.length + matches.length > stackAvail)
                {
                    newStack();
                    lastState = 0;
                }
                *cast(State*)&memory[lastState] =
                    State(s._index, pc, counter, infiniteNesting);
                lastState += stateSize;
                memory[lastState .. lastState + 2 * matches.length] = (cast(size_t[])matches)[];
                lastState += 2*matches.length;
                if(trackers.length)
                {
                    memory[lastState .. lastState + trackers.length] = trackers[];
                    lastState += trackers.length;
                }
                debug(std_regex_matcher)
                    writefln("Saved(pc=%s) src: %s",
                        pc,  s.slice(s._index, s.lastIndex));
            }

            //helper function, restores engine state
            bool popState()
            {
                if(!lastState)
                    return prevStack();
                if (trackers.length)
                {
                    lastState -= trackers.length;
                    trackers[] = memory[lastState .. lastState + trackers.length];
                }
                lastState -= 2*matches.length;
                auto pm = cast(size_t[])matches;
                pm[] = memory[lastState .. lastState + 2 * matches.length];
                lastState -= stateSize;
                State* state = cast(State*)&memory[lastState];
                s._index = state.index;
                pc = state.pc;
                counter = state.counter;
                infiniteNesting = state.infiniteNesting;
                debug(std_regex_matcher)
                {
                    writefln("Restored matches", s.slice(s._index, s.lastIndex));
                    foreach(i, m; matches)
                        writefln("Sub(%d) : %s..%s", i, m.begin, m.end);
                }
                debug(std_regex_matcher)
                    writefln("Backtracked (pc=%s) src: %s",
                        pc, s.slice(s._index, s.lastIndex));
                return true;
            }
        }
    }
}

//very shitty string formatter, $$ replaced with next argument converted to string
@trusted string ctSub( U...)(string format, U args)
{
    import std.conv;
    bool seenDollar;
    foreach(i, ch; format)
    {
        if(ch == '$')
        {
            if(seenDollar)
            {
                static if(args.length > 0)
                {
                    return  format[0 .. i - 1] ~ to!string(args[0])
                        ~ ctSub(format[i + 1 .. $], args[1 .. $]);
                }
                else
                    assert(0);
            }
            else
                seenDollar = true;
        }
        else
            seenDollar = false;

    }
    return format;
}

alias Sequence(int B, int E) = staticIota!(B, E);

struct CtContext
{
    import std.conv;
    //dirty flags
    bool counter, infNesting;
    // to make a unique advancement counter per nesting level of loops
    int curInfLoop, nInfLoops;
    //to mark the portion of matches to save
    int match, total_matches;
    int reserved;


    //state of codegenerator
    struct CtState
    {
        string code;
        int addr;
    }

    this(Char)(Regex!Char re)
    {
        match = 1;
        reserved = 1; //first match is skipped
        total_matches = re.ngroup;
    }

    CtContext lookaround(uint s, uint e)
    {
        CtContext ct;
        ct.total_matches = e - s;
        ct.match = 1;
        return ct;
    }

    //restore state having current context
    string restoreCode()
    {
        string text;
        //stack is checked in L_backtrack
        text ~= counter
            ? "
                    stackPop(counter);"
            : "
                    counter = 0;";
        if(infNesting)
        {
            text ~= ctSub(`
                    stackPop(trackers[0..$$]);
                    `, curInfLoop + 1);
        }
        if(match < total_matches)
        {
            text ~= ctSub("
                    stackPop(matches[$$..$$]);", reserved, match);
            text ~= ctSub("
                    matches[$$..$] = typeof(matches[0]).init;", match);
        }
        else
            text ~= ctSub("
                    stackPop(matches[$$..$]);", reserved);
        return text;
    }

    //save state having current context
    string saveCode(uint pc, string count_expr="counter")
    {
        string text = ctSub("
                    if(stackAvail < $$*(Group!(DataIndex)).sizeof/size_t.sizeof + trackers.length + $$)
                    {
                        newStack();
                        lastState = 0;
                    }", match - reserved, cast(int)counter + 2);
        if(match < total_matches)
            text ~= ctSub("
                    stackPush(matches[$$..$$]);", reserved, match);
        else
            text ~= ctSub("
                    stackPush(matches[$$..$]);", reserved);
        if(infNesting)
        {
            text ~= ctSub(`
                    stackPush(trackers[0..$$]);
                    `, curInfLoop + 1);
        }
        text ~= counter ? ctSub("
                    stackPush($$);", count_expr) : "";
        text ~= ctSub("
                    stackPush(s._index); stackPush($$); \n", pc);
        return text;
    }

    //
    CtState ctGenBlock(Bytecode[] ir, int addr)
    {
        CtState result;
        result.addr = addr;
        while(!ir.empty)
        {
            auto n = ctGenGroup(ir, result.addr);
            result.code ~= n.code;
            result.addr = n.addr;
        }
        return result;
    }

    //
    CtState ctGenGroup(ref Bytecode[] ir, int addr)
    {
        import std.algorithm : max;
        auto bailOut = "goto L_backtrack;";
        auto nextInstr = ctSub("goto case $$;", addr+1);
        CtState r;
        assert(!ir.empty);
        switch(ir[0].code)
        {
        case IR.InfiniteStart, IR.InfiniteQStart, IR.RepeatStart, IR.RepeatQStart:
            bool infLoop =
                ir[0].code == IR.InfiniteStart || ir[0].code == IR.InfiniteQStart;
            infNesting = infNesting || infLoop;
            if(infLoop)
            {
                curInfLoop++;
                nInfLoops = max(nInfLoops, curInfLoop+1);
            }
            counter = counter ||
                ir[0].code == IR.RepeatStart || ir[0].code == IR.RepeatQStart;
            uint len = ir[0].data;
            auto nir = ir[ir[0].length .. ir[0].length+len];
            r = ctGenBlock(nir, addr+1);
            if(infLoop)
                curInfLoop--;
            //start/end codegen
            //r.addr is at last test+ jump of loop, addr+1 is body of loop
            nir = ir[ir[0].length + len .. $];
            r.code = ctGenFixupCode(ir[0..ir[0].length], addr, r.addr) ~ r.code;
            r.code ~= ctGenFixupCode(nir, r.addr, addr+1);
            r.addr += 2;   //account end instruction + restore state
            ir = nir;
            break;
        case IR.OrStart:
            uint len = ir[0].data;
            auto nir = ir[ir[0].length .. ir[0].length+len];
            r = ctGenAlternation(nir, addr);
            ir = ir[ir[0].length + len .. $];
            assert(ir[0].code == IR.OrEnd);
            ir = ir[ir[0].length..$];
            break;
        case IR.LookaheadStart:
        case IR.NeglookaheadStart:
        case IR.LookbehindStart:
        case IR.NeglookbehindStart:
            uint len = ir[0].data;
            bool behind = ir[0].code == IR.LookbehindStart || ir[0].code == IR.NeglookbehindStart;
            bool negative = ir[0].code == IR.NeglookaheadStart || ir[0].code == IR.NeglookbehindStart;
            string fwdType = "typeof(fwdMatcher(matcher, []))";
            string bwdType = "typeof(bwdMatcher(matcher, []))";
            string fwdCreate = "fwdMatcher(matcher, mem)";
            string bwdCreate = "bwdMatcher(matcher, mem)";
            uint start = IRL!(IR.LookbehindStart);
            uint end = IRL!(IR.LookbehindStart)+len+IRL!(IR.LookaheadEnd);
            CtContext context = lookaround(ir[1].raw, ir[2].raw); //split off new context
            auto slice = ir[start .. end];
            r.code ~= ctSub(`
            case $$: //fake lookaround "atom"
                    static if(typeof(matcher.s).isLoopback)
                        alias Lookaround = $$;
                    else
                        alias Lookaround = $$;
                    static bool matcher_$$(ref Lookaround matcher) @trusted
                    {
                        //(neg)lookaround piece start
                        $$
                        //(neg)lookaround piece ends
                    }
                    auto save = s._index;
                    auto mem = malloc(initialMemory(re))[0..initialMemory(re)];
                    scope(exit) free(mem.ptr);
                    static if(typeof(matcher.s).isLoopback)
                        auto lookaround = $$;
                    else
                        auto lookaround = $$;
                    lookaround.matches = matches[$$..$$];
                    lookaround.backrefed = backrefed.empty ? matches : backrefed;
                    lookaround.nativeFn = &matcher_$$; //hookup closure's binary code
                    bool match = $$;
                    s._index = save;
                    if(match)
                        $$
                    else
                        $$`, addr,
                        behind ? fwdType : bwdType, behind ? bwdType : fwdType,
                        addr, context.ctGenRegEx(slice),
                        behind ? fwdCreate : bwdCreate, behind ? bwdCreate : fwdCreate,
                        ir[1].raw, ir[2].raw, //start - end of matches slice
                        addr,
                        negative ? "!lookaround.matchImpl()" : "lookaround.matchImpl()",
                        nextInstr, bailOut);
            ir = ir[end .. $];
            r.addr = addr + 1;
            break;
        case IR.LookaheadEnd: case IR.NeglookaheadEnd:
        case IR.LookbehindEnd: case IR.NeglookbehindEnd:
            ir = ir[IRL!(IR.LookaheadEnd) .. $];
            r.addr = addr;
            break;
        default:
            assert(ir[0].isAtom,  text(ir[0].mnemonic));
            r = ctGenAtom(ir, addr);
        }
        return r;
    }

    //generate source for bytecode contained  in OrStart ... OrEnd
    CtState ctGenAlternation(Bytecode[] ir, int addr)
    {
        CtState[] pieces;
        CtState r;
        enum optL = IRL!(IR.Option);
        for(;;)
        {
            assert(ir[0].code == IR.Option);
            auto len = ir[0].data;
            if(optL+len < ir.length  && ir[optL+len].code == IR.Option)//not a last option
            {
                auto nir = ir[optL .. optL+len-IRL!(IR.GotoEndOr)];
                r = ctGenBlock(nir, addr+2);//space for Option + restore state
                //r.addr+1 to account GotoEndOr  at end of branch
                r.code = ctGenFixupCode(ir[0 .. ir[0].length], addr, r.addr+1) ~ r.code;
                addr = r.addr+1;//leave space for GotoEndOr
                pieces ~= r;
                ir = ir[optL + len .. $];
            }
            else
            {
                pieces ~= ctGenBlock(ir[optL..$], addr);
                addr = pieces[$-1].addr;
                break;
            }
        }
        r = pieces[0];
        for(uint i = 1; i < pieces.length; i++)
        {
            r.code ~= ctSub(`
                case $$:
                    goto case $$; `, pieces[i-1].addr, addr);
            r.code ~= pieces[i].code;
        }
        r.addr = addr;
        return r;
    }

    // generate fixup code for instruction in ir,
    // fixup means it has an alternative way for control flow
    string ctGenFixupCode(Bytecode[] ir, int addr, int fixup)
    {
        return ctGenFixupCode(ir, addr, fixup); // call ref Bytecode[] version
    }
    string ctGenFixupCode(ref Bytecode[] ir, int addr, int fixup)
    {
        string r;
        string testCode;
        r = ctSub(`
                case $$: debug(std_regex_matcher) writeln("#$$");`,
                    addr, addr);
        switch(ir[0].code)
        {
        case IR.InfiniteStart, IR.InfiniteQStart:
            r ~= ctSub( `
                    trackers[$$] = DataIndex.max;
                    goto case $$;`, curInfLoop, fixup);
            ir = ir[ir[0].length..$];
            break;
        case IR.InfiniteEnd:
            testCode = ctQuickTest(ir[IRL!(IR.InfiniteEnd) .. $],addr + 1);
            r ~= ctSub( `
                    if(trackers[$$] == s._index)
                    {//source not consumed
                        goto case $$;
                    }
                    trackers[$$] = s._index;

                    $$
                    {
                        $$
                    }
                    goto case $$;
                case $$: //restore state and go out of loop
                    $$
                    goto case;`, curInfLoop, addr+2,
                    curInfLoop, testCode, saveCode(addr+1),
                    fixup, addr+1, restoreCode());
            ir = ir[ir[0].length..$];
            break;
        case IR.InfiniteQEnd:
            testCode = ctQuickTest(ir[IRL!(IR.InfiniteEnd) .. $],addr + 1);
            auto altCode = testCode.length ? ctSub("else goto case $$;", fixup) : "";
            r ~= ctSub( `
                    if(trackers[$$] == s._index)
                    {//source not consumed
                        goto case $$;
                    }
                    trackers[$$] = s._index;

                    $$
                    {
                        $$
                        goto case $$;
                    }
                    $$
                case $$://restore state and go inside loop
                    $$
                    goto case $$;`, curInfLoop, addr+2,
                    curInfLoop, testCode, saveCode(addr+1),
                    addr+2, altCode, addr+1, restoreCode(), fixup);
            ir = ir[ir[0].length..$];
            break;
        case IR.RepeatStart, IR.RepeatQStart:
            r ~= ctSub( `
                    goto case $$;`, fixup);
            ir = ir[ir[0].length..$];
            break;
         case IR.RepeatEnd, IR.RepeatQEnd:
            //len, step, min, max
            uint len = ir[0].data;
            uint step = ir[2].raw;
            uint min = ir[3].raw;
            uint max = ir[4].raw;
            r ~= ctSub(`
                    if(counter < $$)
                    {
                        debug(std_regex_matcher) writeln("RepeatEnd min case pc=", $$);
                        counter += $$;
                        goto case $$;
                    }`,  min, addr, step, fixup);
            if(ir[0].code == IR.RepeatEnd)
            {
                string counter_expr = ctSub("counter % $$", step);
                r ~= ctSub(`
                    else if(counter < $$)
                    {
                            $$
                            counter += $$;
                            goto case $$;
                    }`, max, saveCode(addr+1, counter_expr), step, fixup);
            }
            else
            {
                string counter_expr = ctSub("counter % $$", step);
                r ~= ctSub(`
                    else if(counter < $$)
                    {
                        $$
                        counter = counter % $$;
                        goto case $$;
                    }`, max, saveCode(addr+1,counter_expr), step, addr+2);
            }
            r ~= ctSub(`
                    else
                    {
                        counter = counter % $$;
                        goto case $$;
                    }
                case $$: //restore state
                    $$
                    goto case $$;`, step, addr+2, addr+1, restoreCode(),
                    ir[0].code == IR.RepeatEnd ? addr+2 : fixup );
            ir = ir[ir[0].length..$];
            break;
        case IR.Option:
            r ~= ctSub( `
                {
                    $$
                }
                goto case $$;
            case $$://restore thunk to go to the next group
                $$
                goto case $$;`, saveCode(addr+1), addr+2,
                    addr+1, restoreCode(), fixup);
                ir = ir[ir[0].length..$];
            break;
        default:
            assert(0, text(ir[0].mnemonic));
        }
        return r;
    }


    string ctQuickTest(Bytecode[] ir, int id)
    {
        uint pc = 0;
        while(pc < ir.length && ir[pc].isAtom)
        {
            if(ir[pc].code == IR.GroupStart || ir[pc].code == IR.GroupEnd)
            {
                pc++;
            }
            else if(ir[pc].code == IR.Backref)
                break;
            else
            {
                string code = ctAtomCode(ir[pc..$], -1);
                return ctSub(`
                    int test_$$()
                    {
                        $$ //$$
                    }
                    if(test_$$() >= 0)`, id, code.ptr ? code : "return 0;",
                        ir[pc].mnemonic, id);
            }
        }
        return "";
    }

    //process & generate source for simple bytecodes at front of ir using address addr
    CtState ctGenAtom(ref Bytecode[] ir, int addr)
    {
        CtState result;
        result.code = ctAtomCode(ir, addr);
        ir.popFrontN(ir[0].code == IR.OrChar ? ir[0].sequence : ir[0].length);
        result.addr = addr + 1;
        return result;
    }

    //D code for atom at ir using address addr, addr < 0 means quickTest
    string ctAtomCode(Bytecode[] ir, int addr)
    {
        string load, code;
        string bailOut, nextInstr;
        if(addr < 0)
        {
            load = "if(atEnd) return -1;";
            bailOut = "return -1;";
            nextInstr = "return 0;";
        }
        else
        {
            load = "if(atEnd) goto L_backtrack;";
            bailOut = "goto L_backtrack;";
            nextInstr = ctSub("goto case $$;", addr+1);
            code ~=  ctSub( `
                 case $$: debug(std_regex_matcher) writefln("#$$ $$ src: %s",
                    s.slice(s._index, s.lastIndex));
                `, addr, addr, ir[0].mnemonic);
        }
        switch(ir[0].code)
        {
        case IR.OrChar://assumes IRL!(OrChar) == 1
            code ~= load;
            uint len = ir[0].sequence;
            for(uint i = 0; i < len; i++)
            {
                code ~= ctSub( `
                    if(s.$$DChar($$))
                        $$
                    `,  addr < 0 ? "test" : "match", ir[i].data, nextInstr);
            }
            code ~= ctSub( `
                    $$`, bailOut);
            break;
        case IR.Char:
            code ~= load;
            code ~= ctSub( `
                    if(!s.$$DChar($$))
                        $$
                    $$`, addr < 0 ? "test" : "match", ir[0].data, bailOut, nextInstr);
            break;
        case IR.Any:
            code ~= load;
            code ~= ctSub(`
                    if(!(re.flags & RegexOption.singleline)
                                && (s.front == '\r' || s.front == '\n'))
                        $$
                    $$
                    $$`, bailOut, addr < 0 ? "" : "s.skipChar();", nextInstr);
            break;
        case IR.CodepointSet:
        case IR.Trie:
            code ~= load;
            code ~= ctSub( `
                    if(!$$Class(s, re.matchers[$$]))
                        $$
                    $$`,  addr < 0 ? "test" : "match", ir[0].data, bailOut, nextInstr);
            break;
        case IR.Wordboundary:
            code ~= ctSub( `
                    if(atStart)
                    {
                        if(!atEnd && !s.testWordClass())
                            $$
                    }
                    else if(atEnd)
                    {
                        if(!s.loopBack(s._index).testWordClass())
                            $$
                    }
                    else
                    {
                        bool af = s.testWordClass();
                        bool ab = s.loopBack(s._index).testWordClass();
                        if((af ^ ab) == false)
                            $$
                    }
                    $$
                    `, bailOut, bailOut, bailOut, nextInstr);
            break;
        case IR.Notwordboundary:
            code ~= ctSub( `
                    if(atStart)
                    {
                        if(atEnd || s.testWordClass())
                            $$
                    }
                    else if(atEnd)
                    {
                        if(s.loopBack(s._index).testWordClass())
                            $$
                    }
                    else
                    {
                        bool af = s.testWordClass();
                        bool ab = s.loopBack(s._index).testWordClass();
                        if((af ^ ab) == true)
                            $$
                    }
                    $$
                    `, bailOut, bailOut, bailOut, nextInstr);

            break;
        case IR.Bol:
            code ~= ctSub(`
                    if(atStart)
                    {
                        $$
                    }
                    else if(re.flags & RegexOption.multiline)
                    {
                        bool seenNl = !atEnd && s.front == '\n';
                        if(startOfLine(s.loopBack(s._index), seenNl))
                        {
                            $$
                        }
                    }
                    $$`, nextInstr, nextInstr, bailOut);

            break;
        case IR.Eol:
            code ~= ctSub(`
                    if(atEnd)
                    {
                        $$
                    }
                    else if(re.flags & RegexOption.multiline)
                    {
                        bool seenCr = !atStart && s.loopBack(s._index).front == '\r';
                        if(endOfLine(s, seenCr))
                        {
                            $$
                        }
                    }
                    $$`, nextInstr, nextInstr, bailOut);

            break;
        case IR.GroupStart:
            code ~= ctSub(`
                    matches[$$].begin = s._index;
                    $$`, ir[0].data, nextInstr);
            match = ir[0].data+1;
            break;
        case IR.GroupEnd:
            code ~= ctSub(`
                    matches[$$].end = s._index;
                    $$`, ir[0].data, nextInstr);
            break;
        case IR.Backref:
            string mStr = "auto referenced = ";
            mStr ~= ir[0].localRef
                ? ctSub("s.slice(matches[$$].begin, matches[$$].end);",
                    ir[0].data, ir[0].data)
                : ctSub("s.slice(backrefed[$$].begin, backrefed[$$].end);",
                    ir[0].data, ir[0].data);
            code ~= ctSub( `
                    $$
                    import std.string, std.algorithm;
                    if(skipOver(s, referenced.representation))
                        $$
                    else
                        $$`, mStr, nextInstr, bailOut);
            break;
        case IR.Nop:
        case IR.End:
            break;
        default:
            assert(0, text(ir[0].mnemonic, " is not supported yet"));
        }
        return code;
    }

    //generate D code for the whole regex
    public string ctGenRegEx(Bytecode[] ir)
    {
        auto bdy = ctGenBlock(ir, 0);
        auto r = `
            import core.stdc.stdlib;
            with(matcher)
            {
            pc = 0;
            counter = 0;
            lastState = 0;
            auto start = s._index;`;
        r ~= `
            goto StartLoop;
            debug(std_regex_matcher) writeln("Try CT matching  starting at ", s.slice(s._index, s.lastIndex));
        L_backtrack:
            if(lastState || prevStack())
            {
                stackPop(pc);
                stackPop(s._index);
            }
            else
            {
                s.reset(start);
                return false;
            }
        StartLoop:
            switch(pc)
            {
        `;
        r ~= bdy.code;
        r ~= ctSub(`
                case $$: break;`,bdy.addr);
        r ~= `
            default:
                assert(0);
            }
            return true;
            }
        `;
        return r;
    }

}

string ctGenRegExCode(Char)(Regex!Char re)
{
    auto context = CtContext(re);
    return context.ctGenRegEx(re.ir);
}
