// Written in the D programming language.

/++
    The purpose of this module is to perform static construction away from the
    normal modules to eliminate cyclic construction errors.

    Copyright: Copyright 2011 - 2016
    License:   $(HTTP www.boost.org/LICENSE_1_0.txt, Boost License 1.0).
    Authors:   Jonathan M Davis, Kato Shoichi, Steven Schveighoffer
    Source:    $(PHOBOSSRC std/internal/_phobosinit.d)
  +/
module std.internal.phobosinit;

shared static this()
{
    import std.encoding : EncodingScheme;
    EncodingScheme.register("std.encoding.EncodingSchemeASCII");
    EncodingScheme.register("std.encoding.EncodingSchemeLatin1");
    EncodingScheme.register("std.encoding.EncodingSchemeLatin2");
    EncodingScheme.register("std.encoding.EncodingSchemeWindows1250");
    EncodingScheme.register("std.encoding.EncodingSchemeWindows1252");
    EncodingScheme.register("std.encoding.EncodingSchemeUtf8");
    EncodingScheme.register("std.encoding.EncodingSchemeUtf16Native");
    EncodingScheme.register("std.encoding.EncodingSchemeUtf32Native");
}
