module std.simd;

pure:
nothrow:
@safe:

///////////////////////////////////////////////////////////////////////////////
// Version mess
///////////////////////////////////////////////////////////////////////////////

version(X86)
{
	version = X86_OR_X64;
}
else version(X86_64)
{
	version = X86_OR_X64;
}

version(PPC)
{
	version = PowerPC;
}
else version(PPC64)
{
	version = PowerPC;
}


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

import core.simd;
import std.traits;


///////////////////////////////////////////////////////////////////////////////
// Define available versions of vector hardware
///////////////////////////////////////////////////////////////////////////////

version(X86_OR_X64)
{
	enum SIMDVer
	{
		SSE,
		SSE2,
		SSE3,	// Later Pentium4 + Athlon64
		SSSE3,	// Introduced in Intel 'Core' series, AMD 'Bobcat'
		SSE41,	// (Intel) Introduced in 45nm 'Core' series
		SSE42,	// (Intel) Introduced in i7
		SSE4a,	// (AMD) Introduced to 'Bobcat' (includes SSSE3 and below)
		AVX,	// 128x2/256bit, 3 operand opcodes
		SSE5,	// (AMD) XOP, FMA4 and CVT16. Introduced to 'Bulldozer' (includes ALL prior architectures)
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
		VMX128 // extended register file (128 regs), and some awesome bonus opcodes
	}

	immutable SIMDVer sseVer = SIMDVer.VMX;
}
else version(ARM)
{
	enum SIMDVer
	{
		VFP,	// should we implement this? it's deprecated on modern ARM chips
		NEON,	// added to Cortex-A8, Snapdragon
		VFPv4	// added to Cortex-A15
	}

	immutable SIMDVer sseVer = SIMDVer.NEON;
}
else
{
	static assert(0, "Unsupported architecture.");

	// TODO: I think it would be worth emulating this API with pure FPU on unsupported architectures...
}


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
	/**** <WORK AROUNDS> ****/
	template isVector(T) // TODO: REMOVE BRUTAL WORKAROUND
	{
		static if(is(T == double2) || is(T == float4) ||
				  is(T == long2) || is(T == ulong2) ||
				  is(T == int4) || is(T == uint4) ||
				  is(T == short8) || is(T == ushort8) ||
				  is(T == byte16) || is(T == ubyte16))
			enum bool isVector = true;
		else
			enum bool isVector = false;
	}
	template VectorType(T)
	{
		static if(is(T == double2))
			alias double VectorType;
		else static if(is(T == float4))
			alias float VectorType;
		else static if(is(T == long2))
			alias long VectorType;
		else static if(is(T == ulong2))
			alias ulong VectorType;
		else static if(is(T == int4))
			alias int VectorType;
		else static if(is(T == uint4))
			alias uint VectorType;
		else static if(is(T == short8))
			alias short VectorType;
		else static if(is(T == ushort8))
			alias ushort VectorType;
		else static if(is(T == byte16))
			alias byte VectorType;
		else static if(is(T == ubyte16))
			alias ubyte VectorType;
		else
			static assert(0, "Incorrect type");
	}
	template NumElements(T)
	{
		static if(is(T == double2) || is(T == long2) || is(T == ulong2))
			enum size_t NumElements = 2;
		else static if(is(T == float4) || is(T == int4) || is(T == uint4))
			enum size_t NumElements = 4;
		else static if(is(T == short8) || is(T == ushort8))
			enum size_t NumElements = 8;
		else static if(is(T == byte16) || is(T == ubyte16))
			enum size_t NumElements = 16;
		else
			static assert(0, "Incorrect type");
	}
	template UnsignedOf(T)
	{
		static if(is(T == long2) || is(T == ulong2))
			alias ulong2 UnsignedOf;
		else static if(is(T == int4) || is(T == uint4))
			alias uint4 UnsignedOf;
		else static if(is(T == short8) || is(T == ushort8))
			alias ushort8 UnsignedOf;
		else static if(is(T == byte16) || is(T == ubyte16))
			alias ubyte16 UnsignedOf;
		else static if(is(T == long) || is(T == ulong))
			alias ulong UnsignedOf;
		else static if(is(T == int) || is(T == uint))
			alias uint UnsignedOf;
		else static if(is(T == short) || is(T == ushort))
			alias ushort UnsignedOf;
		else static if(is(T == byte) || is(T == ubyte))
			alias ubyte UnsignedOf;
		else
			static assert(0, "Incorrect type");
	}
	template SignedOf(T)
	{
		static if(is(T == long2) || is(T == ulong2))
			alias long2 SignedOf;
		else static if(is(T == int4) || is(T == uint4))
			alias int4 SignedOf;
		else static if(is(T == short8) || is(T == ushort8))
			alias short8 SignedOf;
		else static if(is(T == byte16) || is(T == ubyte16))
			alias byte16 SignedOf;
		else static if(is(T == long) || is(T == ulong))
			alias long SignedOf;
		else static if(is(T == int) || is(T == uint))
			alias int SignedOf;
		else static if(is(T == short) || is(T == ushort))
			alias short SignedOf;
		else static if(is(T == byte) || is(T == ubyte))
			alias byte SignedOf;
		else
			static assert(0, "Incorrect type");
	}
	template PromotionOf(T)
	{
		static if(is(T == int4))
			alias long2 PromotionOf;
		else static if(is(T == uint4))
			alias ulong2 PromotionOf;
		else static if(is(T == short8))
			alias int4 PromotionOf;
		else static if(is(T == ushort8))
			alias uint4 PromotionOf;
		else static if(is(T == byte16))
			alias short8 PromotionOf;
		else static if(is(T == ubyte16))
			alias ushort8 PromotionOf;
		else static if(is(T == int))
			alias long PromotionOf;
		else static if(is(T == uint))
			alias ulong PromotionOf;
		else static if(is(T == short))
			alias int PromotionOf;
		else static if(is(T == ushort))
			alias uint PromotionOf;
		else static if(is(T == byte))
			alias short PromotionOf;
		else static if(is(T == ubyte))
			alias ushort PromotionOf;
		else
			static assert(0, "Incorrect type");
	}
	template DemotionOf(T)
	{
		static if(is(T == long2))
			alias int4 DemotionOf;
		else static if(is(T == ulong2))
			alias uint4 DemotionOf;
		else static if(is(T == int4))
			alias short8 DemotionOf;
		else static if(is(T == uint4))
			alias ushort8 DemotionOf;
		else static if(is(T == short8))
			alias byte16 DemotionOf;
		else static if(is(T == ushort8))
			alias ubyte16 DemotionOf;
		else static if(is(T == long))
			alias int DemotionOf;
		else static if(is(T == ulong))
			alias uint DemotionOf;
		else static if(is(T == int))
			alias short DemotionOf;
		else static if(is(T == uint))
			alias ushort DemotionOf;
		else static if(is(T == short))
			alias byte DemotionOf;
		else static if(is(T == ushort))
			alias ubyte DemotionOf;
		else
			static assert(0, "Incorrect type");
	}
	/**** </WORK AROUNDS> ****/


	// a template to test if a type is a vector type
	//	template isVector(T : __vector(U[N]), U, size_t N) { enum bool isVector = true; }
	//	template isVector(T) { enum bool isVector = false; }

	// pull the base type from a vector, array, or primitive type
	template ArrayType(T : T[]) { alias T ArrayType; }
	//	template VectorType(T : Vector!T) { alias T VectorType; }
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
		enum bool isScalarFloat = is(T == float) || is(T == double);
	}

	template isScalarInt(T)
	{
		enum bool isScalarInt = is(T == long) || is(T == ulong) || is(T == int) || is(T == uint) || is(T == short) || is(T == ushort) || is(T == byte) || is(T == ubyte);
	}

	template isScalarUnsigned(T)
	{
		enum bool isScalarUnsigned = is(T == ulong) || is(T == uint) || is(T == ushort) || is(T == ubyte);
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
		enum bool is64bitInteger = is64bitElement!T && !is(T == double);
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

	/**** And some helpers for various architectures ****/
	version(X86_OR_X64)
	{
		int shufMask(size_t N)(int[N] elements)
		{
			static if(N == 2)
				return ((elements[0] & 1) << 0) | ((elements[1] & 1) << 1);
			else static if(N == 4)
				return ((elements[0] & 3) << 0) | ((elements[1] & 3) << 2) | ((elements[2] & 3) << 4) | ((elements[3] & 3) << 6);
		}
	}

	version(ARM)
	{
		template ARMOpType(T, bool Rounded = false)
		{
			// NOTE: 0-unsigned, 1-signed, 2-poly, 3-float, 4-unsigned rounded, 5-signed rounded
			static if(is(T == double2) || is(T == float4))
				enum uint ARMOpType = 3;
			else static if(is(T == long2) || is(T == int4) || is(T == short8) || is(T == byte16))
				enum uint ARMOpType = 1 + (Rounded ? 4 : 0);
			else static if(is(T == ulong2) || is(T == uint4) || is(T == ushort8) || is(T == ubyte16))
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
Vector!T loadScalar(SIMDVer Ver = sseVer, T)(T s)
{
	return loadScalar(&s);
}

// load scaler from memory
Vector!T loadScalar(SIMDVer Ver = sseVer, T)(T* pS)
{
	version(X86_OR_X64)
	{
		version(DigitalMars)
		{
			static assert(0, "TODO");
		}
		else version(GNU)
		{
			static if(is(T == float4))
				return __builtin_ia32_loadsss(pS);
			else static if(is(T == double2))
				return __builtin_ia32_loadddup(pV);
			else
				return *cast(Vector!T*)pS;
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
Vector!T loadUnaligned(SIMDVer Ver = sseVer, T)(T* pV)
{
	version(X86_OR_X64)
	{
		version(DigitalMars)
		{
			static assert(0, "TODO");
		}
		else version(GNU)
		{
			static if(is(T == float4))
				return __builtin_ia32_loadups(pV);
			else static if(is(T == double2))
				return __builtin_ia32_loadupd(pV);
			else
				return cast(Vector!T)__builtin_ia32_loaddqu(cast(char*)pV);
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

// return the X element in a scalar register
T getScalar(SIMDVer Ver = sseVer, T)(Vector!T v)
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
				static if(is(T == float4))
					return __builtin_ia32_vec_ext_v4sf(v, 0);
				else static if(is64bitElement!T)
					return __builtin_ia32_vec_ext_v2di(v, 0);
				else static if(is32bitElement!T)
					return __builtin_ia32_vec_ext_v4si(v, 0);
//				else static if(is16bitElement!T)
//					return __builtin_ia32_vec_ext_v8hi(v, 0); // does this opcode exist??
				else static if(is8bitElement!T)
					return __builtin_ia32_vec_ext_v16qi(v, 0);
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

// store the X element to the address provided
void storeScalar(SIMDVer Ver = sseVer, T)(Vector!T v, T* pS)
{
	// TODO: check this optimises correctly!! (opcode writes directly to memory)
	*pS = getScalar(v);
}

// store the vector to an unaligned address
void storeUnaligned(SIMDVer Ver = sseVer, T)(Vector!T v, T* pV)
{
	version(X86_OR_X64)
	{
		version(DigitalMars)
		{
			static assert(0, "TODO");
		}
		else version(GNU)
		{
			static if(is(T == float4))
				__builtin_ia32_storeups(pV, v);
			else static if(is(T == double2))
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
T getX(SIMDVer Ver = sseVer, T)(T v)
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
T getY(SIMDVer Ver = sseVer, T)(T v)
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
T getZ(SIMDVer Ver = sseVer, T)(T v)
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
T getW(SIMDVer Ver = sseVer, T)(T v)
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
T setX(SIMDVer Ver = sseVer, T)(T v, T x)
{
	version(X86_OR_X64)
	{
		version(DigitalMars)
		{
			static assert(0, "TODO");
		}
		else version(GNU)
		{
			static if(Ver >= SIMDVer.SSE41 && !is8bitElement!T)
			{
				static if(is(T == double2))
					return __builtin_ia32_blendpd(v, x, 1);
				else static if(is(T == float4))
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
T setY(SIMDVer Ver = sseVer, T)(T v, T y)
{
	version(X86_OR_X64)
	{
		version(DigitalMars)
		{
			static assert(0, "TODO");
		}
		else version(GNU)
		{
			static if(Ver >= SIMDVer.SSE41 && !is8bitElement!T)
			{
				static if(is(T == double2))
					return __builtin_ia32_blendpd(v, y, 2);
				else static if(is(T == float4))
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
T setZ(SIMDVer Ver = sseVer, T)(T v, T z)
{
	version(X86_OR_X64)
	{
		version(DigitalMars)
		{
			static assert(0, "TODO");
		}
		else version(GNU)
		{
			static if(Ver >= SIMDVer.SSE41 && !is8bitElement!T)
			{
				static if(is(T == float4))
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
T setW(SIMDVer Ver = sseVer, T)(T v, T w)
{
	version(X86_OR_X64)
	{
		version(DigitalMars)
		{
			static assert(0, "TODO");
		}
		else version(GNU)
		{
			static if(Ver >= SIMDVer.SSE41 && !is8bitElement!T)
			{
				static if(is(T == float4))
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
T swizzle(string swiz, SIMDVer Ver = sseVer, T)(T v)
{
	// parse the string into elements
	int[N] parseElements(string swiz, size_t N)(string[] elements)
	{
		import std.string;
		import std.algorithm;
		auto swizzleKey = toLower(swiz);

		// initialise the element list to 'identity'
		int[N] r;
		foreach(int i; 0..N)
			r[i] = i;

		if(swizzleKey.length == 1)
		{
			// broadcast
			foreach(s; elements)
			{
				int i = cast(int) countUntil(s, swizzleKey[0]);
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
			bool bFound = false;
			foreach(s; elements) // foreach swizzle naming convention
			{
				foreach(i; 0..swizzleKey.length) // foreach char in swizzle string
				{
					foreach(int j, c; s) // find the offset of the 
					{
						if(swizzleKey[i] == c)
						{
							bFound = true;
							r[i] = j;
							break;
						}
					}
				}

				if(bFound)
					break;
			}
		}
		return r;
	}

	bool isIdentity(size_t N)(int[N] elements)
	{
		foreach(i, e; elements)
		{
			if(e != i)
				return false;
		}
		return true;
	}

	bool isBroadcast(size_t N)(int[N] elements)
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

	static if(Elements == 2)
		enum elementNames = ["xy", "01"];
	else static if(Elements == 4)
		enum elementNames = ["xyzw", "rgba", "0123"];
	else static if(Elements == 8)
		enum elementNames = ["01234567"];
	else static if(Elements == 16)
		enum elementNames = ["0123456789ABCDEF"];

	// parse the swizzle string
	enum int[Elements] elements = parseElements!(swiz, Elements)(elementNames);

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
				static assert(0, "TODO");
			}
			else version(GNU)
			{
				// broadcasts can usually be implemented more efficiently...
				static if(isBroadcast!Elements(elements) && !is32bitElement!T)
				{
					static if(is(T == double2))
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
//							immutable ubyte16 permuteControl = [1,0,1,0,1,0,1,0,1,0,1,0,1,0,1,0];
//							return __builtin_ia32_pshufb128(v, permuteControl);
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
					static if(is(T == double2))
						return __builtin_ia32_shufpd(v, v, shufMask!Elements(elements)); // swizzle: YX
					else static if(is64bitElement!(T)) // (u)long2
						// use a 32bit integer shuffle for swizzle: YZ
						return __builtin_ia32_pshufd(v, shufMask!4([elements[0]*2, elements[0]*2 + 1, elements[1]*2, elements[1]*2 + 1]));
					else static if(is(T == float4))
					{
						static if(elements == [0,0,2,2] && Ver >= SIMDVer.SSE3)
							return __builtin_ia32_movsldup(v);
						else static if(elements == [1,1,3,3] && Ver >= SIMDVer.SSE3)
							return __builtin_ia32_movshdup(v);
						else
							return __builtin_ia32_shufps(v, v, shufMask!Elements(elements));
					}
					else static if(is32bitElement!(T))
						return __builtin_ia32_pshufd(v, shufMask!Elements(elements));
					else
					{
						// TODO: 16 and 8bit swizzles...
						static assert(0, "Unsupported vector type: " ~ T.stringof);
					}
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
}

// assign bytes to the target according to a permute control register
T permute(SIMDVer Ver = sseVer, T)(T v, ubyte16 control)
{
	version(X86_OR_X64)
	{
		version(DigitalMars)
		{
			static assert(0, "TODO");
		}
		else version(GNU)
		{
			static if(Ver >= SIMDVer.SSSE3)
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
			static assert(0, "TODO");
		}
		else version(GNU)
		{
			static if(is(T == float4))
				return __builtin_ia32_unpcklps(v1, v2);
			else static if(is(T == double2))
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
			static assert(0, "TODO");
		}
		else version(GNU)
		{
			static if(is(T == float4))
				return __builtin_ia32_unpckhps(v1, v2);
			else static if(is(T == double2))
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
			static assert(0, "TODO");
		}
		else version(GNU)
		{
			static if(is(T == int4))
				return cast(PromotionOf!T)interleaveLow!Ver(v, shiftRightImmediate!(31, Ver)(v));
			else static if(is(T == uint4))
				return cast(PromotionOf!T)interleaveLow!Ver(v, 0);
			else static if(is(T == short8))
				return shiftRightImmediate!(16, Ver)(cast(int4)interleaveLow!Ver(v, v));
			else static if(is(T == ushort8))
				return cast(PromotionOf!T)interleaveLow!Ver(v, 0);
			else static if(is(T == byte16))
				return shiftRightImmediate!(8, Ver)(cast(short8)interleaveLow!Ver(v, v));
			else static if(is(T == ubyte16))
				return cast(PromotionOf!T)interleaveLow!Ver(v, 0);
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

PromotionOf!T unpackHigh(SIMDVer Ver = sseVer, T)(T v)
{
	version(X86_OR_X64)
	{
		version(DigitalMars)
		{
			static assert(0, "TODO");
		}
		else version(GNU)
		{
			static if(is(T == int4))
				return cast(PromotionOf!T)interleaveHigh!Ver(v, shiftRightImmediate!(31, Ver)(v));
			else static if(is(T == uint4))
				return cast(PromotionOf!T)interleaveHigh!Ver(v, cast(uint4)0);
			else static if(is(T == short8))
				return shiftRightImmediate!(16, Ver)(cast(int4)interleaveHigh!Ver(v, v));
			else static if(is(T == ushort8))
				return cast(PromotionOf!T)interleaveHigh!Ver(v, cast(ushort8)0);
			else static if(is(T == byte16))
				return shiftRightImmediate!(8, Ver)(cast(short8)interleaveHigh!Ver(v, v));
			else static if(is(T == ubyte16))
				return cast(PromotionOf!T)interleaveHigh!Ver(v, cast(ubyte16)0);
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
			static if(is(T == long2))
				static assert(0, "TODO");
			else static if(is(T == ulong2))
				static assert(0, "TODO");
			else static if(is(T == int4))
			{
				static assert(0, "TODO");
				// return _mm_packs_epi32( _mm_srai_epi32( _mm_slli_epi16( a, 16), 16), _mm_srai_epi32( _mm_slli_epi32( b, 16), 16) );
			}
			else static if(is(T == uint4))
			{
				static assert(0, "TODO");
				// return _mm_packs_epi32( _mm_srai_epi32( _mm_slli_epi32( a, 16), 16), _mm_srai_epi32( _mm_slli_epi32( b, 16), 16) );
			}
			else static if(is(T == short8))
			{
				static assert(0, "TODO");
				// return _mm_packs_epi16( _mm_srai_epi16( _mm_slli_epi16( a, 8), 8), _mm_srai_epi16( _mm_slli_epi16( b, 8), 8) );
			}
			else static if(is(T == ushort8))
			{
				static assert(0, "TODO");
				// return _mm_packs_epi16( _mm_and_si128( a, 0x00FF), _mm_and_si128( b, 0x00FF) );
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

DemotionOf!T packSaturate(SIMDVer Ver = sseVer, T)(T v1, T v2)
{
	version(X86_OR_X64)
	{
		version(DigitalMars)
		{
			static assert(0, "TODO");
		}
		else version(GNU)
		{
			static if(is(T == int4))
				return __builtin_ia32_packssdw128(v1, v2);
			else static if(is(T == uint4))
				static assert(0, "TODO: should we emulate this?");
			else static if(is(T == short8))
				return __builtin_ia32_packsswb128(v1, v2);
			else static if(is(T == ushort8))
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
	version(X86_OR_X64)
	{
		version(DigitalMars)
		{
			static assert(0, "TODO");
		}
		else version(GNU)
		{
			static if(is(T == float4))
				return __builtin_ia32_cvtps2dq(v);
			else static if(is(T == double2))
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

float4 toFloat(SIMDVer Ver = sseVer, T)(T v)
{
	version(X86_OR_X64)
	{
		version(DigitalMars)
		{
			static assert(0, "TODO");
		}
		else version(GNU)
		{
			static if(is(T == int4))
				return __builtin_ia32_cvtdq2ps(v);
			else static if(is(T == double2))
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

double2 toDouble(SIMDVer Ver = sseVer, T)(T v)
{
	version(X86_OR_X64)
	{
		version(DigitalMars)
		{
			static assert(0, "TODO");
		}
		else version(GNU)
		{
			static if(is(T == int4))
				return __builtin_ia32_cvtdq2pd(v);
			else static if(is(T == float4))
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

///////////////////////////////////////////////////////////////////////////////
// Basic mathematical operations

// unary absolute
T abs(SIMDVer Ver = sseVer, T)(T v)
{
	static assert(!isUnsigned!(T), "Can not take absolute of unsigned value");

	/******************************
	* integer abs with no branches
	*   mask = v >> numBits(v)-1;
	*   r = (v + mask) ^ mask;
	******************************/

	version(X86_OR_X64)
	{
		version(DigitalMars)
		{
			static assert(0, "TODO");
		}
		else version(GNU)
		{
			static if(is(T == double2))
				return __builtin_ia32_andnpd(cast(double2)signMask2, v);
			else static if(is(T == float4))
				return __builtin_ia32_andnps(cast(float4)signMask4, v);
			else static if(Ver >= SIMDVer.SSSE3)
			{
				static if(is64bitElement!(T))
					static assert(0, "Unsupported: abs(" ~ T.stringof ~ "). Should we emulate?");
				else static if(is32bitElement!(T))
					return __builtin_ia32_pabsd128(v);
				else static if(is16bitElement!(T))
					return __builtin_ia32_pabsw128(v);
				else static if(is8bitElement!(T))
					return __builtin_ia32_pabsb128(v);
			}
			else static if(is(T == int4))
			{
				int4 t = shiftRightImmediate!Ver(v, 31);
				return sub!Ver(xor!Ver(v, t), t);
			}
			else static if(is(T == short8))
			{
				return max!Ver(v, sub!Ver(0, v));
			}
			else static if(is(T == byte16))
			{
				byte16 t = maskGreater!Ver(0, v);
				return sub!Ver(xor!Ver(v, t), t);
			}
			else
				static assert(0, "Unsupported vector type: " ~ T.stringof);
		}
	}
	else version(ARM)
	{
		static if(is(T == float4))
			return __builtin_neon_vabsv4sf(v, ARMOpType!T);
		else static if(is(T == int4))
			return __builtin_neon_vabsv4si(v, ARMOpType!T);
		else static if(is(T == short8))
			return __builtin_neon_vabsv8hi(v, ARMOpType!T);
		else static if(is(T == byte16))
			return __builtin_neon_vabsv16qi(v, ARMOpType!T);
		else
			static assert(0, "Unsupported vector type: " ~ T.stringof);
	}
	else
	{
		static assert(0, "Unsupported on this architecture");
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
		static if(is(T == float4))
			return __builtin_neon_vnegv4sf(v, ARMOpType!T);
		else static if(is(T == int4))
			return __builtin_neon_vnegv4si(v, ARMOpType!T);
		else static if(is(T == short8))
			return __builtin_neon_vnegv8hi(v, ARMOpType!T);
		else static if(is(T == byte16))
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
		static if(is(T == float4))
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
			static assert(0, "TODO");
		}
		else version(GNU)
		{
			static if(is(T == short8))
				return __builtin_ia32_paddsw(v1, v2);
			else static if(is(T == ushort8))
				return __builtin_ia32_paddusw(v1, v2);
			else static if(is(T == byte16))
				return __builtin_ia32_paddsb(v1, v2);
			else static if(is(T == ubyte16))
				return __builtin_ia32_paddusb(v1, v2);
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
		static if(is(T == float4))
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
			static assert(0, "TODO");
		}
		else version(GNU)
		{
			static if(is(T == short8))
				return __builtin_ia32_psubsw(v1, v2);
			else static if(is(T == ushort8))
				return __builtin_ia32_psubusw(v1, v2);
			else static if(is(T == byte16))
				return __builtin_ia32_psubsb(v1, v2);
			else static if(is(T == ubyte16))
				return __builtin_ia32_psubusb(v1, v2);
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
		static if(is(T == float4))
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
			return v1*v2 + v3;
		}
		else version(GNU)
		{
			static if(is(T == double2) && Ver == SIMDVer.SSE5)
				return __builtin_ia32_fmaddpd(v1, v2, v3);
			else static if(is(T == float4) && Ver == SIMDVer.SSE5)
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
			static if(is(T == float4))
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
		else version(GNU)
		{
			static if(is(T == double2) && Ver == SIMDVer.SSE5)
				return __builtin_ia32_fmsubpd(v1, v2, v3);
			else static if(is(T == float4) && Ver == SIMDVer.SSE5)
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
		else version(GNU)
		{
			static if(is(T == double2) && Ver == SIMDVer.SSE5)
				return __builtin_ia32_fnmaddpd(v1, v2, v3);
			else static if(is(T == float4) && Ver == SIMDVer.SSE5)
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

			static if(is(T == float4))
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
		else version(GNU)
		{
			static if(is(T == double2) && Ver == SIMDVer.SSE5)
				return __builtin_ia32_fnmsubpd(v1, v2, v3);
			else static if(is(T == float4) && Ver == SIMDVer.SSE5)
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
			static assert(0, "TODO");
		}
		else version(GNU)
		{
			static if(is(T == double2))
				return __builtin_ia32_minpd(v1, v2);
			else static if(is(T == float4))
				return __builtin_ia32_minps(v1, v2);
			else static if(is(T == int4))
			{
				static if(Ver >= SIMDVer.SSE41)
					return __builtin_ia32_pminsd128(v1, v2);
				else
					return selectGreater!Ver(v1, v2, v2, v1);
			}
			else static if(is(T == uint4))
			{
				static if(Ver >= SIMDVer.SSE41)
					return __builtin_ia32_pminud128(v1, v2);
				else
					return selectGreater!Ver(v1, v2, v2, v1);
			}
			else static if(is(T == short8))
				return __builtin_ia32_pminsw128(v1, v2); // available in SSE2
			else static if(is(T == ushort8))
			{
				static if(Ver >= SIMDVer.SSE41)
					return __builtin_ia32_pminuw128(v1, v2);
				else
					return selectGreater!Ver(v1, v2, v2, v1);
			}
			else static if(is(T == byte16))
			{
				static if(Ver >= SIMDVer.SSE41)
					return __builtin_ia32_pminsb128(v1, v2);
				else
					return selectGreater!Ver(v1, v2, v2, v1);
			}
			else static if(is(T == ubyte16))
				return __builtin_ia32_pminub128(v1, v2); // available in SSE2
			else
				static assert(0, "Unsupported vector type: " ~ T.stringof);
		}
	}
	else version(ARM)
	{
		static if(is(T == float4))
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
			static assert(0, "TODO");
		}
		else version(GNU)
		{
			static if(is(T == double2))
				return __builtin_ia32_maxpd(v1, v2);
			else static if(is(T == float4))
				return __builtin_ia32_maxps(v1, v2);
			else static if(is(T == int4))
			{
				static if(Ver >= SIMDVer.SSE41)
					return __builtin_ia32_pmaxsd128(v1, v2);
				else
					return selectGreater!Ver(v1, v2, v1, v2);
			}
			else static if(is(T == uint4))
			{
				static if(Ver >= SIMDVer.SSE41)
					return __builtin_ia32_pmaxud128(v1, v2);
				else
					return selectGreater!Ver(v1, v2, v1, v2);
			}
			else static if(is(T == short8))
				return __builtin_ia32_pmaxsw128(v1, v2); // available in SSE2
			else static if(is(T == ushort8))
			{
				static if(Ver >= SIMDVer.SSE41)
					return __builtin_ia32_pmaxuw128(v1, v2);
				else
					return selectGreater!Ver(v1, v2, v1, v2);
			}
			else static if(is(T == byte16))
			{
				static if(Ver >= SIMDVer.SSE41)
					return __builtin_ia32_pmaxsb128(v1, v2);
				else
					return selectGreater!Ver(v1, v2, v1, v2);
			}
			else static if(is(T == ubyte16))
				return __builtin_ia32_pmaxub128(v1, v2); // available in SSE2
			else
				static assert(0, "Unsupported vector type: " ~ T.stringof);
		}
	}
	else version(ARM)
	{
		static if(is(T == float4))
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
			static assert(0, "TODO");
		}
		else version(GNU)
		{
			static if(is(T == double2))
			{
				static if(Ver >= SIMDVer.SSE41)
					return __builtin_ia32_roundpd(v, 1);
				else
					static assert(0, "Only supported in SSE4.1 and above");
			}
			else static if(is(T == float4))
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
			static assert(0, "TODO");
		}
		else version(GNU)
		{
			static if(is(T == double2))
			{
				static if(Ver >= SIMDVer.SSE41)
					return __builtin_ia32_roundpd(v, 2);
				else
					static assert(0, "Only supported in SSE4.1 and above");
			}
			else static if(is(T == float4))
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
			static assert(0, "TODO");
		}
		else version(GNU)
		{
			static if(is(T == double2))
			{
				static if(Ver >= SIMDVer.SSE41)
					return __builtin_ia32_roundpd(v, 0);
				else
					static assert(0, "Only supported in SSE4.1 and above");
			}
			else static if(is(T == float4))
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
			static assert(0, "TODO");
		}
		else version(GNU)
		{
			static if(is(T == double2))
			{
				static if(Ver >= SIMDVer.SSE41)
					return __builtin_ia32_roundpd(v, 3);
				else
					static assert(0, "Only supported in SSE4.1 and above");
			}
			else static if(is(T == float4))
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
	version(ARM)
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
			static assert(0, "TODO");
		}
		else version(GNU)
		{
			static if(is(T == double2))
				return div!Ver(1.0, v);
			else static if(is(T == float4))
				return __builtin_ia32_rcpps(v);
			else
				static assert(0, "Unsupported vector type: " ~ T.stringof);
		}
	}
	else version(ARM)
	{
		static assert(0, "TODO!");
		static if(is(T == float4))
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
			static assert(0, "TODO");
		}
		else version(GNU)
		{
			static if(is(T == double2))
				return __builtin_ia32_sqrtpd(v);
			else static if(is(T == float4))
				return __builtin_ia32_sqrtps(v);
			else
				static assert(0, "Unsupported vector type: " ~ T.stringof);
		}
	}
	else version(ARM)
	{
		static assert(0, "TODO!");
		static if(is(T == float4))
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
			static assert(0, "TODO");
		}
		else version(GNU)
		{
			static if(is(T == double2))
				return rcp!Ver(sqrt!Ver(v));
			else static if(is(T == float4))
				return __builtin_ia32_rsqrtps(v);
			else
				static assert(0, "Unsupported vector type: " ~ T.stringof);
		}
	}
	else version(ARM)
	{
		static assert(0, "TODO!");
		static if(is(T == float4))
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
			static assert(0, "TODO");
		}
		else version(GNU)
		{
			static if(is(T == double2))
			{
				static if(Ver >= SIMDVer.SSE41) // 1 op
					return __builtin_ia32_dppd(v1, v2, 0x0F);
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
			else static if(is(T == float4))
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
			static assert(0, "TODO");
		}
		else version(GNU)
		{
			static if(is(T == float4))
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
			static assert(0, "TODO");
		}
		else version(GNU)
		{
			static if(is(T == float4))
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
		static if(is(T == float4))
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
		static if(is(T == float4))
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

// unary compliment: ~v
T comp(SIMDVer Ver = sseVer, T)(T v)
{
	version(X86_OR_X64)
	{
		return ~v;
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
			static assert(0, "TODO");
		}
		else version(GNU)
		{
			static if(is(T == double2))
				return __builtin_ia32_orpd(v1, v2);
			else static if(is(T == float4))
				return __builtin_ia32_orps(v1, v2);
			else
				return __builtin_ia32_por128(v1, v2);
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
			static assert(0, "TODO");
		}
		else version(GNU)
		{
			static if(is(T == double2))
				return __builtin_ia32_andpd(v1, v2);
			else static if(is(T == float4))
				return __builtin_ia32_andps(v1, v2);
			else
				return __builtin_ia32_pand128(v1, v2);
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
			static assert(0, "TODO");
		}
		else version(GNU)
		{
			static if(is(T == double2))
				return __builtin_ia32_andnpd(v2, v1);
			else static if(is(T == float4))
				return __builtin_ia32_andnps(v2, v1);
			else
				return __builtin_ia32_pandn128(v2, v1);
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
			static assert(0, "TODO");
		}
		else version(GNU)
		{
			static if(is(T == double2))
				return __builtin_ia32_xorpd(v1, v2);
			else static if(is(T == float4))
				return __builtin_ia32_xorps(v1, v2);
			else
				return __builtin_ia32_pxor128(v1, v2);
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
			static assert(0, "TODO");
		}
		else version(GNU)
		{
			static if(is(T == long2) || is(T == ulong2))
				return __builtin_ia32_psllq128(v1, v2);
			else static if(is(T == int4) || is(T == uint4))
				return __builtin_ia32_psrld128(v1, v2);
			else static if(is(T == short8) || is(T == ushort8))
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
				static assert(0, "TODO");
			}
			else version(GNU)
			{
				static if(is(T == long2) || is(T == ulong2))
					return __builtin_ia32_psllqi128(v, bits);
				else static if(is(T == int4) || is(T == uint4))
					return __builtin_ia32_psrldi128(v, bits);
				else static if(is(T == short8) || is(T == ushort8))
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

// binary shift right (signed types perform arithmatic shift right)
T shiftRight(SIMDVer Ver = sseVer, T)(T v1, T v2)
{
	version(X86_OR_X64)
	{
		version(DigitalMars)
		{
			static assert(0, "TODO");
		}
		else version(GNU)
		{
			static if(is(T == ulong2))
				return __builtin_ia32_psrlq128(v1, v2);
			else static if(is(T == int4))
				return __builtin_ia32_psrad128(v1, v2);
			else static if(is(T == uint4))
				return __builtin_ia32_psrld128(v1, v2);
			else static if(is(T == short8))
				return __builtin_ia32_psraw128(v1, v2);
			else static if(is(T == ushort8))
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
				static assert(0, "TODO");
			}
			else version(GNU)
			{
				static if(is(T == ulong2))
					return __builtin_ia32_psrlqi128(v, bits);
				else static if(is(T == int4))
					return __builtin_ia32_psradi128(v, bits);
				else static if(is(T == uint4))
					return __builtin_ia32_psrldi128(v, bits);
				else static if(is(T == short8))
					return __builtin_ia32_psrawi128(v, bits);
				else static if(is(T == ushort8))
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
				static assert(0, "TODO");
			}
			else version(GNU)
			{
				// little endian reads the bytes into the register in reverse, so we need to flip the operations
				return __builtin_ia32_psrldqi128(v, bytes * 8); // TODO: *8? WAT?
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
				static assert(0, "TODO");
			}
			else version(GNU)
			{
				// little endian reads the bytes into the register in reverse, so we need to flip the operations
				return __builtin_ia32_pslldqi128(v, bytes * 8); // TODO: *8? WAT?
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
	enum size_t e = n & (NumElements!T - 1); // large rotations should wrap

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
			static assert(0, "TODO");
		}
		else version(GNU)
		{
			static if(is(T == double2))
				return __builtin_ia32_cmpeqpd(a, b);
			else static if(is(T == float4))
				return __builtin_ia32_cmpeqps(a, b);
			else static if(is(T == long2) || is(T == ulong2))
			{
				static if(Ver >= SIMDVer.SSE41)
					return __builtin_ia32_pcmpeqq(a, b);
				else
					static assert(0, "Only supported in SSE4.1 and above");
			}
			else static if(is(T == int4) || is(T == uint4))
				return __builtin_ia32_pcmpeqd128(a, b);
			else static if(is(T == short8) || is(T == ushort8))
				return __builtin_ia32_pcmpeqw128(a, b);
			else static if(is(T == byte16) || is(T == ubyte16))
				return __builtin_ia32_pcmpeqb128(a, b);
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

// generate a bitmask of for elements: Rn = An != Bn ? -1 : 0 (SLOW)
void16 maskNotEqual(SIMDVer Ver = sseVer, T)(T a, T b)
{
	version(X86_OR_X64)
	{
		version(DigitalMars)
		{
			static assert(0, "TODO");
		}
		else version(GNU)
		{
			static if(is(T == double2))
				return __builtin_ia32_cmpneqpd(a, b);
			else static if(is(T == float4))
				return __builtin_ia32_cmpneqps(a, b);
			else
				return comp!Ver(cast(void16)maskEqual!Ver(a, b));
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

// generate a bitmask of for elements: Rn = An > Bn ? -1 : 0
void16 maskGreater(SIMDVer Ver = sseVer, T)(T a, T b)
{
	version(X86_OR_X64)
	{
		version(DigitalMars)
		{
			static assert(0, "TODO");
		}
		else version(GNU)
		{
			static if(is(T == double2))
				return __builtin_ia32_cmpgtpd(a, b);
			else static if(is(T == float4))
				return __builtin_ia32_cmpgtps(a, b);
			else static if(is(T == long2))
			{
				static if(Ver >= SIMDVer.SSE42)
					return __builtin_ia32_pcmpgtq(a, b);
				else
					static assert(0, "Only supported in SSE4.2 and above");
			}
			else static if(is(T == ulong2))
			{
				static if(Ver >= SIMDVer.SSE42)
					return __builtin_ia32_pcmpgtq(a + signMask2, b + signMask2);
				else
					static assert(0, "Only supported in SSE4.2 and above");
			}
			else static if(is(T == int4))
				return __builtin_ia32_pcmpgtd128(a, b);
			else static if(is(T == uint4))
				return __builtin_ia32_pcmpgtd128(a + signMask4, b + signMask4);
			else static if(is(T == short8))
				return __builtin_ia32_pcmpgtw128(a, b);
			else static if(is(T == ushort8))
				return __builtin_ia32_pcmpgtw128(a + signMask8, b + signMask8);
			else static if(is(T == byte16))
				return __builtin_ia32_pcmpgtb128(a, b);
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

// generate a bitmask of for elements: Rn = An >= Bn ? -1 : 0 (SLOW)
void16 maskGreaterEqual(SIMDVer Ver = sseVer, T)(T a, T b)
{
	version(X86_OR_X64)
	{
		version(DigitalMars)
		{
			static assert(0, "TODO");
		}
		else version(GNU)
		{
			static if(is(T == double2))
				return __builtin_ia32_cmpgepd(a, b);
			else static if(is(T == float4))
				return __builtin_ia32_cmpgeps(a, b);
			else
				return or!Ver(cast(void16)maskGreater!Ver(a, b), cast(void16)maskEqual!Ver(a, b)); // compound greater OR equal
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

// generate a bitmask of for elements: Rn = An < Bn ? -1 : 0 (SLOW)
void16 maskLess(SIMDVer Ver = sseVer, T)(T a, T b)
{
	version(X86_OR_X64)
	{
		version(DigitalMars)
		{
			static assert(0, "TODO");
		}
		else version(GNU)
		{
			static if(is(T == double2))
				return __builtin_ia32_cmpltpd(a, b);
			else static if(is(T == float4))
				return __builtin_ia32_cmpltps(a, b);
			else
				return maskGreaterEqual!Ver(b, a); // reverse the args
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

// generate a bitmask of for elements: Rn = An <= Bn ? -1 : 0
void16 maskLessEqual(SIMDVer Ver = sseVer, T)(T a, T b)
{
	version(X86_OR_X64)
	{
		version(DigitalMars)
		{
			static assert(0, "TODO");
		}
		else version(GNU)
		{
			static if(is(T == double2))
				return __builtin_ia32_cmplepd(a, b);
			else static if(is(T == float4))
				return __builtin_ia32_cmpleps(a, b);
			else
				return maskGreaterEqual!Ver(b, a); // reverse the args
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
// Branchless selection

// select elements according to: mask == true ? x : y
T select(SIMDVer Ver = sseVer, T)(void16 mask, T x, T y)
{
	version(X86_OR_X64)
	{
		version(DigitalMars)
		{
			static assert(0, "TODO");
		}
		else version(GNU)
		{
			static if(Ver >= SIMDVer.SSE41)
			{
				static if(is(T == double2))
					return __builtin_ia32_blendvpd(y, x, cast(double2)mask);
				else static if(is(T == float4))
					return __builtin_ia32_blendvps(y, x, cast(float4)mask);
				else
					return cast(T)__builtin_ia32_pblendvb128(cast(ubyte16)y, cast(ubyte16)x, cast(ubyte16)mask);
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
			static if(is(T == float4x4))
			{
				float4 b0 = __builtin_ia32_shufps(m.xRow, m.yRow, shufMask!4([0,1,0,1]));
				float4 b1 = __builtin_ia32_shufps(m.zRow, m.wRow, shufMask!4([0,1,0,1]));
				float4 b2 = __builtin_ia32_shufps(m.xRow, m.yRow, shufMask!4([2,3,2,3]));
				float4 b3 = __builtin_ia32_shufps(m.zRow, m.wRow, shufMask!4([2,3,2,3]));
				float4 a0 = __builtin_ia32_shufps(b0, b1, shufMask!4([0,2,0,2]));
				float4 a1 = __builtin_ia32_shufps(b2, b3, shufMask!4([0,2,0,2]));
				float4 a2 = __builtin_ia32_shufps(b0, b1, shufMask!4([1,3,1,3]));
				float4 a3 = __builtin_ia32_shufps(b2, b3, shufMask!4([1,3,1,3]));

				return float4x4(a0, a2, a1, a3);
			}
			else static if (is(T == double2x2))
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
