// Written in the D programming language.

/**
    This package contains implementations of various common _color types.
    Types are supplied for various _color spaces, along with _color space
    conversion functionality.

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
/** Floating point UV color type. */
alias UVf32 =   RGB!("rg", float);
/** Floating point UVW color type. */
alias UVWf32 =  RGB!("rgb", float);


/** Set of colors defined by X11, adopted by the W3C, SVG, and other popular libraries. */
enum Colors
{
    aliceBlue            = RGB8(240,248,255), ///
    antiqueWhite         = RGB8(250,235,215), ///
    aqua                 = RGB8(0,255,255),   ///
    aquamarine           = RGB8(127,255,212), ///
    azure                = RGB8(240,255,255), ///
    beige                = RGB8(245,245,220), ///
    bisque               = RGB8(255,228,196), ///
    black                = RGB8(0,0,0),       ///
    blanchedAlmond       = RGB8(255,235,205), ///
    blue                 = RGB8(0,0,255),     ///
    blueViolet           = RGB8(138,43,226),  ///
    brown                = RGB8(165,42,42),   ///
    burlyWood            = RGB8(222,184,135), ///
    cadetBlue            = RGB8(95,158,160),  ///
    chartreuse           = RGB8(127,255,0),   ///
    chocolate            = RGB8(210,105,30),  ///
    coral                = RGB8(255,127,80),  ///
    cornflowerBlue       = RGB8(100,149,237), ///
    cornsilk             = RGB8(255,248,220), ///
    crimson              = RGB8(220,20,60),   ///
    cyan                 = RGB8(0,255,255),   ///
    darkBlue             = RGB8(0,0,139),     ///
    darkCyan             = RGB8(0,139,139),   ///
    darkGoldenrod        = RGB8(184,134,11),  ///
    darkGray             = RGB8(169,169,169), ///
    darkGrey             = RGB8(169,169,169), ///
    darkGreen            = RGB8(0,100,0),     ///
    darkKhaki            = RGB8(189,183,107), ///
    darkMagenta          = RGB8(139,0,139),   ///
    darkOliveGreen       = RGB8(85,107,47),   ///
    darkOrange           = RGB8(255,140,0),   ///
    darkOrchid           = RGB8(153,50,204),  ///
    darkRed              = RGB8(139,0,0),     ///
    darkSalmon           = RGB8(233,150,122), ///
    darkSeaGreen         = RGB8(143,188,143), ///
    darkSlateBlue        = RGB8(72,61,139),   ///
    darkSlateGray        = RGB8(47,79,79),    ///
    darkSlateGrey        = RGB8(47,79,79),    ///
    darkTurquoise        = RGB8(0,206,209),   ///
    darkViolet           = RGB8(148,0,211),   ///
    deepPink             = RGB8(255,20,147),  ///
    deepSkyBlue          = RGB8(0,191,255),   ///
    dimGray              = RGB8(105,105,105), ///
    dimGrey              = RGB8(105,105,105), ///
    dodgerBlue           = RGB8(30,144,255),  ///
    fireBrick            = RGB8(178,34,34),   ///
    floralWhite          = RGB8(255,250,240), ///
    forestGreen          = RGB8(34,139,34),   ///
    fuchsia              = RGB8(255,0,255),   ///
    gainsboro            = RGB8(220,220,220), ///
    ghostWhite           = RGB8(248,248,255), ///
    gold                 = RGB8(255,215,0),   ///
    goldenrod            = RGB8(218,165,32),  ///
    gray                 = RGB8(128,128,128), ///
    grey                 = RGB8(128,128,128), ///
    green                = RGB8(0,128,0),     ///
    greenYellow          = RGB8(173,255,47),  ///
    honeydew             = RGB8(240,255,240), ///
    hotPink              = RGB8(255,105,180), ///
    indianRed            = RGB8(205,92,92),   ///
    indigo               = RGB8(75,0,130),    ///
    ivory                = RGB8(255,255,240), ///
    khaki                = RGB8(240,230,140), ///
    lavender             = RGB8(230,230,250), ///
    lavenderBlush        = RGB8(255,240,245), ///
    lawnGreen            = RGB8(124,252,0),   ///
    lemonChiffon         = RGB8(255,250,205), ///
    lightBlue            = RGB8(173,216,230), ///
    lightCoral           = RGB8(240,128,128), ///
    lightCyan            = RGB8(224,255,255), ///
    lightGoldenrodYellow = RGB8(250,250,210), ///
    lightGray            = RGB8(211,211,211), ///
    lightGrey            = RGB8(211,211,211), ///
    lightGreen           = RGB8(144,238,144), ///
    lightPink            = RGB8(255,182,193), ///
    lightSalmon          = RGB8(255,160,122), ///
    lightSeaGreen        = RGB8(32,178,170),  ///
    lightSkyBlue         = RGB8(135,206,250), ///
    lightSlateGray       = RGB8(119,136,153), ///
    lightSlateGrey       = RGB8(119,136,153), ///
    lightSteelBlue       = RGB8(176,196,222), ///
    lightYellow          = RGB8(255,255,224), ///
    lime                 = RGB8(0,255,0),     ///
    limeGreen            = RGB8(50,205,50),   ///
    linen                = RGB8(250,240,230), ///
    magenta              = RGB8(255,0,255),   ///
    maroon               = RGB8(128,0,0),     ///
    mediumAquamarine     = RGB8(102,205,170), ///
    mediumBlue           = RGB8(0,0,205),     ///
    mediumOrchid         = RGB8(186,85,211),  ///
    mediumPurple         = RGB8(147,112,219), ///
    mediumSeaGreen       = RGB8(60,179,113),  ///
    mediumSlateBlue      = RGB8(123,104,238), ///
    mediumSpringGreen    = RGB8(0,250,154),   ///
    mediumTurquoise      = RGB8(72,209,204),  ///
    mediumVioletRed      = RGB8(199,21,133),  ///
    midnightBlue         = RGB8(25,25,112),   ///
    mintCream            = RGB8(245,255,250), ///
    mistyRose            = RGB8(255,228,225), ///
    moccasin             = RGB8(255,228,181), ///
    navajoWhite          = RGB8(255,222,173), ///
    navy                 = RGB8(0,0,128),     ///
    oldLace              = RGB8(253,245,230), ///
    olive                = RGB8(128,128,0),   ///
    oliveDrab            = RGB8(107,142,35),  ///
    orange               = RGB8(255,165,0),   ///
    orangeRed            = RGB8(255,69,0),    ///
    orchid               = RGB8(218,112,214), ///
    paleGoldenrod        = RGB8(238,232,170), ///
    paleGreen            = RGB8(152,251,152), ///
    paleTurquoise        = RGB8(175,238,238), ///
    paleVioletRed        = RGB8(219,112,147), ///
    papayaWhip           = RGB8(255,239,213), ///
    peachPuff            = RGB8(255,218,185), ///
    peru                 = RGB8(205,133,63),  ///
    pink                 = RGB8(255,192,203), ///
    plum                 = RGB8(221,160,221), ///
    powderBlue           = RGB8(176,224,230), ///
    purple               = RGB8(128,0,128),   ///
    red                  = RGB8(255,0,0),     ///
    rosyBrown            = RGB8(188,143,143), ///
    royalBlue            = RGB8(65,105,225),  ///
    saddleBrown          = RGB8(139,69,19),   ///
    salmon               = RGB8(250,128,114), ///
    sandyBrown           = RGB8(244,164,96),  ///
    seaGreen             = RGB8(46,139,87),   ///
    seashell             = RGB8(255,245,238), ///
    sienna               = RGB8(160,82,45),   ///
    silver               = RGB8(192,192,192), ///
    skyBlue              = RGB8(135,206,235), ///
    slateBlue            = RGB8(106,90,205),  ///
    slateGray            = RGB8(112,128,144), ///
    slateGrey            = RGB8(112,128,144), ///
    snow                 = RGB8(255,250,250), ///
    springGreen          = RGB8(0,255,127),   ///
    steelBlue            = RGB8(70,130,180),  ///
    tan                  = RGB8(210,180,140), ///
    teal                 = RGB8(0,128,128),   ///
    thistle              = RGB8(216,191,216), ///
    tomato               = RGB8(255,99,71),   ///
    turquoise            = RGB8(64,224,208),  ///
    violet               = RGB8(238,130,238), ///
    wheat                = RGB8(245,222,179), ///
    white                = RGB8(255,255,255), ///
    whiteSmoke           = RGB8(245,245,245), ///
    yellow               = RGB8(255,255,0),   ///
    yellowGreen          = RGB8(154,205,50)   ///
}


/**
Convert between color types.
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
May be a hex color in the standard forms: (#/$/0x)rgb/argb/rrggbb/aarrggbb
May also be the name of any color from the $(D_INLINECODE Colors) enum.
*/
Color colorFromString(Color = RGB8)(const(char)[] str) pure @safe
{
    return cast(Color)colorFromStringImpl(str);
}
///
unittest
{
    // common hex formats supported:

    // 3 digits
    static assert(colorFromString("F80") == RGB8(0xFF, 0x88, 0x00));
    static assert(colorFromString("#F80") == RGB8(0xFF, 0x88, 0x00));
    static assert(colorFromString("$F80") == RGB8(0xFF, 0x88, 0x00));
    static assert(colorFromString("0xF80") == RGB8(0xFF, 0x88, 0x00));

    // 6 digits
    static assert(colorFromString("FF8000") == RGB8(0xFF, 0x80, 0x00));
    static assert(colorFromString("#FF8000") == RGB8(0xFF, 0x80, 0x00));
    static assert(colorFromString("$FF8000") == RGB8(0xFF, 0x80, 0x00));
    static assert(colorFromString("0xFF8000") == RGB8(0xFF, 0x80, 0x00));

    // 4/8 digita (/w alpha)
    static assert(colorFromString!RGBA8("#8C41") == RGBA8(0xCC, 0x44, 0x11, 0x88));
    static assert(colorFromString!RGBA8("#80CC4401") == RGBA8(0xCC, 0x44, 0x01, 0x80));

    // named colors (case-insensitive)
    static assert(colorFromString("red") == RGB8(0xFF, 0x0, 0x0));
    static assert(colorFromString("WHITE") == RGB8(0xFF, 0xFF, 0xFF));
    static assert(colorFromString("LightGoldenrodYellow") == RGB8(250,250,210));
}


package:

import std.traits : isInstanceOf, TemplateOf;
import std.typetuple : TypeTuple;


RGBA8 colorFromStringImpl(const(char)[] str) pure @safe
{
    static const(char)[] getHex(const(char)[] hex) pure nothrow @nogc @safe
    {
        if (hex.length > 0 && (hex[0] == '#' || hex[0] == '$'))
            hex = hex[1..$];
        else if (hex.length > 1 && (hex[0] == '0' && hex[1] == 'x'))
            hex = hex[2..$];
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

        throw new Exception("Hex string has invalid length");
    }

    foreach (k; __traits(allMembers, Colors))
    {
        import std.uni : icmp;
        if (str.icmp(k) == 0)
            mixin("return cast(RGBA8)Colors." ~ k ~ ";");
    }

    throw new Exception("String is not a valid color");
}

// try and use the preferred float type
// if the int type exceeds the preferred float precision, we'll upgrade the float
template FloatTypeFor(IntType, RequestedFloat = float)
{
    static if (IntType.sizeof > 2)
        alias FloatTypeFor = double;
    else
        alias FloatTypeFor = RequestedFloat;
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
