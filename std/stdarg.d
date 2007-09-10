
/*
 * Placed in public domain.
 * Written by Hauke Duden and Walter Bright
 */

module std.stdarg;

template va_arg(T)
{
    T va_arg(inout void* _argptr)
    {
	T arg = *cast(T*)_argptr;
	_argptr = _argptr + ((T.sizeof + int.sizeof - 1) & ~(int.sizeof - 1));
	return arg;
    }
}

