// Written in the D programming language.

/* Contains elementary mathematical functions, and low-level
 * floating-point operations for X86 processors.
 *
 * All of these functions are subject to change, and are intended
 * for internal use only.
 *
 * Copyright: Copyright The D Language Foundation 2000 - 2011.
 * License:   $(HTTP www.boost.org/LICENSE_1_0.txt, Boost License 1.0).
 * Authors:   $(HTTP digitalmars.com, Walter Bright), Don Clugston,
 *            Conversion of CEPHES math library to D by Iain Buclaw and David Nadlinger
 * Source: $(PHOBOSSRC std/internal/math/mathx86.d)
 */
module std.internal.math.mathx86;

version (D_InlineAsm_X86)
{
    version = InlineAsm_X86_Any;
}
else version (D_InlineAsm_X86_64)
{
    version = InlineAsm_X86_Any;
}

version (InlineAsm_X86_Any):

/////////////////////////////////////////////////////////////////////////////

real tan()(real x) @trusted pure nothrow @nogc // TODO: @safe
{
    version (D_InlineAsm_X86)
    {
    asm pure nothrow @nogc
    {
        fld     x[EBP]                  ; // load theta
        fxam                            ; // test for oddball values
        fstsw   AX                      ;
        sahf                            ;
        jc      trigerr                 ; // x is NAN, infinity, or empty
                                          // 387's can handle subnormals
SC18:   fptan                           ;
        fstsw   AX                      ;
        sahf                            ;
        jnp     Clear1                  ; // C2 = 1 (x is out of range)

        // Do argument reduction to bring x into range
        fldpi                           ;
        fxch                            ;
SC17:   fprem1                          ;
        fstsw   AX                      ;
        sahf                            ;
        jp      SC17                    ;
        fstp    ST(1)                   ; // remove pi from stack
        jmp     SC18                    ;

trigerr:
        jnp     Lret                    ; // if theta is NAN, return theta
        fstp    ST(0)                   ; // dump theta
    }
    return real.nan;

Clear1: asm pure nothrow @nogc{
        fstp    ST(0)                   ; // dump X, which is always 1
    }

Lret: {}
    }
    else version (D_InlineAsm_X86_64)
    {
        version (Win64)
        {
            asm pure nothrow @nogc
            {
                fld     real ptr [RCX]  ; // load theta
            }
        }
        else
        {
            asm pure nothrow @nogc
            {
                fld     x[RBP]          ; // load theta
            }
        }
    asm pure nothrow @nogc
    {
        fxam                            ; // test for oddball values
        fstsw   AX                      ;
        test    AH,1                    ;
        jnz     trigerr                 ; // x is NAN, infinity, or empty
                                          // 387's can handle subnormals
SC18:   fptan                           ;
        fstsw   AX                      ;
        test    AH,4                    ;
        jz      Clear1                  ; // C2 = 1 (x is out of range)

        // Do argument reduction to bring x into range
        fldpi                           ;
        fxch                            ;
SC17:   fprem1                          ;
        fstsw   AX                      ;
        test    AH,4                    ;
        jnz     SC17                    ;
        fstp    ST(1)                   ; // remove pi from stack
        jmp     SC18                    ;

trigerr:
        test    AH,4                    ;
        jz      Lret                    ; // if theta is NAN, return theta
        fstp    ST(0)                   ; // dump theta
    }
    return real.nan;

Clear1: asm pure nothrow @nogc{
        fstp    ST(0)                   ; // dump X, which is always 1
    }

Lret: {}
    }
    else
        static assert(0);
}
