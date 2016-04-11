//Written in the D programming language
/*
    Implementation of a concept "NFA in a word" which is
    bit-parallel impementation of regex where each bit represents 
    a state in an NFA. Execution is Thompson-style achieved via bit tricks.

    There is a great number of limitations inlcuding not tracking any state (captures)
    and not supporting even basic assertions such as ^, $  or \b.
*/
import std.regex.internal.ir;

// since there is no way to mark a starting position
// need 2 instance of BitNfa - one to find the end, and the other
// to run backwards to find the start.
struct BitNfa
{
    uint        asciiTab[128];    // state mask for ascii characters
    UintTrie2   uniTab;           // state mask for unicode characters
    uint[uint]  controlFlow;      // maps each bit pattern to resulting jumps pattern
    uint        controlFlowMask;  // masks all control flow bits
    uint        finalMask;        // marks final states terminating the NFA

    bool opCall(Input)(ref Input r)
    {
        dchar ch;
        size_t idx;
        uint word = ~0u;
        while(r.nextChar(ch, idx)){
            word <<= 1; // shift - create a state
            // cfMask has 1 for each control-flow op
            uint cflow = ~word  & controlFlowMask; 
            word = word | controlFlowMask; // kill cflow
            word |= controlFlow[cflow]; // map normal ops
            if(word & finalMask != finalMask)
                return true;
            // mask away failing states
            if(ch < 0x80)
                word |= assciiTab[ch];
            else
                word |= uniTab[ch];
        }
        return false;
    }
}

final class BitMatcher
{
    BitNfa forward, backward;
    bool opCall(Input)(ref Input r)
    {
        bool res = forward(r);
        if(res){
            auto backward = r.loopBack
            backward(backward);
            r.reset(backward._index);
        }
        return res;
    }
}

