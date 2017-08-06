module std.experimental.simd;


pure:
nothrow:
@nogc:
@safe:


///////////////////////////////////////////////////////////////////////////////
// Version mess

static if(__ctfe)
{
    version = NoSIMD; // __ctfe can't SIMD, we'll need to emulate
}
else version(X86)
{
    version(DigitalMars)
        version = NoSIMD; // DMD-x86 does not support SIMD
    else
        version = X86_OR_X64;
}
else version(X86_64)
    version = X86_OR_X64;
else version(PPC)
    version = PowerPC;
else version(PPC64)
    version = PowerPC;
else
    version = NoSIMD;

version(GNU)
    version = GNU_OR_LDC;
version(LDC)
    version = GNU_OR_LDC;


///////////////////////////////////////////////////////////////////////////////
// Platform specific imports

version(DigitalMars)
{
    // DMD intrinsics
}
else version(GNU)
{
    // GDC intrinsics
    import gcc.builtins;
}

public import core.simd;
import std.traits, std.typetuple;


///////////////////////////////////////////////////////////////////////////////
// Define available versions of vector hardware

version(X86_OR_X64)
{
    enum SIMDVer
    {
        SSE,
        SSE2,
        SSE3,   // Later Pentium4 + Athlon64
        SSSE3,  // Introduced in Intel 'Core' series, AMD 'Bobcat'
        SSE41,  // (Intel) Introduced in 45nm 'Core' series
        SSE42,  // (Intel) Introduced in i7
        SSE4a,  // (AMD) Introduced to 'Bobcat' (includes SSSE3 and below)
        SSE5,   // (AMD) XOP, FMA4 and CVT16. Introduced to 'Bulldozer' (includes ALL prior architectures)
        AVX,    // 256bit, 16regs, 3 operand opcodes, no integer
        AVX2,   // integer support for AVX
        AVX512  // 512bit, 32regs
    }

    // we source this from the compiler flags, ie. -msse2 for instance
    immutable SIMDVer simdVer = SIMDVer.SSE2;

    enum string[SIMDVer.max+1] targetNames =
    [
        "sse",
        "sse2",
        "sse3",
        "ssse3",
        "sse4.1",
        "sse4.2",
        "sse4a",
        "sse5",
        "avx",
        "avx2",
        "avx512"
    ];
}
else version(ARM)
{
    enum SIMDVer
    {
        VFP,    // Should we implement this? it's deprecated on modern ARM chips
        NEON,   // Added to Cortex-A8, Snapdragon
        VFPv4   // Added to Cortex-A15
    }

    immutable SIMDVer simdVer = SIMDVer.NEON;

    enum string[SIMDVer.max+1] targetNames =
    [
        "", "", "" // TODO...
    ];
}
else version(PowerPC)
{
    enum SIMDVer
    {
        VMX,
        VMX128,         // Extended register file (128 regs), reduced integer support, and some awesome bonus opcodes
        PairedSingle    // Used on Nintendo platforms
    }

    immutable SIMDVer simdVer = SIMDVer.VMX;

    enum string[SIMDVer.max+1] targetNames =
    [
        "altivec",
        "", // 'vmx128' doesn't exist...
        ""
    ];
}
else version(MIPS_SIMD)
{
    enum SIMDVer
    {
        Unknown,

        PairedSingle,   // 32bit pairs in 64bit regs
        MIPS3D,         // Licensed MIPS SIMD extension
        MDMX,           // More comprehensive SIMD extension
        XBurst1,        // XBurst1 custom SIMD (Android)
        PSP_VFPU        // SIMD extension used by the Playstation Portable
    }

    immutable SIMDVer simdVer = SIMDVer.Unknown;

    enum string[SIMDVer.max+1] targetNames =
    [
        "", "", "", "", "", "" // TODO...
    ];
}
else
{
    // TODO: it would be nice to provide a fallback for __ctfe and hardware with no SIMD unit...

    enum SIMDVer
    {
        None
    }

    immutable SIMDVer simdVer = SIMDVer.None;

    enum string[SIMDVer.max+1] targetNames =
    [
        ""
    ];
}


// TODO: should this go in core.simd? or even std.range?
template ElementType(T : __vector(V[N]), V, size_t N) if(isSIMDVector!T)
{
    alias Impl(T) = V;
    alias ElementType = std.traits.ModifyTypePreservingSTC!(Impl, OriginalType!T);
}


///////////////////////////////////////////////////////////////////////////////
// Public API
///////////////////////////////////////////////////////////////////////////////


///////////////////////////////////////////////////////////////////////////////
// Load and store

// load scalar into all components (!! or just X?). Note: SLOW on many architectures
Vector!T loadScalar(T, SIMDVer Ver = simdVer)(BaseType!T s)
{
    return loadScalar!(T, Ver)(&s);
}

// load scaler from memory
T loadScalar(T, SIMDVer Ver = simdVer)(BaseType!T* pS) if(isSIMDVector!T)
{
    version(X86_OR_X64)
    {
        version(DigitalMars)
        {
            static assert(0, "TODO");
        }
        else version(GNU)
        {
            static if(isOfType(T, float4))
                return __builtin_ia32_loadss(pS);
            else static if(isOfType(T, double2))
                return __builtin_ia32_loadddup(pV);
            else
                static assert(0, "TODO");
        }
        else version(LDC)
        {
            //TODO: non-optimal
            T r = 0;
            r = ldcsimd.insertelement!(T, 0)(r, *pS);
            return r;
        }
    }
    else version(ARM)
    {
        static assert(0, "TODO");
    }
    else
    {
        static assert(0, "Unsupported on this architecture");
    }
}

// load vector from an unaligned address
T loadUnaligned(T, SIMDVer Ver = simdVer)(BaseType!T* pV) @trusted
{
    version(X86_OR_X64)
    {
        version(DigitalMars)
        {
            static assert(0, "TODO");
        }
        else version(GNU)
        {
            static if(isOfType!(T, float4))
                return __builtin_ia32_loadups(pV);
            else static if(isOfType!(T, double2))
                return __builtin_ia32_loadupd(pV);
            else
                return cast(Vector!T)__builtin_ia32_loaddqu(cast(char*)pV);
        }
        else version(LDC)
            return ldcsimd.loadUnaligned!T(pV);
    }
    else version(ARM)
    {
        static assert(0, "TODO");
    }
    else
    {
        static assert(0, "Unsupported on this architecture");
    }
}

// return the X element in a scalar register
BaseType!T getScalar(SIMDVer Ver = simdVer, T)(T v) if(isSIMDVector!T)
{
    version(X86_OR_X64)
    {
        version(DigitalMars)
        {
            static assert(0, "TODO");
        }
        else version(GNU)
        {
            static if(Ver >= SIMDVer.SSE41 && !is16bitElement!T)
            {
                static if(isOfType!(T, float4))
                    return __builtin_ia32_vec_ext_v4sf(v, 0);
                static if(isOfType!(T, double2))
                    return __builtin_ia32_vec_ext_v2df(v, 0);
                else static if(is64bitElement!T)
                    return __builtin_ia32_vec_ext_v2di(v, 0);
                else static if(is32bitElement!T)
                    return __builtin_ia32_vec_ext_v4si(v, 0);
//                else static if(is16bitElement!T)
//                    return __builtin_ia32_vec_ext_v8hi(v, 0); // does this opcode exist??
                else static if(is8bitElement!T)
                    return __builtin_ia32_vec_ext_v16qi(v, 0);
            }
            else
                static assert(0, "Unsupported vector type: " ~ T.stringof);
        }
        else version(LDC)
        {
            return ldcsimd.extractelement!(T, 0)(v);
        }
    }
    else version(ARM)
    {
        static assert(0, "TODO");
    }
    else
    {
        static assert(0, "Unsupported on this architecture");
    }
}

// store the X element to the address provided
// If we use BaseType!T* as a parameter type, T can not be infered
// That's why we need to use template parameter S and check that it is
// the base type in the template constraint. We will use this in some other
// functions too.
void storeScalar(SIMDVer Ver = simdVer, T, S = BaseType!T)(T v, S* pS) if(isSIMDVector!T)
{
    // TODO: check this optimises correctly!! (opcode writes directly to memory)
    *pS = getScalar(v);
}

// store the vector to an unaligned address
void storeUnaligned(SIMDVer Ver = simdVer, T, S = BaseType!T)(T v, S* pV) @trusted if(isSIMDVector!T)
{
    version(X86_OR_X64)
    {
        version(DigitalMars)
        {
            static assert(0, "TODO");
        }
        else version(GNU_OR_LDC)
        {
            static if(isOfType!(T, float4))
                __builtin_ia32_storeups(pV, v);
            else static if(isOfType!(T, double2))
                __builtin_ia32_storeupd(pV, v);
            else
                __builtin_ia32_storedqu(cast(char*)pV, cast(byte16)v);
        }
    }
    else version(ARM)
    {
        static assert(0, "TODO");
    }
    else
    {
        static assert(0, "Unsupported on this architecture");
    }
}


///////////////////////////////////////////////////////////////////////////////
// Shuffle, swizzle, permutation

// broadcast X to all elements
T getX(SIMDVer Ver = simdVer, T)(inout T v) if(isSIMDVector!T)
{
    // broadcast the first component
    return swizzle!("0", Ver)(v);
}

// broadcast Y to all elements
T getY(SIMDVer Ver = simdVer, T)(inout T v) if(isSIMDVector!T && NumElements!T >= 2)
{
    // broadcast the second component
    return swizzle!("1", Ver)(v);
}

// broadcast Z to all elements
T getZ(SIMDVer Ver = simdVer, T)(inout T v) if(isSIMDVector!T && NumElements!T >= 3)
{
    // broadcast the 3nd component
    return swizzle!("2", Ver)(v);
}

// broadcast W to all elements
T getW(SIMDVer Ver = simdVer, T)(inout T v) if(isSIMDVector!T && NumElements!T >= 4)
{
    // broadcast the 4th component
    return swizzle!("3", Ver)(v);
}

// set the X element
T setX(SIMDVer Ver = simdVer, T)(inout T v, inout T x) if(isSIMDVector!T)
{
    version(X86_OR_X64)
    {
        version(DigitalMars)
        {
            static if(Ver >= SIMDVer.SSE41 && !is8bitElement!T)
            {
                static if(isOfType!(T, double2))
                    return __simd(XMM.BLENDPD, v, x, 1);
                else static if(isOfType!(T, float4))
                    return __simd(XMM.BLENDPS, v, x, 1);
                else static if(is64bitElement!T)
                    return __simd(XMM.PBLENDW, v, x, 0x0F);
                else static if(is32bitElement!T)
                    return __simd(XMM.PBLENDW, v, x, 0x03);
                else static if(is16bitElement!T)
                    return __simd(XMM.PBLENDW, v, x, 0x01);
            }
            else
                static assert(0, "Unsupported vector type: " ~ T.stringof);
        }
        else version(GNU)
        {
            static if(Ver >= SIMDVer.SSE41 && !is8bitElement!T)
            {
                static if(isOfType!(T, double2))
                    return __builtin_ia32_blendpd(v, x, 1);
                else static if(isOfType!(T, float4))
                    return __builtin_ia32_blendps(v, x, 1);
                else static if(is64bitElement!T)
                    return __builtin_ia32_pblendw128(v, x, 0x0F);
                else static if(is32bitElement!T)
                    return __builtin_ia32_pblendw128(v, x, 0x03);
                else static if(is16bitElement!T)
                    return __builtin_ia32_pblendw128(v, x, 0x01);
            }
            else
                static assert(0, "Unsupported vector type: " ~ T.stringof);
        }
        else version(LDC)
        {
            enum int n = NumElements!T;
            return ldcsimd.shufflevector!(T, n, staticIota!(1, n))(v, x);
        }
    }
    else version(ARM)
    {
        static assert(0, "TODO");
    }
    else
    {
        static assert(0, "Unsupported on this architecture");
    }
}

// set the Y element
T setY(SIMDVer Ver = simdVer, T)(inout T v, inout T y) if(isSIMDVector!T)
{
    version(X86_OR_X64)
    {
        version(DigitalMars)
        {
            static if(Ver >= SIMDVer.SSE41 && !is8bitElement!T)
            {
                static if(isOfType!(T, double2))
                    return __simd(XMM.BLENDPD, v, x, 2);
                else static if(isOfType!(T, float4))
                    return __simd(XMM.BLENDPS, v, x, 2);
                else static if(is64bitElement!T)
                    return __simd(XMM.PBLENDW, v, x, 0xF0);
                else static if(is32bitElement!T)
                    return __simd(XMM.PBLENDW, v, x, 0x0C);
                else static if(is16bitElement!T)
                    return __simd(XMM.PBLENDW, v, x, 0x02);
            }
            else
                static assert(0, "Unsupported vector type: " ~ T.stringof);
        }
        else version(GNU)
        {
            static if(Ver >= SIMDVer.SSE41 && !is8bitElement!T)
            {
                static if(isOfType!(T, double2))
                    return __builtin_ia32_blendpd(v, y, 2);
                else static if(isOfType!(T, float4))
                    return __builtin_ia32_blendps(v, y, 2);
                else static if(is64bitElement!T)
                    return __builtin_ia32_pblendw128(v, y, 0xF0);
                else static if(is32bitElement!T)
                    return __builtin_ia32_pblendw128(v, y, 0x0C);
                else static if(is16bitElement!T)
                    return __builtin_ia32_pblendw128(v, y, 0x02);
            }
            else
                static assert(0, "Unsupported vector type: " ~ T.stringof);
        }
        else version(LDC)
        {
            enum int n = NumElements!T;
            static assert(n >= 2);
            return ldcsimd.shufflevector!(T, 0, n + 1, staticIota!(2, n))(v, y);
        }
    }
    else version(ARM)
    {
        static assert(0, "TODO");
    }
    else
    {
        static assert(0, "Unsupported on this architecture");
    }
}

// set the Z element
T setZ(SIMDVer Ver = simdVer, T)(inout T v, inout T z) if(isSIMDVector!T)
{
    version(X86_OR_X64)
    {
        version(DigitalMars)
        {
            static if(Ver >= SIMDVer.SSE41 && !is8bitElement!T)
            {
                static if(isOfType!(T, float4))
                    return __simd(XMM.BLENDPS, v, x, 4);
                else static if(is32bitElement!T)
                    return __simd(XMM.PBLENDW, v, x, 0x30);
                else static if(is16bitElement!T)
                    return __simd(XMM.PBLENDW, v, x, 0x04);
                else
                    static assert(0, "Unsupported vector type: " ~ T.stringof);
            }
            else
                static assert(0, "Unsupported vector type: " ~ T.stringof);
        }
        else version(GNU)
        {
            static if(Ver >= SIMDVer.SSE41 && !is8bitElement!T)
            {
                static if(isOfType!(T, float4))
                    return __builtin_ia32_blendps(v, z, 4);
                else static if(is32bitElement!T)
                    return __builtin_ia32_pblendw128(v, z, 0x30);
                else static if(is16bitElement!T)
                    return __builtin_ia32_pblendw128(v, z, 0x04);
                else
                    static assert(0, "Unsupported vector type: " ~ T.stringof);
            }
            else
                static assert(0, "Unsupported vector type: " ~ T.stringof);
        }
        else version(LDC)
        {
            enum int n = NumElements!T;
            static assert(n >= 3);
            return ldcsimd.shufflevector!(T, 0, 1,  n + 2, staticIota!(3, n))(v, z);
        }
    }
    else version(ARM)
    {
        static assert(0, "TODO");
    }
    else
    {
        static assert(0, "Unsupported on this architecture");
    }
}

// set the W element
T setW(SIMDVer Ver = simdVer, T)(inout T v, inout T w) if(isSIMDVector!T)
{
    version(X86_OR_X64)
    {
        version(DigitalMars)
        {
            static if(Ver >= SIMDVer.SSE41 && !is8bitElement!T)
            {
                static if(isOfType!(T, float4))
                    return __simd(XMM.BLENDPS, v, x, 8);
                else static if(is32bitElement!T)
                    return __simd(XMM.PBLENDW, v, x, 0xC0);
                else static if(is16bitElement!T)
                    return __simd(XMM.PBLENDW, v, x, 0x08);
                else
                    static assert(0, "Unsupported vector type: " ~ T.stringof);
            }
            else
                static assert(0, "Unsupported vector type: " ~ T.stringof);
        }
        else version(GNU)
        {
            static if(Ver >= SIMDVer.SSE41 && !is8bitElement!T)
            {
                static if(isOfType!(T, float4))
                    return __builtin_ia32_blendps(v, w, 8);
                else static if(is32bitElement!T)
                    return __builtin_ia32_pblendw128(v, w, 0xC0);
                else static if(is16bitElement!T)
                    return __builtin_ia32_pblendw128(v, w, 0x08);
                else
                    static assert(0, "Unsupported vector type: " ~ T.stringof);
            }
            else
                static assert(0, "Unsupported vector type: " ~ T.stringof);
        }
        else version(LDC)
        {
            enum int n = NumElements!T;
            static assert(n >= 4);
            return ldcsimd.shufflevector!(T, 0, 1, 2, n + 3, staticIota!(4, n))(v, w);
        }
    }
    else version(ARM)
    {
        static assert(0, "TODO");
    }
    else
    {
        static assert(0, "Unsupported on this architecture");
    }
}

// swizzle a vector: r = swizzle!"ZZWX"(v); // r = v.zzwx
T swizzle(string swiz, SIMDVer Ver = simdVer, T)(inout T v)
{
    // meta to extract the elements from a swizzle string
    template getElements(string s, T)
    {
        // accepted element component names
        template elementNames(int numElements)
        {
            static if(numElements == 2)
                alias elementNames = TypeTuple!("01", "xy");
            else static if(numElements == 3)
                alias elementNames = TypeTuple!("012", "xyz", "rgb");
            else static if(numElements == 4)
                alias elementNames = TypeTuple!("0123", "xyzw", "rgba");
            else static if(numElements == 8)
                alias elementNames = TypeTuple!("01234567");
            else static if(numElements == 16)
                alias elementNames = TypeTuple!("0123456789abcdef");
            else
                alias elementNames = TypeTuple!();
        }

        enum char lower(char c) = c >= 'A' && c <= 'Z' ? c + 32 : c;

        // get the component name set for a swizzle string
        template Components(string s, names...)
        {
            template charIn(char c, string s)
            {
                static if(s.length == 0)
                    enum charIn = false;
                else
                    enum charIn = lower!c == s[0] || charIn!(c, s[1..$]);
            }
            template allIn(string chars, string s)
            {
                static if(chars.length == 0)
                    enum allIn = true;
                else
                    enum allIn = charIn!(chars[0], s) && allIn!(chars[1..$], s);
            }

            static if(s.length == 0 || names.length == 0)
                enum string Components = null;
            else static if(allIn!(s, names[0]))
                enum Components = names[0];
            else
                enum Components = Components!(s, names[1..$]);
        }

        // used to find the element id of a compoment
        template Offset(char c, string elements, int i = 0)
        {
            static if(i == elements.length)
                enum Offset = -1;
            else static if(lower!c == elements[i])
                enum Offset = i;
            else
                enum Offset = Offset!(c, elements, i+1);
        }

        // parse the swizzle string
        template Parse(string chars, string elements)
        {
            static if(chars.length == 0 || elements.length == 0)
                alias Parse = TypeTuple!();
            else
                alias Parse = TypeTuple!(Offset!(chars[0], elements), Parse!(chars[1..$], elements));
        }

        alias getElements = Parse!(s, Components!(s, elementNames!(NumElements!T)));
    }

    // repeat an element to form a broadcast
    template broadcast(size_t element, size_t count)
    {
        static if(element == -1 || count == 0)
            alias broadcast = TypeTuple!();
        else
            alias broadcast = TypeTuple!(element, broadcast!(element, count-1));
    }

    template isIdentity(E...)
    {
        template Impl(size_t i)
        {
            static if(i == E.length)
                enum Impl = true;
            else
                enum Impl = E[i] == i && Impl!(i+1);
        }
        enum isIdentity = Impl!0;
    }
    template isBroadcast(E...)
    {
        template Impl(size_t i)
        {
            static if(i == E.length)
                enum Impl = true;
            else
                enum Impl = E[i] == E[i-1] && Impl!(i+1);
        }
        enum isBroadcast = Impl!1;
    }

    enum numElements = NumElements!T;

    // get the swizzle elements
    alias el = getElements!(swiz, T);

    static assert(el.length > 0, "Invalid swizzle string: '" ~ swiz ~ "'");

    // support broadcasting
    static if(el.length == 1)
        alias elements = broadcast!(el[0], numElements);
    else
        alias elements = el;

    // TODO: if there are fewer elements in the string than the type, should we padd with identity swizzle? ie, "yyx" -> "yyxw"
    static assert(elements.length == numElements, "Invalid number of components in swizzle string '" ~ swiz ~ "' for type " ~ T.stringof);

    static if(isIdentity!elements)
    {
        // early out if no swizzle took place
        return v;
    }
    else
    {
        version(X86_OR_X64)
        {
            version(DigitalMars)
            {
                // broadcasts can usually be implemented more efficiently...
                static if(isBroadcast!elements && !is32bitElement!T)
                {
                    static if(isOfType!(T, double2))
                    {
                        // unpacks are more efficient than shuffd
                        static if(elements[0] == 0)
                        {
                            static if(0)//Ver >= SIMDVer.SSE3) // TODO: *** WHY DOESN'T THIS WORK?!
                                return __simd(XMM.MOVDDUP, v);
                            else
                                return __simd(XMM.UNPCKLPD, v, v);
                        }
                        else
                            return __simd(XMM.UNPCKHPD, v, v);
                    }
                    else static if(is64bitElement!(T)) // (u)long2
                    {
                        // unpacks are more efficient than shuffd
                        static if(elements[0] == 0)
                            return __simd(XMM.PUNPCKLQDQ, v, v);
                        else
                            return __simd(XMM.PUNPCKHQDQ, v, v);
                    }
                    else static if(is16bitElement!T)
                    {
                        // TODO: we should use permute to perform this operation when immediates work >_<
                        static if(false)// Ver >= SIMDVer.SSSE3)
                        {
//                            immutable ubyte16 permuteControl = [1,0,1,0,1,0,1,0,1,0,1,0,1,0,1,0];
//                            return __simd(XMM.PSHUFB, v, permuteControl);
                        }
                        else
                        {
                            // TODO: is this most efficient?
                            // No it is not... we should use a single shuflw/shufhw followed by a 64bit unpack...
                            enum int[] shufValues = [0x00, 0x55, 0xAA, 0xFF];
                            T t = __simd(XMM.PSHUFD, v, v, shufValues[elements[0] >> 1]);
                            t = __simd(XMM.PSHUFLW, t, t, (elements[0] & 1) ? 0x55 : 0x00);
                            return __simd(XMM.PSHUFHW, t, t, (elements[0] & 1) ? 0x55 : 0x00);
                        }
                    }
                    else static if(is8bitElement!T)
                    {
                        static if(Ver >= SIMDVer.SSSE3)
                        {
                            static if(elements[0] == 0)
                                immutable ubyte16 permuteControl = __simd(XMM.XORPS, v, v); // generate a zero register
                            else
                                immutable ubyte16 permuteControl = cast(ubyte)elements[0]; // load a permute constant
                            return __simd(XMM.PSHUFB, v, permuteControl);
                        }
                        else
                            static assert(0, "Only supported in SSSE3 and above");
                    }
                    else
                        static assert(0, "Unsupported vector type: " ~ T.stringof);
                }
                else
                {
                    static if(isOfType!(T, double2))
                        return __simd(XMM.SHUFPD, v, v, shufMask!(elements)); // swizzle: YX
                    else static if(is64bitElement!(T)) // (u)long2
                        // use a 32bit integer shuffle for swizzle: YZ
                        return __simd(XMM.PSHUFD, v, v, shufMask!(elements[0]*2, elements[0]*2 + 1, elements[1]*2, elements[1]*2 + 1));
                    else static if(isOfType!(T, float4))
                    {
                        static if(elements == TypeTuple!(0,0,2,2) && Ver >= SIMDVer.SSE3)
                            return __simd(XMM.MOVSLDUP, v);
                        else static if(elements == TypeTuple!(1,1,3,3) && Ver >= SIMDVer.SSE3)
                            return __simd(XMM.MOVSHDUP, v);
                        else
                            return __simd(XMM.SHUFPS, v, v, shufMask!(elements));
                    }
                    else static if(is32bitElement!(T))
                        return __simd(XMM.PSHUFD, v, v, shufMask!(elements));
                    else static if(is8bitElement!T || is16bitElement!T)
                    {
                        static if(Ver >= SIMDVer.SSSE3)
                        {
                            // static ubyte[16] mask = [pshufbMask!elements];
                            // auto vmask = cast(ubyte16) __simd(XMM.LOADDQU, cast(char*) mask.ptr);
                            // XMM.LOADDQU does not exist, and I don't know of anything equivalent in DMD.
                            // this compiles (I hope ther aren't any alignment issues):
                            __gshared static ubyte16 vmask = [pshufbMask!elements];
                            return cast(T) __simd(XMM.PSHUFB, cast(ubyte16) v, vmask);
                        }
                        else
                            static assert(0, "Only supported in SSSE3 and above");
                    }
                    else
                    {
                        // TODO: 16 and 8bit swizzles...
                        static assert(0, "Unsupported vector type: " ~ T.stringof);
                    }
                }
            }
            else version(GNU)
            {
                // broadcasts can usually be implemented more efficiently...
                static if(isBroadcast!elements && !is32bitElement!T)
                {
                    static if(isOfType!(T, double2))
                    {
                        // unpacks are more efficient than shuffd
                        static if(elements[0] == 0)
                        {
                            static if(0)//Ver >= SIMDVer.SSE3) // TODO: *** WHY DOESN'T THIS WORK?!
                                return __builtin_ia32_movddup(v);
                            else
                                return __builtin_ia32_unpcklpd(v, v);
                        }
                        else
                            return __builtin_ia32_unpckhpd(v, v);
                    }
                    else static if(is64bitElement!(T)) // (u)long2
                    {
                        // unpacks are more efficient than shuffd
                        static if(elements[0] == 0)
                            return __builtin_ia32_punpcklqdq128(v, v);
                        else
                            return __builtin_ia32_punpckhqdq128(v, v);
                    }
                    else static if(is16bitElement!T)
                    {
                        // TODO: we should use permute to perform this operation when immediates work >_<
                        static if(false)// Ver >= SIMDVer.SSSE3)
                        {
//                            immutable ubyte16 permuteControl = [1,0,1,0,1,0,1,0,1,0,1,0,1,0,1,0];
//                            return __builtin_ia32_pshufb128(v, permuteControl);
                        }
                        else
                        {
                            // TODO: is this most efficient?
                            // No it is not... we should use a single shuflw/shufhw followed by a 64bit unpack...
                            enum int[] shufValues = [0x00, 0x55, 0xAA, 0xFF];
                            T t = __builtin_ia32_pshufd(v, shufValues[elements[0] >> 1]);
                            t = __builtin_ia32_pshuflw(t, (elements[0] & 1) ? 0x55 : 0x00);
                            return __builtin_ia32_pshufhw(t, (elements[0] & 1) ? 0x55 : 0x00);
                        }
                    }
                    else static if(is8bitElement!T)
                    {
                        static if(Ver >= SIMDVer.SSSE3)
                        {
                            static if(elements[0] == 0)
                                immutable ubyte16 permuteControl = __builtin_ia32_xorps(v, v); // generate a zero register
                            else
                                immutable ubyte16 permuteControl = cast(ubyte)elements[0]; // load a permute constant
                            return __builtin_ia32_pshufb128(v, permuteControl);
                        }
                        else
                            static assert(0, "Only supported in SSSE3 and above");
                    }
                    else
                        static assert(0, "Unsupported vector type: " ~ T.stringof);
                }
                else
                {
                    static if(isOfType!(T, double2))
                        return __builtin_ia32_shufpd(v, v, shufMask!(elements)); // swizzle: YX
                    else static if(is64bitElement!(T)) // (u)long2
                        // use a 32bit integer shuffle for swizzle: YZ
                        return __builtin_ia32_pshufd(v, shufMask!(elements[0]*2, elements[0]*2 + 1, elements[1]*2, elements[1]*2 + 1));
                    else static if(isOfType!(T, float4))
                    {
                        static if(elements == TypeTuple!(0,0,2,2) && Ver >= SIMDVer.SSE3)
                            return __builtin_ia32_movsldup(v);
                        else static if(elements == TypeTuple!(1,1,3,3) && Ver >= SIMDVer.SSE3)
                            return __builtin_ia32_movshdup(v);
                        else
                            return __builtin_ia32_shufps(v, v, shufMask!(elements));
                    }
                    else static if(is32bitElement!(T))
                        return __builtin_ia32_pshufd(v, shufMask!(elements));
                    else static if(is8bitElement!T || is16bitElement!T)
                    {
                        static if(Ver >= SIMDVer.SSSE3)
                        {
                            static immutable ubyte[16] mask = [pshufbMask!elements];
                            auto vmask = cast(ubyte16) __builtin_ia32_loaddqu(cast(char*) mask.ptr);
                            return cast(T) __builtin_ia32_pshufb128(cast(ubyte16) v, vmask);
                        }
                        else
                            static assert(0, "Only supported in SSSE3 and above");
                    }
                    else
                    {
                        // TODO: 16 and 8bit swizzles...
                        static assert(0, "Unsupported vector type: " ~ T.stringof);
                    }
                }
            }
            else version(LDC)
            {
                return ldcsimd.shufflevector!(T, toTypeTuple!elements)(v, v);
            }
        }
        else version(ARM)
        {
            static assert(0, "TODO");
        }
        else
        {
            static assert(0, "Unsupported on this architecture");
        }
    }
}

// assign bytes to the target according to a permute control register
T permute(SIMDVer Ver = simdVer, T)(inout T v, ubyte16 control)
{
    version(X86_OR_X64)
    {
        version(DigitalMars)
        {
            static if(Ver >= SIMDVer.SSE3)
                return __simd(XMM.PSHUFB, v, control);
            else
                static assert(0, "Only supported in SSSE3 and above");
        }
        else version(GNU_OR_LDC)
        {
            static if(Ver >= SIMDVer.SSE3)
                return cast(T)__builtin_ia32_pshufb128(cast(ubyte16)v, control);
            else
                static assert(0, "Only supported in SSSE3 and above");
        }
    }
    else version(ARM)
    {
        static assert(0, "TODO");
    }
    else
    {
        static assert(0, "Unsupported on this architecture");
    }
}

// interleave low elements from 2 vectors
T interleaveLow(SIMDVer Ver = simdVer, T)(inout T v1, inout T v2)
{
    // this really requires multiple return values >_<

    version(X86_OR_X64)
    {
        version(DigitalMars)
        {
            static if(isOfType!(T, float4))
                return __simd(XMM.UNPCKLPS, v1, v2);
            else static if(isOfType!(T, double2))
                return __simd(XMM.UNPCKLPD, v1, v2);
            else static if(is64bitElement!T)
                return __simd(XMM.PUNPCKLQDQ, v1, v2);
            else static if(is32bitElement!T)
                return __simd(XMM.PUNPCKLDQ, v1, v2);
            else static if(is16bitElement!T)
                return __simd(XMM.PUNPCKLWD, v1, v2);
            else static if(is8bitElement!T)
                return __simd(XMM.PUNPCKLBW, v1, v2);
            else
                static assert(0, "Unsupported vector type: " ~ T.stringof);
        }
        else version(GNU)
        {
            static if(isOfType!(T, float4))
                return __builtin_ia32_unpcklps(v1, v2);
            else static if(isOfType!(T, double2))
                return __builtin_ia32_unpcklpd(v1, v2);
            else static if(is64bitElement!T)
                return __builtin_ia32_punpcklqdq128(v1, v2);
            else static if(is32bitElement!T)
                return __builtin_ia32_punpckldq128(v1, v2);
            else static if(is16bitElement!T)
                return __builtin_ia32_punpcklwd128(v1, v2);
            else static if(is8bitElement!T)
                return __builtin_ia32_punpcklbw128(v1, v2);
            else
                static assert(0, "Unsupported vector type: " ~ T.stringof);
        }
        else version(LDC)
        {
            enum int n = NumElements!T;
            alias interleaveTuples!(staticIota!(0, n / 2), staticIota!(n, n + n / 2)) mask;
            return ldcsimd.shufflevector!(T, mask)(v1, v2);
        }
    }
    else version(ARM)
    {
        static assert(0, "TODO");
    }
    else
    {
        static assert(0, "Unsupported on this architecture");
    }
}

// interleave high elements from 2 vectors
T interleaveHigh(SIMDVer Ver = simdVer, T)(inout T v1, inout T v2)
{
    // this really requires multiple return values >_<

    version(X86_OR_X64)
    {
        version(DigitalMars)
        {
            static if(isOfType!(T, float4))
                return __simd(XMM.UNPCKHPS, v1, v2);
            else static if(isOfType!(T, double2))
                return __simd(XMM.UNPCKHPD, v1, v2);
            else static if(is64bitElement!T)
                return __simd(XMM.PUNPCKHQDQ, v1, v2);
            else static if(is32bitElement!T)
                return __simd(XMM.PUNPCKHDQ, v1, v2);
            else static if(is16bitElement!T)
                return __simd(XMM.PUNPCKHWD, v1, v2);
            else static if(is8bitElement!T)
                return __simd(XMM.PUNPCKHBW, v1, v2);
            else
                static assert(0, "Unsupported vector type: " ~ T.stringof);
        }
        else version(GNU)
        {
            static if(isOfType!(T, float4))
                return __builtin_ia32_unpckhps(v1, v2);
            else static if(isOfType!(T, double2))
                return __builtin_ia32_unpckhpd(v1, v2);
            else static if(is64bitElement!T)
                return __builtin_ia32_punpckhqdq128(v1, v2);
            else static if(is32bitElement!T)
                return __builtin_ia32_punpckhdq128(v1, v2);
            else static if(is16bitElement!T)
                return __builtin_ia32_punpckhwd128(v1, v2);
            else static if(is8bitElement!T)
                return __builtin_ia32_punpckhbw128(v1, v2);
            else
                static assert(0, "Unsupported vector type: " ~ T.stringof);
        }
        else version(LDC)
        {
            enum int n = NumElements!T;
            alias interleaveTuples!(staticIota!(n / 2, n), staticIota!(n + n / 2, n + n)) mask;

            return ldcsimd.shufflevector!(T, mask)(v1, v2);
        }
    }
    else version(ARM)
    {
        static assert(0, "TODO");
    }
    else
    {
        static assert(0, "Unsupported on this architecture");
    }
}

//... there are many more useful permutation ops



///////////////////////////////////////////////////////////////////////////////
// Pack/unpack

// these are PERFECT examples of functions that would benefit from multiple return values!
/* eg.
short8,short8 unpackBytes(byte16)
{
    short8 low,high;
    low = bytes[0..4];
    high = bytes[4..8];
    return low,high;
}
*/

PromotionOf!T unpackLow(SIMDVer Ver = simdVer, T)(inout T v)
{
    version(X86_OR_X64)
    {
        static if(isOfType!(T, float4))
            return cast(PromotopnOf!T)toDouble!Ver(v);
        else static if(isOfType!(T, int4))
            return cast(PromotionOf!T)interleaveLow!Ver(v, shiftRightImmediate!(31, Ver)(v));
        else static if(isOfType!(T, uint4))
            return cast(PromotionOf!T)interleaveLow!(Ver, T)(v, 0);
        else static if(isOfType!(T, short8))
            return shiftRightImmediate!(16, Ver)(cast(int4)interleaveLow!Ver(v, v));
        else static if(isOfType!(T, ushort8))
            return cast(PromotionOf!T)interleaveLow!(Ver, T)(v, 0);
        else static if(isOfType!(T, byte16))
            return shiftRightImmediate!(8, Ver)(cast(short8)interleaveLow!Ver(v, v));
        else static if(isOfType!(T, ubyte16))
            return cast(PromotionOf!T)interleaveLow!(Ver, T)(v, 0);
        else
            static assert(0, "Unsupported vector type: " ~ T.stringof);
    }
    else version(ARM)
    {
        static assert(0, "TODO");
    }
    else
    {
        static assert(0, "Unsupported on this architecture");
    }
}

PromotionOf!T unpackHigh(SIMDVer Ver = simdVer, T)(inout T v)
{
    version(X86_OR_X64)
    {
        static if(isOfType!(T, float4))
            return toDouble!Ver(swizzle!("zwzw", Ver)(v));
        else static if(isOfType!(T, int4))
            return cast(PromotionOf!T)interleaveHigh!Ver(v, shiftRightImmediate!(31, Ver)(v));
        else static if(isOfType!(T, uint4))
            return cast(PromotionOf!T)interleaveHigh!(Ver, T)(v, 0);
        else static if(isOfType!(T, short8))
            return shiftRightImmediate!(16, Ver)(cast(int4)interleaveHigh!Ver(v, v));
        else static if(isOfType!(T, ushort8))
            return cast(PromotionOf!T)interleaveHigh!(Ver, T)(v, 0);
        else static if(isOfType!(T, byte16))
            return shiftRightImmediate!(8, Ver)(cast(short8)interleaveHigh!Ver(v, v));
        else static if(isOfType!(T, ubyte16))
            return cast(PromotionOf!T)interleaveHigh!(Ver, T)(v, 0);
        else
            static assert(0, "Unsupported vector type: " ~ T.stringof);
    }
    else version(ARM)
    {
        static assert(0, "TODO");
    }
    else
    {
        static assert(0, "Unsupported on this architecture");
    }
}

DemotionOf!T pack(SIMDVer Ver = simdVer, T)(inout T v1, inout T v2)
{
    version(X86_OR_X64)
    {
        static if(isOfType!(T, double2))
            return interleaveLow!Ver(toFloat!Ver(v1), toFloat!Ver(v2));
        else
        {
            version(DigitalMars)
            {
                static if(isOfType!(T, long2))
                    static assert(0, "TODO");
                else static if(isOfType!(T, ulong2))
                    static assert(0, "TODO");
                else static if(isOfType!(T, int4))
                    static assert(0, "TODO");
                else static if(isOfType!(T, uint4))
                    static assert(0, "TODO");
                else static if(is16bitElement!T)
                {
//                  return _mm_packus_epi16(_mm_and_si128(v1, 0x00FF), _mm_and_si128(v2, 0x00FF));
                    return __simd(XMM.PACKUSWB, v1, v2);
                }
                else
                    static assert(0, "Unsupported vector type: " ~ T.stringof);
            }
            else version(GNU)
            {
                static if(isOfType!(T, long2))
                    static assert(0, "TODO");
                else static if(isOfType!(T, ulong2))
                    static assert(0, "TODO");
                else static if(isOfType!(T, int4))
                {
                    static assert(0, "TODO");
                    // return _mm_packs_epi32( _mm_srai_epi32( _mm_slli_epi16( a, 16), 16), _mm_srai_epi32( _mm_slli_epi32( b, 16), 16) );
                }
                else static if(isOfType!(T, uint4))
                {
                    static assert(0, "TODO");
                    // return _mm_packs_epi32( _mm_srai_epi32( _mm_slli_epi32( a, 16), 16), _mm_srai_epi32( _mm_slli_epi32( b, 16), 16) );
                }
                else static if(is16bitElement!T)
                    static assert(0, "TODO");
//                  return _mm_packus_epi16(_mm_and_si128(v1, 0x00FF), _mm_and_si128(v2, 0x00FF));
                else
                    static assert(0, "Unsupported vector type: " ~ T.stringof);
            }
            else version(LDC)
            {
                alias DemotionOf!T D;
                enum int n = NumElements!D;

                return ldcsimd.shufflevector!(D, staticIota!(0, 2 * n, 2))(cast(D) v1, cast(D) v2);
            }
        }
    }
    else version(ARM)
    {
        static assert(0, "TODO");
    }
    else
    {
        static assert(0, "Unsupported on this architecture");
    }
}

DemotionOf!T packSaturate(SIMDVer Ver = simdVer, T)(inout T v1, inout T v2)
{
    version(X86_OR_X64)
    {
        version(DigitalMars)
        {
            static if(isOfType!(T, int4))
                return __simd(XMM.PACKSSDW, v1, v2);
            else static if(isOfType!(T, uint4))
                static assert(0, "TODO: should we emulate this?");
            else static if(isOfType!(T, short8))
                return __simd(XMM.PACKSSWB, v1, v2);
            else static if(isOfType!(T, ushort8))
                return __simd(XMM.PACKUSWB, v1, v2);
            else
                static assert(0, "Unsupported vector type: " ~ T.stringof);
        }
        else version(GNU_OR_LDC)
        {
            static if(isOfType!(T, int4))
                return __builtin_ia32_packssdw128(v1, v2);
            else static if(isOfType!(T, uint4))
                static assert(0, "TODO: should we emulate this?");
            else static if(isOfType!(T, short8))
                return __builtin_ia32_packsswb128(v1, v2);
            else static if(isOfType!(T, ushort8))
                return __builtin_ia32_packuswb128(v1, v2);
            else
                static assert(0, "Unsupported vector type: " ~ T.stringof);
        }
    }
    else version(ARM)
    {
        static assert(0, "TODO");
    }
    else
    {
        static assert(0, "Unsupported on this architecture");
    }
}

///////////////////////////////////////////////////////////////////////////////
// Type conversion

int4 toInt(SIMDVer Ver = simdVer, T)(inout T v)
{
    static if(isOfType!(T, int4))
        return v;
    else
    {
        version(X86_OR_X64)
        {
            version(DigitalMars)
            {
                static if(isOfType!(T, float4))
                    return __simd(XMM.CVTPS2DQ, v);
                else static if(isOfType!(T, double2))
                    return __simd(XMM.CVTPD2DQ, v); // TODO: z,w are undefined... should we repeat xy to zw?
                else
                    static assert(0, "Unsupported vector type: " ~ T.stringof);
            }
            else version(GNU_OR_LDC)
            {
                static if(isOfType!(T, float4))
                    return __builtin_ia32_cvtps2dq(v);
                else static if(isOfType!(T, double2))
                    return __builtin_ia32_cvtpd2dq(v); // TODO: z,w are undefined... should we repeat xy to zw?
                else
                    static assert(0, "Unsupported vector type: " ~ T.stringof);
            }
        }
        else version(ARM)
        {
            static assert(0, "TODO");
        }
        else
        {
            static assert(0, "Unsupported on this architecture");
        }
    }
}

float4 toFloat(SIMDVer Ver = simdVer, T)(inout T v)
{
    static if(isOfType!(T, float4))
        return v;
    else
    {
        version(X86_OR_X64)
        {
            version(DigitalMars)
            {
                static if(isOfType!(T, int4))
                    return __simd(XMM.CVTDQ2PS, v);
                else static if(isOfType!(T, double2))
                    return __simd(XMM.CVTPD2PS, v);
                else
                    static assert(0, "Unsupported vector type: " ~ T.stringof);
            }
            else version(GNU_OR_LDC)
            {
                static if(isOfType!(T, int4))
                    return __builtin_ia32_cvtdq2ps(v);
                else static if(isOfType!(T, double2))
                    return __builtin_ia32_cvtpd2ps(v);
                else
                    static assert(0, "Unsupported vector type: " ~ T.stringof);
            }
        }
        else version(ARM)
        {
            static assert(0, "TODO");
        }
        else
        {
            static assert(0, "Unsupported on this architecture");
        }
    }
}

double2 toDouble(SIMDVer Ver = simdVer, T)(inout T v)
{
    static if(isOfType!(T, double2))
        return v;
    else
    {
        version(X86_OR_X64)
        {
            version(DigitalMars)
            {
                static if(isOfType!(T, int4))
                    return __simd(XMM.CVTDQ2PD, v);
                else static if(isOfType!(T, float4))
                    return __simd(XMM.CVTPS2PD, v);
                else
                    static assert(0, "Unsupported vector type: " ~ T.stringof);
            }
            else version(GNU_OR_LDC)
            {
                static if(isOfType!(T, int4))
                    return __builtin_ia32_cvtdq2pd(v);
                else static if(isOfType!(T, float4))
                    return __builtin_ia32_cvtps2pd(v);
                else
                    static assert(0, "Unsupported vector type: " ~ T.stringof);
            }
        }
        else version(ARM)
        {
            static assert(0, "TODO");
        }
        else
        {
            static assert(0, "Unsupported on this architecture");
        }
    }
}

///////////////////////////////////////////////////////////////////////////////
// Basic mathematical operations

// unary absolute

template abs(SIMDVer Ver = simdVer, T)
{
    @attribute("target", targetNames[Ver])
    T abs(inout T v)
    {
        /******************************
        * integer abs with no branches
        *   mask = v >> numBits(v)-1;
        *   r = (v + mask) ^ mask;
        ******************************/

        static if(isUnsigned!T)
            return v;
        else
        {
            version(X86_OR_X64)
            {
                version(DigitalMars)
                {
                    static if(isOfType!(T, double2))
                    {
                        return __simd(XMM.ANDNPD, cast(double2)signMask2, v);
                    }
                    else static if(isOfType!(T, float4))
                    {
                        return __simd(XMM.ANDNPS, cast(float4)signMask4, v);
                    }
                    else static if(Ver >= SIMDVer.SSSE3)
                    {
                        static if(is64bitElement!(T))
                            static assert(0, "Unsupported: abs(" ~ T.stringof ~ "). Should we emulate?");
                        else static if(is32bitElement!(T))
                            return __simd(XMM.PABSD, v);
                        else static if(is16bitElement!(T))
                            return __simd(XMM.PABSW, v);
                        else static if(is8bitElement!(T4))
                            return __simd(XMM.PABSB, v);
                    }
                    else static if(isOfType!(T, int4))
                    {
                        int4 t = shiftRightImmediate!(31, Ver)(v);
                        return sub!Ver(xor!Ver(v, t), t);
                    }
                    else static if(isOfType!(T, short8))
                    {
                        return max!Ver(v, neg!Ver(v));
                    }
                    else static if(isOfType!(T, byte16))
                    {
                        T zero = 0;
                        byte16 t = maskGreater!Ver(zero, v);
                        return sub!Ver(xor!Ver(v, t), t);
                    }
                    else
                        static assert(0, "Unsupported vector type: " ~ T.stringof);
                }
                else version(GNU_OR_LDC)
                {
                    static if(isOfType!(T, double2))
                    {
                        version(GNU)
                            return __builtin_ia32_andnpd(cast(double2)signMask2, v);
                        else
                            return cast(double2)(~signMask2 & cast(ulong2)v);
                    }
                    else static if(isOfType!(T, float4))
                    {
                        version(GNU)
                            return __builtin_ia32_andnps(cast(float4)signMask4, v);
                        else
                            return cast(float4)(~signMask4 & cast(uint4)v);
                    }
                    else static if(Ver >= SIMDVer.SSSE3 && !isOfType!(T, long2))
                    {
                        static if(is32bitElement!(T))
                            return __builtin_ia32_pabsd128(v);
                        else static if(is16bitElement!(T))
                            return __builtin_ia32_pabsw128(v);
                        else static if(is8bitElement!(T))
                            return __builtin_ia32_pabsb128(v);
                    }
                    else static if(isOfType!(T, int4))
                    {
                        int4 t = shiftRightImmediate!(31, Ver)(v);
                        return sub!Ver(xor!Ver(v, t), t);
                    }
                    else static if(isOfType!(T, short8))
                    {
                        return max!Ver(v, neg!Ver(v));
                    }
                    else static if(isOfType!(T, byte16) || isOfType!(T, long2))
                    {
                        T zero = 0;
                        T t = maskGreater!Ver(zero, v);
                        return sub!Ver(xor!Ver(v, t), t);
                    }
                    else
                        static assert(0, "Unsupported vector type: " ~ T.stringof);
                }
            }
            else version(ARM)
            {
                static if(isOfType!(T, float4))
                    return __builtin_neon_vabsv4sf(v, ARMOpType!T);
                else static if(isOfType!(T, int4))
                    return __builtin_neon_vabsv4si(v, ARMOpType!T);
                else static if(isOfType!(T, short8))
                    return __builtin_neon_vabsv8hi(v, ARMOpType!T);
                else static if(isOfType!(T, byte16))
                    return __builtin_neon_vabsv16qi(v, ARMOpType!T);
                else
                    static assert(0, "Unsupported vector type: " ~ T.stringof);
            }
            else
            {
                static assert(0, "Unsupported on this architecture");
            }
        }
    }
}

// unary negate
template neg(SIMDVer Ver = simdVer, T)
{
    @attribute("target", targetNames[Ver])
    T neg(inout T v)
    {
        // D allows to negate unsigned values, so I guess we should support it in SIMD too
//      static assert(!isUnsigned!(T), "Can't negate unsigned value");

        version(X86_OR_X64)
        {
            return -v;
        }
        else version(ARM)
        {
            static if(isOfType!(T, float4))
                return __builtin_neon_vnegv4sf(v, ARMOpType!T);
            else static if(isOfType!(T, int4))
                return __builtin_neon_vnegv4si(v, ARMOpType!T);
            else static if(isOfType!(T, short8))
                return __builtin_neon_vnegv8hi(v, ARMOpType!T);
            else static if(isOfType!(T, byte16))
                return __builtin_neon_vnegv16qi(v, ARMOpType!T);
            else
                static assert(0, "Unsupported vector type: " ~ T.stringof);
        }
        else
        {
            static assert(0, "Unsupported on this architecture");
        }
    }
}

// binary add
template add(SIMDVer Ver = simdVer, T)
{
    @attribute("target", targetNames[Ver])
    T add(inout T v1, inout T v2)
    {
        pragma(msg, T.stringof);
        version(NoSIMD)
        {
            return (v1[]+v2[])[];
        }
        else version(X86_OR_X64)
        {
            return v1 + v2;
        }
        else version(ARM)
        {
            static if(isOfType!(T, float4))
                return __builtin_neon_vaddv4sf(v1, v2, ARMOpType!T);
            else static if(is64bitInteger!T)
                return __builtin_neon_vaddv2di(v1, v2, ARMOpType!T);
            else static if(is32bitElement!T)
                return __builtin_neon_vaddv4si(v1, v2, ARMOpType!T);
            else static if(is16bitElement!T)
                return __builtin_neon_vaddv8hi(v1, v2, ARMOpType!T);
            else static if(is8bitElement!T)
                return __builtin_neon_vaddv16qi(v1, v2, ARMOpType!T);
            else
                static assert(0, "Unsupported vector type: " ~ T.stringof);
        }
        else
        {
            static assert(0, "Unsupported on this architecture");
        }
    }
}

// binary add and saturate
template addSaturate(SIMDVer Ver = simdVer)
{
    @attribute("target", targetNames[Ver])
    T addSaturate(T)(inout T v1, inout T v2)
    {
        version(X86_OR_X64)
        {
            version(DigitalMars)
            {
                static if(isOfType!(T, short8))
                    return __simd(XMM.PADDSW, v1, v2);
                else static if(isOfType!(T, ushort8))
                    return __simd(XMM.PADDUSW, v1, v2);
                else static if(isOfType!(T, byte16))
                    return __simd(XMM.PADDSB, v1, v2);
                else static if(isOfType!(T, ubyte16))
                    return __simd(XMM.PADDUSB, v1, v2);
                else
                    static assert(0, "Unsupported vector type: " ~ T.stringof);
            }
            else version(GNU_OR_LDC)
            {
                static if(isOfType!(T, short8))
                    return __builtin_ia32_paddsw128(v1, v2);
                else static if(isOfType!(T, ushort8))
                    return __builtin_ia32_paddusw128(v1, v2);
                else static if(isOfType!(T, byte16))
                    return __builtin_ia32_paddsb128(v1, v2);
                else static if(isOfType!(T, ubyte16))
                    return __builtin_ia32_paddusb128(v1, v2);
                else
                    static assert(0, "Unsupported vector type: " ~ T.stringof);
            }
        }
        else version(ARM)
        {
            static assert(0, "TODO");
        }
        else
        {
            static assert(0, "Unsupported on this architecture");
        }
    }
}

// binary subtract
template sub(SIMDVer Ver = simdVer, T)
{
    @attribute("target", targetNames[Ver])
    T sub(inout T v1, inout T v2)
    {
        version(X86_OR_X64)
        {
            return v1 - v2;
        }
        else version(ARM)
        {
            static if(isOfType!(T, float4))
                return __builtin_neon_vsubv4sf(v1, v2, ARMOpType!T);
            else static if(is64bitInteger!T)
                return __builtin_neon_vsubv2di(v1, v2, ARMOpType!T);
            else static if(is32bitElement!T)
                return __builtin_neon_vsubv4si(v1, v2, ARMOpType!T);
            else static if(is16bitElement!T)
                return __builtin_neon_vsubv8hi(v1, v2, ARMOpType!T);
            else static if(is8bitElement!T)
                return __builtin_neon_vsubv16qi(v1, v2, ARMOpType!T);
            else
                static assert(0, "Unsupported vector type: " ~ T.stringof);
        }
        else
        {
            static assert(0, "Unsupported on this architecture");
        }
    }
}

// binary subtract and saturate
template subSaturate(SIMDVer Ver = simdVer, T)
{
    @attribute("target", targetNames[Ver])
    T subSaturate(inout T v1, inout T v2)
    {
        version(X86_OR_X64)
        {
            version(DigitalMars)
            {
                static if(isOfType!(T, short8))
                    return __simd(XMM.PSUBSW, v1, v2);
                else static if(isOfType!(T, ushort8))
                    return __simd(XMM.PSUBUSW, v1, v2);
                else static if(isOfType!(T, byte16))
                    return __simd(XMM.PSUBSB, v1, v2);
                else static if(isOfType!(T, ubyte16))
                    return __simd(XMM.PSUBUSB, v1, v2);
                else
                    static assert(0, "Unsupported vector type: " ~ T.stringof);
            }
            else version(GNU_OR_LDC)
            {
                static if(isOfType!(T, short8))
                    return __builtin_ia32_psubsw128(v1, v2);
                else static if(isOfType!(T, ushort8))
                    return __builtin_ia32_psubusw128(v1, v2);
                else static if(isOfType!(T, byte16))
                    return __builtin_ia32_psubsb128(v1, v2);
                else static if(isOfType!(T, ubyte16))
                    return __builtin_ia32_psubusb128(v1, v2);
                else
                    static assert(0, "Unsupported vector type: " ~ T.stringof);
            }
        }
        else version(ARM)
        {
            static assert(0, "TODO");
        }
        else
        {
            static assert(0, "Unsupported on this architecture");
        }
    }
}

// binary multiply
template mul(SIMDVer Ver = simdVer, T)
{
    @attribute("target", targetNames[Ver])
    T mul(inout T v1, inout T v2)
    {
        version(X86_OR_X64)
        {
            version(DigitalMars)
            {
                static if(isOfType!(T, double2))
                    return __simd(XMM.MULPD, v1, v2);
                else static if(isOfType!(T, float4))
                    return __simd(XMM.MULPS, v1, v2);
                else static if(is64bitElement!T) // 9 ops : 5 lat (scalar possibly faster?)
                {
                    T l = __simd(XMM.PMULUDQ, v1, v2);
                    T h1 = __simd(XMM.PMULUDQ, v1, shiftRightImmediate!(32, Ver)(cast(ulong2)v2));
                    T h2 = __simd(XMM.PMULUDQ, v2, shiftRightImmediate!(32, Ver)(cast(ulong2)v1));
                    return add!Ver(l, add!Ver(shiftLeftImmediate!(32, Ver)(cast(ulong2)h1), shiftLeftImmediate!(32, Ver)(cast(ulong2)h2)));
                }
                else static if(is32bitElement!T)
                {
                    static if(Ver >= SIMDVer.SSE41)
                    {
                      return __simd(XMM.PMULLD, v1, v2);
                    }
                    else // 7 ops : 4 lat (scalar possibly faster?)
                    {
                        T t1 = shiftBytesLeftImmediate!(4, Ver)(v1);
                        T t2 = shiftBytesLeftImmediate!(4, Ver)(v2);
                        T r1 = __simd(XMM.PMULUDQ, v1, v2); // x, z
                        T r2 = __simd(XMM.PMULUDQ, t1, t2); // y, w
                        return interleaveLow!Ver(swizzle!("xzxz", Ver)(r1), swizzle!("xzxz", Ver)(r2));
                    }
                }
                else static if(is16bitElement!T)
                    return __simd(XMM.PMULLW, v1, v2);
                else static if(is8bitElement!T)
                {
                    static if(Ver >= SIMDVer.SSSE3) // 9 ops : 4 lat
                    {
                        // should we do this? it is very inefficient...
                        // perhaps it's just better to just admit that SSE doesn't support byte mul?
                        static assert(0, "Not implemented: this is really inefficient...");
//                      vpunpckhbw    %xmm2, %xmm2, %xmm3
//                      vpunpckhbw    %xmm1, %xmm1, %xmm0
//                      vpunpcklbw    %xmm2, %xmm2, %xmm2
//                      vpunpcklbw    %xmm1, %xmm1, %xmm1
//                      vpmullw    %xmm0, %xmm3, %xmm0
//                      vpshufb    .LC1(%rip), %xmm0, %xmm0
//                      vpmullw    %xmm1, %xmm2, %xmm1
//                      vpshufb    .LC0(%rip), %xmm1, %xmm1
//                      vpor    %xmm0, %xmm1, %xmm0
                    }
                    else
                        static assert(0, "Only supported in SSSE3 and above");
                }
                else
                    static assert(0, "Unsupported vector type: " ~ T.stringof);
            }
            else
            {
                return v1 * v2;
            }
        }
        else version(ARM)
        {
            static if(isOfType!(T, float4))
                return __builtin_neon_vmulv4sf(v1, v2, ARMOpType!T);
            else static if(is64bitInteger!T)
                return __builtin_neon_vmulv2di(v1, v2, ARMOpType!T);
            else static if(is32bitElement!T)
                return __builtin_neon_vmulv4si(v1, v2, ARMOpType!T);
            else static if(is16bitElement!T)
                return __builtin_neon_vmulv8hi(v1, v2, ARMOpType!T);
            else static if(is8bitElement!T)
                return __builtin_neon_vmulv16qi(v1, v2, ARMOpType!T);
            else
                static assert(0, "Unsupported vector type: " ~ T.stringof);
        }
        else
        {
            static assert(0, "Unsupported on this architecture");
        }
    }
}

// multiply and add: v1*v2 + v3
template madd(SIMDVer Ver = simdVer, T)
{
    @attribute("target", targetNames[Ver])
    T madd(inout T v1, inout T v2, inout T v3)
    {
        version(X86_OR_X64)
        {
            version(DigitalMars)
            {
                static if(isOfType!(T, double2) && Ver == SIMDVer.SSE5)
                    return __simd(XMM.FMADDPD, v1, v2, v3);
                else static if(isOfType!(T, float4) && Ver == SIMDVer.SSE5)
                    return __simd(XMM.FMADDPS, v1, v2, v3);
                else
                    return add!Ver(mul!Ver(v1, v2), v3);
            }
            else version(GNU_OR_LDC)    // TODO: declare the SSE5 builtins for LDC
            {
                static if(isOfType!(T, double2) && Ver == SIMDVer.SSE5)
                    return __builtin_ia32_fmaddpd(v1, v2, v3);
                else static if(isOfType!(T, float4) && Ver == SIMDVer.SSE5)
                    return __builtin_ia32_fmaddps(v1, v2, v3);
                else
                    return add!Ver(mul!Ver(v1, v2), v3);
            }
        }
        else version(ARM)
        {
            static if(false)//Ver == SIMDVer.VFPv4)
            {
                // VFPv4 has better opcodes, but i can't find the intrinsics right now >_<
                // VFMA, VFMS, VFNMA, and VFNMS
            }
            else
            {
                static if(isOfType!(T, float4))
                    return __builtin_neon_vmlav4sf(v3, v1, v2, ARMOpType!T);
                else static if(is64bitInteger!T)
                    return __builtin_neon_vmlav2di(v3, v1, v2, ARMOpType!T);
                else static if(is32bitElement!T)
                    return __builtin_neon_vmlav4si(v3, v1, v2, ARMOpType!T);
                else static if(is16bitElement!T)
                    return __builtin_neon_vmlav8hi(v3, v1, v2, ARMOpType!T);
                else static if(is8bitElement!T)
                    return __builtin_neon_vmlav16qi(v3, v1, v2, ARMOpType!T);
                else
                    static assert(0, "Unsupported vector type: " ~ T.stringof);
            }
        }
        else
        {
            static assert(0, "Unsupported on this architecture");
        }
    }
}
// multiply and subtract: v1*v2 - v3
template msub(SIMDVer Ver = simdVer, T)
{
    @attribute("target", targetNames[Ver])
    T msub(inout T v1, inout T v2, inout T v3)
    {
        version(X86_OR_X64)
        {
            version(DigitalMars)
            {
                return sub!Ver(mul!Ver(v1, v2), v3);
            }
            else version(GNU_OR_LDC)    // TODO: declare the SSE5 builtins for LDC
            {
                static if(isOfType!(T, double2) && Ver == SIMDVer.SSE5)
                    return __builtin_ia32_fmsubpd(v1, v2, v3);
                else static if(isOfType!(T, float4) && Ver == SIMDVer.SSE5)
                    return __builtin_ia32_fmsubps(v1, v2, v3);
                else
                    return sub!Ver(mul!Ver(v1, v2), v3);
            }
        }
        else version(ARM)
        {
            static if(false)//Ver == SIMDVer.VFPv4)
            {
                // VFPv4 has better opcodes, but i can't find the intrinsics right now >_<
                // VFMA, VFMS, VFNMA, and VFNMS
            }
            else
            {
                return sub!Ver(mul!Ver(v1, v2), v3);
            }
        }
        else
        {
            static assert(0, "Unsupported on this architecture");
        }
    }
}

// negate multiply and add: -(v1*v2) + v3
template nmadd(SIMDVer Ver = simdVer, T)
{
    @attribute("target", targetNames[Ver])
    T nmadd(inout T v1, inout T v2, inout T v3)
    {
        version(X86_OR_X64)
        {
            version(DigitalMars)
            {
                return sub!Ver(v3, mul!Ver(v1, v2));
            }
            else version(GNU_OR_LDC)    // TODO: declare the SSE5 builtins for LDC
            {
                static if(isOfType!(T, double2) && Ver == SIMDVer.SSE5)
                    return __builtin_ia32_fnmaddpd(v1, v2, v3);
                else static if(isOfType!(T, float4) && Ver == SIMDVer.SSE5)
                    return __builtin_ia32_fnmaddps(v1, v2, v3);
                else
                    return sub!Ver(v3, mul!Ver(v1, v2));
            }
        }
        else version(ARM)
        {
            static if(false)//Ver == SIMDVer.VFPv4)
            {
                // VFPv4 has better opcodes, but i can't find the intrinsics right now >_<
                // VFMA, VFMS, VFNMA, and VFNMS
            }
            else
            {
                // Note: ARM's msub is backwards, it performs:  r = r - a*b
                // Which is identical to the conventinal nmadd: r = -(a*b) + c

                static if(isOfType!(T, float4))
                    return __builtin_neon_vmlsv4sf(v3, v1, v2, ARMOpType!T);
                else static if(is64bitInteger!T)
                    return __builtin_neon_vmlsv2di(v3, v1, v2, ARMOpType!T);
                else static if(is32bitElement!T)
                    return __builtin_neon_vmlsv4si(v3, v1, v2, ARMOpType!T);
                else static if(is16bitElement!T)
                    return __builtin_neon_vmlsv8hi(v3, v1, v2, ARMOpType!T);
                else static if(is8bitElement!T)
                    return __builtin_neon_vmlsv16qi(v3, v1, v2, ARMOpType!T);
                else
                    static assert(0, "Unsupported vector type: " ~ T.stringof);
            }
        }
        else version(PowerPC)
        {
            // note PowerPC also has an opcode for this...
            static assert(0, "Unsupported on this architecture");
        }
        else
        {
            static assert(0, "Unsupported on this architecture");
        }
    }
}

// negate multiply and subtract: -(v1*v2) - v3
template nmsub(SIMDVer Ver = simdVer, T)
{
    @attribute("target", targetNames[Ver])
    T nmsub(inout T v1, inout T v2, inout T v3)
    {
        version(X86_OR_X64)
        {
            version(DigitalMars)
            {
                return sub!Ver(neg!Ver(v3), mul!Ver(v1, v2));
            }
            else version(GNU_OR_LDC)    // TODO: declare the SSE5 builtins for LDC
            {
                static if(isOfType!(T, double2) && Ver == SIMDVer.SSE5)
                    return __builtin_ia32_fnmsubpd(v1, v2, v3);
                else static if(isOfType!(T, float4) && Ver == SIMDVer.SSE5)
                    return __builtin_ia32_fnmsubps(v1, v2, v3);
                else
                    return sub!Ver(neg!Ver(v3), mul!Ver(v1, v2));
            }
        }
        else version(ARM)
        {
            static if(false)//Ver == SIMDVer.VFPv4)
            {
                // VFPv4 has better opcodes, but i can't find the intrinsics right now >_<
                // VFMA, VFMS, VFNMA, and VFNMS
            }
            else
            {
                return nmadd!Ver(v1, v2, neg!Ver(v3));
            }
        }
        else
        {
            static assert(0, "Unsupported on this architecture");
        }
    }
}

// min
template min(SIMDVer Ver = simdVer, T)
{
    @attribute("target", targetNames[Ver])
    T min(inout T v1, inout T v2)
    {
        version(X86_OR_X64)
        {
            version(DigitalMars)
            {
                static if(isOfType!(T, double2))
                    return __simd(XMM.MINPD, v1, v2);
                else static if(isOfType!(T, float4))
                    return __simd(XMM.MINPS, v1, v2);
                else static if(isOfType!(T, long2) || isOfType!(T, ulong2))
                    return selectGreater!Ver(v1, v2, v2, v1);
                else static if(isOfType!(T, int4))
                {
                    static if(Ver >= SIMDVer.SSE41)
                        return __simd(XMM.PMINSD, v1, v2);
                    else
                        return selectGreater!Ver(v1, v2, v2, v1);
                }
                else static if(isOfType!(T, uint4))
                {
                    static if(Ver >= SIMDVer.SSE41)
                        return __simd(XMM.PMINUD, v1, v2);
                    else
                        return selectGreater!Ver(v1, v2, v2, v1);
                }
                else static if(isOfType!(T, short8))
                    return __simd(XMM.PMINSW, v1, v2); // available in SSE2
                else static if(isOfType!(T, ushort8))
                {
                    static if(Ver >= SIMDVer.SSE41)
                        return __simd(XMM.PMINUW, v1, v2);
                    else
                        return selectGreater!Ver(v1, v2, v2, v1);
                }
                else static if(isOfType!(T, byte16))
                {
                    static if(Ver >= SIMDVer.SSE41)
                        return __simd(XMM.PMINSB, v1, v2);
                    else
                        return selectGreater!Ver(v1, v2, v2, v1);
                }
                else static if(isOfType!(T, ubyte16))
                    return __simd(XMM.PMINUB, v1, v2); // available in SSE2
                else
                    static assert(0, "Unsupported vector type: " ~ T.stringof);
            }
            else version(GNU_OR_LDC)
            {
                static if(isOfType!(T, double2))
                    return __builtin_ia32_minpd(v1, v2);
                else static if(isOfType!(T, float4))
                    return __builtin_ia32_minps(v1, v2);
                else static if(isOfType!(T, long2) || isOfType!(T, ulong2))
                    return selectGreater!Ver(v1, v2, v2, v1);
                else static if(isOfType!(T, int4))
                {
                    static if(Ver >= SIMDVer.SSE41)
                        return __builtin_ia32_pminsd128(v1, v2);
                    else
                        return selectGreater!Ver(v1, v2, v2, v1);
                }
                else static if(isOfType!(T, uint4))
                {
                    static if(Ver >= SIMDVer.SSE41)
                        return __builtin_ia32_pminud128(v1, v2);
                    else
                        return selectGreater!Ver(v1, v2, v2, v1);
                }
                else static if(isOfType!(T, short8))
                    return __builtin_ia32_pminsw128(v1, v2); // available in SSE2
                else static if(isOfType!(T, ushort8))
                {
                    static if(Ver >= SIMDVer.SSE41)
                        return __builtin_ia32_pminuw128(v1, v2);
                    else
                        return selectGreater!Ver(v1, v2, v2, v1);
                }
                else static if(isOfType!(T, byte16))
                {
                    static if(Ver >= SIMDVer.SSE41)
                        return __builtin_ia32_pminsb128(v1, v2);
                    else
                        return selectGreater!Ver(v1, v2, v2, v1);
                }
                else static if(isOfType!(T, ubyte16))
                    return __builtin_ia32_pminub128(v1, v2); // available in SSE2
                else
                    static assert(0, "Unsupported vector type: " ~ T.stringof);
            }
        }
        else version(ARM)
        {
            static if(isOfType!(T, float4))
                return __builtin_neon_vminv4sf(v1, v2, ARMOpType!T);
            else static if(is64bitInteger!T)
                return __builtin_neon_vminv2di(v1, v2, ARMOpType!T);
            else static if(is32bitElement!T)
                return __builtin_neon_vminv4si(v1, v2, ARMOpType!T);
            else static if(is16bitElement!T)
                return __builtin_neon_vminv8hi(v1, v2, ARMOpType!T);
            else static if(is8bitElement!T)
                return __builtin_neon_vminv16qi(v1, v2, ARMOpType!T);
            else
                static assert(0, "Unsupported vector type: " ~ T.stringof);
        }
        else
        {
            static assert(0, "Unsupported on this architecture");
        }
    }
}

// max
template max(SIMDVer Ver = simdVer, T)
{
    @attribute("target", targetNames[Ver])
    T max(inout T v1, inout T v2)
    {
        version(X86_OR_X64)
        {
            version(DigitalMars)
            {
                static if(isOfType!(T, double2))
                    return __simd(XMM.MAXPD, v1, v2);
                else static if(isOfType!(T, float4))
                    return __simd(XMM.MAXPS, v1, v2);
                else static if(isOfType!(T, long2) || isOfType!(T, ulong2))
                    return selectGreater!Ver(v1, v2, v1, v2);
                else static if(isOfType!(T, int4))
                {
                    static if(Ver >= SIMDVer.SSE41)
                        return __simd(XMM.PMAXSD, v1, v2);
                    else
                        return selectGreater!Ver(v1, v2, v1, v2);
                }
                else static if(isOfType!(T, uint4))
                {
                    static if(Ver >= SIMDVer.SSE41)
                        return __simd(XMM.PMAXUD, v1, v2);
                    else
                        return selectGreater!Ver(v1, v2, v1, v2);
                }
                else static if(isOfType!(T, short8))
                    return __simd(XMM.PMAXSW, v1, v2); // available in SSE2
                else static if(isOfType!(T, ushort8))
                {
                    static if(Ver >= SIMDVer.SSE41)
                        return __simd(XMM.PAXUW, v1, v2);
                    else
                        return selectGreater!Ver(v1, v2, v1, v2);
                }
                else static if(isOfType!(T, byte16))
                {
                    static if(Ver >= SIMDVer.SSE41)
                        return __simd(XMM.PMAXSB, v1, v2);
                    else
                        return selectGreater!Ver(v1, v2, v1, v2);
                }
                else static if(isOfType!(T, ubyte16))
                    return __simd(XMM.PMAXUB, v1, v2); // available in SSE2
                else
                    static assert(0, "Unsupported vector type: " ~ T.stringof);
            }
            else version(GNU_OR_LDC)
            {
                static if(isOfType!(T, double2))
                    return __builtin_ia32_maxpd(v1, v2);
                else static if(isOfType!(T, float4))
                    return __builtin_ia32_maxps(v1, v2);
                else static if(isOfType!(T, long2) || isOfType!(T, ulong2))
                    return selectGreater!Ver(v1, v2, v1, v2);
                else static if(isOfType!(T, int4))
                {
                    static if(Ver >= SIMDVer.SSE41)
                        return __builtin_ia32_pmaxsd128(v1, v2);
                    else
                        return selectGreater!Ver(v1, v2, v1, v2);
                }
                else static if(isOfType!(T, uint4))
                {
                    static if(Ver >= SIMDVer.SSE41)
                        return __builtin_ia32_pmaxud128(v1, v2);
                    else
                        return selectGreater!Ver(v1, v2, v1, v2);
                }
                else static if(isOfType!(T, short8))
                    return __builtin_ia32_pmaxsw128(v1, v2); // available in SSE2
                else static if(isOfType!(T, ushort8))
                {
                    static if(Ver >= SIMDVer.SSE41)
                        return __builtin_ia32_pmaxuw128(v1, v2);
                    else
                        return selectGreater!Ver(v1, v2, v1, v2);
                }
                else static if(isOfType!(T, byte16))
                {
                    static if(Ver >= SIMDVer.SSE41)
                        return __builtin_ia32_pmaxsb128(v1, v2);
                    else
                        return selectGreater!Ver(v1, v2, v1, v2);
                }
                else static if(isOfType!(T, ubyte16))
                    return __builtin_ia32_pmaxub128(v1, v2); // available in SSE2
                else
                    static assert(0, "Unsupported vector type: " ~ T.stringof);
            }
        }
        else version(ARM)
        {
            static if(isOfType!(T, float4))
                return __builtin_neon_vmaxv4sf(v1, v2, ARMOpType!T);
            else static if(is64bitInteger!T)
                return __builtin_neon_vmaxv2di(v1, v2, ARMOpType!T);
            else static if(is32bitElement!T)
                return __builtin_neon_vmaxv4si(v1, v2, ARMOpType!T);
            else static if(is16bitElement!T)
                return __builtin_neon_vmaxv8hi(v1, v2, ARMOpType!T);
            else static if(is8bitElement!T)
                return __builtin_neon_vmaxv16qi(v1, v2, ARMOpType!T);
            else
                static assert(0, "Unsupported vector type: " ~ T.stringof);
        }
        else
        {
            static assert(0, "Unsupported on this architecture");
        }
    }
}

// clamp values such that a <= v <= b
template clamp(SIMDVer Ver = simdVer, T)
{
    @attribute("target", targetNames[Ver])
    T clamp(inout T a, inout T v, inout T b)
    {
        return max!Ver(a, min!Ver(v, b));
    }
}

// lerp
template lerp(SIMDVer Ver = simdVer, T)
{
    @attribute("target", targetNames[Ver])
    T lerp(inout T a, inout T b, inout T t)
    {
        return madd!Ver(sub!Ver(b, a), t, a);
    }
}


///////////////////////////////////////////////////////////////////////////////
// Floating point operations

// round to the next lower integer value
T floor(SIMDVer Ver = simdVer, T)(inout T v)
{
    version(X86_OR_X64)
    {
        version(DigitalMars)
        {
            static assert(0, "WAITING FOR DMD");
        }
        else version(GNU_OR_LDC)
        {
            static if(isOfType!(T, double2))
            {
                static if(Ver >= SIMDVer.SSE41)
                    return __builtin_ia32_roundpd(v, 1);
                else
                    static assert(0, "Only supported in SSE4.1 and above");
            }
            else static if(isOfType!(T, float4))
            {
                static if(Ver >= SIMDVer.SSE41)
                    return __builtin_ia32_roundps(v, 1);
                else
                    static assert(0, "Only supported in SSE4.1 and above");
            }
            else
            {
                static assert(0, "Unsupported vector type: " ~ T.stringof);
/*
                static const vFloat twoTo23 = (vFloat){ 0x1.0p23f, 0x1.0p23f, 0x1.0p23f, 0x1.0p23f };
                vFloat b = (vFloat) _mm_srli_epi32( _mm_slli_epi32( (vUInt32) v, 1 ), 1 ); //fabs(v)
                vFloat d = _mm_sub_ps( _mm_add_ps( _mm_add_ps( _mm_sub_ps( v, twoTo23 ), twoTo23 ), twoTo23 ), twoTo23 ); //the meat of floor
                vFloat largeMaskE = (vFloat) _mm_cmpgt_ps( b, twoTo23 ); //-1 if v >= 2**23
                vFloat g = (vFloat) _mm_cmplt_ps( v, d ); //check for possible off by one error
                vFloat h = _mm_cvtepi32_ps( (vUInt32) g ); //convert positive check result to -1.0, negative to 0.0
                vFloat t = _mm_add_ps( d, h ); //add in the error if there is one

                //Select between output result and input value based on v >= 2**23
                v = _mm_and_ps( v, largeMaskE );
                t = _mm_andnot_ps( largeMaskE, t );

                return _mm_or_ps( t, v );
*/
            }
        }
    }
    else version(ARM)
    {
        static assert(0, "TODO");
    }
    else
    {
        static assert(0, "Unsupported on this architecture");
    }
}

// round to the next higher integer value
T ceil(SIMDVer Ver = simdVer, T)(inout T v)
{
    version(X86_OR_X64)
    {
        version(DigitalMars)
        {
            static assert(0, "WAITING FOR DMD");
        }
        else version(GNU_OR_LDC)
        {
            static if(isOfType!(T, double2))
            {
                static if(Ver >= SIMDVer.SSE41)
                    return __builtin_ia32_roundpd(v, 2);
                else
                    static assert(0, "Only supported in SSE4.1 and above");
            }
            else static if(isOfType!(T, float4))
            {
                static if(Ver >= SIMDVer.SSE41)
                    return __builtin_ia32_roundps(v, 2);
                else
                    static assert(0, "Only supported in SSE4.1 and above");
            }
            else
                static assert(0, "Unsupported vector type: " ~ T.stringof);
        }
    }
    else version(ARM)
    {
        static assert(0, "TODO");
    }
    else
    {
        static assert(0, "Unsupported on this architecture");
    }
}

// round to the nearest integer value
T round(SIMDVer Ver = simdVer, T)(inout T v)
{
    version(X86_OR_X64)
    {
        version(DigitalMars)
        {
            static assert(0, "WAITING FOR DMD");
        }
        else version(GNU_OR_LDC)
        {
            static if(isOfType!(T, double2))
            {
                static if(Ver >= SIMDVer.SSE41)
                    return __builtin_ia32_roundpd(v, 0);
                else
                    static assert(0, "Only supported in SSE4.1 and above");
            }
            else static if(isOfType!(T, float4))
            {
                static if(Ver >= SIMDVer.SSE41)
                    return __builtin_ia32_roundps(v, 0);
                else
                    static assert(0, "Only supported in SSE4.1 and above");
            }
            else
                static assert(0, "Unsupported vector type: " ~ T.stringof);
        }
    }
    else version(ARM)
    {
        static assert(0, "TODO");
    }
    else
    {
        static assert(0, "Unsupported on this architecture");
    }
}

// truncate fraction (round towards zero)
T trunc(SIMDVer Ver = simdVer, T)(inout T v)
{
    version(X86_OR_X64)
    {
        version(DigitalMars)
        {
            static assert(0, "WAITING FOR DMD");
        }
        else version(GNU_OR_LDC)
        {
            static if(isOfType!(T, double2))
            {
                static if(Ver >= SIMDVer.SSE41)
                    return __builtin_ia32_roundpd(v, 3);
                else
                    static assert(0, "Only supported in SSE4.1 and above");
            }
            else static if(isOfType!(T, float4))
            {
                static if(Ver >= SIMDVer.SSE41)
                    return __builtin_ia32_roundps(v, 3);
                else
                    static assert(0, "Only supported in SSE4.1 and above");
            }
            else
            {
                static assert(0, "Unsupported vector type: " ~ T.stringof);
/*
                static const vFloat twoTo23 = (vFloat){ 0x1.0p23f, 0x1.0p23f, 0x1.0p23f, 0x1.0p23f };
                vFloat b = (vFloat) _mm_srli_epi32( _mm_slli_epi32( (vUInt32) v, 1 ), 1 ); //fabs(v)
                vFloat d = _mm_sub_ps( _mm_add_ps( b, twoTo23 ), twoTo23 ); //the meat of floor
                vFloat largeMaskE = (vFloat) _mm_cmpgt_ps( b, twoTo23 ); //-1 if v >= 2**23
                vFloat g = (vFloat) _mm_cmplt_ps( b, d ); //check for possible off by one error
                vFloat h = _mm_cvtepi32_ps( (vUInt32) g ); //convert positive check result to -1.0, negative to 0.0
                vFloat t = _mm_add_ps( d, h ); //add in the error if there is one

                //put the sign bit back
                vFloat sign = (vFloat) _mm_slli_epi31( _mm_srli128( (vUInt32) v, 31), 31 );
                t = _mm_or_ps( t, sign );

                //Select between output result and input value based on fabs(v) >= 2**23
                v = _mm_and_ps( v, largeMaskE );
                t = _mm_andnot_ps( largeMaskE, t );

                return _mm_or_ps( t, v );
*/
            }
        }
    }
    else version(ARM)
    {
        static assert(0, "TODO");
    }
    else
    {
        static assert(0, "Unsupported on this architecture");
    }
}

///////////////////////////////////////////////////////////////////////////////
// Precise mathematical operations

// divide
T div(SIMDVer Ver = simdVer, T)(inout T v1, inout T v2)
{
    version(X86_OR_X64)
    {
        return v1 / v2;
    }
    else version(ARM)
    {
        return mul!Ver(v1, rcp!Ver(v2));
    }
    else
    {
        static assert(0, "Unsupported on this architecture");
    }
}

// reciprocal
T rcp(SIMDVer Ver = simdVer, T)(inout T v)
{
    version(X86_OR_X64)
    {
        version(DigitalMars)
        {
            static if(isOfType!(T, double2))
                return div!(Ver, T)(1.0, v);
            else static if(isOfType!(T, float4))
                return div!(Ver, T)(1.0f, v);
            else
                static assert(0, "Unsupported vector type: " ~ T.stringof);
        }
        else version(GNU_OR_LDC)
        {
            static if(isOfType!(T, double2) || isOfType!(T, float4))
            {
                T one = 1;
                return div!Ver(one, v);
            }
            else
                static assert(0, "Unsupported vector type: " ~ T.stringof);
        }
    }
    else version(ARM)
    {
        static assert(0, "TODO!");
        static if(isOfType!(T, float4))
            return null;
        else
            static assert(0, "Unsupported vector type: " ~ T.stringof);
    }
    else
    {
        static assert(0, "Unsupported on this architecture");
    }
}

// square root
T sqrt(SIMDVer Ver = simdVer, T)(inout T v)
{
    version(X86_OR_X64)
    {
        version(DigitalMars)
        {
            static if(isOfType!(T, double2))
                return __simd(XMM.SQRTPD, v);
            else static if(isOfType!(T, float4))
                return __simd(XMM.SQRTPS, v);
            else
                static assert(0, "Unsupported vector type: " ~ T.stringof);
        }
        else version(GNU_OR_LDC)
        {
            static if(isOfType!(T, double2))
                return __builtin_ia32_sqrtpd(v);
            else static if(isOfType!(T, float4))
                return __builtin_ia32_sqrtps(v);
            else
                static assert(0, "Unsupported vector type: " ~ T.stringof);
        }
    }
    else version(ARM)
    {
        static assert(0, "TODO!");
        static if(isOfType!(T, float4))
            return null;
        else
            static assert(0, "Unsupported vector type: " ~ T.stringof);
    }
    else
    {
        static assert(0, "Unsupported on this architecture");
    }
}

// reciprocal square root
T rsqrt(SIMDVer Ver = simdVer, T)(inout T v)
{
    version(X86_OR_X64)
    {
        version(DigitalMars)
        {
            static if(isOfType!(T, double2) || isOfType!(T, float4))
                return rcp!Ver(sqrt!Ver(v));
            else
                static assert(0, "Unsupported vector type: " ~ T.stringof);
        }
        else version(GNU_OR_LDC)
        {
            static if(isOfType!(T, double2) || isOfType!(T, float4))
                return rcp!Ver(sqrt!Ver(v));
            else
                static assert(0, "Unsupported vector type: " ~ T.stringof);
        }
    }
    else version(ARM)
    {
        static assert(0, "TODO!");
        static if(isOfType!(T, float4))
            return null;
        else
            static assert(0, "Unsupported vector type: " ~ T.stringof);
    }
    else
    {
        static assert(0, "Unsupported on this architecture");
    }
}


///////////////////////////////////////////////////////////////////////////////
// Vector maths operations

// 2d dot product
T dot2(SIMDVer Ver = simdVer, T)(inout T v1, inout T v2)
{
    version(X86_OR_X64)
    {
        version(DigitalMars)
        {
            static if(isOfType!(T, double2))
            {
                static if(Ver >= SIMDVer.SSE41) // 1 op
                    return __simd(XMM.DPPD, v1, v2, 0x33);
                else static if(Ver >= SIMDVer.SSE3) // 2 ops
                {
                    double2 t = v1 * v2;
                    return __simd(XMM.HADDPD, t, t);
                }
                else // 5 ops
                {
                    double2 t = v1 * v2;
                    return getX!Ver(t) + getY!Ver(t);
                }
            }
            else static if(isOfType!(T, float4))
            {
                static if(Ver >= SIMDVer.SSE41) // 1 op
                    return __simd(XMM.DPPS, v1, v2, 0x3F);
                else static if(Ver >= SIMDVer.SSE3) // 3 ops
                {
                    float4 t = v1 * v2;
                    t = __simd(XMM.HADDPS, t, t);
                    return swizzle!("XXZZ", Ver)(t);
                }
                else // 5 ops
                {
                    float4 t = v1 * v2;
                    return getX!Ver(t) + getY!Ver(t);
                }
            }
            else
                static assert(0, "Unsupported vector type: " ~ T.stringof);
        }
        else version(GNU_OR_LDC)
        {
            static if(isOfType!(T, double2))
            {
                static if(Ver >= SIMDVer.SSE41) // 1 op
                    return __builtin_ia32_dppd(v1, v2, 0x33);
                else static if(Ver >= SIMDVer.SSE3) // 2 ops
                {
                    double2 t = v1 * v2;
                    return __builtin_ia32_haddpd(t, t);
                }
                else // 5 ops
                {
                    double2 t = v1 * v2;
                    return getX!Ver(t) + getY!Ver(t);
                }
            }
            else static if(isOfType!(T, float4))
            {
                static if(Ver >= SIMDVer.SSE41) // 1 op
                    return __builtin_ia32_dpps(v1, v2, 0x3F);
                else static if(Ver >= SIMDVer.SSE3) // 3 ops
                {
                    float4 t = v1 * v2;
                    t = __builtin_ia32_haddps(t, t);
                    return swizzle!("XXZZ", Ver)(t);
                }
                else // 5 ops
                {
                    float4 t = v1 * v2;
                    return getX!Ver(t) + getY!Ver(t);
                }
            }
            else
                static assert(0, "Unsupported vector type: " ~ T.stringof);
        }
    }
    else version(ARM)
    {
        static assert(0, "TODO");
    }
    else
    {
        static assert(0, "Unsupported on this architecture");
    }
}

// 3d dot product
T dot3(SIMDVer Ver = simdVer, T)(inout T v1, inout T v2)
{
    version(X86_OR_X64)
    {
        version(DigitalMars)
        {
            static if(isOfType!(T, float4))
            {
                static if(Ver >= SIMDVer.SSE41) // 1 op
                    return __simd(XMM.DPPS, v1, v2, 0x7F);
                else static if(Ver >= SIMDVer.SSE3) // 4 ops
                {
                    float4 t = shiftElementsRight!(1, Ver)(v1 * v2);
                    t = __simd(XMM.HADDPS, t, t);
                    return __simd(XMM.HADDPS, t, t);
                }
                else // 8 ops!... surely we can do better than this?
                {
                    float4 t = shiftElementsRight!(1, Ver)(v1 * v2);
                    t = t + swizzle!("yxwz", Ver)(t);
                    return t + swizzle!("zzxx", Ver)(t);
                }
            }
            else
                static assert(0, "Unsupported vector type: " ~ T.stringof);
        }
        else version(GNU_OR_LDC)
        {
            static if(isOfType!(T, float4))
            {
                static if(Ver >= SIMDVer.SSE41) // 1 op
                    return __builtin_ia32_dpps(v1, v2, 0x7F);
                else static if(Ver >= SIMDVer.SSE3) // 4 ops
                {
                    float4 t = shiftElementsRight!(1, Ver)(v1 * v2);
                    t = __builtin_ia32_haddps(t, t);
                    return __builtin_ia32_haddps(t, t);
                }
                else // 8 ops!... surely we can do better than this?
                {
                    float4 t = shiftElementsRight!(1, Ver)(v1 * v2);
                    t = t + swizzle!("yxwz", Ver)(t);
                    return t + swizzle!("zzxx", Ver)(t);
                }
            }
            else
                static assert(0, "Unsupported vector type: " ~ T.stringof);
        }
    }
    else version(ARM)
    {
        static assert(0, "TODO");
    }
    else
    {
        static assert(0, "Unsupported on this architecture");
    }
}

// 4d dot product
T dot4(SIMDVer Ver = simdVer, T)(inout T v1, inout T v2)
{
    version(X86_OR_X64)
    {
        version(DigitalMars)
        {
            static if(isOfType!(T, float4))
            {
                static if(Ver >= SIMDVer.SSE41) // 1 op
                    return __simd(XMM.DPPS, v1, v2, 0xFF);
                else static if(Ver >= SIMDVer.SSE3) // 3 ops
                {
                    float4 t = v1 * v2;
                    t = __simd(XMM.HADDPS, t, t);
                    return __simd(XMM.HADDPS, t, t);
                }
                else // 7 ops!... surely we can do better than this?
                {
                    float4 t = v1 * v2;
                    t = t + swizzle!("yxwz", Ver)(t);
                    return t + swizzle!("zzxx", Ver)(t);
                }
            }
            else
                static assert(0, "Unsupported vector type: " ~ T.stringof);
        }
        else version(GNU_OR_LDC)
        {
            static if(isOfType!(T, float4))
            {
                static if(Ver >= SIMDVer.SSE41) // 1 op
                    return __builtin_ia32_dpps(v1, v2, 0xFF);
                else static if(Ver >= SIMDVer.SSE3) // 3 ops
                {
                    float4 t = v1 * v2;
                    t = __builtin_ia32_haddps(t, t);
                    return __builtin_ia32_haddps(t, t);
                }
                else // 7 ops!... surely we can do better than this?
                {
                    float4 t = v1 * v2;
                    t = t + swizzle!("yxwz", Ver)(t);
                    return t + swizzle!("zzxx", Ver)(t);
                }
            }
            else
                static assert(0, "Unsupported vector type: " ~ T.stringof);
        }
    }
    else version(ARM)
    {
        static assert(0, "TODO");
    }
    else
    {
        static assert(0, "Unsupported on this architecture");
    }
}

// homogeneous dot product: v1.xyz1 dot v2.xyzw
T dotH(SIMDVer Ver = simdVer, T)(inout T v1, inout T v2)
{
    return null;
}

// 3d cross product
T cross3(SIMDVer Ver = simdVer, T)(inout T v1, inout T v2)
{
    T left = mul!Ver(swizzle!("YZXW", Ver)(v1), swizzle!("ZXYW", Ver)(v2));
    T right = mul!Ver(swizzle!("ZXYW", Ver)(v1), swizzle!("YZXW", Ver)(v2));
    return sub!Ver(left, right);
}

// 3d magnitude
T magnitude3(SIMDVer Ver = simdVer, T)(inout T v)
{
    return sqrt!Ver(dot3!Ver(v, v));
}

// 4d magnitude
T magnitude4(SIMDVer Ver = simdVer, T)(inout T v)
{
    return sqrt!Ver(dot4!Ver(v, v));
}

// 3d normalise
T normalise3(SIMDVer Ver = simdVer, T)(inout T v)
{
    return div!Ver(v, magnitude3!Ver(v));
}

// 4d normalise
T normalise4(SIMDVer Ver = simdVer, T)(inout T v)
{
    return div!Ver(v, magnitude4!Ver(v));
}

// 3d magnitude squared
T magSq3(SIMDVer Ver = simdVer, T)(inout T v)
{
    return dot3!Ver(v, v);
}

// 4d magnitude squared
T magSq4(SIMDVer Ver = simdVer, T)(inout T v)
{
    return dot4!Ver(v, v);
}


///////////////////////////////////////////////////////////////////////////////
// Fast estimates

// divide estimate
T divEst(SIMDVer Ver = simdVer, T)(inout T v1, inout T v2)
{
    version(X86_OR_X64)
    {
        static if(isOfType!(T, double2))
            return div!Ver(v1, v2);
        else static if(isOfType!(T, float4))
            return mul!Ver(v1, rcpEst!Ver(v2));
        else
            static assert(0, "Unsupported vector type: " ~ T.stringof);
    }
    else version(ARM)
    {
        return mul!Ver(v1, rcpEst!Ver(v2));
    }
    else
    {
        return div!Ver(v1, v2);
    }
}

// reciprocal estimate
T rcpEst(SIMDVer Ver = simdVer, T)(inout T v)
{
    version(X86_OR_X64)
    {
        version(DigitalMars)
        {
            static if(isOfType!(T, double2))
                return div!(Ver, T)(1.0, v);
            else static if(isOfType!(T, float4))
                return __simd(XMM.RCPPS, v);
            else
                static assert(0, "Unsupported vector type: " ~ T.stringof);
        }
        else version(GNU_OR_LDC)
        {
            static if(isOfType!(T, double2))
            {
                T one = 1;
                return div!Ver(one, v);
            }
            else static if(isOfType!(T, float4))
                return __builtin_ia32_rcpps(v);
            else
                static assert(0, "Unsupported vector type: " ~ T.stringof);
        }
    }
    else version(ARM)
    {
        static if(isOfType!(T, float4))
            return __builtin_neon_vrecpev4sf(v, ARMOpType!T);
        else
            static assert(0, "Unsupported vector type: " ~ T.stringof);
    }
    else
    {
        return rcp!Ver(v);
    }
}

// square root estimate
T sqrtEst(SIMDVer Ver = simdVer, T)(inout T v)
{
    version(ARM)
    {
        static assert(0, "TODO: I'm sure ARM has a good estimate for this...");
    }
    else
    {
        return sqrt!Ver(v);
    }
}

// reciprocal square root estimate
T rsqrtEst(SIMDVer Ver = simdVer, T)(inout T v)
{
    version(X86_OR_X64)
    {
        version(DigitalMars)
        {
            static if(isOfType!(T, double2))
                return rcpEst!Ver(sqrtEst!Ver(v));
            else static if(isOfType!(T, float4))
                return __simd(XMM.RSQRTPS, v);
            else
                static assert(0, "Unsupported vector type: " ~ T.stringof);
        }
        else version(GNU_OR_LDC)
        {
            static if(isOfType!(T, double2))
                return rcpEst!Ver(sqrtEst!Ver(v));
            else static if(isOfType!(T, float4))
                return __builtin_ia32_rsqrtps(v);
            else
                static assert(0, "Unsupported vector type: " ~ T.stringof);
        }
    }
    else version(ARM)
    {
        static if(isOfType!(T, float4))
            return __builtin_neon_vrsqrtev4sf(v, ARMOpType!T);
        else
            static assert(0, "Unsupported vector type: " ~ T.stringof);
    }
    else
    {
        return rsqrt!Ver(v);
    }
}

// 3d magnitude estimate
T magEst3(SIMDVer Ver = simdVer, T)(inout T v)
{
    return sqrtEst!Ver(dot3!Ver(v, v));
}

// 4d magnitude estimate
T magEst4(SIMDVer Ver = simdVer, T)(inout T v)
{
    return sqrtEst!Ver(dot4!Ver(v, v));
}

// 3d normalise estimate
T normEst3(SIMDVer Ver = simdVer, T)(inout T v)
{
    return mul!Ver(v, rsqrtEst!Ver(dot3!Ver(v, v)));
}

// 4d normalise estimate
T normEst4(SIMDVer Ver = simdVer, T)(inout T v)
{
    return mul!Ver(v, rsqrtEst!Ver(dot4!Ver(v, v)));
}


///////////////////////////////////////////////////////////////////////////////
// Bitwise operations

// unary complement: ~v
T comp(SIMDVer Ver = simdVer, T)(inout T v)
{
    version(X86_OR_X64)
    {
        return cast(T) ~ cast(int4) v;
    }
    else version(ARM)
    {
        static assert(0, "TODO");
    }
    else
    {
        static assert(0, "Unsupported on this architecture");
    }
}

// bitwise or: v1 | v2
T or(SIMDVer Ver = simdVer, T)(inout T v1, inout T v2)
{
    version(X86_OR_X64)
    {
        version(DigitalMars)
        {
            static if(isOfType!(T, double2))
                return __simd(XMM.ORPD, v1, v2);
            else static if(isOfType!(T, float4))
                return __simd(XMM.ORPS, v1, v2);
            else
                return __simd(XMM.POR, v1, v2);
        }
        else version(GNU)
        {
            static if(isOfType!(T, double2))
                return __builtin_ia32_orpd(v1, v2);
            else static if(isOfType!(T, float4))
                return __builtin_ia32_orps(v1, v2);
            else
                return __builtin_ia32_por128(v1, v2);
        }
        else version(LDC)
        {
            return cast(T) (cast(int4) v1 | cast(int4) v2);
        }
    }
    else version(ARM)
    {
        static assert(0, "TODO");
    }
    else
    {
        static assert(0, "Unsupported on this architecture");
    }
}

// bitwise nor: ~(v1 | v2)
T nor(SIMDVer Ver = simdVer, T)(inout T v1, inout T v2)
{
    return comp!Ver(or!Ver(v1, v2));
}

// bitwise and: v1 & v2
T and(SIMDVer Ver = simdVer, T)(inout T v1, inout T v2)
{
    version(X86_OR_X64)
    {
        version(DigitalMars)
        {
            static if(isOfType!(T, double2))
                return __simd(XMM.ANDPD, v1, v2);
            else static if(isOfType!(T, float4))
                return __simd(XMM.ANDPS, v1, v2);
            else
                return __simd(XMM.PAND, v1, v2);
        }
        else version(GNU)
        {
            static if(isOfType!(T, double2))
                return __builtin_ia32_andpd(v1, v2);
            else static if(isOfType!(T, float4))
                return __builtin_ia32_andps(v1, v2);
            else
                return __builtin_ia32_pand128(v1, v2);
        }
        else version(LDC)
        {
            return cast(T)(cast(int4) v1 & cast(int4) v2);
        }
    }
    else version(ARM)
    {
        static assert(0, "TODO");
    }
    else
    {
        static assert(0, "Unsupported on this architecture");
    }
}

// bitwise nand: ~(v1 & v2)
T nand(SIMDVer Ver = simdVer, T)(inout T v1, inout T v2)
{
    return comp!Ver(and!Ver(v1, v2));
}

// bitwise and with not: v1 & ~v2
T andNot(SIMDVer Ver = simdVer, T)(inout T v1, inout T v2)
{
    version(X86_OR_X64)
    {
        version(DigitalMars)
        {
            static if(isOfType!(T, double2))
                return __simd(XMM.ANDNPD, v2, v1);
            else static if(isOfType!(T, float4))
                return __simd(XMM.ANDNPS, v2, v1);
            else
                return __simd(XMM.PANDN, v2, v1);
        }
        else version(GNU)
        {
            static if(isOfType!(T, double2))
                return __builtin_ia32_andnpd(v2, v1);
            else static if(isOfType!(T, float4))
                return __builtin_ia32_andnps(v2, v1);
            else
                return __builtin_ia32_pandn128(v2, v1);
        }
        else version(LDC)
        {
            return cast(T)(cast(int4) v1 & ~cast(int4) v2);
        }
    }
    else version(ARM)
    {
        static assert(0, "TODO");
    }
    else
    {
        static assert(0, "Unsupported on this architecture");
    }
}

// bitwise xor: v1 ^ v2
T xor(SIMDVer Ver = simdVer, T)(inout T v1, inout T v2)
{
    version(X86_OR_X64)
    {
        version(DigitalMars)
        {
            static if(isOfType!(T, double2))
                return __simd(XMM.XORPD, v1, v2);
            else static if(isOfType!(T, float4))
                return __simd(XMM.XORPS, v1, v2);
            else
                return __simd(XMM.PXOR, v1, v2);
        }
        else version(GNU)
        {
            static if(isOfType!(T, double2))
                return __builtin_ia32_xorpd(v1, v2);
            else static if(isOfType!(T, float4))
                return __builtin_ia32_xorps(v1, v2);
            else
                return __builtin_ia32_pxor128(v1, v2);
        }
        else version(LDC)
        {
            return cast(T) (cast(int4) v1 ^ cast(int4) v2);
        }
    }
    else version(ARM)
    {
        static assert(0, "TODO");
    }
    else
    {
        static assert(0, "Unsupported on this architecture");
    }
}


///////////////////////////////////////////////////////////////////////////////
// Bit shifts and rotates

// binary shift left
T shiftLeft(SIMDVer Ver = simdVer, T)(inout T v, inout T bits)
{
    version(X86_OR_X64)
    {
        version(DigitalMars)
        {
            static if(isOfType!(T, long2) || isOfType!(T, ulong2))
                return  __simd(XMM.PSLLQ, v, bits);
            else static if(isOfType!(T, int4) || isOfType!(T, uint4))
                return  __simd(XMM.PSLLD, v, bits);
            else static if(isOfType!(T, short8) || isOfType!(T, ushort8))
                return  __simd(XMM.PSLLW, v, bits);
            else
                static assert(0, "Unsupported vector type: " ~ T.stringof);
        }
        else version(GNU_OR_LDC)
        {
            static if(isOfType!(T, long2) || isOfType!(T, ulong2))
                return __builtin_ia32_psllq128(v, bits);
            else static if(isOfType!(T, int4) || isOfType!(T, uint4))
                return __builtin_ia32_pslld128(v, bits);
            else static if(isOfType!(T, short8) || isOfType!(T, ushort8))
                return __builtin_ia32_psllw128(v, bits);
            else
                static assert(0, "Unsupported vector type: " ~ T.stringof);
        }
    }
    else version(ARM)
    {
        static assert(0, "TODO");
    }
    else
    {
        static assert(0, "Unsupported on this architecture");
    }
}

// binary shift left by immediate
T shiftLeftImmediate(size_t bits, SIMDVer Ver = simdVer, T)(inout T v)
{
    static if(bits == 0) // shift by 0 is a no-op
        return v;
    else
    {
        version(X86_OR_X64)
        {
            version(DigitalMars)
            {
                static if(isOfType!(T, long2) || isOfType!(T, ulong2))
                    return __simd_ib(XMM.PSLLQ, v, bits);
                else static if(isOfType!(T, int4) || isOfType!(T, uint4))
                    return __simd_ib(XMM.PSLLD, v, bits);
                else static if(isOfType!(T, short8) || isOfType!(T, ushort8))
                    return __simd_ib(XMM.PSLLW, v, bits);
                else
                    static assert(0, "Unsupported vector type: " ~ T.stringof);
            }
            else version(GNU_OR_LDC)
            {
                static if(isOfType!(T, long2) || isOfType!(T, ulong2))
                    return __builtin_ia32_psllqi128(v, bits);
                else static if(isOfType!(T, int4) || isOfType!(T, uint4))
                    return __builtin_ia32_pslldi128(v, bits);
                else static if(isOfType!(T, short8) || isOfType!(T, ushort8))
                    return __builtin_ia32_psllwi128(v, bits);
                else
                    static assert(0, "Unsupported vector type: " ~ T.stringof);
            }
        }
        else version(ARM)
        {
            static assert(0, "TODO");
        }
        else
        {
            static assert(0, "Unsupported on this architecture");
        }
    }
}

// binary shift right (signed types perform arithmatic shift right)
T shiftRight(SIMDVer Ver = simdVer, T)(inout T v, inout T bits)
{
    version(X86_OR_X64)
    {
        version(DigitalMars)
        {
            static if(isOfType!(T, ulong2))
                return __simd(XMM.PSRLQ, v, bits);
            else static if(isOfType!(T, int4))
                return __simd(XMM.PSRAD, v, bits);
            else static if(isOfType!(T, uint4))
                return __simd(XMM.PSRLD, v, bits);
            else static if(isOfType!(T, short8))
                return __simd(XMM.PSRAW, v, bits);
            else static if(isOfType!(T, ushort8))
                return __simd(XMM.PSRLW, v, bits);
            else
                static assert(0, "Unsupported vector type: " ~ T.stringof);
        }
        else version(GNU_OR_LDC)
        {
            static if(isOfType!(T, ulong2))
                return __builtin_ia32_psrlq128(v, bits);
            else static if(isOfType!(T, int4))
                return __builtin_ia32_psrad128(v, bits);
            else static if(isOfType!(T, uint4))
                return __builtin_ia32_psrld128(v, bits);
            else static if(isOfType!(T, short8))
                return __builtin_ia32_psraw128(v, bits);
            else static if(isOfType!(T, ushort8))
                return __builtin_ia32_psrlw128(v, bits);
            else
                static assert(0, "Unsupported vector type: " ~ T.stringof);
        }
    }
    else version(ARM)
    {
        static assert(0, "TODO");
    }
    else
    {
        static assert(0, "Unsupported on this architecture");
    }
}

// binary shift right by immediate (signed types perform arithmatic shift right)
T shiftRightImmediate(size_t bits, SIMDVer Ver = simdVer, T)(inout T v)
{
    static if(bits == 0) // shift by 0 is a no-op
        return v;
    else
    {
        version(X86_OR_X64)
        {
            version(DigitalMars)
            {
                static if(isOfType!(T, ulong2))
                    return __simd_ib(XMM.PSRLQ, v, bits);
                else static if(isOfType!(T, int4))
                    return __simd_ib(XMM.PSRAD, v, bits);
                else static if(isOfType!(T, uint4))
                    return __simd_ib(XMM.PSRLD, v, bits);
                else static if(isOfType!(T, short8))
                    return __simd_ib(XMM.PSRAW, v, bits);
                else static if(isOfType!(T, ushort8))
                    return __simd_ib(XMM.PSRLW, v, bits);
                else
                    static assert(0, "Unsupported vector type: " ~ T.stringof);
            }
            else version(GNU_OR_LDC)
            {
                static if(isOfType!(T, ulong2))
                    return __builtin_ia32_psrlqi128(v, bits);
                else static if(isOfType!(T, int4))
                    return __builtin_ia32_psradi128(v, bits);
                else static if(isOfType!(T, uint4))
                    return __builtin_ia32_psrldi128(v, bits);
                else static if(isOfType!(T, short8))
                    return __builtin_ia32_psrawi128(v, bits);
                else static if(isOfType!(T, ushort8))
                    return __builtin_ia32_psrlwi128(v, bits);
                else
                    static assert(0, "Unsupported vector type: " ~ T.stringof);
            }
        }
        else version(ARM)
        {
            static assert(0, "TODO");
        }
        else
        {
            static assert(0, "Unsupported on this architecture");
        }
    }
}

// shift bytes left by immediate ('left' as they appear in memory)
T shiftBytesLeftImmediate(size_t bytes, SIMDVer Ver = simdVer, T)(inout T v)
{
    static assert(bytes >= 0 && bytes < 16, "Invalid shift amount");
    static if(bytes == 0) // shift by 0 is a no-op
        return v;
    else
    {
        version(X86_OR_X64)
        {
            version(DigitalMars)
            {
                // little endian reads the bytes into the register in reverse, so we need to flip the operations
                return __simd_ib(XMM.PSRLDQ, v, bytes);
            }
            else version(GNU_OR_LDC)
            {
                // little endian reads the bytes into the register in reverse, so we need to flip the operations
                return cast(T) __builtin_ia32_psrldqi128(cast(ubyte16) v, bytes * 8); // TODO: *8? WAT?
            }
        }
        else version(ARM)
        {
            static assert(0, "TODO");
        }
        else
        {
            static assert(0, "Unsupported on this architecture");
        }
    }
}

// shift bytes right by immediate ('right' as they appear in memory)
T shiftBytesRightImmediate(size_t bytes, SIMDVer Ver = simdVer, T)(inout T v)
{
    static assert(bytes >= 0 && bytes < 16, "Invalid shift amount");
    static if(bytes == 0) // shift by 0 is a no-op
        return v;
    else
    {
        version(X86_OR_X64)
        {
            version(DigitalMars)
            {
                // little endian reads the bytes into the register in reverse, so we need to flip the operations
                return __simd_ib(XMM.PSLLDQ, v, bytes);
            }
            else version(GNU_OR_LDC)
            {
                // little endian reads the bytes into the register in reverse, so we need to flip the operations
                return cast(T) __builtin_ia32_pslldqi128(cast(ubyte16) v, bytes * 8); // TODO: *8? WAT?
            }
        }
        else version(ARM)
        {
            static assert(0, "TODO");
        }
        else
        {
            static assert(0, "Unsupported on this architecture");
        }
    }
}

// shift bytes left by immediate
T rotateBytesLeftImmediate(size_t bytes, SIMDVer Ver = simdVer, T)(inout T v)
{
    enum b = bytes & 15;

    static if(b == 0) // shift by 0 is a no-op
        return v;
    else
    {
        static assert(b >= 0 && b < 16, "Invalid shift amount");

        version(X86_OR_X64)
        {
            return or!Ver(shiftBytesLeftImmediate!(b, Ver)(v), shiftBytesRightImmediate!(16 - b, Ver)(v));
        }
        else
        {
            static assert(0, "Unsupported on this architecture");
        }
    }
}

// shift bytes right by immediate
T rotateBytesRightImmediate(size_t bytes, SIMDVer Ver = simdVer, T)(inout T v)
{
    enum b = bytes & 15;

    static if(b == 0) // shift by 0 is a no-op
        return v;
    else
    {
        static assert(b >= 0 && b < 16, "Invalid shift amount");

        version(X86_OR_X64)
        {
            return or!Ver(shiftBytesRightImmediate!(b, Ver)(v), shiftBytesLeftImmediate!(16 - b, Ver)(v));
        }
        else
        {
            static assert(0, "Unsupported on this architecture");
        }
    }
}

// shift elements left
T shiftElementsLeft(size_t n, SIMDVer Ver = simdVer, T)(inout T v)
{
    return shiftBytesLeftImmediate!(n * BaseType!(T).sizeof, Ver)(v);
}

// shift elements right
T shiftElementsRight(size_t n, SIMDVer Ver = simdVer, T)(inout T v)
{
    return shiftBytesRightImmediate!(n * BaseType!(T).sizeof, Ver)(v);
}

// shift elements left, shifting elements from v2 into the exposed elements of v1
T shiftElementsLeftPair(size_t n, SIMDVer Ver = simdVer, T)(inout T v1, inout T v2)
{
    static assert(n >= 0 && n <= NumElements!T, "Invalid shift amount");

    static if(n == 0) // shift by 0 is a no-op
        return v1;
    else static if(n == NumElements!T) // shift by NumElements!T is a no-op
        return v2;
    else
    {
        version(X86_OR_X64)
        {
/+ TODO: Finish me!
            static if(Ver >= SIMDVersion.SSSE3)
            {
                version(DigitalMars)
                    return __simd(XMM.PALIGNR, v1, v2, n * BaseType!(T).sizeof);
                else version(GNU_OR_LDC)
                    static assert(false, "TODO: what is the intrinsics?!");
            }
            else static if(n == NumElements!T/2)
            {
                // sine we're splitting in the middle, we can use a shuf
                static assert(false, "TODO: create the proper shuffle");
            }
            else
+/
            {
                return or!Ver(shiftElementsLeft!(n, Ver)(v1), shiftElementsRight!(NumElements!T - n, Ver)(v2));
            }
        }
        else
        {
            // TODO: detect opportunities to use shuf instead of shifts...
            return or!Ver(shiftElementsLeft!(n, Ver)(v1), shiftElementsRight!(NumElements!T - n, Ver)(v2));
        }
    }
}

// shift elements right, shifting elements from v2 into the exposed elements of v1
T shiftElementsRightPair(size_t n, SIMDVer Ver = simdVer, T)(inout T v1, inout T v2)
{
    return shiftElementsLeftPair!(NumElements!T-n, Ver)(v2, v1);
}

// rotate elements left
T rotateElementsLeft(size_t n, SIMDVer Ver = simdVer, T)(inout T v)
{
    enum e = n & (NumElements!T - 1); // large rotations should wrap

    static if(e == 0) // shift by 0 is a no-op
        return v;
    else
    {
        version(X86_OR_X64)
        {
            static if(is64bitElement!T)
            {
                return swizzle!("YX",Ver)(v);
            }
            else static if(is32bitElement!T)
            {
                // we can do this with shuffles more efficiently than rotating bytes
                static if(e == 1)
                    return swizzle!("YZWX",Ver)(v); // X, [Y, Z, W, X], Y, Z, W
                static if(e == 2)
                    return swizzle!("ZWXY",Ver)(v); // X, Y, [Z, W, X, Y], Z, W
                static if(e == 3)
                    return swizzle!("WXYZ",Ver)(v); // X, Y, Z, [W, X, Y, Z], W
            }
            else
            {
                // perform the operation as bytes
                static if(is16bitElement!T)
                    enum bytes = e * 2;
                else
                    enum bytes = e;

                // we can use a shuf for multiples of 4 bytes
                static if((bytes & 3) == 0)
                    return cast(T)rotateElementsLeft!(bytes >> 2, Ver)(cast(uint4)v);
                else
                    return rotateBytesLeftImmediate!(bytes, Ver)(v);
            }
        }
        else
        {
            static assert(0, "Unsupported on this architecture");
        }
    }
}

// rotate elements right
T rotateElementsRight(size_t n, SIMDVer Ver = simdVer, T)(inout T v)
{
    enum e = n & (NumElements!T - 1); // large rotations should wrap

    static if(e == 0) // shift by 0 is a no-op
        return v;
    else
    {
        // just invert the rotation
        return rotateElementsLeft!(NumElements!T - e, Ver)(v);
    }
}


///////////////////////////////////////////////////////////////////////////////
// Comparisons

// true if all elements: r = A[n] == B[n] && A[n+1] == B[n+1] && ...
bool allEqual(SIMDVer Ver = simdVer, T)(inout T a, inout T b)
{
    return null;
}

// true if all elements: r = A[n] != B[n] && A[n+1] != B[n+1] && ...
bool allNotEqual(SIMDVer Ver = simdVer, T)(inout T a, inout T b)
{
    return null;
}

// true if all elements: r = A[n] > B[n] && A[n+1] > B[n+1] && ...
bool allGreater(SIMDVer Ver = simdVer, T)(inout T a, inout T b)
{
    return null;
}

// true if all elements: r = A[n] >= B[n] && A[n+1] >= B[n+1] && ...
bool allGreaterEqual(SIMDVer Ver = simdVer, T)(inout T a, inout T b)
{
    return null;
}

// true if all elements: r = A[n] < B[n] && A[n+1] < B[n+1] && ...
bool allLess(SIMDVer Ver = simdVer, T)(inout T a, inout T b)
{
    return null;
}

// true if all elements: r = A[n] <= B[n] && A[n+1] <= B[n+1] && ...
bool allLessEqual(SIMDVer Ver = simdVer, T)(inout T a, inout T b)
{
    return null;
}

// true if any elements: r = A[n] == B[n] || A[n+1] == B[n+1] || ...
bool anyEqual(SIMDVer Ver = simdVer, T)(inout T a, inout T b)
{
    return null;
}

// true if any elements: r = A[n] != B[n] || A[n+1] != B[n+1] || ...
bool anyNotEqual(SIMDVer Ver = simdVer, T)(inout T a, inout T b)
{
    return null;
}

// true if any elements: r = A[n] > B[n] || A[n+1] > B[n+1] || ...
bool anyGreater(SIMDVer Ver = simdVer, T)(inout T a, inout T b)
{
    return null;
}

// true if any elements: r = A[n] >= B[n] || A[n+1] >= B[n+1] || ...
bool anyGreaterEqual(SIMDVer Ver = simdVer, T)(inout T a, inout T b)
{
    return null;
}

// true if any elements: r = A[n] < B[n] || A[n+1] < B[n+1] || ...
bool anyLess(SIMDVer Ver = simdVer, T)(inout T a, inout T b)
{
    return null;
}

// true if any elements: r = A[n] <= B[n] || A[n+1] <= B[n+1] || ...
bool anyLessEqual(SIMDVer Ver = simdVer, T)(inout T a, inout T b)
{
    return null;
}


///////////////////////////////////////////////////////////////////////////////
// Generate bit masks

// generate a bitmask of for elements: Rn = An == Bn ? -1 : 0
void16 maskEqual(SIMDVer Ver = simdVer, T)(inout T a, inout T b)
{
    version(X86_OR_X64)
    {
        version(DigitalMars)
        {
            static if(isOfType!(T, double2))
                return __simd(XMM.CMPPD, a, b, 0);
            else static if(isOfType!(T, float4))
                return __simd(XMM.CMPPS, a, b, 0);
            else static if(isOfType!(T, long2) || isOfType!(T, ulong2))
            {
                static if(Ver >= SIMDVer.SSE41)
                    return __simd(XMM.PCMPEQQ, a, b);
                else
                    static assert(0, "Only supported in SSE4.1 and above");
            }
            else static if(isOfType!(T, int4) || isOfType!(T, uint4))
                return __simd(XMM.PCMPEQD, a, b);
            else static if(isOfType!(T, short8) || isOfType!(T, ushort8))
                return __simd(XMM.PCMPEQW, a, b);
            else static if(isOfType!(T, byte16) || isOfType!(T, ubyte16))
                return __simd(XMM.PCMPEQB, a, b);
            else
                static assert(0, "Unsupported vector type: " ~ T.stringof);
        }
        else version(GNU)
        {
            static if(isOfType!(T, double2))
                return __builtin_ia32_cmpeqpd(a, b);
            else static if(isOfType!(T, float4))
                return __builtin_ia32_cmpeqps(a, b);
            else static if(isOfType!(T, long2) || isOfType!(T, ulong2))
            {
                static if(Ver >= SIMDVer.SSE41)
                    return __builtin_ia32_pcmpeqq(a, b);
                else
                    static assert(0, "Only supported in SSE4.1 and above");
            }
            else static if(isOfType!(T, int4) || isOfType!(T, uint4))
                return __builtin_ia32_pcmpeqd128(a, b);
            else static if(isOfType!(T, short8) || isOfType!(T, ushort8))
                return __builtin_ia32_pcmpeqw128(a, b);
            else static if(isOfType!(T, byte16) || isOfType!(T, ubyte16))
                return __builtin_ia32_pcmpeqb128(a, b);
            else
                static assert(0, "Unsupported vector type: " ~ T.stringof);
        }
        else version(LDC)
            return ldcsimd.equalMask!T(a, b);
    }
    else version(ARM)
    {
        static assert(0, "TODO");
    }
    else
    {
        static assert(0, "Unsupported on this architecture");
    }
}

// generate a bitmask of for elements: Rn = An != Bn ? -1 : 0 (SLOW)
void16 maskNotEqual(SIMDVer Ver = simdVer, T)(inout T a, inout T b)
{
    version(X86_OR_X64)
    {
        version(DigitalMars)
        {
            static if(isOfType!(T, double2))
                return __simd(XMM.CMPPD, a, b, 4);
            else static if(isOfType!(T, float4))
                return __simd(XMM.CMPPS, a, b, 4);
            else
                return comp!Ver(cast(void16)maskEqual!Ver(a, b));
        }
        else version(GNU)
        {
            static if(isOfType!(T, double2))
                return __builtin_ia32_cmpneqpd(a, b);
            else static if(isOfType!(T, float4))
                return __builtin_ia32_cmpneqps(a, b);
            else
                return comp!Ver(cast(void16)maskEqual!Ver(a, b));
        }
        else version(LDC)
            return ldcsimd.notEqualMask!T(a, b);
    }
    else version(ARM)
    {
        static assert(0, "TODO");
    }
    else
    {
        static assert(0, "Unsupported on this architecture");
    }
}

// generate a bitmask of for elements: Rn = An > Bn ? -1 : 0
void16 maskGreater(SIMDVer Ver = simdVer, T)(inout T a, inout T b)
{
    version(X86_OR_X64)
    {
        version(DigitalMars)
        {
            static if(isOfType!(T, double2))
                return __simd(XMM.CMPPD, b, a, 1);
            else static if(isOfType!(T, float4))
                return __simd(XMM.CMPPS, b, a, 1);
            else static if(isOfType!(T, long2))
                return __simd(XMM.PCMPGTQ, a, b);
            else static if(isOfType!(T, ulong2))
                return __simd(XMM.PCMPGTQ, a + signMask2, b + signMask2);
            else static if(isOfType!(T, int4))
                return __simd(XMM.PCMPGTD, a, b);
            else static if(isOfType!(T, uint4))
                return __simd(XMM.PCMPGTD, a + signMask4, b + signMask4);
            else static if(isOfType!(T, short8))
                return __simd(XMM.PCMPGTW, a, b);
            else static if(isOfType!(T, ushort8))
                return __simd(XMM.PCMPGTW, a + signMask8, b + signMask8);
            else static if(isOfType!(T, byte16))
                return __simd(XMM.PCMPGTB, a, b);
            else static if(isOfType!(T, ubyte16))
                return __simd(XMM.PCMPGTB, a + signMask16, b + signMask16);
            else
                static assert(0, "Unsupported vector type: " ~ T.stringof);
        }
        else version(GNU)
        {
            static if(isOfType!(T, double2))
                return __builtin_ia32_cmpgtpd(a, b);
            else static if(isOfType!(T, float4))
                return __builtin_ia32_cmpgtps(a, b);
            else static if(isOfType!(T, long2))
                return __builtin_ia32_pcmpgtq(a, b);
            else static if(isOfType!(T, ulong2))
                return __builtin_ia32_pcmpgtq(a + signMask2, b + signMask2);
            else static if(isOfType!(T, int4))
                return __builtin_ia32_pcmpgtd128(a, b);
            else static if(isOfType!(T, uint4))
                return __builtin_ia32_pcmpgtd128(a + signMask4, b + signMask4);
            else static if(isOfType!(T, short8))
                return __builtin_ia32_pcmpgtw128(a, b);
            else static if(isOfType!(T, ushort8))
                return __builtin_ia32_pcmpgtw128(a + signMask8, b + signMask8);
            else static if(isOfType!(T, byte16))
                return __builtin_ia32_pcmpgtb128(a, b);
            else static if(isOfType!(T, ubyte16))
                return __builtin_ia32_pcmpgtb128(a + signMask16, b + signMask16);
            else
                static assert(0, "Unsupported vector type: " ~ T.stringof);
        }
        else version(LDC)
            return ldcsimd.greaterMask!T(a, b);
    }
    else version(ARM)
    {
        static assert(0, "TODO");
    }
    else
    {
        static assert(0, "Unsupported on this architecture");
    }
}

// generate a bitmask of for elements: Rn = An >= Bn ? -1 : 0 (SLOW)
void16 maskGreaterEqual(SIMDVer Ver = simdVer, T)(inout T a, inout T b)
{
    version(X86_OR_X64)
    {
        version(DigitalMars)
        {
            static if(isOfType!(T, double2))
                return __simd(XMM.CMPPD, b, a, 2);
            else static if(isOfType!(T, float4))
                return __simd(XMM.CMPPS, b, a, 2);
            else
                return or!Ver(cast(void16)maskGreater!Ver(a, b), cast(void16)maskEqual!Ver(a, b)); // compound greater OR equal
        }
        else version(GNU)
        {
            static if(isOfType!(T, double2))
                return __builtin_ia32_cmpgepd(a, b);
            else static if(isOfType!(T, float4))
                return __builtin_ia32_cmpgeps(a, b);
            else
                return or!Ver(cast(void16)maskGreater!Ver(a, b), cast(void16)maskEqual!Ver(a, b)); // compound greater OR equal
        }
        else version(LDC)
            return ldcsimd.greaterOrEqualMask!T(a, b);
    }
    else version(ARM)
    {
        static assert(0, "TODO");
    }
    else
    {
        static assert(0, "Unsupported on this architecture");
    }
}

// generate a bitmask of for elements: Rn = An < Bn ? -1 : 0 (SLOW)
void16 maskLess(SIMDVer Ver = simdVer, T)(inout T a, inout T b)
{
    version(X86_OR_X64)
    {
        version(DigitalMars)
        {
            static if(isOfType!(T, double2))
                return __simd(XMM.CMPPD, a, b, 1);
            else static if(isOfType!(T, float4))
                return __simd(XMM.CMPPS, a, b, 1);
            else
                return maskGreater!Ver(b, a); // reverse the args
        }
        else version(GNU)
        {
            static if(isOfType!(T, double2))
                return __builtin_ia32_cmpltpd(a, b);
            else static if(isOfType!(T, float4))
                return __builtin_ia32_cmpltps(a, b);
            else
                return maskGreater!Ver(b, a); // reverse the args
        }
        else version(LDC)
            return ldcsimd.greaterMask!T(b, a);
    }
    else version(ARM)
    {
        static assert(0, "TODO");
    }
    else
    {
        static assert(0, "Unsupported on this architecture");
    }
}

// generate a bitmask of for elements: Rn = An <= Bn ? -1 : 0
void16 maskLessEqual(SIMDVer Ver = simdVer, T)(inout T a, inout T b)
{
    version(X86_OR_X64)
    {
        version(DigitalMars)
        {
            static if(isOfType!(T, double2))
                return __simd(XMM.CMPPD, a, b, 2);
            else static if(isOfType!(T, float4))
                return __simd(XMM.CMPPS, a, b, 2);
            else
                return maskGreaterEqual!Ver(b, a); // reverse the args
        }
        else version(GNU)
        {
            static if(isOfType!(T, double2))
                return __builtin_ia32_cmplepd(a, b);
            else static if(isOfType!(T, float4))
                return __builtin_ia32_cmpleps(a, b);
            else
                return maskGreaterEqual!Ver(b, a); // reverse the args
        }
        else version(LDC)
            return ldcsimd.greaterOrEqualMask!T(b, a);
    }
    else version(ARM)
    {
        static assert(0, "TODO");
    }
    else
    {
        static assert(0, "Unsupported on this architecture");
    }
}


///////////////////////////////////////////////////////////////////////////////
// Branchless selection

// select elements according to: mask == true ? x : y
T select(SIMDVer Ver = simdVer, T)(void16 mask, inout T x, inout T y)
{
    version(X86_OR_X64)
    {
        version(DigitalMars)
        {
            static if(Ver >= SIMDVer.SSE41)
            {
                static if(isOfType!(T, double2))
                    return __simd(XMM.BLENDVPD, y, x, mask);
                else static if(isOfType!(T, float4))
                    return __simd(XMM.BLENDVPS, y, x, mask);
                else
                    return __simd(XMM.PBLENDVB, y, x, mask);
            }
            else
                return xor!Ver(cast(void16)x, and!Ver(mask, xor!Ver(cast(void16)y, cast(void16)x)));
        }
        else version(GNU_OR_LDC)
        {
            static if(Ver >= SIMDVer.SSE41)
            {
                static if(isOfType!(T, double2))
                    return __builtin_ia32_blendvpd(y, x, cast(double2)mask);
                else static if(isOfType!(T, float4))
                    return __builtin_ia32_blendvps(y, x, cast(float4)mask);
                else
                {
                    alias PblendvbParam P;
                    return cast(R)__builtin_ia32_pblendvb128(cast(P)y, cast(P)x, cast(P)mask);
                }
            }
            else
                return xor!Ver(cast(void16)x, and!Ver(mask, xor!Ver(cast(void16)y, cast(void16)x)));
        }
    }
    else version(ARM)
    {
        static assert(0, "TODO");
    }
    else
    {
        // simulate on any architecture without an opcode: ((b ^ a) & mask) ^ a
        return xor!Ver(cast(void16)x, and!Ver(mask, xor!Ver(cast(void16)y, cast(void16)x)));
    }
}

// select elements: Rn = An == Bn ? Xn : Yn
U selectEqual(SIMDVer Ver = simdVer, T, U)(inout T a, inout T b, inout U x, inout U y)
{
    return select!Ver(maskEqual!Ver(a, b), x, y);
}

// select elements: Rn = An != Bn ? Xn : Yn
U selectNotEqual(SIMDVer Ver = simdVer, T, U)(inout T a, inout T b, inout U x, inout U y)
{
    return select!Ver(maskNotEqual!Ver(a, b), x, y);
}

// select elements: Rn = An > Bn ? Xn : Yn
U selectGreater(SIMDVer Ver = simdVer, T, U)(inout T a, inout T b, inout U x, inout U y)
{
    return select!Ver(maskGreater!Ver(a, b), x, y);
}

// select elements: Rn = An >= Bn ? Xn : Yn
U selectGreaterEqual(SIMDVer Ver = simdVer, T, U)(inout T a, inout T b, inout U x, inout U y)
{
    return select!Ver(maskGreaterEqual!Ver(a, b), x, y);
}

// select elements: Rn = An < Bn ? Xn : Yn
U selectLess(SIMDVer Ver = simdVer, T, U)(inout T a, inout T b, inout U x, inout U y)
{
    return select!Ver(maskLess!Ver(a, b), x, y);
}

// select elements: Rn = An <= Bn ? Xn : Yn
U selectLessEqual(SIMDVer Ver = simdVer, T, U)(inout T a, inout T b, inout U x, inout U y)
{
    return select!Ver(maskLessEqual!Ver(a, b), x, y);
}


///////////////////////////////////////////////////////////////////////////////
// Matrix API

// define a/some matrix type(s)
//...

struct float4x4
{
    float4 xRow;
    float4 yRow;
    float4 zRow;
    float4 wRow;
}

struct double2x2
{
    double2 xRow;
    double2 yRow;
}

///////////////////////////////////////////////////////////////////////////////
// Matrix functions

T transpose(SIMDVer Ver = simdVer, T)(inout T m)
{
    version(X86_OR_X64)
    {
        version(DigitalMars)
        {
            static assert(0, "TODO");
        }
        else version(GNU)
        {
            static if(isOfType!(T, float4x4))
            {
                float4 b0 = __builtin_ia32_shufps(m.xRow, m.yRow, shufMask!(0,1,0,1));
                float4 b1 = __builtin_ia32_shufps(m.zRow, m.wRow, shufMask!(0,1,0,1));
                float4 b2 = __builtin_ia32_shufps(m.xRow, m.yRow, shufMask!(2,3,2,3));
                float4 b3 = __builtin_ia32_shufps(m.zRow, m.wRow, shufMask!(2,3,2,3));
                float4 a0 = __builtin_ia32_shufps(b0, b1, shufMask!(0,2,0,2));
                float4 a1 = __builtin_ia32_shufps(b2, b3, shufMask!(0,2,0,2));
                float4 a2 = __builtin_ia32_shufps(b0, b1, shufMask!(1,3,1,3));
                float4 a3 = __builtin_ia32_shufps(b2, b3, shufMask!(1,3,1,3));

                return float4x4(a0, a2, a1, a3);
            }
            else static if (isOfType!(T, double2x2))
            {
                static if(Ver >= SIMDVer.SSE2)
                {
                    return double2x2(
                                     __builtin_ia32_unpcklpd(m.xRow, m.yRow),
                                     __builtin_ia32_unpckhpd(m.xRow, m.yRow));
                }
                else
                    static assert(0, "TODO");
            }
            else
                static assert(0, "Unsupported matrix type: " ~ T.stringof);
        }
    }
    else
    {
        static assert(0, "Unsupported on this architecture");
    }
}


// determinant, etc...


///////////////////////////////////////////////////////////////////////////////
// Private stuff...

private:

version(GNU){} else
{
    // GDC already declares this
    struct attribute
    {
        string attrib;
        string value;
    }
}

// LLVM instructions and intrinsics for LDC.
version(LDC)
{
    template RepeatType(T, size_t n, R...)
    {
        static if(n == 0)
            alias RepeatType = R;
        else
            alias RepeatType = RepeatType!(T, n - 1, T, R);
    }

    version(X86_OR_X64)
        import ldc.gccbuiltins_x86;

    import ldcsimd = ldc.simd;

    alias PblendvbParam = byte16;
}
else version(GNU)
{
    alias PblendvbParam = ubyte16;
}


// Internal constants
enum ulong2 signMask2 = 0x8000_0000_0000_0000;
enum uint4 signMask4 = 0x8000_0000;
enum ushort8 signMask8 = 0x8000;
enum ubyte16 signMask16 = 0x80;


// Helper templates
enum NumElements(T : __vector(V[N]), V, size_t N) = N;

template PromotionOf(T)
{
    template Impl(T)
    {
        static if(is(T : __vector(V[N]), V, size_t N))
            alias Impl = __vector(Impl!V[N/2]);
        else static if(is(T == float))
            alias Impl = double;
        else static if(is(T == int))
            alias Impl = long;
        else static if(is(T == uint))
            alias Impl = ulong;
        else static if(is(T == short))
            alias Impl = int;
        else static if(is(T == ushort))
            alias Impl = uint;
        else static if(is(T == byte))
            alias Impl = short;
        else static if(is(T == ubyte))
            alias Impl = ushort;
        else
            static assert(0, "Incorrect type: " ~ T.stringof);
    }

    alias PromotionOf = std.traits.ModifyTypePreservingSTC!(Impl, OriginalType!T);
}
template DemotionOf(T)
{
    template Impl(T)
    {
        static if(is(T : __vector(V[N]), V, size_t N))
            alias Impl = __vector(Impl!V[N*2]);
        else static if(is(T == double))
            alias Impl = float;
        else static if(is(T == long))
            alias Impl = int;
        else static if(is(T == ulong))
            alias Impl = uint;
        else static if(is(T == int))
            alias Impl = short;
        else static if(is(T == uint))
            alias Impl = ushort;
        else static if(is(T == short))
            alias Impl = byte;
        else static if(is(T == ushort))
            alias Impl = ubyte;
        else
            static assert(0, "Incorrect type: " ~ T.stringof);
    }

    alias DemotionOf = std.traits.ModifyTypePreservingSTC!(Impl, OriginalType!T);
}

enum bool isOfType(U, V) = is(Unqual!U == Unqual!V);

// pull the base type from a vector, array, or primitive
// type. The first version does not work for vectors.
template ArrayType(T : T[]) { alias T ArrayType; }
template ArrayType(T) if(isSIMDVector!T)
{
    // typeof T.array.init does not work for some reason, so we use this
    alias typeof(()
    {
        T a;
        return a.array;
    }()) ArrayType;
}
template BaseType(T)
{
    static if(isSIMDVector!T)
        alias ElementType!T BaseType;
    else static if(isArray!T)
        alias ArrayType!T BaseType;
    else static if(isScalar!T)
        alias T BaseType;
    else
        static assert(0, "Unsupported type");
}

template isScalarFloat(T)
{
    alias U = Unqual!T;
    enum bool isScalarFloat = is(U == float) || is(U == double);
}

template isScalarInt(T)
{
    alias U = Unqual!T;
    enum bool isScalarInt = is(U == long) || is(U == ulong) || is(U == int) || is(U == uint) || is(U == short) || is(U == ushort) || is(U == byte) || is(U == ubyte);
}

template isScalarUnsigned(T)
{
    alias U = Unqual!T;
    enum bool isScalarUnsigned = is(U == ulong) || is(U == uint) || is(U == ushort) || is(U == ubyte);
}

enum bool isScalar(T) = isScalarFloat!T || isScalarInt!T;
enum bool isFloatArray(T) = isArray!T && isScalarFloat!(BaseType!T);
enum bool isIntArray(T) = isArray!T && isScalarInt!(BaseType!T);
enum bool isFloatVector(T) = isSIMDVector!T && isScalarFloat(BaseType!T);
enum bool isIntVector(T) = isSIMDVector!T && isScalarInt(BaseType!T);
enum bool isSigned(T) = isScalarInt!(BaseType!T) && !isScalarUnsigned!(BaseType!T);
enum bool isUnsigned(T) = isScalarUnsigned!(BaseType!T);
enum bool is64bitElement(T) = BaseType!(T).sizeof == 8;
enum bool is64bitInteger(T) = is64bitElement!T && isScalarInt!(BaseType!T);
enum bool is32bitElement(T) = BaseType!(T).sizeof == 4;
enum bool is16bitElement(T) = BaseType!(T).sizeof == 2;
enum bool is8bitElement(T) = BaseType!(T).sizeof == 1;


// Templates for generating TypeTuples
template staticIota(int start, int end, int stride = 1)
{
    static if(start >= end)
        alias staticIota = TypeTuple!();
    else
        alias staticIota = TypeTuple!(start, staticIota!(start + stride, end, stride));
}

template toTypeTuple(alias array, r...)
{
    static if(array.length == r.length)
        alias toTypeTuple = r;
    else
        alias toTypeTuple = toTypeTuple!(array, r, array[r.length]);
}

template interleaveTuples(a...)
{
    static if(a.length == 0)
        alias interleaveTuples = TypeTuple!();
    else
        alias interleaveTuples = TypeTuple!(a[0], a[$ / 2], interleaveTuples!(a[1 .. $ / 2], a[$ / 2 + 1 .. $]));
}

// Some helpers for various architectures
version(X86_OR_X64)
{
    template shufMask(elements...)
    {
        static if(elements.length == 2)
            enum shufMask = ((elements[0] & 1) << 0) | ((elements[1] & 1) << 1);
        else static if(elements.length == 4)
            enum shufMask = ((elements[0] & 3) << 0) | ((elements[1] & 3) << 2) | ((elements[2] & 3) << 4) | ((elements[3] & 3) << 6);
        else
            static assert(0, "Incorrect number of elements");
    }

    template pshufbMask(alias elements)
    {
        template c(a...)
        {
            static if(a.length == 0)
                alias c = TypeTuple!();
            else
                alias c = TypeTuple!(2 * a[0], 2 * a[0] + 1, c!(a[1 .. $]));
        }

        static if(elements.length == 16)
            alias pshufbMask = toTypeTuple!elements;
        else static if(elements.length == 8)
            alias pshufbMask = c!(toTypeTuple!elements);
        else
            static assert(0, "Unsupported parameter length");
    }
}

version(ARM)
{
    template ARMOpType(T, bool Rounded = false)
    {
        // NOTE: 0-unsigned, 1-signed, 2-poly, 3-float, 4-unsigned rounded, 5-signed rounded
        static if(isOfType!(T, double2) || isOfType!(T, float4))
            enum uint ARMOpType = 3;
        else static if(isOfType!(T, long2) || isOfType!(T, int4) || isOfType!(T, short8) || isOfType!(T, byte16))
            enum uint ARMOpType = 1 + (Rounded ? 4 : 0);
        else static if(isOfType!(T, ulong2) || isOfType!(T, uint4) || isOfType!(T, ushort8) || isOfType!(T, ubyte16))
            enum uint ARMOpType = 0 + (Rounded ? 4 : 0);
        else
            static assert(0, "Incorrect type");
    }
}


///////////////////////////////////////////////////////////////////////////////
// Unit test the lot!

unittest
{
    import std.traits;
    import std.typetuple;
    import std.math;
    import std.random;
    import std.conv;

    template staticIota(int start, int end, int stride = 1)
    {
        static if(start >= end)
            alias staticIota = TypeTuple!();
        else
            alias staticIota = TypeTuple!(start, staticIota!(start + stride, end, stride));
    }

    template staticRepeat(int n, a...) if(a.length == 1)
    {
        static if(n <= 0)
            alias staticRepeat = TypeTuple!();
        else
            alias staticRepeat = TypeTuple!(a, staticRepeat!(n - 1, a));
    }

    static T randomVector(T, Rng)(int seed, ref Rng rng)
    {
        alias ET = ElementType!T;

        T r = void;
        foreach(ref e; r.array)
        {
            static if(isFloatingPoint!ET)
                e = uniform(cast(ET)-3.0, cast(ET)3.0, rng)^^5.0;
            else
                e = uniform(ET.min, ET.max, rng);
        }
        return r;
    }

    static bool eq(bool approx = false, T)(T a, T b)
    {
        static if(isIntegral!T || is(T == bool))
        {
            return a == b;
        }
        else static if(isFloatingPoint!T)
        {
            if(a.isnan && b.isnan)
                return true;
            return feqrel(a, b) + 3 >= (approx ? T.mant_dig / 2 : T.mant_dig);
        }
        else static if(isStaticArray!T)
        {
            foreach(i; staticIota!(0, T.length))
                if(!eq!approx(a[i], b[i]))
                    return false;
            return true;
        }
    }

    static void byElement(SIMDVer Ver, bool approx, alias f, alias l, T...)(T v)
    {
        alias BT = ElementType!(T[0]);

        auto r = f!Ver(v);

        typeof(v[0].array) r2 = void;
        foreach(i; staticIota!(0, r2.length))
        {
            // TODO: can't make a template work in this case >_<
            static if(v.length == 1)
                r2[i] = cast(BT)l(v[0].array[i]);
            else static if(v.length == 2)
                r2[i] = cast(BT)l(v[0].array[i], v[1].array[i]);
            else static if(v.length == 3)
                r2[i] = cast(BT)l(v[0].array[i], v[1].array[i], v[2].array[i]);
        }

        assert(eq!(approx)(r.array, r2), "Incorrect result in function: " ~ f.stringof ~ " for type: " ~ T[0].stringof ~ " with SIMD Ver: " ~ Ver.stringof);
    }

    static void byVector(SIMDVer Ver, bool approx, alias f, alias l, T...)(T v)
    {
        auto r = f!Ver(v);

        typeof(v[0].array) r2 = void;

        // TODO: can't make a template work in this case >_<
        static if(v.length == 1)
            r2 = l(v[0].array);
        else static if(v.length == 2)
            r2 = l(v[0].array, v[1].array);
        else static if(v.length == 3)
            r2 = l(v[0].array, v[1].array, v[2].array);

        assert(eq!(approx)(r.array, r2));
    }

    static void testTypes(SIMDVer Ver, bool approx, alias testFunc, alias f, alias l, Types...)()
    {
        // for each type
        foreach(T; Types)
        {
            // work out which vector widths are relevant
            version(X86_OR_X64)
            {
                static if(Ver >= SIMDVer.AVX512)
                    alias Widths = TypeTuple!(128, 256, 512);
                static if(Ver >= SIMDVer.AVX)
                    alias Widths = TypeTuple!(128, 256);
                else
                    alias Widths = TypeTuple!(128);
            }
            else
                alias Widths = TypeTuple!(128);

            // for each vector width
            foreach(w; Widths)
            {
                auto rng = Xorshift128(w);

                // work out __vector type
                enum numElements = w/(T.sizeof*8);
                alias V = __vector(T[numElements]);

                // compile for the right number of args based on whether the function conpiles
                V t;
                static if(__traits(compiles, f!Ver(t)))
                {
                    foreach(i; 0..16)
                        testFunc!(Ver, approx, f, l)(randomVector!V(i, rng));
                }
                else static if(__traits(compiles, f!Ver(t, t)))
                {
                    foreach(i; 0..16)
                        testFunc!(Ver, approx, f, l)(randomVector!V(i, rng), randomVector!V(i, rng));
                }
                else static if(__traits(compiles, f!Ver(t, t, t)))
                {
                    foreach(i; 0..16)
                        testFunc!(Ver, approx, f, l)(randomVector!V(i, rng), randomVector!V(i, rng), randomVector!V(i, rng));
                }
                else static if(__traits(compiles, f!Ver(t, t, t, t)))
                {
                    foreach(i; 0..16)
                        testFunc!(Ver, approx, f, l)(randomVector!V(i, rng), randomVector!V(i, rng), randomVector!V(i, rng), randomVector!V(i, rng));
                }
                else
                    pragma(msg, "Unsupported: " ~ f.stringof ~ " with: " ~ V.stringof ~ " " ~ Ver.stringof);
            }
        }
    }

    void testver(SIMDVer Ver)()
    {
        import std.math;

        T Clamp(T, U)(T a, U x, T b)
        {
            return cast(T)(a > x ? a : (x > b ? b : x));
        }

        alias SignedInts = TypeTuple!(long, int, short, byte);
        alias UnsignedInts = TypeTuple!(ulong, uint, ushort, ubyte);
        alias Ints = TypeTuple!(SignedInts, UnsignedInts);
        alias Floats = TypeTuple!(float, double);
        alias Signed = TypeTuple!(Floats, SignedInts);
        alias All = TypeTuple!(Floats, Ints);

        testTypes!(Ver, false, byElement, std.simd.abs,        (a)       => a < 0 ? -a : a, All)();
        testTypes!(Ver, false, byElement, neg,                (a)       => -a, All)();
        testTypes!(Ver, false, byElement, add,                (a, b)    => a + b, All)();
        testTypes!(Ver, false, byElement, addSaturate,        (a, b)    => Clamp(typeof(a).min, a + b, typeof(a).max), Ints)();
        testTypes!(Ver, false, byElement, sub,                (a, b)    => a - b, All)();
        testTypes!(Ver, false, byElement, subSaturate,        (a, b)    => Clamp(typeof(a).min, a - b, typeof(a).max), Ints)();
        testTypes!(Ver, false, byElement, mul,                (a, b)    => a * b, All)();
        testTypes!(Ver, false, byElement, madd,                (a, b, c) => a*b + c, All)();
        testTypes!(Ver, false, byElement, msub,                (a, b, c) => a*b - c, All)();
        testTypes!(Ver, false, byElement, nmadd,            (a, b, c) => -a*b + c, All)();
        testTypes!(Ver, false, byElement, nmsub,            (a, b, c) => -a*b - c, All)();
        testTypes!(Ver, false, byElement, min,                (a, b)    => a < b ? a : b, All)();
        testTypes!(Ver, false, byElement, max,                (a, b)    => a > b ? a : b, All)();
        testTypes!(Ver, false, byElement, clamp,            (a, v, b) => Clamp(a, v, b), All)();
        testTypes!(Ver, false, byElement, lerp,                (a, b, t) => (b-a)*t + a, All)();
        testTypes!(Ver, false, byElement, comp,                (a)       => ~a, Ints)();
        testTypes!(Ver, false, byElement, or,                (a, b)    => a | b, Ints)();
        testTypes!(Ver, false, byElement, nor,                (a, b)    => ~(a | b), Ints)();
        testTypes!(Ver, false, byElement, and,                (a, b)    => a & b, Ints)();
        testTypes!(Ver, false, byElement, nand,                (a, b)    => ~(a & b), Ints)();
        testTypes!(Ver, false, byElement, andNot,            (a, b)    => a & ~b, Ints)();
        testTypes!(Ver, false, byElement, xor,                (a, b)    => a ^ b, Ints)();

        testTypes!(Ver, false, byElement, div,                (a, b)    => a / b, Floats)();
        testTypes!(Ver, false, byElement, rcp,                (a)       => 1.0/a, Floats)();
        testTypes!(Ver, false, byElement, std.simd.sqrt,    (a)       => std.math.sqrt(a), Floats)();
        testTypes!(Ver, false, byElement, rsqrt,            (a)       => 1.0/std.math.sqrt(a), Floats)();
        testTypes!(Ver, true, byElement, divEst,            (a, b)    => a / b, Floats)();
        testTypes!(Ver, true, byElement, rcpEst,            (a)       => 1.0/a, Floats)();
        testTypes!(Ver, true, byElement, sqrtEst,            (a)       => std.math.sqrt(a), Floats)();
        testTypes!(Ver, true, byElement, rsqrtEst,            (a)       => 1.0/std.math.sqrt(a), Floats)();

        testTypes!(Ver, false, byElement, std.simd.floor,    (a)       => std.math.floor(a), Floats)();
        testTypes!(Ver, false, byElement, std.simd.ceil,    (a)       => std.math.ceil(a), Floats)();
        testTypes!(Ver, false, byElement, std.simd.round,    (a)       => std.math.round(a), Floats)();
        testTypes!(Ver, false, byElement, std.simd.trunc,    (a)       => std.math.trunc(a), Floats)();

        testTypes!(Ver, false, byVector, dot2,                (a, b)    => a[0]*b[0] + a[1]*b[1], Floats)();
        testTypes!(Ver, false, byVector, dot3,                (a, b)    => a[0]*b[0] + a[1]*b[1] + a[2]*b[2], float)();
        testTypes!(Ver, false, byVector, dot4,                (a, b)    => a[0]*b[0] + a[1]*b[1] + a[2]*b[2] + a[3]*b[3], float)();
        testTypes!(Ver, false, byVector, dotH,                (a, b)    => a[0]*b[0] + a[1]*b[1] + a[2]*b[2] + b[3], float)();
        testTypes!(Ver, false, byVector, cross3,            (a, b)    => [ a[1]*b[2] - a[2]*b[1], a[2]*b[0] - a[0]*b[2], a[0]*b[1] - a[1]*b[0], 0], float)();
        testTypes!(Ver, false, byVector, magnitude3,        (a)       => std.math.sqrt(a[0]*a[0] + a[1]*a[1] + a[2]*a[2]), float)();
        testTypes!(Ver, false, byVector, magnitude4,        (a)       => std.math.sqrt(a[0]*a[0] + a[1]*a[1] + a[2]*a[2] + a[3]*a[3]), float)();
        testTypes!(Ver, false, byVector, normalise3,        (a)       { float l = 1/std.math.sqrt(a[0]*a[0] + a[1]*a[1] + a[2]*a[2]); return [ a[0]*l, a[1]*l, a[2]*l, a[3]*l ]; }, float)();
        testTypes!(Ver, false, byVector, normalise4,        (a)       { float l = 1/std.math.sqrt(a[0]*a[0] + a[1]*a[1] + a[2]*a[2] + a[3]*a[3]); return [ a[0]*l, a[1]*l, a[2]*l, a[3]*l ]; }, float)();
        testTypes!(Ver, false, byVector, magSq3,            (a)       => a[0]*a[0] + a[1]*a[1] + a[2]*a[2], float)();
        testTypes!(Ver, false, byVector, magSq4,            (a)       => a[0]*a[0] + a[1]*a[1] + a[2]*a[2] + a[3]*a[3], float)();
        testTypes!(Ver, true, byVector, magEst3,            (a)       => std.math.sqrt(a[0]*a[0] + a[1]*a[1] + a[2]*a[2]), float)();
        testTypes!(Ver, true, byVector, magEst4,            (a)       => std.math.sqrt(a[0]*a[0] + a[1]*a[1] + a[2]*a[2] + a[3]*a[3]), float)();
        testTypes!(Ver, true, byVector, normEst3,            (a)       { float l = 1/std.math.sqrt(a[0]*a[0] + a[1]*a[1] + a[2]*a[2]); return [ a[0]*l, a[1]*l, a[2]*l, a[3]*l ]; }, float)();
        testTypes!(Ver, true, byVector, normEst4,            (a)       { float l = 1/std.math.sqrt(a[0]*a[0] + a[1]*a[1] + a[2]*a[2] + a[3]*a[3]); return [ a[0]*l, a[1]*l, a[2]*l, a[3]*l ]; }, float)();

        //shiftLeft
        //shiftLeftImmediate
        //shiftRight
        //shiftRightImmediate
        //shiftBytesLeftImmediate
        //shiftBytesRightImmediate
        //rotateBytesLeftImmediate
        //rotateBytesRightImmediate
        //shiftElementsLeft
        //shiftElementsRight
        //shiftElementsLeftPair
        //shiftElementsRightPair
        //rotateElementsLeft
        //rotateElementsRight

        //loadScalar
        //loadUnaligned
        //getScalar
        //storeScalar
        //storeUnaligned
        //getX
        //getY
        //getZ
        //getW
        //setX
        //setY
        //setZ
        //setW
        //swizzle
        //permute
        //interleaveLow
        //interleaveHigh

        //unpackLow
        //unpackHigh
        //pack
        //packSaturate

        //toInt
        //toFloat
        //toDouble

    }

    // check for CPU support before calling each function...
    testver!(SIMDVer.SSE);
    testver!(SIMDVer.SSE2);
    testver!(SIMDVer.SSE3);
    testver!(SIMDVer.SSSE3);
    testver!(SIMDVer.SSE41);
    testver!(SIMDVer.SSE42);
//    testver!(SIMDVer.SSE4a);
//    testver!(SIMDVer.SSE5);
//    testver!(SIMDVer.AVX);
//    testver!(SIMDVer.AVX2);
//    testver!(SIMDVer.AVX512);
}
