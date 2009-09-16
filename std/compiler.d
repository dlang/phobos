// Written in the D programming language.

/**
 * Identify the compiler used and its various features.
 *
 * Macros:
 *      WIKI = Phobos/StdCompiler
 *
 * Copyright: Copyright Digital Mars 2000 - 2009.
 * License:   <a href="http://www.boost.org/LICENSE_1_0.txt">Boost License 1.0</a>.
 * Authors:   $(WEB digitalmars.com, Walter Bright)
 *
 *          Copyright Digital Mars 2000 - 2009.
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
        DigitalMars = 1,        /// Digital Mars
    }

    /// Which vendor produced this compiler.
    Vendor vendor = Vendor.DigitalMars;


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
