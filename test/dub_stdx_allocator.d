#!/usr/bin/env dub
/++dub.sdl:
dependency "phobos:allocator" path=".."
+/

void main(string[] args)
{
    import stdx.allocator.mallocator : Mallocator; // From latest Phobos
    import std.stdio; // current phobos
    auto buf = Mallocator.instance.allocate(10);
    writeln("allocate: ", buf);
    scope(exit) Mallocator.instance.deallocate(buf);
}
