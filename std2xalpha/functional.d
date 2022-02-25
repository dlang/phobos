module std2xalpha.functional;

static import std.functional;

// Pull all symbols from std.functional into the stdxalpha namespace.
static foreach (s; __traits(allMembers, std.functional))
{
    static if (__traits(compiles, mixin("{ alias "~s~" = std.functional."~s~"; }")))
    {
        mixin("alias "~s~" = std.functional."~s~";");
    }
}

/**
@@@TODO@@@: std2x `unaryFun` does not support string lambdas. Use function literals instead.
*/
//alias unaryFun(alias func) = func;

/**
@@@TODO@@@: std2x `unaryFun` does not support string lambdas. Use function literals instead.
*/
//alias binaryFun(alias func) = func;

///
unittest
{
    // string literals not supported
    // assert(binaryFun!"a + b"(1, 1) == 2); // no longer compiles
    assert(binaryFun!((a, b) => a + b)(1, 1) == 2); // works
}
