// Written in the D programming language.

/**
 * Identify the compiler used and its various features.
 *
 * Copyright: Copyright The D Language Foundation 2000 - 2011.
 * License:   $(HTTP www.boost.org/LICENSE_1_0.txt, Boost License 1.0).
 * Authors:   $(HTTP digitalmars.com, Walter Bright), Alex Rønne Petersen
 * Source:    $(PHOBOSSRC std/compiler.d)
 */
/*          Copyright The D Language Foundation 2000 - 2011.
 * Distributed under the Boost Software License, Version 1.0.
 *    (See accompanying file LICENSE_1_0.txt or copy at
 *          http://www.boost.org/LICENSE_1_0.txt)
 */
module std.compiler;

immutable
{
    /// Vendor specific string naming the compiler, for example: "Digital Mars D".
    string name = __VENDOR__;

    /// Master list of D compiler vendors.
    enum Vendor
    {
        unknown = 0,     /// Compiler vendor could not be detected
        digitalMars = 1, /// Digital Mars D (DMD)
        gnu = 2,         /// GNU D Compiler (GDC)
        llvm = 3,        /// LLVM D Compiler (LDC)
        dotNET = 4,      /// D.NET
        sdc = 5,         /// Snazzy D Compiler (SDC)
    }

    /// Which vendor produced this compiler.
    version (StdDdoc)          Vendor vendor;
    else version (DigitalMars) Vendor vendor = Vendor.digitalMars;
    else version (GNU)         Vendor vendor = Vendor.gnu;
    else version (LDC)         Vendor vendor = Vendor.llvm;
    else version (D_NET)       Vendor vendor = Vendor.dotNET;
    else version (SDC)         Vendor vendor = Vendor.sdc;
    else                      Vendor vendor = Vendor.unknown;


    /**
     * The vendor specific version number, as in
     * version_major.version_minor
     */
    uint version_major = __VERSION__ / 1000;
    uint version_minor = __VERSION__ % 1000;    /// ditto


    /**
     * The version of the D Programming Language Specification
     * supported by the compiler.
     */
    uint D_major = 2;
    uint D_minor = 0;
}

/**
 * Allows version conditions to be available as boolean values at compile
 * time, allowing for more complex combinations of versions to be expressed
 * more simply. Any valid version(x) will have an equivalent Version.x
 * evaluating to either true or false depending on whether version(x) was
 * defined.
 */
struct Version
{
    static bool opDispatch(string identifier)()
    {
        mixin("
            version(", identifier, ")
            {
                return true;
            }
            else
            {
                return false;
            }
        ");
    }
}

///
@system unittest
{
    static if (Version.D_InlineAsm_X86 || Version.D_InlineAsm_X86_64)
    {
        asm {
            // x86 assembly goes here
        }
    }
    else
    {
        // a fallback implementation
    }
}

@safe pure unittest
{
    static assert(Version.all);
    static assert(!Version.none);
}
