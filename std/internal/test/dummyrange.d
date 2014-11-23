/**
For testing only.
Used with the dummy ranges for testing higher order ranges.
*/
module std.internal.test.dummyrange;

import std.typecons;
import std.typetuple;
import std.range.primitives;

enum RangeType
{
    Input,
    Forward,
    Bidirectional,
    Random
}

enum Length
{
    Yes,
    No
}

enum ReturnBy
{
    Reference,
    Value
}

// Range that's useful for testing other higher order ranges,
// can be parametrized with attributes.  It just dumbs down an array of
// numbers 1..10.
struct DummyRange(ReturnBy _r, Length _l, RangeType _rt)
{
    // These enums are so that the template params are visible outside
    // this instantiation.
    enum r = _r;
    enum l = _l;
    enum rt = _rt;

    uint[] arr = [1U, 2U, 3U, 4U, 5U, 6U, 7U, 8U, 9U, 10U];

    void reinit()
    {
        // Workaround for DMD bug 4378
        arr = [1U, 2U, 3U, 4U, 5U, 6U, 7U, 8U, 9U, 10U];
    }

    void popFront()
    {
        arr = arr[1..$];
    }

    @property bool empty() const
    {
        return arr.length == 0;
    }

    static if(r == ReturnBy.Reference)
    {
        @property ref inout(uint) front() inout
        {
            return arr[0];
        }

        @property void front(uint val)
        {
            arr[0] = val;
        }
    }
    else
    {
        @property uint front() const
        {
            return arr[0];
        }
    }

    static if(rt >= RangeType.Forward)
    {
        @property typeof(this) save()
        {
            return this;
        }
    }

    static if(rt >= RangeType.Bidirectional)
    {
        void popBack()
        {
            arr = arr[0..$ - 1];
        }

        static if(r == ReturnBy.Reference)
        {
            @property ref inout(uint) back() inout
            {
                return arr[$ - 1];
            }

            @property void back(uint val)
            {
                arr[$ - 1] = val;
            }

        }
        else
        {
            @property uint back() const
            {
                return arr[$ - 1];
            }
        }
    }

    static if(rt >= RangeType.Random)
    {
        static if(r == ReturnBy.Reference)
        {
            ref inout(uint) opIndex(size_t index) inout
            {
                return arr[index];
            }

            void opIndexAssign(uint val, size_t index)
            {
                arr[index] = val;
            }
        }
        else
        {
            uint opIndex(size_t index) const
            {
                return arr[index];
            }
        }

        typeof(this) opSlice(size_t lower, size_t upper)
        {
            auto ret = this;
            ret.arr = arr[lower..upper];
            return ret;
        }
    }

    static if(l == Length.Yes)
    {
        @property size_t length() const
        {
            return arr.length;
        }

        alias opDollar = length;
    }
}

enum dummyLength = 10;

alias AllDummyRanges = TypeTuple!(
    DummyRange!(ReturnBy.Reference, Length.Yes, RangeType.Forward),
    DummyRange!(ReturnBy.Reference, Length.Yes, RangeType.Bidirectional),
    DummyRange!(ReturnBy.Reference, Length.Yes, RangeType.Random),
    DummyRange!(ReturnBy.Reference, Length.No, RangeType.Forward),
    DummyRange!(ReturnBy.Reference, Length.No, RangeType.Bidirectional),
    DummyRange!(ReturnBy.Value, Length.Yes, RangeType.Input),
    DummyRange!(ReturnBy.Value, Length.Yes, RangeType.Forward),
    DummyRange!(ReturnBy.Value, Length.Yes, RangeType.Bidirectional),
    DummyRange!(ReturnBy.Value, Length.Yes, RangeType.Random),
    DummyRange!(ReturnBy.Value, Length.No, RangeType.Input),
    DummyRange!(ReturnBy.Value, Length.No, RangeType.Forward),
    DummyRange!(ReturnBy.Value, Length.No, RangeType.Bidirectional)
);

/**
Tests whether forward, bidirectional and random access properties are
propagated properly from the base range(s) R to the higher order range
H.  Useful in combination with DummyRange for testing several higher
order ranges.
*/
template propagatesRangeType(H, R...) 
{
    static if(allSatisfy!(isRandomAccessRange, R))
        enum bool propagatesRangeType = isRandomAccessRange!H;
    else static if(allSatisfy!(isBidirectionalRange, R))
        enum bool propagatesRangeType = isBidirectionalRange!H;
    else static if(allSatisfy!(isForwardRange, R))
        enum bool propagatesRangeType = isForwardRange!H;
    else
        enum bool propagatesRangeType = isInputRange!H;
}

template propagatesLength(H, R...) 
{
    static if(allSatisfy!(hasLength, R))
        enum bool propagatesLength = hasLength!H;
    else
        enum bool propagatesLength = !hasLength!H;
}

/**
Reference type input range
*/
class ReferenceInputRange(T)
{
    import std.array : array;

    this(Range)(Range r) if (isInputRange!Range) {_payload = array(r);}
    final @property ref T front(){return _payload.front;}
    final void popFront(){_payload.popFront();}
    final @property bool empty(){return _payload.empty;}
    protected T[] _payload;
}

/**
Reference forward range
*/
class ReferenceForwardRange(T) : ReferenceInputRange!T
{
    this(Range)(Range r) if (isInputRange!Range) {super(r);}
    final @property ReferenceForwardRange save()
    {return new ReferenceForwardRange!T(_payload);}
}

//Infinite input range
class ReferenceInfiniteInputRange(T)
{
    this(T first = T.init) {_val = first;}
    final @property T front(){return _val;}
    final void popFront(){++_val;}
    enum bool empty = false;
    protected T _val;
}

//Infinite forward range
class ReferenceInfiniteForwardRange(T) : ReferenceInfiniteInputRange!T
{
    this(T first = T.init) {super(first);}
    final @property ReferenceInfiniteForwardRange save()
    {return new ReferenceInfiniteForwardRange!T(_val);}
}
