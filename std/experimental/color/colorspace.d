// Written in the D programming language.

/**
This module defines and operates on standard color spaces.

Authors:    Manu Evans
Copyright:  Copyright (c) 2016, Manu Evans.
License:    $(WEB boost.org/LICENSE_1_0.txt, Boost License 1.0)
Source:     $(PHOBOSSRC std/experimental/color/_colorspace.d)
*/
module std.experimental.color.colorspace;

import std.experimental.color;
import std.experimental.color.xyz;

import std.traits : isFloatingPoint;

version(unittest)
    import std.math : abs;

@safe pure nothrow @nogc:

import std.range : iota;
import std.algorithm : reduce;


/** White points of $(LINK2 https://en.wikipedia.org/wiki/Standard_illuminant, standard illuminants). */
template WhitePoint(F) if (isFloatingPoint!F)
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
        /** Used by Japanese NTSC */
        D93 = xyY!F(0.28486, 0.29322, 1.00000),
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
        F12 = xyY!F(0.43695, 0.40441, 1.00000),
        /** DCI-P3 digital cinema projector */
        DCI = xyY!F(0.31270, 0.32900, 1.00000)
    }
}


/**
Enum of common RGB color spaces.
*/
enum RGBColorSpace
{
    /** sRGB */
    sRGB,
    /** sRGB approximation using gamma 2.2 */
    sRGB_Gamma2_2,

    /** NTSC Colorimetry (1953) */
    Colorimetry,
    /** NTSC SMPTE/C (1987) (ITU-R BT.601) */
    SMPTE_C,
    /** Japanese NTSC (1987) (ITU-R BT.601) */
    NTSC_J,
    /** PAL/SECAM (ITU-R BT.601) */
    PAL_SECAM,
    /** HDTV (ITU-R BT.709) */
    HDTV,
    /** UHDTV (ITU-R BT.2020) */
    UHDTV,

    /** Adobe RGB */
    AdobeRGB,
    /** Wide Gamut RGB */
    WideGamutRGB,
    /** Apple RGB */
    AppleRGB,
    /** ProPhoto */
    ProPhoto,
    /** CIE RGB */
    CIERGB,
    /** Best RGB */
    BestRGB,
    /** Beta RGB */
    BetaRGB,
    /** Bruce RGB */
    BruceRGB,
    /** Color Match RGB */
    ColorMatchRGB,
    /** DonRGB 4 */
    DonRGB4,
    /** Ekta Space PS5 */
    EktaSpacePS5,

    /** DCI-P3 Theater */
    DCI_P3_Theater,
    /** DCI-P3 D65 */
    DCI_P3_D65,
}


/**
Chromatic adaptation method.
*/
enum ChromaticAdaptationMethod
{
    /** Direct method, no correction for cone response. */
    XYZ,
    /** Bradford method. Considered by most experts to be the best. */
    Bradford,
    /** Von Kries method. */
    VonKries
}


/**
Parameters that define an RGB color space.$(BR)
$(D_INLINECODE F) is the float type that should be used for the colors and gamma functions.
*/
struct RGBColorSpaceDesc(F) if (isFloatingPoint!F)
{
    /** Gamma conversion function type. */
    alias GammaFunc = F function(F v) pure nothrow @nogc @safe;

    /** Color space name. */
    string name;

    /** Function that converts a linear luminance to gamma space. */
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
RGBColorSpaceDesc!F rgbColorSpaceDef(F = double)(RGBColorSpace colorSpace) if (isFloatingPoint!F)
{
    return rgbColorSpaceDefs!F[colorSpace];
}

/**
RGB to XYZ color space transformation matrix.$(BR)
$(D_INLINECODE cs) describes the source RGB color space.
*/
F[3][3] rgbToXyzMatrix(F = double)(RGBColorSpaceDesc!F cs) if (isFloatingPoint!F)
{
    static XYZ!F toXYZ(xyY!F c) { return c.y == F(0) ? XYZ!F() : XYZ!F(c.x/c.y, F(1), (F(1)-c.x-c.y)/c.y); }

    // build a matrix from the 3 color vectors
    auto r = toXYZ(cs.red);
    auto g = toXYZ(cs.green);
    auto b = toXYZ(cs.blue);
    F[3][3] m = [[ r.X, g.X, b.X],
                 [ r.Y, g.Y, b.Y],
                 [ r.Z, g.Z, b.Z]];

    // multiply by the whitepoint
    F[3] w = [ toXYZ(cs.white).tupleof ];
    auto s = multiply(inverse(m), w);

    // return colorspace matrix (RGB -> XYZ)
    return [[ r.X*s[0], g.X*s[1], b.X*s[2] ],
            [ r.Y*s[0], g.Y*s[1], b.Y*s[2] ],
            [ r.Z*s[0], g.Z*s[1], b.Z*s[2] ]];
}

/**
XYZ to RGB color space transformation matrix.$(BR)
$(D_INLINECODE cs) describes the target RGB color space.
*/
F[3][3] xyzToRgbMatrix(F = double)(RGBColorSpaceDesc!F cs) if (isFloatingPoint!F)
{
    return inverse(rgbToXyzMatrix(cs));
}

/**
Generate a chromatic adaptation matrix from $(D_INLINECODE srcWhite) to $(D_INLINECODE destWhite).

Chromatic adaptation is the process of transforming colors relative to a particular white point to some other white point.
Information about chromatic adaptation can be found at $(LINK2 https://en.wikipedia.org/wiki/Chromatic_adaptation, wikipedia).
*/
F[3][3] chromaticAdaptationMatrix(ChromaticAdaptationMethod method = ChromaticAdaptationMethod.Bradford, F = double)(xyY!F srcWhite, xyY!F destWhite) if (isFloatingPoint!F)
{
    enum Ma = chromaticAdaptationMatrices!F[method];
    enum iMa = inverse!F(Ma);
    auto XYZs = convertColor!(XYZ!F)(srcWhite);
    auto XYZd = convertColor!(XYZ!F)(destWhite);
    F[3] Ws = [ XYZs.X, XYZs.Y, XYZs.Z ];
    F[3] Wd = [ XYZd.X, XYZd.Y, XYZd.Z ];
    auto s = multiply!F(Ma, Ws);
    auto d = multiply!F(Ma, Wd);
    F[3][3] t = [[d[0]/s[0], F(0),      F(0)     ],
                 [F(0),      d[1]/s[1], F(0)     ],
                 [F(0),      F(0),      d[2]/s[2]]];
    return multiply!F(multiply!F(iMa, t), Ma);
}

/** Linear to hybrid linear-gamma ramp function.  The function and parameters are detailed in the example below. */
T linearToHybridGamma(double a, double b, double s, double e, T)(T v) if (isFloatingPoint!T)
{
    if (v <= T(b))
        return v*T(s);
    else
        return T(a)*v^^T(e) - T(a - 1);
}
///
unittest
{
    // sRGB parameters
    enum a = 1.055;
    enum b = 0.0031308;
    enum s = 12.92;
    enum e = 1/2.4;

    double v = 0.5;

    // the gamma function
    if (v <= b)
        v = v*s;
    else
        v = a*v^^e - (a - 1);

    assert(abs(v - linearToHybridGamma!(a, b, s, e)(0.5)) < double.epsilon);
}

/** Hybrid linear-gamma to linear function. The function and parameters are detailed in the example below. */
T hybridGammaToLinear(double a, double b, double s, double e, T)(T v) if (isFloatingPoint!T)
{
    if (v <= T(b*s))
        return v * T(1/s);
    else
        return ((v + T(a - 1)) * T(1/a))^^T(e);
}
///
unittest
{
    // sRGB parameters
    enum a = 1.055;
    enum b = 0.0031308;
    enum s = 12.92;
    enum e = 2.4;

    double v = 0.5;

    // the gamma function
    if (v <= b*s)
        v = v/s;
    else
        v = ((v + (a - 1)) / a)^^e;

    assert(abs(v - hybridGammaToLinear!(a, b, s, e)(0.5)) < double.epsilon);
}

/** Linear to sRGB ramp function. */
alias linearTosRGB(F) = linearToHybridGamma!(1.055, 0.0031308, 12.92, 1/2.4, F);
/** sRGB to linear function. */
alias sRGBToLinear(F) = hybridGammaToLinear!(1.055, 0.0031308, 12.92, 2.4, F);

/** Linear to Rec.601 ramp function. Note, Rec.709 also uses this same function.*/
alias linearToRec601(F) = linearToHybridGamma!(1.099, 0.018, 4.5, 0.45, F);
/** Rec.601 to linear function. Note, Rec.709 also uses this same function. */
alias rec601ToLinear(F) = hybridGammaToLinear!(1.099, 0.018, 4.5, 1/0.45, F);
/** Linear to Rec.2020 ramp function. */
alias linearToRec2020(F) = linearToHybridGamma!(1.09929682680944, 0.018053968510807, 4.5, 0.45, F);
/** Rec.2020 to linear function. */
alias rec2020ToLinear(F) = hybridGammaToLinear!(1.09929682680944, 0.018053968510807, 4.5, 1/0.45, F);

/** Linear to gamma space function. */
T linearToGamma(double gamma, T)(T v) if (isFloatingPoint!T)
{
    return v^^T(1.0/gamma);
}
/** Linear to gamma space function. */
T linearToGamma(T)(T v, T gamma) if (isFloatingPoint!T)
{
    return v^^T(1.0/gamma);
}

/** Gamma to linear function. */
T gammaToLinear(double gamma, T)(T v) if (isFloatingPoint!T)
{
    return v^^T(gamma);
}
/** Gamma to linear function. */
T gammaToLinear(T)(T v, T gamma) if (isFloatingPoint!T)
{
    return v^^T(gamma);
}


package:

__gshared immutable RGBColorSpaceDesc!F[RGBColorSpace.max + 1] rgbColorSpaceDefs(F) = [
    RGBColorSpaceDesc!F("sRGB",             &linearTosRGB!F,         &sRGBToLinear!F,         WhitePoint!F.D65, xyY!F(0.6400, 0.3300, 0.212656), xyY!F(0.3000, 0.6000, 0.715158), xyY!F(0.1500, 0.0600, 0.072186)),
    RGBColorSpaceDesc!F("sRGB simple",      &linearToGamma!(2.2, F), &gammaToLinear!(2.2, F), WhitePoint!F.D65, xyY!F(0.6400, 0.3300, 0.212656), xyY!F(0.3000, 0.6000, 0.715158), xyY!F(0.1500, 0.0600, 0.072186)),

    RGBColorSpaceDesc!F("Colorimetry",      &linearToRec601!F,       &rec601ToLinear!F,       WhitePoint!F.C,   xyY!F(0.6700, 0.3300, 0.298839), xyY!F(0.2100, 0.7100, 0.586811), xyY!F(0.1400, 0.0800, 0.114350)),
    RGBColorSpaceDesc!F("SMPTE/C",          &linearToRec601!F,       &rec601ToLinear!F,       WhitePoint!F.D65, xyY!F(0.6300, 0.3400, 0.212395), xyY!F(0.3100, 0.5950, 0.701049), xyY!F(0.1550, 0.0700, 0.086556)),
//  RGBColorSpaceDesc!F("Rec601 NTSC",      &linearToRec601!F,       &rec601ToLinear!F,       WhitePoint!F.D65, xyY!F(0.6300, 0.3400, 0.299),    xyY!F(0.3100, 0.5950, 0.587),    xyY!F(0.1550, 0.0700, 0.114)), // what's with the Y difference?
    RGBColorSpaceDesc!F("NTSC-J",           &linearToRec601!F,       &rec601ToLinear!F,       WhitePoint!F.D93, xyY!F(0.6300, 0.3400, 0.212395), xyY!F(0.3100, 0.5950, 0.701049), xyY!F(0.1550, 0.0700, 0.086556)),
    RGBColorSpaceDesc!F("PAL/SECAM",        &linearToRec601!F,       &rec601ToLinear!F,       WhitePoint!F.D65, xyY!F(0.6400, 0.3300, 0.222021), xyY!F(0.2900, 0.6000, 0.706645), xyY!F(0.1500, 0.0600, 0.071334)),
//  RGBColorSpaceDesc!F("Rec601 PAL/SECAM", &linearToRec601!F,       &rec601ToLinear!F,       WhitePoint!F.D65, xyY!F(0.6400, 0.3300, 0.299),    xyY!F(0.2900, 0.6000, 0.587),    xyY!F(0.1500, 0.0600, 0.114)), // what's with the Y difference?
    RGBColorSpaceDesc!F("HDTV",             &linearToRec601!F,       &rec601ToLinear!F,       WhitePoint!F.D65, xyY!F(0.6400, 0.3300, 0.212656), xyY!F(0.3000, 0.6000, 0.715158), xyY!F(0.1500, 0.0600, 0.072186)),
    RGBColorSpaceDesc!F("UHDTV",            &linearToRec2020!F,      &rec2020ToLinear!F,      WhitePoint!F.D65, xyY!F(0.7080, 0.2920, 0.262698), xyY!F(0.1700, 0.7970, 0.678009), xyY!F(0.1310, 0.0460, 0.059293)),

    RGBColorSpaceDesc!F("Adobe RGB",        &linearToGamma!(2.2, F), &gammaToLinear!(2.2, F), WhitePoint!F.D65, xyY!F(0.6400, 0.3300, 0.297361), xyY!F(0.2100, 0.7100, 0.627355), xyY!F(0.1500, 0.0600, 0.075285)),
    RGBColorSpaceDesc!F("Wide Gamut RGB",   &linearToGamma!(2.2, F), &gammaToLinear!(2.2, F), WhitePoint!F.D50, xyY!F(0.7350, 0.2650, 0.258187), xyY!F(0.1150, 0.8260, 0.724938), xyY!F(0.1570, 0.0180, 0.016875)),
    RGBColorSpaceDesc!F("Apple RGB",        &linearToGamma!(1.8, F), &gammaToLinear!(1.8, F), WhitePoint!F.D65, xyY!F(0.6250, 0.3400, 0.244634), xyY!F(0.2800, 0.5950, 0.672034), xyY!F(0.1550, 0.0700, 0.083332)),
    RGBColorSpaceDesc!F("ProPhoto",         &linearToGamma!(1.8, F), &gammaToLinear!(1.8, F), WhitePoint!F.D50, xyY!F(0.7347, 0.2653, 0.288040), xyY!F(0.1596, 0.8404, 0.711874), xyY!F(0.0366, 0.0001, 0.000086)),
    RGBColorSpaceDesc!F("CIE RGB",          &linearToGamma!(2.2, F), &gammaToLinear!(2.2, F), WhitePoint!F.E,   xyY!F(0.7350, 0.2650, 0.176204), xyY!F(0.2740, 0.7170, 0.812985), xyY!F(0.1670, 0.0090, 0.010811)),
//  RGBColorSpaceDesc!F("CIE RGB",          &linearToGamma!(2.2, F), &gammaToLinear!(2.2, F), WhitePoint!F.E,   xyY!F(0.7347, 0.2653),           xyY!F(0.2738, 0.7174),           xyY!F(0.1666, 0.0089)), // another source shows slightly different primaries
    RGBColorSpaceDesc!F("Best RGB",         &linearToGamma!(2.2, F), &gammaToLinear!(2.2, F), WhitePoint!F.D50, xyY!F(0.7347, 0.2653, 0.228457), xyY!F(0.2150, 0.7750, 0.737352), xyY!F(0.1300, 0.0350, 0.034191)),
    RGBColorSpaceDesc!F("Beta RGB",         &linearToGamma!(2.2, F), &gammaToLinear!(2.2, F), WhitePoint!F.D50, xyY!F(0.6888, 0.3112, 0.303273), xyY!F(0.1986, 0.7551, 0.663786), xyY!F(0.1265, 0.0352, 0.032941)),
    RGBColorSpaceDesc!F("Bruce RGB",        &linearToGamma!(2.2, F), &gammaToLinear!(2.2, F), WhitePoint!F.D65, xyY!F(0.6400, 0.3300, 0.240995), xyY!F(0.2800, 0.6500, 0.683554), xyY!F(0.1500, 0.0600, 0.075452)),
    RGBColorSpaceDesc!F("Color Match RGB",  &linearToGamma!(1.8, F), &gammaToLinear!(1.8, F), WhitePoint!F.D50, xyY!F(0.6300, 0.3400, 0.274884), xyY!F(0.2950, 0.6050, 0.658132), xyY!F(0.1500, 0.0750, 0.066985)),
    RGBColorSpaceDesc!F("DonRGB 4",         &linearToGamma!(2.2, F), &gammaToLinear!(2.2, F), WhitePoint!F.D50, xyY!F(0.6960, 0.3000, 0.278350), xyY!F(0.2150, 0.7650, 0.687970), xyY!F(0.1300, 0.0350, 0.033680)),
    RGBColorSpaceDesc!F("Ekta Space PS5",   &linearToGamma!(2.2, F), &gammaToLinear!(2.2, F), WhitePoint!F.D50, xyY!F(0.6950, 0.3050, 0.260629), xyY!F(0.2600, 0.7000, 0.734946), xyY!F(0.1100, 0.0050, 0.004425)),

    RGBColorSpaceDesc!F("DCI-P3 Theater",   &linearToGamma!(2.6, F), &gammaToLinear!(2.6, F), WhitePoint!F.DCI, xyY!F(0.6800, 0.3200, 0.228975), xyY!F(0.2650, 0.6900, 0.691739), xyY!F(0.1500, 0.0600, 0.079287)),
    RGBColorSpaceDesc!F("DCI-P3 D65",       &linearToGamma!(2.6, F), &gammaToLinear!(2.6, F), WhitePoint!F.D65, xyY!F(0.6800, 0.3200, 0.228973), xyY!F(0.2650, 0.6900, 0.691752), xyY!F(0.1500, 0.0600, 0.079275)),
];

__gshared immutable F[3][3][ChromaticAdaptationMethod.max + 1] chromaticAdaptationMatrices(F) = [
    // XYZ (identity) matrix
    [[ F(1), F(0), F(0) ],
     [ F(0), F(1), F(0) ],
     [ F(0), F(0), F(1) ]],
    // Bradford matrix
    [[ F( 0.8951000), F( 0.2664000), F(-0.1614000) ],
     [ F(-0.7502000), F( 1.7135000), F( 0.0367000) ],
     [ F( 0.0389000), F(-0.0685000), F( 1.0296000) ]],
    // Von Kries matrix
    [[ F( 0.4002400), F( 0.7076000), F(-0.0808100) ],
     [ F(-0.2263000), F( 1.1653200), F( 0.0457000) ],
     [ F( 0.0000000), F( 0.0000000), F( 0.9182200) ]]
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
