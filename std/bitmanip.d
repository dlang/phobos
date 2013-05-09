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
import std.range;
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
        static if (len + offset <= uint.sizeof * 8)
            alias uint MasksType;
        else
            alias ulong MasksType;
        enum MasksType
            maskAllElse = ((1uL << len) - 1u) << offset,
            signBitCheck = 1uL << (len - 1),
            extendSign = ~((cast(MasksType)1u << len) - 1);
        static if (T.min < 0)
        {
            enum long minVal = -(1uL << (len - 1));
            enum ulong maxVal = (1uL << (len - 1)) - 1;
        }
        else
        {
            enum ulong minVal = 0;
            enum ulong maxVal = (1uL << len) - 1;
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
                "("~store~" & "
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
                " (("~store~" & ~cast(typeof("~store~"))"~myToString(maskAllElse)~")"
                " | ((cast(typeof("~store~")) v << "~myToString(offset)~")"
                " & "~myToString(maskAllElse)~"));}\n"
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
            alias ubyte StoreType;
        else static if (offset == ushort.sizeof * 8)
            alias ushort StoreType;
        else static if (offset == uint.sizeof * 8)
            alias uint StoreType;
        else static if (offset == ulong.sizeof * 8)
            alias ulong StoreType;
        else
        {
            static assert(false, "Field widths must sum to 8, 16, 32, or 64");
            alias ulong StoreType; // just to avoid another error msg
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
        Ldone:
            ;
        }
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
     * in the array. Does not copy the data.
     *
     * This is the inverse of $(D opCast).
     */
    void init(void[] v, size_t numbits)
    in
    {
        assert(numbits <= v.length * 8);
        assert((v.length & 3) == 0);
    }
    body
    {
        ptr = cast(size_t*)v.ptr;
        len = numbits;
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
        alias TypeTuple!(uint, int, long, ulong, short, ubyte, ushort, byte, uint) Types;
        ulong[] values = [42, -11, long.max, 1098911981329L, 16, 255, 19012, 2, 17];
        assert(Types.length == values.length);

        size_t index = 0;
        size_t length = 0;
        foreach(T; Types)
        {
            toWrite.append!T(cast(T)values[index++]);
            length += T.sizeof;
        }

        auto toRead = toWrite.data;
        assert(toRead.length == length);

        index = 0;
        foreach(T; Types)
        {
            assert(toRead.peek!T() == values[index], format("Failed Index: %s", index));
            assert(toRead.peek!T(0) == values[index], format("Failed Index: %s", index));
            assert(toRead.length == length,
                   format("Failed Index [%s], Actual Length: %s", index, toRead.length));
            assert(toRead.read!T() == values[index], format("Failed Index: %s", index));
            length -= T.sizeof;
            assert(toRead.length == length,
                   format("Failed Index [%s], Actual Length: %s", index, toRead.length));
            ++index;
        }
        assert(toRead.empty);
    }
}
