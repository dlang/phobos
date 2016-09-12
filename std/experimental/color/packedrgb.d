// Written in the D programming language.

/**
    This module implements the packed RGB _color type.

    Authors:    Manu Evans
    Copyright:  Copyright (c) 2015, Manu Evans.
    License:    $(WEB boost.org/LICENSE_1_0.txt, Boost License 1.0)
    Source:     $(PHOBOSSRC std/experimental/color/_packedrgb.d)
*/
module std.experimental.color.packedrgb;

import std.experimental.color;
import std.experimental.color.rgb;
import std.experimental.color.colorspace : RGBColorSpace;
import std.experimental.normint;

import std.traits : isNumeric, isFloatingPoint, isSigned, isUnsigned, Unsigned;

@safe pure nothrow:


/**
Detect whether $(D_INLINECODE T) is a packed RGB color.
*/
enum isPackedRGB(T) = isInstanceOf!(PackedRGB, T);

///
unittest
{
    static assert(isPackedRGB!(PackedRGB!("rgb_5_6_5", ubyte)) == true);
    static assert(isPackedRGB!(PackedRGB!("rgba_s10_s10_s10_u2", short)) == true);
    static assert(isPackedRGB!(PackedRGB!("rg_f16_f16", float)) == true);
    static assert(isPackedRGB!(PackedRGB!("rgb_f11_f11_f10", float)) == true);
    static assert(isPackedRGB!(PackedRGB!("rgb_9_9_9_e5", float)) == true);
    static assert(isPackedRGB!(PackedRGB!("rgb_f10_s4_u2", float)) == true);
    static assert(isPackedRGB!int == false);
}


/** Component info struct. */
struct ComponentInfo
{
    /** Type of the component. */
    enum ComponentType : ubyte
    {
        /** Component is unsigned normalized integer. */
        Unsigned,
        /** Component is signed normalized integer. */
        Signed,
        /** Component is floating point. Floats with less than 16 bits precision are unsigned. */
        Float,
        /** Component is floating point mantissa only. */
        Mantissa,
        /** Component is floating point exponent only. */
        Exponent,
    }

    /** First bit, starting from bit 0 (LSB). */
    ubyte offset;
    /** Number of bits. */
    ubyte bits;
    /** Component type. */
    ComponentType type;
}

/** Buffer used for bit-packing. */
struct Buffer(size_t N)
{
@safe pure nothrow @nogc:

    private
    {
        static if (N >= 8 && (N & 7) == 0)
            ulong[N/8] data;
        else static if (N >= 4 && (N & 3) == 0)
            uint[N/4] data;
        else static if (N >= 2 && (N & 1) == 0)
            ushort[N/2] data;
        else
            ubyte[N] data;
    }

    /** Read bits from the buffer. */
    @property uint bits(size_t Offset, size_t Bits)() const
    {
        enum Index = Offset / ElementWidth;
        enum ElementOffset = Offset % ElementWidth;
        static assert(Offset+Bits <= data.sizeof*8, "Bits are outside of data range");
        static assert(Index == (Offset+Bits-1) / ElementWidth, "Bits may not straddle element boundaries");
        return (data[Index] >> ElementOffset) & ((1UL << Bits)-1);
    }

    /** Write bits to the buffer. */
    @property void bits(size_t Offset, size_t Bits)(uint value)
    {
        enum Index = Offset / ElementWidth;
        enum ElementOffset = Offset % ElementWidth;
        static assert(Offset+Bits <= data.sizeof*8, "Bits are outside of data range");
        static assert(Index == (Offset+Bits-1) / ElementWidth, "Bits may not straddle element boundaries");
        data[Index] |= (value & ((1UL << Bits)-1)) << ElementOffset;
    }

    /** Element width for multi-element buffers. */
    enum ElementWidth = data[0].sizeof*8;
}

/**
A packed RGB color, parameterised with format, unpacked component type, and color space specification.

Params: format_ = Format of the packed color.$(BR)
                  Format shall be arranged for instance: "rgba_10_10_10_2" for 10 bits each RGB, and 2 bits alpha, starting from the least significant bit.$(BR)
                  Formats may specify packed floats: "rgba_f16_f16_f16_f16" for an RGBA half-precision float color.$(BR)
                  Low-precision floats are supported: "rgb_f11_f11_f10" for an RGB partial-precision floating point format. Floats with less than 16 bits always have a 5 bit exponent, and no sign bit.$(BR)
                  Formats may specify a shared exponent: "rgb_9_9_9_e5" for 9 mantissa bits each RGB, and a 5 bit shared exponent.$(BR)
                  Formats may specify the signed-ness for integer components: "rgb_s5_s5_s5_u1" for 5 bit signed RGB, and a 1 bit unsigned alpha. The 'u' is optional, default is assumed to be unsigned.$(BR)
                  Formats may contain a combination of the color channels r, g, b, l, a, x, in any order. Color channels l, and r, g, b are mutually exclusive, and may not appear together in the same color.
        ComponentType_ = Type for the unpacked color channels. May be a basic integer or floating point type.
        colorSpace_ = Color will be within the specified color space.
*/
struct PackedRGB(string format_, ComponentType_, RGBColorSpace colorSpace_ = RGBColorSpace.sRGB)
    if (isNumeric!ComponentType_)
{
@safe pure nothrow @nogc:

    // RGB colors may only contain components 'rgb', or 'l' (luminance)
    // They may also optionally contain an 'a' (alpha) component, and 'x' (unused) components
    static assert(allIn!("rgblax", components), "Invalid Color component '"d ~ notIn!("rgblax", components) ~ "'. RGB colors may only contain components: r, g, b, l, a, x"d);
    static assert(anyIn!("rgbal", components), "RGB colors must contain at least one component of r, g, b, l, a.");
    static assert(!canFind!(components, 'l') || !anyIn!("rgb", components), "RGB colors may not contain rgb AND luminance components together.");

    /** The unpacked color type. */
    alias UnpackedColor = RGB!(components, ComponentType_, false, colorSpace_);

    /** The packed color format. */
    enum format = format_;

    /** The color components that were specified. */
    enum string components = GetComponents!format_;

    /** Bit assignments for each component. */
    enum ComponentInfo[components.length] componentInfo = GetComponentInfos!AllInfos;
    /** Shared exponent bits. */
    enum ComponentInfo sharedExponent = GetSharedExponent!AllInfos;
    /** If the format has a shared exponent. */
    enum bool hasSharedExponent = sharedExponent.bits > 0;

    /** The colors color space. */
    enum RGBColorSpace colorSpace = colorSpace_;
    /** The color space descriptor. */
    enum RGBColorSpaceDesc!F colorSpaceDesc(F = double) = rgbColorSpaceDef!F(colorSpace_);

    /** Number of bits per element. */
    enum BitsPerElement = numBits(AllInfos);
    /** The raw packed data. */
    Buffer!(BitsPerElement/8) data;

    /** Test if a particular component is present. */
    enum bool hasComponent(char c) = canFind!(components, c);
    /** If the color has alpha. */
    enum bool hasAlpha = hasComponent!'a';

    /** The unpacked color. */
    @property ParentColor unpacked()
    {
        return convertColorImpl!(ParentColor)(this);
    }

    /** Construct a color from RGB and optional alpha values. */
    this(UnpackedColor color)
    {
        this = cast(typeof(this))color;
    }

    /** Cast to other color types */
    Color opCast(Color)() const if (isColor!Color)
    {
        return convertColor!Color(this);
    }

    // comparison
    bool opEquals(typeof(this) rh) const
    {
        // TODO: mask out 'x' component
        return data.data[] == rh.data.data[];
    }


package:

    alias ParentColor = UnpackedColor;

    static To convertColorImpl(To, From)(From color) if (isPackedRGB!From && isPackedRGB!To)
    {
        static if (From.colorSpace == To.colorSpace)
        {
            auto t = convertColorImpl!(From.ParentColor)(color);
            return convertColorImpl!To(t);
        }
        else
        {
            auto t = convertColorImpl!(From.ParentColor)(color);
            return convertColorImpl!To(cast(To.ParentColor)t);
        }
    }

    static To convertColorImpl(To, From)(From color) @trusted if (isPackedRGB!From && isRGB!To)
    {
        // target component type might be NormalizedInt
        static if (!isNumeric!(To.ComponentType))
            alias ToType = To.ComponentType.IntType;
        else
            alias ToType = To.ComponentType;

        // if the color has a shared exponent
        static if (From.hasSharedExponent)
            int exp = cast(int)color.data.bits!(cast(size_t)From.sharedExponent.offset, cast(size_t)From.sharedExponent.bits) - ExpBias!(cast(size_t)From.sharedExponent.bits);

        To r;
        foreach (i; Iota!(0, From.componentInfo.length))
        {
            // 'x' components are padding, no need to do work for them!
            static if (To.components[i] != 'x')
            {
                enum info = From.componentInfo[i];
                enum size_t NumBits = info.bits;

                uint bits = color.data.bits!(cast(size_t)info.offset, NumBits);

                static if (info.type == ComponentInfo.ComponentType.Unsigned ||
                           info.type == ComponentInfo.ComponentType.Signed)
                {
                    enum Signed = info.type == ComponentInfo.ComponentType.Signed;
                    static if (isFloatingPoint!ToType)
                        ToType c = normBitsToFloat!(NumBits, Signed, ToType)(bits);
                    else
                        ToType c = cast(ToType)convertNormBits!(NumBits, Signed, ToType.sizeof*8, isSigned!ToType, Unsigned!ToType)(bits);
                }
                else static if (info.type == ComponentInfo.ComponentType.Float)
                {
                    static assert(NumBits >= 6, "Needs at least 6 bits for a float!");

                    // TODO: investigate a better way to select signed-ness in the format spec, maybe 'sf10', or 's10e5'?
                    enum bool Signed = NumBits >= 16;

                    // TODO: investigate a way to specify exponent bits in the format spec, maybe 'f10e3'?
                    enum Exponent = 5;
                    enum ExpBias = ExpBias!Exponent;
                    enum Mantissa = NumBits - Exponent - (Signed ? 1 : 0);

                    uint exponent = ((bits >> Mantissa) & BitsUMax!Exponent) - ExpBias + 127;
                    uint mantissa = (bits & BitsUMax!Mantissa) << (23 - Mantissa);

                    uint u = (Signed && (bits & SignBit!NumBits) ? SignBit!32 : 0) | (exponent << 23) | mantissa;
                    static if (isFloatingPoint!ToType)
                        ToType c = *cast(float*)&u;
                    else
                        ToType c = floatToNormInt!ToType(*cast(float*)&u);
                }
                else static if (info.type == ComponentInfo.ComponentType.Mantissa)
                {
                    uint scale = (0x7F + (exp - info.bits)) << 23;
                    static if (isFloatingPoint!ToType)
                        ToType c = bits * *cast(float*)&scale;
                    else
                        ToType c = floatToNormInt!ToType(bits * *cast(float*)&scale);
                }
                mixin("r." ~ components[i] ~ " = To.ComponentType(c);");
            }
        }
        return r;
    }

    static To convertColorImpl(To, From)(From color) @trusted if (isRGB!From && isPackedRGB!To)
    {
        // target component type might be NormalizedInt
        static if (!isNumeric!(From.ComponentType))
            alias FromType = From.ComponentType.IntType;
        else
            alias FromType = From.ComponentType;

        To res;

        // if the color has a shared exponent
        static if (To.hasSharedExponent)
        {
            import std.algorithm : min, max, clamp;

            // prepare exponent...
            template SmallestMantissa(ComponentInfo[] Components)
            {
                template Impl(size_t i)
                {
                    static if (i == Components.length)
                        alias Impl = TypeTuple!();
                    else
                        alias Impl = TypeTuple!(Components[i].bits, Impl!(i+1));
                }
                enum SmallestMantissa = min(Impl!0);
            }
            enum MantBits = SmallestMantissa!(To.componentInfo);
            enum ExpBits = To.sharedExponent.bits;
            enum ExpBias = ExpBias!ExpBits;
            enum MaxExp = BitsUMax!ExpBits;

            // the maximum representable value is the one represented by the smallest mantissa
            enum MaxVal = cast(float)(BitsUMax!MantBits * (1<<(MaxExp-ExpBias))) / (1<<MantBits);

            float maxc = 0;
            foreach (i; Iota!(0, To.componentInfo.length))
            {
                static if (To.components[i] != 'x')
                    mixin("maxc = max(maxc, cast(float)color." ~ To.components[i] ~ ");");
            }
            maxc = clamp(maxc, 0, MaxVal);

            import std.stdio;

            int maxc_exp = ((*cast(uint*)&maxc >> 23) & 0xFF) - 127;
            int sexp = max(-ExpBias - 1, maxc_exp) + 1 + ExpBias;
            assert(sexp >= 0 && sexp <= MaxExp);

            res.data.bits!(cast(size_t)To.sharedExponent.offset, cast(size_t)To.sharedExponent.bits) = cast(uint)sexp;
        }

        foreach (i; Iota!(0, To.componentInfo.length))
        {
            // 'x' components are padding, no need to do work for them!
            static if (To.components[i] != 'x')
            {
                enum info = To.componentInfo[i];
                enum size_t NumBits = info.bits;

                static if (info.type == ComponentInfo.ComponentType.Unsigned ||
                           info.type == ComponentInfo.ComponentType.Signed)
                {
                    static if (isFloatingPoint!FromType)
                        mixin("FromType c = color." ~ components[i] ~ ";");
                    else
                        mixin("FromType c = color." ~ components[i] ~ ".value;");

                    enum Signed = info.type == ComponentInfo.ComponentType.Signed;
                    static if (isFloatingPoint!FromType)
                        uint bits = floatToNormBits!(NumBits, Signed)(c);
                    else
                        uint bits = convertNormBits!(FromType.sizeof*8, isSigned!FromType, NumBits, Signed)(cast(Unsigned!FromType)c);
                }
                else static if (info.type == ComponentInfo.ComponentType.Float)
                {
                    static assert(NumBits >= 6, "Needs at least 6 bits for a float!");

                    // TODO: investigate a better way to select signed-ness in the format spec, maybe 'sf10', or 's10e5'?
                    enum bool Signed = NumBits >= 16;

                    // TODO: investigate a way to specify exponent bits in the format spec, maybe 'f10e3'?
                    enum Exponent = 5;
                    enum ExpBias = ExpBias!Exponent;
                    enum Mantissa = NumBits - Exponent - (Signed ? 1 : 0);

                    mixin("float f = cast(float)color." ~ components[i] ~ ";");
                    uint u = *cast(uint*)&f;

                    int exponent = ((u >> 23) & 0xFF) - 127 + ExpBias;
                    uint mantissa = (u >> (23 - Mantissa)) & BitsUMax!Mantissa;
                    if (exponent < 0)
                    {
                        exponent = 0;
                        mantissa = 0;
                    }
                    uint bits = (Signed && (u & SignBit!32) ? SignBit!NumBits : 0) | (exponent << Mantissa) | mantissa;
                }
                else static if (info.type == ComponentInfo.ComponentType.Mantissa)
                {
                    // TODO: we could easily support signed values here...

                    uint denom_u = cast(uint)(127 + sexp - ExpBias - NumBits) << 23;
                    float denom = *cast(float*)&denom_u;

                    mixin("float c = clamp(cast(float)color." ~ To.components[i] ~ ", 0.0f, MaxVal);");
                    uint bits = cast(uint)cast(int)(c / denom + 0.5f);
                    assert(bits <= BitsUMax!NumBits);
                }

                res.data.bits!(cast(size_t)info.offset, NumBits) = bits;
            }
        }
        return res;
    }

private:
    enum AllInfos = ParseFormat!format_;
}


private:

// lots of logic to parse the format string
template GetComponents(string format)
{
    string get(string s)
    {
        foreach (i; 0..s.length)
        {
            if (s[i] == '_')
                return s[0..i];
        }
        assert(false);
    }
    enum string GetComponents = get(format);
}

template GetComponentInfos(ComponentInfo[] infos)
{
    template Impl(ComponentInfo[] infos, size_t i)
    {
        static if (i == infos.length)
            enum Impl = infos;
        else static if (infos[i].type == ComponentInfo.ComponentType.Exponent)
            enum Impl = infos[0..i] ~ infos[i+1..$];
        else
            enum Impl = Impl!(infos, i+1);
    }
    enum GetComponentInfos = Impl!(infos, 0);
}

template GetSharedExponent(ComponentInfo[] infos)
{
    template Impl(ComponentInfo[] infos, size_t i)
    {
        static if (i == infos.length)
            enum Impl = ComponentInfo(0, 0, ComponentInfo.ComponentType.Unsigned);
        else static if (infos[i].type == ComponentInfo.ComponentType.Exponent)
            enum Impl = infos[i];
        else
            enum Impl = Impl!(infos, i+1);
    }
    enum GetSharedExponent = Impl!(infos, 0);
}

template ParseFormat(string format)
{
    // parse the format string into component infos
    ComponentInfo[] impl(string s) pure nothrow @safe
    {
        static int parseInt(ref string str) pure nothrow @nogc @safe
        {
            int n = 0;
            while (str.length && str[0] >= '0' && str[0] <= '9')
            {
                n = n*10 + (str[0] - '0');
                str = str[1..$];
            }
            return n;
        }

        while (s.length && s[0] != '_')
            s = s[1..$];

        ComponentInfo[] infos;

        int offset = 0;
        bool hasSharedExp = false;
        while (s.length && s[0] == '_')
        {
            s = s[1..$];
            assert(s.length);

            char c = 0;
            if (!(s[0] >= '0' && s[0] <= '9'))
            {
                c = s[0];
                s = s[1..$];
            }

            int i = parseInt(s);
            assert(i > 0);

            infos ~= ComponentInfo(cast(ubyte)offset, cast(ubyte)i, ComponentInfo.ComponentType.Unsigned);

            if (c)
            {
                if (c == 'e' && !hasSharedExp)
                {
                    infos[$-1].type = ComponentInfo.ComponentType.Exponent;
                    hasSharedExp = true;
                }
                else if (c == 'f')
                    infos[$-1].type = ComponentInfo.ComponentType.Float;
                else if (c == 's')
                    infos[$-1].type = ComponentInfo.ComponentType.Signed;
                else if (c == 'u')
                    infos[$-1].type = ComponentInfo.ComponentType.Unsigned;
                else
                    assert(false);
            }

            offset += i;
        }
        assert(s.length == 0);

        if (hasSharedExp)
        {
            foreach (ref c; infos)
            {
                assert(c.type != ComponentInfo.ComponentType.Float && c.type != ComponentInfo.ComponentType.Signed);
                if (c.type != ComponentInfo.ComponentType.Exponent)
                    c.type = ComponentInfo.ComponentType.Mantissa;
            }
        }

        return infos;
    }
    enum ParseFormat = impl(format);
}

template Iota(alias start, alias end)
{
    static if (end == start)
        alias Iota = TypeTuple!();
    else
        alias Iota = TypeTuple!(Iota!(start, end-1), end-1);
}

int numBits(ComponentInfo[] infos) pure nothrow @nogc @safe
{
    int bits;
    foreach (i; infos)
        bits += i.bits;
    int slop = bits % 8;
    if (slop)
        bits += 8 - slop;
    return bits;
}

enum ExpBias(size_t n) = (1 << (n-1)) - 1;
