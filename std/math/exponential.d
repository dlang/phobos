// Written in the D programming language.

/**
This package is currently in a nascent state and may be subject to
change. Please do not use it yet, but stick to $(MREF std, math).

Copyright: Copyright The D Language Foundation 2000 - 2011.
           D implementations of exp, expm1, exp2, log, log10, log1p, and log2
           functions are based on the CEPHES math library, which is Copyright
           (C) 2001 Stephen L. Moshier $(LT)steve@moshier.net$(GT) and are
           incorporated herein by permission of the author. The author reserves
           the right to distribute this material elsewhere under different
           copying permissions. These modifications are distributed here under
           the following terms:
License:   $(HTTP www.boost.org/LICENSE_1_0.txt, Boost License 1.0).
Authors:   $(HTTP digitalmars.com, Walter Bright), Don Clugston,
           Conversion of CEPHES math library to D by Iain Buclaw and David Nadlinger
Source: $(PHOBOSSRC std/math/exponential.d)
 */

module std.math.exponential;

// Will contain functions like pow, exp, log2
