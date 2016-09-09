// Written in the D programming language.

/**
    This module implements HSV, HSL, HSI, HCY, HWB, HCG _color types.

    Authors:    Manu Evans
    Copyright:  Copyright (c) 2015, Manu Evans.
    License:    $(WEB boost.org/LICENSE_1_0.txt, Boost License 1.0)
    Source:     $(PHOBOSSRC std/experimental/color/_hsx.d)
*/
module std.experimental.color.hsx;

import std.experimental.color;
import std.experimental.color.rgb;
import std.experimental.color.colorspace : RGBColorSpace, RGBColorSpaceDesc, rgbColorSpaceDef;
import std.experimental.normint;

import std.traits : isInstanceOf, isFloatingPoint, isUnsigned, Unqual;
import std.typetuple : TypeTuple;
import std.math : PI;

@safe pure nothrow @nogc:

/**
Detect whether $(D_INLINECODE T) is a member of the HSx color family.
*/
enum isHSx(T) = isInstanceOf!(HSx, T);

///
unittest
{
    static assert(isHSx!(HSV!ushort) == true);
    static assert(isHSx!RGB8 == false);
    static assert(isHSx!string == false);
}

/**
Alias for a HSV (HSB) color.
*/
alias HSV(CT = float, RGBColorSpace cs = RGBColorSpace.sRGB) = HSx!(HSxType.HSV, CT, cs);

/**
Alias for a HSL color.
*/
alias HSL(CT = float, RGBColorSpace cs = RGBColorSpace.sRGB) = HSx!(HSxType.HSL, CT, cs);

/**
Alias for a HSI color.
*/
alias HSI(CT = float, RGBColorSpace cs = RGBColorSpace.sRGB) = HSx!(HSxType.HSI, CT, cs);

/**
Alias for a HCY' color.
*/
alias HCY(CT = float, RGBColorSpace cs = RGBColorSpace.sRGB) = HSx!(HSxType.HCY, CT, cs);

/**
Alias for a HWB color.
*/
alias HWB(CT = float, RGBColorSpace cs = RGBColorSpace.sRGB) = HSx!(HSxType.HWB, CT, cs);

/**
Alias for a HCG color.
*/
alias HCG(CT = float, RGBColorSpace cs = RGBColorSpace.sRGB) = HSx!(HSxType.HCG, CT, cs);

/**
Define a HSx family color type.
*/
enum HSxType
{
    /** Hue-saturation-value (aka HSB: Hue-saturation-brightness) */
    HSV,
    /** Hue-saturation-lightness */
    HSL,
    /** Hue-saturation-intensity */
    HSI,
    /** Hue-chroma-luma */
    HCY,
    /** Hue-white-black */
    HWB,
    /** Hue-chroma-grey */
    HCG
}

/**
HSx color space is used to describe a suite of angular color spaces including HSL, HSV, HSI, HCY.

Params: type_ = A type from the HSxType enum.
        ComponentType_ = Type for the color channels. May be unsigned integer or floating point type.
        colorSpace_ = Color will be within the specified RGB color space.
*/
struct HSx(HSxType type_, ComponentType_ = float, RGBColorSpace colorSpace_ = RGBColorSpace.sRGB) if (isFloatingPoint!ComponentType_ || isUnsigned!ComponentType_)
{
@safe pure nothrow @nogc:

    static if (isFloatingPoint!ComponentType_)
    {
        /** Type of the hue components. */
        alias HueType = ComponentType_;
        /** Type of the s and x components. */
        alias ComponentType = ComponentType_;
    }
    else
    {
        /** Type of the hue components. */
        alias HueType = ComponentType_;
        /** Type of the s and x components. */
        alias ComponentType = NormalizedInt!ComponentType_;
    }

    /** The parent RGB color space. */
    enum colorSpace = colorSpace_;
    /** The parent RGB color space descriptor. */
    enum RGBColorSpaceDesc!F colorSpaceDesc(F = double) = rgbColorSpaceDef!F(colorSpace_);
    /** The color type from the HSx family. */
    enum type = type_;

    // mixin the color channels according to the type
    mixin("HueType " ~ Components!type[0] ~ " = 0;");
    mixin("ComponentType " ~ Components!type[1] ~ " = 0;");
    mixin("ComponentType " ~ Components!type[2] ~ " = 0;");

    /** Get hue angle in degrees. */
    @property double degrees() const
    {
        static if (!isFloatingPoint!ComponentType_)
            return h * (360/(ComponentType_.max + 1.0));
        else
            return (h < 0 ? 1 - h%1 : h%1) * 360;
    }
    /** Set hue angle in degrees. */
    @property void degrees(double angle)
    {
        static if (!isFloatingPoint!ComponentType_)
            h = cast(ComponentType_)(angle * ((ComponentType_.max + 1.0)/360));
        else
            h = angle * 1.0/360;
    }

    /** Get hue angle in radians. */
    @property double radians() const
    {
        static if (!isFloatingPoint!ComponentType_)
            return h * ((PI*2)/(ComponentType_.max + 1.0));
        else
            return (h < 0 ? 1 - h%1 : h%1) * (PI*2);
    }
    /** Set hue angle in radians. */
    @property void radians(double angle)
    {
        static if (!isFloatingPoint!ComponentType_)
            h = cast(ComponentType_)(angle * ((ComponentType_.max + 1.0)/(PI*2)));
        else
            h = angle * 1.0/(PI*2);
    }

    /** Construct a color from hsx components. */
    this(HueType h, ComponentType s, ComponentType x)
    {
        mixin("this." ~ Components!type[0] ~ " = h;");
        mixin("this." ~ Components!type[1] ~ " = s;");
        mixin("this." ~ Components!type[2] ~ " = x;");
    }

    static if (!isFloatingPoint!ComponentType_)
    {
        /** Construct a color from hsx components. */
        this(HueType h, ComponentType.IntType s, ComponentType.IntType x)
        {
            mixin("this." ~ Components!type[0] ~ " = h;");
            mixin("this." ~ Components!type[1] ~ " = ComponentType(s);");
            mixin("this." ~ Components!type[2] ~ " = ComponentType(x);");
        }
    }

    /** Cast to other color types */
    Color opCast(Color)() const if (isColor!Color)
    {
        return convertColor!Color(this);
    }


package:

    alias ParentColor = RGB!("rgb", ComponentType_, false, colorSpace_);

    static To convertColorImpl(To, From)(From color) if (isHSx!From && isHSx!To)
    {
        // HACK: cast through RGB (this works fine, but could be faster)
        return convertColorImpl!(To)(convertColorImpl!(From.ParentColor)(color));
    }
    unittest
    {
        static assert(convertColorImpl!(HSL!float)(HSV!float(1.0/6, 1, 1)) == HSL!float(1.0/6, 1, 0.5));

        static assert(convertColorImpl!(HSV!float)(HSL!float(1.0/6, 1, 0.5)) == HSV!float(1.0/6, 1, 1));

        static assert(convertColorImpl!(HSI!float)(HSV!float(0, 1, 1)) == HSI!float(0, 1, 1.0/3));
        static assert(convertColorImpl!(HSI!float)(HSV!float(1.0/6, 1, 1)) == HSI!float(1.0/6, 1, 2.0/3));

        // TODO: HCY (needs approx ==)
    }

    static To convertColorImpl(To, From)(From color) if (isHSx!From && isRGB!To)
    {
        import std.math : abs;

        alias ToType = To.ComponentType;
        alias WT = FloatTypeFor!ToType;

        auto c = color.tupleof;
        WT h = cast(WT)color.degrees;
        WT s = cast(WT)c[1];
        WT x = cast(WT)c[2];

        static if (isFloatingPoint!ComponentType_)
        {
            // clamp s and x
            import std.algorithm.comparison : clamp;
            s = clamp(s, 0, 1);
            x = clamp(x, 0, 1);
        }

        WT C, m;
        static if (From.type == HSxType.HSV)
        {
            C = x*s;
            m = x - C;
        }
        else static if (From.type == HSxType.HSL)
        {
            C = (1 - abs(2*x - 1))*s;
            m = x - C/2;
        }
        else static if (From.type == HSxType.HSI)
        {
            C = s;
        }
        else static if (From.type == HSxType.HCY)
        {
            C = s;
        }
        else static if (From.type == HSxType.HWB)
        {
            WT t = s + x;
            if (t > 1)
            {
                // normalise W/B
                s /= t;
                x /= t;
            }
            s = x == 1 ? 0 : 1 - (s / (1 - x)); // saturation
            x = 1 - x; // 'value'

            C = x*s;
            m = x - C;
        }
        else static if (From.type == HSxType.HCG)
        {
            C = s;
            m = x * (1 - C);
        }

        WT H = h/60;
        WT X = C*(1 - abs(H%2.0 - 1));

        WT r, g, b;
        if (H < 1)
            r = C, g = X, b = 0;
        else if (H < 2)
            r = X, g = C, b = 0;
        else if (H < 3)
            r = 0, g = C, b = X;
        else if (H < 4)
            r = 0, g = X, b = C;
        else if (H < 5)
            r = X, g = 0, b = C;
        else if (H < 6)
            r = C, g = 0, b = X;

        static if (From.type == HSxType.HSI)
        {
            m = x - (r+g+b)*WT(1.0/3.0);
        }
        else static if (From.type == HSxType.HCY)
        {
            m = x - toGrayscale!(false, colorSpace_, WT)(r, g, b); // Derive from Luma'
        }

        return To(cast(ToType)(r+m), cast(ToType)(g+m), cast(ToType)(b+m));
    }
    unittest
    {
        static assert(convertColorImpl!(RGB8)(HSV!float(0, 1, 1)) == RGB8(255, 0, 0));
        static assert(convertColorImpl!(RGB8)(HSV!float(1.0/6, 0.5, 0.5)) == RGB8(128, 128, 64));

        static assert(convertColorImpl!(RGB8)(HSL!float(0, 1, 0.5)) == RGB8(255, 0, 0));
        static assert(convertColorImpl!(RGB8)(HSL!float(1.0/6, 0.5, 0.5)) == RGB8(191, 191, 64));
    }

    static To convertColorImpl(To, From)(From color) if (isRGB!From && isHSx!To)
    {
        import std.algorithm : min, max, clamp;
        import std.math : abs;

        alias ToType = To.ComponentType;
        alias WT = FloatTypeFor!ToType;

        auto c = color.tristimulus;
        WT r = cast(WT)c[0];
        WT g = cast(WT)c[1];
        WT b = cast(WT)c[2];

        static if (isFloatingPoint!ComponentType_)
        {
            // clamp r, g, b
            r = clamp(r, 0, 1);
            g = clamp(g, 0, 1);
            b = clamp(b, 0, 1);
        }

        WT M = max(r, g, b);
        WT m = min(r, g, b);
        WT C = M-m;

        // Calculate Hue
        WT h;
        if (C == 0)
            h = 0;
        else if (M == r)
            h = WT(1.0/6) * ((g-b)/C % WT(6));
        else if (M == g)
            h = WT(1.0/6) * ((b-r)/C + WT(2));
        else if (M == b)
            h = WT(1.0/6) * ((r-g)/C + WT(4));

        WT s, x;
        static if (To.type == HSxType.HSV)
        {
            x = M; // 'Value'
            s = x == 0 ? WT(0) : C/x; // Saturation
        }
        else static if (To.type == HSxType.HSL)
        {
            x = (M + m)/WT(2); // Lightness
            s = (x == 0 || x == 1) ? WT(0) : C/(1 - abs(2*x - 1)); // Saturation
        }
        else static if (To.type == HSxType.HSI)
        {
            x = (r + g + b)/WT(3); // Intensity
            s = x == 0 ? WT(0) : 1 - m/x; // Saturation
        }
        else static if (To.type == HSxType.HCY)
        {
            x = toGrayscale!(false, colorSpace_, WT)(r, g, b); // Calculate Luma' using the proper coefficients
            s = C; // Chroma
        }
        else static if (To.type == HSxType.HWB)
        {
            s = M == 0 ? WT(0) : C/M; // Saturation
            s = (1 - s)*M;            // White
            x = 1 - M;                // Black
        }
        else static if (To.type == HSxType.HCG)
        {
            s = C;
            x = m / (1 - C);
        }

        static if (!isFloatingPoint!ToType)
            h = h * WT(ToType.max + 1.0);

        return To(cast(ToType)h, cast(ToType)s, cast(ToType)x);
    }
    unittest
    {
        static assert(convertColorImpl!(HSV!float)(RGB8(255, 0, 0)) == HSV!float(0, 1, 1));
        static assert(convertColorImpl!(HSL!float)(RGB8(255, 0, 0)) == HSL!float(0, 1, 0.5));
        static assert(convertColorImpl!(HSI!float)(RGB8(255, 0, 0)) == HSI!float(0, 1, 1.0/3));
        static assert(convertColorImpl!(HSI!float)(RGB8(255, 255, 0)) == HSI!float(1.0/6, 1, 2.0/3));
//        static assert(convertColorImpl!(HCY!float)(RGB8(255, 0, 0)) == HCY!float(0, 1, 1));
    }

private:
    template Components(HSxType type)
    {
        static if (type == HSxType.HSV)
            alias Components = TypeTuple!("h","s","v");
        else static if (type == HSxType.HSL)
            alias Components = TypeTuple!("h","s","l");
        else static if (type == HSxType.HSI)
            alias Components = TypeTuple!("h","s","i");
        else static if (type == HSxType.HCY)
            alias Components = TypeTuple!("h","c","y");
        else static if (type == HSxType.HWB)
            alias Components = TypeTuple!("h","w","b");
        else static if (type == HSxType.HCG)
            alias Components = TypeTuple!("h","c","g");
    }
    alias AllComponents = Components!type_;
}

///
unittest
{
    // HSV color with float components
    alias HSVf = HSV!float;

    HSVf c = HSVf(3.1415, 1, 0.5);

    // test HSV operators and functions
}
///
unittest
{
    // HSL color with float components
    alias HSLf = HSL!float;

    HSLf c = HSLf(3.1415, 1, 0.5);

    // test HSL operators and functions
}
///
unittest
{
    // HSI color with float components
    alias HSIf = HSI!float;

    HSIf c = HSIf(3.1415, 1, 0.5);

    // test HSI operators and functions
}
///
unittest
{
    // HCY color with float components
    alias HCYf = HCY!float;

    HCYf c = HCYf(3.1415, 1, 0.5);

    // test HCY operators and functions
}
