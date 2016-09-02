// Written in the D programming language.

/**
This module defines and operates on standard color spaces.

Authors:    Manu Evans
Copyright:  Copyright (c) 2016, Manu Evans.
License:    $(WEB boost.org/LICENSE_1_0.txt, Boost License 1.0)
Source:     $(PHOBOSSRC std/experimental/color/colorspace.d)
*/
module std.experimental.color.colorspace;

import std.experimental.color.xyz;

import std.traits : isFloatingPoint;

@safe pure nothrow @nogc:


/** White points of standard illuminants. */
template WhitePoint(F) if(isFloatingPoint!F)
{
    /** */
    enum WhitePoint
    {
        /** Incandescent / Tungsten */
        A =   xyY!F(0.44757, 0.40745, 1.00000),
        /** [obsolete] Direct sunlight at noon */
        B =   xyY!F(0.34842, 0.35161, 1.00000),
        /** [obsolete] Average / North sky Daylight */
        C =   xyY!F(0.31006, 0.31616, 1.00000),
        /** Horizon Light, ICC profile PCS (Profile connection space) */
        D50 = xyY!F(0.34567, 0.35850, 1.00000),
        /** Mid-morning / Mid-afternoon Daylight */
        D55 = xyY!F(0.33242, 0.34743, 1.00000),
        /** Noon Daylight: Television, sRGB color space */
        D65 = xyY!F(0.31271, 0.32902, 1.00000),
        /** North sky Daylight */
        D75 = xyY!F(0.29902, 0.31485, 1.00000),
        /** Equal energy */
        E =   xyY!F(1.0/3.0, 1.0/3.0, 1.00000),
        /** Daylight Fluorescent */
        F1 =  xyY!F(0.31310, 0.33727, 1.00000),
        /** Cool White Fluorescent */
        F2 =  xyY!F(0.37208, 0.37529, 1.00000),
        /** White Fluorescent */
        F3 =  xyY!F(0.40910, 0.39430, 1.00000),
        /** Warm White Fluorescent */
        F4 =  xyY!F(0.44018, 0.40329, 1.00000),
        /** Daylight Fluorescent */
        F5 =  xyY!F(0.31379, 0.34531, 1.00000),
        /** Lite White Fluorescent */
        F6 =  xyY!F(0.37790, 0.38835, 1.00000),
        /** D65 simulator, Daylight simulator */
        F7 =  xyY!F(0.31292, 0.32933, 1.00000),
        /** D50 simulator, Sylvania F40 Design 50 */
        F8 =  xyY!F(0.34588, 0.35875, 1.00000),
        /** Cool White Deluxe Fluorescent */
        F9 =  xyY!F(0.37417, 0.37281, 1.00000),
        /** Philips TL85, Ultralume 50 */
        F10 = xyY!F(0.34609, 0.35986, 1.00000),
        /** Philips TL84, Ultralume 40 */
        F11 = xyY!F(0.38052, 0.37713, 1.00000),
        /** Philips TL83, Ultralume 30 */
        F12 = xyY!F(0.43695, 0.40441, 1.00000)
    }
}


/**
Enum of RGB color spaces.
*/
enum RGBColorSpace
{
    /** sRGB, HDTV (ITU-R BT.709) */
    sRGB,
    /** sRGB approximation using gamma 2.2 */
    sRGB_Gamma2_2,

    // custom color space will disable automatic color space conversions
    custom = -1
}


/**
Parameters that define an RGB color space.
*/
struct RGBColorSpaceDesc(F)
{
    /** Gamma conversion function type. */
    alias GammaFunc = F function(F v) pure nothrow @nogc @safe;

    /** Color space name. */
    string name;

    /** Function that converts a linear luminance to gamme space. */
    GammaFunc toGamma;
    /** Function that converts a gamma luminance to linear space. */
    GammaFunc toLinear;

    /** White point. */
    xyY!F white;
    /** Red point. */
    xyY!F red;
    /** Green point. */
    xyY!F green;
    /** Blue point. */
    xyY!F blue;
}

/**
Color space descriptor for the specified color space.
*/
template RGBColorSpaceDef(RGBColorSpace colorSpace, F = double) if(isFloatingPoint!F)
{
    enum RGBColorSpaceDef = RGBColorSpaceDefs!F[colorSpace];
}

/**
Color space transform matrix.
*/
template RGBColorSpaceMatrix(RGBColorSpace cs, F = double) if(isFloatingPoint!F)
{
    enum F[3] ToXYZ(xyY!F c) = [ c.x/c.y, F(1), (F(1)-c.x-c.y)/c.y ];

    // get the color space definition
    enum def = RGBColorSpaceDefs!F[cs];
    // build a matrix from the 3 color vectors
    enum r = def.red, g = def.green, b = def.blue;
    enum m = transpose([ ToXYZ!r, ToXYZ!g, ToXYZ!b ]);

    // multiply by the whitepoint
    enum w = [ (cast(XYZ!F)def.white).tupleof ];
    enum s = multiply(inverse(m), w);

    // return colorspace matrix (RGB -> XYZ)
    enum F[3][3] RGBColorSpaceMatrix = [[ m[0][0]*s[0], m[0][1]*s[1], m[0][2]*s[2] ],
                                        [ m[1][0]*s[0], m[1][1]*s[1], m[1][2]*s[2] ],
                                        [ m[2][0]*s[0], m[2][1]*s[1], m[2][2]*s[2] ]];
}

/** Linear to sRGB ramp function. */
T linearTosRGB(T)(T s) if(isFloatingPoint!T)
{
    if(s <= T(0.0031308))
        return T(12.92) * s;
    else
        return T(1.055) * s^^T(1.0/2.4) - T(0.055);
}

/** sRGB to linear function. */
T sRGBToLinear(T)(T s) if(isFloatingPoint!T)
{
    if(s <= T(0.04045))
        return s / T(12.92);
    else
        return ((s + T(0.055)) / T(1.055))^^T(2.4);
}

/** Linear to gamma space function. */
T linearToGamma(double gamma, T)(T v) if(isFloatingPoint!T)
{
    return v^^T(1.0/gamma);
}
/** Linear to gamma space function. */
T linearToGamma(T)(T v, T gamma) if(isFloatingPoint!T)
{
    return v^^T(1.0/gamma);
}

/** Gamma to linear function. */
T gammaToLinear(double gamma, T)(T v) if(isFloatingPoint!T)
{
    return v^^T(gamma);
}
/** Gamma to linear function. */
T gammaToLinear(T)(T v, T gamma) if(isFloatingPoint!T)
{
    return v^^T(gamma);
}


package:

enum RGBColorSpaceDefs(F) = [
    RGBColorSpaceDesc!F("sRGB",           &linearTosRGB!F,         &sRGBToLinear!F,         WhitePoint!F.D65, xyY!F(0.6400, 0.3300, 0.212656), xyY!F(0.3000, 0.6000, 0.715158), xyY!F(0.1500, 0.0600, 0.072186)),
    RGBColorSpaceDesc!F("sRGB Simple",    &linearToGamma!(2.2, F), &gammaToLinear!(2.2, F), WhitePoint!F.D65, xyY!F(0.6400, 0.3300, 0.212656), xyY!F(0.3000, 0.6000, 0.715158), xyY!F(0.1500, 0.0600, 0.072186)),

//    RGBColorSpaceDesc!F("Rec601",           &linearTosRGB!F,         &sRGBToLinear!F,         WhitePoint!F.D65, xyY!F(0.6400, 0.3300, 0.299),    xyY!F(0.3000, 0.6000, 0.587),    xyY!F(0.1500, 0.0600, 0.114)),
//    RGBColorSpaceDesc!F("Rec709",           &linearTosRGB!F,         &sRGBToLinear!F,         WhitePoint!F.D65, xyY!F(0.6400, 0.3300, 0.212656), xyY!F(0.3000, 0.6000, 0.715158), xyY!F(0.1500, 0.0600, 0.072186)),
//    RGBColorSpaceDesc!F("Rec2020",          &linearToRec2020!F,      &Rec2020ToLinear!F,      WhitePoint!F.D65, xyY!F(0.708,  0.292,  0.2627),   xyY!F(0.170,  0.797,  0.6780),   xyY!F(0.131,  0.046,  0.0593)),
];

// 3d linear algebra functions (this would ideally live somewhere else...)
F[3] multiply(F)(F[3][3] m1, F[3] v)
{
    return [ m1[0][0]*v[0] + m1[0][1]*v[1] + m1[0][2]*v[2],
             m1[1][0]*v[0] + m1[1][1]*v[1] + m1[1][2]*v[2],
             m1[2][0]*v[0] + m1[2][1]*v[1] + m1[2][2]*v[2] ];
}

F[3][3] multiply(F)(F[3][3] m1, F[3][3] m2)
{
    return [[ m1[0][0]*m2[0][0] + m1[0][1]*m2[1][0] + m1[0][2]*m2[2][0],
              m1[0][0]*m2[0][1] + m1[0][1]*m2[1][1] + m1[0][2]*m2[2][1],
              m1[0][0]*m2[0][2] + m1[0][1]*m2[1][2] + m1[0][2]*m2[2][2] ],
            [ m1[1][0]*m2[0][0] + m1[1][1]*m2[1][0] + m1[1][2]*m2[2][0],
              m1[1][0]*m2[0][1] + m1[1][1]*m2[1][1] + m1[1][2]*m2[2][1],
              m1[1][0]*m2[0][2] + m1[1][1]*m2[1][2] + m1[1][2]*m2[2][2] ],
            [ m1[2][0]*m2[0][0] + m1[2][1]*m2[1][0] + m1[2][2]*m2[2][0],
              m1[2][0]*m2[0][1] + m1[2][1]*m2[1][1] + m1[2][2]*m2[2][1],
              m1[2][0]*m2[0][2] + m1[2][1]*m2[1][2] + m1[2][2]*m2[2][2] ]];
}

F[3][3] transpose(F)(F[3][3] m)
{
    return [[ m[0][0], m[1][0], m[2][0] ],
            [ m[0][1], m[1][1], m[2][1] ],
            [ m[0][2], m[1][2], m[2][2] ]];
}

F determinant(F)(F[3][3] m)
{
    return m[0][0] * (m[1][1]*m[2][2] - m[2][1]*m[1][2]) -
           m[0][1] * (m[1][0]*m[2][2] - m[1][2]*m[2][0]) +
           m[0][2] * (m[1][0]*m[2][1] - m[1][1]*m[2][0]);
}

F[3][3] inverse(F)(F[3][3] m)
{
    F det = determinant(m);
    assert(det != 0, "Matrix is not invertible!");

    F invDet = F(1)/det;
    return [[ (m[1][1]*m[2][2] - m[2][1]*m[1][2]) * invDet,
              (m[0][2]*m[2][1] - m[0][1]*m[2][2]) * invDet,
              (m[0][1]*m[1][2] - m[0][2]*m[1][1]) * invDet ],
            [ (m[1][2]*m[2][0] - m[1][0]*m[2][2]) * invDet,
              (m[0][0]*m[2][2] - m[0][2]*m[2][0]) * invDet,
              (m[1][0]*m[0][2] - m[0][0]*m[1][2]) * invDet ],
            [ (m[1][0]*m[2][1] - m[2][0]*m[1][1]) * invDet,
              (m[2][0]*m[0][1] - m[0][0]*m[2][1]) * invDet,
              (m[0][0]*m[1][1] - m[1][0]*m[0][1]) * invDet ]];
}
