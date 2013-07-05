module std.simd;

/*
pure:
nothrow:
@safe:
*/

///////////////////////////////////////////////////////////////////////////////
// Version mess
///////////////////////////////////////////////////////////////////////////////

version(X86)
{
    version(DigitalMars)
        version = NoSIMD; // DMD-x86 does not support SIMD
    else
        version = X86_OR_X64;
}
else version(X86_64)
{
    version = X86_OR_X64;
}
else version(PPC)
    version = PowerPC;
else version(PPC64)
    version = PowerPC;

version(GNU)
    version = GNU_OR_LDC;
version(LDC)
    version = GNU_OR_LDC;

///////////////////////////////////////////////////////////////////////////////
// Platform specific imports
///////////////////////////////////////////////////////////////////////////////

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
import std.range;


///////////////////////////////////////////////////////////////////////////////
// Define available versions of vector hardware
///////////////////////////////////////////////////////////////////////////////

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
        AVX,    // 128x2/256bit, 3 operand opcodes
        SSE5,   // (AMD) XOP, FMA4 and CVT16. Introduced to 'Bulldozer' (includes ALL prior architectures)
        AVX2
    }

    // we source this from the compiler flags, ie. -msse2 for instance
    immutable SIMDVer sseVer = SIMDVer.SSE2;
}
else version(PowerPC)
{
    enum SIMDVer
    {
        VMX,
        VMX128,         // Extended register file (128 regs), and some awesome bonus opcodes
        PairedSingle    // Used on Nintendo platforms
    }

    immutable SIMDVer sseVer = SIMDVer.VMX;
}
else version(ARM)
{
    enum SIMDVer
    {
        VFP,    // Should we implement this? it's deprecated on modern ARM chips
        NEON,   // Added to Cortex-A8, Snapdragon
        VFPv4   // Added to Cortex-A15
    }

    immutable SIMDVer sseVer = SIMDVer.NEON;
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

    immutable SIMDVer sseVer = SIMDVer.Unknown;
}
else
{
    // TODO: it would be nice to provide a fallback for __ctfe and hardware with no SIMD unit...

    enum SIMDVer
    {
        None
    }
    
    immutable SIMDVer sseVer = SIMDVer.None;
}

///////////////////////////////////////////////////////////////////////////////
// LLVM instructions and intrinsics for LDC.
///////////////////////////////////////////////////////////////////////////////

version(LDC)
{
    template RepeatType(T, size_t n, R...)
    {
        static if(n == 0)
            alias R RepeatType;
        else
            alias RepeatType!(T, n - 1, T, R) RepeatType;
    }

    version(X86_OR_X64)
        import ldc.gccbuiltins_x86;

    import ldcsimd = ldc.simd;

    alias byte16 PblendvbParam;
}
else version(GNU)
{
    alias ubyte16 PblendvbParam;
}

version(GNU)
    version = GNU_OR_LDC;
version(LDC)
    version = GNU_OR_LDC;

///////////////////////////////////////////////////////////////////////////////
// Internal constants
///////////////////////////////////////////////////////////////////////////////

private
{
    enum ulong2 signMask2 = 0x8000_0000_0000_0000;
    enum uint4 signMask4 = 0x8000_0000;
    enum ushort8 signMask8 = 0x8000;
    enum ubyte16 signMask16 = 0x80;
}

///////////////////////////////////////////////////////////////////////////////
// Internal functions
///////////////////////////////////////////////////////////////////////////////

private
{
    template isVector(T)
    {
        enum bool isVector = is(T : __vector(V[N]), V, size_t N);
    }
    template isOfType(T, V)
    {
        enum bool isOfType = is(Unqual!T == V);
    }
    template VectorType(T : __vector(V[N]), V, size_t N)
    {
        template Impl(T)
        {
            alias Impl = V;
        }

        alias VectorType = std.traits.ModifyTypePreservingSTC!(Impl, OriginalType!T);
    }
    template NumElements(T : __vector(V[N]), V, size_t N)
    {
        enum NumElements = N;
    }
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
                static assert(0, "Incorrect type");
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
                static assert(0, "Incorrect type");
        }

        alias DemotionOf = std.traits.ModifyTypePreservingSTC!(Impl, OriginalType!T);
    }

    // pull the base type from a vector, array, or primitive
    // type. The first version does not work for vectors.
    template ArrayType(T : T[]) { alias T ArrayType; }
    template ArrayType(T) if(isVector!T)
    {
        // typeof T.array.init does not work for some reason, so we use this
        alias typeof(()
        {
            T a;
            return a.array;
        }()) ArrayType;
    }
    //    template VectorType(T : Vector!T) { alias T VectorType; }
    template BaseType(T)
    {
        static if(isVector!T)
            alias VectorType!T BaseType;
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

    template isScalar(T)
    {
        enum bool isScalar = isScalarFloat!T || isScalarInt!T;
    }

    template isFloatArray(T)
    {
        enum bool isFloatArray = isArray!T && isScalarFloat!(BaseType!T);
    }

    template isIntArray(T)
    {
        enum bool isIntArray = isArray!T && isScalarInt!(BaseType!T);
    }

    template isFloatVector(T)
    {
        enum bool isFloatVector = isVector!T && isScalarFloat(BaseType!T);
    }

    template isIntVector(T)
    {
        enum bool isIntVector = isVector!T && isScalarInt(BaseType!T);
    }

    template isSigned(T)
    {
        enum bool isSigned = !isScalarUnsigned!(BaseType!T);
    }

    template isUnsigned(T)
    {
        enum bool isUnsigned = isScalarUnsigned!(BaseType!T);
    }

    template is64bitElement(T)
    {
        enum bool is64bitElement = (BaseType!(T).sizeof == 8);
    }

    template is64bitInteger(T)
    {
        enum bool is64bitInteger = is64bitElement!T && !is(Unqual!(BaseType!(T)) == double);
    }

    template is32bitElement(T)
    {
        enum bool is32bitElement = (BaseType!(T).sizeof == 4);
    }

    template is16bitElement(T)
    {
        enum bool is16bitElement = (BaseType!(T).sizeof == 2);
    }

    template is8bitElement(T)
    {
        enum bool is8bitElement = (BaseType!(T).sizeof == 1);
    }

    /**** Templates for generating TypeTuples ****/

    template staticIota(int start, int end, int stride = 1)
    {
        static if(start >= end)
            alias TypeTuple!() staticIota;
        else
            alias TypeTuple!(start, staticIota!(start + stride, end, stride))
                staticIota;
    }

    template toTypeTuple(alias array, r...)
    {
        static if(array.length == r.length)
            alias r toTypeTuple;
        else
            alias toTypeTuple!(array, r, array[r.length]) toTypeTuple;
    }

    template interleaveTuples(a...)
    {
        static if(a.length == 0)
            alias TypeTuple!() interleaveTuples;
        else
            alias TypeTuple!(a[0], a[$ / 2],
                interleaveTuples!(a[1 .. $ / 2], a[$ / 2 + 1 .. $]))
                interleaveTuples;
    }

    /**** And some helpers for various architectures ****/
    version(X86_OR_X64)
    {
        template shufMask(alias elements)
        {
            static if(elements.length == 2)
                enum shufMask = ((elements[0] & 1) << 0) | ((elements[1] & 1) << 1);
            else static if(elements.length)
                enum shufMask = ((elements[0] & 3) << 0) | ((elements[1] & 3) << 2) | ((elements[2] & 3) << 4) | ((elements[3] & 3) << 6);
        }

        template pshufbMask(alias elements)
        {
            template c(a...)
            {
                static if(a.length == 0)
                    alias TypeTuple!() c;
                else
                    alias TypeTuple!(2 * a[0], 2 * a[0] + 1, c!(a[1 .. $])) c;
            }

            static if(elements.length == 16)
                alias toTypeTuple!elements pshufbMask;
            else static if(elements.length == 8)
                alias c!(toTypeTuple!elements) pshufbMask;
            else
                static assert(0, "Unsupported parameter length.");
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
}


///////////////////////////////////////////////////////////////////////////////
// Public API
///////////////////////////////////////////////////////////////////////////////


///////////////////////////////////////////////////////////////////////////////
// Load and store

// load scalar into all components (!! or just X?). Note: SLOW on many architectures
Vector!T loadScalar(T, SIMDVer Ver = sseVer)(BaseType!T s)
{
    return loadScalar!(T, Ver)(&s);
}

// load scaler from memory
T loadScalar(T, SIMDVer Ver = sseVer)(BaseType!T* pS) if(isVector!T)
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
T loadUnaligned(T, SIMDVer Ver = sseVer)(BaseType!T* pV) @trusted
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
BaseType!T getScalar(SIMDVer Ver = sseVer, T)(T v) if(isVector!T)
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
void storeScalar(SIMDVer Ver = sseVer, T, S)(T v, S* pS) if(isVector!T && is(BaseType!T == S))
{
    // TODO: check this optimises correctly!! (opcode writes directly to memory)
    *pS = getScalar(v);
}

// store the vector to an unaligned address
void storeUnaligned(SIMDVer Ver = sseVer, T, S)(T v, S* pV) @trusted if(isVector!T && is(BaseType!T == S))
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
T getX(SIMDVer Ver = sseVer, T)(T v) if(isVector!T)
{
    version(X86_OR_X64)
    {
        // broadcast the 1st component
        return swizzle!("0", Ver)(v);
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

// broadcast Y to all elements
T getY(SIMDVer Ver = sseVer, T)(T v) if(isVector!T)
{
    version(X86_OR_X64)
    {
        // broadcast the second component
        static if(NumElements!T >= 2)
            return swizzle!("1", Ver)(v);
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

// broadcast Z to all elements
T getZ(SIMDVer Ver = sseVer, T)(T v) if(isVector!T)
{
    version(X86_OR_X64)
    {
        static if(NumElements!T >= 3)
            return swizzle!("2", Ver)(v); // broadcast the 3nd component
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

// broadcast W to all elements
T getW(SIMDVer Ver = sseVer, T)(T v) if(isVector!T)
{
    version(X86_OR_X64)
    {
        static if(NumElements!T >= 4)
            return swizzle!("3", Ver)(v); // broadcast the 4th component
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

// set the X element
T setX(SIMDVer Ver = sseVer, T)(T v, T x) if(isVector!T)
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
T setY(SIMDVer Ver = sseVer, T)(T v, T y) if(isVector!T)
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
T setZ(SIMDVer Ver = sseVer, T)(T v, T z) if(isVector!T)
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
T setW(SIMDVer Ver = sseVer, T)(T v, T w) if(isVector!T)
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

// when this was defined inside swizzle, LDC was allocating an array at run
// time for some reason.
private template elementNames(int Elements)
{
    static if(Elements == 2)
        enum elementNames = ["xy", "01"];
    else static if(Elements == 4)
        enum elementNames = ["xyzw", "rgba", "0123"];
    else static if(Elements == 8)
        enum elementNames = ["01234567"];
    else static if(Elements == 16)
        enum elementNames = ["0123456789abcdef"];
}

// swizzle a vector: r = swizzle!"ZZWX"(v); // r = v.zzwx
T swizzle(string swiz, SIMDVer Ver = sseVer, T)(T v)
{

    // parse the string into elements
    static int[N] parseElements(string swiz, size_t N)(string[] elements)
    {
        import std.string;
        auto swizzleKey = toLower(swiz);

        // initialise the element list to 'identity'
        int[N] r;
        foreach(int i; 0..N)
            r[i] = i;

        static int countUntil(R, T)(R r, T a)
        {
            int i = 0;
            for(; !r.empty; r.popFront(), i++)
                if(r.front == a)
                    return i;

            return -1;
        }

        if(swizzleKey.length == 1)
        {
            // broadcast
            foreach(s; elements)
            {
                auto i = countUntil(s, swizzleKey[0]);
                if(i != -1)
                {
                    // set all elements to 'i'
                    r[] = i;
                    break;
                }
            }
        }
        else
        {
            // regular swizzle
            foreach(s; elements) // foreach swizzle naming convention
            {
                bool bFound = true;
                foreach(i; 0..swizzleKey.length) // foreach char in swizzle string
                {
                    bool keyInS = false;
                    foreach(int j, c; s) // find the offset of the
                    {
                        if(swizzleKey[i] == c)
                        {
                            keyInS = true;
                            r[i] = j;
                            break;
                        }
                    }
                    bFound = bFound && keyInS;
                }

                if(bFound)
                    break;
            }
        }
        return r;
    }

    static bool isIdentity(size_t N)(int[N] elements)
    {
        foreach(i, e; elements)
        {
            if(e != i)
                return false;
        }
        return true;
    }

    static bool isBroadcast(size_t N)(int[N] elements)
    {
        foreach(i; 1..N)
        {
            if(elements[i] != elements[i-1])
                return false;
        }
        return true;
    }

    enum size_t Elements = NumElements!T;

    static assert(swiz.length > 0 && swiz.length <= Elements, "Invalid number of components in swizzle string");

    // parse the swizzle string
    enum int[Elements] elements = parseElements!(swiz, Elements)(elementNames!Elements);

    // early out if no actual swizzle
    static if(isIdentity!Elements(elements))
    {
        return v;
    }
    else
    {
        version(X86_OR_X64)
        {
            version(DigitalMars)
            {
                // broadcasts can usually be implemented more efficiently...
                static if(isBroadcast!Elements(elements) && !is32bitElement!T)
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
                        return __simd(XMM.PSHUFD, v, v, shufMask!([elements[0]*2, elements[0]*2 + 1, elements[1]*2, elements[1]*2 + 1]));
                    else static if(isOfType!(T, float4))
                    {
                        static if(elements == [0,0,2,2] && Ver >= SIMDVer.SSE3)
                            return __simd(XMM.MOVSLDUP, v);
                        else static if(elements == [1,1,3,3] && Ver >= SIMDVer.SSE3)
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
                static if(isBroadcast!Elements(elements) && !is32bitElement!T)
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
                        return __builtin_ia32_pshufd(v, shufMask!([elements[0]*2, elements[0]*2 + 1, elements[1]*2, elements[1]*2 + 1]));
                    else static if(isOfType!(T, float4))
                    {
                        static if(elements == [0,0,2,2] && Ver >= SIMDVer.SSE3)
                            return __builtin_ia32_movsldup(v);
                        else static if(elements == [1,1,3,3] && Ver >= SIMDVer.SSE3)
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
T permute(SIMDVer Ver = sseVer, T)(T v, ubyte16 control)
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
T interleaveLow(SIMDVer Ver = sseVer, T)(T v1, T v2)
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
T interleaveHigh(SIMDVer Ver = sseVer, T)(T v1, T v2)
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
            alias interleaveTuples!(
                staticIota!(n / 2, n), staticIota!(n + n / 2, n + n)) mask;

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

PromotionOf!T unpackLow(SIMDVer Ver = sseVer, T)(T v)
{
    version(X86_OR_X64)
    {
        version(DigitalMars)
        {
            enum int n = NumElements!T;
            T zero = 0;
            alias interleaveTuples!(staticIota!(0, n / 2), staticIota!(n, n + n / 2)) index;
            return cast(PromotionOf!T) shufflevector(v, zero, index);
        }
        else version(GNU)
        {
            static if(isOfType!(T, int4))
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
        else version(LDC)
        {
            enum int n = NumElements!T;
            T zero = 0;
            alias interleaveTuples!(
                staticIota!(0, n / 2), staticIota!(n, n + n / 2)) index;

            return cast(PromotionOf!T) ldcsimd.shufflevector!(T, index)(v, zero);
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

PromotionOf!T unpackHigh(SIMDVer Ver = sseVer, T)(T v)
{
    version(X86_OR_X64)
    {
        version(DigitalMars)
        {
            enum int n = NumElements!T;
            T zero = 0;
            alias interleaveTuples!(
                                    staticIota!(n / 2, n), staticIota!(n + n / 2, n + n)) index;

            return cast(PromotionOf!T) shufflevector(v, zero, index);
        }
        else version(GNU)
        {
            static if(isOfType!(T, int4))
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
        else version(LDC)
        {
            enum int n = NumElements!T;
            T zero = 0;
            alias interleaveTuples!(
                staticIota!(n / 2, n), staticIota!(n + n / 2, n + n)) index;

            return cast(PromotionOf!T) ldcsimd.shufflevector!(T, index)(v, zero);
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

DemotionOf!T pack(SIMDVer Ver = sseVer, T)(T v1, T v2)
{
    version(X86_OR_X64)
    {
        version(DigitalMars)
        {
            static assert(0, "TODO");
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
            else static if(isOfType!(T, short8))
            {
                static assert(0, "TODO");
                // return _mm_packs_epi16( _mm_srai_epi16( _mm_slli_epi16( a, 8), 8), _mm_srai_epi16( _mm_slli_epi16( b, 8), 8) );
            }
            else static if(isOfType!(T, ushort8))
            {
                static assert(0, "TODO");
                // return _mm_packs_epi16( _mm_and_si128( a, 0x00FF), _mm_and_si128( b, 0x00FF) );
            }
            else
                static assert(0, "Unsupported vector type: " ~ T.stringof);
        }
        else version(LDC)
        {
            alias DemotionOf!T D;
            enum int n = NumElements!D;

            return ldcsimd.shufflevector!(D, staticIota!(0, 2 * n, 2))(
                cast(D) v1, cast(D) v2);
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

DemotionOf!T packSaturate(SIMDVer Ver = sseVer, T)(T v1, T v2)
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

int4 toInt(SIMDVer Ver = sseVer, T)(T v)
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

float4 toFloat(SIMDVer Ver = sseVer, T)(T v)
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
                    return __simd(XMM.CVTPD2PS, v); // TODO: z,w are undefined... should we repeat xy to zw?
                else
                    static assert(0, "Unsupported vector type: " ~ T.stringof);
            }
            else version(GNU_OR_LDC)
            {
                static if(isOfType!(T, int4))
                    return __builtin_ia32_cvtdq2ps(v);
                else static if(isOfType!(T, double2))
                    return __builtin_ia32_cvtpd2ps(v); // TODO: z,w are undefined... should we repeat xy to zw?
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

double2 toDouble(SIMDVer Ver = sseVer, T)(T v)
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

T abs(SIMDVer Ver = sseVer, T)(T v)
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
                    else static if(is8bitElement!(T))
                        return __simd(XMM.PABSB, v);
                }
                else static if(isOfType!(T, int4))
                {
                    int4 t = shiftRightImmediate!(31, Ver)(v);
                    return sub!Ver(xor!Ver(v, t), t);
                }
                else static if(isOfType!(T, short8))
                {
                    return max!Ver(v, sub!Ver(0, v));
                }
                else static if(isOfType!(T, byte16))
                {
                    byte16 t = maskGreater!Ver(0, v);
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
                    return max!Ver(v, sub!Ver(0, v));
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

// unary negate
T neg(SIMDVer Ver = sseVer, T)(T v)
{
    static assert(!isUnsigned!(T), "Can not negate unsigned value");

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

// binary add
T add(SIMDVer Ver = sseVer, T)(T v1, T v2)
{
    version(X86_OR_X64)
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

// binary add and saturate
T addSaturate(SIMDVer Ver = sseVer, T)(T v1, T v2)
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

// binary subtract
T sub(SIMDVer Ver = sseVer, T)(T v1, T v2)
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

// binary subtract and saturate
T subSaturate(SIMDVer Ver = sseVer, T)(T v1, T v2)
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

// binary multiply
T mul(SIMDVer Ver = sseVer, T)(T v1, T v2)
{
    version(X86_OR_X64)
    {
        return v1 * v2;
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

// multiply and add: v1*v2 + v3
T madd(SIMDVer Ver = sseVer, T)(T v1, T v2, T v3)
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
                return v1*v2 + v3;
        }
        else version(GNU_OR_LDC)    // TODO: declare the SSE5 builtins for LDC
        {
            static if(isOfType!(T, double2) && Ver == SIMDVer.SSE5)
                return __builtin_ia32_fmaddpd(v1, v2, v3);
            else static if(isOfType!(T, float4) && Ver == SIMDVer.SSE5)
                return __builtin_ia32_fmaddps(v1, v2, v3);
            else
                return v1*v2 + v3;
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

// multiply and subtract: v1*v2 - v3
T msub(SIMDVer Ver = sseVer, T)(T v1, T v2, T v3)
{
    version(X86_OR_X64)
    {
        version(DigitalMars)
        {
            return v1*v2 - v3;
        }
        else version(GNU_OR_LDC)    // TODO: declare the SSE5 builtins for LDC
        {
            static if(isOfType!(T, double2) && Ver == SIMDVer.SSE5)
                return __builtin_ia32_fmsubpd(v1, v2, v3);
            else static if(isOfType!(T, float4) && Ver == SIMDVer.SSE5)
                return __builtin_ia32_fmsubps(v1, v2, v3);
            else
                return v1*v2 - v3;
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

// negate multiply and add: -(v1*v2) + v3
T nmadd(SIMDVer Ver = sseVer, T)(T v1, T v2, T v3)
{
    version(X86_OR_X64)
    {
        version(DigitalMars)
        {
            return v3 - v1*v2;
        }
        else version(GNU_OR_LDC)    // TODO: declare the SSE5 builtins for LDC
        {
            static if(isOfType!(T, double2) && Ver == SIMDVer.SSE5)
                return __builtin_ia32_fnmaddpd(v1, v2, v3);
            else static if(isOfType!(T, float4) && Ver == SIMDVer.SSE5)
                return __builtin_ia32_fnmaddps(v1, v2, v3);
            else
                return v3 - (v1*v2);
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

// negate multiply and subtract: -(v1*v2) - v3
T nmsub(SIMDVer Ver = sseVer, T)(T v1, T v2, T v3)
{
    version(X86_OR_X64)
    {
        version(DigitalMars)
        {
            return -(v1*v2) - v3;
        }
        else version(GNU_OR_LDC)    // TODO: declare the SSE5 builtins for LDC
        {
            static if(isOfType!(T, double2) && Ver == SIMDVer.SSE5)
                return __builtin_ia32_fnmsubpd(v1, v2, v3);
            else static if(isOfType!(T, float4) && Ver == SIMDVer.SSE5)
                return __builtin_ia32_fnmsubps(v1, v2, v3);
            else
                return -(v1*v2) - v3;
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

// min
T min(SIMDVer Ver = sseVer, T)(T v1, T v2)
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

// max
T max(SIMDVer Ver = sseVer, T)(T v1, T v2)
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

// clamp values such that a <= v <= b
T clamp(SIMDVer Ver = sseVer, T)(T a, T v, T b)
{
    return max!Ver(a, min!Ver(v, b));
}

// lerp
T lerp(SIMDVer Ver = sseVer, T)(T a, T b, T t)
{
    return madd!Ver(sub!Ver(b, a), t, a);
}


///////////////////////////////////////////////////////////////////////////////
// Floating point operations

// round to the next lower integer value
T floor(SIMDVer Ver = sseVer, T)(T v)
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
T ceil(SIMDVer Ver = sseVer, T)(T v)
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
T round(SIMDVer Ver = sseVer, T)(T v)
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
T trunc(SIMDVer Ver = sseVer, T)(T v)
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
T div(SIMDVer Ver = sseVer, T)(T v1, T v2)
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
T rcp(SIMDVer Ver = sseVer, T)(T v)
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
T sqrt(SIMDVer Ver = sseVer, T)(T v)
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
T rsqrt(SIMDVer Ver = sseVer, T)(T v)
{
    version(X86_OR_X64)
    {
        version(DigitalMars)
        {
            static if(isOfType!(T, double2))
                return rcp!Ver(sqrt!Ver(v));
            else static if(isOfType!(T, float4))
                return  __simd(XMM.RSQRTPS, v);
            else
                static assert(0, "Unsupported vector type: " ~ T.stringof);
        }
        else version(GNU_OR_LDC)
        {
            static if(isOfType!(T, double2))
                return rcp!Ver(sqrt!Ver(v));
            else static if(isOfType!(T, float4))
                return __builtin_ia32_rsqrtps(v);
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
T dot2(SIMDVer Ver = sseVer, T)(T v1, T v2)
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
                    t = __simd(XMM.haddps, t, t);
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
T dot3(SIMDVer Ver = sseVer, T)(T v1, T v2)
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
T dot4(SIMDVer Ver = sseVer, T)(T v1, T v2)
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
T dotH(SIMDVer Ver = sseVer, T)(T v1, T v2)
{
    return null;
}

// 3d cross product
T cross3(SIMDVer Ver = sseVer, T)(T v1, T v2)
{
    T left = mul!Ver(swizzle!("YZXW", Ver)(v1), swizzle!("ZXYW", Ver)(v2));
    T right = mul!Ver(swizzle!("ZXYW", Ver)(v1), swizzle!("YZXW", Ver)(v2));
    return sub!Ver(left, right);
}

// 3d magnitude
T magnitude3(SIMDVer Ver = sseVer, T)(T v)
{
    return sqrt!Ver(magSq3!Ver(v));
}

// 4d magnitude
T magnitude4(SIMDVer Ver = sseVer, T)(T v)
{
    return sqrt!Ver(magSq4!Ver(v));
}

// 3d normalise
T normalise3(SIMDVer Ver = sseVer, T)(T v)
{
    return v * rsqrt!Ver(magSq3!Ver(v));
}

// 4d normalise
T normalise4(SIMDVer Ver = sseVer, T)(T v)
{
    return v * rsqrt!Ver(magSq4!Ver(v));
}

// 3d magnitude squared
T magSq3(SIMDVer Ver = sseVer, T)(T v)
{
    return dot3!Ver(v, v);
}

// 4d magnitude squared
T magSq4(SIMDVer Ver = sseVer, T)(T v)
{
    return dot4!Ver(v, v);
}


///////////////////////////////////////////////////////////////////////////////
// Fast estimates

// divide estimate
T divEst(SIMDVer Ver = sseVer, T)(T v1, T v2)
{
    version(ARM)
    {
        return mul!Ver(v1, rcpEst!Ver(v2));
    }
    else
    {
        return div!Ver(v1, v2);
    }
}

// reciprocal estimate
T rcpEst(SIMDVer Ver = sseVer, T)(T v)
{
    version(ARM)
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
T sqrtEst(SIMDVer Ver = sseVer, T)(T v)
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
T rsqrtEst(SIMDVer Ver = sseVer, T)(T v)
{
    version(ARM)
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
T magEst3(SIMDVer Ver = sseVer, T)(T v)
{
    return sqrtEst!Ver(magSq3!Ver(v));
}

// 4d magnitude estimate
T magEst4(SIMDVer Ver = sseVer, T)(T v)
{
    return sqrtEst!Ver(magSq4!Ver(v));
}

// 3d normalise estimate
T normEst3(SIMDVer Ver = sseVer, T)(T v)
{
    return v * rsqrtEst!Ver(magSq3!Ver(v));
}

// 4d normalise estimate
T normEst4(SIMDVer Ver = sseVer, T)(T v)
{
    return v * rsqrtEst!Ver(magSq4!Ver(v));
}


///////////////////////////////////////////////////////////////////////////////
// Bitwise operations

// unary complement: ~v
T comp(SIMDVer Ver = sseVer, T)(T v)
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
T or(SIMDVer Ver = sseVer, T)(T v1, T v2)
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
T nor(SIMDVer Ver = sseVer, T)(T v1, T v2)
{
    return comp!Ver(or!Ver(v1, v2));
}

// bitwise and: v1 & v2
T and(SIMDVer Ver = sseVer, T)(T v1, T v2)
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
T nand(SIMDVer Ver = sseVer, T)(T v1, T v2)
{
    return comp!Ver(and!Ver(v1, v2));
}

// bitwise and with not: v1 & ~v2
T andNot(SIMDVer Ver = sseVer, T)(T v1, T v2)
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
T xor(SIMDVer Ver = sseVer, T)(T v1, T v2)
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
T shiftLeft(SIMDVer Ver = sseVer, T)(T v1, T v2)
{
    version(X86_OR_X64)
    {
        version(DigitalMars)
        {
            static if(isOfType!(T, long2) || isOfType!(T, ulong2))
                return  __simd(XMM.PSLLQ, v1, v2);
            else static if(isOfType!(T, int4) || isOfType!(T, uint4))
                return  __simd(XMM.PSLLD, v1, v2);
            else static if(isOfType!(T, short8) || isOfType!(T, ushort8))
                return  __simd(XMM.PSLLW, v1, v2);
            else
                static assert(0, "Unsupported vector type: " ~ T.stringof);
        }
        else version(GNU_OR_LDC)
        {
            static if(isOfType!(T, long2) || isOfType!(T, ulong2))
                return __builtin_ia32_psllq128(v1, v2);
            else static if(isOfType!(T, int4) || isOfType!(T, uint4))
                return __builtin_ia32_pslld128(v1, v2);
            else static if(isOfType!(T, short8) || isOfType!(T, ushort8))
                return __builtin_ia32_psllw128(v1, v2);
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
T shiftLeftImmediate(size_t bits, SIMDVer Ver = sseVer, T)(T v)
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
T shiftRight(SIMDVer Ver = sseVer, T)(T v1, T v2)
{
    version(X86_OR_X64)
    {
        version(DigitalMars)
        {
            static if(isOfType!(T, ulong2))
                return __simd(XMM.PSRLQ, v1, v2);
            else static if(isOfType!(T, int4))
                return __simd(XMM.PSRAD, v1, v2);
            else static if(isOfType!(T, uint4))
                return __simd(XMM.PSRLD, v1, v2);
            else static if(isOfType!(T, short8))
                return __simd(XMM.PSRAW, v1, v2);
            else static if(isOfType!(T, ushort8))
                return __simd(XMM.PSRLW, v1, v2);
            else
                static assert(0, "Unsupported vector type: " ~ T.stringof);
        }
        else version(GNU_OR_LDC)
        {
            static if(isOfType!(T, ulong2))
                return __builtin_ia32_psrlq128(v1, v2);
            else static if(isOfType!(T, int4))
                return __builtin_ia32_psrad128(v1, v2);
            else static if(isOfType!(T, uint4))
                return __builtin_ia32_psrld128(v1, v2);
            else static if(isOfType!(T, short8))
                return __builtin_ia32_psraw128(v1, v2);
            else static if(isOfType!(T, ushort8))
                return __builtin_ia32_psrlw128(v1, v2);
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
T shiftRightImmediate(size_t bits, SIMDVer Ver = sseVer, T)(T v)
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
T shiftBytesLeftImmediate(size_t bytes, SIMDVer Ver = sseVer, T)(T v)
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
T shiftBytesRightImmediate(size_t bytes, SIMDVer Ver = sseVer, T)(T v)
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
T rotateBytesLeftImmediate(size_t bytes, SIMDVer Ver = sseVer, T)(T v)
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
T rotateBytesRightImmediate(size_t bytes, SIMDVer Ver = sseVer, T)(T v)
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
T shiftElementsLeft(size_t n, SIMDVer Ver = sseVer, T)(T v)
{
    return shiftBytesLeftImmediate!(n * BaseType!(T).sizeof, Ver)(v);
}

// shift elements right
T shiftElementsRight(size_t n, SIMDVer Ver = sseVer, T)(T v)
{
    return shiftBytesRightImmediate!(n * BaseType!(T).sizeof, Ver)(v);
}

// shift elements left
T shiftElementsLeftPair(size_t n, SIMDVer Ver = sseVer, T)(T v1, T v2)
{
    static if(n == 0) // shift by 0 is a no-op
        return v;
    else
    {
        static assert(n >= 0 && n < NumElements!T, "Invalid shift amount");

        // TODO: detect opportunities to use shuf instead of shifts...
        return or!Ver(shiftElementsLeft!(n, Ver)(v1), shiftElementsRight!(NumElements!T - n, Ver)(v2));
    }
}

// shift elements right
T shiftElementsRightPair(size_t n, SIMDVer Ver = sseVer, T)(T v1, T v2)
{
    static if(n == 0) // shift by 0 is a no-op
        return v;
    else
    {
        static assert(n >= 0 && n < NumElements!T, "Invalid shift amount");

        // TODO: detect opportunities to use shuf instead of shifts...
        return or!Ver(shiftElementsRight!(n, Ver)(v1), shiftElementsLeft!(NumElements!T - n, Ver)(v2));
    }
}

// rotate elements left
T rotateElementsLeft(size_t n, SIMDVer Ver = sseVer, T)(T v)
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
T rotateElementsRight(size_t n, SIMDVer Ver = sseVer, T)(T v)
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
bool allEqual(SIMDVer Ver = sseVer, T)(T a, T b)
{
    return null;
}

// true if all elements: r = A[n] != B[n] && A[n+1] != B[n+1] && ...
bool allNotEqual(SIMDVer Ver = sseVer, T)(T a, T b)
{
    return null;
}

// true if all elements: r = A[n] > B[n] && A[n+1] > B[n+1] && ...
bool allGreater(SIMDVer Ver = sseVer, T)(T a, T b)
{
    return null;
}

// true if all elements: r = A[n] >= B[n] && A[n+1] >= B[n+1] && ...
bool allGreaterEqual(SIMDVer Ver = sseVer, T)(T a, T b)
{
    return null;
}

// true if all elements: r = A[n] < B[n] && A[n+1] < B[n+1] && ...
bool allLess(SIMDVer Ver = sseVer, T)(T a, T b)
{
    return null;
}

// true if all elements: r = A[n] <= B[n] && A[n+1] <= B[n+1] && ...
bool allLessEqual(SIMDVer Ver = sseVer, T)(T a, T b)
{
    return null;
}

// true if any elements: r = A[n] == B[n] || A[n+1] == B[n+1] || ...
bool anyEqual(SIMDVer Ver = sseVer, T)(T a, T b)
{
    return null;
}

// true if any elements: r = A[n] != B[n] || A[n+1] != B[n+1] || ...
bool anyNotEqual(SIMDVer Ver = sseVer, T)(T a, T b)
{
    return null;
}

// true if any elements: r = A[n] > B[n] || A[n+1] > B[n+1] || ...
bool anyGreater(SIMDVer Ver = sseVer, T)(T a, T b)
{
    return null;
}

// true if any elements: r = A[n] >= B[n] || A[n+1] >= B[n+1] || ...
bool anyGreaterEqual(SIMDVer Ver = sseVer, T)(T a, T b)
{
    return null;
}

// true if any elements: r = A[n] < B[n] || A[n+1] < B[n+1] || ...
bool anyLess(SIMDVer Ver = sseVer, T)(T a, T b)
{
    return null;
}

// true if any elements: r = A[n] <= B[n] || A[n+1] <= B[n+1] || ...
bool anyLessEqual(SIMDVer Ver = sseVer, T)(T a, T b)
{
    return null;
}


///////////////////////////////////////////////////////////////////////////////
// Generate bit masks

// generate a bitmask of for elements: Rn = An == Bn ? -1 : 0
void16 maskEqual(SIMDVer Ver = sseVer, T)(T a, T b)
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
void16 maskNotEqual(SIMDVer Ver = sseVer, T)(T a, T b)
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
void16 maskGreater(SIMDVer Ver = sseVer, T)(T a, T b)
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
void16 maskGreaterEqual(SIMDVer Ver = sseVer, T)(T a, T b)
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
void16 maskLess(SIMDVer Ver = sseVer, T)(T a, T b)
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
void16 maskLessEqual(SIMDVer Ver = sseVer, T)(T a, T b)
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
T select(SIMDVer Ver = sseVer, T)(void16 mask, T x, T y)
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
                return xor!Ver(x, and!Ver(cast(T)mask, xor!Ver(y, x)));
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
                    return cast(T)__builtin_ia32_pblendvb128(cast(P)y, cast(P)x, cast(P)mask);
                }
            }
            else
                return xor!Ver(x, and!Ver(cast(T)mask, xor!Ver(y, x)));
        }
    }
    else version(ARM)
    {
        static assert(0, "TODO");
    }
    else
    {
        // simulate on any architecture without an opcode: ((b ^ a) & mask) ^ a
        return xor!Ver(x, cast(T)and!Ver(mask, cast(void16)xor!Ver(y, x)));
    }
}

// select elements: Rn = An == Bn ? Xn : Yn
T selectEqual(SIMDVer Ver = sseVer, T)(T a, T b, T x, T y)
{
    return select!Ver(maskEqual!Ver(a, b), x, y);
}

// select elements: Rn = An != Bn ? Xn : Yn
T selectNotEqual(SIMDVer Ver = sseVer, T)(T a, T b, T x, T y)
{
    return select!Ver(maskNotEqual!Ver(a, b), x, y);
}

// select elements: Rn = An > Bn ? Xn : Yn
T selectGreater(SIMDVer Ver = sseVer, T)(T a, T b, T x, T y)
{
    return select!Ver(maskGreater!Ver(a, b), x, y);
}

// select elements: Rn = An >= Bn ? Xn : Yn
T selectGreaterEqual(SIMDVer Ver = sseVer, T)(T a, T b, T x, T y)
{
    return select!Ver(maskGreaterEqual!Ver(a, b), x, y);
}

// select elements: Rn = An < Bn ? Xn : Yn
T selectLess(SIMDVer Ver = sseVer, T)(T a, T b, T x, T y)
{
    return select!Ver(maskLess!Ver(a, b), x, y);
}

// select elements: Rn = An <= Bn ? Xn : Yn
T selectLessEqual(SIMDVer Ver = sseVer, T)(T a, T b, T x, T y)
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

T transpose(SIMDVer Ver = sseVer, T)(T m)
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
                float4 b0 = __builtin_ia32_shufps(m.xRow, m.yRow, shufMask!([0,1,0,1]));
                float4 b1 = __builtin_ia32_shufps(m.zRow, m.wRow, shufMask!([0,1,0,1]));
                float4 b2 = __builtin_ia32_shufps(m.xRow, m.yRow, shufMask!([2,3,2,3]));
                float4 b3 = __builtin_ia32_shufps(m.zRow, m.wRow, shufMask!([2,3,2,3]));
                float4 a0 = __builtin_ia32_shufps(b0, b1, shufMask!([0,2,0,2]));
                float4 a1 = __builtin_ia32_shufps(b2, b3, shufMask!([0,2,0,2]));
                float4 a2 = __builtin_ia32_shufps(b0, b1, shufMask!([1,3,1,3]));
                float4 a3 = __builtin_ia32_shufps(b2, b3, shufMask!([1,3,1,3]));

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
// Unit test the lot!

unittest
{
    // test all functions and all types

    // >_< *** EPIC LONG TEST FUNCTION HERE ***
}
