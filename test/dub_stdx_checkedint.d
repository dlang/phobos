#!/usr/bin/env dub
/++dub.sdl:
dependency "phobos:checkedint" path=".."
+/

void main(string[] args)
{
    import stdx.checkedint; // From latest Phobos
    import std.stdio; // DMD's Phobos
    writeln("checkedint: ", 2.checked + 3);
}
