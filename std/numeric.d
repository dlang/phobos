// Written in the D programming language.

/**
This module is a port of a growing fragment of the $(D_PARAM numeric)
header in Alexander Stepanov's $(LINK2 http://sgi.com/tech/stl,
Standard Template Library), with a few additions.

Macros:

WIKI = Phobos/StdNumeric

Author:

$(WEB erdani.org, Andrei Alexandrescu)
*/

/*
 *  Copyright (C) 2004-2006 by Digital Mars, www.digitalmars.com
 *  Written by Andrei Alexandrescu, www.erdani.org
 *
 *  This software is provided 'as-is', without any express or implied
 *  warranty. In no event will the authors be held liable for any damages
 *  arising from the use of this software.
 *
 *  Permission is granted to anyone to use this software for any purpose,
 *  including commercial applications, and to alter it and redistribute it
 *  freely, subject to the following restrictions:
 *
 *  o  The origin of this software must not be misrepresented; you must not
 *     claim that you wrote the original software. If you use this software
 *     in a product, an acknowledgment in the product documentation would be
 *     appreciated but is not required.
 *  o  Altered source versions must be plainly marked as such, and must not
 *     be misrepresented as being the original software.
 *  o  This notice may not be removed or altered from any source
 *     distribution.
 */

module std.numeric;
import std.math;
import std.stdio;

/**
   Implements the $(LINK2 http://tinyurl.com/2zb9yr,secant method) for
   finding a root of the function $(D_PARAM f) starting from points
   [xn_1, x_n] (ideally close to the root). $(D_PARAM Num) may be
   $(D_PARAM float), $(D_PARAM double), or $(D_PARAM real).

Example:

----
float f(float x) {
    return cos(x) - x*x*x;
}
auto x = secantMethod(&f, 0f, 1f);
assert(approxEqual(x, 0.865474));
----
*/
template secantMethod(alias F)
{
    Num secantMethod(Num)(Num xn_1, Num xn) {
        auto fxn = F(xn_1), d = xn_1 - xn;
        typeof(fxn) fxn_1;
        xn = xn_1;
        while (!approxEqual(d, 0) && isfinite(d)) {
            xn_1 = xn;
            xn -= d;
            fxn_1 = fxn;
            fxn = F(xn);
            d *= -fxn / (fxn - fxn_1);
        }
        return xn;
    }
}

unittest
{
    scope(failure) writeln(stderr, "Failure testing secantMethod");
    float f(float x) {
        return cos(x) - x*x*x;
    }
    invariant x = secantMethod!(f)(0f, 1f);
    assert(approxEqual(x, 0.865474));
}

