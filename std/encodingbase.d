// Written in the D programming language.

/++
    The only purpose of this module is to do the static construction for
    std.encoding, to eliminate cyclic construction errors.

    Copyright: Copyright Digital Mars 2011 -
    License:   $(WEB www.boost.org/LICENSE_1_0.txt, Boost License 1.0).
    Authors:   Jonathan M Davis
    Source:    $(PHOBOSSRC std/_encodingbase.d)
  +/
module std.encodingbase;

extern(C) void std_encoding_EncodingSchemeASCII_static_this();
extern(C) void std_encoding_EncodingSchemeLatin1_static_this();
extern(C) void std_encoding_EncodingSchemeWindows1252_static_this();
extern(C) void std_encoding_EncodingSchemeUtf8_static_this();
extern(C) void std_encoding_EncodingSchemeUtf16Native_static_this();
extern(C) void std_encoding_EncodingSchemeUtf32Native_static_this();

shared static this()
{
    std_encoding_EncodingSchemeASCII_static_this();
    std_encoding_EncodingSchemeLatin1_static_this();
    std_encoding_EncodingSchemeWindows1252_static_this();
    std_encoding_EncodingSchemeUtf8_static_this();
    std_encoding_EncodingSchemeUtf16Native_static_this();
    std_encoding_EncodingSchemeUtf32Native_static_this();
}
