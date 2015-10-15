//Written in the D programming language
/*
    Implementation of Thompson NFA std.regex engine.
    Key point is evaluation of all possible threads (state) at each step
    in a breadth-first manner, thereby geting some nice properties:
        - looking at each character only once
        - merging of equivalent threads, that gives matching process linear time complexity
*/
module std.regex.internal.thompson;

package(std.regex):

import std.regex.internal.ir;
import std.range;

debug(std_regex_matcher) import std.stdio;

//State of VM thread
struct Thread(DataIndex)
{
    Thread* next;    //intrusive linked list
    uint pc;
    uint counter;    //loop counter
    uint uopCounter; //counts micro operations inside one macro instruction (e.g. BackRef)
    Group!DataIndex[1] matches;
}

//head-tail singly-linked list
struct ThreadList(DataIndex)
{
    Thread!DataIndex* tip = null, toe = null;
    //add new thread to the start of list
    void insertFront(Thread!DataIndex* t)
    {
        if(tip)
        {
            t.next = tip;
            tip = t;
        }
        else
        {
            t.next = null;
            tip = toe = t;
        }
    }
    //add new thread to the end of list
    void insertBack(Thread!DataIndex* t)
    {
        if(toe)
        {
            toe.next = t;
            toe = t;
        }
        else
            tip = toe = t;
        toe.next = null;
    }
    //move head element out of list
    Thread!DataIndex* fetch()
    {
        auto t = tip;
        if(tip == toe)
            tip = toe = null;
        else
            tip = tip.next;
        return t;
    }
    //non-destructive iteration of ThreadList
    struct ThreadRange
    {
        const(Thread!DataIndex)* ct;
        this(ThreadList tlist){ ct = tlist.tip; }
        @property bool empty(){ return ct is null; }
        @property const(Thread!DataIndex)* front(){ return ct; }
        @property popFront()
        {
            assert(ct);
            ct = ct.next;
        }
    }
    @property bool empty()
    {
        return tip == null;
    }
    ThreadRange opSlice()
    {
        return ThreadRange(this);
    }
}

// What is at front of range - nothing, single code unit (<= ASCII), full codepoint ( > ASCII)
enum InputKind { None=0, Unit, Point };

// Thompson doesn't do quick test on empty input, and it knows ASCII vs non-ASCII
int quickTestKnown(InputKind kind, RegEx, Stream)(uint pc, ref Stream s, ref RegEx re)
{
    for(;;)
        switch(re.ir[pc].code) with (InputKind)
        {
            static if(kind == Point || is(dchar : typeof(s.front)))
            {
        case IR.OrChar:
                uint len = re.ir[pc].sequence;
                uint end = pc + len;
                if(!s.testDChar(re.ir[pc].data) && !s.testDChar(re.ir[pc+1].data))
                {
                    for(pc = pc+2; pc < end; pc++)
                        if(s.testDChar(re.ir[pc].data))
                            break;
                    if(pc == end)
                        return -1;
                }
                return 0;
        case IR.Char:
                return s.testDChar(re.ir[pc].data) ? 0 : -1;
        case IR.CodepointSet:
        case IR.Trie:
                if(s.testClass(re.matchers[re.ir[pc].data]))
                    return 0;
                else
                    return -1;
            }
            else
            {
        case IR.OrChar:
                uint len = re.ir[pc].sequence;
                uint end = pc + len;
                immutable c = s.front;
                if(c != re.ir[pc].data && c != re.ir[pc+1].data)
                {
                    for(pc = pc+2; pc < end; pc++)
                        if(c == re.ir[pc].data)
                            break;
                    if(pc == end)
                        return -1;
                }
                return 0;
        case IR.Char:
                return s.front == re.ir[pc].data ? 0 : -1;
        case IR.CodepointSet:
        case IR.Trie:
                if(re.matchers[re.ir[pc].data].subMatcher!1.test(s))
                    return 0;
                else
                    return -1;
            }
        case IR.GroupStart, IR.GroupEnd:
            pc += IRL!(IR.GroupStart);
            break;

        case IR.Any:
        default:
            return 0;
        }
    assert(0);
}


/+
   Thomspon matcher does all matching in lockstep,
   never looking at the same char twice
+/
@trusted struct ThompsonMatcher(Char, Stream = Input!Char)
    if(is(Char : dchar))
{
    alias DataIndex = Stream.DataIndex;
    Thread!DataIndex* freelist;
    ThreadList!DataIndex clist, nlist;
    DataIndex[] merge;
    Group!DataIndex[] backrefed;
    Regex!Char re;           //regex program
    Stream s;
    DataIndex genCounter;    //merge trace counter, goes up on every dchar
    size_t[size_t] subCounters; //a table of gen counter per sub-engine: PC -> counter
    size_t threadSize;
    bool matched;
    bool exhausted;
    static if(__traits(hasMember,Stream, "search"))
    {
        enum kicked = true;
    }
    else
        enum kicked = false;

    static size_t getThreadSize(const ref Regex!Char re)
    {
        return re.ngroup
            ? (Thread!DataIndex).sizeof + (re.ngroup-1)*(Group!DataIndex).sizeof
            : (Thread!DataIndex).sizeof - (Group!DataIndex).sizeof;
    }

    static size_t initialMemory(const ref Regex!Char re)
    {
        return getThreadSize(re)*re.threadCount + re.hotspotTableSize*size_t.sizeof;
    }

    //true if it's start of input
    @property bool atStart(){   return s._index == 0; }

    //true if it's end of input
    @property bool atEnd(){  return s.atEnd; }

    void initExternalMemory(void[] memory)
    {
        threadSize = getThreadSize(re);
        prepareFreeList(re.threadCount, memory);
        if(re.hotspotTableSize)
        {
            merge = arrayInChunk!(DataIndex)(re.hotspotTableSize, memory);
            merge[] = 0;
        }
    }

    this()(Regex!Char program, Stream stream, void[] memory)
    {
        re = program;
        s = stream;
        initExternalMemory(memory);
        genCounter = 0;
    }

    this(S)(ref ThompsonMatcher!(Char,S) matcher, Bytecode[] piece, Stream stream)
    {
        s = stream;
        re = matcher.re;
        re.ir = piece;
        threadSize = matcher.threadSize;
        merge = matcher.merge;
        freelist = matcher.freelist;
    }

    auto fwdMatcher()(Bytecode[] piece, size_t counter)
    {
        auto m = ThompsonMatcher!(Char, Stream)(this, piece, s);
        m.genCounter = counter;
        return m;
    }

    auto bwdMatcher()(Bytecode[] piece, size_t counter)
    {
        alias BackLooper = typeof(s.loopBack(s._index));
        auto m = ThompsonMatcher!(Char, BackLooper)(this, piece, s.loopBack(s._index));
        m.genCounter = counter;
        return m;
    }

    auto dupTo(void[] memory)
    {
        typeof(this) tmp = this;//bitblit
        tmp.initExternalMemory(memory);
        tmp.genCounter = 0;
        return tmp;
    }

    bool match(Group!DataIndex[] matches)
    {
        debug(std_regex_matcher)
            writeln("------------------------------------------");
        if(exhausted)
        {
            return false;
        }
        if(re.flags & RegexInfo.oneShot)
        {
            exhausted = true;
            return matchOneShot(matches);
        }
        static if(kicked)
            if(!re.kickstart.empty)
                return matchImpl!(true, true)(matches);
        return matchImpl!(false, true)(matches);
    }

    //match the input and fill matches
    bool matchImpl(bool withKick, bool withSearch)(Group!DataIndex[] matches)
    {
        matched = false;
        static if(!withSearch)
            clist.insertBack(createStart(s._index));
        if(!atEnd)
            for(;;) with(InputKind)
            {
                genCounter++;
                debug(std_regex_matcher)
                {
                    writefln("Threaded matching threads at src: %s  %s",
                        s.slice(s._index, s.lastIndex),
                        is(typeof(s) == Input!Char) ? " " : " backwards");
                    foreach(t; clist[])
                    {
                        assert(t);
                        writef("pc=%s ",t.pc);
                        write(t.matches);
                        writeln();
                    }
                }
                uint step = s.stride();
                if(step == 1)
                {
                    if(evalAll!(Unit, withSearch)(matches))
                    {
                        s.popFrontN(step);
                        break;
                    }
                }
                else if (evalAll!(Point, withSearch)(matches))
                {
                    s.popFrontN(step);
                    break;
                }
                s.popFrontN(step);
                clist = nlist;
                nlist = (ThreadList!DataIndex).init;
                if(clist.tip is null)
                {
                    static if(withKick)
                    {
                        s._index = re.kickstart.search(s._origin,
                            s._index);
                    }
                    else if(!withSearch)
                        break;
                }
                if(atEnd)
                {
                    exhausted = true;
                    break;
                }
            }

        genCounter++; //increment also on each end
        debug(std_regex_matcher) writefln("Threaded matching threads at end");
        //try out all zero-width posibilities
        evalAll!(InputKind.None, withSearch)(matches);
        if(matched)
        {
            // in case NFA found match along the way
            // and last possible longer alternative ultimately failed
            static if(withSearch) // no point in any of this for one-shot mode
            {
                s.reset(matches[0].end);// reset to last successful match
                exhausted = atEnd || !(re.flags & RegexOption.global);
                //+ empty match advances the input
                if(!exhausted && matches[0].begin == matches[0].end)
                    s.skipChar();
            }
        }
        return matched;
    }

    /+
        handle succesful threads
    +/
    void finish(const(Thread!DataIndex)* t, Group!DataIndex[] matches)
    {
        matches.ptr[0..re.ngroup] = t.matches.ptr[0..re.ngroup];
        debug(std_regex_matcher)
        {
            writef("FOUND pc=%s prog_len=%s",
                    t.pc, re.ir.length);
            if(!matches.empty)
                writefln(": %s..%s", matches[0].begin, matches[0].end);
            foreach(v; matches)
                writefln("%d .. %d", v.begin, v.end);
        }
        matched = true;
    }

    bool evalAll(InputKind kind, bool spawnThread)(Group!DataIndex[] matches)
    {
        for(Thread!DataIndex* t = clist.fetch(); t; t = clist.fetch())
            eval!kind(t, matches);
        if(!matched)//if we already have match no need to push the engine
        {
            if(spawnThread) // should be optimized away if false
                eval!kind(createStart(s._index), matches);//new thread staring at this position
        }
        else if(nlist.empty) //matched and no better threads
        {
            debug(std_regex_matcher) writeln("Stopped  matching before consuming full input");
            return true;
        }
        return false;
    }

    /+
        match thread against codepoint, cutting trough all 0-width instructions
        and taking care of control flow, then add it to nlist
    +/
    void eval(InputKind kind)(Thread!DataIndex* t, Group!DataIndex[] matches)
    {
        ThreadList!DataIndex worklist;
        debug(std_regex_matcher) writeln("---- Evaluating thread");
        for(;;)
        {
            debug(std_regex_matcher)
            {
                writef("\tpc=%s [", t.pc);
                foreach(x; worklist[])
                    writef(" %s ", x.pc);
                writeln("]");
            }
            debug(std_regex_matcher)
                writefln("PC: %s\tCNT: %s\t%s \t src: %s",
                    t.pc, t.counter, disassemble(re.ir, t.pc, re.dict),
                    s.slice(s._index, s.lastIndex));
            switch(re.ir[t.pc].code) with(InputKind)
            {
            case IR.End:
                finish(t, matches);
                matches[0].end = s._index; //fix endpoint of the whole match
                recycle(t);
                //cut off low priority threads
                recycle(clist);
                recycle(worklist);
                debug(std_regex_matcher) writeln("Finished thread ", matches);
                return;
            case IR.Wordboundary:
                //at start & end of input
                if(atStart)
                {
                    if(!atEnd && !s.testWordClass())
                        goto L_kill_thread;
                }
                else if(atEnd)
                {
                    if(!s.loopBack(s._index).testWordClass())
                        goto L_kill_thread;
                }
                else
                {
                    bool af = s.testWordClass();
                    bool ab = s.loopBack(s._index).testWordClass();
                    if((af ^ ab) == false)
                        goto L_kill_thread;
                }
                t.pc += IRL!(IR.Wordboundary);
                break;
            case IR.Notwordboundary:
                //at start & end of input
                if(atStart)
                {
                    if(atEnd || s.testWordClass())
                        goto L_kill_thread;
                }
                else if(atEnd)
                {
                    if(s.loopBack(s._index).testWordClass())
                        goto L_kill_thread;
                }
                else
                {
                    bool af = s.testWordClass();
                    bool ab = s.loopBack(s._index).testWordClass();
                    if((af ^ ab) == true)
                        goto L_kill_thread;
                }
                t.pc += IRL!(IR.Wordboundary);
                break;
            case IR.Bol:
                if(atStart)
                {
                    t.pc += IRL!(IR.Bol);
                    break;
                }
                else if(re.flags & RegexOption.multiline)
                {
                    bool seenNl = !atEnd && s.front == '\n';
                    if(startOfLine(s.loopBack(s._index), seenNl))
                    {
                        t.pc += IRL!(IR.Eol);
                        break;
                    }
                }
                goto L_kill_thread;
            case IR.Eol:
                //no matching inside \r\n
                if(atEnd)
                {
                    t.pc += IRL!(IR.Eol);
                    break;
                }
                else if(re.flags & RegexOption.multiline)
                {
                    bool seenCr = !atStart && s.loopBack(s._index).front == '\r';
                    if(endOfLine(s, seenCr))
                    {
                        t.pc += IRL!(IR.Eol);
                        break;
                    }
                }
                goto L_kill_thread;
            case IR.InfiniteStart, IR.InfiniteQStart:
                t.pc += re.ir[t.pc].data + IRL!(IR.InfiniteStart);
                goto case IR.InfiniteEnd; //both Q and non-Q
            case IR.RepeatStart, IR.RepeatQStart:
                t.pc += re.ir[t.pc].data + IRL!(IR.RepeatStart);
                goto case IR.RepeatEnd; //both Q and non-Q
            case IR.RepeatEnd:
            case IR.RepeatQEnd:
                //len, step, min, max
                uint len = re.ir[t.pc].data;
                uint step =  re.ir[t.pc+2].raw;
                uint min = re.ir[t.pc+3].raw;
                if(t.counter < min)
                {
                    t.counter += step;
                    t.pc -= len;
                    break;
                }
                if(merge[re.ir[t.pc + 1].raw+t.counter] < genCounter)
                {
                    debug(std_regex_matcher) writefln("A thread(pc=%s) passed there : %s ; GenCounter=%s mergetab=%s",
                                    t.pc, s._index, genCounter, merge[re.ir[t.pc + 1].raw+t.counter] );
                    merge[re.ir[t.pc + 1].raw+t.counter] = genCounter;
                }
                else
                {
                    debug(std_regex_matcher) writefln("A thread(pc=%s) got merged there : %s ; GenCounter=%s mergetab=%s",
                                    t.pc, s._index, genCounter, merge[re.ir[t.pc + 1].raw+t.counter] );
                    recycle(t);
                    t = worklist.fetch();
                    if(!t)
                        return;
                    break;
                }
                uint max = re.ir[t.pc+4].raw;
                if(t.counter < max)
                {
                    if(re.ir[t.pc].code == IR.RepeatEnd)
                    {
                        //queue out-of-loop thread
                        worklist.insertFront(fork(t, t.pc + IRL!(IR.RepeatEnd),  t.counter % step));
                        t.counter += step;
                        t.pc -= len;
                    }
                    else
                    {
                        //queue into-loop thread
                        worklist.insertFront(fork(t, t.pc - len,  t.counter + step));
                        t.counter %= step;
                        t.pc += IRL!(IR.RepeatEnd);
                    }
                }
                else
                {
                    t.counter %= step;
                    t.pc += IRL!(IR.RepeatEnd);
                }
                break;
            case IR.InfiniteEnd:
            case IR.InfiniteQEnd:
                if(merge[re.ir[t.pc + 1].raw+t.counter] < genCounter)
                {
                    debug(std_regex_matcher) writefln("A thread(pc=%s) passed there : %s ; GenCounter=%s mergetab=%s",
                                    t.pc, s._index, genCounter, merge[re.ir[t.pc + 1].raw+t.counter] );
                    merge[re.ir[t.pc + 1].raw+t.counter] = genCounter;
                }
                else
                {
                    debug(std_regex_matcher) writefln("A thread(pc=%s) got merged there : %s ; GenCounter=%s mergetab=%s",
                                    t.pc, s._index, genCounter, merge[re.ir[t.pc + 1].raw+t.counter] );
                    recycle(t);
                    t = worklist.fetch();
                    if(!t)
                        return;
                    break;
                }
                uint len = re.ir[t.pc].data;
                uint pc1, pc2; //branches to take in priority order
                if(re.ir[t.pc].code == IR.InfiniteEnd)
                {
                    pc1 = t.pc - len;
                    pc2 = t.pc + IRL!(IR.InfiniteEnd);
                }
                else
                {
                    pc1 = t.pc + IRL!(IR.InfiniteEnd);
                    pc2 = t.pc - len;
                }
                static if(kind)
                {
                    int test = quickTestKnown!kind(pc1, s, re);
                    if(test >= 0)
                    {
                        worklist.insertFront(fork(t, pc2, t.counter));
                        t.pc = pc1;
                    }
                    else
                        t.pc = pc2;
                }
                else
                {
                    worklist.insertFront(fork(t, pc2, t.counter));
                    t.pc = pc1;
                }
                break;
            case IR.OrEnd:
                if(merge[re.ir[t.pc + 1].raw+t.counter] < genCounter)
                {
                    debug(std_regex_matcher) writefln("A thread(pc=%s) passed there : %s ; GenCounter=%s mergetab=%s",
                                    t.pc, s.slice(s._index ,  s.lastIndex), genCounter, merge[re.ir[t.pc + 1].raw + t.counter] );
                    merge[re.ir[t.pc + 1].raw+t.counter] = genCounter;
                    t.pc += IRL!(IR.OrEnd);
                }
                else
                {
                    debug(std_regex_matcher) writefln("A thread(pc=%s) got merged there : %s ; GenCounter=%s mergetab=%s",
                                    t.pc, s.slice(s._index ,  s.lastIndex), genCounter, merge[re.ir[t.pc + 1].raw + t.counter] );
                    recycle(t);
                    t = worklist.fetch();
                    if(!t)
                        return;
                }
                break;
            case IR.OrStart:
                t.pc += IRL!(IR.OrStart);
                goto case;
            case IR.Option:
                uint next = t.pc + re.ir[t.pc].data + IRL!(IR.Option);
                //queue next Option
                if(re.ir[next].code == IR.Option)
                {
                    worklist.insertFront(fork(t, next, t.counter));
                }
                t.pc += IRL!(IR.Option);
                break;
            case IR.GotoEndOr:
                t.pc = t.pc + re.ir[t.pc].data + IRL!(IR.GotoEndOr);
                goto case IR.OrEnd;
            case IR.GroupStart:
                uint n = re.ir[t.pc].data;
                t.matches.ptr[n].begin = s._index;
                t.pc += IRL!(IR.GroupStart);
                break;
            case IR.GroupEnd:
                uint n = re.ir[t.pc].data;
                t.matches.ptr[n].end = s._index;
                t.pc += IRL!(IR.GroupEnd);
                break;
            case IR.Backref:
                uint n = re.ir[t.pc].data;
                Group!DataIndex* source = re.ir[t.pc].localRef ? t.matches.ptr : backrefed.ptr;
                assert(source);
                if(source[n].begin == source[n].end)//zero-width Backref!
                {
                    t.pc += IRL!(IR.Backref);
                }
                else static if(kind)
                { //non zero-width backref
                    if(t.uopCounter == 0) // eager test
                    {
                        auto refed = s.slice(source[n].begin, source[n].end);
                        import std.algorithm, std.string;
                        static if(Stream.isLoopback)
                        {
                            if(s.length < refed.length || !s.startsWith(refed.representation.retro))
                            {
                                goto L_kill_thread;
                            }
                        }
                        else
                        {
                            if(s.length < refed.length || !s.startsWith(refed.representation))
                            {
                                goto L_kill_thread;
                            }
                        }
                    }
                    size_t idx = source[n].begin + t.uopCounter;
                    size_t end = source[n].end;
                    // just keep incrementing till it ends, everything is tested just once
                    t.uopCounter += std.utf.stride(s.slice(idx, end), 0);
                    if(t.uopCounter + source[n].begin == source[n].end) // last codepoint
                    {
                        t.pc += IRL!(IR.Backref);
                        t.uopCounter = 0;
                    }
                    nlist.insertBack(t);
                    break;
                }
                else
                {
                    recycle(t);
                    t = worklist.fetch();
                    if(!t)
                        return;
                    break;
                }
                break;
            case IR.LookbehindStart:
            case IR.NeglookbehindStart:
                uint len = re.ir[t.pc].data;
                uint ms = re.ir[t.pc + 1].raw, me = re.ir[t.pc + 2].raw;
                uint end = t.pc + len + IRL!(IR.LookbehindEnd) + IRL!(IR.LookbehindStart);
                bool positive = re.ir[t.pc].code == IR.LookbehindStart;
                static if(Stream.isLoopback)
                    auto matcher = fwdMatcher(re.ir[t.pc + IRL!(IR.LookbehindStart) .. end],
                        subCounters.get(t.pc, 0));
                else
                    auto matcher = bwdMatcher(re.ir[t.pc + IRL!(IR.LookbehindStart) .. end],
                        subCounters.get(t.pc, 0));
                matcher.re.ngroup = me - ms;
                matcher.backrefed = backrefed.empty ? t.matches : backrefed;
                //backMatch
                auto mRes = matcher.matchOneShot(t.matches.ptr[ms .. me]);
                freelist = matcher.freelist;
                subCounters[t.pc] = matcher.genCounter;
                if(mRes ^ positive)
                {
                    recycle(t);
                    t = worklist.fetch();
                    if(!t)
                        return;
                    break;
                }
                else
                    t.pc = end;
                break;
            case IR.LookaheadStart:
            case IR.NeglookaheadStart:
                auto save = s._index;
                uint len = re.ir[t.pc].data;
                uint ms = re.ir[t.pc+1].raw, me = re.ir[t.pc+2].raw;
                uint end = t.pc+len+IRL!(IR.LookaheadEnd)+IRL!(IR.LookaheadStart);
                bool positive = re.ir[t.pc].code == IR.LookaheadStart;
                static if(Stream.isLoopback)
                    auto matcher = bwdMatcher(re.ir[t.pc + IRL!(IR.LookaheadStart) .. end],
                        subCounters.get(t.pc, 0));
                else
                    auto matcher = fwdMatcher(re.ir[t.pc + IRL!(IR.LookaheadStart) .. end],
                        subCounters.get(t.pc, 0));
                matcher.re.ngroup = me - ms;
                matcher.backrefed = backrefed.empty ? t.matches : backrefed;
                auto mRes = matcher.matchOneShot(t.matches.ptr[ms .. me]);
                freelist = matcher.freelist;
                subCounters[t.pc] = matcher.genCounter;
                s.reset(save);
                if(mRes ^ positive)
                {
                    recycle(t);
                    t = worklist.fetch();
                    if(!t)
                        return;
                    break;
                }
                else
                    t.pc = end;
                break;
            case IR.LookaheadEnd:
            case IR.NeglookaheadEnd:
            case IR.LookbehindEnd:
            case IR.NeglookbehindEnd:
                finish(t, matches.ptr[0 .. re.ngroup]);
                recycle(t);
                //cut off low priority threads
                recycle(clist);
                recycle(worklist);
                return;
            case IR.Nop:
                t.pc += IRL!(IR.Nop);
                break;

                static if(kind)
                {
            case IR.OrChar:
                      uint len = re.ir[t.pc].sequence;
                      uint end = t.pc + len;
                      static assert(IRL!(IR.OrChar) == 1);
                      for(; t.pc < end; t.pc++)
                            static if(kind == Point)
                            {
                                if(s.testDChar(re.ir[t.pc].data))
                                    break;
                            }
                            else
                            {
                                if(s.front == re.ir[t.pc].data)
                                    break;
                            }
                      if(t.pc != end)
                      {
                          t.pc = end;
                          nlist.insertBack(t);
                      }
                      else
                          recycle(t);
                      t = worklist.fetch();
                      if(!t)
                          return;
                      break;
            case IR.Char:
                      if(s.testDChar(re.ir[t.pc].data))
                      {
                          t.pc += IRL!(IR.Char);
                          nlist.insertBack(t);
                      }
                      else
                          recycle(t);
                      t = worklist.fetch();
                      if(!t)
                          return;
                      break;
            case IR.Any:
                      t.pc += IRL!(IR.Any);
                      if(!(re.flags & RegexOption.singleline)
                              && (s.front == '\r' || s.front == '\n'))
                          recycle(t);
                      else
                          nlist.insertBack(t);
                      t = worklist.fetch();
                      if(!t)
                          return;
                      break;
            case IR.CodepointSet:
            case IR.Trie:
                      static if(kind == Point || is(dchar : Char))
                      {
                          if(s.testClass(re.matchers[re.ir[t.pc].data]))
                          {
                              t.pc += IRL!(IR.Trie);
                              nlist.insertBack(t);
                          }
                          else
                              recycle(t);
                      }
                      else
                      {
                          if(re.matchers[re.ir[t.pc].data].subMatcher!1.test(s))
                          {
                              t.pc += IRL!(IR.Trie);
                              nlist.insertBack(t);
                          }
                          else
                              recycle(t);
                      }
                      t = worklist.fetch();
                      if(!t)
                          return;
                      break;
                  default:
                      assert(0, "Unrecognized instruction " ~ re.ir[t.pc].mnemonic);
            L_kill_thread:
                        recycle(t);
                        t = worklist.fetch();
                        if(!t)
                            return;
                }
                else
                {

                    default:
            L_kill_thread:
                        recycle(t);
                        t = worklist.fetch();
                        if(!t)
                            return;
                }
            }
        }

    }

    //match the input, evaluating IR without searching
    bool matchOneShot(Group!DataIndex[] matches)
    {
        return matchImpl!(false, false)(matches);
    }

    //get a dirty recycled Thread
    Thread!DataIndex* allocate()
    {
        assert(freelist, "not enough preallocated memory");
        Thread!DataIndex* t = freelist;
        freelist = freelist.next;
        return t;
    }

    //link memory into a free list of Threads
    void prepareFreeList(size_t size, ref void[] memory)
    {
        void[] mem = memory[0 .. threadSize*size];
        memory = memory[threadSize * size .. $];
        freelist = cast(Thread!DataIndex*)&mem[0];
        size_t i;
        for(i = threadSize; i < threadSize*size; i += threadSize)
            (cast(Thread!DataIndex*)&mem[i-threadSize]).next = cast(Thread!DataIndex*)&mem[i];
        (cast(Thread!DataIndex*)&mem[i-threadSize]).next = null;
    }

    //dispose a thread
    void recycle(Thread!DataIndex* t)
    {
        t.next = freelist;
        freelist = t;
    }

    //dispose list of threads
    void recycle(ref ThreadList!DataIndex list)
    {
        auto t = list.tip;
        while(t)
        {
            auto next = t.next;
            recycle(t);
            t = next;
        }
        list = list.init;
    }

    //creates a copy of master thread with given pc
    Thread!DataIndex* fork(Thread!DataIndex* master, uint pc, uint counter)
    {
        auto t = allocate();
        t.matches.ptr[0..re.ngroup] = master.matches.ptr[0..re.ngroup];
        t.pc = pc;
        t.counter = counter;
        t.uopCounter = 0;
        return t;
    }

    //creates a start thread
    Thread!DataIndex* createStart(DataIndex index, uint pc = 0)
    {
        auto t = allocate();
        t.matches.ptr[0..re.ngroup] = (Group!DataIndex).init;
        t.matches[0].begin = index;
        t.pc = pc;
        t.counter = 0;
        t.uopCounter = 0;
        return t;
    }
}
