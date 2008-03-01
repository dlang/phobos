/**
 * Part of the D programming language runtime library.
 */

/*
 *  http://www.digitalmars.com
 *  Written by Walter Bright
 *  Placed in the Public Domain
 */

module arraycat;

import object;
import std.string;
import std.c.string;

extern (C)
void[] _d_arraycopy(uint size, void[] from, void[] to)
{
    //printf("f = %p,%d, t = %p,%d, size = %d\n", from.ptr, from.length, to.ptr, to.length, size);

    if (to.length != from.length)
    {
	//throw new Error(std.string.format("lengths don't match for array copy, %s = %s", to.length, from.length));
	throw new Error(cast(string) ("lengths don't match for array copy," ~
                                      toString(to.length) ~ " = "
                                      ~ toString(from.length)));
    }
    else if (to.ptr + to.length * size <= from.ptr ||
	from.ptr + from.length * size <= to.ptr)
    {
	memcpy(to.ptr, from.ptr, to.length * size);
    }
    else
    {
	throw new Error("overlapping array copy");
	//memmove(to.ptr, from.ptr, to.length * size);
    }
    return to;
}

