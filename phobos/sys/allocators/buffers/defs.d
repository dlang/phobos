/**
Definitions used by multiple allocator buffers.

License: Boost
Authors: Richard (Rikki) Andrew Cattermole <firstname@lastname.co.nz>
Copyright: 2022-2024 Richard Andrew Cattermole
*/
module phobos.sys.allocators.buffers.defs;

///
enum FitsStrategy
{
    ///
    FirstFit,
    ///
    NextFit,
    ///
    BestFit,
    ///
    WorstFit,
}
