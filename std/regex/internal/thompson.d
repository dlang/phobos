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
    dchar front;
    DataIndex index;
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
    @property bool atStart(){   return index == 0; }

    //true if it's end of input
    @property bool atEnd(){  return index == s.lastIndex && s.atEnd; }

    bool next()
    {
        if(!s.nextChar(front, index))
        {
            index =  s.lastIndex;
            return false;
        }
        return true;
    }

    static if(kicked)
    {
        bool search()
        {

            if(!s.search(re.kickstart, front, index))
            {
                index = s.lastIndex;
                return false;
            }
            return true;
        }
    }

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
        front = matcher.front;
        index = matcher.index;
    }

    auto fwdMatcher()(Bytecode[] piece, size_t counter)
    {
        auto m = ThompsonMatcher!(Char, Stream)(this, piece, s);
        m.genCounter = counter;
        return m;
    }

    auto bwdMatcher()(Bytecode[] piece, size_t counter)
    {
        alias BackLooper = typeof(s.loopBack(index));
        auto m = ThompsonMatcher!(Char, BackLooper)(this, piece, s.loopBack(index));
        m.genCounter = counter;
        m.next();
        return m;
    }

    auto dupTo(void[] memory)
    {
        typeof(this) tmp = this;//bitblit
        tmp.initExternalMemory(memory);
        tmp.genCounter = 0;
        return tmp;
    }

    enum MatchResult{
        NoMatch,
        PartialMatch,
        Match,
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
            next();
            exhausted = true;
            return matchOneShot(matches)==MatchResult.Match;
        }
        static if(kicked)
            if(!re.kickstart.empty)
                return matchImpl!(true)(matches);
        return matchImpl!(false)(matches);
    }

    //match the input and fill matches
    bool matchImpl(bool withSearch)(Group!DataIndex[] matches)
    {
        if(!matched && clist.empty)
        {
           static if(withSearch)
                search();
           else
                next();
        }
        else//char in question is  fetched in prev call to match
        {
            matched = false;
        }

        if(!atEnd)//if no char
            for(;;)
            {
                genCounter++;
                debug(std_regex_matcher)
                {
                    writefln("Threaded matching threads at  %s", s[index..s.lastIndex]);
                    foreach(t; clist[])
                    {
                        assert(t);
                        writef("pc=%s ",t.pc);
                        write(t.matches);
                        writeln();
                    }
                }
                for(Thread!DataIndex* t = clist.fetch(); t; t = clist.fetch())
                {
                    eval!true(t, matches);
                }
                if(!matched)//if we already have match no need to push the engine
                    eval!true(createStart(index), matches);//new thread staring at this position
                else if(nlist.empty)
                {
                    debug(std_regex_matcher) writeln("Stopped  matching before consuming full input");
                    break;//not a partial match for sure
                }
                clist = nlist;
                nlist = (ThreadList!DataIndex).init;
                if(clist.tip is null)
                {
                    static if(withSearch)
                    {
                        if(!search())
                            break;
                    }
                    else
                    {
                        if(!next())
                            break;
                    }
                }
                else if(!next())
                {
                    if (!atEnd) return false;
                    exhausted = true;
                    break;
                }
            }

        genCounter++; //increment also on each end
        debug(std_regex_matcher) writefln("Threaded matching threads at end");
        //try out all zero-width posibilities
        for(Thread!DataIndex* t = clist.fetch(); t; t = clist.fetch())
        {
            eval!false(t, matches);
        }
        if(!matched)
            eval!false(createStart(index), matches);//new thread starting at end of input
        if(matched)
        {//in case NFA found match along the way
         //and last possible longer alternative ultimately failed
            s.reset(matches[0].end);//reset to last successful match
            next();//and reload front character
            //--- here the exact state of stream was restored ---
            exhausted = atEnd || !(re.flags & RegexOption.global);
            //+ empty match advances the input
            if(!exhausted && matches[0].begin == matches[0].end)
                next();
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

    /+
        match thread against codepoint, cutting trough all 0-width instructions
        and taking care of control flow, then add it to nlist
    +/
    void eval(bool withInput)(Thread!DataIndex* t, Group!DataIndex[] matches)
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
            switch(re.ir[t.pc].code)
            {
            case IR.End:
                finish(t, matches);
                matches[0].end = index; //fix endpoint of the whole match
                recycle(t);
                //cut off low priority threads
                recycle(clist);
                recycle(worklist);
                debug(std_regex_matcher) writeln("Finished thread ", matches);
                return;
            case IR.Wordboundary:
                dchar back;
                DataIndex bi;
                //at start & end of input
                if(atStart && wordTrie[front])
                {
                    t.pc += IRL!(IR.Wordboundary);
                    break;
                }
                else if(atEnd && s.loopBack(index).nextChar(back, bi)
                        && wordTrie[back])
                {
                    t.pc += IRL!(IR.Wordboundary);
                    break;
                }
                else if(s.loopBack(index).nextChar(back, bi))
                {
                    bool af = wordTrie[front];
                    bool ab = wordTrie[back];
                    if(af ^ ab)
                    {
                        t.pc += IRL!(IR.Wordboundary);
                        break;
                    }
                }
                recycle(t);
                t = worklist.fetch();
                if(!t)
                    return;
                break;
            case IR.Notwordboundary:
                dchar back;
                DataIndex bi;
                //at start & end of input
                if(atStart && wordTrie[front])
                {
                    recycle(t);
                    t = worklist.fetch();
                    if(!t)
                        return;
                    break;
                }
                else if(atEnd && s.loopBack(index).nextChar(back, bi)
                        && wordTrie[back])
                {
                    recycle(t);
                    t = worklist.fetch();
                    if(!t)
                        return;
                    break;
                }
                else if(s.loopBack(index).nextChar(back, bi))
                {
                    bool af = wordTrie[front];
                    bool ab = wordTrie[back]  != 0;
                    if(af ^ ab)
                    {
                        recycle(t);
                        t = worklist.fetch();
                        if(!t)
                            return;
                        break;
                    }
                }
                t.pc += IRL!(IR.Wordboundary);
                break;
            case IR.Bol:
                dchar back;
                DataIndex bi;
                if(atStart
                    ||( (re.flags & RegexOption.multiline)
                    && s.loopBack(index).nextChar(back,bi)
                    && startOfLine(back, front == '\n')))
                {
                    t.pc += IRL!(IR.Bol);
                }
                else
                {
                    recycle(t);
                    t = worklist.fetch();
                    if(!t)
                        return;
                }
                break;
            case IR.Eol:
                debug(std_regex_matcher) writefln("EOL (front 0x%x) %s",  front, s[index..s.lastIndex]);
                dchar back;
                DataIndex bi;
                //no matching inside \r\n
                if(atEnd || ((re.flags & RegexOption.multiline)
                    && endOfLine(front, s.loopBack(index).nextChar(back, bi)
                        && back == '\r')))
                {
                    t.pc += IRL!(IR.Eol);
                }
                else
                {
                    recycle(t);
                    t = worklist.fetch();
                    if(!t)
                        return;
                }
                break;
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
                                    t.pc, index, genCounter, merge[re.ir[t.pc + 1].raw+t.counter] );
                    merge[re.ir[t.pc + 1].raw+t.counter] = genCounter;
                }
                else
                {
                    debug(std_regex_matcher) writefln("A thread(pc=%s) got merged there : %s ; GenCounter=%s mergetab=%s",
                                    t.pc, index, genCounter, merge[re.ir[t.pc + 1].raw+t.counter] );
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
                                    t.pc, index, genCounter, merge[re.ir[t.pc + 1].raw+t.counter] );
                    merge[re.ir[t.pc + 1].raw+t.counter] = genCounter;
                }
                else
                {
                    debug(std_regex_matcher) writefln("A thread(pc=%s) got merged there : %s ; GenCounter=%s mergetab=%s",
                                    t.pc, index, genCounter, merge[re.ir[t.pc + 1].raw+t.counter] );
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
                static if(withInput)
                {
                    int test = quickTestFwd(pc1, front, re);
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
                                    t.pc, s[index .. s.lastIndex], genCounter, merge[re.ir[t.pc + 1].raw + t.counter] );
                    merge[re.ir[t.pc + 1].raw+t.counter] = genCounter;
                    t.pc += IRL!(IR.OrEnd);
                }
                else
                {
                    debug(std_regex_matcher) writefln("A thread(pc=%s) got merged there : %s ; GenCounter=%s mergetab=%s",
                                    t.pc, s[index .. s.lastIndex], genCounter, merge[re.ir[t.pc + 1].raw + t.counter] );
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
                t.matches.ptr[n].begin = index;
                t.pc += IRL!(IR.GroupStart);
                break;
            case IR.GroupEnd:
                uint n = re.ir[t.pc].data;
                t.matches.ptr[n].end = index;
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
                else static if(withInput)
                {
                    size_t idx = source[n].begin + t.uopCounter;
                    size_t end = source[n].end;
                    if(s[idx..end].front == front)
                    {
                        t.uopCounter += std.utf.stride(s[idx..end], 0);
                        if(t.uopCounter + source[n].begin == source[n].end)
                        {//last codepoint
                            t.pc += IRL!(IR.Backref);
                            t.uopCounter = 0;
                        }
                        nlist.insertBack(t);
                    }
                    else
                        recycle(t);
                    t = worklist.fetch();
                    if(!t)
                        return;
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
                    auto matcher = fwdMatcher(re.ir[t.pc .. end], subCounters.get(t.pc, 0));
                else
                    auto matcher = bwdMatcher(re.ir[t.pc .. end], subCounters.get(t.pc, 0));
                matcher.re.ngroup = me - ms;
                matcher.backrefed = backrefed.empty ? t.matches : backrefed;
                //backMatch
                auto mRes = matcher.matchOneShot(t.matches.ptr[ms .. me], IRL!(IR.LookbehindStart));
                freelist = matcher.freelist;
                subCounters[t.pc] = matcher.genCounter;
                if((mRes == MatchResult.Match) ^ positive)
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
                auto save = index;
                uint len = re.ir[t.pc].data;
                uint ms = re.ir[t.pc+1].raw, me = re.ir[t.pc+2].raw;
                uint end = t.pc+len+IRL!(IR.LookaheadEnd)+IRL!(IR.LookaheadStart);
                bool positive = re.ir[t.pc].code == IR.LookaheadStart;
                static if(Stream.isLoopback)
                    auto matcher = bwdMatcher(re.ir[t.pc .. end], subCounters.get(t.pc, 0));
                else
                    auto matcher = fwdMatcher(re.ir[t.pc .. end], subCounters.get(t.pc, 0));
                matcher.re.ngroup = me - ms;
                matcher.backrefed = backrefed.empty ? t.matches : backrefed;
                auto mRes = matcher.matchOneShot(t.matches.ptr[ms .. me], IRL!(IR.LookaheadStart));
                freelist = matcher.freelist;
                subCounters[t.pc] = matcher.genCounter;
                s.reset(index);
                next();
                if((mRes == MatchResult.Match) ^ positive)
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

                static if(withInput)
                {
            case IR.OrChar:
                      uint len = re.ir[t.pc].sequence;
                      uint end = t.pc + len;
                      static assert(IRL!(IR.OrChar) == 1);
                      for(; t.pc < end; t.pc++)
                          if(re.ir[t.pc].data == front)
                              break;
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
                      if(front == re.ir[t.pc].data)
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
                              && (front == '\r' || front == '\n'))
                          recycle(t);
                      else
                          nlist.insertBack(t);
                      t = worklist.fetch();
                      if(!t)
                          return;
                      break;
            case IR.CodepointSet:
                      if(re.charsets[re.ir[t.pc].data].scanFor(front))
                      {
                          t.pc += IRL!(IR.CodepointSet);
                          nlist.insertBack(t);
                      }
                      else
                      {
                          recycle(t);
                      }
                      t = worklist.fetch();
                      if(!t)
                          return;
                      break;
            case IR.Trie:
                      if(re.tries[re.ir[t.pc].data][front])
                      {
                          t.pc += IRL!(IR.Trie);
                          nlist.insertBack(t);
                      }
                      else
                      {
                          recycle(t);
                      }
                      t = worklist.fetch();
                      if(!t)
                          return;
                      break;
                  default:
                      assert(0, "Unrecognized instruction " ~ re.ir[t.pc].mnemonic);
                }
                else
                {
                    default:
                        recycle(t);
                        t = worklist.fetch();
                        if(!t)
                            return;
                }
            }
        }

    }
    enum uint RestartPc = uint.max;
    //match the input, evaluating IR without searching
    MatchResult matchOneShot(Group!DataIndex[] matches, uint startPc = 0)
    {
        debug(std_regex_matcher)
        {
            writefln("---------------single shot match ----------------- ");
        }
        alias evalFn = eval;
        assert(clist == (ThreadList!DataIndex).init || startPc == RestartPc); // incorrect after a partial match
        assert(nlist == (ThreadList!DataIndex).init || startPc == RestartPc);
        if(!atEnd)//if no char
        {
            debug(std_regex_matcher)
            {
                writefln("-- Threaded matching threads at  %s",  s[index..s.lastIndex]);
            }
            if(startPc!=RestartPc)
            {
                auto startT = createStart(index, startPc);
                genCounter++;
                evalFn!true(startT, matches);
            }
            for(;;)
            {
                debug(std_regex_matcher) writeln("\n-- Started iteration of main cycle");
                genCounter++;
                debug(std_regex_matcher)
                {
                    foreach(t; clist[])
                    {
                        assert(t);
                    }
                }
                for(Thread!DataIndex* t = clist.fetch(); t; t = clist.fetch())
                {
                    evalFn!true(t, matches);
                }
                if(nlist.empty)
                {
                    debug(std_regex_matcher) writeln("Stopped  matching before consuming full input");
                    break;//not a partial match for sure
                }
                clist = nlist;
                nlist = (ThreadList!DataIndex).init;
                if(!next())
                {
                    if (!atEnd) return MatchResult.PartialMatch;
                    break;
                }
                debug(std_regex_matcher) writeln("-- Ended iteration of main cycle\n");
            }
        }
        genCounter++; //increment also on each end
        debug(std_regex_matcher) writefln("-- Matching threads at end");
        //try out all zero-width posibilities
        for(Thread!DataIndex* t = clist.fetch(); t; t = clist.fetch())
        {
            evalFn!false(t, matches);
        }
        if(!matched)
            evalFn!false(createStart(index, startPc), matches);

        return (matched?MatchResult.Match:MatchResult.NoMatch);
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
