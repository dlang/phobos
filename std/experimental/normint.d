// Written in the D programming language.

/**
This module implements support for normalized integers.

Authors:    Manu Evans
Copyright:  Copyright (c) 2015, Manu Evans.
License:    $(WEB boost.org/LICENSE_1_0.txt, Boost License 1.0)
Source:     $(PHOBOSSRC std/experimental/normint.d)
*/
module std.experimental.normint;

import std.traits : isIntegral, isSigned, isUnsigned, isFloatingPoint;
static import std.algorithm;

import std.experimental.color : FloatTypeFor;

@safe pure nothrow @nogc:


/**
Normalized integers express a fractional range of values within an integer data type.

Unsigned integers map the values 0 -> I.max to the fractional values 0.0 -> 1.0 in equal increments.
Signed integers represent the values -I.max -> 0 -> I.max to fractional values -1.0 -> 0.0 -> 1.0 in equal increments. I.min is outside the nominal integer range and is clamped to represent -1.0.

Params: I = Any builtin integer type.
*/
struct NormalizedInt(I) if(isIntegral!I)
{
@safe:

    string toString() const
    {
        import std.conv : to;
        return to!string(cast(float)this);
    }
    unittest
    {
        import std.conv : to;
        assert(to!string(NormalizedInt!ubyte(0xFF)) == "1");
    }

pure nothrow @nogc:

    I value;

    /** Integral storage type. */
    alias IntType = I;

    /** Maximum integral value. */
    enum max = I.max;
    /** Minimum integral value. */
    enum min = isSigned!I ? -I.max : 0;
    /** Maximum floating point value. */
    enum max_float = 1.0;
    /** Minimum floating point value. */
    enum min_float = isSigned!I ? -1.0 : 0.0;

    /** Construct a NormalizedInt from an integer representation. */
    this(I value)
    {
        this.value = value;
    }
    ///
    unittest
    {
        static assert(NormalizedInt!ubyte(100) == 100);
    }

    /** Construct a NormalizedInt from a floating point representation. The value is clamped to the range [min, max]. */
    this(F)(F value) if(isFloatingPoint!F)
    {
        if(value >= max_float)
            this.value = max;
        else if(value <= min_float)
            this.value = min;
        else if(value >= 0)
            this.value = cast(I)(value*max + 0.5);
        else
            this.value = cast(I)(value*max - 0.5);
    }
    ///
    unittest
    {
        static assert(NormalizedInt!ubyte(1.0) == 255);
        static assert(NormalizedInt!ubyte(2.0) == 255);
        static assert(NormalizedInt!ubyte(0.5) == 128);
        static assert(NormalizedInt!ubyte(-2.0) == 0);
        static assert(NormalizedInt!byte(-2.0) == -127);
    }

    NormalizedInt!I opUnary(string op)() const
    {
        return NormalizedInt!I(mixin(op ~ "value"));
    }
    unittest
    {
        static assert(+NormalizedInt!ubyte(0.5) == 128);
        static assert(-NormalizedInt!ubyte(0.5) == 128);
        static assert(~NormalizedInt!ubyte(0.5) == 127);
        static assert(+NormalizedInt!byte(0.5) == 64);
        static assert(-NormalizedInt!byte(0.5) == -64);
        static assert(~NormalizedInt!byte(0.5) == -65);
    }

    NormalizedInt!I opBinary(string op)(NormalizedInt!I rh) const if(op == "+" || op == "-")
    {
        auto r = mixin("value " ~ op ~ " rh.value");
        r = std.algorithm.min(r, max);
        static if(op == "-")
            r = std.algorithm.max(r, min);
        return NormalizedInt!I(cast(I)r);
    }
    unittest
    {
        static assert(NormalizedInt!ubyte(1.0) + NormalizedInt!ubyte(0.5) == 255);
        static assert(NormalizedInt!ubyte(1.0) - NormalizedInt!ubyte(0.5) == 127);
        static assert(NormalizedInt!ubyte(0.5) - NormalizedInt!ubyte(1.0) == 0);
        static assert(NormalizedInt!byte(1.0) + NormalizedInt!byte(0.5) == 127);
        static assert(NormalizedInt!byte(1.0) - NormalizedInt!byte(0.5) == 63);
        static assert(NormalizedInt!byte(-0.5) - NormalizedInt!byte(1.0) == -127);
    }

    NormalizedInt!I opBinary(string op)(NormalizedInt!I rh) const if(op == "*" || op == "^^")
    {
        static if(is(I == ubyte) && op == "*")
        {
            uint r = cast(uint)value * rh.value;
            r = r * 0x1011 >> 20;
        }
        else static if(is(I == ushort) && op == "*")
        {
            ulong r = cast(ulong)value * rh.value;
            r = r * 0x10_0011 >> 36;
        }
        else
        {
            // *** SLOW PATH ***
            // do it with floats
            double a = value * (1.0/max);
            double b = rh.value * (1.0/max);
            static if(isSigned!I)
            {
                a = std.algorithm.max(a, -1.0);
                b = std.algorithm.max(b, -1.0);
            }
            double r = mixin("a" ~ op ~ "b") * (max * 1.000000000000001); // conversion may lose a bit of mantissa, so we add this epsilon
        }
        return NormalizedInt!I(cast(I)r);
    }
    unittest
    {
        // ubyte (has a fast no-float path)
        static assert(NormalizedInt!ubyte(0xFF) * NormalizedInt!ubyte(0xFF) == 255);
        static assert(NormalizedInt!ubyte(0xFF) * NormalizedInt!ubyte(0xFE) == 254);
        static assert(NormalizedInt!ubyte(0xFF) * NormalizedInt!ubyte(0x80) == 128);
        static assert(NormalizedInt!ubyte(0xFF) * NormalizedInt!ubyte(0x40) == 64);
        static assert(NormalizedInt!ubyte(0xFF) * NormalizedInt!ubyte(0x02) == 2);
        static assert(NormalizedInt!ubyte(0xFF) * NormalizedInt!ubyte(0x01) == 1);
        static assert(NormalizedInt!ubyte(0x80) * NormalizedInt!ubyte(0xFF) == 128);
        static assert(NormalizedInt!ubyte(0x80) * NormalizedInt!ubyte(0xFE) == 127);
        static assert(NormalizedInt!ubyte(0x80) * NormalizedInt!ubyte(0x80) == 64);
        static assert(NormalizedInt!ubyte(0x80) * NormalizedInt!ubyte(0x40) == 32);
        static assert(NormalizedInt!ubyte(0x80) * NormalizedInt!ubyte(0x02) == 1);
        static assert(NormalizedInt!ubyte(0x80) * NormalizedInt!ubyte(0x01) == 0);
        static assert(NormalizedInt!ubyte(0x40) * NormalizedInt!ubyte(0xFF) == 64);
        static assert(NormalizedInt!ubyte(0x40) * NormalizedInt!ubyte(0xFE) == 63);
        static assert(NormalizedInt!ubyte(0x40) * NormalizedInt!ubyte(0x80) == 32);
        static assert(NormalizedInt!ubyte(0x40) * NormalizedInt!ubyte(0x40) == 16);
        static assert(NormalizedInt!ubyte(0x40) * NormalizedInt!ubyte(0x02) == 0);
        static assert(NormalizedInt!ubyte(0x40) * NormalizedInt!ubyte(0x01) == 0);

        // positive byte
        static assert(NormalizedInt!byte(cast(byte)0x7F) * NormalizedInt!byte(cast(byte)0x7F) == 127);
        static assert(NormalizedInt!byte(cast(byte)0x7F) * NormalizedInt!byte(cast(byte)0x7E) == 126);
        static assert(NormalizedInt!byte(cast(byte)0x7F) * NormalizedInt!byte(cast(byte)0x40) == 64);
        static assert(NormalizedInt!byte(cast(byte)0x7F) * NormalizedInt!byte(cast(byte)0x02) == 2);
        static assert(NormalizedInt!byte(cast(byte)0x7F) * NormalizedInt!byte(cast(byte)0x01) == 1);
        static assert(NormalizedInt!byte(cast(byte)0x40) * NormalizedInt!byte(cast(byte)0x7F) == 64);
        static assert(NormalizedInt!byte(cast(byte)0x40) * NormalizedInt!byte(cast(byte)0x7E) == 63);
        static assert(NormalizedInt!byte(cast(byte)0x40) * NormalizedInt!byte(cast(byte)0x40) == 32);
        static assert(NormalizedInt!byte(cast(byte)0x40) * NormalizedInt!byte(cast(byte)0x02) == 1);
        static assert(NormalizedInt!byte(cast(byte)0x40) * NormalizedInt!byte(cast(byte)0x01) == 0);
        static assert(NormalizedInt!byte(cast(byte)0x20) * NormalizedInt!byte(cast(byte)0x7F) == 32);
        static assert(NormalizedInt!byte(cast(byte)0x20) * NormalizedInt!byte(cast(byte)0x7E) == 31);
        static assert(NormalizedInt!byte(cast(byte)0x20) * NormalizedInt!byte(cast(byte)0x40) == 16);
        static assert(NormalizedInt!byte(cast(byte)0x20) * NormalizedInt!byte(cast(byte)0x02) == 0);
        static assert(NormalizedInt!byte(cast(byte)0x20) * NormalizedInt!byte(cast(byte)0x01) == 0);
        // negative byte
        static assert(NormalizedInt!byte(cast(byte)0x81) * NormalizedInt!byte(cast(byte)0x7F) == -127);
        static assert(NormalizedInt!byte(cast(byte)0x81) * NormalizedInt!byte(cast(byte)0x7E) == -126);
        static assert(NormalizedInt!byte(cast(byte)0x81) * NormalizedInt!byte(cast(byte)0x40) == -64);
        static assert(NormalizedInt!byte(cast(byte)0x81) * NormalizedInt!byte(cast(byte)0x02) == -2);
        static assert(NormalizedInt!byte(cast(byte)0x81) * NormalizedInt!byte(cast(byte)0x01) == -1);
        static assert(NormalizedInt!byte(cast(byte)0xC0) * NormalizedInt!byte(cast(byte)0x7F) == -64);
        static assert(NormalizedInt!byte(cast(byte)0xC0) * NormalizedInt!byte(cast(byte)0x7E) == -63);
        static assert(NormalizedInt!byte(cast(byte)0xC0) * NormalizedInt!byte(cast(byte)0x40) == -32);
        static assert(NormalizedInt!byte(cast(byte)0xC0) * NormalizedInt!byte(cast(byte)0x02) == -1);
        static assert(NormalizedInt!byte(cast(byte)0xC0) * NormalizedInt!byte(cast(byte)0x01) == 0);
        static assert(NormalizedInt!byte(cast(byte)0xE0) * NormalizedInt!byte(cast(byte)0x7F) == -32);
        static assert(NormalizedInt!byte(cast(byte)0xE0) * NormalizedInt!byte(cast(byte)0x7E) == -31);
        static assert(NormalizedInt!byte(cast(byte)0xE0) * NormalizedInt!byte(cast(byte)0x40) == -16);
        static assert(NormalizedInt!byte(cast(byte)0xE0) * NormalizedInt!byte(cast(byte)0x02) == 0);
        static assert(NormalizedInt!byte(cast(byte)0xE0) * NormalizedInt!byte(cast(byte)0x01) == 0);

        // ushort (has a fast no-float path)
        static assert(NormalizedInt!ushort(0xFFFF) * NormalizedInt!ushort(0xFFFF) == 0xFFFF);
        static assert(NormalizedInt!ushort(0xFFFF) * NormalizedInt!ushort(0xFFFE) == 0xFFFE);
        static assert(NormalizedInt!ushort(0xFFFF) * NormalizedInt!ushort(0x8000) == 0x8000);
        static assert(NormalizedInt!ushort(0xFFFF) * NormalizedInt!ushort(0x4000) == 0x4000);
        static assert(NormalizedInt!ushort(0xFFFF) * NormalizedInt!ushort(0x0002) == 0x0002);
        static assert(NormalizedInt!ushort(0xFFFF) * NormalizedInt!ushort(0x0001) == 0x0001);
        static assert(NormalizedInt!ushort(0x8000) * NormalizedInt!ushort(0xFFFF) == 0x8000);
        static assert(NormalizedInt!ushort(0x8000) * NormalizedInt!ushort(0xFFFE) == 0x7FFF);
        static assert(NormalizedInt!ushort(0x8000) * NormalizedInt!ushort(0x8000) == 0x4000);
        static assert(NormalizedInt!ushort(0x8000) * NormalizedInt!ushort(0x4000) == 0x2000);
        static assert(NormalizedInt!ushort(0x8000) * NormalizedInt!ushort(0x0002) == 0x0001);
        static assert(NormalizedInt!ushort(0x8000) * NormalizedInt!ushort(0x0001) == 0x0000);
        static assert(NormalizedInt!ushort(0x4000) * NormalizedInt!ushort(0xFFFF) == 0x4000);
        static assert(NormalizedInt!ushort(0x4000) * NormalizedInt!ushort(0xFFFE) == 0x3FFF);
        static assert(NormalizedInt!ushort(0x4000) * NormalizedInt!ushort(0x8000) == 0x2000);
        static assert(NormalizedInt!ushort(0x4000) * NormalizedInt!ushort(0x4000) == 0x1000);
        static assert(NormalizedInt!ushort(0x4000) * NormalizedInt!ushort(0x0002) == 0x0000);
        static assert(NormalizedInt!ushort(0x4000) * NormalizedInt!ushort(0x0001) == 0x0000);

        // uint
        static assert(NormalizedInt!uint(0xFFFFFFFF) * NormalizedInt!uint(0xFFFFFFFF) == 0xFFFFFFFF);
        static assert(NormalizedInt!uint(0xFFFFFFFF) * NormalizedInt!uint(0xFFFFFFFE) == 0xFFFFFFFE);
        static assert(NormalizedInt!uint(0xFFFFFFFF) * NormalizedInt!uint(0x80000000) == 0x80000000);
        static assert(NormalizedInt!uint(0xFFFFFFFF) * NormalizedInt!uint(0x40000000) == 0x40000000);
        static assert(NormalizedInt!uint(0xFFFFFFFF) * NormalizedInt!uint(0x00000002) == 0x00000002);
        static assert(NormalizedInt!uint(0xFFFFFFFF) * NormalizedInt!uint(0x00000001) == 0x00000001);
        static assert(NormalizedInt!uint(0x80000000) * NormalizedInt!uint(0xFFFFFFFF) == 0x80000000);
        static assert(NormalizedInt!uint(0x80000000) * NormalizedInt!uint(0xFFFFFFFE) == 0x7FFFFFFF);
        static assert(NormalizedInt!uint(0x80000000) * NormalizedInt!uint(0x80000000) == 0x40000000);
        static assert(NormalizedInt!uint(0x80000000) * NormalizedInt!uint(0x40000000) == 0x20000000);
        static assert(NormalizedInt!uint(0x80000000) * NormalizedInt!uint(0x00000002) == 0x00000001);
        static assert(NormalizedInt!uint(0x80000000) * NormalizedInt!uint(0x00000001) == 0x00000000);
        static assert(NormalizedInt!uint(0x40000000) * NormalizedInt!uint(0xFFFFFFFF) == 0x40000000);
        static assert(NormalizedInt!uint(0x40000000) * NormalizedInt!uint(0xFFFFFFFE) == 0x3FFFFFFF);
        static assert(NormalizedInt!uint(0x40000000) * NormalizedInt!uint(0x80000000) == 0x20000000);
        static assert(NormalizedInt!uint(0x40000000) * NormalizedInt!uint(0x40000000) == 0x10000000);
        static assert(NormalizedInt!uint(0x40000000) * NormalizedInt!uint(0x00000002) == 0x00000000);
        static assert(NormalizedInt!uint(0x40000000) * NormalizedInt!uint(0x00000001) == 0x00000000);

        // int
        static assert(NormalizedInt!int(0x80000001) * NormalizedInt!int(0x7FFFFFFF) == 0x80000001);
        static assert(NormalizedInt!int(0x80000001) * NormalizedInt!int(0x7FFFFFFE) == 0x80000002);
        static assert(NormalizedInt!int(0x80000001) * NormalizedInt!int(0x40000000) == 0xC0000000);
        static assert(NormalizedInt!int(0x80000001) * NormalizedInt!int(0x00000002) == 0xFFFFFFFE);
        static assert(NormalizedInt!int(0x80000001) * NormalizedInt!int(0x00000001) == 0xFFFFFFFF);
        static assert(NormalizedInt!int(0xC0000000) * NormalizedInt!int(0x7FFFFFFF) == 0xC0000000);
        static assert(NormalizedInt!int(0xC0000000) * NormalizedInt!int(0x7FFFFFFE) == 0xC0000001);
        static assert(NormalizedInt!int(0xC0000000) * NormalizedInt!int(0x40000000) == 0xE0000000);
        static assert(NormalizedInt!int(0xC0000000) * NormalizedInt!int(0x00000002) == 0xFFFFFFFF);
        static assert(NormalizedInt!int(0xC0000000) * NormalizedInt!int(0x00000001) == 0x00000000);
        static assert(NormalizedInt!int(0xE0000000) * NormalizedInt!int(0x7FFFFFFF) == 0xE0000000);
        static assert(NormalizedInt!int(0xE0000000) * NormalizedInt!int(0x7FFFFFFE) == 0xE0000001);
        static assert(NormalizedInt!int(0xE0000000) * NormalizedInt!int(0x40000000) == 0xF0000000);
        static assert(NormalizedInt!int(0xE0000000) * NormalizedInt!int(0x00000002) == 0x00000000);
        static assert(NormalizedInt!int(0xE0000000) * NormalizedInt!int(0x00000001) == 0x00000000);
    }

    NormalizedInt!I opBinary(string op)(NormalizedInt!I rh) const if(op == "/" || op == "%")
    {
        return mixin("this " ~ op ~ " cast(FloatTypeFor!I)rh");
    }
    unittest
    {
        static assert(NormalizedInt!ubyte(0x80) / NormalizedInt!ubyte(0xFF) == 0x80);
        static assert(NormalizedInt!ubyte(0x80) / NormalizedInt!ubyte(0x80) == 0xFF);

        static assert(NormalizedInt!ubyte(0x80) % NormalizedInt!ubyte(0xFF) == 0x80);
        static assert(NormalizedInt!ubyte(0x80) % NormalizedInt!ubyte(0x80) == 0);
    }

    NormalizedInt!I opBinary(string op, T)(T rh) const if(isIntegral!T && op == "*")
    {
        return NormalizedInt!I(cast(I)std.algorithm.clamp(value * rh, min, max));
    }
    unittest
    {
        static assert(NormalizedInt!ubyte(0x40) * 2 == 0x80);
        static assert(NormalizedInt!ubyte(0x80) * 2 == 0xFF);
        static assert(NormalizedInt!ubyte(0xFF) * 2 == 0xFF);
        static assert(NormalizedInt!byte(32) * 2 == 64);
        static assert(NormalizedInt!byte(64) * 2 == 127);
        static assert(NormalizedInt!byte(127) * 2 == 127);
        static assert(NormalizedInt!byte(-32) * 2 == -64);
        static assert(NormalizedInt!byte(-64) * 2 == -127);
        static assert(NormalizedInt!byte(-127) * 2 == -127);
        static assert(NormalizedInt!byte(-32) * -2 == 64);
        static assert(NormalizedInt!byte(-64) * -2 == 127);
    }

    NormalizedInt!I opBinary(string op, T)(T rh) const if(isIntegral!T && (op == "/" || op == "%"))
    {
        return NormalizedInt!I(cast(I)mixin("value " ~ op ~ " rh"));
    }
    unittest
    {
        static assert(NormalizedInt!ubyte(0x40) / 2 == 0x20);
        static assert(NormalizedInt!ubyte(0xFF) / 2 == 0x7F);

        static assert(NormalizedInt!ubyte(0x40) % 2 == 0);
        static assert(NormalizedInt!ubyte(0xFF) % 2 == 1);
    }

    NormalizedInt!I opBinary(string op, F)(F rh) const if(isFloatingPoint!F && (op == "*" || op == "/" || op == "%"))
    {
        return NormalizedInt!I(mixin("cast(F)this " ~ op ~ " rh"));
    }
    unittest
    {
        static assert(NormalizedInt!ubyte(0x40) * 2.0 == 0x80);
        static assert(NormalizedInt!ubyte(0x80) * 2.0 == 0xFF);
        static assert(NormalizedInt!ubyte(0xFF) * 2.0 == 0xFF);
        static assert(NormalizedInt!byte(32) * 2.0 == 64);
        static assert(NormalizedInt!byte(64) * 2.0 == 127);
        static assert(NormalizedInt!byte(127) * 2.0 == 127);
        static assert(NormalizedInt!byte(-32) * 2.0 == -64);
        static assert(NormalizedInt!byte(-64) * 2.0 == -127);
        static assert(NormalizedInt!byte(-127) * 2.0 == -127);
        static assert(NormalizedInt!byte(-32) * -2.0 == 64);
        static assert(NormalizedInt!byte(-64) * -2.0 == 127);

        static assert(NormalizedInt!ubyte(0x40) * 0.5 == 0x20);
        static assert(NormalizedInt!ubyte(0x80) * 0.5 == 0x40);
        static assert(NormalizedInt!ubyte(0xFF) * 0.5 == 0x80);
        static assert(NormalizedInt!byte(32) * 0.5 == 16);
        static assert(NormalizedInt!byte(64) * 0.5 == 32);
        static assert(NormalizedInt!byte(127) * 0.5 == 64);
        static assert(NormalizedInt!byte(-32) * 0.5 == -16);
        static assert(NormalizedInt!byte(-64) * 0.5 == -32);
        static assert(NormalizedInt!byte(-127) * 0.5 == -64);
        static assert(NormalizedInt!byte(-32) * -0.5 == 16);
        static assert(NormalizedInt!byte(-64) * -0.5 == 32);

        static assert(NormalizedInt!ubyte(0xFF) / 2.0 == 0x80);
        static assert(NormalizedInt!ubyte(0xFF) % 0.5 == 0);
    }

    NormalizedInt!I opBinary(string op)(NormalizedInt!I rh) const if(op == "|" || op == "&" || op == "^")
    {
        return NormalizedInt!I(cast(I)(mixin("value " ~ op ~ " rh.value")));
    }
    unittest
    {
        static assert((NormalizedInt!uint(0x80) | NormalizedInt!uint(0x08)) == 0x88);
        static assert((NormalizedInt!uint(0xF0) & NormalizedInt!uint(0x81)) == 0x80);
        static assert((NormalizedInt!uint(0x81) ^ NormalizedInt!uint(0x80)) == 0x01);
    }

    NormalizedInt!I opBinary(string op)(int rh) const if(op == "<<" || op == ">>" || op == ">>>")
    {
        return NormalizedInt!I(cast(I)(mixin("value " ~ op ~ " rh")));
    }
    unittest
    {
        static assert(NormalizedInt!uint(0x08000000) << 2 == 0x20000000);
        static assert(NormalizedInt!int(0x80000000) >> 7 == 0xFF000000);
        static assert(NormalizedInt!int(0x80000000) >>> 7 == 0x01000000);
    }

    bool opEquals(NormalizedInt!I rh) const
    {
        return value == rh.value;
    }
    bool opEquals(T)(T rh) const if(isIntegral!T)
    {
        return value == rh;
    }
    bool opEquals(F)(F rh) const if(isFloatingPoint!F)
    {
        return cast(float)value == rh;
    }

    int opCmp(NormalizedInt!I rh) const
    {
        return value - rh.value;
    }
    int opCmp(T)(T rh) const if(isIntegral!T)
    {
        return value - rh;
    }
    int opCmp(F)(F rh) const if(isFloatingPoint!F)
    {
        F f = cast(F)value - rh;
        return f < 0 ? -1 : (f > 0 ? 1 : 0);
    }

    ref NormalizedInt!I opOpAssign(string op, T)(T rh) if(is(T == NormalizedInt!I) || isFloatingPoint!T || isIntegral!T)
    {
        this = mixin("this " ~ op ~ "rh");
        return this;
    }

    NormInt opCast(NormInt)() const if(is(NormInt == NormalizedInt!T, T))
    {
        static if(is(NormInt == NormalizedInt!T, T))
            return NormInt(convertNormInt!T(value));
        else
            static assert(false, "Shouldn't be possible!");
    }
    unittest
    {
        // up cast
        static assert(cast(NormalizedInt!ushort)NormalizedInt!ubyte(0xFF) == 0xFFFF);
        static assert(cast(NormalizedInt!ushort)NormalizedInt!ubyte(0x81) == 0x8181);

        // down cast
        static assert(cast(NormalizedInt!ubyte)NormalizedInt!ushort(0xFFFF) == 0xFF);
        static assert(cast(NormalizedInt!ubyte)NormalizedInt!ushort(0x9F37) == 0x9F);

        // signed -> unsigned
        static assert(cast(NormalizedInt!ubyte)NormalizedInt!byte(127) == 0xFF);
        static assert(cast(NormalizedInt!ushort)NormalizedInt!byte(127) == 0xFFFF);
        static assert(cast(NormalizedInt!ubyte)NormalizedInt!byte(-127) == 0);
        static assert(cast(NormalizedInt!ubyte)NormalizedInt!byte(-128) == 0);
        static assert(cast(NormalizedInt!ushort)NormalizedInt!byte(-127) == 0);
        static assert(cast(NormalizedInt!ubyte)NormalizedInt!short(-32767) == 0);
        static assert(cast(NormalizedInt!ubyte)NormalizedInt!short(-32768) == 0);

        // unsigned -> signed
        static assert(cast(NormalizedInt!byte)NormalizedInt!ubyte(0xFF) == 0x7F);
        static assert(cast(NormalizedInt!byte)NormalizedInt!ubyte(0x83) == 0x41);
        static assert(cast(NormalizedInt!short)NormalizedInt!ubyte(0xFF) == 0x7FFF);
        static assert(cast(NormalizedInt!short)NormalizedInt!ubyte(0x83) == 0x41C1);
        static assert(cast(NormalizedInt!byte)NormalizedInt!ushort(0xFFFF) == 0x7F);
        static assert(cast(NormalizedInt!byte)NormalizedInt!ushort(0x83F7) == 0x41);

        // signed -> signed
        static assert(cast(NormalizedInt!short)NormalizedInt!byte(127) == 32767);
        static assert(cast(NormalizedInt!byte)NormalizedInt!short(32767) == 127);
        static assert(cast(NormalizedInt!short)NormalizedInt!byte(-127) == -32767);
        static assert(cast(NormalizedInt!byte)NormalizedInt!short(-32767) == -127);
    }

    F opCast(F)() const if(isFloatingPoint!F)
    {
        F r = value * F(1.0/max);
        static if(isSigned!I)
        {
            // max(c, -1) is the signed conversion followed by D3D, OpenGL, etc.
            r = std.algorithm.max(r, F(-1.0));
        }
        return r;
    }
    unittest
    {
        static assert(cast(float)NormalizedInt!ubyte(0xFF) == 1.0);
        static assert(cast(float)NormalizedInt!ubyte(0x00) == 0.0);
        static assert(cast(float)NormalizedInt!ubyte(0x80) > 0.5);
        static assert(cast(float)NormalizedInt!ubyte(0x7F) < 0.5);
        static assert(cast(float)NormalizedInt!byte(127) == 1.0);
        static assert(cast(float)NormalizedInt!byte(-128) == -1.0);
        static assert(cast(float)NormalizedInt!byte(-127) == -1.0);
        static assert(cast(float)NormalizedInt!byte(0x00) == 0.0);
        static assert(cast(float)NormalizedInt!byte(0x40) > 0.5);
        static assert(cast(float)NormalizedInt!byte(0x3F) < 0.5);
    }
}


/** Convert values between normalized integer types. */
To convertNormInt(To, From)(From i) if(isIntegral!To && isIntegral!From)
{
    // TODO: this should be tested for performance; we can optimise the small->large conversions with table lookups, maybe imul?

    import std.typetuple : TypeTuple;
    import std.traits : Unsigned;

    template Iota(alias start, alias end)
    {
        static if(end == start)
            alias Iota = TypeTuple!();
        else
            alias Iota = TypeTuple!(Iota!(start, end-1), end-1);
    }
    enum Bits(T) = T.sizeof*8;

    static if(isUnsigned!To && isUnsigned!From)
    {
        static if(Bits!To <= Bits!From)
            return To(i >> (Bits!From-Bits!To));
        else
        {
            To r;

            enum numReps = Bits!To/Bits!From;
            foreach(j; Iota!(0, numReps))
                r |= To(i) << (j*Bits!From);

            return r;
        }
    }
    else static if(isUnsigned!To)
    {
        if(i < 0) // if i is negative, return 0
            return 0;
        else
        {
            enum Sig = Bits!From-1;
            static if(Bits!To < Bits!From)
                return cast(To)(i >> (Sig-Bits!To));
            else
            {
                To r;

                enum numReps = Bits!To/Sig;
                foreach(j; Iota!(1, numReps+1))
                    r |= To(cast(Unsigned!From)(i&From.max)) << (Bits!To - j*Sig);

                enum remain = Bits!To - numReps*Sig;
                static if(remain)
                    r |= cast(Unsigned!From)(i&From.max) >> (Sig - remain);

                return r;
            }
        }
    }
    else static if(isUnsigned!From)
    {
        static if(Bits!To <= Bits!From)
            return To(i >> (Bits!From-Bits!To+1));
        else
        {
            Unsigned!To r;

            enum numReps = Bits!To/Bits!From;
            foreach(j; Iota!(0, numReps))
                r |= Unsigned!To(i) << (j*Bits!From);

            return To(r >> 1);
        }
    }
    else
    {
        // TODO: there may be a faster path for byte<->short using imul
        double f = std.algorithm.max(i * (1.0/From.max), -1.0);
        return cast(To)(f * double(To.max));
    }
}
///
unittest
{
    // unsigned -> unsigned
    static assert(convertNormInt!ubyte(ushort(0x3765)) == 0x37);
    static assert(convertNormInt!ushort(ubyte(0x37)) == 0x3737);
    static assert(convertNormInt!ulong(ubyte(0x35)) == 0x3535353535353535);

    // signed -> unsigned
    static assert(convertNormInt!ubyte(short(-61)) == 0);
    static assert(convertNormInt!ubyte(short(0x3795)) == 0x6F);
    static assert(convertNormInt!ushort(byte(0x37)) == 0x6EDD);
    static assert(convertNormInt!ulong(byte(0x35)) == 0x6AD5AB56AD5AB56A);

    // unsigned -> signed
    static assert(convertNormInt!byte(ushort(0x3765)) == 0x1B);
    static assert(convertNormInt!short(ubyte(0x37)) == 0x1B9B);
    static assert(convertNormInt!long(ubyte(0x35)) == 0x1A9A9A9A9A9A9A9A);

    // signed -> signed
    static assert(convertNormInt!short(byte(-127)) == -32767);
    static assert(convertNormInt!short(byte(-128)) == -32767);
    static assert(convertNormInt!byte(short(0x3795)) == 0x37);
    static assert(convertNormInt!byte(short(-28672)) == -111);
    static assert(convertNormInt!short(byte(0x37)) == 0x376E);
    static assert(convertNormInt!short(byte(-109)) == -28122);
}
