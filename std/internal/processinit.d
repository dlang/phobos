// Written in the D programming language.

/++
    The only purpose of this module is to do the static construction for
    std.process in order to eliminate cyclic construction errors.

    Copyright: Copyright 2011 -
    License:   $(WEB www.boost.org/LICENSE_1_0.txt, Boost License 1.0).
    Authors:   Jonathan M Davis and Kato Shoichi
    Source:    $(PHOBOSSRC std/_datetime.d)
  +/
module std.internal.processinit;

version(OSX)
{
    extern(C) void std_process_static_this();

    shared static this()
    {
        std_process_static_this();
    }
}
