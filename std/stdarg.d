// Written in the D programming language.

/**
 * This is for use with variable argument lists with extern(D) linkage.
 * 
 * Copyright: Copyright Hauke Duden 2004 - 2009.
 * License:   <a href="http://www.boost.org/LICENSE_1_0.txt">Boost License 1.0</a>.
 * Authors:   Hauke Duden, $(WEB digitalmars.com, Walter Bright)
 *
 *          Copyright Hauke Duden 2004 - 2009.
 * Distributed under the Boost Software License, Version 1.0.
 *    (See accompanying file LICENSE_1_0.txt or copy at
 *          http://www.boost.org/LICENSE_1_0.txt)
 */
module std.stdarg;

alias void* va_list;

template va_arg(T)
{
    T va_arg(ref va_list _argptr)
    {
        T arg = *cast(T*)_argptr;
        _argptr = _argptr + ((T.sizeof + int.sizeof - 1) & ~(int.sizeof - 1));
        return arg;
    }
}

