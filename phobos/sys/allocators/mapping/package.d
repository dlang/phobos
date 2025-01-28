/**
Provides memory mapping for a given platform, along with the default to use.

License: Boost
Authors: Richard (Rikki) Andrew Cattermole <firstname@lastname.co.nz>
Copyright: 2022-2024 Richard Andrew Cattermole
 */
module phobos.sys.allocators.mapping;
///
public import phobos.sys.allocators.mapping.vars;

///
public import phobos.sys.allocators.mapping.malloc;

version (Windows)
{
    ///
    public import phobos.sys.allocators.mapping.virtualalloc;

    ///
    alias DefaultMapper = VirtualAllocMapper;
}
else version (Posix)
{
    ///
    public import phobos.sys.allocators.mapping.mmap;

    ///
    alias DefaultMapper = MMap;
}
else
{
    ///
    alias DefaultMapper = Mallocator;
}
