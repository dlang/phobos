// Written in the D programming language.

/**
 * Contains elementary mathematical functions, and low-level
 * floating-point operations.
 *
 * All of these functions are subject to change, and are intended
 * for internal use only.
 *
 * Copyright: Copyright The D Language Foundation 2000 - 2011.
 * License:   $(HTTP www.boost.org/LICENSE_1_0.txt, Boost License 1.0).
 * Authors:   $(HTTP digitalmars.com, Walter Bright), Don Clugston,
 *            Conversion of CEPHES math library to D by Iain Buclaw and David Nadlinger
 * Source: $(PHOBOSSRC std/internal/math/mathcore.d)
 */
module std.internal.math.mathcore;

version (D_InlineAsm_X86)
{
    version = InlineAsm_X86_Any;
}
else version (D_InlineAsm_X86_64)
{
    version = InlineAsm_X86_Any;
}

version (InlineAsm_X86_Any)
{
    static import std.internal.math.mathx86;
}
static import std.internal.math.mathnoasm;

/////////////////////////////////////////////////////////////////////////////

T tan(T)(T x) @safe pure nothrow @nogc
{
    if (__ctfe)
        return std.internal.math.mathnoasm.tan(cast(real) x);
    else static if (is(T == real))
    {
        version (InlineAsm_X86_Any)
            return std.internal.math.mathx86.tan(x);
        else
            return std.internal.math.mathnoasm.tan(x);
    }
    else
        return std.internal.math.mathnoasm.tan(x);
}
