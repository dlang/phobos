/**
Memory allocators handle memory mapping (mapping of memory address ranges onto hardware), guaranteeing alignment and optimizing for memory usage patterns.

A good memory allocator fit for purpose can improve a programs preformance quite significantly.
An ill fitting memory allocator on the other hand can not only slow down a program, but out right result in the program crashing.

All memory allocators have a memory mapper associated with them, either initially initializing it with a mapping or to allow further mapping as needed.
There are a few memory mappers implemented in this library. The first is malloc to provide a portable mapper that can be used as a fallback.
VirtualAlloc + HeapAlloc (Windows), and mmap (Posix) are also available. A common one not implemented is sbrk(Posix) as it was deprecated in the early 2000's.

On top of a memory mapper you will typically use either an allocator list with regions, or a buddy list.

The top most level is quite often some sort of allocation size allocator determiner with some sort of buffer like a coalescing free tree.

It is highly recommended by the author that when a type owns memory to not pass in a memory allocator but rather use the global allocator.
For types that are designed to be aggregated, these should take a memory allocator but default to the global allocator.
When data structures accept aggregatable types, it should also optionally support a memory allocator to deallocate its memory when removing.

Like all native allocators in use by D, this library is not safe to call in `@safe` code.
This is due to caller passing the wrong arguments and holding onto values it shouldn't.
It can result in use after free, and double free bugs in your code that can be highly difficult to debug.
Use containers to manage allocated memory, rather than interacting with an allocator directly.

When allocating, the `TypeInfo` parameter may not be used.
This will be made available to the memory mapper when forwarding calls.

Be aware that this library will not call destructors for you as part of the allocator itself.

License: Boost
Authors: Richard (Rikki) Andrew Cattermole <firstname@lastname.co.nz>
Copyright: 2022-2024 Richard Andrew Cattermole
*/
module phobos.sys.allocators;
public import phobos.sys.allocators.api;
