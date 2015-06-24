// Written in the D programming language.

/**
    This module implements various _color type conversions.

    Authors:    Manu Evans
    Copyright:  Copyright (c) 2015, Manu Evans.
    License:    $(WEB boost.org/LICENSE_1_0.txt, Boost License 1.0)
    Source:     $(PHOBOSSRC std/experimental/color/conv.d)
*/
module std.experimental.color.conv;

import std.experimental.color;
import std.experimental.color.rgb;
import std.experimental.color.xyz;

import std.traits : isNumeric, isIntegral, isFloatingPoint, isSigned, isSomeChar, TemplateOf;
import std.typetuple : TypeTuple;


/**
Convert between color types.
*/
To convertColor(To, From)(From color) if(isColor!To && isColor!From)
{
    // no conversion is necessary
    static if(is(To == From))
        return color;

    // *** XYZ is the root type ***
    else static if(isXYZ!From && isXYZ!To)
    {
        alias F = To.ComponentType;
        return To(F(color.X), F(color.Y), F(color.Z));
    }

    // following conversions come in triplets:
    //   Type!U -> Type!V
    //   Type -> Parent
    //   Parent -> type

    // *** RGB triplet ***
    else static if(isRGB!From && isRGB!To)
    {
        alias ToType = To.ComponentType;
        alias FromType = From.ComponentType;

        auto src = color.tristimulusWithAlpha;

        static if(false && From.colorSpace == To.colorSpace && isIntegral!FromType && FromType.sizeof <= 2 &&
                    (From.linear != To.linear || !is(FromType == ToType)))
        {
            alias WorkType = WorkingType!(FromType, ToType);
            enum NumValues = 1 << (FromType.sizeof*8);

            // <= 16bit type conversion should use a look-up table
            shared immutable ToType[NumValues] conversionTable = {
                ToType[NumValues] table = void;
                foreach(i; 0..NumValues)
                {
                    WorkType v = convertPixelType!WorkType(cast(FromType)i);
                    static if(From.linear == false)
                        v = toLinear!(From.colorSpace)(v);
                    static if(To.linear == false)
                        v = toGamma!(To.colorSpace)(v);
                    table[i] = convertPixelType!ToType(v);
                }
                return table;
            }();

            static if(To.hasAlpha)
                return To(conversionTable[src[0]], conversionTable[src[0]], conversionTable[src[1]], conversionTable[src[2]], convertPixelType!ToType(src[3]));
            else
                return To(conversionTable[src[0]], conversionTable[src[0]], conversionTable[src[1]], conversionTable[src[2]]);
        }
        else static if(From.colorSpace == To.colorSpace && From.linear == To.linear)
        {
            // color space is the same, just do type conversion
            return To(convertPixelType!ToType(src[0]), convertPixelType!ToType(src[1]), convertPixelType!ToType(src[2]), convertPixelType!ToType(src[3]));
        }
        else
        {
            // unpack the working values
            alias WorkType = WorkingType!(FromType, ToType);
            WorkType r = convertPixelType!WorkType(src[0]);
            WorkType g = convertPixelType!WorkType(src[1]);
            WorkType b = convertPixelType!WorkType(src[2]);

            static if(From.linear == false)
            {
                r = toLinear!(From.colorSpace)(r);
                g = toLinear!(From.colorSpace)(g);
                b = toLinear!(From.colorSpace)(b);
            }
            static if(From.colorSpace != To.colorSpace)
            {
                enum toXYZ = RGBColorSpaceMatrix!(From.colorSpace, WorkType);
                enum toRGB = inverse(RGBColorSpaceMatrix!(To.colorSpace, WorkType));
                enum mat = multiply(toXYZ, toRGB);
                WorkType[3] v = multiply(mat, [r, g, b]);
                r = v[0]; g = v[1]; b = v[2];
            }
            static if(To.linear == false)
            {
                r = toGamma!(To.colorSpace)(r);
                g = toGamma!(To.colorSpace)(g);
                b = toGamma!(To.colorSpace)(b);
            }

            // convert and return the output
            static if(To.hasAlpha)
                return To(convertPixelType!ToType(r), convertPixelType!ToType(g), convertPixelType!ToType(b), convertPixelType!ToType(src[3]));
            else
                return To(convertPixelType!ToType(r), convertPixelType!ToType(g), convertPixelType!ToType(b));
        }
    }
    else static if(isRGB!From && isXYZ!To)
    {
        alias ToType = To.ComponentType;
        alias FromType = From.ComponentType;
        alias WorkType = WorkingType!(FromType, ToType);

        // unpack the working values
        auto src = color.tristimulus;
        WorkType r = convertPixelType!WorkType(src[0]);
        WorkType g = convertPixelType!WorkType(src[1]);
        WorkType b = convertPixelType!WorkType(src[2]);

        static if(From.linear == false)
        {
            r = toLinear!(From.colorSpace)(r);
            g = toLinear!(From.colorSpace)(g);
            b = toLinear!(From.colorSpace)(b);
        }

        // transform to XYZ
        enum toXYZ = RGBColorSpaceMatrix!(From.colorSpace, WorkType);
        WorkType[3] v = multiply(toXYZ, [r, g, b]);
        return To(v[0], v[1], v[2]);
    }
    else static if(isXYZ!From && isRGB!To)
    {
        alias ToType = To.ComponentType;
        alias FromType = From.ComponentType;
        alias WorkType = WorkingType!(FromType, ToType);

        enum toRGB = inverse(RGBColorSpaceMatrix!(To.colorSpace, WorkType));
        WorkType[3] v = multiply(toRGB, [ WorkType(color.X), WorkType(color.Y), WorkType(color.Z) ]);

        static if(To.linear == false)
        {
            v[0] = toGamma!(To.colorSpace)(v[0]);
            v[1] = toGamma!(To.colorSpace)(v[1]);
            v[2] = toGamma!(To.colorSpace)(v[2]);
        }

        return To(convertPixelType!ToType(v[0]), convertPixelType!ToType(v[1]), convertPixelType!ToType(v[2]));
    }

    // *** xyY triplet ***
    else static if(isxyY!From && isxyY!To)
    {
        alias F = To.ComponentType;
        return To(F(color.x), F(color.y), F(color.Y));
    }
    else static if(isxyY!From && isXYZ!To)
    {
        alias F = To.ComponentType;
        if(color.y == F(0))
            return To(F(0), F(0), F(0));
        else
            return To(F(color.x*color.Y/color.y), F(color.Y), F((F(1)-color.x-color.y)*color.Y/color.y));
    }
    else static if(isXYZ!From && isxyY!To)
    {
        alias F = To.ComponentType;
        auto sum = color.X + color.Y + color.Z;
        if(sum == F(0))
            return To(WhitePoint!F.D65.x, WhitePoint!F.D65.y, F(0));
        else
            return To(F(color.X/sum), F(color.Y/sum), F(color.Y));
    }

    // *** fallback plan ***
    else
    {
        // cast along a conversion path to reach our target conversion
        alias Path = ConversionPath!(From, To);
        return convertColor!To(convertColor!(Path[0])(color));
    }
}

unittest
{
    import std.experimental.color.xyz;

    // test format conversions
    alias UnsignedRGB = RGB!("rgb", ubyte);
    alias SignedRGBX = RGB!("rgbx", byte);
    alias FloatRGBA = RGB!("rgba", float);

    static assert(cast(UnsignedRGB)SignedRGBX(0x20,0x30,-10)               == UnsignedRGB(0x40,0x60,0));
    static assert(cast(UnsignedRGB)FloatRGBA(1,0.5,0,1)                    == UnsignedRGB(0xFF,0x80,0));
    static assert(cast(UnsignedRGB)cast(FloatRGBA)UnsignedRGB(0xFF,0x80,0) == UnsignedRGB(0xFF,0x80,0));
    static assert(cast(FloatRGBA)UnsignedRGB(0xFF,0x80,0)                  == FloatRGBA(1,float(0x80)/float(0xFF),0,0));
    static assert(cast(FloatRGBA)SignedRGBX(127,-127,-128)                 == FloatRGBA(1,-1,-1,0));

    // test greyscale conversion
    alias UnsignedL = RGB!("l", ubyte);
    assert(cast(UnsignedL)UnsignedRGB(0xFF,0x20,0x40)   == UnsignedL(0x83));

    // alias a bunch of types for testing
    alias sRGBA = RGB!("rgba", ubyte, false, RGBColorSpace.sRGB);
    alias lRGBA = RGB!("rgba", ushort, true, RGBColorSpace.sRGB);
    alias gRGBA = RGB!("rgba", byte, false, RGBColorSpace.sRGB_Gamma2_2);
    alias sRGBAf = RGB!("rgba", float, false, RGBColorSpace.sRGB);
    alias lRGBAf = RGB!("rgba", double, true, RGBColorSpace.sRGB);
    alias gRGBAf = RGB!("rgba", float, false, RGBColorSpace.sRGB_Gamma2_2);
    alias XYZf = XYZ!float;

    // TODO... we can't test this properly since DMD can't CTFE the '^^' operator! >_<

    // test RGB conversions
    assert(cast(lRGBA)sRGBA(0xFF, 0xFF, 0xFF, 0xFF)           == lRGBA(0xFFFF, 0xFFFF, 0xFFFF, 0xFFFF));
    assert(cast(gRGBA)sRGBA(0xFF, 0x80, 0x01, 0xFF)           == gRGBA(0x7F, 0x3F, 0x03, 0x7F));
    assert(cast(sRGBA)cast(XYZf)sRGBA(0xFF, 0xFF, 0xFF, 0xFF) == sRGBA(0xFF, 0xFF, 0xFF, 0));
    //...

    // test PackedRGB conversions
    //...

    // test xyY conversions
    //...
}


/**
* Create a color from hex strings in the standard forms: (#/$/0x)rgb/argb/rrggbb/aarrggbb
*/
Color colorFromString(Color = RGB8, C)(const(C)[] hex) if(isSomeChar!C)
{
    static ubyte val(C c)
    {
        if(c >= '0' && c <= '9')
            return cast(ubyte)(c - '0');
        else if(c >= 'a' && c <= 'f')
            return cast(ubyte)(c - 'a' + 10);
        else if(c >= 'A' && c <= 'F')
            return cast(ubyte)(c - 'A' + 10);
        else
            assert(false, "Invalid hex string");
    }

    if(hex.length > 0 && (hex[0] == '#' || hex[0] == '$'))
        hex = hex[1..$];
    else if(hex.length > 1 && (hex[0] == '0' && hex[1] == 'x'))
        hex = hex[2..$];

    if(hex.length == 3)
    {
        ubyte r = val(hex[0]);
        ubyte g = val(hex[1]);
        ubyte b = val(hex[2]);
        return cast(Color)RGB8(cast(ubyte)(r | (r << 4)), cast(ubyte)(g | (g << 4)), cast(ubyte)(b | (b << 4)));
    }
    if(hex.length == 4)
    {
        ubyte a = val(hex[0]);
        ubyte r = val(hex[1]);
        ubyte g = val(hex[2]);
        ubyte b = val(hex[3]);
        return cast(Color)RGBA8(cast(ubyte)(r | (r << 4)), cast(ubyte)(g | (g << 4)), cast(ubyte)(b | (b << 4)), cast(ubyte)(a | (a << 4)));
    }
    if(hex.length == 6)
    {
        ubyte r = cast(ubyte)(val(hex[0]) << 4) | val(hex[1]);
        ubyte g = cast(ubyte)(val(hex[2]) << 4) | val(hex[3]);
        ubyte b = cast(ubyte)(val(hex[4]) << 4) | val(hex[5]);
        return cast(Color)RGB8(r, g, b);
    }
    if(hex.length == 8)
    {
        ubyte a = cast(ubyte)(val(hex[0]) << 4) | val(hex[1]);
        ubyte r = cast(ubyte)(val(hex[2]) << 4) | val(hex[3]);
        ubyte g = cast(ubyte)(val(hex[4]) << 4) | val(hex[5]);
        ubyte b = cast(ubyte)(val(hex[6]) << 4) | val(hex[7]);
        return cast(Color)RGBA8(r, g, b, a);
    }
    else
    {
        // TODO: should we look up colors from the W3C color table by name?

        assert(false, "Invalid hex string!");
    }
}

unittest
{
    // 3 digits
    static assert(colorFromString("F80") == RGB8(0xFF,0x88, 0x00));
    static assert(colorFromString("#F80"w) == RGB8(0xFF,0x88, 0x00));
    static assert(colorFromString("$F80"d) == RGB8(0xFF,0x88, 0x00));
    static assert(colorFromString("0xF80") == RGB8(0xFF,0x88, 0x00));

    // 6 digits
    static assert(colorFromString("FF8000") == RGB8(0xFF,0x80, 0x00));
    static assert(colorFromString("#FF8000") == RGB8(0xFF,0x80, 0x00));
    static assert(colorFromString("$FF8000") == RGB8(0xFF,0x80, 0x00));
    static assert(colorFromString("0xFF8000") == RGB8(0xFF,0x80, 0x00));

    // 4/8 digita (/w alpha)
    static assert(colorFromString!RGBA8("#8C41") == RGBA8(0xCC,0x44, 0x11, 0x88));
    static assert(colorFromString!RGBA8("#80CC4401") == RGBA8(0xCC,0x44, 0x01, 0x80));
}


package:

// convert between pixel data types
To convertPixelType(To, From)(From v) if(isNumeric!From && isNumeric!To)
{
    static if(isIntegral!From && isIntegral!To)
    {
        // extending normalised integer types is not trivial
        return convertNormInt!To(v);
    }
    else static if(isIntegral!From && isFloatingPoint!To)
    {
        import std.algorithm: max;
        alias FP = FloatTypeFor!(From, To);
        static if(isSigned!From) // max(c, -1) is the signed conversion followed by D3D, OpenGL, etc.
            return To(max(v*FP(1.0/From.max), FP(-1.0)));
        else
            return To(v*FP(1.0/From.max));
    }
    else static if(isFloatingPoint!From && isIntegral!To)
    {
        alias FP = FloatTypeFor!(To, From);
        // HACK: this is incomplete!
        //       +0.5 rounding only works for positive numbers
        //       we also need to clamp (saturate) [To.min, To.max]
        return cast(To)(v*FP(To.max) + FP(0.5));
    }
    else
        return To(v);
}


// converts directly between fixed-point color types, without doing float conversions
// ** this should be tested for performance; we can optimise the small->large conversions with table lookups
To convertNormInt(To, From)(From i) if(isIntegral!To && isIntegral!From)
{
    import std.traits: isUnsigned, Unsigned;
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
        static if(Bits!To <= Bits!From)
            return cast(To)(i >> (Bits!From-Bits!To));
        else
        {
            enum Sig = Bits!From-1;
            enum Fill = Bits!To - Bits!From;

            To r = To(i) << Fill;

            enum numReps = Fill/Sig;
            foreach(j; Iota!(1, numReps+1))
                r |= Unsigned!To(cast(Unsigned!From)(i&From.max)) << (Fill - j*Sig);

            enum remain = Fill - numReps*Sig;
            static if(remain)
                r |= cast(Unsigned!From)(i&From.max) >> (Sig - remain);

            return r;
        }
    }
}

unittest
{
    // static asserts since these should all ctfe:

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
    static assert(convertNormInt!byte(short(0x3795)) == 0x37);
    static assert(convertNormInt!byte(short(-28672)) == -112);
    static assert(convertNormInt!short(byte(0x37)) == 0x376E);
    static assert(convertNormInt!short(byte(-109)) == -27866);
    static assert(convertNormInt!long(byte(-45)) == -3195498973398505005);
}


// try and use the preferred float type
// if the int type exceeds the preferred float precision, we'll upgrade the float
template FloatTypeFor(IntType, RequestedFloat = float)
{
    static if(IntType.sizeof > 2)
        alias FloatTypeFor = double;
    else
        alias FloatTypeFor = RequestedFloat;
}

// find the fastest type to do format conversion without losing precision
template WorkingType(From, To)
{
    static if(isIntegral!From && isIntegral!To)
    {
        // small integer types can use float and not lose precision
        static if(From.sizeof <= 2 && To.sizeof <= 2)
            alias WorkingType = float;
        else
            alias WorkingType = double;
    }
    else static if(isIntegral!From && isFloatingPoint!To)
        alias WorkingType = To;
    else static if(isFloatingPoint!From && isIntegral!To)
        alias WorkingType = FloatTypeFor!To;
    else
    {
        static if(From.sizeof > To.sizeof)
            alias WorkingType = From;
        else
            alias WorkingType = To;
    }
}

// find the conversion path from one distant type to another
template ConversionPath(From, To)
{
    template isParentType(Parent, Of)
    {
        static if(isXYZ!Of)
            enum isParentType = false;
        else static if(isInstanceOf!(TemplateOf!Parent, Of.ParentColor))
            enum isParentType = true;
        else
            enum isParentType = isParentType!(Parent, Of.ParentColor);
    }

    template FindPath(From, To)
    {
        static if(isInstanceOf!(TemplateOf!To, From))
            alias FindPath = TypeTuple!(To);
        else static if(isParentType!(From, To))
            alias FindPath = TypeTuple!(FindPath!(From, To.ParentColor), To);
        else
            alias FindPath = TypeTuple!(From, FindPath!(From.ParentColor, To));
    }

    alias Path = FindPath!(From, To);
    static if(Path.length == 1 && !is(Path[0] == From))
        alias ConversionPath = Path;
    else
        alias ConversionPath = Path[1..$];
}
