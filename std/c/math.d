
/* Copyright (C) 2003 by Digital Mars.
 * All Rights Reserved
 * www.digitalmars.com
 */

module std.c.math;

extern (C):

alias float float_t;
alias double double_t;

real   acosl(real);
real   asinl(real);
real   atanl(real);
real   atan2l(real, real);
real   cosl(real);
real   sinl(real);
real   tanl(real);
real   acoshl(real x);
real   asinhl(real x);
real   atanhl(real x);
real   coshl(real);
real   sinhl(real);
real   tanhl(real);
real   expl(real);
real   exp2l(real);
real   expm1l(real);
real   frexpl(real,int *);
int    ilogbl(real);
real   ldexpl(real, int);
real   logl(real);
real   log10l(real);
real   log1pl(real);
real   log2l(real);
real   logbl(real);
real   modfl(real, real *);
real   scalbnl(real, int);
real   scalblnl(real, int);
real   cbrtl(real);
real   fabsl(real);
real   hypotl(real, real);
real   powl(real, real);
real   sqrtl(real);
real   erfl(real x);
real   erfcl(real x);
real   lgammal(real x);
real   tgammal(real x);
real   ceill(real);
real   floorl(real);
real   nearbyintl(real);
real   rintl(real);
int    lrintl(real x);
long   llrintl(real x);
real   roundl(real);
int    lroundl(real x);
long   llroundl(real x);
real   truncl(real);
real   fmodl(real, real);
real   remainderl(real, real);
real   remquol(real, real, int *);
real   copysignl(real, real);
real   nanl(char *);
real   nextafterl(real, real);
real   nexttowardl(real, real);
real   fdiml(real, real);
real   fmaxl(real, real);
real   fminl(real, real);
real   fmal(real, real, real);


int isgreater(real x, real y)		{ return !(x !>  y); }
int isgreaterequal(real x, real y)	{ return !(x !>= y); }
int isless(real x, real y)		{ return !(x !<  y); }
int islessequal(real x, real y)		{ return !(x !<= y); }
int islessgreater(real x, real y)	{ return !(x !<> y); }
int isunordered(real x, real y)		{ return (x !<>= y); }

