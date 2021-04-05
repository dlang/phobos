// Written in the D programming language.

/**
This package is currently in a nascent state and may be subject to
change. Please do not use it yet, but stick to $(MREF std, math).

Copyright: Copyright The D Language Foundation 2021 - .
License:   $(HTTP www.boost.org/LICENSE_1_0.txt, Boost License 1.0).
Authors:   Bernhard Seckinger
Source: $(PHOBOSSRC std/math/integral.d)
 */

module std.math.integral;

import std.traits : Unqual;

/**
Calculates the base-2 logarithm of an integral number using binary search.

The result can also be interpreted as the position of the most significant
1 bit in the binary representation of that number.

The algorithm uses a special processor instruction, if available and
a very fast software implementation else.

Params:
    value = an integral number
    Int = the type of the integral number

Returns:
    For positive values the base-2 logarithm rounded down to the next integer
    value and 0 for zero and negative values.
 */
Unqual!Int ilog2(Int)(Int value)
{
    import core.bitop : bsr;

    if (value <= 0) return 0;
    return cast(typeof(return)) bsr(value);
}

///
@safe pure unittest
{
    assert(ilog2(8) == 3);

    // the result is rounded down
    assert(ilog2(10) == 3);

    // zero and negative values always return 0
    assert(ilog2(0) == 0);
    assert(ilog2(-5) == 0);
}

@safe pure unittest
{
    static assert(ilog2(ubyte.max) == 7);
    static assert(ilog2(ushort.max) == 15);
    static assert(ilog2(uint.max) == 31);
    static assert(ilog2(ulong.max) == 63);

    static assert(ilog2(byte.max) == 6);
    static assert(ilog2(short.max) == 14);
    static assert(ilog2(int.max) == 30);
    static assert(ilog2(long.max) == 62);
}

@safe pure unittest
{
    immutable r = 987654321;
    assert(ilog2(r) == 29);

    shared s = 987654321;
    assert(ilog2(s) == 29);
}
