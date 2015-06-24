// Written in the D programming language.

/**
    This module implements XYZ and xyY _color types.

    Authors:    Manu Evans
    Copyright:  Copyright (c) 2015, Manu Evans.
    License:    $(WEB boost.org/LICENSE_1_0.txt, Boost License 1.0)
    Source:     $(PHOBOSSRC std/experimental/color/xyz.d)
*/
module std.experimental.color.xyz;

import std.experimental.color;
import std.experimental.color.conv : convertColor;

import std.traits : isFloatingPoint, isIntegral, isSigned, isSomeChar, Unqual;
import std.typetuple : TypeTuple;
import std.typecons : tuple;

@safe pure nothrow @nogc:


/**
Detect whether $(D T) is an XYZ color.
*/
enum isXYZ(T) = isInstanceOf!(XYZ, T);

///
unittest
{
    static assert(isXYZ!(XYZ!float) == true);
    static assert(isXYZ!(xyY!double) == false);
}


/**
Detect whether $(D T) is an xyY color.
*/
enum isxyY(T) = isInstanceOf!(xyY, T);

///
unittest
{
    static assert(isxyY!(xyY!float) == true);
    static assert(isxyY!(XYZ!double) == false);
}


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
A CIE 1931 XYZ color, parameterised for component type.
*/
struct XYZ(F = float) if(isFloatingPoint!F)
{
@safe pure nothrow @nogc:

    /** Type of the color components. */
    alias ComponentType = F;

    /** X value. */
    F X = 0;
    /** Y value. */
    F Y = 0;
    /** Z value. */
    F Z = 0;

    /** Return the XYZ tristimulus values as a tuple. */
    @property auto tristimulus() const
    {
        return tuple(X, Y, Z);
    }

    // CIE XYZ constructor
    /** Construct a color from XYZ values. */
    this(ComponentType X, ComponentType Y, ComponentType Z)
    {
        this.X = X;
        this.Y = Y;
        this.Z = Z;
    }

    // casts
    Color opCast(Color)() const if(isColor!Color)
    {
        return convertColor!Color(this);
    }

    // operators
    mixin ColorOperators!(TypeTuple!("X","Y","Z"));
}

///
unittest
{
    // CIE XYZ 1931 color with float components
    alias XYZf = XYZ!float;

    XYZf c = XYZf(0.8, 1, 1.2);

    // tristimulus() returns a tuple of the components
    assert(c.tristimulus == tuple(c.X, c.Y, c.Z));

    // test XYZ operators and functions
    static assert(XYZf(0, 0.5, 0) + XYZf(0.5, 0.5, 1) == XYZf(0.5, 1, 1));
    static assert(XYZf(0.5, 0.5, 1) * 100.0 == XYZf(50, 50, 100));
}


/**
A CIE 1931 xyY color, parameterised for component type.
*/
struct xyY(F = float) if(isFloatingPoint!F)
{
@safe pure nothrow @nogc:

    /** Type of the color components. */
    alias ComponentType = F;

    /** x coordinate. */
    F x = 0;
    /** y coordinate. */
    F y = 0;
    /** Y value (luminance). */
    F Y = 0;

    // CIE xyY constructor
    /** Construct a color from xyY values. */
    this(ComponentType x, ComponentType y, ComponentType Y)
    {
        this.x = x;
        this.y = y;
        this.Y = Y;
    }

    // casts
    Color opCast(Color)() const if(isColor!Color)
    {
        return convertColor!Color(this);
    }

    // operators
    mixin ColorOperators!(TypeTuple!("x","y","Y"));

private:
    alias ParentColor = XYZ!ComponentType;
}

///
unittest
{
    // CIE xyY 1931 color with double components
    alias xyYd = xyY!double;

    xyYd c = xyYd(0.4, 0.5, 1);

    // test xyY operators and functions
    static assert(xyYd(0, 0.5, 0) + xyYd(0.5, 0.5, 1) == xyYd(0.5, 1, 1));
    static assert(xyYd(0.5, 0.5, 1) * 100.0 == xyYd(50, 50, 100));
}
