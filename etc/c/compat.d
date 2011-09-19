/// This module provides compatibility with C language by defining symbols, related to it, including aliass for built-in types, depending on the compiler and processor.
/// If you don't find your compiler and/or processor in this module, please contact me (gor@boloneum.com)
/// BUGS: The documentation does not take into account conditional compilation as of DMD 2.055.
module etc.c.compat;

public:
	/// The list of known compilers.
	enum Compiler
	{
		/// Undefined compiler.
		UNDEFINED,
		
		/// Digital Mars C++.
		DMC,
		
		/// GNU C compiler.
		GCC,
		
		/// Microsoft Visual C++.
		MSVC,
		
		/// Low-Level Virtual Machine's CLang.
		CLANG
	};

	/// The list of known processors.
	enum Processor
	{
		/// Undefined Processor.
		UNDEFINED,
		
		/// Intel or AMD x86 processor.
		X86,
		
		/// Intel or AMD x86_64 processor.
		X86_64,
	}
	
	/// The list of C types, depending on the given compiler and processor.
	/// Mix this in your module with the respective compiler and processor information to get the C types with correct sizes for that pair of compiler and processor.
	template Type(Compiler comp = compiler, Processor proc = processor)
	{
		/// Type: char.
		/// Size: 8 bits.
		alias c_schar c_char;
		
		/// Type: unsigned char.
		/// Size: 8 bits.
		alias char c_uchar;
		
		/// Type: signed char.
		/// Size: 8 bits.
		alias byte c_schar;
		
		/// Type: short, short int, signed short, signed short int.
		/// Size: 16 bits.
		alias short c_short;
		
		/// Type: unsigned short, unsigned short int.
		/// Size: 16 bits.
		alias ushort c_ushort;
		
		/// Type: int, signed.
		/// Size: 32 bits.
		alias int c_int;
		
		/// Type: unsigned int, unsigned.
		/// Size: 32 bits.
		alias uint c_uint;
		
		static if(comp == Compiler.GCC && proc == Processor.X86_64)
		{
			/// Type: long, long int, signed long, signed long int.
			/// Size: 64 bits.
			alias long c_long;
			
			/// Type: unsigned long, unsigned long int.
			/// Size: 64 bits.
			alias ulong c_ulong;
		}
		else
		{
			/// Type: long, long int, signed long, signed long int.
			/// Size: 32 bits.
			alias int c_long;
			
			/// Type: unsigned long, unsigned long int.
			/// Size: 32 bits.
			alias uint c_ulong;
		}
		
		static if(comp == Compiler.MSVC)
		{
			/// Type: __int8, signed __int8.
			/// Size: 8 bits.
			alias byte c_int8;
			
			/// Type: unsigned __int8.
			/// Size: 8 bits.
			alias ubyte c_uint8;

			/// Type: __int16, signed __int16.
			/// Size: 16 bits.
			alias short c_int16;
			
			/// Type: unsigned __int16.
			/// Size: 16 bits.
			alias ushort c_uint16;

			/// Type: __int32, signed __int32.
			/// Size: 32 bits.
			alias int c_int32;
			
			/// Type: unsigned __int32.
			/// Size: 32 bits.
			alias uint c_uint32;

			/// Type: __int64, signed __int64.
			/// Size: 64 bits.
			alias long c_int64;
			
			/// Type: unsigned __int64.
			/// Size: 64 bits.
			alias ulong c_uint64;
		}
	}
