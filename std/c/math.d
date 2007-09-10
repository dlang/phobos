
/**
 * Standard C math.h
 *
 * Copyright: Public Domain
 */

/* www.digitalmars.com
 */

module std.c.math;

extern (C):

alias float float_t;
alias double double_t;

const double HUGE_VAL  = double.infinity;
const double HUGE_VALF = float.infinity;
const double HUGE_VALL = real.infinity;

const float INFINITY = float.infinity;
const float NAN = float.nan;

enum
{
    FP_NANS,	// extension
    FP_NANQ,	// extension
    FP_INFINITE,
    FP_NAN = FP_NANQ,
    FP_NORMAL = 3,
    FP_SUBNORMAL = 4,
    FP_ZERO = 5,
    FP_EMPTY = 6,	// extension
    FP_UNSUPPORTED = 7, // extension
}

enum
{
    FP_FAST_FMA  = 0,
    FP_FAST_FMAF = 0,
    FP_FAST_FMAL = 0,
}

const int FP_ILOGB0   = int.min;
const int FP_ILOGBNAN = int.min;

const int MATH_ERRNO     = 1;
const int MATH_ERREXCEPT = 2;
const int math_errhandling   = MATH_ERRNO | MATH_ERREXCEPT;

double acos(double x);
float  acosf(float x);
real   acosl(real x);

double asin(double x);
float  asinf(float x);
real   asinl(real x);

double atan(double x);
float  atanf(float x);
real   atanl(real x);

double atan2(double y, double x);
float  atan2f(float y, float x);
real   atan2l(real y, real x);

double cos(double x);
float  cosf(float x);
real   cosl(real x);

double sin(double x);
float  sinf(float x);
real   sinl(real x);

double tan(double x);
float  tanf(float x);
real   tanl(real x);

double acosh(double x);
float  acoshf(float x);
real   acoshl(real x);

double asinh(double x);
float  asinhf(float x);
real   asinhl(real x);

double atanh(double x);
float  atanhf(float x);
real   atanhl(real x);

double cosh(double x);
float  coshf(float x);
real   coshl(real x);

double sinh(double x);
float  sinhf(float x);
real   sinhl(real x);

double tanh(double x);
float  tanhf(float x);
real   tanhl(real x);

double exp(double x);
float  expf(float x);
real   expl(real x);

double exp2(double x);
float  exp2f(float x);
real   exp2l(real x);

double expm1(double x);
float  expm1f(float x);
real   expm1l(real x);

double frexp(double value, int *exp);
float  frexpf(float value, int *exp);
real   frexpl(real value, int *exp);

int    ilogb(double x);
int    ilogbf(float x);
int    ilogbl(real x);

double ldexp(double x, int exp);
float  ldexpf(float x, int exp);
real   ldexpl(real x, int exp);

double log(double x);
float  logf(float x);
real   logl(real x);

double log10(double x);
float  log10f(float x);
real   log10l(real x);

double log1p(double x);
float  log1pf(float x);
real   log1pl(real x);

double log2(double x);
float  log2f(float x);
real   log2l(real x);

double logb(double x);
float  logbf(float x);
real   logbl(real x);

double modf(double value, double *iptr);
float  modff(float value, float *iptr);
real   modfl(real value, real *iptr);

double scalbn(double x, int n);
float  scalbnf(float x, int n);
real   scalbnl(real x, int n);

double scalbln(double x, int n);
float  scalblnf(float x, int n);
real   scalblnl(real x, int n);

double cbrt(double x);
float  cbrtf(float x);
real   cbrtl(real x);

double fabs(double x);
float  fabsf(float x);
real   fabsl(real x);

double hypot(double x, double y);
float  hypotf(float x, float y);
real   hypotl(real x, real y);

double pow(double x, double y);
float  powf(float x, float y);
real   powl(real x, real y);

double sqrt(double x);
float  sqrtf(float x);
real   sqrtl(real x);

double erf(double x);
float  erff(float x);
real   erfl(real x);

double erfc(double x);
float  erfcf(float x);
real   erfcl(real x);

double lgamma(double x);
float  lgammaf(float x);
real   lgammal(real x);

double tgamma(double x);
float  tgammaf(float x);
real   tgammal(real x);

double ceil(double x);
float  ceilf(float x);
real   ceill(real x);

double floor(double x);
float  floorf(float x);
real   floorl(real x);

double nearbyint(double x);
float  nearbyintf(float x);
real   nearbyintl(real x);

double rint(double x);
float  rintf(float x);
real   rintl(real x);

int    lrint(double x);
int    lrintf(float x);
int    lrintl(real x);

long   llrint(double x);
long   llrintf(float x);
long   llrintl(real x);

double round(double x);
float  roundf(float x);
real   roundl(real x);

int    lround(double x);
int    lroundf(float x);
int    lroundl(real x);

long   llround(double x);
long   llroundf(float x);
long   llroundl(real x);

double trunc(double x);
float  truncf(float x);
real   truncl(real x);

double fmod(double x, double y);
float  fmodf(float x, float y);
real   fmodl(real x, real y);

double remainder(double x, double y);
float  remainderf(float x, float y);
real   remainderl(real x, real y);

double remquo(double x, double y, int *quo);
float  remquof(float x, float y, int *quo);
real   remquol(real x, real y, int *quo);

double copysign(double x, double y);
float  copysignf(float x, float y);
real   copysignl(real x, real y);

double nan(char *tagp);
float  nanf(char *tagp);
real   nanl(char *tagp);

double nextafter(double x, double y);
float  nextafterf(float x, float y);
real   nextafterl(real x, real y);

double nexttoward(double x, real y);
float  nexttowardf(float x, real y);
real   nexttowardl(real x, real y);

double fdim(double x, double y);
float  fdimf(float x, float y);
real   fdiml(real x, real y);

double fmax(double x, double y);
float  fmaxf(float x, float y);
real   fmaxl(real x, real y);

double fmin(double x, double y);
float  fminf(float x, float y);
real   fminl(real x, real y);

double fma(double x, double y, double z);
float  fmaf(float x, float y, float z);
real   fmal(real x, real y, real z);

int isgreater(real x, real y)		{ return !(x !>  y); }
int isgreaterequal(real x, real y)	{ return !(x !>= y); }
int isless(real x, real y)		{ return !(x !<  y); }
int islessequal(real x, real y)		{ return !(x !<= y); }
int islessgreater(real x, real y)	{ return !(x !<> y); }
int isunordered(real x, real y)		{ return (x !<>= y); }

