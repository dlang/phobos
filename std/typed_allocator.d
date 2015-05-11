// Written in the D programming language.

/**
Macros:
WIKI = Phobos/StdAllocator
MYREF = <font face='Consolas, "Bitstream Vera Sans Mono", "Andale Mono", Monaco,
"DejaVu Sans Mono", "Lucida Console", monospace'><a href="#$1">$1</a>&nbsp;</font>
TDC = <td nowrap>$(D $1)$(BR)$(SMALL $(I Post:) $(BLUE $(D $+)))</td>
TDC2 = <td nowrap>$(D $(LREF $0))</td>
RES = $(I result)

Copyright: Andrei Alexandrescu 2013-.

License: $(WEB boost.org/LICENSE_1_0.txt, Boost License 1.0).

Authors: $(WEB erdani.com, Andrei Alexandrescu)

Source: $(PHOBOSSRC std/_typed_allocator.d)

This module implements typed allocators - allocators that, unliked the untyped allocators in $(D std.allocator), are aware of the type of the objects stored
within.

*/
module std.typed_allocator;

/**
*/
void obliterate(T)(ref T obj)
{
    import std.traits;
    static if (isIntegral!T)
        static if (isSigned!T)
            obj = obj.min;
        else
            obj = obj.max;
    else static if (isBoolean!T)
        obj = false;
    else static if (isSomeChar!T)
        obj = obj.init;
    else static if (isSomeChar!T)
        obj = obj.init;
    else static if (isFloatingPoint!T)
        obj = obj.init;
    else if (is(T == U[], U))
        obj = (cast(U*) 0xFFFF_FFFF_FFFF_FFF0)[0 .. 0];
    else if (is(T : Object))
        obj = cast(T) 0xFFFF_FFFF_FFFF_FFF0;
    else
        static assert(false, T.stringof);
}

unittest
{
//    import std.typetuple;
//    foreach (T; TypeTuple!(byte, short, int, long))
//    {
//        T a;
//        obliterate(a);
//        assert(a == T.min);
//    }
}
