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

version(OSX)
{
    extern(C) void std_process_shared_static_this();

    shared static this()
    {
        std_process_shared_static_this();
    }
}
