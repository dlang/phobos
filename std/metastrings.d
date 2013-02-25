// Written in the D programming language.

/**
$(RED Deprecated. It will be removed in March 2014.
      Please use $(XREF string, format), $(XREF conv, to), or
      $(XREF conv, parse) instead of these templates (which one would depend on
      which template is being replaced.) They now work in CTFE, and these
      templates are very inefficient.)

Templates with which to do compile-time manipulation of strings.

Macros:
 WIKI = Phobos/StdMetastrings

Copyright: Copyright Digital Mars 2007 - 2013.
License:   <a href="http://www.boost.org/LICENSE_1_0.txt">Boost License 1.0</a>.
Authors:   $(WEB digitalmars.com, Walter Bright),
           Don Clugston
Source:    $(PHOBOSSRC std/_metastrings.d)
*/
module std.metastrings;

/**
$(RED Deprecated.
     Please use $(XREF string, format) instead. It now works in CTFE,
     and this template is very inefficient.)

Formats constants into a string at compile time.  Analogous to $(XREF
string,format).

Parameters:

A = tuple of constants, which can be strings, characters, or integral
    values.

Formats:
 *    The formats supported are %s for strings, and %%
 *    for the % character.
Example:
---
import std.metastrings;
import std.stdio;

void main()
{
  string s = Format!("Arg %s = %s", "foo", 27);
  writefln(s); // "Arg foo = 27"
}
 * ---
 */

deprecated("std.string.format now works in CTFE. Please use it instead.")
template Format(A...)
{
    static if (A.length == 0)
        enum Format = "";
    else static if (is(typeof(A[0]) : const(char)[]))
        enum Format = FormatString!(A[0], A[1..$]);
    else
        enum Format = toStringNow!(A[0]) ~ Format!(A[1..$]);
}

deprecated("std.string.format now works in CTFE. Please use it instead.")
template FormatString(const(char)[] F, A...)
{
    static if (F.length == 0)
        enum FormatString = Format!(A);
    else static if (F.length == 1)
        enum FormatString = F[0] ~ Format!(A);
    else static if (F[0..2] == "%s")
        enum FormatString
            = toStringNow!(A[0]) ~ FormatString!(F[2..$],A[1..$]);
    else static if (F[0..2] == "%%")
        enum FormatString = "%" ~ FormatString!(F[2..$],A);
    else
    {
        static assert(F[0] != '%', "unrecognized format %" ~ F[1]);
        enum FormatString = F[0] ~ FormatString!(F[1..$],A);
    }
}

unittest
{
    auto s = Format!("hel%slo", "world", -138, 'c', true);
    assert(s == "helworldlo-138ctrue", "[" ~ s ~ "]");
}

/**
 * $(RED Deprecated.
 *       Please use $(XREF conv, format) instead. It now works in CTFE,
 *       and this template is very inefficient.)
 *
 * Convert constant argument to a string.
 */

deprecated("std.conv.to now works in CTFE. Please use it instead.")
template toStringNow(ulong v)
{
    static if (v < 10)
        enum toStringNow = "" ~ cast(char)(v + '0');
    else
        enum toStringNow = toStringNow!(v / 10) ~ toStringNow!(v % 10);
}

unittest
{
    static assert(toStringNow!(1uL << 62) == "4611686018427387904");
}

/// ditto
deprecated("std.conv.to!string now works in CTFE. Please use it instead.")
template toStringNow(long v)
{
    static if (v < 0)
        enum toStringNow = "-" ~ toStringNow!(cast(ulong) -v);
    else
        enum toStringNow = toStringNow!(cast(ulong) v);
}

unittest
{
    static assert(toStringNow!(0x100000000) == "4294967296");
    static assert(toStringNow!(-138L) == "-138");
}

/// ditto
deprecated("std.conv.to!string now works in CTFE. Please use it instead.")
template toStringNow(uint U)
{
    enum toStringNow = toStringNow!(cast(ulong)U);
}

/// ditto
deprecated("std.conv.to!string now works in CTFE. Please use it instead.")
template toStringNow(int I)
{
    enum toStringNow = toStringNow!(cast(long)I);
}

/// ditto
deprecated("std.conv.to!string now works in CTFE. Please use it instead.")
template toStringNow(bool B)
{
    enum toStringNow = B ? "true" : "false";
}

/// ditto
deprecated("std.conv.to!string now works in CTFE. Please use it instead.")
template toStringNow(string S)
{
    enum toStringNow = S;
}

/// ditto
deprecated("std.conv.to!string now works in CTFE. Please use it instead.")
template toStringNow(char C)
{
    enum toStringNow = "" ~ C;
}


/********
 * $(RED Deprecated.
 *       Please use $(XREF conv, parse) instead. It now works in CTFE,
 *       and this template is very inefficient.)
 *
 * Parse unsigned integer literal from the start of string s.
 * returns:
 *    .value = the integer literal as a string,
 *    .rest = the string following the integer literal
 * Otherwise:
 *    .value = null,
 *    .rest = s
 */

deprecated("to!string(std.conv.parse!uint(value)) now works in CTFE. Please use it instead.")
template parseUinteger(const(char)[] s)
{
    static if (s.length == 0)
    {
        enum value = "";
        enum rest = "";
    }
    else static if (s[0] >= '0' && s[0] <= '9')
    {
        enum value = s[0] ~ parseUinteger!(s[1..$]).value;
        enum rest = parseUinteger!(s[1..$]).rest;
    }
    else
    {
        enum value = "";
        enum rest = s;
    }
}

/********
$(RED Deprecated.
      Please use $(XREF conv, parse) instead. It now works in CTFE,
      and this template is very inefficient.)

Parse integer literal optionally preceded by $(D '-') from the start
of string $(D s).

Returns:
   .value = the integer literal as a string,
   .rest = the string following the integer literal

Otherwise:
   .value = null,
   .rest = s
*/

deprecated("to!string(std.conv.parse!int(value)) now works in CTFE. Please use it instead.")
template parseInteger(const(char)[] s)
{
    static if (s.length == 0)
    {
        enum value = "";
        enum rest = "";
    }
    else static if (s[0] >= '0' && s[0] <= '9')
    {
        enum value = s[0] ~ parseUinteger!(s[1..$]).value;
        enum rest = parseUinteger!(s[1..$]).rest;
    }
    else static if (s.length >= 2 &&
            s[0] == '-' && s[1] >= '0' && s[1] <= '9')
    {
        enum value = s[0..2] ~ parseUinteger!(s[2..$]).value;
        enum rest = parseUinteger!(s[2..$]).rest;
    }
    else
    {
        enum value = "";
        enum rest = s;
    }
}

unittest
{
    assert(parseUinteger!("1234abc").value == "1234");
    assert(parseUinteger!("1234abc").rest == "abc");
    assert(parseInteger!("-1234abc").value == "-1234");
    assert(parseInteger!("-1234abc").rest == "abc");
}
