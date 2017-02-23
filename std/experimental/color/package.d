// Written in the D programming language.

/**
This package defines human-visible colors in various formats.

RGB _color formats are particularly flexible to express typical RGB image data
in a wide variety of common formats without having to write adapters.

It is intended that this library facilitate a common API that allows a variety
of image and multimedia libraries to interact more seamlessly, without need
for constant conversions between custom, library-defined _color data types.

This package pays very careful attention to correctness with respect to
_color space definitions, and correct handling of _color space conversions.
For best results, users should also pay careful attention to _color space
selection when working with _color data, and the rest will follow.
A crash course on understanding _color space can be found at
$(LINK2 https://en.wikipedia.org/wiki/Color_space, wikipedia).

More information regarding specific _color spaces can be found in their
respective modules.

All types and functions offered in this package are $(D_INLINECODE pure),
$(D_INLINECODE nothrow), $(D_INLINECODE @safe) and $(D_INLINECODE @nogc).
It is intended to be useful by realtime or memory-contrained systems such as
video games, games consoles or mobile devices.


Expressing images:

Images may be expressed in a variety of ways, but a simple way may be to use
std.experimental.ndslice to produce simple n-dimensional images.

-------
import std.experimental.color;
import std.experimental.ndslice;

auto imageBuffer = new RGB8[height*width];
auto image = imageBuffer.sliced(height, width);

foreach(ref row; image)
{
    foreach(ref pixel; row)
    {
        pixel = Colors.white;
    }
}
-------

Use of ndslice this way allows the use of n-dimentional slices to produce
sub-images.


Implement custom _color type:

The library is extensible such that users or libraries can easily supply
their own custom _color formats and expect comprehensive conversion and
interaction with any other libraries or code that makes use of
std.experimental._color.

The requirement for a user _color type is to specify a 'parent' _color space,
and expose at least a set of conversion functions to/from that parent.

For instance, HSV is a cylindrical representation of RGB colors, so the
'parent' _color type in this case is said to be RGB.
If your custom _color space is not derivative of an existing _color space,
then you should provide conversion between CIE XYZ, which can most simply
express all of human-visible _color.

-------
struct HueOnlyColor
{
    alias ParentColor = HSV!float;

    static To convertColorImpl(To, From)(From color) if (is(From == HueOnlyColor) && isHSx!To)
    {
        return To(color.hue, 1.0, 1.0); // assume maximum saturation, maximum lightness
    }

    static To convertColorImpl(To, From)(From color) if (isHSx!From && is(To == HueOnlyColor))
    {
        return HueOnlyColor(color.h); // just keep the hue
    }

private:
    float hue;
}

static assert(isColor!HueOnlyColor == true, "This is all that is required to create a valid color type");
-------

If your _color type has template args, it may also be necessary to produce a
third convertColorImpl function that converts between instantiations with
different template args.


Authors:    Manu Evans
Copyright:  Copyright (c) 2015, Manu Evans.
License:    $(WEB boost.org/LICENSE_1_0.txt, Boost License 1.0)
Source:     $(PHOBOSSRC std/experimental/color/_package.d)
*/
module std.experimental.color;

import std.experimental.color.rgb;
import std.experimental.color.xyz : XYZ;
import std.experimental.normint;

import std.traits : isNumeric, isFloatingPoint, isSomeChar, Unqual;


/**
Detect whether $(D_INLINECODE T) is a color type compatible with std.experimental.color.
*/
enum isColor(T) = __traits(compiles, convertColor!(XYZ!float)(T.init));

///
unittest
{
    import std.experimental.color.rgb;
    import std.experimental.color.hsx;
    import std.experimental.color.xyz;

    static assert(isColor!RGB8 == true);
    static assert(isColor!(XYZ!float) == true);
    static assert(isColor!(HSL!float) == true);
    static assert(isColor!float == false);
}

/**
Detect whether $(D_INLINECODE T) is a valid color component type.
*/
enum isColorComponentType(T) = isFloatingPoint!T || is(T == NormalizedInt!U, U);

/**
Detect whether $(D_INLINECODE T) can represent a color component.
*/
enum isColorScalarType(T) = isNumeric!T || is(T == NormalizedInt!U, U);


// declare some common color types

/** 24 bit RGB color type with 8 bits per channel. */
alias RGB8 =    RGB!("rgb", ubyte);
/** 32 bit RGB color type with 8 bits per channel. */
alias RGBX8 =   RGB!("rgbx", ubyte);
/** 32 bit RGB + alpha color type with 8 bits per channel. */
alias RGBA8 =   RGB!("rgba", ubyte);

/** Floating point RGB color type. */
alias RGBf32 =  RGB!("rgb", float);
/** Floating point RGB + alpha color type. */
alias RGBAf32 = RGB!("rgba", float);

/** 24 bit BGR color type with 8 bits per channel. */
alias BGR8 =    RGB!("bgr", ubyte);
/** 32 bit BGR color type with 8 bits per channel. */
alias BGRX8 =   RGB!("bgrx", ubyte);
/** 32 bit BGR + alpha color type with 8 bits per channel. */
alias BGRA8 =   RGB!("bgra", ubyte);

/** 8 bit luminance-only color type. */
alias L8 =      RGB!("l", ubyte);
/** 8 bit alpha-only color type. */
alias A8 =      RGB!("a", ubyte);
/** 16 bit luminance + alpha color type with 8 bits per channel. */
alias LA8 =     RGB!("la", ubyte);

/** 16 bit signed UV color type with 8 bits per channel. */
alias UV8 =     RGB!("rg", byte);
/** 24 bit signed UVW color type with 8 bits per channel. */
alias UVW8 =    RGB!("rgb", byte);


/** Set of colors defined by X11, adopted by the W3C, SVG, and other popular libraries. */
enum Colors
{
    aliceBlue            = RGB8(240,248,255), /// <font color=aliceBlue>&#x25FC;</font>
    antiqueWhite         = RGB8(250,235,215), /// <font color=antiqueWhite>&#x25FC;</font>
    aqua                 = RGB8(0,255,255),   /// <font color=aqua>&#x25FC;</font>
    aquamarine           = RGB8(127,255,212), /// <font color=aquamarine>&#x25FC;</font>
    azure                = RGB8(240,255,255), /// <font color=azure>&#x25FC;</font>
    beige                = RGB8(245,245,220), /// <font color=beige>&#x25FC;</font>
    bisque               = RGB8(255,228,196), /// <font color=bisque>&#x25FC;</font>
    black                = RGB8(0,0,0),       /// <font color=black>&#x25FC;</font>
    blanchedAlmond       = RGB8(255,235,205), /// <font color=blanchedAlmond>&#x25FC;</font>
    blue                 = RGB8(0,0,255),     /// <font color=blue>&#x25FC;</font>
    blueViolet           = RGB8(138,43,226),  /// <font color=blueViolet>&#x25FC;</font>
    brown                = RGB8(165,42,42),   /// <font color=brown>&#x25FC;</font>
    burlyWood            = RGB8(222,184,135), /// <font color=burlyWood>&#x25FC;</font>
    cadetBlue            = RGB8(95,158,160),  /// <font color=cadetBlue>&#x25FC;</font>
    chartreuse           = RGB8(127,255,0),   /// <font color=chartreuse>&#x25FC;</font>
    chocolate            = RGB8(210,105,30),  /// <font color=chocolate>&#x25FC;</font>
    coral                = RGB8(255,127,80),  /// <font color=coral>&#x25FC;</font>
    cornflowerBlue       = RGB8(100,149,237), /// <font color=cornflowerBlue>&#x25FC;</font>
    cornsilk             = RGB8(255,248,220), /// <font color=cornsilk>&#x25FC;</font>
    crimson              = RGB8(220,20,60),   /// <font color=crimson>&#x25FC;</font>
    cyan                 = RGB8(0,255,255),   /// <font color=cyan>&#x25FC;</font>
    darkBlue             = RGB8(0,0,139),     /// <font color=darkBlue>&#x25FC;</font>
    darkCyan             = RGB8(0,139,139),   /// <font color=darkCyan>&#x25FC;</font>
    darkGoldenrod        = RGB8(184,134,11),  /// <font color=darkGoldenrod>&#x25FC;</font>
    darkGray             = RGB8(169,169,169), /// <font color=darkGray>&#x25FC;</font>
    darkGrey             = RGB8(169,169,169), /// <font color=darkGrey>&#x25FC;</font>
    darkGreen            = RGB8(0,100,0),     /// <font color=darkGreen>&#x25FC;</font>
    darkKhaki            = RGB8(189,183,107), /// <font color=darkKhaki>&#x25FC;</font>
    darkMagenta          = RGB8(139,0,139),   /// <font color=darkMagenta>&#x25FC;</font>
    darkOliveGreen       = RGB8(85,107,47),   /// <font color=darkOliveGreen>&#x25FC;</font>
    darkOrange           = RGB8(255,140,0),   /// <font color=darkOrange>&#x25FC;</font>
    darkOrchid           = RGB8(153,50,204),  /// <font color=darkOrchid>&#x25FC;</font>
    darkRed              = RGB8(139,0,0),     /// <font color=darkRed>&#x25FC;</font>
    darkSalmon           = RGB8(233,150,122), /// <font color=darkSalmon>&#x25FC;</font>
    darkSeaGreen         = RGB8(143,188,143), /// <font color=darkSeaGreen>&#x25FC;</font>
    darkSlateBlue        = RGB8(72,61,139),   /// <font color=darkSlateBlue>&#x25FC;</font>
    darkSlateGray        = RGB8(47,79,79),    /// <font color=darkSlateGray>&#x25FC;</font>
    darkSlateGrey        = RGB8(47,79,79),    /// <font color=darkSlateGrey>&#x25FC;</font>
    darkTurquoise        = RGB8(0,206,209),   /// <font color=darkTurquoise>&#x25FC;</font>
    darkViolet           = RGB8(148,0,211),   /// <font color=darkViolet>&#x25FC;</font>
    deepPink             = RGB8(255,20,147),  /// <font color=deepPink>&#x25FC;</font>
    deepSkyBlue          = RGB8(0,191,255),   /// <font color=deepSkyBlue>&#x25FC;</font>
    dimGray              = RGB8(105,105,105), /// <font color=dimGray>&#x25FC;</font>
    dimGrey              = RGB8(105,105,105), /// <font color=dimGrey>&#x25FC;</font>
    dodgerBlue           = RGB8(30,144,255),  /// <font color=dodgerBlue>&#x25FC;</font>
    fireBrick            = RGB8(178,34,34),   /// <font color=fireBrick>&#x25FC;</font>
    floralWhite          = RGB8(255,250,240), /// <font color=floralWhite>&#x25FC;</font>
    forestGreen          = RGB8(34,139,34),   /// <font color=forestGreen>&#x25FC;</font>
    fuchsia              = RGB8(255,0,255),   /// <font color=fuchsia>&#x25FC;</font>
    gainsboro            = RGB8(220,220,220), /// <font color=gainsboro>&#x25FC;</font>
    ghostWhite           = RGB8(248,248,255), /// <font color=ghostWhite>&#x25FC;</font>
    gold                 = RGB8(255,215,0),   /// <font color=gold>&#x25FC;</font>
    goldenrod            = RGB8(218,165,32),  /// <font color=goldenrod>&#x25FC;</font>
    gray                 = RGB8(128,128,128), /// <font color=gray>&#x25FC;</font>
    grey                 = RGB8(128,128,128), /// <font color=grey>&#x25FC;</font>
    green                = RGB8(0,128,0),     /// <font color=green>&#x25FC;</font>
    greenYellow          = RGB8(173,255,47),  /// <font color=greenYellow>&#x25FC;</font>
    honeydew             = RGB8(240,255,240), /// <font color=honeydew>&#x25FC;</font>
    hotPink              = RGB8(255,105,180), /// <font color=hotPink>&#x25FC;</font>
    indianRed            = RGB8(205,92,92),   /// <font color=indianRed>&#x25FC;</font>
    indigo               = RGB8(75,0,130),    /// <font color=indigo>&#x25FC;</font>
    ivory                = RGB8(255,255,240), /// <font color=ivory>&#x25FC;</font>
    khaki                = RGB8(240,230,140), /// <font color=khaki>&#x25FC;</font>
    lavender             = RGB8(230,230,250), /// <font color=lavender>&#x25FC;</font>
    lavenderBlush        = RGB8(255,240,245), /// <font color=lavenderBlush>&#x25FC;</font>
    lawnGreen            = RGB8(124,252,0),   /// <font color=lawnGreen>&#x25FC;</font>
    lemonChiffon         = RGB8(255,250,205), /// <font color=lemonChiffon>&#x25FC;</font>
    lightBlue            = RGB8(173,216,230), /// <font color=lightBlue>&#x25FC;</font>
    lightCoral           = RGB8(240,128,128), /// <font color=lightCoral>&#x25FC;</font>
    lightCyan            = RGB8(224,255,255), /// <font color=lightCyan>&#x25FC;</font>
    lightGoldenrodYellow = RGB8(250,250,210), /// <font color=lightGoldenrodYellow>&#x25FC;</font>
    lightGray            = RGB8(211,211,211), /// <font color=lightGray>&#x25FC;</font>
    lightGrey            = RGB8(211,211,211), /// <font color=lightGrey>&#x25FC;</font>
    lightGreen           = RGB8(144,238,144), /// <font color=lightGreen>&#x25FC;</font>
    lightPink            = RGB8(255,182,193), /// <font color=lightPink>&#x25FC;</font>
    lightSalmon          = RGB8(255,160,122), /// <font color=lightSalmon>&#x25FC;</font>
    lightSeaGreen        = RGB8(32,178,170),  /// <font color=lightSeaGreen>&#x25FC;</font>
    lightSkyBlue         = RGB8(135,206,250), /// <font color=lightSkyBlue>&#x25FC;</font>
    lightSlateGray       = RGB8(119,136,153), /// <font color=lightSlateGray>&#x25FC;</font>
    lightSlateGrey       = RGB8(119,136,153), /// <font color=lightSlateGrey>&#x25FC;</font>
    lightSteelBlue       = RGB8(176,196,222), /// <font color=lightSteelBlue>&#x25FC;</font>
    lightYellow          = RGB8(255,255,224), /// <font color=lightYellow>&#x25FC;</font>
    lime                 = RGB8(0,255,0),     /// <font color=lime>&#x25FC;</font>
    limeGreen            = RGB8(50,205,50),   /// <font color=limeGreen>&#x25FC;</font>
    linen                = RGB8(250,240,230), /// <font color=linen>&#x25FC;</font>
    magenta              = RGB8(255,0,255),   /// <font color=magenta>&#x25FC;</font>
    maroon               = RGB8(128,0,0),     /// <font color=maroon>&#x25FC;</font>
    mediumAquamarine     = RGB8(102,205,170), /// <font color=mediumAquamarine>&#x25FC;</font>
    mediumBlue           = RGB8(0,0,205),     /// <font color=mediumBlue>&#x25FC;</font>
    mediumOrchid         = RGB8(186,85,211),  /// <font color=mediumOrchid>&#x25FC;</font>
    mediumPurple         = RGB8(147,112,219), /// <font color=mediumPurple>&#x25FC;</font>
    mediumSeaGreen       = RGB8(60,179,113),  /// <font color=mediumSeaGreen>&#x25FC;</font>
    mediumSlateBlue      = RGB8(123,104,238), /// <font color=mediumSlateBlue>&#x25FC;</font>
    mediumSpringGreen    = RGB8(0,250,154),   /// <font color=mediumSpringGreen>&#x25FC;</font>
    mediumTurquoise      = RGB8(72,209,204),  /// <font color=mediumTurquoise>&#x25FC;</font>
    mediumVioletRed      = RGB8(199,21,133),  /// <font color=mediumVioletRed>&#x25FC;</font>
    midnightBlue         = RGB8(25,25,112),   /// <font color=midnightBlue>&#x25FC;</font>
    mintCream            = RGB8(245,255,250), /// <font color=mintCream>&#x25FC;</font>
    mistyRose            = RGB8(255,228,225), /// <font color=mistyRose>&#x25FC;</font>
    moccasin             = RGB8(255,228,181), /// <font color=moccasin>&#x25FC;</font>
    navajoWhite          = RGB8(255,222,173), /// <font color=navajoWhite>&#x25FC;</font>
    navy                 = RGB8(0,0,128),     /// <font color=navy>&#x25FC;</font>
    oldLace              = RGB8(253,245,230), /// <font color=oldLace>&#x25FC;</font>
    olive                = RGB8(128,128,0),   /// <font color=olive>&#x25FC;</font>
    oliveDrab            = RGB8(107,142,35),  /// <font color=oliveDrab>&#x25FC;</font>
    orange               = RGB8(255,165,0),   /// <font color=orange>&#x25FC;</font>
    orangeRed            = RGB8(255,69,0),    /// <font color=orangeRed>&#x25FC;</font>
    orchid               = RGB8(218,112,214), /// <font color=orchid>&#x25FC;</font>
    paleGoldenrod        = RGB8(238,232,170), /// <font color=paleGoldenrod>&#x25FC;</font>
    paleGreen            = RGB8(152,251,152), /// <font color=paleGreen>&#x25FC;</font>
    paleTurquoise        = RGB8(175,238,238), /// <font color=paleTurquoise>&#x25FC;</font>
    paleVioletRed        = RGB8(219,112,147), /// <font color=paleVioletRed>&#x25FC;</font>
    papayaWhip           = RGB8(255,239,213), /// <font color=papayaWhip>&#x25FC;</font>
    peachPuff            = RGB8(255,218,185), /// <font color=peachPuff>&#x25FC;</font>
    peru                 = RGB8(205,133,63),  /// <font color=peru>&#x25FC;</font>
    pink                 = RGB8(255,192,203), /// <font color=pink>&#x25FC;</font>
    plum                 = RGB8(221,160,221), /// <font color=plum>&#x25FC;</font>
    powderBlue           = RGB8(176,224,230), /// <font color=powderBlue>&#x25FC;</font>
    purple               = RGB8(128,0,128),   /// <font color=purple>&#x25FC;</font>
    red                  = RGB8(255,0,0),     /// <font color=red>&#x25FC;</font>
    rosyBrown            = RGB8(188,143,143), /// <font color=rosyBrown>&#x25FC;</font>
    royalBlue            = RGB8(65,105,225),  /// <font color=royalBlue>&#x25FC;</font>
    saddleBrown          = RGB8(139,69,19),   /// <font color=saddleBrown>&#x25FC;</font>
    salmon               = RGB8(250,128,114), /// <font color=salmon>&#x25FC;</font>
    sandyBrown           = RGB8(244,164,96),  /// <font color=sandyBrown>&#x25FC;</font>
    seaGreen             = RGB8(46,139,87),   /// <font color=seaGreen>&#x25FC;</font>
    seashell             = RGB8(255,245,238), /// <font color=seashell>&#x25FC;</font>
    sienna               = RGB8(160,82,45),   /// <font color=sienna>&#x25FC;</font>
    silver               = RGB8(192,192,192), /// <font color=silver>&#x25FC;</font>
    skyBlue              = RGB8(135,206,235), /// <font color=skyBlue>&#x25FC;</font>
    slateBlue            = RGB8(106,90,205),  /// <font color=slateBlue>&#x25FC;</font>
    slateGray            = RGB8(112,128,144), /// <font color=slateGray>&#x25FC;</font>
    slateGrey            = RGB8(112,128,144), /// <font color=slateGrey>&#x25FC;</font>
    snow                 = RGB8(255,250,250), /// <font color=snow>&#x25FC;</font>
    springGreen          = RGB8(0,255,127),   /// <font color=springGreen>&#x25FC;</font>
    steelBlue            = RGB8(70,130,180),  /// <font color=steelBlue>&#x25FC;</font>
    tan                  = RGB8(210,180,140), /// <font color=tan>&#x25FC;</font>
    teal                 = RGB8(0,128,128),   /// <font color=teal>&#x25FC;</font>
    thistle              = RGB8(216,191,216), /// <font color=thistle>&#x25FC;</font>
    tomato               = RGB8(255,99,71),   /// <font color=tomato>&#x25FC;</font>
    turquoise            = RGB8(64,224,208),  /// <font color=turquoise>&#x25FC;</font>
    violet               = RGB8(238,130,238), /// <font color=violet>&#x25FC;</font>
    wheat                = RGB8(245,222,179), /// <font color=wheat>&#x25FC;</font>
    white                = RGB8(255,255,255), /// <font color=white>&#x25FC;</font>
    whiteSmoke           = RGB8(245,245,245), /// <font color=whiteSmoke>&#x25FC;</font>
    yellow               = RGB8(255,255,0),   /// <font color=yellow>&#x25FC;</font>
    yellowGreen          = RGB8(154,205,50)   /// <font color=yellowGreen>&#x25FC;</font>
}


/**
Convert between _color types.

Conversion is always supported between any pair of valid _color types.
Colour types usually implement only direct conversion between their immediate 'parent' _color type.
In the case of distantly related colors, convertColor will follow a conversion path via
intermediate representations such that it is able to perform the conversion.

For instance, a conversion from HSV to Lab necessary follows the conversion path: HSV -> RGB -> XYZ -> Lab.

Params: color = A _color in some source format.
Returns: $(D_INLINECODE color) converted to the target format.
*/
To convertColor(To, From)(From color) @safe pure nothrow @nogc
{
    // cast along a conversion path to reach our target conversion
    alias Path = ConversionPath!(From, To);

    // no conversion is necessary
    static if (Path.length == 0)
        return color;
    else static if (Path.length > 1)
    {
        // we need to recurse to trace a path via the first common ancestor
        static if (__traits(compiles, From.convertColorImpl!(Path[0])(color)))
            return convertColor!To(From.convertColorImpl!(Path[0])(color));
        else
            return convertColor!To(To.convertColorImpl!(Path[0])(color));
    }
    else
    {
        static if (__traits(compiles, From.convertColorImpl!(Path[0])(color)))
            return From.convertColorImpl!(Path[0])(color);
        else
            return To.convertColorImpl!(Path[0])(color);
    }
}
///
unittest
{
    assert(convertColor!(RGBA8)(convertColor!(XYZ!float)(RGBA8(0xFF, 0xFF, 0xFF, 0xFF))) == RGBA8(0xFF, 0xFF, 0xFF, 0));
}


/**
Create a color from a string.

Params: str = A string representation of a _color.$(BR)
              May be a hex _color in the standard forms: (#/$)rgb/argb/rrggbb/aarrggbb$(BR)
              May also be the name of any _color from the $(D_INLINECODE Colors) enum.
Returns: The _color expressed by the string.
Throws: Throws $(D_INLINECODE std.conv.ConvException) if the string is invalid.
*/
Color colorFromString(Color = RGB8)(scope const(char)[] str) pure @safe
{
    import std.conv : ConvException;

    uint error;
    auto r = colorFromStringImpl(str, error);

    if (error > 0)
    {
        if (error == 1)
            throw new ConvException("Hex string has invalid length");
        throw new ConvException("String is not a valid color");
    }

    return cast(Color)r;
}

/**
Create a color from a string.

This version of the function is $(D_INLINECODE nothrow), $(D_INLINECODE @nogc).

Params: str = A string representation of a _color.$(BR)
              May be a hex _color in the standard forms: (#/$)rgb/argb/rrggbb/aarrggbb$(BR)
              May also be the name of any _color from the $(D_INLINECODE Colors) enum.
        color = Receives the _color expressed by the string.
Returns: $(D_INLINECODE true) if a _color was successfully parsed from the string, $(D_INLINECODE false) otherwise.
*/
bool colorFromString(Color = RGB8)(scope const(char)[] str, out Color color) pure nothrow @safe @nogc
{
    uint error;
    auto r = colorFromStringImpl(str, error);
    if (!error)
    {
        color = cast(Color)r;
        return true;
    }
    return false;
}

///
unittest
{
    // common hex formats supported:

    // 3 digits
    assert(colorFromString("F80") == RGB8(0xFF, 0x88, 0x00));
    assert(colorFromString("#F80") == RGB8(0xFF, 0x88, 0x00));
    assert(colorFromString("$F80") == RGB8(0xFF, 0x88, 0x00));

    // 6 digits
    assert(colorFromString("FF8000") == RGB8(0xFF, 0x80, 0x00));
    assert(colorFromString("#FF8000") == RGB8(0xFF, 0x80, 0x00));
    assert(colorFromString("$FF8000") == RGB8(0xFF, 0x80, 0x00));

    // 4/8 digita (/w alpha)
    assert(colorFromString!RGBA8("#8C41") == RGBA8(0xCC, 0x44, 0x11, 0x88));
    assert(colorFromString!RGBA8("#80CC4401") == RGBA8(0xCC, 0x44, 0x01, 0x80));

    // named colors (case-insensitive)
    assert(colorFromString("red") == RGB8(0xFF, 0x0, 0x0));
    assert(colorFromString("WHITE") == RGB8(0xFF, 0xFF, 0xFF));
    assert(colorFromString("LightGoldenrodYellow") == RGB8(250,250,210));

    // parse failure
    RGB8 c;
    assert(colorFromString("Ultraviolet", c) == false);
}


package:

import std.traits : isInstanceOf, TemplateOf;
import std.typetuple : TypeTuple;

RGBA8 colorFromStringImpl(scope const(char)[] str, out uint error) pure nothrow @safe @nogc
{
    static const(char)[] getHex(const(char)[] hex) pure nothrow @nogc @safe
    {
        if (hex.length > 0 && (hex[0] == '#' || hex[0] == '$'))
            hex = hex[1..$];
        foreach (i; 0 .. hex.length)
        {
            if (!(hex[i] >= '0' && hex[i] <= '9' || hex[i] >= 'a' && hex[i] <= 'f' || hex[i] >= 'A' && hex[i] <= 'F'))
                return null;
        }
        return hex;
    }

    const(char)[] hex = getHex(str);
    if (hex)
    {
        static ubyte val(char c) pure nothrow @nogc @safe
        {
            if (c >= '0' && c <= '9')
                return cast(ubyte)(c - '0');
            else if (c >= 'a' && c <= 'f')
                return cast(ubyte)(c - 'a' + 10);
            else
                return cast(ubyte)(c - 'A' + 10);
        }

        if (hex.length == 3)
        {
            ubyte r = val(hex[0]);
            ubyte g = val(hex[1]);
            ubyte b = val(hex[2]);
            return RGBA8(cast(ubyte)(r | (r << 4)), cast(ubyte)(g | (g << 4)), cast(ubyte)(b | (b << 4)), 0);
        }
        if (hex.length == 4)
        {
            ubyte a = val(hex[0]);
            ubyte r = val(hex[1]);
            ubyte g = val(hex[2]);
            ubyte b = val(hex[3]);
            return RGBA8(cast(ubyte)(r | (r << 4)), cast(ubyte)(g | (g << 4)), cast(ubyte)(b | (b << 4)), cast(ubyte)(a | (a << 4)));
        }
        if (hex.length == 6)
        {
            ubyte r = cast(ubyte)(val(hex[0]) << 4) | val(hex[1]);
            ubyte g = cast(ubyte)(val(hex[2]) << 4) | val(hex[3]);
            ubyte b = cast(ubyte)(val(hex[4]) << 4) | val(hex[5]);
            return RGBA8(r, g, b, 0);
        }
        if (hex.length == 8)
        {
            ubyte a = cast(ubyte)(val(hex[0]) << 4) | val(hex[1]);
            ubyte r = cast(ubyte)(val(hex[2]) << 4) | val(hex[3]);
            ubyte g = cast(ubyte)(val(hex[4]) << 4) | val(hex[5]);
            ubyte b = cast(ubyte)(val(hex[6]) << 4) | val(hex[7]);
            return RGBA8(r, g, b, a);
        }

        error = 1;
        return RGBA8();
    }

    // need to write a string compare, since phobos is not nothrow @nogc, etc...
    static bool streqi(const(char)[] a, const(char)[] b)
    {
        if (a.length != b.length)
            return false;
        foreach(i; 0 .. a.length)
        {
            auto c1 = (a[i] >= 'A' && a[i] <= 'Z') ? a[i] | 0x20 : a[i];
            auto c2 = (b[i] >= 'A' && b[i] <= 'Z') ? b[i] | 0x20 : b[i];
            if(c1 != c2)
                return false;
        }
        return true;
    }

    foreach (k; __traits(allMembers, Colors))
    {
        if (streqi(str, k))
            mixin("return cast(RGBA8)Colors." ~ k ~ ";");
    }

    error = 2;
    return RGBA8();
}

// find the fastest type to do format conversion without losing precision
template WorkingType(From, To)
{
    static if (isFloatingPoint!From && isFloatingPoint!To)
    {
        static if (From.sizeof > To.sizeof)
            alias WorkingType = From;
        else
            alias WorkingType = To;
    }
    else static if (isFloatingPoint!To)
        alias WorkingType = To;
    else static if (isFloatingPoint!From)
        alias WorkingType = FloatTypeFor!To;
    else
    {
        // small integer types can use float and not lose precision
        static if (From.sizeof <= 2 && To.sizeof <= 2)
            alias WorkingType = float;
        else
            alias WorkingType = double;
    }
}

private template isParentType(Parent, Of)
{
    static if (!is(Of.ParentColor))
        enum isParentType = false;
    else static if (isInstanceOf!(TemplateOf!Parent, Of.ParentColor))
        enum isParentType = true;
    else
        enum isParentType = isParentType!(Parent, Of.ParentColor);
}

private template FindPath(From, To)
{
    static if (isInstanceOf!(TemplateOf!To, From))
        alias FindPath = TypeTuple!(To);
    else static if (isParentType!(From, To))
        alias FindPath = TypeTuple!(FindPath!(From, To.ParentColor), To);
    else static if (is(From.ParentColor))
        alias FindPath = TypeTuple!(From, FindPath!(From.ParentColor, To));
    else
        static assert(false, "Shouldn't be here!");
}

// find the conversion path from one distant type to another
template ConversionPath(From, To)
{
    static if (is(Unqual!From == Unqual!To))
        alias ConversionPath = TypeTuple!();
    else
    {
        alias Path = FindPath!(Unqual!From, Unqual!To);
        static if (Path.length == 1 && !is(Path[0] == From))
            alias ConversionPath = Path;
        else
            alias ConversionPath = Path[1..$];
    }
}
unittest
{
    import std.experimental.color.hsx;
    import std.experimental.color.lab;
    import std.experimental.color.xyz;

    // dest indirect conversion paths
    static assert(is(ConversionPath!(XYZ!float, const XYZ!float) == TypeTuple!()));
    static assert(is(ConversionPath!(RGB8, RGB8) == TypeTuple!()));

    static assert(is(ConversionPath!(XYZ!float, XYZ!double) == TypeTuple!(XYZ!double)));
    static assert(is(ConversionPath!(xyY!float, XYZ!float) == TypeTuple!(XYZ!float)));
    static assert(is(ConversionPath!(xyY!float, XYZ!double) == TypeTuple!(XYZ!double)));
    static assert(is(ConversionPath!(XYZ!float, xyY!float) == TypeTuple!(xyY!float)));
    static assert(is(ConversionPath!(XYZ!float, xyY!double) == TypeTuple!(xyY!double)));

    static assert(is(ConversionPath!(HSL!float, XYZ!float) == TypeTuple!(RGB!("rgb", float, false), XYZ!float)));
    static assert(is(ConversionPath!(LCh!float, HSI!double) == TypeTuple!(Lab!float, XYZ!double, RGB!("rgb", double), HSI!double)));
    static assert(is(ConversionPath!(shared HSI!double, immutable LCh!float) == TypeTuple!(RGB!("rgb", double), XYZ!float, Lab!float, LCh!float)));
}

// build mixin code to perform expresions per-element
template ComponentExpression(string expression, string component, string op)
{
    template BuildExpression(string e, string c, string op)
    {
        static if (e.length == 0)
            enum BuildExpression = "";
        else static if (e[0] == '_')
            enum BuildExpression = c ~ BuildExpression!(e[1..$], c, op);
        else static if (e[0] == '#')
            enum BuildExpression = op ~ BuildExpression!(e[1..$], c, op);
        else
            enum BuildExpression = e[0] ~ BuildExpression!(e[1..$], c, op);
    }
    enum ComponentExpression =
        "static if (is(typeof(this." ~ component ~ ")))" ~ "\n\t" ~
            BuildExpression!(expression, component, op);
}
