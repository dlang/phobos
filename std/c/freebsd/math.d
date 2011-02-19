
/**
 * Missing functions from C's &lt;math.h&gt;
 * Authors: Walter Bright, Digital Mars, http://www.digitalmars.com
 * License: Public Domain
 * Macros:
 *      WIKI=Phobos/StdCMath
 */

module std.c.freebsd.math;

import std.c.math;

extern (C):

version (all)
{
/* FreeBSD >= 8.0 doesn't do all the 'l' math functions.
 * So we provide our own (lame) implementations.
 */
real   log1pl(real x) { return log1p(x); }
real   cbrtl(real x) { return cbrt(x); }
real   powl(real x, real y) { return pow(x, y); }
real   erfl(real x) { return erf(x); }
real   erfcl(real x) { return erfc(x); }
real   lgammal(real x) { return lgamma(x); }
real   tgammal(real x) { return tgamma(x); }
}
else
{
/* FreeBSD < 8.0 doesn't do the 'l' math functions.
 * So we provide our own (lame) implementations.
 */

real   acosl(real x) { return acos(x); }
real   asinl(real x) { return asin(x); }
real   atanl(real x) { return atan(x); }
real   atan2l(real y, real x) { return atan2(y, x); }

real   cosl(real x) { return cos(x); }
real   sinl(real x) { return sin(x); }
real   tanl(real x) { return tan(x); }

real   acoshl(real x) { return acosh(x); }
real   asinhl(real x) { return asinh(x); }
real   atanhl(real x) { return atanh(x); }

real   coshl(real x) { return cosh(x); }
real   sinhl(real x) { return sinh(x); }
real   tanhl(real x) { return tanh(x); }

real   expl(real x) { return exp(x); }
real   exp2l(real x) { return exp2(x); }
real   expm1l(real x) { return expm1(x); }

//real   frexpl(real x, int *exp) { return frexp(x, exp); }
//real   ldexpl(real x, int exp) { return ldexp(x, exp); }

//real   ilogbl(real x) { return ilogb(x); }
real   logl(real x) { return log(x); }
real   log10l(real x) { return log10(x); }
real   log1pl(real x) { return log1p(x); }
real   log2l(real x) { return log10(x) / log10(2); }
real   logbl(real x) { return logb(x); }

/*
real   modfl(real x, real *iptr)
{   double d;
    auto r = modf(x, &d);
    *iptr = d;
    return r;
}
*/

//real   scalbnl(real x, int n) { return scalbn(x, n); }
//real   scalblnl(real x, int n) { return scalbln(x, n); }

real   cbrtl(real x) { return cbrt(x); }

//real   fabsl(real x) { return fabs(x); }

real   hypotl(real x, real y) { return hypot(x, y); }
real   powl(real x, real y) { return pow(x, y); }

real   sqrtl(real x) { return sqrt(x); }
real   erfl(real x) { return erf(x); }
real   erfcl(real x) { return erfc(x); }
real   lgammal(real x) { return lgamma(x); }
real   tgammal(real x) { return tgamma(x); }
real   ceill(real x) { return ceil(x); }
//real   floorl(real x) { return floor(x); }
real   nearbyintl(real x) { return nearbyint(x); }
real   rintl(real x) { return rint(x); }
int    lrintl(real x) { return lrint(x); }
long   llrintl(real x) { return llrint(x); }
//real   roundl(real x) { return round(x); }
//int   lroundl(real x) { return lround(x); }
//long   llroundl(real x) { return llround(x); }
//real   truncl(real x) { return trunc(x); }

real   fmodl(real x, real y) { return fmod(x, y); }
real   remainderl(real x, real y) { return remainder(x, y); }
real   remquol(real x, real y, int* quo) { return remquo(x, y, quo); }
real   copysignl(real x, real y) { return copysign(x, y); }
real   nanl(char *tagp) { return real.nan; }
//real   nextafterl(real x, real y) { return nextafter(x, y); }
//real   nexttowardl(real x, real y) { return nexttoward(x, y); }
//real   fdiml(real x, real y) { return fdim(x, y); }
//real   fmaxl(real x, real y) { return fmax(x, y); }
//real   fminl(real x, real y) { return fmin(x, y); }
//real   fmal(real x, real y, real z) { return fma(x, y, z); }

}
