
/**
 * Macros:
 *	WIKI = Phobos/StdCompiler
 */

/**
 * Identify the compiler used and its various features.
 * Authors: Walter Bright, www.digitalmars.com
 * License: Public Domain
 */


module std.compiler;

const
{
    /// Vendor specific string naming the compiler, for example: "Digital Mars D".
    char[] name = "Digital Mars D";

    /// Master list of D compiler vendors.
    enum Vendor
    {
	DigitalMars = 1,	/// Digital Mars
    }

    /// Which vendor produced this compiler.
    Vendor vendor = Vendor.DigitalMars;


    /**
     * The vendor specific version number, as in
     * version_major.version_minor
     */
    uint version_major = 0;
    uint version_minor = 176;	/// ditto


    /**
     * The version of the D Programming Language Specification
     * supported by the compiler.
     */
    uint D_major = 1;
    uint D_minor = 0;
}
