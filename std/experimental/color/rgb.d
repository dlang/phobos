// Written in the D programming language.

/**
    This module implements the RGB _color type.

    Authors:    Manu Evans
    Copyright:  Copyright (c) 2015, Manu Evans.
    License:    $(WEB boost.org/LICENSE_1_0.txt, Boost License 1.0)
    Source:     $(PHOBOSSRC std/experimental/color/rgb.d)
*/
module std.experimental.color.rgb;

import std.experimental.color;
import std.experimental.color.conv;

import std.traits: isInstanceOf, isNumeric, isIntegral, isFloatingPoint, isSigned, isSomeChar, Unqual;
import std.typetuple: TypeTuple;
import std.typecons: tuple;

@safe: pure: nothrow: @nogc:

enum isValidComponentType(T) = isIntegral!T || isFloatingPoint!T;


/**
Detect whether $(D T) is an RGB color.
*/
enum isRGB(T) = isInstanceOf!(RGB, T);


// DEBATE: which should it be?
template defaultAlpha(T)
{
/+
    enum defaultAlpha = isFloatingPoint!T ? T(1) : T.max;
+/
    enum defaultAlpha = T(0);
}


/**
Enum of RGB color spaces.
*/
enum RGBColorSpace
{
    /** sRGB, HDTV (ITU-R BT.709) */
    sRGB,
    /** sRGB with gamma 2.2 */
    sRGB_Gamma2_2,

    // custom color space will disable automatic color spoace conversions
    custom = -1
}


/**
An RGB color, parameterised with components, component type, and color space specification.

Params: components_ = Components that shall be available. Struct is populated with components in the order specified.
                      Valid components are:
                        "r" = red
                        "g" = green
                        "b" = blue
                        "a" = alpha
                        "l" = luminance
                        "x" = placeholder/padding (no significant value)
        ComponentType_ = Type for the color channels. May be a basic integer or floating point type.
        linear_ = Color is stored with linear luminance.
        colorSpace_ = Color will be within the specified color space.
*/
struct RGB(string components_, ComponentType_, bool linear_ = false, RGBColorSpace colorSpace_ = RGBColorSpace.sRGB) if(isValidComponentType!ComponentType_)
{
@safe: pure: nothrow: @nogc:

    // RGB colors may only contain components 'rgb', or 'l' (luminance)
    // They may also optionally contain an 'a' (alpha) component, and 'x' (unused) components
    static assert(allIn!("rgblax", components), "Invalid Color component '"d ~ notIn!("rgblax", components) ~ "'. RGB colors may only contain components: r, g, b, l, a, x"d);
    static assert(anyIn!("rgbal", components), "RGB colors must contain at least one component of r, g, b, l, a.");
    static assert(!canFind!(components, 'l') || !anyIn!("rgb", components), "RGB colors may not contain rgb AND luminance components together.");

    // create members for some useful information
    /** Type of the color components. */
    alias ComponentType = ComponentType_;
    /** The color components that were specified. */
    enum string components = components_;
    /** The color space specified. */
    enum RGBColorSpace colorSpace = colorSpace_;
    /** If the color is stored linearly (without gamma applied). */
    enum bool linear = linear_;


    // mixin will emit members for components
    template Components(string components)
    {
        static if(components.length == 0)
            enum Components = "";
        else
            enum Components = ComponentType.stringof ~ ' ' ~ components[0] ~ " = 0;\n" ~ Components!(components[1..$]);
    }
    mixin(Components!components);

    /** Test if a particular component is present. */
    enum bool hasComponent(char c) = mixin("is(typeof(this."~c~"))");
    /** If the color has alpha. */
    enum bool hasAlpha = hasComponent!'a';


    // functions that return the color channels as a tuple
    /** Return the RGB tristimulus values as a tuple.
        These will always be ordered (R, G, B).
        Any color channels not present will be 0. */
    @property auto tristimulus() const
    {
        static if(hasComponent!'l')
        {
            return tuple(l, l, l);
        }
        else
        {
            static if(!hasComponent!'r')
                enum r = ComponentType(0);
            static if(!hasComponent!'g')
                enum g = ComponentType(0);
            static if(!hasComponent!'b')
                enum b = ComponentType(0);
            return tuple(r, g, b);
        }
    }
    /** Return the RGB tristimulus values + alpha as a tuple.
        These will always be ordered (R, G, B, A). */
    @property auto tristimulusWithAlpha() const
    {
        static if(!hasAlpha)
            enum a = defaultAlpha!ComponentType;
        return tuple(tristimulus.expand, a);
    }

    // RGB/A initialiser
    /** Construct a color from RGB and optional alpha values. */
    this(ComponentType r, ComponentType g, ComponentType b, ComponentType a = defaultAlpha!ComponentType)
    {
        foreach(c; TypeTuple!("r","g","b","a"))
            mixin(ComponentExpression!("this._ = _;", c, null));
        static if(canFind!(components, 'l'))
            this.l = toGrayscale!(linear, colorSpace)(r, g, b); // ** Contentious? I this this is most useful
    }

    // L/A initialiser
    /** Construct a color from a luminance and optional alpha value. */
    this(ComponentType l, ComponentType a = defaultAlpha!ComponentType)
    {
        foreach(c; TypeTuple!("l","r","g","b"))
            mixin(ComponentExpression!("this._ = l;", c, null));
        static if(canFind!(components, 'a'))
            this.a = a;
    }

    // hex string initialiser
    /** Construct a color from a hex string. */
    this(C)(const(C)[] hex) if(isSomeChar!C)
    {
        import std.experimental.color.conv: colorFromString;
        this = colorFromString!(typeof(this))(hex);
    }

    // casts
    Color opCast(Color)() const if(isColor!Color)
    {
        return convertColor!Color(this);
    }

    // comparison
    bool opEquals(typeof(this) rh) const
    {
        // this is required to exclude 'x' components from equality comparisons
        return tristimulusWithAlpha == rh.tristimulusWithAlpha;
    }

    // operators
    mixin ColorOperators!AllComponents;

    unittest
    {
        alias UnsignedRGB = RGB!("rgb", ubyte);
        alias SignedRGBX = RGB!("rgbx", byte);
        alias FloatRGBA = RGB!("rgba", float);

        // test construction
        static assert(UnsignedRGB("0x908000FF")  == UnsignedRGB(0x80,0,0xFF));
        static assert(FloatRGBA("0x908000FF")    == FloatRGBA(float(0x80)/float(0xFF),0,1,float(0x90)/float(0xFF)));

        // test operators
        static assert(-SignedRGBX(1,2,3) == SignedRGBX(-1,-2,-3));
        static assert(-FloatRGBA(1,2,3)  == FloatRGBA(-1,-2,-3));

        static assert(UnsignedRGB(10,20,30)  + UnsignedRGB(4,5,6) == UnsignedRGB(14,25,36));
        static assert(SignedRGBX(10,20,30)   + SignedRGBX(4,5,6)  == SignedRGBX(14,25,36));
        static assert(FloatRGBA(10,20,30,40) + FloatRGBA(4,5,6,7) == FloatRGBA(14,25,36,47));

        static assert(UnsignedRGB(10,20,30)  - UnsignedRGB(4,5,6) == UnsignedRGB(6,15,24));
        static assert(SignedRGBX(10,20,30)   - SignedRGBX(4,5,6)  == SignedRGBX(6,15,24));
        static assert(FloatRGBA(10,20,30,40) - FloatRGBA(4,5,6,7) == FloatRGBA(6,15,24,33));

        static assert(UnsignedRGB(10,20,30)  * UnsignedRGB(0,1,2) == UnsignedRGB(0,20,60));
        static assert(SignedRGBX(10,20,30)   * SignedRGBX(0,1,2)  == SignedRGBX(0,20,60));
        static assert(FloatRGBA(10,20,30,40) * FloatRGBA(0,1,2,3) == FloatRGBA(0,20,60,120));

        static assert(UnsignedRGB(10,20,30)  / UnsignedRGB(1,2,3) == UnsignedRGB(10,10,10));
        static assert(SignedRGBX(10,20,30)   / SignedRGBX(1,2,3)  == SignedRGBX(10,10,10));
        static assert(FloatRGBA(2,4,8,16)    / FloatRGBA(1,2,4,8) == FloatRGBA(2,2,2,2));

        static assert(UnsignedRGB(10,20,30)  * 2 == UnsignedRGB(20,40,60));
        static assert(SignedRGBX(10,20,30)   * 2 == SignedRGBX(20,40,60));
        static assert(FloatRGBA(10,20,30,40) * 2 == FloatRGBA(20,40,60,80));

        static assert(UnsignedRGB(10,20,30)  / 2 == UnsignedRGB(5,10,15));
        static assert(SignedRGBX(10,20,30)   / 2 == SignedRGBX(5,10,15));
        static assert(FloatRGBA(10,20,30,40) / 2 == FloatRGBA(5,10,15,20));
    }

private:
    alias AllComponents = TypeTuple!("l","r","g","b","a");
    alias ParentColor = XYZ!(FloatTypeFor!ComponentType);
}


// gamma ramp conversions
/** Convert a value from gamma compressed space to linear. */
T toLinear(RGBColorSpace src, T)(T v) if(isFloatingPoint!T)
{
    enum ColorSpace = RGBColorSpaceDefs!T[src];
    return ColorSpace.toLinear(v);
}
/** Convert a value to gamma compressed space. */
T toGamma(RGBColorSpace src, T)(T v) if(isFloatingPoint!T)
{
    enum ColorSpace = RGBColorSpaceDefs!T[src];
    return ColorSpace.toGamma(v);
}

/** Convert a color to linear space. */
auto toLinear(C)(C color) if(isRGB!C)
{
    return cast(RGB!(C.components, C.ComponentType, true, C.colorSpace))color;
}
/** Convert a color to gamma space. */
auto toGamma(C)(C color) if(isRGB!C)
{
    return cast(RGB!(C.components, C.ComponentType, false, C.colorSpace))color;
}


package:
//
// Below exists a bunch of machinery for converting between RGB color spaces
//

import std.experimental.color.xyz;

// RGB color space definitions
struct RGBColorSpaceDef(F)
{
    alias GammaFunc = F function(F v) pure nothrow @nogc @safe;

    string name;

    GammaFunc toGamma;
    GammaFunc toLinear;

    xyY!F white;
    xyY!F red;
    xyY!F green;
    xyY!F blue;
}

enum RGBColorSpaceDefs(F) = [
    RGBColorSpaceDef!F("sRGB",           &linearTosRGB!F,         &sRGBToLinear!F,         WhitePoint!F.D65, xyY!F(0.6400, 0.3300, 0.212656), xyY!F(0.3000, 0.6000, 0.715158), xyY!F(0.1500, 0.0600, 0.072186)),
    RGBColorSpaceDef!F("sRGB Simple",    &linearToGamma!(F, 2.2), &gammaToLinear!(F, 2.2), WhitePoint!F.D65, xyY!F(0.6400, 0.3300, 0.212656), xyY!F(0.3000, 0.6000, 0.715158), xyY!F(0.1500, 0.0600, 0.072186)),
];

template RGBColorSpaceMatrix(RGBColorSpace cs, F)
{
    enum F[3] ToXYZ(xyY!F c) = [ c.x/c.y, F(1), (F(1)-c.x-c.y)/c.y ];

    // get the color space definition
    enum def = RGBColorSpaceDefs!F[cs];
    // build a matrix from the 3 color vectors
    enum r = def.red, g = def.green, b = def.blue;
    enum m = transpose([ ToXYZ!r, ToXYZ!g, ToXYZ!b ]);

    // multiply by the whitepoint
    enum w = [ (cast(XYZ!F)(def.white)).tupleof ];
    enum s = multiply(inverse(m), w);

    // return colorspace matrix (RGB -> XYZ)
    enum F[3][3] RGBColorSpaceMatrix = [[ m[0][0]*s[0], m[0][1]*s[1], m[0][2]*s[2] ],
                                        [ m[1][0]*s[0], m[1][1]*s[1], m[1][2]*s[2] ],
                                        [ m[2][0]*s[0], m[2][1]*s[1], m[2][2]*s[2] ]];
}


T linearTosRGB(T)(T s) if(isFloatingPoint!T)
{
    if(s <= T(0.0031308))
        return T(12.92) * s;
    else
        return T(1.055) * s^^T(1.0/2.4) - T(0.055);
}
T sRGBToLinear(T)(T s) if(isFloatingPoint!T)
{
    if(s <= T(0.04045))
        return s / T(12.92);
    else
        return ((s + T(0.055)) / T(1.055))^^T(2.4);
}

T linearToGamma(T, T gamma)(T v) if(isFloatingPoint!T)
{
    return v^^T(1.0/gamma);
}
T gammaToLinear(T, T gamma)(T v) if(isFloatingPoint!T)
{
    return v^^T(gamma);
}

T toGrayscale(bool linear, RGBColorSpace colorSpace = RGBColorSpace.sRGB, T)(T r, T g, T b) pure if(isFloatingPoint!T)
{
    // calculate the luminance (Y) value by multiplying the Y row of the XYZ matrix with the color
    enum YAxis = RGBColorSpaceMatrix!(colorSpace, T)[1];

    static if(linear)
    {
        return YAxis[0]*r + YAxis[1]*g + YAxis[2]*b;
    }
    else
    {
        // precise; convert to linear, then convert
        return toGamma!colorSpace(YAxis[0]*toLinear!colorSpace(r) + YAxis[1]*toLinear!colorSpace(g) + YAxis[2]*toLinear!colorSpace(b));

        // fast (standardised) approximations, performed in sRGB gamma space
//        return T(0.299)*r + T(0.587)*g + T(0.114)*b; // Y'UV (PAL/NSTC/SECAM)
//        return T(0.2126)*r + T(0.7152)*g + T(0.0722)*b; // HDTV
    }
}
T toGrayscale(bool linear, RGBColorSpace colorSpace = RGBColorSpace.sRGB, T)(T r, T g, T b) pure if(isIntegral!T)
{
    import std.experimental.color.conv: convertPixelType;
    alias F = FloatTypeFor!T;
    return convertPixelType!T(toGrayscale!(linear, colorSpace)(convertPixelType!F(r), convertPixelType!F(g), convertPixelType!F(b)));
}


// helpers to parse color components from color component string
template canFind(string s, char c)
{
    static if(s.length == 0)
        enum canFind = false;
    else
        enum canFind = s[0] == c || canFind!(s[1..$], c);
}
template allIn(string s, string chars)
{
    static if(chars.length == 0)
        enum allIn = true;
    else
        enum allIn = canFind!(s, chars[0]) && allIn!(s, chars[1..$]);
}
template anyIn(string s, string chars)
{
    static if(chars.length == 0)
        enum anyIn = false;
    else
        enum anyIn = canFind!(s, chars[0]) || anyIn!(s, chars[1..$]);
}
template notIn(string s, string chars)
{
    static if(chars.length == 0)
        enum notIn = char(0);
    else static if(!canFind!(s, chars[0]))
        enum notIn = chars[0];
    else
        enum notIn = notIn!(s, chars[1..$]);
}

unittest
{
    static assert(canFind!("string", 'i'));
    static assert(!canFind!("string", 'x'));
    static assert(allIn!("string", "sgi"));
    static assert(!allIn!("string", "sgix"));
    static assert(anyIn!("string", "sx"));
    static assert(!anyIn!("string", "x"));
}


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
