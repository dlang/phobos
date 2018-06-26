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

void test()
{
    import stdx.allocator : make;
    import stdx.allocator.mallocator : Mallocator;
    alias alloc = Mallocator.instance;
    struct Node
    {
        int x;
        this(int, int){}
    }
    auto newNode = alloc.make!Node(2, 3);
}
