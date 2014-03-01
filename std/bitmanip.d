// Written in the D programming language.

/**
Bit-level manipulation facilities.

Macros:

WIKI = StdBitarray

Copyright: Copyright Digital Mars 2007 - 2011.
License:   <a href="http://www.boost.org/LICENSE_1_0.txt">Boost License 1.0</a>.
Authors:   $(WEB digitalmars.com, Walter Bright),
           $(WEB erdani.org, Andrei Alexandrescu),
           Jonathan M Davis,
           Alex Rønne Petersen,
           Damian Ziemba
Source: $(PHOBOSSRC std/_bitmanip.d)
*/
/*
         Copyright Digital Mars 2007 - 2012.
Distributed under the Boost Software License, Version 1.0.
   (See accompanying file LICENSE_1_0.txt or copy at
         http://www.boost.org/LICENSE_1_0.txt)
*/
module std.bitmanip;

//debug = bitarray;                // uncomment to turn on debugging printf's

import core.bitop;
import std.format;
import std.range;
import std.string;
import std.system;
import std.traits;

version(unittest)
{
    import std.stdio;
    import std.typetuple;
}


private string myToStringx(ulong n)
{
    enum s = "0123456789";
    if (n < 10)
        return s[cast(size_t)n..cast(size_t)n+1];
    else
        return myToStringx(n / 10) ~ myToStringx(n % 10);
}

private string myToString(ulong n)
{
    return myToStringx(n) ~ (n > uint.max ? "UL" : "U");
}

private template createAccessors(
    string store, T, string name, size_t len, size_t offset)
{
    static if (!name.length)
    {
        // No need to create any accessor
        enum result = "";
    }
    else static if (len == 0)
    {
        // Fields of length 0 are always zero
        enum result = "enum "~T.stringof~" "~name~" = 0;\n";
    }
    else
    {
        enum ulong
            maskAllElse = ((~0uL) >> (64 - len)) << offset,
            signBitCheck = 1uL << (len - 1);

        static if (T.min < 0)
        {
            enum long minVal = -(1uL << (len - 1));
            enum ulong maxVal = (1uL << (len - 1)) - 1;
            alias UT = Unsigned!(T);
            enum UT extendSign = cast(UT)~((~0uL) >> (64 - len));
        }
        else
        {
            enum ulong minVal = 0;
            enum ulong maxVal = (~0uL) >> (64 - len);
            enum extendSign = 0;
        }

        static if (is(T == bool))
        {
            static assert(len == 1);
            enum result =
            // getter
                "@property @safe bool " ~ name ~ "() pure nothrow const { return "
                ~"("~store~" & "~myToString(maskAllElse)~") != 0;}\n"
            // setter
                ~"@property @safe void " ~ name ~ "(bool v) pure nothrow {"
                ~"if (v) "~store~" |= "~myToString(maskAllElse)~";"
                ~"else "~store~" &= ~"~myToString(maskAllElse)~";}\n";
        }
        else
        {
            // getter
            enum result = "@property @safe "~T.stringof~" "~name~"() pure nothrow const { auto result = "
                ~"("~store~" & "
                ~ myToString(maskAllElse) ~ ") >>"
                ~ myToString(offset) ~ ";"
                ~ (T.min < 0
                   ? "if (result >= " ~ myToString(signBitCheck)
                   ~ ") result |= " ~ myToString(extendSign) ~ ";"
                   : "")
                ~ " return cast("~T.stringof~") result;}\n"
            // setter
                ~"@property @safe void "~name~"("~T.stringof~" v) pure nothrow { "
                ~"assert(v >= "~name~"_min); "
                ~"assert(v <= "~name~"_max); "
                ~store~" = cast(typeof("~store~"))"
                ~" (("~store~" & ~cast(typeof("~store~"))"~myToString(maskAllElse)~")"
                ~" | ((cast(typeof("~store~")) v << "~myToString(offset)~")"
                ~" & "~myToString(maskAllElse)~"));}\n"
            // constants
                ~"enum "~T.stringof~" "~name~"_min = cast("~T.stringof~")"
                ~myToString(minVal)~"; "
                ~" enum "~T.stringof~" "~name~"_max = cast("~T.stringof~")"
                ~myToString(maxVal)~"; ";
        }
    }
}

private template createStoreName(Ts...)
{
    static if (Ts.length < 2)
        enum createStoreName = "";
    else
        enum createStoreName = "_" ~ Ts[1] ~ createStoreName!(Ts[3 .. $]);
}

private template createFields(string store, size_t offset, Ts...)
{
    static if (!Ts.length)
    {
        static if (offset == ubyte.sizeof * 8)
            alias StoreType = ubyte;
        else static if (offset == ushort.sizeof * 8)
            alias StoreType = ushort;
        else static if (offset == uint.sizeof * 8)
            alias StoreType = uint;
        else static if (offset == ulong.sizeof * 8)
            alias StoreType = ulong;
        else
        {
            static assert(false, "Field widths must sum to 8, 16, 32, or 64");
            alias StoreType = ulong; // just to avoid another error msg
        }
        enum result = "private " ~ StoreType.stringof ~ " " ~ store ~ ";";
    }
    else
    {
        enum result
            = createAccessors!(store, Ts[0], Ts[1], Ts[2], offset).result
            ~ createFields!(store, offset + Ts[2], Ts[3 .. $]).result;
    }
}

/**
Allows creating bit fields inside $(D_PARAM struct)s and $(D_PARAM
class)es.

Example:

----
struct A
{
    int a;
    mixin(bitfields!(
        uint, "x",    2,
        int,  "y",    3,
        uint, "z",    2,
        bool, "flag", 1));
}
A obj;
obj.x = 2;
obj.z = obj.x;
----

The example above creates a bitfield pack of eight bits, which fit in
one $(D_PARAM ubyte). The bitfields are allocated starting from the
least significant bit, i.e. x occupies the two least significant bits
of the bitfields storage.

The sum of all bit lengths in one $(D_PARAM bitfield) instantiation
must be exactly 8, 16, 32, or 64. If padding is needed, just allocate
one bitfield with an empty name.

Example:

----
struct A
{
    mixin(bitfields!(
        bool, "flag1",    1,
        bool, "flag2",    1,
        uint, "",         6));
}
----

The type of a bit field can be any integral type or enumerated
type. The most efficient type to store in bitfields is $(D_PARAM
bool), followed by unsigned types, followed by signed types.
*/

template bitfields(T...)
{
    enum { bitfields = createFields!(createStoreName!(T), 0, T).result }
}

unittest
{
    // Degenerate bitfields (#8474 / #11160) tests mixed with range tests
    struct Test1
    {
        mixin(bitfields!(uint, "a", 32,
                        uint, "b", 4,
                        uint, "c", 4,
                        uint, "d", 8,
                        uint, "e", 16,));

        static assert(Test1.b_min == 0);
        static assert(Test1.b_max == 15);
    }

    struct Test2
    {
        mixin(bitfields!(bool, "a", 0,
                        ulong, "b", 64));

        static assert(Test2.b_min == ulong.min);
        static assert(Test2.b_max == ulong.max);
    }

    struct Test1b
    {
        mixin(bitfields!(bool, "a", 0,
                        int, "b", 8));
    }

    struct Test2b
    {
        mixin(bitfields!(int, "a", 32,
                        int, "b", 4,
                        int, "c", 4,
                        int, "d", 8,
                        int, "e", 16,));

        static assert(Test2b.b_min == -8);
        static assert(Test2b.b_max == 7);
    }

    struct Test3b
    {
        mixin(bitfields!(bool, "a", 0,
                        long, "b", 64));

        static assert(Test3b.b_min == long.min);
        static assert(Test3b.b_max == long.max);
    }

    struct Test4b
    {
        mixin(bitfields!(long, "a", 32,
                        int, "b", 32));
    }

    // Sign extension tests
    Test2b t2b;
    Test4b t4b;
    t2b.b = -5; assert(t2b.b == -5);
    t2b.d = -5; assert(t2b.d == -5);
    t2b.e = -5; assert(t2b.e == -5);
    t4b.a = -5; assert(t4b.a == -5L);
}

unittest
{
    // Bug #6686
    union  S {
        ulong bits = ulong.max;
        mixin (bitfields!(
            ulong, "back",  31,
            ulong, "front", 33)
        );
    }
    S num;

    num.bits = ulong.max;
    num.back = 1;
    assert(num.bits == 0xFFFF_FFFF_8000_0001uL);
}

unittest
{
    // Bug #5942
    struct S
    {
        mixin(bitfields!(
            int, "a" , 32,
            int, "b" , 32
        ));
    }

    S data;
    data.b = 42;
    data.a = 1;
    assert(data.b == 42);
}

unittest
{
    struct Test
    {
        mixin(bitfields!(bool, "a", 1,
                         uint, "b", 3,
                         short, "c", 4));
    }

    @safe void test() pure nothrow
    {
        Test t;

        t.a = true;
        t.b = 5;
        t.c = 2;

        assert(t.a);
        assert(t.b == 5);
        assert(t.c == 2);
    }

    test();
}

unittest
{
    {
        static struct Integrals {
            bool checkExpectations(bool eb, int ei, short es) { return b == eb && i == ei && s == es; }

            mixin(bitfields!(
                      bool, "b", 1,
                      uint, "i", 3,
                      short, "s", 4));
        }
        Integrals i;
        assert(i.checkExpectations(false, 0, 0));
        i.b = true;
        assert(i.checkExpectations(true, 0, 0));
        i.i = 7;
        assert(i.checkExpectations(true, 7, 0));
        i.s = -8;
        assert(i.checkExpectations(true, 7, -8));
        i.s = 7;
        assert(i.checkExpectations(true, 7, 7));
    }

    //Bug# 8876
    {
        struct MoreIntegrals {
            bool checkExpectations(uint eu, ushort es, uint ei) { return u == eu && s == es && i == ei; }

            mixin(bitfields!(
                  uint, "u", 24,
                  short, "s", 16,
                  int, "i", 24));
        }

        MoreIntegrals i;
        assert(i.checkExpectations(0, 0, 0));
        i.s = 20;
        assert(i.checkExpectations(0, 20, 0));
        i.i = 72;
        assert(i.checkExpectations(0, 20, 72));
        i.u = 8;
        assert(i.checkExpectations(8, 20, 72));
        i.s = 7;
        assert(i.checkExpectations(8, 7, 72));
    }

    enum A { True, False }
    enum B { One, Two, Three, Four }
    static struct Enums {
        bool checkExpectations(A ea, B eb) { return a == ea && b == eb; }

        mixin(bitfields!(
                  A, "a", 1,
                  B, "b", 2,
                  uint, "", 5));
    }
    Enums e;
    assert(e.checkExpectations(A.True, B.One));
    e.a = A.False;
    assert(e.checkExpectations(A.False, B.One));
    e.b = B.Three;
    assert(e.checkExpectations(A.False, B.Three));

    static struct SingleMember {
        bool checkExpectations(bool eb) { return b == eb; }

        mixin(bitfields!(
                  bool, "b", 1,
                  uint, "", 7));
    }
    SingleMember f;
    assert(f.checkExpectations(false));
    f.b = true;
    assert(f.checkExpectations(true));
}

/**
   Allows manipulating the fraction, exponent, and sign parts of a
   $(D_PARAM float) separately. The definition is:

----
struct FloatRep
{
    union
    {
        float value;
        mixin(bitfields!(
                  uint,  "fraction", 23,
                  ubyte, "exponent",  8,
                  bool,  "sign",      1));
    }
    enum uint bias = 127, fractionBits = 23, exponentBits = 8, signBits = 1;
}
----
*/

struct FloatRep
{
    union
    {
        float value;
        mixin(bitfields!(
                  uint,  "fraction", 23,
                  ubyte, "exponent",  8,
                  bool,  "sign",      1));
    }
    enum uint bias = 127, fractionBits = 23, exponentBits = 8, signBits = 1;
}

/**
   Allows manipulating the fraction, exponent, and sign parts of a
   $(D_PARAM double) separately. The definition is:

----
struct DoubleRep
{
    union
    {
        double value;
        mixin(bitfields!(
                  ulong,   "fraction", 52,
                  ushort,  "exponent", 11,
                  bool,    "sign",      1));
    }
    enum uint bias = 1023, signBits = 1, fractionBits = 52, exponentBits = 11;
}
----
*/

struct DoubleRep
{
    union
    {
        double value;
        mixin(bitfields!(
                  ulong,  "fraction", 52,
                  ushort, "exponent", 11,
                  bool,   "sign",      1));
    }
    enum uint bias = 1023, signBits = 1, fractionBits = 52, exponentBits = 11;
}

unittest
{
    // test reading
    DoubleRep x;
    x.value = 1.0;
    assert(x.fraction == 0 && x.exponent == 1023 && !x.sign);
    x.value = -0.5;
    assert(x.fraction == 0 && x.exponent == 1022 && x.sign);
    x.value = 0.5;
    assert(x.fraction == 0 && x.exponent == 1022 && !x.sign);

    // test writing
    x.fraction = 1125899906842624;
    x.exponent = 1025;
    x.sign = true;
    assert(x.value == -5.0);

    // test enums
    enum ABC { A, B, C }
    struct EnumTest
    {
        mixin(bitfields!(
                  ABC, "x", 2,
                  bool, "y", 1,
                  ubyte, "z", 5));
    }
}

/**
 * An array of bits.
 */

struct BitArray
{
    size_t len;
    size_t* ptr;
    enum bitsPerSizeT = size_t.sizeof * 8;

    /**********************************************
     * Gets the amount of native words backing this $(D BitArray).
     */
    @property const size_t dim()
    {
        return (len + (bitsPerSizeT-1)) / bitsPerSizeT;
    }

    /**********************************************
     * Gets the amount of bits in the $(D BitArray).
     */
    @property const size_t length()
    {
        return len;
    }

    /**********************************************
     * Sets the amount of bits in the $(D BitArray).
     */
    @property size_t length(size_t newlen)
    {
        if (newlen != len)
        {
            size_t olddim = dim;
            size_t newdim = (newlen + (bitsPerSizeT-1)) / bitsPerSizeT;

            if (newdim != olddim)
            {
                // Create a fake array so we can use D's realloc machinery
                auto b = ptr[0 .. olddim];
                b.length = newdim;                // realloc
                ptr = b.ptr;
                if (newdim & (bitsPerSizeT-1))
                {   // Set any pad bits to 0
                    ptr[newdim - 1] &= ~(~0 << (newdim & (bitsPerSizeT-1)));
                }
            }

            len = newlen;
        }
        return len;
    }

    /**********************************************
     * Gets the $(D i)'th bit in the $(D BitArray).
     */
    bool opIndex(size_t i) const
    in
    {
        assert(i < len);
    }
    body
    {
        // Andrei: review for @@@64-bit@@@
        return cast(bool) bt(ptr, i);
    }

    unittest
    {
        void Fun(const BitArray arr)
        {
            auto x = arr[0];
            assert(x == 1);
        }
        BitArray a;
        a.length = 3;
        a[0] = 1;
        Fun(a);
    }

    /**********************************************
     * Sets the $(D i)'th bit in the $(D BitArray).
     */
    bool opIndexAssign(bool b, size_t i)
    in
    {
        assert(i < len);
    }
    body
    {
        if (b)
            bts(ptr, i);
        else
            btr(ptr, i);
        return b;
    }

    /**********************************************
     * Duplicates the $(D BitArray) and its contents.
     */
    @property BitArray dup() const
    {
        BitArray ba;

        auto b = ptr[0 .. dim].dup;
        ba.len = len;
        ba.ptr = b.ptr;
        return ba;
    }

    unittest
    {
        BitArray a;
        BitArray b;
        int i;

        debug(bitarray) printf("BitArray.dup.unittest\n");

        a.length = 3;
        a[0] = 1; a[1] = 0; a[2] = 1;
        b = a.dup;
        assert(b.length == 3);
        for (i = 0; i < 3; i++)
        {   debug(bitarray) printf("b[%d] = %d\n", i, b[i]);
            assert(b[i] == (((i ^ 1) & 1) ? true : false));
        }
    }

    /**********************************************
     * Support for $(D foreach) loops for $(D BitArray).
     */
    int opApply(scope int delegate(ref bool) dg)
    {
        int result;

        for (size_t i = 0; i < len; i++)
        {
            bool b = opIndex(i);
            result = dg(b);
            this[i] = b;
            if (result)
                break;
        }
        return result;
    }

    /** ditto */
    int opApply(scope int delegate(bool) dg) const
    {
        int result;

        for (size_t i = 0; i < len; i++)
        {
            bool b = opIndex(i);
            result = dg(b);
            if (result)
                break;
        }
        return result;
    }

    /** ditto */
    int opApply(scope int delegate(ref size_t, ref bool) dg)
    {
        int result;

        for (size_t i = 0; i < len; i++)
        {
            bool b = opIndex(i);
            result = dg(i, b);
            this[i] = b;
            if (result)
                break;
        }
        return result;
    }

    /** ditto */
    int opApply(scope int delegate(size_t, bool) dg) const
    {
        int result;

        for (size_t i = 0; i < len; i++)
        {
            bool b = opIndex(i);
            result = dg(i, b);
            if (result)
                break;
        }
        return result;
    }

    unittest
    {
        debug(bitarray) printf("BitArray.opApply unittest\n");

        static bool[] ba = [1,0,1];

        BitArray a; a.init(ba);

        int i;
        foreach (b;a)
        {
            switch (i)
            {
                case 0: assert(b == true); break;
                case 1: assert(b == false); break;
                case 2: assert(b == true); break;
                default: assert(0);
            }
            i++;
        }

        foreach (j,b;a)
        {
            switch (j)
            {
                case 0: assert(b == true); break;
                case 1: assert(b == false); break;
                case 2: assert(b == true); break;
                default: assert(0);
            }
        }
    }


    /**********************************************
     * Reverses the bits of the $(D BitArray).
     */
    @property BitArray reverse()
    out (result)
    {
        assert(result == this);
    }
    body
    {
        if (len >= 2)
        {
            bool t;
            size_t lo, hi;

            lo = 0;
            hi = len - 1;
            for (; lo < hi; lo++, hi--)
            {
                t = this[lo];
                this[lo] = this[hi];
                this[hi] = t;
            }
        }
        return this;
    }

    unittest
    {
        debug(bitarray) printf("BitArray.reverse.unittest\n");

        BitArray b;
        static bool[5] data = [1,0,1,1,0];
        int i;

        b.init(data);
        b.reverse;
        for (i = 0; i < data.length; i++)
        {
            assert(b[i] == data[4 - i]);
        }
    }


    /**********************************************
     * Sorts the $(D BitArray)'s elements.
     */
    @property BitArray sort()
    out (result)
    {
        assert(result == this);
    }
    body
    {
        if (len >= 2)
        {
            size_t lo, hi;

            lo = 0;
            hi = len - 1;
            while (1)
            {
                while (1)
                {
                    if (lo >= hi)
                        goto Ldone;
                    if (this[lo] == true)
                        break;
                    lo++;
                }

                while (1)
                {
                    if (lo >= hi)
                        goto Ldone;
                    if (this[hi] == false)
                        break;
                    hi--;
                }

                this[lo] = false;
                this[hi] = true;

                lo++;
                hi--;
            }
        }
    Ldone:
        return this;
    }

    unittest
    {
        debug(bitarray) printf("BitArray.sort.unittest\n");

        __gshared size_t x = 0b1100011000;
        __gshared BitArray ba = { 10, &x };
        ba.sort;
        for (size_t i = 0; i < 6; i++)
            assert(ba[i] == false);
        for (size_t i = 6; i < 10; i++)
            assert(ba[i] == true);
    }


    /***************************************
     * Support for operators == and != for $(D BitArray).
     */
    const bool opEquals(const ref BitArray a2)
    {
        int i;

        if (this.length != a2.length)
            return 0;                // not equal
        auto p1 = this.ptr;
        auto p2 = a2.ptr;
        auto n = this.length / bitsPerSizeT;
        for (i = 0; i < n; i++)
        {
            if (p1[i] != p2[i])
                return 0;                // not equal
        }

        n = this.length & (bitsPerSizeT-1);
        size_t mask = (1 << n) - 1;
        //printf("i = %d, n = %d, mask = %x, %x, %x\n", i, n, mask, p1[i], p2[i]);
        return (mask == 0) || (p1[i] & mask) == (p2[i] & mask);
    }

    unittest
    {
        debug(bitarray) printf("BitArray.opEquals unittest\n");

        static bool[] ba = [1,0,1,0,1];
        static bool[] bb = [1,0,1];
        static bool[] bc = [1,0,1,0,1,0,1];
        static bool[] bd = [1,0,1,1,1];
        static bool[] be = [1,0,1,0,1];

        BitArray a; a.init(ba);
        BitArray b; b.init(bb);
        BitArray c; c.init(bc);
        BitArray d; d.init(bd);
        BitArray e; e.init(be);

        assert(a != b);
        assert(a != c);
        assert(a != d);
        assert(a == e);
    }

    /***************************************
     * Supports comparison operators for $(D BitArray).
     */
    int opCmp(BitArray a2) const
    {
        uint i;

        auto len = this.length;
        if (a2.length < len)
            len = a2.length;
        auto p1 = this.ptr;
        auto p2 = a2.ptr;
        auto n = len / bitsPerSizeT;
        for (i = 0; i < n; i++)
        {
            if (p1[i] != p2[i])
                break;                // not equal
        }
        for (size_t j = 0; j < len-i * bitsPerSizeT; j++)
        {
            size_t mask = cast(size_t)(1 << j);
            auto c = (cast(long)(p1[i] & mask) - cast(long)(p2[i] & mask));
            if (c)
                return c > 0 ? 1 : -1;
        }
        return cast(int)this.len - cast(int)a2.length;
    }

    unittest
    {
        debug(bitarray) printf("BitArray.opCmp unittest\n");

        static bool[] ba = [1,0,1,0,1];
        static bool[] bb = [1,0,1];
        static bool[] bc = [1,0,1,0,1,0,1];
        static bool[] bd = [1,0,1,1,1];
        static bool[] be = [1,0,1,0,1];

        BitArray a; a.init(ba);
        BitArray b; b.init(bb);
        BitArray c; c.init(bc);
        BitArray d; d.init(bd);
        BitArray e; e.init(be);

        assert(a >  b);
        assert(a >= b);
        assert(a <  c);
        assert(a <= c);
        assert(a <  d);
        assert(a <= d);
        assert(a == e);
        assert(a <= e);
        assert(a >= e);

        bool[] v;
        for (int i = 1; i < 256; i++)
        {
            v.length = i;
            v[] = false;
            BitArray x; x.init(v);
            v[i-1] = true;
            BitArray y; y.init(v);
            assert(x < y);
            assert(x <= y);
        }
    }

    /***************************************
     * Support for hashing for $(D BitArray).
     */
    size_t toHash() const pure nothrow
    {
        size_t hash = 3557;
        auto n  = len / 8;
        for (int i = 0; i < n; i++)
        {
            hash *= 3559;
            hash += (cast(byte*)this.ptr)[i];
        }
        for (size_t i = 8*n; i < len; i++)
        {
            hash *= 3571;
            hash += bt(this.ptr, i);
        }
        return hash;
    }

    /***************************************
     * Set this $(D BitArray) to the contents of $(D ba).
     */
    void init(bool[] ba)
    {
        length = ba.length;
        foreach (i, b; ba)
        {
            this[i] = b;
        }
    }


    /***************************************
     * Map the $(D BitArray) onto $(D v), with $(D numbits) being the number of bits
     * in the array. Does not copy the data. $(D v.length) must be a multiple of
     * $(D size_t.sizeof). If there are unmapped bits in the final mapped word then
     * these will be set to 0.
     *
     * This is the inverse of $(D opCast).
     */
    void init(void[] v, size_t numbits)
    in
    {
        assert(numbits <= v.length * 8);
        assert(v.length % size_t.sizeof == 0);
    }
    body
    {
        ptr = cast(size_t*)v.ptr;
        len = numbits;
        size_t finalBits = len % bitsPerSizeT;
        if (finalBits != 0)
        {
            // Need to mask away extraneous bits from v.
            ptr[dim - 1] &= (cast(size_t)1 << finalBits) - 1;
        }
    }

    unittest
    {
        debug(bitarray) printf("BitArray.init unittest\n");

        static bool[] ba = [1,0,1,0,1];

        BitArray a; a.init(ba);
        BitArray b;
        void[] v;

        v = cast(void[])a;
        b.init(v, a.length);

        assert(b[0] == 1);
        assert(b[1] == 0);
        assert(b[2] == 1);
        assert(b[3] == 0);
        assert(b[4] == 1);

        a[0] = 0;
        assert(b[0] == 0);

        assert(a == b);
    }

    /***************************************
     * Convert to $(D void[]).
     */
    void[] opCast(T : void[])()
    {
        return cast(void[])ptr[0 .. dim];
    }

    /***************************************
     * Convert to $(D size_t[]).
     */
    size_t[] opCast(T : size_t[])()
    {
        return ptr[0 .. dim];
    }

    unittest
    {
        debug(bitarray) printf("BitArray.opCast unittest\n");

        static bool[] ba = [1,0,1,0,1];

        BitArray a; a.init(ba);
        void[] v = cast(void[])a;

        assert(v.length == a.dim * size_t.sizeof);
    }

    /***************************************
     * Support for unary operator ~ for $(D BitArray).
     */
    BitArray opCom()
    {
        auto dim = this.dim;

        BitArray result;

        result.length = len;
        for (size_t i = 0; i < dim; i++)
            result.ptr[i] = ~this.ptr[i];
        if (len & (bitsPerSizeT-1))
            result.ptr[dim - 1] &= ~(~0 << (len & (bitsPerSizeT-1)));
        return result;
    }

    unittest
    {
        debug(bitarray) printf("BitArray.opCom unittest\n");

        static bool[] ba = [1,0,1,0,1];

        BitArray a; a.init(ba);
        BitArray b = ~a;

        assert(b[0] == 0);
        assert(b[1] == 1);
        assert(b[2] == 0);
        assert(b[3] == 1);
        assert(b[4] == 0);
    }


    /***************************************
     * Support for binary operator & for $(D BitArray).
     */
    BitArray opAnd(BitArray e2)
    in
    {
        assert(len == e2.length);
    }
    body
    {
        auto dim = this.dim;

        BitArray result;

        result.length = len;
        for (size_t i = 0; i < dim; i++)
            result.ptr[i] = this.ptr[i] & e2.ptr[i];
        return result;
    }

    unittest
    {
        debug(bitarray) printf("BitArray.opAnd unittest\n");

        static bool[] ba = [1,0,1,0,1];
        static bool[] bb = [1,0,1,1,0];

        BitArray a; a.init(ba);
        BitArray b; b.init(bb);

        BitArray c = a & b;

        assert(c[0] == 1);
        assert(c[1] == 0);
        assert(c[2] == 1);
        assert(c[3] == 0);
        assert(c[4] == 0);
    }


    /***************************************
     * Support for binary operator | for $(D BitArray).
     */
    BitArray opOr(BitArray e2) const
    in
    {
        assert(len == e2.length);
    }
    body
    {
        auto dim = this.dim;

        BitArray result;

        result.length = len;
        for (size_t i = 0; i < dim; i++)
            result.ptr[i] = this.ptr[i] | e2.ptr[i];
        return result;
    }

    unittest
    {
        debug(bitarray) printf("BitArray.opOr unittest\n");

        static bool[] ba = [1,0,1,0,1];
        static bool[] bb = [1,0,1,1,0];

        BitArray a; a.init(ba);
        BitArray b; b.init(bb);

        BitArray c = a | b;

        assert(c[0] == 1);
        assert(c[1] == 0);
        assert(c[2] == 1);
        assert(c[3] == 1);
        assert(c[4] == 1);
    }


    /***************************************
     * Support for binary operator ^ for $(D BitArray).
     */
    BitArray opXor(BitArray e2) const
    in
    {
        assert(len == e2.length);
    }
    body
    {
        auto dim = this.dim;

        BitArray result;

        result.length = len;
        for (size_t i = 0; i < dim; i++)
            result.ptr[i] = this.ptr[i] ^ e2.ptr[i];
        return result;
    }

    unittest
    {
        debug(bitarray) printf("BitArray.opXor unittest\n");

        static bool[] ba = [1,0,1,0,1];
        static bool[] bb = [1,0,1,1,0];

        BitArray a; a.init(ba);
        BitArray b; b.init(bb);

        BitArray c = a ^ b;

        assert(c[0] == 0);
        assert(c[1] == 0);
        assert(c[2] == 0);
        assert(c[3] == 1);
        assert(c[4] == 1);
    }


    /***************************************
     * Support for binary operator - for $(D BitArray).
     *
     * $(D a - b) for $(D BitArray) means the same thing as $(D a &amp; ~b).
     */
    BitArray opSub(BitArray e2) const
    in
    {
        assert(len == e2.length);
    }
    body
    {
        auto dim = this.dim;

        BitArray result;

        result.length = len;
        for (size_t i = 0; i < dim; i++)
            result.ptr[i] = this.ptr[i] & ~e2.ptr[i];
        return result;
    }

    unittest
    {
        debug(bitarray) printf("BitArray.opSub unittest\n");

        static bool[] ba = [1,0,1,0,1];
        static bool[] bb = [1,0,1,1,0];

        BitArray a; a.init(ba);
        BitArray b; b.init(bb);

        BitArray c = a - b;

        assert(c[0] == 0);
        assert(c[1] == 0);
        assert(c[2] == 0);
        assert(c[3] == 0);
        assert(c[4] == 1);
    }


    /***************************************
     * Support for operator &= for $(D BitArray).
     */
    BitArray opAndAssign(BitArray e2)
    in
    {
        assert(len == e2.length);
    }
    body
    {
        auto dim = this.dim;

        for (size_t i = 0; i < dim; i++)
            ptr[i] &= e2.ptr[i];
        return this;
    }

    unittest
    {
        debug(bitarray) printf("BitArray.opAndAssign unittest\n");

        static bool[] ba = [1,0,1,0,1];
        static bool[] bb = [1,0,1,1,0];

        BitArray a; a.init(ba);
        BitArray b; b.init(bb);

        a &= b;
        assert(a[0] == 1);
        assert(a[1] == 0);
        assert(a[2] == 1);
        assert(a[3] == 0);
        assert(a[4] == 0);
    }


    /***************************************
     * Support for operator |= for $(D BitArray).
     */
    BitArray opOrAssign(BitArray e2)
    in
    {
        assert(len == e2.length);
    }
    body
    {
        auto dim = this.dim;

        for (size_t i = 0; i < dim; i++)
            ptr[i] |= e2.ptr[i];
        return this;
    }

    unittest
    {
        debug(bitarray) printf("BitArray.opOrAssign unittest\n");

        static bool[] ba = [1,0,1,0,1];
        static bool[] bb = [1,0,1,1,0];

        BitArray a; a.init(ba);
        BitArray b; b.init(bb);

        a |= b;
        assert(a[0] == 1);
        assert(a[1] == 0);
        assert(a[2] == 1);
        assert(a[3] == 1);
        assert(a[4] == 1);
    }

    /***************************************
     * Support for operator ^= for $(D BitArray).
     */
    BitArray opXorAssign(BitArray e2)
    in
    {
        assert(len == e2.length);
    }
    body
    {
        auto dim = this.dim;

        for (size_t i = 0; i < dim; i++)
            ptr[i] ^= e2.ptr[i];
        return this;
    }

    unittest
    {
        debug(bitarray) printf("BitArray.opXorAssign unittest\n");

        static bool[] ba = [1,0,1,0,1];
        static bool[] bb = [1,0,1,1,0];

        BitArray a; a.init(ba);
        BitArray b; b.init(bb);

        a ^= b;
        assert(a[0] == 0);
        assert(a[1] == 0);
        assert(a[2] == 0);
        assert(a[3] == 1);
        assert(a[4] == 1);
    }

    /***************************************
     * Support for operator -= for $(D BitArray).
     *
     * $(D a -= b) for $(D BitArray) means the same thing as $(D a &amp;= ~b).
     */
    BitArray opSubAssign(BitArray e2)
    in
    {
        assert(len == e2.length);
    }
    body
    {
        auto dim = this.dim;

        for (size_t i = 0; i < dim; i++)
            ptr[i] &= ~e2.ptr[i];
        return this;
    }

    unittest
    {
        debug(bitarray) printf("BitArray.opSubAssign unittest\n");

        static bool[] ba = [1,0,1,0,1];
        static bool[] bb = [1,0,1,1,0];

        BitArray a; a.init(ba);
        BitArray b; b.init(bb);

        a -= b;
        assert(a[0] == 0);
        assert(a[1] == 0);
        assert(a[2] == 0);
        assert(a[3] == 0);
        assert(a[4] == 1);
    }

    /***************************************
     * Support for operator ~= for $(D BitArray).
     */

    BitArray opCatAssign(bool b)
    {
        length = len + 1;
        this[len - 1] = b;
        return this;
    }

    unittest
    {
        debug(bitarray) printf("BitArray.opCatAssign unittest\n");

        static bool[] ba = [1,0,1,0,1];

        BitArray a; a.init(ba);
        BitArray b;

        b = (a ~= true);
        assert(a[0] == 1);
        assert(a[1] == 0);
        assert(a[2] == 1);
        assert(a[3] == 0);
        assert(a[4] == 1);
        assert(a[5] == 1);

        assert(b == a);
    }

    /***************************************
     * ditto
     */

    BitArray opCatAssign(BitArray b)
    {
        auto istart = len;
        length = len + b.length;
        for (auto i = istart; i < len; i++)
            this[i] = b[i - istart];
        return this;
    }

    unittest
    {
        debug(bitarray) printf("BitArray.opCatAssign unittest\n");

        static bool[] ba = [1,0];
        static bool[] bb = [0,1,0];

        BitArray a; a.init(ba);
        BitArray b; b.init(bb);
        BitArray c;

        c = (a ~= b);
        assert(a.length == 5);
        assert(a[0] == 1);
        assert(a[1] == 0);
        assert(a[2] == 0);
        assert(a[3] == 1);
        assert(a[4] == 0);

        assert(c == a);
    }

    /***************************************
     * Support for binary operator ~ for $(D BitArray).
     */
    BitArray opCat(bool b) const
    {
        BitArray r;

        r = this.dup;
        r.length = len + 1;
        r[len] = b;
        return r;
    }

    /** ditto */
    BitArray opCat_r(bool b) const
    {
        BitArray r;

        r.length = len + 1;
        r[0] = b;
        for (size_t i = 0; i < len; i++)
            r[1 + i] = this[i];
        return r;
    }

    /** ditto */
    BitArray opCat(BitArray b) const
    {
        BitArray r;

        r = this.dup;
        r ~= b;
        return r;
    }

    unittest
    {
        debug(bitarray) printf("BitArray.opCat unittest\n");

        static bool[] ba = [1,0];
        static bool[] bb = [0,1,0];

        BitArray a; a.init(ba);
        BitArray b; b.init(bb);
        BitArray c;

        c = (a ~ b);
        assert(c.length == 5);
        assert(c[0] == 1);
        assert(c[1] == 0);
        assert(c[2] == 0);
        assert(c[3] == 1);
        assert(c[4] == 0);

        c = (a ~ true);
        assert(c.length == 3);
        assert(c[0] == 1);
        assert(c[1] == 0);
        assert(c[2] == 1);

        c = (false ~ a);
        assert(c.length == 3);
        assert(c[0] == 0);
        assert(c[1] == 1);
        assert(c[2] == 0);
    }

    /***************************************
     * Return a string representation of this BitArray.
     *
     * Two format specifiers are supported:
     * $(LI $(B %s) which prints the bits as an array, and)
     * $(LI $(B %b) which prints the bits as 8-bit byte packets)
     * separated with an underscore.
     */
    void toString(scope void delegate(const(char)[]) sink,
                  FormatSpec!char fmt) const
    {
        switch(fmt.spec)
        {
            case 'b':
                return formatBitString(sink);
            case 's':
                return formatBitArray(sink);
            default:
                throw new Exception("Unknown format specifier: %" ~ fmt.spec);
        }
    }

    ///
    unittest
    {
        debug(bitarray) printf("BitArray.toString unittest\n");
        BitArray b;
        b.init([0, 0, 0, 0, 1, 1, 1, 1, 0, 0, 0, 0, 1, 1, 1, 1]);

        auto s1 = format("%s", b);
        assert(s1 == "[0, 0, 0, 0, 1, 1, 1, 1, 0, 0, 0, 0, 1, 1, 1, 1]");

        auto s2 = format("%b", b);
        assert(s2 == "00001111_00001111");
    }

    /***************************************
     * Return a lazy range of the indices of set bits.
     */
    @property auto bitsSet()
    {
        return iota(dim).
               filter!(i => ptr[i]).
               map!(i => BitsSet!size_t(ptr[i], i * bitsPerSizeT)).
               joiner();
    }

    ///
    unittest
    {
        BitArray b1;
        b1.init([0, 0, 0, 0, 1, 1, 1, 1, 0, 0, 0, 0, 1, 1, 1, 1]);
        assert(b1.bitsSet.equal([4, 5, 6, 7, 12, 13, 14, 15]));

        BitArray b2;
        b2.length = 1000;
        b2[333] = true;
        b2[666] = true;
        b2[999] = true;
        assert(b2.bitsSet.equal([333, 666, 999]));
    }

    unittest
    {
        debug(bitarray) printf("BitArray.bitsSet unittest\n");
        BitArray b;
        enum wordBits = size_t.sizeof * 8;
        b.init([size_t.max], 0);
        assert(b.bitsSet.empty);
        b.init([size_t.max], 1);
        assert(b.bitsSet.equal([0]));
        b.init([size_t.max], wordBits);
        assert(b.bitsSet.equal(iota(wordBits)));
        b.init([size_t.max, size_t.max], wordBits);
        assert(b.bitsSet.equal(iota(wordBits)));
        b.init([size_t.max, size_t.max], wordBits + 1);
        assert(b.bitsSet.equal(iota(wordBits + 1)));
        b.init([size_t.max, size_t.max], wordBits * 2);
        assert(b.bitsSet.equal(iota(wordBits * 2)));
    }

    private void formatBitString(scope void delegate(const(char)[]) sink) const
    {
        if (!length)
            return;

        auto leftover = len % 8;
        foreach (idx; 0 .. leftover)
        {
            char[1] res = cast(char)(bt(ptr, idx) + '0');
            sink.put(res[]);
        }

        if (leftover && len > 8)
            sink.put("_");

        size_t count;
        foreach (idx; leftover .. len)
        {
            char[1] res = cast(char)(bt(ptr, idx) + '0');
            sink.put(res[]);
            if (++count == 8 && idx != len - 1)
            {
                sink.put("_");
                count = 0;
            }
        }
    }

    private void formatBitArray(scope void delegate(const(char)[]) sink) const
    {
        sink("[");
        foreach (idx; 0 .. len)
        {
            char[1] res = cast(char)(bt(ptr, idx) + '0');
            sink(res[]);
            if (idx+1 < len)
                sink(", ");
        }
        sink("]");
    }
}

unittest
{
    BitArray b;

    b.init([]);
    assert(format("%s", b) == "[]");
    assert(format("%b", b) is null);

    b.init([1]);
    assert(format("%s", b) == "[1]");
    assert(format("%b", b) == "1");

    b.init([0, 0, 0, 0]);
    assert(format("%b", b) == "0000");

    b.init([0, 0, 0, 0, 1, 1, 1, 1]);
    assert(format("%s", b) == "[0, 0, 0, 0, 1, 1, 1, 1]");
    assert(format("%b", b) == "00001111");

    b.init([0, 0, 0, 0, 1, 1, 1, 1, 0, 0, 0, 0, 1, 1, 1, 1]);
    assert(format("%s", b) == "[0, 0, 0, 0, 1, 1, 1, 1, 0, 0, 0, 0, 1, 1, 1, 1]");
    assert(format("%b", b) == "00001111_00001111");

    b.init([1, 0, 0, 0, 0, 1, 1, 1, 1]);
    assert(format("%b", b) == "1_00001111");

    b.init([1, 0, 0, 0, 0, 1, 1, 1, 1, 0, 0, 0, 0, 1, 1, 1, 1]);
    assert(format("%b", b) == "1_00001111_00001111");
}

/++
    Swaps the endianness of the given integral value or character.
  +/
T swapEndian(T)(T val) @safe pure nothrow
    if(isIntegral!T || isSomeChar!T || isBoolean!T)
{
    static if(val.sizeof == 1)
        return val;
    else static if(isUnsigned!T)
        return swapEndianImpl(val);
    else static if(isIntegral!T)
        return cast(T)swapEndianImpl(cast(Unsigned!T) val);
    else static if(is(Unqual!T == wchar))
        return cast(T)swapEndian(cast(ushort)val);
    else static if(is(Unqual!T == dchar))
        return cast(T)swapEndian(cast(uint)val);
    else
        static assert(0, T.stringof ~ " unsupported by swapEndian.");
}

private ushort swapEndianImpl(ushort val) @safe pure nothrow
{
    return ((val & 0xff00U) >> 8) |
           ((val & 0x00ffU) << 8);
}

private uint swapEndianImpl(uint val) @trusted pure nothrow
{
    return bswap(val);
}

private ulong swapEndianImpl(ulong val) @trusted pure nothrow
{
    immutable ulong res = bswap(cast(uint)val);
    return res << 32 | bswap(cast(uint)(val >> 32));
}

unittest
{
    foreach(T; TypeTuple!(bool, byte, ubyte, short, ushort, int, uint, long, ulong, char, wchar, dchar))
    {
        scope(failure) writefln("Failed type: %s", T.stringof);
        T val;
        const T cval;
        immutable T ival;

        assert(swapEndian(swapEndian(val)) == val);
        assert(swapEndian(swapEndian(cval)) == cval);
        assert(swapEndian(swapEndian(ival)) == ival);
        assert(swapEndian(swapEndian(T.min)) == T.min);
        assert(swapEndian(swapEndian(T.max)) == T.max);

        foreach(i; 2 .. 10)
        {
            immutable T maxI = cast(T)(T.max / i);
            immutable T minI = cast(T)(T.min / i);

            assert(swapEndian(swapEndian(maxI)) == maxI);

            static if(isSigned!T)
                assert(swapEndian(swapEndian(minI)) == minI);
        }

        static if(isSigned!T)
            assert(swapEndian(swapEndian(cast(T)0)) == 0);

        // used to trigger BUG6354
        static if(T.sizeof > 1 && isUnsigned!T)
        {
            T left = 0xffU;
            left <<= (T.sizeof - 1) * 8;
            T right = 0xffU;

            for(size_t i = 1; i < T.sizeof; ++i)
            {
                assert(swapEndian(left) == right);
                assert(swapEndian(right) == left);
                left >>= 8;
                right <<= 8;
            }
        }
    }
}


private union EndianSwapper(T)
    if(canSwapEndianness!T)
{
    Unqual!T value;
    ubyte[T.sizeof] array;

    static if(is(FloatingPointTypeOf!T == float))
        uint  intValue;
    else static if(is(FloatingPointTypeOf!T == double))
        ulong intValue;

}


/++
    Converts the given value from the native endianness to big endian and
    returns it as a $(D ubyte[n]) where $(D n) is the size of the given type.

    Returning a $(D ubyte[n]) helps prevent accidentally using a swapped value
    as a regular one (and in the case of floating point values, it's necessary,
    because the FPU will mess up any swapped floating point values. So, you
    can't actually have swapped floating point values as floating point values).

    $(D real) is not supported, because its size is implementation-dependent
    and therefore could vary from machine to machine (which could make it
    unusable if you tried to transfer it to another machine).

        Examples:
--------------------
int i = 12345;
ubyte[4] swappedI = nativeToBigEndian(i);
assert(i == bigEndianToNative!int(swappedI));

double d = 123.45;
ubyte[8] swappedD = nativeToBigEndian(d);
assert(d == bigEndianToNative!double(swappedD));
--------------------
  +/
auto nativeToBigEndian(T)(T val) @safe pure nothrow
    if(canSwapEndianness!T)
{
    return nativeToBigEndianImpl(val);
}

//Verify Examples
unittest
{
    int i = 12345;
    ubyte[4] swappedI = nativeToBigEndian(i);
    assert(i == bigEndianToNative!int(swappedI));

    double d = 123.45;
    ubyte[8] swappedD = nativeToBigEndian(d);
    assert(d == bigEndianToNative!double(swappedD));
}

private auto nativeToBigEndianImpl(T)(T val) @safe pure nothrow
    if(isIntegral!T || isSomeChar!T || isBoolean!T)
{
    EndianSwapper!T es = void;

    version(LittleEndian)
        es.value = swapEndian(val);
    else
        es.value = val;

    return es.array;
}

private auto nativeToBigEndianImpl(T)(T val) @safe pure nothrow
    if(isFloatOrDouble!T)
{
    version(LittleEndian)
        return floatEndianImpl!(T, true)(val);
    else
        return floatEndianImpl!(T, false)(val);
}

unittest
{
    foreach(T; TypeTuple!(bool, byte, ubyte, short, ushort, int, uint, long, ulong,
                          char, wchar, dchar
        /* The trouble here is with floats and doubles being compared against nan
         * using a bit compare. There are two kinds of nans, quiet and signaling.
         * When a nan passes through the x87, it converts signaling to quiet.
         * When a nan passes through the XMM, it does not convert signaling to quiet.
         * float.init is a signaling nan.
         * The binary API sometimes passes the data through the XMM, sometimes through
         * the x87, meaning these will fail the 'is' bit compare under some circumstances.
         * I cannot think of a fix for this that makes consistent sense.
         */
                          /*,float, double*/))
    {
        scope(failure) writefln("Failed type: %s", T.stringof);
        T val;
        const T cval;
        immutable T ival;

        //is instead of == because of NaN for floating point values.
        assert(bigEndianToNative!T(nativeToBigEndian(val)) is val);
        assert(bigEndianToNative!T(nativeToBigEndian(cval)) is cval);
        assert(bigEndianToNative!T(nativeToBigEndian(ival)) is ival);
        assert(bigEndianToNative!T(nativeToBigEndian(T.min)) == T.min);
        assert(bigEndianToNative!T(nativeToBigEndian(T.max)) == T.max);

        static if(isSigned!T)
            assert(bigEndianToNative!T(nativeToBigEndian(cast(T)0)) == 0);

        static if(!is(T == bool))
        {
            foreach(i; [2, 4, 6, 7, 9, 11])
            {
                immutable T maxI = cast(T)(T.max / i);
                immutable T minI = cast(T)(T.min / i);

                assert(bigEndianToNative!T(nativeToBigEndian(maxI)) == maxI);

                static if(T.sizeof > 1)
                    assert(nativeToBigEndian(maxI) != nativeToLittleEndian(maxI));
                else
                    assert(nativeToBigEndian(maxI) == nativeToLittleEndian(maxI));

                static if(isSigned!T)
                {
                    assert(bigEndianToNative!T(nativeToBigEndian(minI)) == minI);

                    static if(T.sizeof > 1)
                        assert(nativeToBigEndian(minI) != nativeToLittleEndian(minI));
                    else
                        assert(nativeToBigEndian(minI) == nativeToLittleEndian(minI));
                }
            }
        }

        static if(isUnsigned!T || T.sizeof == 1 || is(T == wchar))
            assert(nativeToBigEndian(T.max) == nativeToLittleEndian(T.max));
        else
            assert(nativeToBigEndian(T.max) != nativeToLittleEndian(T.max));

        static if(isUnsigned!T || T.sizeof == 1 || isSomeChar!T)
            assert(nativeToBigEndian(T.min) == nativeToLittleEndian(T.min));
        else
            assert(nativeToBigEndian(T.min) != nativeToLittleEndian(T.min));
    }
}


/++
    Converts the given value from big endian to the native endianness and
    returns it. The value is given as a $(D ubyte[n]) where $(D n) is the size
    of the target type. You must give the target type as a template argument,
    because there are multiple types with the same size and so the type of the
    argument is not enough to determine the return type.

    Taking a $(D ubyte[n]) helps prevent accidentally using a swapped value
    as a regular one (and in the case of floating point values, it's necessary,
    because the FPU will mess up any swapped floating point values. So, you
    can't actually have swapped floating point values as floating point values).

        Examples:
--------------------
ushort i = 12345;
ubyte[2] swappedI = nativeToBigEndian(i);
assert(i == bigEndianToNative!ushort(swappedI));

dchar c = 'D';
ubyte[4] swappedC = nativeToBigEndian(c);
assert(c == bigEndianToNative!dchar(swappedC));
--------------------
  +/
T bigEndianToNative(T, size_t n)(ubyte[n] val) @safe pure nothrow
    if(canSwapEndianness!T && n == T.sizeof)
{
    return bigEndianToNativeImpl!(T, n)(val);
}

//Verify Examples.
unittest
{
    ushort i = 12345;
    ubyte[2] swappedI = nativeToBigEndian(i);
    assert(i == bigEndianToNative!ushort(swappedI));

    dchar c = 'D';
    ubyte[4] swappedC = nativeToBigEndian(c);
    assert(c == bigEndianToNative!dchar(swappedC));
}

private T bigEndianToNativeImpl(T, size_t n)(ubyte[n] val) @safe pure nothrow
    if((isIntegral!T || isSomeChar!T || isBoolean!T) &&
       n == T.sizeof)
{
    EndianSwapper!T es = void;
    es.array = val;

    version(LittleEndian)
        immutable retval = swapEndian(es.value);
    else
        immutable retval = es.value;

    return retval;
}

private T bigEndianToNativeImpl(T, size_t n)(ubyte[n] val) @safe pure nothrow
    if(isFloatOrDouble!T && n == T.sizeof)
{
    version(LittleEndian)
        return cast(T) floatEndianImpl!(n, true)(val);
    else
        return cast(T) floatEndianImpl!(n, false)(val);
}


/++
    Converts the given value from the native endianness to little endian and
    returns it as a $(D ubyte[n]) where $(D n) is the size of the given type.

    Returning a $(D ubyte[n]) helps prevent accidentally using a swapped value
    as a regular one (and in the case of floating point values, it's necessary,
    because the FPU will mess up any swapped floating point values. So, you
    can't actually have swapped floating point values as floating point values).

        Examples:
--------------------
int i = 12345;
ubyte[4] swappedI = nativeToLittleEndian(i);
assert(i == littleEndianToNative!int(swappedI));

double d = 123.45;
ubyte[8] swappedD = nativeToLittleEndian(d);
assert(d == littleEndianToNative!double(swappedD));
--------------------
  +/
auto nativeToLittleEndian(T)(T val) @safe pure nothrow
    if(canSwapEndianness!T)
{
    return nativeToLittleEndianImpl(val);
}

//Verify Examples.
unittest
{
    int i = 12345;
    ubyte[4] swappedI = nativeToLittleEndian(i);
    assert(i == littleEndianToNative!int(swappedI));

    double d = 123.45;
    ubyte[8] swappedD = nativeToLittleEndian(d);
    assert(d == littleEndianToNative!double(swappedD));
}

private auto nativeToLittleEndianImpl(T)(T val) @safe pure nothrow
    if(isIntegral!T || isSomeChar!T || isBoolean!T)
{
    EndianSwapper!T es = void;

    version(BigEndian)
        es.value = swapEndian(val);
    else
        es.value = val;

    return es.array;
}

private auto nativeToLittleEndianImpl(T)(T val) @safe pure nothrow
    if(isFloatOrDouble!T)
{
    version(BigEndian)
        return floatEndianImpl!(T, true)(val);
    else
        return floatEndianImpl!(T, false)(val);
}

unittest
{
    foreach(T; TypeTuple!(bool, byte, ubyte, short, ushort, int, uint, long, ulong,
                          char, wchar, dchar/*,
                          float, double*/))
    {
        scope(failure) writefln("Failed type: %s", T.stringof);
        T val;
        const T cval;
        immutable T ival;

        //is instead of == because of NaN for floating point values.
        assert(littleEndianToNative!T(nativeToLittleEndian(val)) is val);
        assert(littleEndianToNative!T(nativeToLittleEndian(cval)) is cval);
        assert(littleEndianToNative!T(nativeToLittleEndian(ival)) is ival);
        assert(littleEndianToNative!T(nativeToLittleEndian(T.min)) == T.min);
        assert(littleEndianToNative!T(nativeToLittleEndian(T.max)) == T.max);

        static if(isSigned!T)
            assert(littleEndianToNative!T(nativeToLittleEndian(cast(T)0)) == 0);

        static if(!is(T == bool))
        {
            foreach(i; 2 .. 10)
            {
                immutable T maxI = cast(T)(T.max / i);
                immutable T minI = cast(T)(T.min / i);

                assert(littleEndianToNative!T(nativeToLittleEndian(maxI)) == maxI);

                static if(isSigned!T)
                    assert(littleEndianToNative!T(nativeToLittleEndian(minI)) == minI);
            }
        }
    }
}


/++
    Converts the given value from little endian to the native endianness and
    returns it. The value is given as a $(D ubyte[n]) where $(D n) is the size
    of the target type. You must give the target type as a template argument,
    because there are multiple types with the same size and so the type of the
    argument is not enough to determine the return type.

    Taking a $(D ubyte[n]) helps prevent accidentally using a swapped value
    as a regular one (and in the case of floating point values, it's necessary,
    because the FPU will mess up any swapped floating point values. So, you
    can't actually have swapped floating point values as floating point values).

    $(D real) is not supported, because its size is implementation-dependent
    and therefore could vary from machine to machine (which could make it
    unusable if you tried to transfer it to another machine).

        Examples:
--------------------
ushort i = 12345;
ubyte[2] swappedI = nativeToLittleEndian(i);
assert(i == littleEndianToNative!ushort(swappedI));

dchar c = 'D';
ubyte[4] swappedC = nativeToLittleEndian(c);
assert(c == littleEndianToNative!dchar(swappedC));
--------------------
  +/
T littleEndianToNative(T, size_t n)(ubyte[n] val) @safe pure nothrow
    if(canSwapEndianness!T && n == T.sizeof)
{
    return littleEndianToNativeImpl!T(val);
}

//Verify Unittest.
unittest
{
    ushort i = 12345;
    ubyte[2] swappedI = nativeToLittleEndian(i);
    assert(i == littleEndianToNative!ushort(swappedI));

    dchar c = 'D';
    ubyte[4] swappedC = nativeToLittleEndian(c);
    assert(c == littleEndianToNative!dchar(swappedC));
}

private T littleEndianToNativeImpl(T, size_t n)(ubyte[n] val) @safe pure nothrow
    if((isIntegral!T || isSomeChar!T || isBoolean!T) &&
       n == T.sizeof)
{
    EndianSwapper!T es = void;
    es.array = val;

    version(BigEndian)
        immutable retval = swapEndian(es.value);
    else
        immutable retval = es.value;

    return retval;
}

private T littleEndianToNativeImpl(T, size_t n)(ubyte[n] val) @safe pure nothrow
    if(((isFloatOrDouble!T) &&
       n == T.sizeof))
{
    version(BigEndian)
        return floatEndianImpl!(n, true)(val);
    else
        return floatEndianImpl!(n, false)(val);
}

private auto floatEndianImpl(T, bool swap)(T val) @safe pure nothrow
    if(isFloatOrDouble!T)
{
    EndianSwapper!T es = void;
    es.value = val;

    static if(swap)
        es.intValue = swapEndian(es.intValue);

    return es.array;
}

private auto floatEndianImpl(size_t n, bool swap)(ubyte[n] val) @safe pure nothrow
    if(n == 4 || n == 8)
{
    static if(n == 4)       EndianSwapper!float es = void;
    else static if(n == 8)  EndianSwapper!double es = void;

    es.array = val;

    static if(swap)
        es.intValue = swapEndian(es.intValue);

    return es.value;
}

private template isFloatOrDouble(T)
{
    enum isFloatOrDouble = isFloatingPoint!T &&
                           !is(Unqual!(FloatingPointTypeOf!T) == real);
}

unittest
{
    foreach(T; TypeTuple!(float, double))
    {
        static assert(isFloatOrDouble!(T));
        static assert(isFloatOrDouble!(const T));
        static assert(isFloatOrDouble!(immutable T));
        static assert(isFloatOrDouble!(shared T));
        static assert(isFloatOrDouble!(shared(const T)));
        static assert(isFloatOrDouble!(shared(immutable T)));
    }

    static assert(!isFloatOrDouble!(real));
    static assert(!isFloatOrDouble!(const real));
    static assert(!isFloatOrDouble!(immutable real));
    static assert(!isFloatOrDouble!(shared real));
    static assert(!isFloatOrDouble!(shared(const real)));
    static assert(!isFloatOrDouble!(shared(immutable real)));
}

private template canSwapEndianness(T)
{
    enum canSwapEndianness = isIntegral!T ||
                             isSomeChar!T ||
                             isBoolean!T ||
                             isFloatOrDouble!T;
}

unittest
{
    foreach(T; TypeTuple!(bool, ubyte, byte, ushort, short, uint, int, ulong,
                          long, char, wchar, dchar, float, double))
    {
        static assert(canSwapEndianness!(T));
        static assert(canSwapEndianness!(const T));
        static assert(canSwapEndianness!(immutable T));
        static assert(canSwapEndianness!(shared(T)));
        static assert(canSwapEndianness!(shared(const T)));
        static assert(canSwapEndianness!(shared(immutable T)));
    }

    //!
    foreach(T; TypeTuple!(real, string, wstring, dstring))
    {
        static assert(!canSwapEndianness!(T));
        static assert(!canSwapEndianness!(const T));
        static assert(!canSwapEndianness!(immutable T));
        static assert(!canSwapEndianness!(shared(T)));
        static assert(!canSwapEndianness!(shared(const T)));
        static assert(!canSwapEndianness!(shared(immutable T)));
    }
}

/++
    Takes a range of $(D ubyte)s and converts the first $(D T.sizeof) bytes to
    $(D T). The value returned is converted from the given endianness to the
    native endianness. The range is not consumed.

    Parems:
        T     = The integral type to convert the first $(D T.sizeof) bytes to.
        endianness = The endianness that the bytes are assumed to be in.
        range = The range to read from.
        index = The index to start reading from (instead of starting at the
                front). If index is a pointer, then it is updated to the index
                after the bytes read. The overloads with index are only
                available if $(D hasSlicing!R) is $(D true).

        Examples:
--------------------
ubyte[] buffer = [1, 5, 22, 9, 44, 255, 8];
assert(buffer.peek!uint() == 17110537);
assert(buffer.peek!ushort() == 261);
assert(buffer.peek!ubyte() == 1);

assert(buffer.peek!uint(2) == 369700095);
assert(buffer.peek!ushort(2) == 5641);
assert(buffer.peek!ubyte(2) == 22);

size_t index = 0;
assert(buffer.peek!ushort(&index) == 261);
assert(index == 2);

assert(buffer.peek!uint(&index) == 369700095);
assert(index == 6);

assert(buffer.peek!ubyte(&index) == 8);
assert(index == 7);
--------------------
  +/

T peek(T, Endian endianness = Endian.bigEndian, R)(R range)
    if (canSwapEndianness!T &&
        isForwardRange!R &&
        is(ElementType!R : const ubyte))
{
    static if(hasSlicing!R)
        const ubyte[T.sizeof] bytes = range[0 .. T.sizeof];
    else
    {
        ubyte[T.sizeof] bytes;
        //Make sure that range is not consumed, even if it's a class.
        range = range.save;

        foreach(ref e; bytes)
        {
            e = range.front;
            range.popFront();
        }
    }

    static if(endianness == Endian.bigEndian)
        return bigEndianToNative!T(bytes);
    else
        return littleEndianToNative!T(bytes);
}

/++ Ditto +/
T peek(T, Endian endianness = Endian.bigEndian, R)(R range, size_t index)
    if(canSwapEndianness!T &&
       isForwardRange!R &&
       hasSlicing!R &&
       is(ElementType!R : const ubyte))
{
    return peek!(T, endianness)(range, &index);
}

/++ Ditto +/
T peek(T, Endian endianness = Endian.bigEndian, R)(R range, size_t* index)
    if(canSwapEndianness!T &&
       isForwardRange!R &&
       hasSlicing!R &&
       is(ElementType!R : const ubyte))
{
    assert(index);

    immutable begin = *index;
    immutable end = begin + T.sizeof;
    const ubyte[T.sizeof] bytes = range[begin .. end];
    *index = end;

    static if(endianness == Endian.bigEndian)
        return bigEndianToNative!T(bytes);
    else
        return littleEndianToNative!T(bytes);
}

//Verify Example.
unittest
{
    ubyte[] buffer = [1, 5, 22, 9, 44, 255, 8];
    assert(buffer.peek!uint() == 17110537);
    assert(buffer.peek!ushort() == 261);
    assert(buffer.peek!ubyte() == 1);

    assert(buffer.peek!uint(2) == 369700095);
    assert(buffer.peek!ushort(2) == 5641);
    assert(buffer.peek!ubyte(2) == 22);

    size_t index = 0;
    assert(buffer.peek!ushort(&index) == 261);
    assert(index == 2);

    assert(buffer.peek!uint(&index) == 369700095);
    assert(index == 6);

    assert(buffer.peek!ubyte(&index) == 8);
    assert(index == 7);
}

unittest
{
    {
        //bool
        ubyte[] buffer = [0, 1];
        assert(buffer.peek!bool() == false);
        assert(buffer.peek!bool(1) == true);

        size_t index = 0;
        assert(buffer.peek!bool(&index) == false);
        assert(index == 1);

        assert(buffer.peek!bool(&index) == true);
        assert(index == 2);
    }

    {
        //char (8bit)
        ubyte[] buffer = [97, 98, 99, 100];
        assert(buffer.peek!char() == 'a');
        assert(buffer.peek!char(1) == 'b');

        size_t index = 0;
        assert(buffer.peek!char(&index) == 'a');
        assert(index == 1);

        assert(buffer.peek!char(&index) == 'b');
        assert(index == 2);
    }

    {
        //wchar (16bit - 2x ubyte)
        ubyte[] buffer = [1, 5, 32, 29, 1, 7];
        assert(buffer.peek!wchar() == 'ą');
        assert(buffer.peek!wchar(2) == '”');
        assert(buffer.peek!wchar(4) == 'ć');

        size_t index = 0;
        assert(buffer.peek!wchar(&index) == 'ą');
        assert(index == 2);

        assert(buffer.peek!wchar(&index) == '”');
        assert(index == 4);

        assert(buffer.peek!wchar(&index) == 'ć');
        assert(index == 6);
    }

    {
        //dchar (32bit - 4x ubyte)
        ubyte[] buffer = [0, 0, 1, 5, 0, 0, 32, 29, 0, 0, 1, 7];
        assert(buffer.peek!dchar() == 'ą');
        assert(buffer.peek!dchar(4) == '”');
        assert(buffer.peek!dchar(8) == 'ć');

        size_t index = 0;
        assert(buffer.peek!dchar(&index) == 'ą');
        assert(index == 4);

        assert(buffer.peek!dchar(&index) == '”');
        assert(index == 8);

        assert(buffer.peek!dchar(&index) == 'ć');
        assert(index == 12);
    }

    {
        //float (32bit - 4x ubyte)
        ubyte[] buffer = [66, 0, 0, 0, 65, 200, 0, 0];
        assert(buffer.peek!float()== 32.0);
        assert(buffer.peek!float(4) == 25.0f);

        size_t index = 0;
        assert(buffer.peek!float(&index) == 32.0f);
        assert(index == 4);

        assert(buffer.peek!float(&index) == 25.0f);
        assert(index == 8);
    }

    {
        //double (64bit - 8x ubyte)
        ubyte[] buffer = [64, 64, 0, 0, 0, 0, 0, 0, 64, 57, 0, 0, 0, 0, 0, 0];
        assert(buffer.peek!double() == 32.0);
        assert(buffer.peek!double(8) == 25.0);

        size_t index = 0;
        assert(buffer.peek!double(&index) == 32.0);
        assert(index == 8);

        assert(buffer.peek!double(&index) == 25.0);
        assert(index == 16);
    }

    {
        //enum
        ubyte[] buffer = [0, 0, 0, 10, 0, 0, 0, 20, 0, 0, 0, 30];

        enum Foo
        {
            one = 10,
            two = 20,
            three = 30
        }

        assert(buffer.peek!Foo() == Foo.one);
        assert(buffer.peek!Foo(0) == Foo.one);
        assert(buffer.peek!Foo(4) == Foo.two);
        assert(buffer.peek!Foo(8) == Foo.three);

        size_t index = 0;
        assert(buffer.peek!Foo(&index) == Foo.one);
        assert(index == 4);

        assert(buffer.peek!Foo(&index) == Foo.two);
        assert(index == 8);

        assert(buffer.peek!Foo(&index) == Foo.three);
        assert(index == 12);
    }

    {
        //enum - bool
        ubyte[] buffer = [0, 1];

        enum Bool: bool
        {
            bfalse = false,
            btrue = true,
        }

        assert(buffer.peek!Bool() == Bool.bfalse);
        assert(buffer.peek!Bool(0) == Bool.bfalse);
        assert(buffer.peek!Bool(1) == Bool.btrue);

        size_t index = 0;
        assert(buffer.peek!Bool(&index) == Bool.bfalse);
        assert(index == 1);

        assert(buffer.peek!Bool(&index) == Bool.btrue);
        assert(index == 2);
    }

    {
        //enum - float
        ubyte[] buffer = [66, 0, 0, 0, 65, 200, 0, 0];

        enum Float: float
        {
            one = 32.0f,
            two = 25.0f
        }

        assert(buffer.peek!Float() == Float.one);
        assert(buffer.peek!Float(0) == Float.one);
        assert(buffer.peek!Float(4) == Float.two);

        size_t index = 0;
        assert(buffer.peek!Float(&index) == Float.one);
        assert(index == 4);

        assert(buffer.peek!Float(&index) == Float.two);
        assert(index == 8);
    }

    {
        //enum - double
        ubyte[] buffer = [64, 64, 0, 0, 0, 0, 0, 0, 64, 57, 0, 0, 0, 0, 0, 0];

        enum Double: double
        {
            one = 32.0,
            two = 25.0
        }

        assert(buffer.peek!Double() == Double.one);
        assert(buffer.peek!Double(0) == Double.one);
        assert(buffer.peek!Double(8) == Double.two);

        size_t index = 0;
        assert(buffer.peek!Double(&index) == Double.one);
        assert(index == 8);

        assert(buffer.peek!Double(&index) == Double.two);
        assert(index == 16);
    }

    {
        //enum - real
        ubyte[] buffer = [64, 64, 0, 0, 0, 0, 0, 0, 64, 57, 0, 0, 0, 0, 0, 0];

        enum Real: real
        {
            one = 32.0,
            two = 25.0
        }

        static assert(!__traits(compiles, buffer.peek!Real()));
    }
}

unittest
{
    import std.algorithm;
    ubyte[] buffer = [1, 5, 22, 9, 44, 255, 7];
    auto range = filter!"true"(buffer);
    assert(range.peek!uint() == 17110537);
    assert(range.peek!ushort() == 261);
    assert(range.peek!ubyte() == 1);
}


/++
    Takes a range of $(D ubyte)s and converts the first $(D T.sizeof) bytes to
    $(D T). The value returned is converted from the given endianness to the
    native endianness. The $(D T.sizeof) bytes which are read are consumed from
    the range.

    Parems:
        T     = The integral type to convert the first $(D T.sizeof) bytes to.
        endianness = The endianness that the bytes are assumed to be in.
        range = The range to read from.

        Examples:
--------------------
ubyte[] buffer = [1, 5, 22, 9, 44, 255, 8];
assert(buffer.length == 7);

assert(buffer.read!ushort() == 261);
assert(buffer.length == 5);

assert(buffer.read!uint() == 369700095);
assert(buffer.length == 1);

assert(buffer.read!ubyte() == 8);
assert(buffer.empty);
--------------------
  +/
T read(T, Endian endianness = Endian.bigEndian, R)(ref R range)
    if(canSwapEndianness!T && isInputRange!R && is(ElementType!R : const ubyte))
{
    static if(hasSlicing!R)
    {
        const ubyte[T.sizeof] bytes = range[0 .. T.sizeof];
        range.popFrontN(T.sizeof);
    }
    else
    {
        ubyte[T.sizeof] bytes;

        foreach(ref e; bytes)
        {
            e = range.front;
            range.popFront();
        }
    }

    static if(endianness == Endian.bigEndian)
        return bigEndianToNative!T(bytes);
    else
        return littleEndianToNative!T(bytes);
}

//Verify Example.
unittest
{
    ubyte[] buffer = [1, 5, 22, 9, 44, 255, 8];
    assert(buffer.length == 7);

    assert(buffer.read!ushort() == 261);
    assert(buffer.length == 5);

    assert(buffer.read!uint() == 369700095);
    assert(buffer.length == 1);

    assert(buffer.read!ubyte() == 8);
    assert(buffer.empty);
}

unittest
{
    {
        //bool
        ubyte[] buffer = [0, 1];
        assert(buffer.length == 2);

        assert(buffer.read!bool() == false);
        assert(buffer.length == 1);

        assert(buffer.read!bool() == true);
        assert(buffer.empty);
    }

    {
        //char (8bit)
        ubyte[] buffer = [97, 98, 99];
        assert(buffer.length == 3);

        assert(buffer.read!char() == 'a');
        assert(buffer.length == 2);

        assert(buffer.read!char() == 'b');
        assert(buffer.length == 1);

        assert(buffer.read!char() == 'c');
        assert(buffer.empty);
    }

    {
        //wchar (16bit - 2x ubyte)
        ubyte[] buffer = [1, 5, 32, 29, 1, 7];
        assert(buffer.length == 6);

        assert(buffer.read!wchar() == 'ą');
        assert(buffer.length == 4);

        assert(buffer.read!wchar() == '”');
        assert(buffer.length == 2);

        assert(buffer.read!wchar() == 'ć');
        assert(buffer.empty);
    }

    {
        //dchar (32bit - 4x ubyte)
        ubyte[] buffer = [0, 0, 1, 5, 0, 0, 32, 29, 0, 0, 1, 7];
        assert(buffer.length == 12);

        assert(buffer.read!dchar() == 'ą');
        assert(buffer.length == 8);

        assert(buffer.read!dchar() == '”');
        assert(buffer.length == 4);

        assert(buffer.read!dchar() == 'ć');
        assert(buffer.empty);
    }

    {
        //float (32bit - 4x ubyte)
        ubyte[] buffer = [66, 0, 0, 0, 65, 200, 0, 0];
        assert(buffer.length == 8);

        assert(buffer.read!float()== 32.0);
        assert(buffer.length == 4);

        assert(buffer.read!float() == 25.0f);
        assert(buffer.empty);
    }

    {
        //double (64bit - 8x ubyte)
        ubyte[] buffer = [64, 64, 0, 0, 0, 0, 0, 0, 64, 57, 0, 0, 0, 0, 0, 0];
        assert(buffer.length == 16);

        assert(buffer.read!double() == 32.0);
        assert(buffer.length == 8);

        assert(buffer.read!double() == 25.0);
        assert(buffer.empty);
    }

    {
        //enum - uint
        ubyte[] buffer = [0, 0, 0, 10, 0, 0, 0, 20, 0, 0, 0, 30];
        assert(buffer.length == 12);

        enum Foo
        {
            one = 10,
            two = 20,
            three = 30
        }

        assert(buffer.read!Foo() == Foo.one);
        assert(buffer.length == 8);

        assert(buffer.read!Foo() == Foo.two);
        assert(buffer.length == 4);

        assert(buffer.read!Foo() == Foo.three);
        assert(buffer.empty);
    }

    {
        //enum - bool
        ubyte[] buffer = [0, 1];
        assert(buffer.length == 2);

        enum Bool: bool
        {
            bfalse = false,
            btrue = true,
        }

        assert(buffer.read!Bool() == Bool.bfalse);
        assert(buffer.length == 1);

        assert(buffer.read!Bool() == Bool.btrue);
        assert(buffer.empty);
    }

    {
        //enum - float
        ubyte[] buffer = [66, 0, 0, 0, 65, 200, 0, 0];
        assert(buffer.length == 8);

        enum Float: float
        {
            one = 32.0f,
            two = 25.0f
        }

        assert(buffer.read!Float() == Float.one);
        assert(buffer.length == 4);

        assert(buffer.read!Float() == Float.two);
        assert(buffer.empty);
    }

    {
        //enum - double
        ubyte[] buffer = [64, 64, 0, 0, 0, 0, 0, 0, 64, 57, 0, 0, 0, 0, 0, 0];
        assert(buffer.length == 16);

        enum Double: double
        {
            one = 32.0,
            two = 25.0
        }

        assert(buffer.read!Double() == Double.one);
        assert(buffer.length == 8);

        assert(buffer.read!Double() == Double.two);
        assert(buffer.empty);
    }

    {
        //enum - real
        ubyte[] buffer = [64, 64, 0, 0, 0, 0, 0, 0, 64, 57, 0, 0, 0, 0, 0, 0];

        enum Real: real
        {
            one = 32.0,
            two = 25.0
        }

        static assert(!__traits(compiles, buffer.read!Real()));
    }
}

unittest
{
    import std.algorithm;
    ubyte[] buffer = [1, 5, 22, 9, 44, 255, 8];
    auto range = filter!"true"(buffer);
    assert(walkLength(range) == 7);

    assert(range.read!ushort() == 261);
    assert(walkLength(range) == 5);

    assert(range.read!uint() == 369700095);
    assert(walkLength(range) == 1);

    assert(range.read!ubyte() == 8);
    assert(range.empty);
}


/++
    Takes an integral value, converts it to the given endianness, and writes it
    to the given range of $(D ubyte)s as a sequence of $(D T.sizeof) $(D ubyte)s
    starting at index. $(D hasSlicing!R) must be $(D true).

    Parems:
        T     = The integral type to convert the first $(D T.sizeof) bytes to.
        endianness = The endianness to write the bytes in.
        range = The range to write to.
        index = The index to start writing to. If index is a pointer, then it
                is updated to the index after the bytes read.

        Examples:
--------------------
{
    ubyte[] buffer = [0, 0, 0, 0, 0, 0, 0, 0];
    buffer.write!uint(29110231u, 0);
    assert(buffer == [1, 188, 47, 215, 0, 0, 0, 0]);

    buffer.write!ushort(927, 0);
    assert(buffer == [3, 159, 47, 215, 0, 0, 0, 0]);

    buffer.write!ubyte(42, 0);
    assert(buffer == [42, 159, 47, 215, 0, 0, 0, 0]);
}

{
    ubyte[] buffer = [0, 0, 0, 0, 0, 0, 0, 0, 0];
    buffer.write!uint(142700095u, 2);
    assert(buffer == [0, 0, 8, 129, 110, 63, 0, 0, 0]);

    buffer.write!ushort(19839, 2);
    assert(buffer == [0, 0, 77, 127, 110, 63, 0, 0, 0]);

    buffer.write!ubyte(132, 2);
    assert(buffer == [0, 0, 132, 127, 110, 63, 0, 0, 0]);
}

{
    ubyte[] buffer = [0, 0, 0, 0, 0, 0, 0, 0];
    size_t index = 0;
    buffer.write!ushort(261, &index);
    assert(buffer == [1, 5, 0, 0, 0, 0, 0, 0]);
    assert(index == 2);

    buffer.write!uint(369700095u, &index);
    assert(buffer == [1, 5, 22, 9, 44, 255, 0, 0]);
    assert(index == 6);

    buffer.write!ubyte(8, &index);
    assert(buffer == [1, 5, 22, 9, 44, 255, 8, 0]);
    assert(index == 7);
}
--------------------
  +/
void write(T, Endian endianness = Endian.bigEndian, R)(R range, T value, size_t index)
    if(canSwapEndianness!T &&
       isForwardRange!R &&
       hasSlicing!R &&
       is(ElementType!R : ubyte))
{
    write!(T, endianness)(range, value, &index);
}

/++ Ditto +/
void write(T, Endian endianness = Endian.bigEndian, R)(R range, T value, size_t* index)
    if(canSwapEndianness!T &&
       isForwardRange!R &&
       hasSlicing!R &&
       is(ElementType!R : ubyte))
{
    assert(index);

    static if(endianness == Endian.bigEndian)
        immutable bytes = nativeToBigEndian!T(value);
    else
        immutable bytes = nativeToLittleEndian!T(value);

    immutable begin = *index;
    immutable end = begin + T.sizeof;
    *index = end;
    range[begin .. end] = bytes[0 .. T.sizeof];
}

//Verify Example.
unittest
{
    {
        ubyte[] buffer = [0, 0, 0, 0, 0, 0, 0, 0];
        buffer.write!uint(29110231u, 0);
        assert(buffer == [1, 188, 47, 215, 0, 0, 0, 0]);

        buffer.write!ushort(927, 0);
        assert(buffer == [3, 159, 47, 215, 0, 0, 0, 0]);

        buffer.write!ubyte(42, 0);
        assert(buffer == [42, 159, 47, 215, 0, 0, 0, 0]);
    }

    {
        ubyte[] buffer = [0, 0, 0, 0, 0, 0, 0, 0, 0];
        buffer.write!uint(142700095u, 2);
        assert(buffer == [0, 0, 8, 129, 110, 63, 0, 0, 0]);

        buffer.write!ushort(19839, 2);
        assert(buffer == [0, 0, 77, 127, 110, 63, 0, 0, 0]);

        buffer.write!ubyte(132, 2);
        assert(buffer == [0, 0, 132, 127, 110, 63, 0, 0, 0]);
    }

    {
        ubyte[] buffer = [0, 0, 0, 0, 0, 0, 0, 0];
        size_t index = 0;
        buffer.write!ushort(261, &index);
        assert(buffer == [1, 5, 0, 0, 0, 0, 0, 0]);
        assert(index == 2);

        buffer.write!uint(369700095u, &index);
        assert(buffer == [1, 5, 22, 9, 44, 255, 0, 0]);
        assert(index == 6);

        buffer.write!ubyte(8, &index);
        assert(buffer == [1, 5, 22, 9, 44, 255, 8, 0]);
        assert(index == 7);
    }
}

unittest
{
    {
        //bool
        ubyte[] buffer = [0, 0];

        buffer.write!bool(false, 0);
        assert(buffer == [0, 0]);

        buffer.write!bool(true, 0);
        assert(buffer == [1, 0]);

        buffer.write!bool(true, 1);
        assert(buffer == [1, 1]);

        buffer.write!bool(false, 1);
        assert(buffer == [1, 0]);

        size_t index = 0;
        buffer.write!bool(false, &index);
        assert(buffer == [0, 0]);
        assert(index == 1);

        buffer.write!bool(true, &index);
        assert(buffer == [0, 1]);
        assert(index == 2);
    }

    {
        //char (8bit)
        ubyte[] buffer = [0, 0, 0];

        buffer.write!char('a', 0);
        assert(buffer == [97, 0, 0]);

        buffer.write!char('b', 1);
        assert(buffer == [97, 98, 0]);

        size_t index = 0;
        buffer.write!char('a', &index);
        assert(buffer == [97, 98, 0]);
        assert(index == 1);

        buffer.write!char('b', &index);
        assert(buffer == [97, 98, 0]);
        assert(index == 2);

        buffer.write!char('c', &index);
        assert(buffer == [97, 98, 99]);
        assert(index == 3);
    }

    {
        //wchar (16bit - 2x ubyte)
        ubyte[] buffer = [0, 0, 0, 0];

        buffer.write!wchar('ą', 0);
        assert(buffer == [1, 5, 0, 0]);

        buffer.write!wchar('”', 2);
        assert(buffer == [1, 5, 32, 29]);

        size_t index = 0;
        buffer.write!wchar('ć', &index);
        assert(buffer == [1, 7, 32, 29]);
        assert(index == 2);

        buffer.write!wchar('ą', &index);
        assert(buffer == [1, 7, 1, 5]);
        assert(index == 4);
    }

    {
        //dchar (32bit - 4x ubyte)
        ubyte[] buffer = [0, 0, 0, 0, 0, 0, 0, 0];

        buffer.write!dchar('ą', 0);
        assert(buffer == [0, 0, 1, 5, 0, 0, 0, 0]);

        buffer.write!dchar('”', 4);
        assert(buffer == [0, 0, 1, 5, 0, 0, 32, 29]);

        size_t index = 0;
        buffer.write!dchar('ć', &index);
        assert(buffer == [0, 0, 1, 7, 0, 0, 32, 29]);
        assert(index == 4);

        buffer.write!dchar('ą', &index);
        assert(buffer == [0, 0, 1, 7, 0, 0, 1, 5]);
        assert(index == 8);
    }

    {
        //float (32bit - 4x ubyte)
        ubyte[] buffer = [0, 0, 0, 0, 0, 0, 0, 0];

        buffer.write!float(32.0f, 0);
        assert(buffer == [66, 0, 0, 0, 0, 0, 0, 0]);

        buffer.write!float(25.0f, 4);
        assert(buffer == [66, 0, 0, 0, 65, 200, 0, 0]);

        size_t index = 0;
        buffer.write!float(25.0f, &index);
        assert(buffer == [65, 200, 0, 0, 65, 200, 0, 0]);
        assert(index == 4);

        buffer.write!float(32.0f, &index);
        assert(buffer == [65, 200, 0, 0, 66, 0, 0, 0]);
        assert(index == 8);
    }

    {
        //double (64bit - 8x ubyte)
        ubyte[] buffer = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0];

        buffer.write!double(32.0, 0);
        assert(buffer == [64, 64, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]);

        buffer.write!double(25.0, 8);
        assert(buffer == [64, 64, 0, 0, 0, 0, 0, 0, 64, 57, 0, 0, 0, 0, 0, 0]);

        size_t index = 0;
        buffer.write!double(25.0, &index);
        assert(buffer == [64, 57, 0, 0, 0, 0, 0, 0, 64, 57, 0, 0, 0, 0, 0, 0]);
        assert(index == 8);

        buffer.write!double(32.0, &index);
        assert(buffer == [64, 57, 0, 0, 0, 0, 0, 0, 64, 64, 0, 0, 0, 0, 0, 0]);
        assert(index == 16);
    }

    {
        //enum
        ubyte[] buffer = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0];

        enum Foo
        {
            one = 10,
            two = 20,
            three = 30
        }

        buffer.write!Foo(Foo.one, 0);
        assert(buffer == [0, 0, 0, 10, 0, 0, 0, 0, 0, 0, 0, 0]);

        buffer.write!Foo(Foo.two, 4);
        assert(buffer == [0, 0, 0, 10, 0, 0, 0, 20, 0, 0, 0, 0]);

        buffer.write!Foo(Foo.three, 8);
        assert(buffer == [0, 0, 0, 10, 0, 0, 0, 20, 0, 0, 0, 30]);

        size_t index = 0;
        buffer.write!Foo(Foo.three, &index);
        assert(buffer == [0, 0, 0, 30, 0, 0, 0, 20, 0, 0, 0, 30]);
        assert(index == 4);

        buffer.write!Foo(Foo.one, &index);
        assert(buffer == [0, 0, 0, 30, 0, 0, 0, 10, 0, 0, 0, 30]);
        assert(index == 8);

        buffer.write!Foo(Foo.two, &index);
        assert(buffer == [0, 0, 0, 30, 0, 0, 0, 10, 0, 0, 0, 20]);
        assert(index == 12);
    }

    {
        //enum - bool
        ubyte[] buffer = [0, 0];

        enum Bool: bool
        {
            bfalse = false,
            btrue = true,
        }

        buffer.write!Bool(Bool.btrue, 0);
        assert(buffer == [1, 0]);

        buffer.write!Bool(Bool.btrue, 1);
        assert(buffer == [1, 1]);

        size_t index = 0;
        buffer.write!Bool(Bool.bfalse, &index);
        assert(buffer == [0, 1]);
        assert(index == 1);

        buffer.write!Bool(Bool.bfalse, &index);
        assert(buffer == [0, 0]);
        assert(index == 2);
    }

    {
        //enum - float
        ubyte[] buffer = [0, 0, 0, 0, 0, 0, 0, 0];

        enum Float: float
        {
            one = 32.0f,
            two = 25.0f
        }

        buffer.write!Float(Float.one, 0);
        assert(buffer == [66, 0, 0, 0, 0, 0, 0, 0]);

        buffer.write!Float(Float.two, 4);
        assert(buffer == [66, 0, 0, 0, 65, 200, 0, 0]);

        size_t index = 0;
        buffer.write!Float(Float.two, &index);
        assert(buffer == [65, 200, 0, 0, 65, 200, 0, 0]);
        assert(index == 4);

        buffer.write!Float(Float.one, &index);
        assert(buffer == [65, 200, 0, 0, 66, 0, 0, 0]);
        assert(index == 8);
    }

    {
        //enum - double
        ubyte[] buffer = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0];

        enum Double: double
        {
            one = 32.0,
            two = 25.0
        }

        buffer.write!Double(Double.one, 0);
        assert(buffer == [64, 64, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]);

        buffer.write!Double(Double.two, 8);
        assert(buffer == [64, 64, 0, 0, 0, 0, 0, 0, 64, 57, 0, 0, 0, 0, 0, 0]);

        size_t index = 0;
        buffer.write!Double(Double.two, &index);
        assert(buffer == [64, 57, 0, 0, 0, 0, 0, 0, 64, 57, 0, 0, 0, 0, 0, 0]);
        assert(index == 8);

        buffer.write!Double(Double.one, &index);
        assert(buffer == [64, 57, 0, 0, 0, 0, 0, 0, 64, 64, 0, 0, 0, 0, 0, 0]);
        assert(index == 16);
    }

    {
        //enum - real
        ubyte[] buffer = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0];

        enum Real: real
        {
            one = 32.0,
            two = 25.0
        }

        static assert(!__traits(compiles, buffer.write!Real(Real.one)));
    }
}


/++
    Takes an integral value, converts it to the given endianness, and appends
    it to the given range of $(D ubyte)s (using $(D put)) as a sequence of
    $(D T.sizeof) $(D ubyte)s starting at index. $(D hasSlicing!R) must be
    $(D true).

    Parems:
        T     = The integral type to convert the first $(D T.sizeof) bytes to.
        endianness = The endianness to write the bytes in.
        range = The range to append to.

        Examples:
--------------------
auto buffer = appender!(const ubyte[])();
buffer.append!ushort(261);
assert(buffer.data == [1, 5]);

buffer.append!uint(369700095u);
assert(buffer.data == [1, 5, 22, 9, 44, 255]);

buffer.append!ubyte(8);
assert(buffer.data == [1, 5, 22, 9, 44, 255, 8]);
--------------------
  +/
void append(T, Endian endianness = Endian.bigEndian, R)(R range, T value)
    if(canSwapEndianness!T && isOutputRange!(R, ubyte))
{
    static if(endianness == Endian.bigEndian)
        immutable bytes = nativeToBigEndian!T(value);
    else
        immutable bytes = nativeToLittleEndian!T(value);

    put(range, bytes[]);
}

//Verify Example.
unittest
{
    auto buffer = appender!(const ubyte[])();
    buffer.append!ushort(261);
    assert(buffer.data == [1, 5]);

    buffer.append!uint(369700095u);
    assert(buffer.data == [1, 5, 22, 9, 44, 255]);

    buffer.append!ubyte(8);
    assert(buffer.data == [1, 5, 22, 9, 44, 255, 8]);
}

unittest
{
    {
        //bool
        auto buffer = appender!(const ubyte[])();

        buffer.append!bool(true);
        assert(buffer.data == [1]);

        buffer.append!bool(false);
        assert(buffer.data == [1, 0]);
    }

    {
        //char wchar dchar
        auto buffer = appender!(const ubyte[])();

        buffer.append!char('a');
        assert(buffer.data == [97]);

        buffer.append!char('b');
        assert(buffer.data == [97, 98]);

        buffer.append!wchar('ą');
        assert(buffer.data == [97, 98, 1, 5]);

        buffer.append!dchar('ą');
        assert(buffer.data == [97, 98, 1, 5, 0, 0, 1, 5]);
    }

    {
        //float double
        auto buffer = appender!(const ubyte[])();

        buffer.append!float(32.0f);
        assert(buffer.data == [66, 0, 0, 0]);

        buffer.append!double(32.0);
        assert(buffer.data == [66, 0, 0, 0, 64, 64, 0, 0, 0, 0, 0, 0]);
    }

    {
        //enum
        auto buffer = appender!(const ubyte[])();

        enum Foo
        {
            one = 10,
            two = 20,
            three = 30
        }

        buffer.append!Foo(Foo.one);
        assert(buffer.data == [0, 0, 0, 10]);

        buffer.append!Foo(Foo.two);
        assert(buffer.data == [0, 0, 0, 10, 0, 0, 0, 20]);

        buffer.append!Foo(Foo.three);
        assert(buffer.data == [0, 0, 0, 10, 0, 0, 0, 20, 0, 0, 0, 30]);
    }

    {
        //enum - bool
        auto buffer = appender!(const ubyte[])();

        enum Bool: bool
        {
            bfalse = false,
            btrue = true,
        }

        buffer.append!Bool(Bool.btrue);
        assert(buffer.data == [1]);

        buffer.append!Bool(Bool.bfalse);
        assert(buffer.data == [1, 0]);

        buffer.append!Bool(Bool.btrue);
        assert(buffer.data == [1, 0, 1]);
    }

    {
        //enum - float
        auto buffer = appender!(const ubyte[])();

        enum Float: float
        {
            one = 32.0f,
            two = 25.0f
        }

        buffer.append!Float(Float.one);
        assert(buffer.data == [66, 0, 0, 0]);

        buffer.append!Float(Float.two);
        assert(buffer.data == [66, 0, 0, 0, 65, 200, 0, 0]);
    }

    {
        //enum - double
        auto buffer = appender!(const ubyte[])();

        enum Double: double
        {
            one = 32.0,
            two = 25.0
        }

        buffer.append!Double(Double.one);
        assert(buffer.data == [64, 64, 0, 0, 0, 0, 0, 0]);

        buffer.append!Double(Double.two);
        assert(buffer.data == [64, 64, 0, 0, 0, 0, 0, 0, 64, 57, 0, 0, 0, 0, 0, 0]);
    }

    {
        //enum - real
        auto buffer = appender!(const ubyte[])();

        enum Real: real
        {
            one = 32.0,
            two = 25.0
        }

        static assert(!__traits(compiles, buffer.append!Real(Real.one)));
    }
}

unittest
{
    import std.string;

    foreach(endianness; TypeTuple!(Endian.bigEndian, Endian.littleEndian))
    {
        auto toWrite = appender!(ubyte[])();
        alias Types = TypeTuple!(uint, int, long, ulong, short, ubyte, ushort, byte, uint);
        ulong[] values = [42, -11, long.max, 1098911981329L, 16, 255, 19012, 2, 17];
        assert(Types.length == values.length);

        size_t index = 0;
        size_t length = 0;
        foreach(T; Types)
        {
            toWrite.append!(T, endianness)(cast(T)values[index++]);
            length += T.sizeof;
        }

        auto toRead = toWrite.data;
        assert(toRead.length == length);

        index = 0;
        foreach(T; Types)
        {
            assert(toRead.peek!(T, endianness)() == values[index], format("Failed Index: %s", index));
            assert(toRead.peek!(T, endianness)(0) == values[index], format("Failed Index: %s", index));
            assert(toRead.length == length,
                   format("Failed Index [%s], Actual Length: %s", index, toRead.length));
            assert(toRead.read!(T, endianness)() == values[index], format("Failed Index: %s", index));
            length -= T.sizeof;
            assert(toRead.length == length,
                   format("Failed Index [%s], Actual Length: %s", index, toRead.length));
            ++index;
        }
        assert(toRead.empty);
    }
}

/**
Counts the number of trailing zeros in the binary representation of $(D value).
For signed integers, the sign bit is included in the count.
*/
private uint countTrailingZeros(T)(T value)
    if (isIntegral!T)
{
    // bsf doesn't give the correct result for 0.
    if (!value)
        return 8 * T.sizeof;

    static if (T.sizeof == 8 && size_t.sizeof == 4)
    {
        // bsf's parameter is size_t, so it doesn't work with 64-bit integers
        // on a 32-bit machine. For this case, we call bsf on each 32-bit half.
        uint lower = cast(uint)value;
        if (lower)
            return bsf(lower);
        value >>>= 32;
        return 32 + bsf(cast(uint)value);
    }
    else
    {
        return bsf(value);
    }
}

///
unittest
{
    assert(countTrailingZeros(1) == 0);
    assert(countTrailingZeros(0) == 32);
    assert(countTrailingZeros(int.min) == 31);
    assert(countTrailingZeros(256) == 8);
}

unittest
{
    foreach (T; TypeTuple!(byte, ubyte, short, ushort, int, uint, long, ulong))
    {
        assert(countTrailingZeros(cast(T)0) == 8 * T.sizeof);
        assert(countTrailingZeros(cast(T)1) == 0);
        assert(countTrailingZeros(cast(T)2) == 1);
        assert(countTrailingZeros(cast(T)3) == 0);
        assert(countTrailingZeros(cast(T)4) == 2);
        assert(countTrailingZeros(cast(T)5) == 0);
        assert(countTrailingZeros(cast(T)64) == 6);
        static if (isSigned!T)
        {
            assert(countTrailingZeros(cast(T)-1) == 0);
            assert(countTrailingZeros(T.min) == 8 * T.sizeof - 1);
        }
        else
        {
            assert(countTrailingZeros(T.max) == 0);
        }
    }
    assert(countTrailingZeros(1_000_000) == 6);
    foreach (i; 0..63)
        assert(countTrailingZeros(1UL << i) == i);
}

/**
Counts the number of set bits in the binary representation of $(D value).
For signed integers, the sign bit is included in the count.
*/
private uint countBitsSet(T)(T value)
    if (isIntegral!T)
{
    // http://graphics.stanford.edu/~seander/bithacks.html#CountBitsSetParallel
    static if (T.sizeof == 8)
    {
        T c = value - ((value >> 1) & 0x55555555_55555555);
        c = ((c >> 2) & 0x33333333_33333333) + (c & 0x33333333_33333333);
        c = ((c >> 4) + c) & 0x0F0F0F0F_0F0F0F0F;
        c = ((c >> 8) + c) & 0x00FF00FF_00FF00FF;
        c = ((c >> 16) + c) & 0x0000FFFF_0000FFFF;
        c = ((c >> 32) + c) & 0x00000000_FFFFFFFF;
    }
    else static if (T.sizeof == 4)
    {
        T c = value - ((value >> 1) & 0x55555555);
        c = ((c >> 2) & 0x33333333) + (c & 0x33333333);
        c = ((c >> 4) + c) & 0x0F0F0F0F;
        c = ((c >> 8) + c) & 0x00FF00FF;
        c = ((c >> 16) + c) & 0x0000FFFF;
    }
    else static if (T.sizeof == 2)
    {
        uint c = value - ((value >> 1) & 0x5555);
        c = ((c >> 2) & 0x3333) + (c & 0X3333);
        c = ((c >> 4) + c) & 0x0F0F;
        c = ((c >> 8) + c) & 0x00FF;
    }
    else static if (T.sizeof == 1)
    {
        uint c = value - ((value >> 1) & 0x55);
        c = ((c >> 2) & 0x33) + (c & 0X33);
        c = ((c >> 4) + c) & 0x0F;
    }
    else
    {
        static assert("countBitsSet only supports 1, 2, 4, or 8 byte sized integers.");
    }
    return cast(uint)c;
}

///
unittest
{
    assert(countBitsSet(1) == 1);
    assert(countBitsSet(0) == 0);
    assert(countBitsSet(int.min) == 1);
    assert(countBitsSet(uint.max) == 32);
}

unittest
{
    foreach (T; TypeTuple!(byte, ubyte, short, ushort, int, uint, long, ulong))
    {
        assert(countBitsSet(cast(T)0) == 0);
        assert(countBitsSet(cast(T)1) == 1);
        assert(countBitsSet(cast(T)2) == 1);
        assert(countBitsSet(cast(T)3) == 2);
        assert(countBitsSet(cast(T)4) == 1);
        assert(countBitsSet(cast(T)5) == 2);
        assert(countBitsSet(cast(T)127) == 7);
        static if (isSigned!T)
        {
            assert(countBitsSet(cast(T)-1) == 8 * T.sizeof);
            assert(countBitsSet(T.min) == 1);
        }
        else
        {
            assert(countBitsSet(T.max) == 8 * T.sizeof);
        }
    }
    assert(countBitsSet(1_000_000) == 7);
    foreach (i; 0..63)
        assert(countBitsSet(1UL << i) == 1);
}

private struct BitsSet(T)
{
    static assert(T.sizeof <= 8, "bitsSet assumes T is no more than 64-bit.");

    this(T value, size_t startIndex = 0)
    {
        _value = value;
        uint n = countTrailingZeros(value);
        _index = startIndex + n;
        _value >>>= n;
    }

    @property size_t front()
    {
        return _index;
    }

    @property bool empty() const
    {
        return !_value;
    }

    void popFront()
    {
        assert(_value, "Cannot call popFront on empty range.");

        _value >>>= 1;
        uint n = countTrailingZeros(_value);
        _value >>>= n;
        _index += n + 1;
    }

    @property auto save()
    {
        return this;
    }

    @property size_t length()
    {
        return countBitsSet(_value);
    }

    private T _value;
    private size_t _index;
}

/**
Range that iterates the indices of the set bits in $(D value).
Index 0 corresponds to the least significant bit.
For signed integers, the highest index corresponds to the sign bit.
*/
auto bitsSet(T)(T value)
    if (isIntegral!T)
{
    return BitsSet!T(value);
}

///
unittest
{
    assert(bitsSet(1).equal([0]));
    assert(bitsSet(5).equal([0, 2]));
    assert(bitsSet(-1).equal(iota(32)));
    assert(bitsSet(int.min).equal([31]));
}

unittest
{
    foreach (T; TypeTuple!(byte, ubyte, short, ushort, int, uint, long, ulong))
    {
        assert(bitsSet(cast(T)0).empty);
        assert(bitsSet(cast(T)1).equal([0]));
        assert(bitsSet(cast(T)2).equal([1]));
        assert(bitsSet(cast(T)3).equal([0, 1]));
        assert(bitsSet(cast(T)4).equal([2]));
        assert(bitsSet(cast(T)5).equal([0, 2]));
        assert(bitsSet(cast(T)127).equal(iota(7)));
        static if (isSigned!T)
        {
            assert(bitsSet(cast(T)-1).equal(iota(8 * T.sizeof)));
            assert(bitsSet(T.min).equal([8 * T.sizeof - 1]));
        }
        else
        {
            assert(bitsSet(T.max).equal(iota(8 * T.sizeof)));
        }
    }
    assert(bitsSet(1_000_000).equal([6, 9, 14, 16, 17, 18, 19]));
    foreach (i; 0..63)
        assert(bitsSet(1UL << i).equal([i]));
}
