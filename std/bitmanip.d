// Written in the D programming language.

/**
Bit-level manipulation facilities.

Macros:

WIKI = StdBitarray

Copyright: Copyright Digital Mars 2007 - 2011.
License:   <a href="http://www.boost.org/LICENSE_1_0.txt">Boost License 1.0</a>.
Authors:   $(WEB digitalmars.com, Walter Bright),
           $(WEB erdani.org, Andrei Alexandrescu),
           Era Scarecrow
Source: $(PHOBOSSRC std/_bitmanip.d)
*/
/*
         Copyright Digital Mars 2007 - 2011.
Distributed under the Boost Software License, Version 1.0.
   (See accompanying file LICENSE_1_0.txt or copy at
         http://www.boost.org/LICENSE_1_0.txt)
*/
module std.bitmanip;

//debug = bitarray;                // uncomment to turn on debugging printf's

import core.bitop;
import std.traits;
import std.algorithm;
import std.string;
import std.ascii;
import std.stdio : writeln, writefln, writef;
import core.stdc.stdio;

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
private string myToString(long n) pure
{
    if (n >= short.min && n <= short.max)
        return myToStringx(n);

    return myToStringHex(n) ~ "UL";
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
    string store, string attributes, T, string nameAndValue, size_t len, size_t offset)
{
    enum name = getName(nameAndValue),
                defaultValue = getValue(nameAndValue),
                unqT = Unqual!(T).stringof; //removes any const qualifier, cleaner output code
    
    static if (!name.length)
    {
        // No need to create any accessor
        enum result = "";
    }
    else static if (len == 0)
    {
        // Fields of length 0 are always zero
        enum result = "enum "~unqT~" "~name~" = 0;";
    }
    else
    {
        static if (len + offset <= uint.sizeof * 8)
            alias uint MasksType;
        else
            alias ulong MasksType;
        enum MasksType
            maskAllElse = ((1uL << len) - 1) << offset,
            signBitCheck = 1uL << (len - 1),
            extendSign = cast(MasksType) ~((1uL << len) - 1);
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
                (defVal ? "enum " ~ name ~ "__def = " ~ myToString(defVal) ~ ";" : "")
            // getter
                ~"bool " ~ name ~ "() " ~ attributes ~ " const { return "
                ~"("~store~" & "~myToString(maskAllElse)~") != 0;}"
            // setter, but only if it's assignable
                ~(isAssignable!(T, T) ?
                    "void " ~ name ~ "(bool v) " ~ attributes ~ " {"
                    ~"if (v) "~store~" |= "~myToString(maskAllElse)~";"
                    ~"else "~store~" &= ~"~myToString(maskAllElse)~";}" : "");
        }
        else
        {
            // constants
            enum result = "enum "~unqT~" "~name~"__min = cast("~unqT~")"
                ~(minVal < 0 ? myToString(cast(long) minVal) : myToString(minVal))~"; "
                ~" enum "~unqT~" "~name~"__max = cast("~unqT~")"
                ~myToString(maxVal)~"; "
            //optional (for cleaner namespace)
                ~ (defVal ? "enum " ~ name ~ "__def = " ~ myToString(defVal) ~ ";" : "")
            // getter
                ~ ""~unqT~" "~name~"() " ~ attributes ~ " const { auto result = "
                ~ "("~store~" & "
                ~ myToString(maskAllElse) ~ ") >>"
                ~ myToString(offset) ~ ";"
                ~ (T.min < 0
                   ? "if (result >= " ~ myToString(signBitCheck)
                   ~ ") result |= " ~ myToString(extendSign) ~ ";"
                   : "")
                ~ " return cast("~unqT~") result;}"
            // setter, but only if it's assignable
                ~(isAssignable!(T, T) ?
                    "void "~name~"("~unqT~" v) " ~ attributes ~ " { "
                    ~"assert(v >= "~name~"__min, \"bitfield '" ~ name ~ "' assignment < min\"); "
                    ~"assert(v <= "~name~"__max, \"bitfield '" ~ name ~ "' assignment > max\"); "
                    ~store~" = cast(typeof("~store~"))"
                    " (("~store~" & ~"~myToString(maskAllElse)~")"
                    " | ((cast(typeof("~store~")) v << "~myToString(offset)~")"
                    " & "~myToString(maskAllElse)~"));}"
                    : "" );
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

private template createFields(alias store, size_t offset, string attributes, string defaults, Ts...)
{
    static if (!Ts.length)
    {
        static if (store[0] == '_') {
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
            enum result = "static assert((" ~ store ~ ".sizeof * 8) >= " ~ myToStringx(offset) ~ ",\"Supplied variable '" ~ store ~ "' too small (" ~ myToStringx(store.sizeof * 8) ~ ")\");";
        }
    }
    else
    {
        enum result = createAccessors!(store, attributes , Ts[0], Ts[1], Ts[2], offset).result
            ~ createFields!(store, offset + Ts[2], attributes, defaults ~
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
obj.x = 2;
obj.z = obj.x;
assert(obj.z == 1);
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

If there is only one field offered that fills the full 8/16/32/64 bit area
then it defaults to it's own type. Example:

----
struct B
{
    mixin(bitfields!(int, "something", 32);
    //is equal to:
    int something;
}
----

 If a bitfield is marked 'const' or 'immutable' as part of it's
type signature, the setter will be absent, to help honor that definition.

----
struct C
{
    mixin(bitfields!(
        bool      , "flag1",    1,
        const bool, "flag2",    1,
        uint      , "",         6));
}

C c;
c.flag1 = true;
c.flag2 = false; //compile-time error, (not a property of flag2)
----

*/

template bitfields(T...)
{
    //if there's one entry and it maxes out, don't bother with bitfields
    //shift operator will complain anyways.
    static if (T.length == 3 && T[0].sizeof * 8 == T[2])
        enum { bitfields = T[0].stringof ~ " " ~ T[1] ~ ";" }
    else
        enum { bitfields = createFields!(createStoreName!(T), 0, "@property @safe pure nothrow", "", T).result }
}


/**
Same as bitfields template, with the exception that you can set the
variable you want to be the target. The selected variable must be
a non-float, unsigned number. No other types will work (at present).
----
struct X {
    struct Y { uint something; }
    Y y;
    uint local;
    mixin(bitfieldsOn!("y.something", //target variable
        int, "a", 10,
        int, "b", 5,
        const bool, "c", 1));
}

X x;
assert(x.y.something == 0);
x.a = 100;
x.b = 10;

assert(x.y.something);   //check it was changed
assert(x.a == 100);      //check against our values.
assert(x.b == 10);

x.c = false; //compile time error, const honored, setter absent.

----
*/
template bitfieldsOn(alias storeName, T...)
if (isSomeString!(typeof(storeName)))
{
    enum bitfieldsOn = "mixin(bitfieldsOn_b!(\"" ~ storeName ~ "\"," ~ storeName ~ TupleToString!(T) ~ "));";
}

template TupleToString(T...) {
    static if (T.length)
        enum TupleToString = "," ~ T[0].stringof ~ TupleToString!(T[1 .. $]);
    else
        enum TupleToString = "";
}

template bitfieldsOn_b(string storeName, alias storeNameType, T...)
if((isIntegral!(typeof(storeNameType)) && isUnsigned!(typeof(storeNameType)) &&
        isFloatingPoint!(typeof(storeNameType)) == false))
{
    enum bitfieldsOn_b = createFields!(storeName, 0, "@property", "", T).result;
}

unittest
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

    /*
      from format.d; Ensures there's no 'overlapping initialization'.
      Compiling is enough to ensure it works. If any of these has a
      default; say 'flDash=true', then the problem would appear.
    */
    union xxx {
        ubyte allFlags;
        mixin(bitfields!(
                bool, "flDash", 1,
                bool, "flZero", 1,
                bool, "flSpace", 1,
                bool, "flPlus", 1,
                bool, "flHash", 1,
                ubyte, "", 3));
    }
}

//bug 8474, 32bits size at beginning of mixin gives trouble.
//also 64bit total (long/ulong)
unittest {
    struct X {
        //single 16bit
        mixin(bitfields!(
            short, "ss",  16,
        ));
        
        //single 32bit
        mixin(bitfields!(
            uint, "ui",  32,
        ));
        
        //two 32bits
        mixin(bitfields!(
            int, "si1",  32,
            int, "si2",  32,
        ));
        
        //full 64bit
        mixin(bitfields!(
            ulong, "ul",  64,
        ));
        
        //check assignment
        //single 32bit
        mixin(bitfields!(
            uint, "ui_def=42",  32,
        ));
    }
    
    X x;
    
    assert(x.ui_def == 42);
}

//issue 5942 - Bitfields are overwritten erroneously
unittest {
    struct S {
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

//issue 5520 - bitfieldsOn, supplying location for int/value to be affected.
unittest {
    struct X {
        struct Y { uint something; }
        Y y;
        mixin(bitfieldsOn!("y.something", //stringof may not get inner references, raw unchecked then.
            int, "a", 10,
            int, "b", 10,
            int, "c", 10,
            uint, "d", 2
        ));
    }

    X x;
    assert(x.y.something == 0);
    x.a = 10;
    x.b = 100;
    x.c = 500;
    x.d = 2;
    
    assert(x.y.something);  //check it was changed
    assert(x.a == 10);      //check against our values.
    assert(x.b == 100);
    assert(x.c == 500);
    assert(x.d == 2);
}

//constness for individual fields: setters will be absent.
unittest {
    struct X {
        uint ui;
        mixin(bitfields!(   //normal
            bool, "b1", 1,
            bool, "b2", 1,
            void, "", 6));
        mixin(bitfields!(
            const bool, "cb1", 1,
            immutable bool, "cb2", 1,
            void, "", 6));
        mixin(bitfields!(
            int, "i1", 4,
            int, "i2", 4));
        mixin(bitfields!(
            const int, "ci1", 4,
            immutable int, "ci2", 4));
            
        mixin(bitfieldsOn!("ui",    //specified variable
            bool, "sp_b1", 1,
            bool, "sp_b2", 1,
            void, "", 6));
        mixin(bitfieldsOn!("ui",
            const bool, "sp_cb1", 1,
            immutable bool, "sp_cb2", 1,
            void, "", 6));
        mixin(bitfieldsOn!("ui",
            int, "sp_i1", 4,
            int, "sp_i2", 4));
        mixin(bitfieldsOn!("ui",
            const int, "sp_ci1", 4,
            immutable int, "sp_ci2", 4));
        }
        
    
    X x;
    //should compile normally
    x.b1 = true;    //normal
    x.b2 = false;
    x.i1 = true;
    x.i2 = false;
    x.sp_b1 = true; //specific variable
    x.sp_b2 = false;
    x.sp_i1 = true;
    x.sp_i2 = false;

    //these should fail setter missing on purpose (as it's const)
    static assert(is(typeof(x.cb1 = true) == bool) == false);   //normal
    static assert(is(typeof(x.cb2 = false) == bool) == false);
    static assert(is(typeof(x.ci1 = true) == bool) == false);
    static assert(is(typeof(x.ci2 = false) == bool) == false);
    static assert(is(typeof(x.sp_cb1 = true) == bool) == false);    //specific variable
    static assert(is(typeof(x.sp_cb2 = false) == bool) == false);
    static assert(is(typeof(x.sp_ci1 = true) == bool) == false);
    static assert(is(typeof(x.sp_ci2 = false) == bool) == false);

    //bitfieldsOn, all these structs should fail based on type.
    struct Y {
        union {
            ulong ul;
            uint ui;
            ushort us;
            ubyte ub;
            float fl;
            double dbl;
            long sl;
        }
        
        X x;
        //needs to be a numeric, non-float, non-signed
        mixin(bitfieldsOn!("ul",
            int, "ul1", 4,
            int, "ul2", 4));
        mixin(bitfieldsOn!("ui",
            int, "ui1", 4,
            int, "ui2", 4));
        mixin(bitfieldsOn!("us",
            int, "us1", 4,
            int, "us2", 4));
        mixin(bitfieldsOn!("ub",
            int, "ub1", 4,
            int, "ub2", 4));
            
        //the following should all fail.
        static assert(is(typeof({
            mixin(bitfieldsOn!("fl",  //float
                int, "fl1", 4,
                int, "", 4));
            }) == bool) == false);
        static assert(is(typeof({
            mixin(bitfieldsOn!("dbl", //double
                int, "dbl1", 4,
                int, "", 4));
            }) == bool) == false);
        static assert(is(typeof({
            mixin(bitfieldsOn!("sl",  //signed - May be relaxed later.
                int, "sl1", 4,
                int, "", 4));
            }) == bool) == false);
        static assert(is(typeof({
            mixin(bitfieldsOn!("x",   //struct
                int, "x1", 4,
                int, "", 4));
            }) == bool) == false);
        static assert(is(typeof({
            mixin(bitfieldsOn!("ub",   //too large for variable
                int, "too_big", 8,
                int, "for_ubyte", 8));
            }) == bool) == false);
    }
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
    x.fraction = 0x4UL << 48;
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
    @property void length(size_t newlen)
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
    @property BitArray dup()
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
        byte *p1 = cast(byte*)this.ptr;
        byte *p2 = cast(byte*)a2.ptr;
        auto n = this.length / 8;
        for (i = 0; i < n; i++)
        {
            if (p1[i] != p2[i])
                return 0;                // not equal
        }

        ubyte mask;

        n = this.length & 7;
        mask = cast(ubyte)((1 << n) - 1);
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
    int opCmp(BitArray a2)
    {
        uint i;

        auto len = this.length;
        if (a2.length < len)
            len = a2.length;
        ubyte* p1 = cast(ubyte*)this.ptr;
        ubyte* p2 = cast(ubyte*)a2.ptr;
        auto n = len / 8;
        for (i = 0; i < n; i++)
        {
            if (p1[i] != p2[i])
                break;                // not equal
        }
        for (uint j = i * 8; j < len; j++)
        {
            ubyte mask = cast(ubyte)(1 << j);
            int c;

            c = cast(int)(p1[i] & mask) - cast(int)(p2[i] & mask);
            if (c)
                return c;
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
    BitArray opOr(BitArray e2)
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
    BitArray opXor(BitArray e2)
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
    BitArray opSub(BitArray e2)
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
    BitArray opCat(bool b)
    {
        BitArray r;

        r = this.dup;
        r.length = len + 1;
        r[len] = b;
        return r;
    }

    /** ditto */
    BitArray opCat_r(bool b)
    {
        BitArray r;

        r.length = len + 1;
        r[0] = b;
        for (size_t i = 0; i < len; i++)
            r[1 + i] = this[i];
        return r;
    }

    /** ditto */
    BitArray opCat(BitArray b)
    {
        BitArray r;

        r = this.dup();
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
