/**
    Note: has code from druntime.

    License: Boost
 */
module phobos.sys.allocators.mapping.vars;
export @trusted nothrow @nogc:

/// Size of the L1 cpu cache line
enum GoodAlignment = 64;

///
@property size_t PAGESIZE() pure
{
    return (cast(typeof(&PAGESIZE))&PAGESIZE_get)();
}

private
{
    // Bug: https://issues.dlang.org/show_bug.cgi?id=22031
    size_t PAGESIZE_get() @system
    {
        if (PAGESIZE_ == 0)
            initializeMappingVariables();
        return PAGESIZE_;
    }

    size_t PAGESIZE_;
}

private:

void initializeMappingVariables()
{
    // COPIED FROM druntime core.thread.types
    version (Windows)
    {
        import core.sys.windows.winbase;

        SYSTEM_INFO info;
        GetSystemInfo(&info);

        PAGESIZE_ = info.dwPageSize;
        assert(PAGESIZE < int.max);
    }
    else version (Posix)
    {
        import core.sys.posix.unistd;

        PAGESIZE_ = cast(size_t) sysconf(_SC_PAGESIZE);
    }
    else
    {
        pragma(msg, "Unknown platform, defaulting PAGESIZE in " ~ __MODULE__ ~ " to 64kb");
        PAGESIZE_ = 64 * 1024;
    }
}
