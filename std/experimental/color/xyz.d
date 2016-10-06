// Written in the D programming language.

/**
This module implements $(LINK2 https://en.wikipedia.org/wiki/CIE_1931_color_space, CIE XYZ) and
$(LINK2 https://en.wikipedia.org/wiki/CIE_1931_color_space#CIE_xy_chromaticity_diagram_and_the_CIE_xyY_color_space, xyY)
_color types.

These _color spaces represent the simplest expression of the full-spectrum of human visible _color.
No attempts are made to support perceptual uniformity, or meaningful colour blending within these _color spaces.
They are most useful as an absolute representation of human visible colors, and a centre point for _color space
conversions.

Authors:    Manu Evans
Copyright:  Copyright (c) 2015, Manu Evans.
License:    $(WEB boost.org/LICENSE_1_0.txt, Boost License 1.0)
Source:     $(PHOBOSSRC std/experimental/color/_xyz.d)
*/
module std.experimental.color.xyz;

import std.experimental.color;
version(unittest)
    import std.experimental.color.colorspace : WhitePoint;

import std.traits : isInstanceOf, isFloatingPoint, Unqual;
import std.typetuple : TypeTuple;
import std.typecons : tuple;

@safe pure nothrow @nogc:


/**
Detect whether $(D_INLINECODE T) is an XYZ color.
*/
enum isXYZ(T) = isInstanceOf!(XYZ, T);

///
unittest
{
    static assert(isXYZ!(XYZ!float) == true);
    static assert(isXYZ!(xyY!double) == false);
    static assert(isXYZ!int == false);
}


/**
Detect whether $(D_INLINECODE T) is an xyY color.
*/
enum isxyY(T) = isInstanceOf!(xyY, T);

///
unittest
{
    static assert(isxyY!(xyY!float) == true);
    static assert(isxyY!(XYZ!double) == false);
    static assert(isxyY!int == false);
}


/**
A CIE 1931 XYZ color, parameterised for component type.
*/
struct XYZ(F = float) if (isFloatingPoint!F)
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

    /** Construct a color from XYZ values. */
    this(ComponentType X, ComponentType Y, ComponentType Z)
    {
        this.X = X;
        this.Y = Y;
        this.Z = Z;
    }

    /**
    Cast to other color types.

    This cast is a convenience which simply forwards the call to convertColor.
    */
    Color opCast(Color)() const if (isColor!Color)
    {
        return convertColor!Color(this);
    }

    /** Unary operators. */
    typeof(this) opUnary(string op)() const if (op == "+" || op == "-" || (op == "~" && is(ComponentType == NormalizedInt!U, U)))
    {
        Unqual!(typeof(this)) res = this;
        foreach (c; AllComponents)
            mixin(ComponentExpression!("res._ = #_;", c, op));
        return res;
    }
    /** Binary operators. */
    typeof(this) opBinary(string op)(typeof(this) rh) const if (op == "+" || op == "-" || op == "*")
    {
        Unqual!(typeof(this)) res = this;
        foreach (c; AllComponents)
            mixin(ComponentExpression!("res._ #= rh._;", c, op));
        return res;
    }
    /** Binary operators. */
    typeof(this) opBinary(string op, S)(S rh) const if (isColorScalarType!S && (op == "*" || op == "/" || op == "%" || op == "^^"))
    {
        Unqual!(typeof(this)) res = this;
        foreach (c; AllComponents)
            mixin(ComponentExpression!("res._ #= rh;", c, op));
        return res;
    }
    /** Binary assignment operators. */
    ref typeof(this) opOpAssign(string op)(typeof(this) rh) if (op == "+" || op == "-" || op == "*")
    {
        foreach (c; AllComponents)
            mixin(ComponentExpression!("_ #= rh._;", c, op));
        return this;
    }
    /** Binary assignment operators. */
    ref typeof(this) opOpAssign(string op, S)(S rh) if (isColorScalarType!S && (op == "*" || op == "/" || op == "%" || op == "^^"))
    {
        foreach (c; AllComponents)
            mixin(ComponentExpression!("_ #= rh;", c, op));
        return this;
    }


package:

    static To convertColorImpl(To, From)(From color) if (isXYZ!From && isXYZ!To)
    {
        alias F = To.ComponentType;
        return To(F(color.X), F(color.Y), F(color.Z));
    }
    unittest
    {
        static assert(convertColorImpl!(XYZ!float)(XYZ!double(1, 2, 3)) == XYZ!float(1, 2, 3));
        static assert(convertColorImpl!(XYZ!double)(XYZ!float(1, 2, 3)) == XYZ!double(1, 2, 3));
    }

private:
    alias AllComponents = TypeTuple!("X", "Y", "Z");
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
struct xyY(F = float) if (isFloatingPoint!F)
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

    /** Construct a color from xyY values. */
    this(ComponentType x, ComponentType y, ComponentType Y)
    {
        this.x = x;
        this.y = y;
        this.Y = Y;
    }

    /**
    Cast to other color types.

    This cast is a convenience which simply forwards the call to convertColor.
    */
    Color opCast(Color)() const if (isColor!Color)
    {
        return convertColor!Color(this);
    }

    /** Unary operators. */
    typeof(this) opUnary(string op)() const if (op == "+" || op == "-" || (op == "~" && is(ComponentType == NormalizedInt!U, U)))
    {
        Unqual!(typeof(this)) res = this;
        foreach (c; AllComponents)
            mixin(ComponentExpression!("res._ = #_;", c, op));
        return res;
    }

    /** Binary operators. */
    typeof(this) opBinary(string op)(typeof(this) rh) const if (op == "+" || op == "-" || op == "*")
    {
        Unqual!(typeof(this)) res = this;
        foreach (c; AllComponents)
            mixin(ComponentExpression!("res._ #= rh._;", c, op));
        return res;
    }

    /** Binary operators. */
    typeof(this) opBinary(string op, S)(S rh) const if (isColorScalarType!S && (op == "*" || op == "/" || op == "%" || op == "^^"))
    {
        Unqual!(typeof(this)) res = this;
        foreach (c; AllComponents)
            mixin(ComponentExpression!("res._ #= rh;", c, op));
        return res;
    }

    /** Binary assignment operators. */
    ref typeof(this) opOpAssign(string op)(typeof(this) rh) if (op == "+" || op == "-" || op == "*")
    {
        foreach (c; AllComponents)
            mixin(ComponentExpression!("_ #= rh._;", c, op));
        return this;
    }

    /** Binary assignment operators. */
    ref typeof(this) opOpAssign(string op, S)(S rh) if (isColorScalarType!S && (op == "*" || op == "/" || op == "%" || op == "^^"))
    {
        foreach (c; AllComponents)
            mixin(ComponentExpression!("_ #= rh;", c, op));
        return this;
    }


package:

    alias ParentColor = XYZ!ComponentType;

    static To convertColorImpl(To, From)(From color) if (isxyY!From && isxyY!To)
    {
        alias F = To.ComponentType;
        return To(F(color.x), F(color.y), F(color.Y));
    }
    unittest
    {
        static assert(convertColorImpl!(xyY!float)(xyY!double(1, 2, 3)) == xyY!float(1, 2, 3));
        static assert(convertColorImpl!(xyY!double)(xyY!float(1, 2, 3)) == xyY!double(1, 2, 3));
    }

    static To convertColorImpl(To, From)(From color) if (isxyY!From && isXYZ!To)
    {
        alias F = To.ComponentType;
        if (color.y == 0)
            return To(F(0), F(0), F(0));
        else
            return To(F((color.Y/color.y)*color.x), F(color.Y), F((color.Y/color.y)*(1-color.x-color.y)));
    }
    unittest
    {
        static assert(convertColorImpl!(XYZ!float)(xyY!float(0.5, 0.5, 1)) == XYZ!float(1, 1, 0));

        // degenerate case
        static assert(convertColorImpl!(XYZ!float)(xyY!float(0.5, 0, 1)) == XYZ!float(0, 0, 0));
    }

    static To convertColorImpl(To, From)(From color) if (isXYZ!From && isxyY!To)
    {
        alias F = To.ComponentType;
        auto sum = color.X + color.Y + color.Z;
        if (sum == 0)
            return To(WhitePoint!F.D65.x, WhitePoint!F.D65.y, F(0));
        else
            return To(F(color.X/sum), F(color.Y/sum), F(color.Y));
    }
    unittest
    {
        static assert(convertColorImpl!(xyY!float)(XYZ!float(0.5, 1, 0.5)) == xyY!float(0.25, 0.5, 1));

        // degenerate case
        static assert(convertColorImpl!(xyY!float)(XYZ!float(0, 0, 0)) == xyY!float(WhitePoint!float.D65.x, WhitePoint!float.D65.y, 0));
    }

private:
    alias AllComponents = TypeTuple!("x", "y", "Y");
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
