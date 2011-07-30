// Written in the D programming language.

/**
 * Identify the compiler used and its various features.
 *
 * Macros:
 *      WIKI = Phobos/StdCompiler
 *
 * Copyright: Copyright Digital Mars 2000 - 2011.
 * License:   <a href="http://www.boost.org/LICENSE_1_0.txt">Boost License 1.0</a>.
 * Authors:   $(WEB digitalmars.com, Walter Bright)
 * Source:    $(PHOBOSSRC std/_compiler.d)
 */
/*          Copyright Digital Mars 2000 - 2011.
 * Distributed under the Boost Software License, Version 1.0.
 *    (See accompanying file LICENSE_1_0.txt or copy at
 *          http://www.boost.org/LICENSE_1_0.txt)
 */
module std.compiler;

const
{
    /// Vendor specific string naming the compiler, for example: "Digital Mars D".
    string name = __VENDOR__;

    /// Master list of D compiler vendors.
    enum Vendor
    {
        Unknown = 0,            /// Compiler vendor could not be detected
        DigitalMars = 1,        /// Digital Mars D (DMD)
        GNU = 2,                /// GNU D Compiler (GDC)
        LLVM = 3,               /// LLVM D Compiler (LDC)
    }

    /// Which vendor produced this compiler.
    version (DigitalMars)
    {
        Vendor vendor = Vendor.DigitalMars;
    }
    else version (GNU)
    {
        Vendor vendor = Vendor.GNU;
    }
    else version (LDC)
    {
        Vendor vendor = Vendor.LLVM;
    }
    else
    {
        Vendor vendor = Vendor.Unknown;
    }


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
