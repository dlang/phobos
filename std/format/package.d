// Written in the D programming language.

/**
   This module implements the formatting functionality for strings and
   I/O. It's comparable to C99's `vsprintf()` and uses a similar
   _format encoding scheme.

   For an introductory look at $(B std._format)'s capabilities and how to use
   this module see the dedicated
   $(LINK2 http://wiki.dlang.org/Defining_custom_print_format_specifiers, DWiki article).

   This module centers around two functions:

$(BOOKTABLE ,
$(TR $(TH Function Name) $(TH Description)
)
    $(TR $(TD $(SUBREF read, formattedRead))
        $(TD Reads values according to the format string from an InputRange.
    ))
    $(TR $(TD $(SUBREF write, formattedWrite))
        $(TD Formats its arguments according to the format string and puts them
        to an OutputRange.
    ))
)

   Please see the documentation of function $(SUBREF write, formattedWrite) for a
   description of the format string.

   Two functions have been added for convenience:

$(BOOKTABLE ,
$(TR $(TH Function Name) $(TH Description)
)
    $(TR $(TD $(SUBREF tools, format))
        $(TD Returns a GC-allocated string with the formatting result.
    ))
    $(TR $(TD $(SUBREF tools, sformat))
        $(TD Puts the formatting result into a preallocated array.
    ))
)

   These two functions are publicly imported by $(MREF std, string)
   to be easily available.

   The functions $(SUBREF write, formatValue) and $(SUBREF read, unformatValue) are
   used for the plumbing.

   Submodules:

$(BOOKTABLE ,
$(TR $(TH Function Name) $(TH Description)
)
    $(TR $(TD $(SUBMODULE Reading, read)))
    $(TR $(TD $(SUBMODULE Writing, write)))
    $(TR $(TD $(SUBMODULE Tools, tools)))
)

Macros:
SUBMODULE = $(MREF_ALTTEXT $1, std, format, $2)
SUBREF = $(REF_ALTTEXT $(TT $2), $2, std, format, $1)$(NBSP)

   Copyright: Copyright The D Language Foundation 2000-2013.

   License: $(HTTP boost.org/LICENSE_1_0.txt, Boost License 1.0).

   Authors: $(HTTP walterbright.com, Walter Bright), $(HTTP erdani.com,
   Andrei Alexandrescu), and Kenji Hara

   Source: $(PHOBOSSRC std/format/package.d)
 */
module std.format;

public import std.format.read;
public import std.format.write;
public import std.format.tools;
