module std.internal.memory;

package(std):

version (D_Exceptions)
{
    import core.exception : onOutOfMemoryError;
    private enum allocationFailed = `onOutOfMemoryError();`;
}
else
{
    private enum allocationFailed = `assert(0, "Memory allocation failed");`;
}

// (below comments are non-DDOC, but are written in similar style)

/+
Pure variants of C's memory allocation functions `malloc`, `calloc`, and
`realloc` that achieve purity by aborting the program on failure so
they never visibly change errno.

The functions may terminate the program using `onOutOfMemoryError` or
`assert(0)`. These functions' purity guarantees no longer hold if
the program continues execution after catching AssertError or
OutOfMemoryError.

See_Also: $(REF pureMalloc, core,memory)
+/
void* enforceMalloc()(size_t size) @nogc nothrow pure @safe
{
    auto result = fakePureMalloc(size);
    if (!result) mixin(allocationFailed);
    return result;
}

// ditto
void* enforceCalloc()(size_t nmemb, size_t size) @nogc nothrow pure @safe
{
    auto result = fakePureCalloc(nmemb, size);
    if (!result) mixin(allocationFailed);
    return result;
}

// ditto
void* enforceRealloc()(void* ptr, size_t size) @nogc nothrow pure @system
{
    auto result = fakePureRealloc(ptr, size);
    if (!result) mixin(allocationFailed);
    return result;
}

// Purified for local use only.
extern (C) @nogc nothrow pure private
{
    pragma(mangle, "malloc") void* fakePureMalloc(size_t) @safe;
    pragma(mangle, "calloc") void* fakePureCalloc(size_t nmemb, size_t size) @safe;
    pragma(mangle, "realloc") void* fakePureRealloc(void* ptr, size_t size) @system;
}
