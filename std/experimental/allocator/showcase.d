/**

Collection of typical and useful prebuilt allocators using the given
components. User code would typically import this module and use its
facilities, or import individual heap building blocks and assemble them.

*/
module std.experimental.allocator.showcase;

import std.experimental.allocator.fallback_allocator,
    std.experimental.allocator.gc_allocator,
    std.experimental.allocator.region;
import std.traits : hasMember;

/**

Allocator that uses stack allocation for up to $(D stackSize) bytes and
then falls back to $(D Allocator). Defined as:

----
alias StackFront(size_t stackSize, Allocator) =
    FallbackAllocator!(
        InSituRegion!(stackSize, Allocator.alignment,
            hasMember!(Allocator, "deallocate")
                ? Yes.defineDeallocate
                : No.defineDeallocate),
        Allocator);
----

Choosing `stackSize` is as always a compromise. Too small a size exhausts the
stack storage after a few allocations, after which there are no gains over the
backup allocator. Too large a size increases the stack consumed by the thread
and may end up worse off because it explores cold portions of the stack.

*/
alias StackFront(size_t stackSize, Allocator = GCAllocator) =
    FallbackAllocator!(
        InSituRegion!(stackSize, Allocator.alignment,
            hasMember!(Allocator, "deallocate")
                ? Yes.defineDeallocate
                : No.defineDeallocate),
        Allocator);

///
unittest
{
    //auto a = stackFront!4096;
    StackFront!4096 a;
    auto b = a.allocate(4000);
    assert(b.length == 4000);
    auto c = a.allocate(4000);
    assert(c.length == 4000);
    a.deallocate(b);
    a.deallocate(c);
}

/**
*/
//auto mmapRegionList!(alias factory)