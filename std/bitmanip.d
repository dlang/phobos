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
           Era Scarecrow
Source: $(PHOBOSSRC std/_bitmanip.d)
*/
/*
         Copyright Digital Mars 2007 - 2012.
Distributed under the Boost Software License, Version 1.0.
   (See accompanying file LICENSE_1_0.txt or copy at
         http://www.boost.org/LICENSE_1_0.txt)
*/
module bitmanip;

//debug = bitarray;                // uncomment to turn on debugging printf's

import core.bitop;
import std.traits;
import std.algorithm;
import std.string;
import std.ascii;

version(unittest)
{
    import std.stdio;
    import std.typetuple;
    import core.stdc.stdio;
}

//CTFE has issues if you use the std.string version at present
private int indexOf(string str, char letter) pure
{
    foreach(i, c; str)
        if (c == letter)
            return i;
    return -1;
}

private string myToStringHex(ulong n) pure
{
    enum s = "0123456789abcdef";
    enum len = s.length;
    if (n < len)
        return "0x" ~ s[cast(size_t) n .. (cast(size_t) n + 1)];
    else
        return myToStringHex(n / len) ~ myToStringHex(n % len)[2 .. $];
}

//for debugging
private string myToStringx(long n) pure
{
    enum s = "0123456789";
    enum len = s.length;

    if (n < 0)
        return "-" ~ myToString(cast(ulong) -n);

    if (n < len)
        return s[cast(size_t) n .. (cast(size_t) n + 1)];
    else
        return myToStringx(n / len) ~ myToStringx(n % len);
}

private ulong myToLongFromHex(string str) pure
{
    enum l = "0123456789abcdef";
    enum u = "0123456789ABCDEF";

    ulong sum;

    foreach(ch; str[2 .. $]) {
        assert(l.indexOf(ch) != -1 || u.indexOf(ch) != -1);
        sum <<= 4;

        if (l.indexOf(ch) != -1)
            sum += l.indexOf(ch);
        else if (u.indexOf(ch) != -1)
            sum += u.indexOf(ch);
    }

    return sum;
}

private ulong myToLong(string str) pure
{
    ulong sum;

    enum d = "0123456789";
    enum len = d.length;

    if (str == "true")
        return 1;
    if (str == "false")
        return 0;

    if (str.length > 2 && str[0 .. 2] == "0x") {
        return myToLongFromHex(str);
    }

    if (str[0] == '-')
        return -myToLong(str[1 .. $]);

    foreach(ch; str) {
        assert(d.indexOf(ch) != -1);
        sum *= len;
        sum += d.indexOf(ch);
    }

    return sum;
}

unittest
{
    assert("01234".indexOf('2') == 2);
    assert("01234".indexOf('x') == -1);

    assert(myToStringHex(0x12340deed) == "0x12340deed");

    assert(myToStringx(-100) == "-100");
    assert(myToStringx(5) == "5");
    assert(myToStringx(512) == "512");
    assert(myToStringx(123) == "123");
    assert(myToStringx(-123) == "-123");

    assert(myToLongFromHex("0x1234") == 0x1234);
    assert(myToLongFromHex("0x90dead") == 0x90dead);
    assert(myToLongFromHex("0x90BEEF") == 0x90beef);

    assert(myToLong("123") == 123);
    assert(myToLong("-123") == -123);
    assert(myToLong("true") == 1);
    assert(myToLong("false") == 0);
    assert(myToLong("0x123") == 0x123);

    assert(myToString(45) == "45");
    assert(myToString(1UL << 32) == "0x100000000UL");

    assert(strip("   123   ") == "123");
}


//within a certain size we don't need to bother with hex, right?
//if you print the mixin data out it makes a bit more sense this way.
private string myToString(long n, bool force64 = false) pure
{
    //useful for the masks, specifically if you invert it. Fixes 8876
    if (force64)
        return myToStringHex(n) ~ "UL";

    if (n >= short.min && n <= short.max)
        return myToStringx(n);

    return myToStringHex(n) ~ ((n > uint.max || n < uint.min) ? "UL" : "U");
}

//pair to split name=value into their two halfs safely.
private string getName(string nameAndValue)
{
    int equalsChar = nameAndValue.indexOf('=');
    if (equalsChar != -1)
        return strip(nameAndValue[0 .. equalsChar]);
    return strip(nameAndValue);
}


private ulong getValue(string nameAndValue)
{
    int equalsChar = nameAndValue.indexOf('=');
    if (equalsChar != -1)
        return myToLong(strip(nameAndValue[equalsChar+1 .. $]));
    return 0;
}

unittest
{
    assert(getName("test") == "test");
    assert(getValue("test") == 0);

    assert(getName("test=100") == "test");
    assert(getValue("test=100") == 100);

    assert(getName("  test  =  100  ") == "test");
    assert(getValue("  test  =  100  ") == 100);
}


private template createAccessors(
    string store, T, string nameAndValue, size_t len, size_t offset)
{
    enum name = getName(nameAndValue),
                defaultValue = getValue(nameAndValue);

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
            static assert(cast(long) minVal <= cast(long) defaultValue &&
                    cast(long) maxVal >= cast(long) defaultValue,
                        "Default value outside of valid range:"
                        ~"\nVariable: " ~ name
                        ~"\nMinimum: " ~ myToStringx(minVal)
                        ~"\nMaximum: " ~ myToStringx(maxVal)
                        ~"\nDefault: " ~ myToStringx(cast(long) defaultValue));
        }
        else
        {
            enum ulong minVal = 0;
            enum ulong maxVal = (1uL << len) - 1;
            static assert(minVal <= defaultValue && maxVal >= defaultValue,
                "Default value outside of valid range:"
                ~"\nVariable: " ~ name
                ~"\nMinimum: " ~ myToStringx(minVal)
                ~"\nMaximum: " ~ myToStringx(maxVal)
                ~"\nDefault: " ~ myToStringx(defaultValue));
        }

        enum ulong defVal = (defaultValue << offset) & maskAllElse;

        static if (is(T == bool))
        {
            static assert(len == 1);
            enum result =
            // constants
                //only optional for cleaner namespace
                //two underscores used since much less likely to clash with other fields
                (defVal ? "enum " ~ name ~ "__def = " ~ myToString(defVal) ~ ";\n" : "\n")
            // getter
                ~"bool " ~ name ~ "() @property @safe pure const nothrow { return "
                ~"("~store~" & "~myToString(maskAllElse, true)~") != 0;}\n"
            // setter
                ~"void " ~ name ~ "(bool v) @property @safe pure nothrow {"
                ~"if (v) "~store~" |= "~myToString(maskAllElse, true)~";"
                ~"else "~store~" &= ~"~myToString(maskAllElse, true)~";}\n";
        }
        else
        {
            // constants
            enum result = "enum "~T.stringof~" "~name~"__min = cast("~T.stringof~")"
                ~(minVal < 0 ? myToString(cast(long) minVal) : myToString(minVal))~"; "
                ~" enum "~T.stringof~" "~name~"__max = cast("~T.stringof~")"
                ~myToString(maxVal)~"; "
                //only optional for cleaner namespace
                ~ (defVal ? "enum " ~ name ~ "__def = " ~ myToString(defVal) ~ ";\n" : "\n")
            // getter
                ~ ""~T.stringof~" "~name~"() @property @safe pure const nothrow { auto result = "
                ~ "("~store~" & "
                ~ myToString(maskAllElse) ~ ") >>"
                ~ myToString(offset) ~ ";"
                ~ (T.min < 0
                   ? "if (result >= " ~ myToString(signBitCheck)
                   ~ ") result |= " ~ myToString(extendSign) ~ ";"
                   : "")
                ~ " return cast("~T.stringof~") result;}\n"
            // setter
                ~"void "~name~"("~T.stringof~" v) @property @safe pure nothrow { "
                ~"assert(v >= "~name~"__min); "
                ~"assert(v <= "~name~"__max); "
                ~store~" = cast(typeof("~store~"))"
                " (("~store~" & ~"~myToString(maskAllElse, true)~")"
                " | ((cast(typeof("~store~")) v << "~myToString(offset)~")"
                " & "~myToString(maskAllElse, true)~"));}\n\n";
        }
    }
}

private template createStoreName(Ts...)
{
    static if (Ts.length < 2)
        enum createStoreName = "";
    else
        enum createStoreName = "_" ~ getName(Ts[1]) ~ createStoreName!(Ts[3 .. $]);
}
unittest
{
    //make sure added defaults don't interfere with store name.
    assert(createStoreName!(int, "abc", 1, int, "def", 1) == "_abc_def");
    assert(createStoreName!(int, "abc=5", 1, int, "def=true", 1) == "_abc_def");
    assert(createStoreName!(int, " abc = -5 ", 1, int, " def = true ", 1) == "_abc_def");
}

private template createFields(string store, size_t offset, string defaults, Ts...)
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
        //if we have any defaults, auto assign, otherwise blank.
        //bitmanip used in a union we will have a 'overlapping initialization' otherwise
        enum result = "private " ~ StoreType.stringof ~ " " ~ store ~
                (defaults.length ? " = " ~ defaults : "") ~ ";";
    }
    else
    {
        enum result
            = createAccessors!(store, Ts[0], Ts[1], Ts[2], offset).result
            ~ createFields!(store, offset + Ts[2], defaults ~
                //if we have a bitfield name
                (Ts[1].length ? (
                    //and it has a value
                    getValue(Ts[1]) ? (
                        //if we have a previous value, OR it, appending our new value
                        (defaults.length ? " | " : "")
                        ~getName(Ts[1]) ~ "__def"
                    ) : ""
                ) : ""),
                Ts[3 .. $]).result;
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
        uint, "z=1",  2,
        bool, "flag", 1));
}
A obj;
assert(obj.z == 1);
obj.x = 2;
obj.z = obj.x;
----

The example above creates a bitfield pack of eight bits, which fit in
one $(D_PARAM ubyte). The bitfields are allocated starting from the
least significant bit, i.e. x occupies the two least significant bits
of the bitfields storage.

Adding a default value is possible using adding '=value' on the variable
name. It will fail to compile if your default value is outside the range
that the bit could hold. IE 'ubyte, "x=64", 5'. Do not use this if you
intend to use it in a union, or you will get a 'overlapping initialization'
compile time error.

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
    enum { bitfields = createFields!(createStoreName!(T), 0, "", T).result }
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

    //test default values
    struct WithDefaults {
        mixin(bitfields!(
                bool, "b_f=false", 1,
                bool, "b_t=true", 1,
                uint, "ii_min=0", 3,
                uint, "ii_max=7", 3,
                short, "  s_min  =  -8  ", 4,   //test spaces
                short, "s_max=7", 4));

        mixin(bitfields!(
                bool, "b", 1,
                uint, "ii", 3,
                short, "  s  ", 4));
    }
    WithDefaults wd;

    with(wd) {
        //non-specified variables go to 0
        assert(b == false);
        assert(ii == 0);
        assert(s == 0);

        //assigned defaults should be set.
        assert(b_f == false);
        assert(b_t == true);
        assert(ii_min == 0);
        assert(ii_max == 7);
        assert(s_min == -8);
        assert(s_max == 7);

        assert(ii_min__max == ii_max__max);
        assert(ii_max__min == ii_min__min);

        assert(ii_min__min == ii_min);
        assert(ii_max__max == ii_max);
        assert(s_min__min == s_min);
        assert(s_max__max == s_max);
    }

/+
    /*
      Ensures there's no 'overlapping initialization'.
      Compiling is enough to ensure it works. If any of these has a
      default; say 'flDash=true', then the problem would appear.
    */
    static assert(__traits(compiles, {
        union xxx {
            ubyte allFlags;
            mixin(bitfields!(
                    bool, "flDash", 1,
                    bool, "flZero", 1,
                    bool, "flSpace", 1,
                    bool, "flPlus", 1,
                    bool, "flHash", 1,
                    ubyte, "", 3));
        }}));
+/
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

//functions preparing for BitArray

/**
  Contains common enum values for bit related data.
  Enums:
  ----
  alias enumBits!ubyte enumUByte;
  assert(enumUByte.bitsPerT == 8);     //bits for the type
  assert(enumUByte.logT == 3);         //log2(bitsPerT)
  assert(enumUByte.logTMask == 7);    //mask to include logT bits on
  ----
*/
template enumBits(T)
if(isArray!(T) == false && (isNumeric!(T) || is(T == void)))
{
    enum {
        bitsPerT = T.sizeof * 8,
        logT = log2(bitsPerT),
        logTMask = (1 << logT) - 1,
    }

    /**
     used for dividing the lower bit offset and the array offset, removing magic numbers
     ----
     alias enumBits!ubyte enumUByte;
     assert(enumUByte.arrayIndex(7) == 0);
     assert(enumUByte.arrayIndex(8) == 1);
     assert(enumUByte.arrayIndex(15) == 1);
     assert(enumUByte.arrayIndex(16) == 2);
     ----
    */
    static size_t arrayIndex(ulong index) @safe pure nothrow
    {
        return cast(size_t) (index >> logT);
    }

    /**
     Compliment of arrayIndex. Give the bit offset for the array
     ----
     alias enumBits!ubyte enumUByte;
     assert(enumUByte.bitIndex(7) == 7);
     assert(enumUByte.bitIndex(8) == 0);
     assert(enumUByte.bitIndex(12) == 4); //12 % 8
     ----
    */
    static size_t bitIndex(ulong index) @safe pure nothrow
    {
        return cast(size_t) (index & logTMask);
    }
}

//simple log2 function not requiring floating point/real
private nothrow size_t log2(T)(T val) @property @safe pure
if(isIntegral!(T) && isFloatingPoint!(T) == false)
{
    size_t shifts;

    if (val) {
        val--;

        while (val) {
            val >>>= 1;
            shifts++;
        }
    }

    return shifts;
}

unittest
{
//    assert(log2(0) == 0);    //correct?
//    assert(log2(1) == 0);    //correct?
    assert(log2(2) == 1);
    assert(log2(3) == 2);
    assert(log2(4) == 2);
    assert(log2(5) == 3);
    assert(log2(6) == 3);
    assert(log2(7) == 3);
    assert(log2(8) == 3);
    assert(log2(9) == 4);
}

unittest
{
    with(enumBits!size_t)
    {
        assert(bitsPerT == size_t.sizeof * 8);
        assert(arrayIndex(30) == 30 / bitsPerT);
        assert(arrayIndex(60) == 60 / bitsPerT);
        assert(arrayIndex(70) == 70 / bitsPerT);
        assert(arrayIndex(63) == 63 / bitsPerT);

        assert(bitIndex(30) == 30 % bitsPerT);
        assert(bitIndex(60) == 60 % bitsPerT);
        assert(bitIndex(70) == 70 % bitsPerT);
        assert(bitIndex(63) == 63 % bitsPerT);
    }

    assert(enumBits!void.bitsPerT == 8);

    with(enumBits!byte)
    {
        assert(bitsPerT == byte.sizeof * 8);
        assert(arrayIndex(30) == 30 / bitsPerT);
        assert(arrayIndex(60) == 60 / bitsPerT);
        assert(arrayIndex(70) == 70 / bitsPerT);
        assert(arrayIndex(63) == 63 / bitsPerT);

        assert(bitIndex(30) == 30 % bitsPerT);
        assert(bitIndex(60) == 60 % bitsPerT);
        assert(bitIndex(70) == 70 % bitsPerT);
        assert(bitIndex(63) == 63 % bitsPerT);
    }
}

//returns how many bits a particular array (in it's entirety) has.
ulong totalBits(T)(T[] arr) @property @safe pure nothrow
{
    return enumBits!T.bitsPerT * arr.length;
}

//returns how many bits a particular type has
ulong totalBits(T)(T e) @property @safe pure nothrow
if(isArray!(T) == false)
{
    return enumBits!T.bitsPerT;
}

unittest
{
    ubyte[10] a;
    size_t[2] b;
    ubyte[] c;
    c.length = 3;

    assert(a.totalBits == (ubyte.sizeof * a.length * 8));
    assert(b.totalBits == (size_t.sizeof * b.length * 8));
    assert(c.totalBits == (ubyte.sizeof * c.length * 8));

    int i;
    assert(i.totalBits == (int.sizeof * 8));
}

/**
 * Returns the true/false value of the bit
 * replacement so ulong can be used for the bit number offset.
 */
bool getBit(T)(in T[] array, ulong bitnum) @safe pure
if(isIntegral!(T) && isFloatingPoint!(T) == false)
{
    with (enumBits!T)
    {
        size_t i = array[arrayIndex(bitnum)];
        return (i >> bitIndex(bitnum)) & 1;
    }
}

/**
 * Sets the bit to the bool value
 */
void setBit(T)(T[] array, ulong bitnum, bool value) @safe pure
if(isIntegral!(T) && isFloatingPoint!(T) == false)
{
    with (enumBits!T)
    {
        if (value)
            array[arrayIndex(bitnum)] |= (1 << bitIndex(bitnum));
        else
            array[arrayIndex(bitnum)] &= ~(1 << bitIndex(bitnum));
    }
}

/**
 * xor/flips the specific bit
 */
void xorBit(T)(T[] array, ulong bitnum) @safe pure
if(isIntegral!(T) && isFloatingPoint!(T) == false)
{
    with (enumBits!T)
    {
        array[arrayIndex(bitnum)] ^= (1 << bitIndex(bitnum));
    }
}

/**
 * checks for the first true/on bit.
 * If there is no on bit, returns -1
 */
long firstOnBit(T)(in T[] array) @safe pure
if(isIntegral!(T) && isFloatingPoint!(T) == false)
{
    ulong i;

    with(enumBits!T)
    {
        ulong length = array.length * bitsPerT;

        //bulk check
        while(i < array.length && !array[cast(size_t) i])
            i++;

        i *= bitsPerT;

        for(; i < length; i++)
        {
            if (getBit(array, i))
                return i;
        }
    }

    return -1;    //proper return for none found?
}

unittest
{
    size_t[1] bits;

    bits = 0x00005555;
    //getBit
    assert(getBit(bits, 0) == true);
    assert(getBit(bits, 1) == false);
    assert(getBit(bits, 2) == true);
    assert(getBit(bits, 3) == false);
    assert(getBit(bits, 12) == true);

    //set
    setBit(bits, 7, true);
    assert(bits[0] == 0x000055d5, myToStringHex(bits[0]));

    setBit(bits, 7, false);
    assert(bits[0] == 0x00005555);

    //xor
    xorBit(bits, 7);
    assert(bits[0] == 0x000055d5);

    xorBit(bits, 7);
    assert(bits[0] == 0x00005555);

    bits = 32;
    assert(firstOnBit(bits) == 5);

    //bulk
    ubyte[4] ub;

    assert(firstOnBit(ub) == -1);

    ub[3] = 255;
    assert(firstOnBit(ub) == 24);
}
 
/**
 * An array for bits
 */
struct BitArray {
    mixin(bitfields!(
        bool, "isCompact=true", 1,
        bool, "canExpand=true", 1,
        //from 0
        ulong, "_startBit", 7,
        //from end, so (length - _maxOffset) = endBit
        ulong, "_endBit=" ~ myToStringx(compact.sizeof * 8), 7)
    );

    union {
        size_t[] normal;
        ubyte[normal.sizeof] compact_ubyte;
        
        /*Some explaination needed here. It's intended to dynamically figure
          out the proper number of bytes/bits that's already used by normal (above).
          convert to raw byte count, then figure out how many size_t's there are.
          In should be 2 (8/4, or 16/8), but magic numbers aren't good.
          Plus if array/fat pointers change...*/
        size_t[normal.sizeof / size_t.sizeof] compact;
    }

    enum maxCompactBits = compact.sizeof * 8;
    enum bitsPerSizeT = enumBits!(size_t).bitsPerT;
    alias enumBits!(size_t).arrayIndex arrayIndex;
    alias enumBits!(size_t).bitIndex bitIndex;
    alias length opDollar;

    /// Determines the offset of the starting bit in the $(D BitArray)
    ulong startBit() @property @safe pure const nothrow
    {
        return _startBit;
    }

    /**********************************************
     *    Changing the startBit may cause the array bounds to change/shrink.
     *    You cannot go lower than the startBit if 'canExpand' is false,
     *    but you can always shrink it up to endBit
     */
    ulong startBit(ulong newStartingBit) @property @safe pure
    in
    {
        if (newStartingBit < startBit)
            assert(canExpand, "Range Violation");
    }
    body
    {
        if (newStartingBit < _startBit)
        {
            _startBit = newStartingBit;
            return newStartingBit;
        }

        //is shrinking an option?
        if (!isCompact && newStartingBit >= bitsPerSizeT)
        {
            size_t st = cast(size_t) newStartingBit / bitsPerSizeT;
            normal = normal[st .. $];    //shorten
            newStartingBit = bitIndex(newStartingBit);    //truncate to new bit startBit
        }

        _startBit = newStartingBit;
        return newStartingBit;
    }

    /// Location for the end (one past) of the $(D BitArray)
    ulong endBit() @property @safe pure const nothrow
    {
        if(isCompact)
            return compact.totalBits - _endBit;

        return normal.totalBits - _endBit;
    }

    /**********************************************
     * Sets the location of the end of the bit Array. You can shrink down to startBit,
     * and you go past endBit unless 'canExpand' is true.
     */
    ulong endBit(ulong newEndingBit) @property @trusted pure
    {
        ulong bits = maxBits;
        if (newEndingBit > endBit)
        {
            //movable to 'in' contract?
            if(!canExpand || newEndingBit > bits)
            {
                debug
                {
                    this.print();
                    writeln("endBit = ", newEndingBit);
                }
                throw new Exception("Range Violation");
            }

            _endBit = bits - newEndingBit;
            return newEndingBit;
        }

        //see if we can shorten the array if it's shrinking enough
        if (!isCompact && (endBit - newEndingBit) >= bitsPerSizeT)
        {
            size_t newEnd = cast(size_t) (newEndingBit / bitsPerSizeT) + (bitIndex(newEndingBit) ? 1 : 0);
            normal = normal[0 .. newEnd];    //shorten
            bits = normal.totalBits;
        }

        _endBit = bits - newEndingBit;
        return newEndingBit;
    }

    ///Returns the number of bits accessible in the array, ignoring startBit and endBit
    ulong maxBits() @safe @property pure const nothrow
    {
        if (isCompact)
            return compact.totalBits;
        else
            return normal.totalBits;
    }

    //issue 4123 - setting length during initialization
    ///
    this(ulong size)
    {
        if (size <= compact.totalBits)
        {
            isCompact = true;
            endBit = size;
        }
        else
            length = size;

        canExpand = true;
    }

    //without this, const bool[] and void[] get confused and errors during compile time.
    this(bool[] source)
    {
        init(source);
    }

    ///
    this(const bool[] source)
    {
        init(source);
    }

    ///
    this(void[] source)
    {
        this(source, 0, source.totalBits);
    }

    ///
    this(void[] source, ulong start, ulong end)
    {
        ulong len = end - start;

        //shrink pointer if we can first.
        if (start >= bitsPerSizeT)
        {
            size_t skip = arrayIndex(start) * size_t.sizeof;
            source = source[skip .. $];
            start = bitIndex(start);
            end = start + len;
        }

        //shrink off end (if we can)
        if (source.totalBits - end > bitsPerSizeT)
        {
            size_t last = (arrayIndex(end) + 1) * size_t.sizeof;
            source = source[0 .. last];
        }

        //if uneven, dup and resize.
        if (source.length % size_t.sizeof)
        {
            source = source.dup;
            size_t src_len = source.length / size_t.sizeof;    //how many size_t's now?
            source.length = (src_len + 1) * size_t.sizeof;    //add 1
            normal = cast(size_t[]) source;
            isCompact = false;
            canExpand = true;
            endBit = end;
            startBit = start;
            return;
        }

        length = source.totalBits;
        size_t[] t = cast(size_t[]) source;

        for(size_t i; i < t.length; ++i)
            setBulk(i, t[i]);

        startBit = start;
        endBit = end;
    }

    unittest {
        auto b = BitArray(10);
        assert(b.length == 10);

        ubyte[2] ub_2;
        ubyte[4] ub_4;

        auto b2 = BitArray(ub_2);
        auto b4 = BitArray(ub_4);

        assert(b2.length == 16, myToStringx(b2.length));
        assert(b4.length == 32);

        b = BitArray(ub_4, 5, 15);

        assert(b.length == 10);
        assert(b.startBit == 5);

        bool[] boolArray = [0,0,1,1];

        b = BitArray(boolArray);
        assert(b.length == 4);
        assert(b.getBulk(0) == 12);

        //non-compact versions
        b = BitArray(maxCompactBits * 2);
        assert(!b.isCompact());
        assert(b.length == (maxCompactBits * 2));

        ubyte[64] ub_64;
        ubyte[128] ub_128;

        b2 = BitArray(ub_64);
        b4 = BitArray(ub_128);

        assert(b2.length == ub_64.totalBits, myToStringx(b2.length));
        assert(b4.length == ub_128.totalBits, myToStringx(b4.length));

        b = BitArray(ub_64, 100, 200);
        assert(b.length == 100);
        assert(!b.isCompact());

        bool[maxCompactBits * 2] boolArray2;

        b = BitArray(boolArray2);
        assert(b.length == boolArray2.length);

        //confirm shrinking
        char[16] shrink = "can_you_do__this";

        BitArray sh = BitArray(shrink, 32, 96);
        assert(!sh.isCompact());
        assert(cast(char[]) sh.normal == "you_do__");

        //confirm odd shape
        char[] oddShape = shrink ~ "_too?";

        sh = BitArray(oddShape);
        assert(cast(char[]) sh.normal == "can_you_do__this_too?\0\0\0");

        //odd shape + shrink
        sh = BitArray(oddShape, 32, 96);
        assert(cast(char[]) sh.normal == "you_do__");
    }

    /* *********************************************
     * Gets the amount of native words backing this $(D BitArray).
     */
    size_t dim() @property @safe pure const nothrow
    {
        //Todo: Check math and add unittest!
        return cast(size_t)(length + bitsPerSizeT - 1 + startBit) / bitsPerSizeT;
    }

    /**********************************************
     * Gets the amount of bits in the $(D BitArray).
     */
    ulong length() @property @safe pure const nothrow
    {
        return endBit - startBit;
    }

    /**********************************************
     * Sets the length in bits for the $(D BitArray).
     * May cause memory reallocation.
     */
    ulong length(ulong newLength) @property @safe pure
    {
        //shrink without changing type or resizing
        if ((newLength + startBit) <= endBit)
        {
            endBit = newLength + startBit;
            return newLength;
        }

        //can grow in place?
        if (canExpand && (newLength + startBit) <= maxBits)
        {
            endBit = newLength + startBit;
            return newLength;
        }

        BitArray orig = this;










        size_t newdim = cast(size_t) ((startBit + newLength + bitsPerSizeT - 1) / bitsPerSizeT);
        isCompact = false;
        canExpand = true;
        _endBit = 0;

        //is it compact? Convert and copy to new memory space
        //otherwise our old data is nulled out
        if (orig.isCompact)
        {
            normal = null;
            normal.length = newdim;

            normal[0 .. orig.compact.length] = orig.compact[0 .. $];
        }
        else
            normal.length = newdim;


        endBit = newLength + startBit;
        return newLength;
    }

    unittest
    {
        //compact
        //shrink in place
        BitArray ba = BitArray([1,0,0,1,1,0,1,1]);
        BitArray slice;
        ba ~= ba; ba ~= ba;

        slice = ba;

        assert(ba.isCompact);
        ba.length = 30;

        assert(ba.length == 30);
        assert(ba == slice[0..30]);

        //grow in place
        ba.length = 32;
        assert(ba.length == 32);
        assert(ba == slice);

        //grow, requires copy
        BitArray blank = BitArray(256);
        assert(blank.toHash == 0);

        ba.length = 256;
        assert(ba.length == 256);
        assert(ba[0 .. 32] == slice);
        assert(ba[32 .. ba.length] == blank[32 .. blank.length]);

        //non compact.
        //shrink in place
        ba.init([1,0,0,1,1,0,1,1]);
        for(int i; i < 5; ++i)  //32*8 = 256
            ba ~= ba;

        ba = ba.dup;    //force 'can expand'
        assert(!ba.isCompact);
        slice = ba;
        ba.length = 246;
        assert(ba.length == 246);
        assert(ba == slice[0 .. 246]);
        assert(ba.normal is slice.normal);

        //grow in place
        ba.length = 256;
        assert(ba.length == 256);
        assert(ba == slice);
        assert(ba.normal is slice.normal);

        //grow, but should only increase the inner length
        ba.length = 512;
        assert(ba.length == 512);
        assert(ba[0 .. 256] == slice);
        assert(ba[256 .. ba.length] == blank);

        assert(!ba.isCompact);
        ba = ba[1 .. 17];   //slice, cannot naturally expand
        assert(!ba.isCompact);

        //auto compacting no longer valid, 'sometimes ref' not an option.
        //so removed from test suite
    }

    /**********************************************
     * Tries to reserve space for this growing $(D BitArray).
     * returns if it tried to reserve space or not.
     */
    bool reserve(ulong bitsSize) @trusted pure
    {
        /* Ensure it's not compact, or the size is larger than our current compact/visible.
          If we force it to not be compact, then if the length is updated it may convert back to
          the compact version.*/
        if ((isCompact || canExpand) && bitsSize <= maxBits)
            return false;

        //not compact; Rounded up
        size_t len = cast(size_t)((bitsSize + bitsPerSizeT - 1) / bitsPerSizeT);

        if (isCompact)
        {
            BitArray orig = this;
            isCompact = false;

            normal = null;
            normal.reserve(len);
            normal.length = compact.length;

            //raw copy no need to adjust lengths.
            normal[] = orig.compact[];
            canExpand = true;
        }
        else
        {
            //non-compact resize possible
            size_t[] ptr = normal;
            normal.reserve(len);    //not @safe: TODO: fix when reserve is pure and safe/trusted
            if (normal !is ptr)    //if it's relocated, it's expandable
                canExpand = true;
        }

        return true;
    }

    unittest
    {
        BitArray ba;
        
        //no expansion when it's bigger or the same.
        assert(!ba.reserve(32));
        assert(!ba.reserve(64));

        //give compact some data for expansion
        //(errors in code more obvious with non-zero)
        ba = BitArray(cast(bool[])[1,0,1,0,1,0]);
        const bb = ba;
                
        //larger, converts from compact to allocated
        assert(ba.reserve(1024));
        assert(ba.length == 6); //actual length hasn't changed.
        assert(ba == bb);
    }

    /* *********************************************
     * Gives indirect raw read access to the data this $(D BitArray) holds.
     */
    size_t getBulk(size_t index) @safe pure const
    in
    {
        if (isCompact) {
            assert(index < compact.length);
        } else
            assert(index < normal.length);

    }
    body
    {
        if (isCompact)
            return compact[index];

        return normal[index];
    }

    /* *********************************************
     * Gives indirect raw write access to the data this $(D BitArray) holds.
     */
    size_t setBulk(size_t index, size_t setValue) @safe pure
    in
    {
        if (isCompact) {
            assert(index < compact.length);
        } else
            assert(index < normal.length);

    }
    body
    {
        if (isCompact)
            return compact[index] = setValue;

        return normal[index] = setValue;
    }

    unittest
    {
        BitArray ba;
   
        ba.compact[0] = 100;
        ba.compact[1] = 200;
        assert(ba.getBulk(0) == 100);
        assert(ba.getBulk(1) == 200);
        ba.setBulk(0, 300);
        assert(ba.getBulk(0) == 300);

        ba.length = maxCompactBits * 2;
        assert(!ba.isCompact);
        ba.normal[0] = 300;
        ba.normal[1] = 400;
        assert(ba.getBulk(0) == 300);
        assert(ba.getBulk(1) == 400);
        ba.setBulk(0,500);
        assert(ba.getBulk(0) == 500);
    }

    /* *********************************************
    * Determines if a bulk (full size_t read/write) is possible, if so it
      activates the action on every bulk-able section it can.
  
      sliceStart/sliceEnd are for the current object (only). Index is the
      startBit within the slice and all following bitarrays.
  
      The action is a given operation, like 'l = r[0]'. l represents the
      current bitarray, and r is the arrays given afterwards. You can
      modify the r contents, but they won't be reflected in their source
      counterparts.
  
      you can also use break/continue to skip saving the result of l,
      (and go to the next bulk section) or break to immediately exit.
  
      The output is how many bits it went through using the bulk function.  
      ----
      BitArray ba;  //filled with data somewhere
      BitArray inp1, inp2;
      ulong i = canUseBulk!("l ^= r[0] & r[1]")(0, ba.length, 0, inp1, inp2);
      ----
    */
    ulong canUseBulk(string action)(ulong sliceStart, ulong sliceEnd, ulong index, const BitArray[] baInputs ...) @trusted pure
    in
    {
        assert(sliceStart <= length, "slice outside of range");
        assert(sliceStart <= sliceEnd, "Slice start/end are backwards");
        assert(sliceEnd <= length, "slice outside of range");
        assert((sliceEnd - sliceStart) + startBit >= index, "Starting index larger than slice area");
    }
    out(o)
    {
        assert(o <= sliceEnd - sliceStart);
    }
    body
    {
        ulong off = startBit + sliceStart;    //slice data
        ulong len = sliceEnd - sliceStart;
        ulong[] rLen;                       //lengths of arrays.
        size_t lIndex = arrayIndex(off + index);   //indexes startBit for bulk
        size_t[] rIndex;            //ditto, only for the right BitArray(s)
        size_t l = void;            //value for bulk (Left/current)
        size_t[] r;                 //value(s) for bulks (right BitArray(s))

        //there has to be at least size_t left to consider it
        if ((len - index) < bitsPerSizeT ||
                bitIndex(off + index))
            return 0;

        //cache basic results and ensure we are aligned right
        if(baInputs.length)
        {
            rLen.length = baInputs.length;
            rIndex.length = baInputs.length;
            r.length = baInputs.length;

            foreach(i, ba; baInputs)
            {
                if (bitIndex(ba.startBit + index))
                    return 0;
                rIndex[i] = arrayIndex(ba.startBit + index);
                rLen[i] = ba.length;
            }
        }

        size_t bulk;            //basically an index, also represents how many 'bulks' we've processed.
        ulong position = index; //bit startBit in question.

        for(; position < len &&
                len - position >= bitsPerSizeT;
                ++bulk, position += bitsPerSizeT)
        {

            //get all current 'bulk blocks'
            //return if not all the (current) blocks can be calculated in bulk
            foreach(i, ba; baInputs)
            {
                if(rLen[i]-position >= bitsPerSizeT)
                    r[i] = baInputs[i].getBulk(rIndex[i] + bulk);
                else
                    return bulk * bitsPerSizeT;
            }

            l = getBulk(lIndex + bulk);

            //the action
            mixin(action ~ ";");

            setBulk(lIndex + bulk, l);
        }

        return bulk * bitsPerSizeT;
    }

    /*
     * ditto. In const version l/r[] can't be modified. Mostly useful for some calculations or comparing
     */

    ulong canUseBulk(string action)(ulong sliceStart, ulong sliceEnd, ulong index, const BitArray[] baInputs ...) @trusted pure const
    in
    {

        assert(sliceStart <= length, "slice outside of range");
        assert(sliceStart <= sliceEnd, "Slice start/end are backwards");
        assert(sliceEnd <= length, "slice outside of range");
        assert(sliceEnd - sliceStart >= index, "Starting index larger than slice area");
    }
    out(o)
    {

        assert(o <= sliceEnd - sliceStart);
    }
    body
    {

        ulong off = startBit + sliceStart;    //slice data
        ulong len = sliceEnd - sliceStart;
        ulong[] rLen;                       //lengths of arrays.
        size_t lIndex = arrayIndex(off + index);   //indexes startBit for bulk
        size_t[] rIndex;            //ditto, only for the right BitArray(s)
        size_t[] rr;                 //value(s) for bulks (right BitArray(s))

        //there has to be at least size_t left to consider it
        if ((len - index) < bitsPerSizeT ||
                bitIndex(off + index))
            return 0;

        //cache basic results and ensure we are aligned right
        if(baInputs.length)
        {
            rLen.length = baInputs.length;
            rIndex.length = baInputs.length;
            rr.length = baInputs.length;

            foreach(i, ba; baInputs)
            {
                if (bitIndex(ba.startBit + index))
                    return 0;
                rIndex[i] = arrayIndex(ba.startBit + index);
                rLen[i] = ba.length;
            }
        }

        size_t bulk;            //basically an index, also represents how many 'bulks' we've processed.
        ulong position = index; //bit startBit in question.

        for(; position < len &&
                len - position >= bitsPerSizeT;
                ++bulk, position += bitsPerSizeT)
        {
            //get all current 'bulk blocks'
            //return if not all the (current) blocks can be calculated in bulk
            foreach(i, ba; baInputs)
            {
                if(rLen[i]-position >= bitsPerSizeT)
                    rr[i] = baInputs[i].getBulk(rIndex[i] + bulk);
                else
                    return bulk * bitsPerSizeT;
            }

            //being const it will error during compiling if either
            //are attempted to be changed.
            const size_t l = getBulk(lIndex + bulk);
            const size_t r[] = cast(const(size_t[])) rr;

            //the action/check
            mixin(action ~ ";");
        }

        return bulk * bitsPerSizeT;
    }

    unittest {
        int bpst2 = bitsPerSizeT / 2;
        BitArray a = BitArray(bitsPerSizeT * 3 + 1);    //+1 prevents dup from making it compact.
        BitArray b = BitArray(bitsPerSizeT * 3 + 1);
        BitArray ba = a[bpst2 .. a.length - bpst2];
        BitArray bb = b[bpst2 .. b.length - bpst2].dup;
        bb[] = true;

        const BitArray b_ba = ba.dup;
        const BitArray b_bb = bb.dup;

        //too small for size_t
        assert(!ba.canUseBulk!("l=r[0]")(0,0,0, bb));
        assert(!ba.canUseBulk!("l=r[0]")(0,16,0, bb));
        assert(!ba.canUseBulk!("l=r[0]")(0,bpst2,0, bb));
        assert(ba == b_ba);

        //large enough for size_t, but startBit wrong
        assert(!ba.canUseBulk!("l=r[0]")(0,ba.length, 0, bb));
        assert(!ba.canUseBulk!("l=r[0]")(0,ba.length, 5, bb));
        assert(!ba.canUseBulk!("l=r[0]")(0,ba.length, 10, bb));
        assert(!ba.canUseBulk!("l=r[0]")(0,ba.length, 15, bb));
        assert(!ba.canUseBulk!("l=r[0]")(0,ba.length, bpst2-1, bb));
        assert(ba == b_ba);

        //startBit of one is off
        assert(!ba.canUseBulk!("l=r[0]^r[1]")(0,ba.length, bpst2, b));
        assert(ba == b_ba);
        assert(bb == b_bb);

        //process one 
        assert(ba.canUseBulk!("l=r[0]")(0,ba.length, bpst2, bb) == bitsPerSizeT);
        assert(ba[bpst2 .. (bpst2 + bitsPerSizeT)] == b_bb[bpst2 .. (bpst2 + bitsPerSizeT)]);
   
        //slice allow startBit to match
        BitArray c = BitArray(bitsPerSizeT);
        c[bpst2 .. c.length] = true;

        assert(ba.canUseBulk!("l^=r[0]")(bpst2, ba.length, 0, c) == bitsPerSizeT);
        assert(ba[bpst2 .. (bpst2 + bitsPerSizeT)] == ~c);

        //const version check (real fast)
        const BitArray cb = b;
        assert(cb.canUseBulk!("if (l) break")(0, b.length, 0) == bitsPerSizeT * 3); //96 bulk is not 97 length..
        assert(b.canUseBulk!("if (l) break")(0, b.length, 0) == bitsPerSizeT * 3);

        b[bitsPerSizeT] = 1;
        assert(b.canUseBulk!("if (l) break")(0, b.length, 0) == bitsPerSizeT);

        //check one shorter than another
        a = BitArray(bitsPerSizeT * 2);    //+1 prevents dup from making it compact.
        b = BitArray(bitsPerSizeT * 3);
        const cca = a;
        const ccb = b;

        assert(a.canUseBulk!("")(0, a.length, 0, b) == bitsPerSizeT * 2);
        assert(b.canUseBulk!("")(0, b.length, 0, a) == bitsPerSizeT * 2);

        assert(cca.canUseBulk!("")(0, cca.length, 0, ccb) == bitsPerSizeT * 2);
        assert(ccb.canUseBulk!("")(0, ccb.length, 0, cca) == bitsPerSizeT * 2);
    }

    /**********************************************
     * Gets the $(D i)'th bit in the $(D BitArray).
     */
    bool opIndex(ulong index) @trusted pure const
    in
    {
        assert(index + startBit < endBit);
    }
    body
    {
        if (isCompact)
            return compact_ubyte.getBit(index + startBit);

        return (cast(const(ubyte)[]) normal).getBit(index + startBit);
    }

    unittest
    {
        void Fun(const BitArray arr) {
            auto x = arr[0];
            assert(x == 1);
        }

        BitArray a;
        a.length = 3;
        a[0] = 1;
        Fun(a);

        a = BitArray(maxCompactBits * 2); //non compact version
        a[0] = 1;
        Fun(a);
    }

    /**********************************************
     * Sets the $(D index)'th bit in the $(D BitArray).
     */
    bool opIndexAssign(bool b, ulong index) @trusted pure
    in
    {
        assert(index + startBit < endBit);
    }
    body
    {
        if (isCompact)
            compact_ubyte.setBit(index + startBit, b);
        else
            (cast(ubyte[]) normal).setBit(index + startBit, b);

        return b;
    }

    /**********************************************
     * Duplicates the $(D BitArray) and its contents.
     */
    BitArray dup() @property @trusted pure const
    {
        BitArray ba;

        //if it's already compact, no need to do anything special.
        if (isCompact)
            return cast(BitArray) this;

        //convert & shrink
        if (length <= maxCompactBits)
        {
            //these two already true by default
//            ba.isCompact = true;
//            ba.canExpand = true;
            ba.length = length;
            ba[] = this[];
            return ba;
        }

        //attempt to shrink the block, and only dup that
        size_t startBlock = arrayIndex(startBit);
        size_t bitOff = bitIndex(startBit);
        size_t endBlock = arrayIndex(endBit) + (bitIndex(startBit) ? 1 : 0);

        auto b = normal[startBlock .. endBlock].dup;
        ba.isCompact = false;
        ba.canExpand = true;
        ba.normal = b;
        ba.startBit = bitOff;
        ba.endBit = bitOff + length;

        return ba;
    }

    ///ditto, but immutable
    immutable(BitArray) idup() @property @trusted pure const
    {
        BitArray ba = this.dup;
        return cast(immutable(BitArray)) ba;
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
        {
            debug(bitarray) printf("b[%d] = %d\n", i, b[i]);
            assert(b[i] == (((i ^ 1) & 1) ? true : false));
        }

        assert(a.isCompact);
        assert(b.isCompact);
        a.length = maxCompactBits * 2;
        b = a.dup;
        assert(!a.isCompact);
        assert(!b.isCompact);

        for (i = 0; i < 3; i++)
        {
            debug(bitarray) printf("b[%d] = %d\n", i, b[i]);
            assert(a[i] == (((i ^ 1) & 1) ? true : false));
            assert(b[i] == (((i ^ 1) & 1) ? true : false));
        }

        immutable x1 = a.idup;
        immutable x2 = x1.idup;    //special idup

        assert(x1 == x2);
        
        //dup can end up creating a compact,
        //safe to assume so...
        assert(a.length >= 21, "Length too short for unittest (But not a test itself)");
        assert(!a.isCompact);

        a = a[5 .. 21]; //16 bits long, just randomly selected
        b = a.dup;

        assert(a.length == 16 && b.length == 16 && a.length == b.length, "length of dup doesn't match original array");
        assert(b.isCompact, "dup did not compact small array");
        assert(a == b, "dup not equalling original slice");
    }

    /**********************************************
     * Support for $(D foreach) loops for $(D BitArray).
     */
    int opApply(scope int delegate(ref bool) dg)
    {
        int result;
        ulong len = length;
        ulong i;

        for (; i < len; i++)
        {
            bool orig;
            bool b = orig = this[i];
            result = dg(b);

            if (orig != b)
                this[i] = b;

            if (result)
                break;
        }
        return result;
    }

    /** ditto */
    int opApply(scope int delegate(ref ulong, ref bool) dg)
    {
        int result;
        ulong i;
        ulong len = length;

        for (; i < len; i++)
        {
            bool orig;
            bool b = orig = this[i];

            result = dg(i, b);

            if (b != orig)
                this[i] = b;

            if (result)
                break;
        }
        return result;
    }

    /**********************************************
     * Support for $(D foreach) loops, for const/immutable arrays.
     */
    int opApply(scope int delegate(bool) dg) const
    {
        int result;
        ulong i;
        ulong len = length;

        for (; i < len; i++)
        {
            result = dg(this[i]);

            if (result)
                break;
        }
        return result;
    }

    /** ditto */
    int opApply(scope int delegate(ref ulong, bool) dg) const
    {
        int result;
        ulong i;
        ulong len = length;

        for (; i < len; i++)
        {
            result = dg(i, this[i]);

            if (result)
                break;
        }
        return result;
    }

    unittest
    {
        debug(bitarray) printf("BitArray.opApply unittest\n");

        bool[] ba = [1,0,1];

        BitArray a; a.init(ba);
        const BitArray ac = BitArray (ba);
        immutable BitArray ai = ac.idup;

        //identical switch-case on every check.
        static void sw_i(bool b, ulong i) {
            switch (i)
            {
                case 0: assert(b == true); break;
                case 1: assert(b == false); break;
                case 2: assert(b == true); break;
                default: assert(0);
            }
        }

        //compact versions
        int i;
        foreach (b; a)
            sw_i(b, i++);

        foreach (j, b; a)
            sw_i(b, j);

        //const versions
        i = 0;
        foreach (b; ac)
            sw_i(b, i++);

        foreach (j,b;ac)
            sw_i(b, j);

        //immutable versions
        i = 0;
        foreach (b; ai)
            sw_i(b, i++);

        foreach (j,b;ai)
            sw_i(b, j);


        //non-compact versions
        a.init(ba);
        a.length = maxCompactBits * 2;
        a = a[0 .. 3];
        assert(!a.isCompact());

        i = 0;
        foreach (b;a)
            sw_i(b, i++);

        foreach (j, b; a)
            sw_i(b, j);

        //const version non-compact
        const BitArray slice = a;
        i = 0;
        foreach (b; slice)
            sw_i(b, i++);

        foreach (j, b; slice)
            sw_i(b, j);

        immutable BitArray slice2 = a.idup;
        i = 0;
        foreach (b; slice2)
            sw_i(b, i++);

        foreach (j, b; slice2)
            sw_i(b, j);
    }


    /**********************************************
     * Reverses the bits of the $(D BitArray).
     */
    deprecated BitArray reverse() @trusted @property
    out (result)
    {
        assert(result == this);
    }
    body
    {
        if (length >= 2)
        {
            bool t;
            ulong lo, hi;

            lo = 0;
            hi = length - 1;
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
        static bool[6] data = [0,1,0,1,1,0];
        int i;

        b.init(data);
        assert(b.isCompact());
        //slice aware version
        b = b[1 .. $];

        b.reverse;
        for (; i < b.length; i++)
        {
            assert(b[i] == data[5 - i]);
        }

        //non-compact version.
        b.length = maxCompactBits * 2;
        b[] = 0;
        b[0 .. data.length] = data[0 .. $];
        //still slice aware
        b = b[1 .. $];

        assert(!b.isCompact());
        b.reverse;
        for (; i < data.length; i++)
        {
            assert(b[i] == data[5 - i]);
        }
    }


    /**********************************************
     * Sorts the $(D BitArray)'s elements.
     */
    deprecated BitArray sort() @trusted @property
    out (result)
    {
        assert(result == this);
    }
    body
    {
        if (length >= 2)
        {
            ulong lo, hi;
            lo = 0;
            hi = length - 1;
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

        ubyte[] x = [0, 0xcc, 0, 0, 0, 0, 0, 0];
        BitArray ba = BitArray(x, 8, 18);
        assert(ba.isCompact());
        ba.sort;
        for (size_t i = 0; i < 6; i++)
            assert(ba[i] == false);
        for (size_t i = 6; i < 10; i++)
            assert(ba[i] == true);

        //non-compact version
        ba = BitArray(x, 8, 18);
        ba.length = maxCompactBits * 2;
        ba = ba[0 .. 10];
        assert(!ba.isCompact());

        ba.sort;
        for (size_t i = 0; i < 6; i++)
            assert(ba[i] == false);
        for (size_t i = 6; i < 10; i++)
            assert(ba[i] == true);
    }

    /***************************************
     * Support for operators == and != for $(D BitArray).
     */
    bool opEquals(const BitArray rhs) @trusted pure const
    {
        if (length != rhs.length)
            return false;

        return opCmp(rhs) == 0;
    }

    /// Ditto
    bool opEquals(const bool[] b_rhs) @trusted const
    {
        if (length != b_rhs.length)
            return false;

        foreach(i, b; this)
        {
            if (b_rhs[cast(size_t) i] != b)
                return false;
        }

        return true;
    }

    unittest
    {
        debug(bitarray) printf("BitArray.opEquals unittest\n");

        static bool[] ba = [1,0,1,0,1];
        static bool[] bb = [1,0,1];
        static bool[] bc = [1,0,1,0,1,0,1];
        static bool[] bd = [0,1,0,1,1,1];
        static bool[] be = [0,1,0,1,0,1];

        BitArray a; a.init(ba);
        BitArray b; b.init(bb);
        BitArray c; c.init(bc);
        BitArray d; d.init(bd);
        BitArray e; e.init(be);

        //slice aware
        d = d[1 .. $];
        e = e[1 .. $];

        assert(a != b);
        assert(a != c);
        assert(a != d);
        assert(a == e);

        //slice & non-compact versions.
        c.init(bc);
        d.init(bd);
        e.init(be);

        c.length = maxCompactBits * 2;
        d.length = maxCompactBits * 2;
        e.length = maxCompactBits * 2;
        assert(!c.isCompact());
        assert(!d.isCompact());
        assert(!e.isCompact());

        a = c[0 .. 5];
        b = a[2 .. 5];
        c = c[0 .. bc.length];
        d = d[1 .. bd.length];
        e = e[1 .. be.length];
        assert(a != b);
        assert(a != c);
        assert(a != d);
        assert(a == e);

        //bool checks
        assert(ba == a);
        assert(c == bc);
        assert(a != be);

        assert(a == [1,0,1,0,1]);
        assert(a != [1,0,1,1,0]);

    }

    /***************************************
     * Supports comparison operators for $(D BitArray).
     */
    int opCmp(const BitArray rhs) @trusted pure const
    {
        if (length != rhs.length)
            return (length > rhs.length) - (length < rhs.length);

        ulong i, cub;
        auto len = length;

        //not aligned and remainder
        size_t l, r;
        for (;i < len; i++)
        {
            cub = canUseBulk!("if (l != r[0]) break")(0, len, i, rhs);
            if (cub)
                i += cub - 1;    //jump forward, compensate for ++
            else if (this[i] != rhs[i])
            {
                //only converted to numbers for the math result
                l = this[i] ? 1 : 0;
                r = rhs[i] ? 1 : 0;

                return (l > r) - (l < r);
            }
        }

        return 0;    //at this point they are equal
    }

    unittest
    {
        debug(bitarray) printf("BitArray.opCmp unittest\n");

        static bool[] ba = [1,0,1,0,1];
        //static bool[] bb = [1,0,1];
        static bool[] bc = [1,0,1,0,1,0,1];
        static bool[] bd = [1,0,1,1,1];
        static bool[] be = [1,0,1,0,1];

        BitArray a; a.init(ba);
        BitArray b; b = a[2 .. $];    //slice aware
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


        assert(a.isCompact());
        assert(!b.isCompact());    //reference so not compact
        assert(c.isCompact());
        assert(d.isCompact());
        assert(e.isCompact());

        //non-compact versions
        a.length = maxCompactBits * 2;
        c.length = maxCompactBits * 2;
        d.length = maxCompactBits * 2;
        e.length = maxCompactBits * 2;
        a = a[0 .. ba.length];
        b = a[2 .. a.length];
        c = c[0 .. bc.length];
        d = d[0 .. bd.length];
        e = e[0 .. be.length];

        assert(!a.isCompact());
        assert(!b.isCompact());
        assert(!c.isCompact());
        assert(!d.isCompact());
        assert(!e.isCompact());

        assert(a >  b);
        assert(a >= b);
        assert(a <  c);
        assert(a <= c);
        assert(a <  d);
        assert(a <= d);
        assert(a == e);
        assert(a <= e);
        assert(a >= e);
    }

    /***************************************
     * Set this $(D BitArray) to the contents of $(D ba).
     */
    void init(const bool[] b_rhs) @trusted
    {
        this = BitArray();
        length = b_rhs.length;

        foreach (i, b; b_rhs)
        {
            this[i] = b;
        }
    }

    /***************************************
     * Map the $(D BitArray) onto $(D v), with $(D numbits) being the number of bits
     * in the array. Does not copy the data. (Unless it can fit as compact).
     * if numbits is 0, it defaults to the full range offered by the array.
     */
    void init(void[] inputBuffer, ulong numbits) @trusted
    in
    {
        assert(numbits <= inputBuffer.totalBits);
        assert(inputBuffer.length % size_t.sizeof == 0);
    }
    body
    {
        if (!numbits)
            numbits = inputBuffer.totalBits;

        this = BitArray();

        if(inputBuffer.totalBits <= maxCompactBits)
        {
            compact[0 .. (inputBuffer.length / size_t.sizeof)] = cast(size_t[]) inputBuffer[0 .. inputBuffer.length]; //raw copy
            endBit = numbits;
            startBit = 0;
            return;
        }

        isCompact = false;
        canExpand = false;
        normal = cast(size_t[]) inputBuffer;
        startBit = 0;
        _endBit = 0; //reset to largest size

        endBit = numbits;
    }

    unittest
    {
        debug(bitarray) printf("BitArray.init unittest\n");

        static bool[] ba = [1,0,1,0,1];

        BitArray a; a.init(ba);
        BitArray b;
        void[] v;

        v = cast(void[]) a.compact;
        b.init(v, a.length);

        assert(b[0] == 1);
        assert(b[1] == 0);
        assert(b[2] == 1);
        assert(b[3] == 0);
        assert(b[4] == 1);

        a[0] = 0;
        assert(b[0] != a[0]);    //compact

        a.length = maxCompactBits * 2;
        b = a;

        a[0] = 0;
        assert(b[0] == 0);

        assert(a == b);

        //non-compact
        size_t[128] large;
        a = BitArray(); //reset
        a.init(cast(void[]) large, 0);
        assert(!a.isCompact);
        assert(a.length == large.totalBits);

        //check that it's connected.
        a[0] = true;
        assert(large[0]);   //not zero anymore.
    }

    /***************************************
     * since opCast is removed (due to problems otherwise for the moment) this returns a slice of the buffer
     */
    inout(T)[] getBuffer(T)(ref inout(T)[] outBuffer) @property pure inout
    if (isArray!(T) == false)
    {
        if (isCompact)
            outBuffer = cast(inout(T)[]) compact[0 .. $].dup;    //potentially unsafe without dup
        else
            outBuffer = cast(inout(T)[]) normal[0 .. $];

        return cast(inout(T)[]) outBuffer;
    }

    /***************************************
     * Allows alignemnt (or reallignment) on a particular startBit.
     * Most likely in cases where you've sliced or added bools before the beginning
     */
    ref BitArray realign(ulong byOffset = 0) @property pure
    {
        if (startBit != byOffset)
        {
            BitArray ba = this.dup;

            startBit = byOffset;
            length = ba.length;
            this[] = ba[];

            //hash shouldn't change.
            assert(toHash == ba.toHash);
        }

        return this;
    }

    unittest
    {
        //getbuffer
        BitArray ba;
        byte[] x;

        ba.getBuffer(x);
        assert(ba.isCompact);
        assert(x.length == ba.compact.length * size_t.sizeof);
        assert(cast(size_t[]) x !is ba.compact);

        ba.length = 256;
        assert(!ba.isCompact);
        assert(ba.length == 256);
        ba.getBuffer(x);
        assert(x.length == (ba.length / 8));
        assert(cast(size_t[]) x is ba.normal);

        size_t[] y;
        ba.getBuffer(y);
        assert(y.length == (ba.length / size_t.sizeof / 8));
        assert(y is ba.normal);
    }

    unittest
    {
        //realign
        bool[] array = [1,1,1,0,0,0,1,0,1,0];
        BitArray ba = BitArray(array);
        assert(array == ba);
        assert(ba.startBit == 0);

        ba.realign = 5;
        assert(array == ba);
        assert(ba.startBit == 5);

        ba.realign;
        assert(array == ba);
        assert(ba.startBit == 0);
    }

    /***************************************
     * Support for unary operator ~ for $(D BitArray).
     */
    BitArray opUnary(string op)() @trusted pure const
    if (op == "~")
    {
        auto dim = this.dim;

        BitArray result = this.dup;
        ulong cub, len = result.length;

        //can't slice/reference inner bits, so might as well flip them all!
        if (result.isCompact)
        {
            for(size_t i; i < compact.length; i++)
                result.compact[i] ^= -1;
            return result;
        }

        for (ulong i; i < len; i++)
        {
            cub = result.canUseBulk!("l = ~l")(0, len, i);
            //if aligned properly, we can do a size_t rather than individual bits
            if (cub)
                i += cub - 1;
            else
                result[i] = !result[i];
        }

        return result;
    }

    unittest {
        debug(bitarray) printf("BitArray.opCom unittest\n");

        bool[] ba = [1,0,1,0,1];
        bool[] ba_c = [0,1,0,1,0];

        BitArray a; a.init(ba);
        BitArray b = ~a;

        assert(b[0] == 0);
        assert(b[1] == 1);
        assert(b[2] == 0);
        assert(b[3] == 1);
        assert(b[4] == 0);
        assert(b == ba_c);

        //should do bulk compare with a larger set
        //results already known and just duplicated
        a = BitArray(ba);
        b = BitArray(ba_c);

        for(int i; i<6; i++)
        {
            a ~= a;
            b ~= b;
        }

        a = a[1 .. $-1]; //forces non bulk to work
        b = b[1 .. $-1];

        assert(b == ~a);
    }

    /***************************************
     * Support for binary operators & | and ^ for $(D BitArray).
     */
    BitArray opBinary(string op)(const BitArray rhs) @trusted pure const
    if (op == "&" || op == "|" || op == "^")
    in
    {
        assert(length == rhs.length);
    }
    body
    {
        BitArray result = this.dup;
        ulong len = result.length;
        ulong i, cub;

        for (; i < len; i++)
        {
            cub = result.canUseBulk!("l " ~ op ~ "= r[0]")(0, len, i, rhs);

            if (cub)
                i += cub - 1;
            else
                mixin("result[i] = result[i] " ~ op ~ " rhs[i];");
        }

        return result;
    }

    /***************************************
     * Support for binary operator - for $(D BitArray).
     *
     * $(D a - b) for $(D BitArray) means the same thing as $(D a &amp; ~b).
     */
    BitArray opBinary(string op)(const BitArray rhs) @trusted pure const
    if (op == "-")
    in
    {
        assert(length == rhs.length);
    }
    body
    {
        BitArray result = this.dup;
        ulong len = result.length;
        ulong i, cub;

        for (; i < len; i++)
        {
            cub = result.canUseBulk!("l &= ~r[0]")(0, len, i, rhs);

            if (cub)
                i += cub - 1;
            else
                result[i] = result[i] & !rhs[i];
        }

        return result;
    }

    unittest
    {
        debug(bitarray) printf("BitArray.opAnd unittest\n");

        static bool[] ba = [0,0, 1,0,1,0,1];
        static bool[] bb = [0,   1,0,1,1,0];

        BitArray a; a.init(ba);
        BitArray b; b.init(bb);

        //slice aware
        a = a[2 .. $];
        b = b[1 .. $];

        BitArray c = a & b;

        assert(c[0] == 1);
        assert(c[1] == 0);
        assert(c[2] == 1);
        assert(c[3] == 0);
        assert(c[4] == 0);


        //check bulk
        a = BitArray(ba[2 .. $]);
        b = BitArray(bb[1 .. $]);
        c = BitArray([1,0,1,0,0]);

        for(int i; i<6; i++)
        {
            a ~= a;
            b ~= b;
            c ~= c;
        }

        assert(c == (a&b));
    }

    unittest
    {
        debug(bitarray) printf("BitArray.opOr unittest\n");

        static bool[] ba = [0,0, 1,0,1,0,1];
        static bool[] bb = [0,   1,0,1,1,0];

        BitArray a; a.init(ba);
        BitArray b; b.init(bb);

        //slice aware
        a = a[2 .. $];
        b = b[1 .. $];

        BitArray c = a | b;

        assert(c[0] == 1);
        assert(c[1] == 0);
        assert(c[2] == 1);
        assert(c[3] == 1);
        assert(c[4] == 1);


        //check bulk
        a = BitArray(ba[2 .. $]);
        b = BitArray(bb[1 .. $]);
        c = BitArray([1,0,1,1,1]);

        for(int i; i < 8; i++)
        {
            a ~= a;
            b ~= b;
            c ~= c;
        }

        assert(c == (a|b));
    }

    unittest
    {
        debug(bitarray) printf("BitArray.opXor unittest\n");

        static bool[] ba = [0,0, 1,0,1,0,1];
        static bool[] bb = [0,   1,0,1,1,0];

        BitArray a; a.init(ba);
        BitArray b; b.init(bb);

        //slice aware
        a = a[2 .. $];
        b = b[1 .. $];

        BitArray c = a ^ b;

        assert(c[0] == 0);
        assert(c[1] == 0);
        assert(c[2] == 0);
        assert(c[3] == 1);
        assert(c[4] == 1);


        //check bulk
        a = BitArray(ba[2 .. $]);
        b = BitArray(bb[1 .. $]);
        c = BitArray([0,0,0,1,1]);

        for(int i; i < 8; i++)
        {
            a ~= a;
            b ~= b;
            c ~= c;
        }

        assert(c == (a^b));
    }

    unittest
    {
        debug(bitarray) printf("BitArray.opSub unittest\n");

        static bool[] ba = [0,0, 1,0,1,0,1];
        static bool[] bb = [0,   1,0,1,1,0];

        BitArray a; a.init(ba);
        BitArray b; b.init(bb);

        //slice aware
        a = a[2 .. $];
        b = b[1 .. $];

        BitArray c = a - b;

        assert(c[0] == 0);
        assert(c[1] == 0);
        assert(c[2] == 0);
        assert(c[3] == 0);
        assert(c[4] == 1);


        //check bulk
        a = BitArray(ba[2 .. $]);
        b = BitArray(bb[1 .. $]);
        c = BitArray([0,0,0,0,1]);

        for(int i; i<6; i++)
        {
            a ~= a;
            b ~= b;
            c ~= c;
        }

        assert(c == (a-b));
    }

    /***************************************
     * Support for operator &= |= -= and ^= for $(D BitArray).
     */
    BitArray opOpAssign(string op)(const BitArray rhs) @trusted pure
    if (op == "&" || op == "|" || op == "^")
    in
    {
        assert(length == rhs.length);
    }
    body
    {
        auto dim = this.dim;
        ulong i, cub;
        ulong len = length;

        for (; i < len; i++)
        {
            cub = canUseBulk!("l " ~ op ~ "= r[0]")(0, len, i, rhs);
            if (cub)
                i += cub - 1;
            else
                mixin("this[i] = this[i] " ~ op ~ " rhs[i];");
        }

        return this;
    }

     /***************************************
     * Support for binary operator - for $(D BitArray).
     *
     * $(D a -= b) for $(D BitArray) means the same thing as $(D a &amp;= ~b).
     */
    BitArray opOpAssign(string op)(const BitArray rhs) @trusted pure
    if (op == "-")
    in
    {
        assert(length == rhs.length);
    }
    body
    {
        auto dim = this.dim;
        ulong i, cub;
        ulong len = length;

        for (; i < len; i++)
        {
            cub = canUseBulk!("l &= ~r[0]")(0, len, i, rhs);
            if (cub)
                i += cub - 1;
            else
                this[i] = this[i] & !rhs[i];
        }

        return this;
    }

    unittest
    {
        debug(bitarray) printf("BitArray.opAndAssign unittest\n");

        //uneven first 0's representing outside of slice.
        static bool[] ba = [0,0, 1,0,1,0,1];
        static bool[] bb = [0,   1,0,1,1,0];

        BitArray a; a.init(ba);
        BitArray b; b.init(bb);

        //slice aware
        a = a[2 .. $];
        b = b[1 .. $];

        a &= b;
        assert(a[0] == 1);
        assert(a[1] == 0);
        assert(a[2] == 1);
        assert(a[3] == 0);
        assert(a[4] == 0);

        //check bulk
        a = BitArray(ba[2 .. $]);
        b = BitArray(bb[1 .. $]);
        BitArray c = BitArray([1,0,1,0,0]);

        for(int i; i < 6; i++)
        {
            a ~= a;
            b ~= b;
            c ~= c;
        }

        a &= b;
        assert(c == a);
    }

    unittest
    {
        debug(bitarray) printf("BitArray.opOrAssign unittest\n");

        static bool[] ba = [0,0, 1,0,1,0,1];
        static bool[] bb = [0,   1,0,1,1,0];

        BitArray a; a.init(ba);
        BitArray b; b.init(bb);

        //slice aware
        a = a[2 .. $];
        b = b[1 .. $];

        a |= b;
        assert(a[0] == 1);
        assert(a[1] == 0);
        assert(a[2] == 1);
        assert(a[3] == 1);
        assert(a[4] == 1);

        //check bulk
        a = BitArray(ba[2 .. $]);
        b = BitArray(bb[1 .. $]);
        BitArray c = BitArray([1,0,1,1,1]);

        for(int i; i < 6; i++)
        {
            a ~= a;
            b ~= b;
            c ~= c;
        }

        a |= b;
        assert(c == a);
    }

    unittest
    {
        debug(bitarray) printf("BitArray.opXorAssign unittest\n");

        static bool[] ba = [0,0, 1,0,1,0,1];
        static bool[] bb = [0,   1,0,1,1,0];

        BitArray a; a.init(ba);
        BitArray b; b.init(bb);

        //slice aware
        a = a[2 .. $];
        b = b[1 .. $];

        a ^= b;
        assert(a[0] == 0);
        assert(a[1] == 0);
        assert(a[2] == 0);
        assert(a[3] == 1);
        assert(a[4] == 1);

        //check bulk
        a = BitArray(ba[2 .. $]);
        b = BitArray(bb[1 .. $]);
        BitArray c = BitArray([0,0,0,1,1]);

        for(int i; i<6; i++)
        {
            a ~= a;
            b ~= b;
            c ~= c;
        }

        a ^= b;
        assert(c == a);
    }

    unittest
    {
        debug(bitarray) printf("BitArray.opSubAssign unittest\n");

        static bool[] ba = [0,0, 1,0,1,0,1];
        static bool[] bb = [0,   1,0,1,1,0];

        BitArray a; a.init(ba);
        BitArray b; b.init(bb);

        //slice aware
        a = a[2 .. $];
        b = b[1 .. $];

        a -= b;
        assert(a[0] == 0);
        assert(a[1] == 0);
        assert(a[2] == 0);
        assert(a[3] == 0);
        assert(a[4] == 1);

        //check bulk
        a = BitArray(ba[2 .. $]);
        b = BitArray(bb[1 .. $]);
        BitArray c = BitArray([0,0,0,0,1]);

        for(int i; i < 6; i++)
        {
            a ~= a;
            b ~= b;
            c ~= c;
        }

        a -= b;
        assert(c == a);
    }
    
    
    /***************************************
     * Support for operator ~= for $(D BitArray).
     */
    BitArray opOpAssign(string op)(bool b) @trusted pure
    if (op == "~")
    {
        length = length + 1;
        this[$-1] = b;
        return this;
    }

    unittest
    {
        debug(bitarray) printf("BitArray.opCatAssign unittest\n");

        static bool[] ba = [0,0, 1,0,1,0,1];

        BitArray a; a.init(ba);
        BitArray b;

        a = a[2 .. $];

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
    BitArray opOpAssign(string op)(const BitArray rhs) @trusted pure
    if (op == "~")
    {
        ulong i, cub;
        auto lOffset = length;
        auto len = rhs.length;
        length = length + len;

        for (; i < len; i++)
        {
            cub = canUseBulk!("l = r[0]")(lOffset, lOffset + len, i, rhs);
            if (cub)
                i += cub - 1;
            else
                this[lOffset + i] = rhs[i];
        }
        return this;
    }

    unittest
    {
        debug(bitarray) printf("BitArray.opCatAssign unittest\n");

        static bool[] ba = [1,0, 0,0];
        static bool[] bb = [0,1,0];

        BitArray a; a.init(ba);
        BitArray b; b.init(bb);
        BitArray c;

        a = a[0 .. 2];

        c = (a ~= b);
        assert(a.length == 5);
        assert(a[0] == 1);
        assert(a[1] == 0);
        assert(a[2] == 0);
        assert(a[3] == 1);
        assert(a[4] == 0);

        assert(c == a);

        a = BitArray(bb);
        b = a;
        for(int i; i < 20; i++)
            a ~= b;

        assert(a.length == (21*3));
        c = BitArray();
        b = a.dup;
        assert(a == b);

        a ~= b;
        assert(a[0 .. $/2] == a[$/2 .. $]);
        assert(b == a[$/2 .. $]);
        assert(a[$/2 .. $] == b);

        b = a;
        a ~= a;
        assert(a.length == b.length*2);
        assert(a[0 .. $/2] == b);
        assert(a[$/2 .. $] == b);
    }

    /***************************************
     * Support for binary operator ~ for $(D BitArray).
     */
    BitArray opBinary(string op)(bool b) const pure
    if (op == "~")
    {
        BitArray r = this.dup;

        r ~= b;
        return r;
    }

    /** ditto */
    BitArray opBinaryRight(string op)(bool b) pure const
    if (op == "~")
    {
        BitArray left;

        //check if we have leftmost bits leftover
        if (bitIndex(startBit) > 0)
        {
            left = this.dup;
            left.canExpand = true;
            left.startBit = left.startBit - 1;
            left[0] = b;    //0 not startBit, startBit is taken into consideration in opIndex
        }
        else
        {
            const BitArray orig = this;
            left.length = length + bitsPerSizeT;
            left.startBit = bitsPerSizeT;
            left.endBit = endBit + bitsPerSizeT;
            if (left.isCompact)
                left[0 .. $] = orig[0 .. $];
            else
                left.normal[1 .. $] = orig.normal[0 .. $ - 1];

            left.startBit = left.startBit - 1;
            left[0] = b;
        }

        return left;
    }

    /** ditto */
    BitArray opBinary(string op)(const BitArray rhs) const pure
    if (op == "~")
    {
        BitArray ba;

        ba = this.dup();
        ba ~= rhs;
        return ba;
    }

    unittest
    {
        debug(bitarray) printf("BitArray.opCat unittest\n");

        static bool[] ba = [1,0, 0,0];
        static bool[] bb = [0,1,0];

        BitArray a; a.init(ba);
        BitArray b; b.init(bb);
        BitArray c;

        a = a[0 .. 2];

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

        c = (true ~ c);    //check after resize/shift that we can do it again.
        assert(c.length == 4);
        assert(c[0] == 1);
        assert(c[1] == 0);
        assert(c[2] == 1);
        assert(c[3] == 0);
    }

    /***************************************
     * Support for slices $(D BitArray).
     */
    BitArray opSlice() @trusted pure
    {
        //to support reference on a compact, we convert it first.
        BitArray sl = this;
        if (isCompact)
        {
            size_t[] allocated;
            allocated.length = compact.length;
            allocated[] = compact[];
            
            sl.isCompact = false;
            sl.normal = allocated;
        }

        sl.canExpand = false;
        return sl;
    }
    
    /**
     * ditto. Being const we can't modify the original
     */
    const(BitArray) opSlice() @trusted pure const
    {
        return this;
    }

    /**
     * ditto
     */
    const(BitArray) opSlice(ulong sliceStart, ulong sliceEnd) @trusted pure const
    {
        assert(sliceStart + startBit <= endBit, "sliceStart = " ~ myToStringx(sliceStart));
        assert(sliceEnd + startBit <= endBit, "sliceEnd = " ~ myToStringx(sliceStart));
        ulong len = sliceEnd - sliceStart;

        if (sliceStart == 0 && sliceEnd == length)
            return this;

        BitArray sl = cast(BitArray) this[];

        sl.startBit = sl.startBit + sliceStart;
        sl.endBit = sl.startBit + len;

        return cast(const BitArray) sl;
    }
    
    immutable(BitArray) opSlice(ulong sliceStart, ulong sliceEnd) @trusted pure immutable
    {
        const BitArray tmp = cast(const BitArray) this;
        return cast(immutable BitArray) tmp[sliceStart .. sliceEnd];
    }
    
    BitArray opSlice(ulong sliceStart, ulong sliceEnd) @trusted pure
    {
        assert(sliceStart + startBit <= endBit, "sliceStart = " ~ myToStringx(sliceStart));
        assert(sliceEnd + startBit <= endBit, "sliceEnd = " ~ myToStringx(sliceStart));
        ulong len = sliceEnd - sliceStart;

        if (sliceStart == 0 && sliceEnd == length)
            return this;

        BitArray sl = this[];

        sl.startBit = sl.startBit + sliceStart;
        sl.endBit = sl.startBit + len;

        return sl;
    }

    unittest
    {
        BitArray ba; ba.init([1,1,1,0,0,0]);
        BitArray bb; bb.init([1,1,0,0,0]);
        BitArray bc; bc.init([1,1,0,0]);
        BitArray bd; bd.init([1,0]);

        BitArray bs = ba[1 .. $]; //11000
        assert(bs == bb);

        bs = bs[0 .. $-1];  //1100
        assert(bs == bc);

        bs = bs[1 .. $-1];  //10

        assert(bs == bd);
    }

    ref BitArray opSliceAssign(const bool[] setSlice, ulong sliceStart, ulong sliceEnd) @trusted pure
    {
        assert(sliceEnd - sliceStart == setSlice.length);

        ulong i = sliceStart;

        for(; i < sliceEnd; i++)
            this[i + startBit + sliceStart] = setSlice[cast(size_t) i];

        return this;
    }

    ref BitArray opSliceAssign(const BitArray setSlice, ulong sliceStart, ulong sliceEnd) @trusted pure
    {
        assert(sliceEnd - sliceStart == setSlice.length);

        ulong i, cub;
        ulong len = sliceEnd - sliceStart;

        for(; i < len; i++)
        {
            cub = canUseBulk!("l = r[0]")(sliceStart, sliceEnd, i, setSlice);
            if (cub)
                i += cub - 1;
            else
                this[i + sliceStart] = setSlice[i];
        }

        return this;
    }

    ref BitArray opSliceAssign(bool setValue, ulong sliceStart, ulong sliceEnd) @trusted pure
    {
        ulong cub, i = sliceStart;

        for(; i < sliceEnd; i++)
        {
            if (setValue)
                //rather than -1, should use type.max? or type.min for signed?
                cub = canUseBulk!(" l = -1")(0, sliceEnd, i);
            else
                cub = canUseBulk!(" l = 0")(0, sliceEnd, i);

            if (cub)
                i += cub - 1;
            else
                this[i] = setValue;
        }
        return this;
    }

    //issue 1998 - opSliceAssign - Let's you set all bits to on or off
    BitArray opSliceAssign(bool setValue) @trusted pure
    {
        return opSliceAssign(setValue, 0, length);
    }

    //a[] = b[]; if the length is the same.
    BitArray opSliceAssign(const BitArray setSlice) @trusted pure
    {
        assert(length == setSlice.length);
        this.opSliceAssign(setSlice, 0, length);

        return this;
    }

    unittest
    {
        BitArray ba = BitArray(24);
        BitArray bb = ba[4 .. $-4];    //2 bytes in the middle, overlapping

        assert(ba.isCompact);    //value semantics
//        assert(bb.isCompact);    //referenced so this fails...

        ba[] = true;
        assert(ba.getBulk(0) == 0x00ffffff);
        assert(ba.compact[0] == 0x00ffffff);

        bb = ba[4 .. $-4];    //compact leaves them separate
        bb[] = false;

        assert(ba.getBulk(0) == 0x00ffffff);
        assert(bb.getBulk(0) == 0x00f0000f);

        bb[4 .. 8] = true;

        assert(bb.getBulk(0) == 0x00f00f0f);

        ba[] = 0;

        ba[0 .. 4] = [0,1,1,0]; //least to most significant
        assert(ba.getBulk(0) == 0x06);

        ba[8 .. 12] = ba[0 .. 4];
        assert(ba.getBulk(0) == 0x0606);


        //test slices
        ba = BitArray(maxCompactBits * 2);    //force normal
        ba = ba[0 .. 24];
        bb = ba[4 .. $-4];    //2 bytes in the middle, overlapping

        assert(!ba.isCompact);
        assert(!bb.isCompact);

        ba[] = true;
        assert(ba.getBulk(0) == 0x00ffffff);

        bb[] = false;
        assert(ba.getBulk(0) == 0x00f0000f);

        bb[4 .. 8] = true;
        assert(bb.getBulk(0) == 0x00f00f0f);

        ba[] = 0;

        ba[0 .. 4] = [0,1,1,0]; //least to most significant
        assert(ba.getBulk(0) == 0x06);

        ba[8 .. 12] = ba[0 .. 4];
        assert(ba.getBulk(0) == 0x0606);


        //bulk slice copy test
        static bool[] a = [1,0,1,0,1];
        static bool[] b = [1,0,1,1,0];

        ba = BitArray(a);
        bb = BitArray(b);

        for(int i; i < 5; i++) 
        {
            ba ~= ba;
            bb ~= bb;
        }

        assert(ba != bb);
        BitArray b_ba = ba;

        ba[] = bb[];
        assert(ba == bb);
        assert(ba.normal !is bb.normal);
        assert(b_ba.normal is ba.normal);

    }

    /**
     * simple toString, like "1010111"
     */
    string toString() const
    {
        char[] str;

        str.length = cast(size_t) length;

        //opApply not pure...
        foreach(i, b; this)
        {
            str[cast(size_t) i] = b ? '1' : '0';
        }

        return cast(string) (str);
    }

    unittest
    {
        BitArray ba;
        bool[] b = [1,0,1,0,1,1,1];
        ba.init(b);
        string str = ba.toString();

        assert(str == "1010111");
    }

    /**
     * Reading/writing of basic types. 
     * allowRemainingBits is useful if there is a remainder of bits that you still need to read
     * like the toHash uses. Otherwise, you will get an error if there isn't enough room in the array.
     * Types allow any basic type, along with value types (no indirection/pointers)
     */
    size_t rawRead(T)(out T val, ulong position, bool allowRemainingBits = false) @trusted pure const
    if (!hasIndirections!(T))
    in
    {
        enum bits = T.sizeof * 8;
        assert(allowRemainingBits ||
                endBit - (position + startBit) >= bits,
                "Not enough left in BitArray for read");
        assert(position + startBit < endBit,
                "Outside of range!");    //ensure it's not past the end of the array.
    }
    body
    {
        union XX {
            ubyte[T.sizeof] rawData;
            T rawType;
        }

        XX Union;    //non-aggregate annonymous enum... Annoying workaround.

        size_t bits = T.sizeof * 8;
        if(allowRemainingBits)
            //another min template would be nice..
            bits = cast(size_t) min(endBit - (position + startBit), bits);

        with(Union)
        {
            for(ulong i; i < bits; ++i) {
                setBit(rawData, i, this[position + i]);
            }

            val = rawType;
        }
        return bits;
    }

    //writes at the specific location. No reallocation, if outside of bounds it will utterly fail
    size_t rawWrite(T)(const T val, ulong position) @trusted pure
    if (!hasIndirections!(T))
    in
    {
        enum bits = T.sizeof * 8;
        assert(endBit - (position + startBit) >= bits,
                "Not enough left in BitArray for write");
        assert(position + startBit < endBit,
                "Outside of range!");    //ensure it's not past the end of the array.
    }
    body
    {
        union XX {
            ubyte[T.sizeof] tmp;
            T rawType;
        }

        XX Union;    //non-aggregate annonymous enum... Annoying workaround.

        enum bits = T.sizeof * 8;
        with(Union)
        {
            rawType = val;

            for(ulong i; i < bits; ++i) {
                this[position + i] = getBit(tmp, i);
            }
        }

        return bits;
    }

    ///Appends to the end of the BitArray
    size_t rawWrite(T)(const T val) @trusted pure
    if (!hasIndirections!(T))
    {
        ulong position = length;
        length = position + (T.sizeof * 8);

        return rawWrite(val, position);
    }

    unittest
    {
        BitArray ba = BitArray(256);
        ba = ba[5 .. $];    //force slicing
        size_t off = 0;    //ensure startBit is working too.

        //pi just as a working point, nothing special :P
        //3.1 41 5926 53589 793238462 6433832795
        const byte i_b = -31;
        const ubyte i_ub = 41;
        const short i_sh = -5926;
        const ushort i_ush = 53589;
        const int i_i = -793_238_462;
        const uint i_ui = 643_383_279;
        const long i_l = -314_159_265_358_979;
        const ulong i_ul = 323_834_626_433_832_795;

        //bug in compare preventing proper use with const
        //so these are non-const, which work properly.
        float i_f = 3.14159265;
        double i_d = 3.1415926535897932384626433832795;
        
        struct PointXY {
            int x;
            int y;
            int color;
        }
        
        const PointXY i_pxy = PointXY(314, 159, 265);

        off += ba.rawWrite(i_b, off);
        off += ba.rawWrite(i_ub, off);
        off += ba.rawWrite(i_sh, off);
        off += ba.rawWrite(i_ush, off);
        off += ba.rawWrite(i_i, off);
        off += ba.rawWrite(i_ui, off);
        off += ba.rawWrite(i_l, off);
        off += ba.rawWrite(i_ul, off); //takes 251 bits at this point

        ba.length = off;    //test rawWrite appending

        ba.rawWrite(i_pxy);
        ba.rawWrite(i_f);
        ba.rawWrite(i_d);
        ba ~= true;        //works up from least significant bit, so 1 instead of 128.

        ubyte uneven;
        byte m_b;       ubyte m_ub;
        short m_sh;     ushort m_ush;
        int m_i;        uint m_ui;
        long m_l;       ulong m_ul;
        float m_f;      double m_d;
        PointXY m_pxy;

        off = 0;
        off += ba.rawRead(m_b, off);
        off += ba.rawRead(m_ub, off);
        off += ba.rawRead(m_sh, off);
        off += ba.rawRead(m_ush, off);
        off += ba.rawRead(m_i, off);
        off += ba.rawRead(m_ui, off);
        off += ba.rawRead(m_l, off);
        off += ba.rawRead(m_ul, off);
        off += ba.rawRead(m_pxy, off);          //custom struct
        off += ba.rawRead(m_f, off);
        off += ba.rawRead(m_d, off);
        off += ba.rawRead(uneven, off, true);   //remaining

        assert(i_b == m_b);
        assert(i_ub == m_ub);
        assert(i_sh == m_sh);
        assert(i_ush == m_ush);
        assert(i_i == m_i);
        assert(i_ui == m_ui);
        assert(i_l == m_l);
        assert(i_ul == m_ul);

        //const float causes it to fail...
        //true floats are inexact matching but a raw compare would confirm...
        assert(i_f == m_f);
        assert(i_d == m_d);

        assert(uneven == 1);
        
        //custom type
        assert(i_pxy == m_pxy);
    }

    ///toHash for BitArray
    //Jenkins_one_at_a_time_hash from wikipedia
    uint toHash() @property pure const
    {
        ulong len = length;
        uint hash;
        ulong i;

        while(i < len)
        {
            ubyte k;
            i += this.rawRead(k, i, true);
            hash += k;
            hash += (hash << 10);
            hash ^= (hash >> 6);
        }

        hash += (hash << 3);
        hash ^= (hash >> 11);
        hash += (hash << 15);

        return hash;
    }

    unittest
    {
        char[7] up = "Balloon";
        char[7] dn = "balloon";
        BitArray upper = BitArray(up);
        BitArray lower = BitArray(dn);

        //ported from C version, they all pass the same. Good :)
        assert(upper.toHash == 0x819f9dcc);
        assert(lower.toHash == 0x85873cce);
        assert(upper[0 .. $-8].toHash == 0x57d3e2fd);    //Balloo

        assert(upper[$-8 .. $].toHash == 0xd98832f1);    //01110110
        assert(upper[$-7 .. $].toHash == 0xecc9d984);    //1110110
        assert(upper[$-6 .. $].toHash == 0xedbfdb78);    //110110

        debug {
            //visually shows how each bit is part of the hash, even if it isn't divisible by 8.
            uint hash = 0;  //adding 0 bits don't change the hash half the time
            for(size_t i = 1; i < upper.length; i++)
            {
                BitArray tmp = upper[0 .. i];
                if (tmp.toHash != hash)
                {
                    hash = tmp.toHash;
                    writefln("0x%08x - %s", hash, tmp);
                }
            }

            for(size_t i; i < upper.length; ++i)
            {
                BitArray tmp = upper[i .. $];
                writefln("0x%08x - %s", tmp.toHash, tmp);
            }
        }
    }

    //informational output for debugging.
    void print(string header = null) const
    {
        writefln("%s\n", header);
        writeln("isCompact:", isCompact);
        writeln("canExpand:", canExpand);
        writefln("startBit: %s (%s)", startBit, _startBit);
        writefln("endBit: %s (%s)", endBit, _endBit);
        writefln("length: %s", length);
        if (isCompact)
        {
            writefln("Compact Length: %s / %s(bits)", compact_ubyte.length, compact_ubyte.totalBits);
            writeln(compact);
            writeln(compact_ubyte);
            writeln(toString());
        }
        else
        {
            writefln("Normal  Length: %s / %s(bits)", normal.length * size_t.sizeof, normal.totalBits);
            writeln(normal, "\t", normal.length);
            writeln(cast(const(ubyte)[]) normal, "\t", (cast(const(ubyte)[]) normal).length);
            writeln(toString());
        }

        writefln("toHash: 0x%08x", toHash);
    }

    //test const-friendliness
    unittest
    {
        bool[] boolArray = [0, 0, 1, 1];
        bool[] boolArray2= [1, 0, 1, 0];
        const BitArray cba = BitArray(boolArray);
        BitArray ba;
        BitArray bb;

        bb = BitArray(boolArray2);

        ba = cba.dup;
        assert(ba == cba);

        foreach(i, b; cba)
            assert(boolArray[cast(size_t) i] == b);

        bool[] answer = [1, 1, 0, 0];
        BitArray a = BitArray(answer);

        //Unary ~
        ba = ~cba;

        assert(a == ba);

        //And
        answer = [0, 0, 1, 0];
        a = BitArray(answer);

        ba = cba & bb;
        assert(a == ba);

        ba = BitArray(boolArray2);
        ba &= cba;
        assert(a == ba, ba.toString());

        //Or
        answer = [1, 0, 1, 1];
        a = BitArray(answer);

        ba = cba | bb;
        assert(a == ba);

        ba = BitArray(boolArray2);
        ba |= cba;
        assert(a == ba);

        //xor
        answer = [1, 0, 0, 1];
        a = BitArray(answer);

        ba = cba ^ bb;
        assert(a == ba);

        ba = BitArray(boolArray2);
        ba ^= cba;
        assert(a == ba);

        //concat
        ba = cba ~ false;
        assert(ba == [0,0,1,1,0]);

        ba = true ~ cba;
        assert(ba == [1,0,0,1,1]);

        ba ~= cba;
        assert(ba == [1,0,0,1,1,  0,0,1,1]);

        //slice compares and copy
        ba[] = false;

        ba = ba[0 .. 4];        //size is wrong from following tests; fixing now...

        ba[] = cba[];
        assert(ba == cba);
        ba[2 .. 4] = cba[0 .. 2];
        ba[0 .. 2] = cba[2 .. 4];

        assert(ba[0 .. 2] == cba[2 .. 4]);
        assert(ba[2 .. 4] == cba[0 .. 2]);

        //const slices compares
        const BitArray cba0 = cba[0 .. 2]; //const slice to const slice
        const BitArray cba2 = cba[2 .. 4];
        const BitArray ba0 = ba[0 .. 2];    //normal to const slice
        const BitArray ba2 = ba[2 .. 4];

        assert(cba0.toHash == 0);
        assert(cba2.toHash);
        assert(ba0.toHash);    //backwards of cba
        assert(ba2.toHash == 0);

        assert(ba[0 .. 2] == cba2);    //still holds true to above
        assert(ba[2 .. 4] == cba0);
        assert(ba0 == cba2);        //should be true as well, only const
        assert(ba2 == cba0);

        //immutability. idup, and compares and access and slices, beyond that not much...
        //sorry for being so verbose and repetative..
        immutable BitArray icba = cba.idup;
        immutable BitArray icba0 = icba[0 .. 2];     //immutable to immutable slices
        immutable BitArray icba2 = icba[2 .. 4];
        immutable BitArray iba0 = ba[0 .. 2].idup;    //obviously idup
        immutable BitArray iba2 = ba[2 .. 4].idup;

        assert(icba0.toHash == 0);    //0,0 is always 0
        assert(icba2.toHash);
        assert(iba0.toHash);
        assert(iba2.toHash == 0);    //backwards of cba

        assert(ba[0 .. 2] == icba2);    //similar tests from above.
        assert(icba0 == ba[2 .. 4]);
        assert(iba0 == icba2);
        assert(iba2 == icba0);

        immutable BitArray iba1 = icba[1 .. 4];

        assert(iba1.length == 3);
        assert(iba1 == icba[1 .. 4]);
        assert(iba1 == cba[1 .. 4]);
        assert(iba1 == boolArray[1 .. 4]);
        assert(boolArray == icba);
        assert([0, 0, 1, 1] == icba); //just to be blatant...

        //regular ops (Obviously not opassign..
        answer = [1, 1, 0, 0];
        a = BitArray(answer);

        //Unary ~
        ba = ~icba;
        assert(a == ba);

        //And
        answer = [0, 0, 1, 0];
        a = BitArray(answer);

        ba = icba & bb;
        assert(a == ba);

        ba = bb & icba;    //forward and reverse...
        assert(a == ba);

        //Or
        answer = [1, 0, 1, 1];
        a = BitArray(answer);

        ba = icba | bb;
        assert(a == ba);

        ba = bb | icba;
        assert(a == ba);

        //xor
        answer = [1, 0, 0, 1];
        a = BitArray(answer);

        ba = icba ^ bb;
        assert(a == ba);

        ba = bb ^ icba;
        assert(a == ba);

        //concat
        ba = icba ~ false;
        assert(ba == [0,0,1,1,0]);

        ba = true ~ icba;
        assert(ba == [1,0,0,1,1]);

        ba ~= icba;
        assert(ba == [1,0,0,1,1,  0,0,1,1]);

        //foreach/opapply
        int i_i;
        foreach(b; icba)
        {
            assert(boolArray[i_i] == b);
            i_i++;
        }

        foreach(i, b; icba)
        {
            assert(boolArray[cast(size_t) i] == b);
        }
    }
}

/** converts string of 0's and 1's to the new bitarray.
  * If it isn't 0's or 1's then it throws an exception.
  * spaces, newlines and _'s are ignored for the purpose of formatting.
  * Constructors confuse between array types
  */
BitArray toBitArray(string source) @property
{
    BitArray ba = BitArray(source.length);

    ulong offset;
    foreach(ch; source) {
        if (isWhite(ch) || ch == '_')
            continue;

        assert(ch == '0' || ch == '1');
        ba[offset++] = (ch == '1');
    }

    ba.length = offset;   //final resize
    return ba;
}

unittest {
    BitArray ba = "1_1_1
             \t\r  0 0 0
             \v\n  1_1_1".toBitArray;
    assert(ba.length == 9);
    assert(ba == [1,1,1,0,0,0,1,1,1]);
}

/++
    Swaps the endianness of the given integral value or character.
  +/
T swapEndian(T)(T val) @safe pure nothrow
    if(isIntegral!T || isSomeChar!T || is(Unqual!T == bool))
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
    import std.stdio;
    import std.typetuple;

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

        // @@@BUG6354@@@
        /+
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
        +/
    }
}


private union EndianSwapper(T)
    if(isIntegral!T ||
       isSomeChar!T ||
       is(Unqual!T == bool) ||
       is(Unqual!T == float) ||
       is(Unqual!T == double))
{
    Unqual!T value;
    ubyte[T.sizeof] array;

    static if(is(Unqual!T == float))
        uint  intValue;
    else static if(is(Unqual!T == double))
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
    if(isIntegral!T ||
       isSomeChar!T ||
       is(Unqual!T == bool) ||
       is(Unqual!T == float) ||
       is(Unqual!T == double))
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
    if(isIntegral!T || isSomeChar!T || is(Unqual!T == bool))
{
    EndianSwapper!T es = void;

    version(LittleEndian)
        es.value = swapEndian(val);
    else
        es.value = val;

    return es.array;
}

private auto nativeToBigEndianImpl(T)(T val) @safe pure nothrow
    if(is(Unqual!T == float) || is(Unqual!T == double))
{
    version(LittleEndian)
        return floatEndianImpl!(T, true)(val);
    else
        return floatEndianImpl!(T, false)(val);
}

unittest
{
    import std.range;
    import std.stdio;
    import std.typetuple;

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
    if((isIntegral!T ||
        isSomeChar!T ||
        is(Unqual!T == bool) ||
        is(Unqual!T == float) ||
        is(Unqual!T == double)) &&
       n == T.sizeof)
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
    if((isIntegral!T || isSomeChar!T || is(Unqual!T == bool)) &&
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
    if((is(Unqual!T == float) || is(Unqual!T == double)) &&
       n == T.sizeof)
{
    version(LittleEndian)
        return floatEndianImpl!(n, true)(val);
    else
        return floatEndianImpl!(n, false)(val);
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
    if(isIntegral!T ||
       isSomeChar!T ||
       is(Unqual!T == bool) ||
       is(Unqual!T == float) ||
       is(Unqual!T == double))
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
    if(isIntegral!T || isSomeChar!T || is(Unqual!T == bool))
{
    EndianSwapper!T es = void;

    version(BigEndian)
        es.value = swapEndian(val);
    else
        es.value = val;

    return es.array;
}

private auto nativeToLittleEndianImpl(T)(T val) @safe pure nothrow
    if(is(Unqual!T == float) || is(Unqual!T == double))
{
    version(BigEndian)
        return floatEndianImpl!(T, true)(val);
    else
        return floatEndianImpl!(T, false)(val);
}

unittest
{
    import std.stdio;
    import std.typetuple;

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
    if((isIntegral!T ||
        isSomeChar!T ||
        is(Unqual!T == bool) ||
        is(Unqual!T == float) ||
        is(Unqual!T == double)) &&
       n == T.sizeof)
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
    if((isIntegral!T || isSomeChar!T || is(Unqual!T == bool)) &&
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
    if(((is(Unqual!T == float) || is(Unqual!T == double)) &&
       n == T.sizeof))
{
    version(BigEndian)
        return floatEndianImpl!(n, true)(val);
    else
        return floatEndianImpl!(n, false)(val);
}

private auto floatEndianImpl(T, bool swap)(T val) @safe pure nothrow
    if(is(Unqual!T == float) || is(Unqual!T == double))
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








