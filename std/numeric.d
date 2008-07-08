// Written in the D programming language.

/**
This module is a port of a growing fragment of the $(D_PARAM numeric)
header in Alexander Stepanov's $(LINK2 http://sgi.com/tech/stl,
Standard Template Library), with a few additions.

Macros:

WIKI = Phobos/StdNumeric

Author:

$(WEB erdani.org, Andrei Alexandrescu), Don Clugston
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
import std.typecons;
import std.math;
import std.traits;
import std.contracts;
import std.random;
import std.string;
version(unittest)
{
    import std.stdio;
}

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


private:
// Return true if a and b have opposite sign.
bool oppositeSigns(T)(T a, T b)
{
    // Use signbit() if available, otherwise check the signs.
    static if (is(typeof(signbit(a)))) {    
        return (signbit(a) ^ signbit(b))!=0;
    } else return (a>0 && b<0) || (a>0 && b<0);
}


public:

/**  Find a real root of a real function f(x) via bracketing.
 *
 * Given a function $(D f) and a range $(D [a..b]) such that $(D f(a))
 * and $(D f(b)) have opposite signs, returns the value of $(D x) in
 * the range which is closest to a root of $(D f(x)).  If $(D f(x))
 * has more than one root in the range, one will be chosen
 * arbitrarily.  If $(D f(x)) returns NaN, NaN will be returned;
 * otherwise, this algorithm is guaranteed to succeed.
 *  
 * Uses an algorithm based on TOMS748, which uses inverse cubic
 * interpolation whenever possible, otherwise reverting to parabolic
 * or secant interpolation. Compared to TOMS748, this implementation
 * improves worst-case performance by a factor of more than 100, and
 * typical performance by a factor of 2. For 80-bit reals, most
 * problems require 8 to 15 calls to $(D f(x)) to achieve full machine
 * precision. The worst-case performance (pathological cases) is
 * approximately twice the number of bits.
 *
 * References: "On Enclosing Simple Roots of Nonlinear Equations",
 * G. Alefeld, F.A. Potra, Yixun Shi, Mathematics of Computation 61,
 * pp733-744 (1993).  Fortran code available from $(WEB
 * www.netlib.org,www.netlib.org) as algorithm TOMS478.
 *
 */
T findRoot(T, R)(R delegate(T) f, T a, T b)
{
    auto r = findRoot(f, a, b, f(a), f(b), (T lo, T hi){ return false; });
    // Return the first value if it is smaller or NaN
    return fabs(r._2) !> fabs(r._3) ? r._0 : r._1;
}

/** Find root of a real function f(x) by bracketing, allowing the
 * termination condition to be specified.
 *
 * Params:
 * 
 * f = Function to be analyzed
 *
 * ax = Left bound of initial range of $(D f) known to contain the
 * root.
 *
 * bx = Right bound of initial range of $(D f) known to contain the
 * root.
 *
 * fax = Value of $(D f(ax)).
 *
 * fax = Value of $(D f(ax)) and $(D f(bx)). ($(D f(ax)) and $(D
 * f(bx)) are commonly known in advance.)
 *
 * 
 * tolerance = Defines an early termination condition. Receives the
 *             current upper and lower bounds on the root. The
 *             delegate must return $(D true) when these bounds are
 *             acceptable. If this function always returns $(D false),
 *             full machine precision will be achieved.
 *
 * Returns:
 *
 * A tuple consisting of two ranges. The first two elements are the
 * range (in $(D x)) of the root, while the second pair of elements
 * are the corresponding function values at those points. If an exact
 * root was found, both of the first two elements will contain the
 * root, and the second pair of elements will be 0.
 */
Tuple!(T, T, R, R) findRoot(T,R)(R delegate(T) f, T ax, T bx, R fax, R fbx,
    bool delegate(T lo, T hi) tolerance)
in {
    assert(ax<>=0 && bx<>=0, "Limits must not be NaN");
    assert(oppositeSigns(fax, fbx), "Parameters must bracket the root.");
}
body {   
// This code is (heavily) modified from TOMS748 (www.netlib.org). Some ideas
// were borrowed from the Boost Mathematics Library.

    T a, b, d;  // [a..b] is our current bracket. d is the third best guess.
    R fa, fb, fd; // Values of f at a, b, d.
    bool done = false; // Has a root been found?
    
    // Allow ax and bx to be provided in reverse order
    if (ax <= bx) {
        a = ax; fa = fax; 
        b = bx; fb = fbx;
    } else {
        a = bx; fa = fbx; 
        b = ax; fb = fax;
    }

    // Test the function at point c; update brackets accordingly
    void bracket(T c)
    {
        T fc = f(c);        
        if (fc !<> 0) { // Exact solution, or NaN
            a = c;
            fa = fc;
            d = c;
            fd = fc;
            done = true;
            return;
        }
        // Determine new enclosing interval
        if (oppositeSigns(fa, fc)) {
            d = b;
            fd = fb;
            b = c;
            fb = fc;
        } else {
            d = a;
            fd = fa;
            a = c;
            fa = fc;
        }
    }

   /* Perform a secant interpolation. If the result would lie on a or b, or if
     a and b differ so wildly in magnitude that the result would be meaningless,
     perform a bisection instead.
    */
    T secant_interpolate(T a, T b, T fa, T fb)
    {
        if (( ((a - b) == a) && b!=0) || (a!=0 && ((b - a) == b))) {
            // Catastrophic cancellation
            if (a == 0) a = copysign(0.0L, b);
            else if (b == 0) b = copysign(0.0L, a);
            else if (oppositeSigns(a, b)) return 0;
            T c = ieeeMean(a, b); 
            return c;
        }
       // avoid overflow
       if (b - a > T.max)    return b / 2.0 + a / 2.0;
       if (fb - fa > T.max)  return a - (b - a) / 2;
       T c = a - (fa / (fb - fa)) * (b - a);
       if (c == a || c == b) return (a + b) / 2;
       return c;
    }
    
    /* Uses 'numsteps' newton steps to approximate the zero in [a..b] of the
       quadratic polynomial interpolating f(x) at a, b, and d.
       Returns:         
         The approximate zero in [a..b] of the quadratic polynomial.
    */
    T newtonQuadratic(int numsteps)
    {
        // Find the coefficients of the quadratic polynomial.
        T a0 = fa;
        T a1 = (fb - fa)/(b - a);
        T a2 = ((fd - fb)/(d - b) - a1)/(d - a);
    
        // Determine the starting point of newton steps.
        T c = oppositeSigns(a2, fa) ? a  : b;
     
        // start the safeguarded newton steps.
        for (int i = 0; i<numsteps; ++i) {        
            T pc = a0 + (a1 + a2 * (c - b))*(c - a);
            T pdc = a1 + a2*((2.0 * c) - (a + b));
            if (pdc == 0) return a - a0 / a1;
            else c = c - pc / pdc;        
        }
        return c;    
    }
    
    // On the first iteration we take a secant step:
    if (fa !<> 0) {
        done = true;
        b = a;
        fb = fa;
    } else if (fb !<> 0) {
        done = true;
        a = b;
        fa = fb;
    } else {
        bracket(secant_interpolate(a, b, fa, fb));
    }
    // Starting with the second iteration, higher-order interpolation can
    // be used.
    int itnum = 1;   // Iteration number    
    int baditer = 1; // Num bisections to take if an iteration is bad.
    T c, e;  // e is our fourth best guess
    R fe;   
whileloop:
    while(!done && (b != nextUp(a)) && !tolerance(a, b)) {        
        T a0 = a, b0 = b; // record the brackets
      
        // Do two higher-order (cubic or parabolic) interpolation steps.
        for (int QQ = 0; QQ < 2; ++QQ) {      
            // Cubic inverse interpolation requires that 
            // all four function values fa, fb, fd, and fe are distinct; 
            // otherwise use quadratic interpolation.
            bool distinct = (fa != fb) && (fa != fd) && (fa != fe) 
                         && (fb != fd) && (fb != fe) && (fd != fe);
            // The first time, cubic interpolation is impossible.
            if (itnum<2) distinct = false;
            bool ok = distinct;
            if (distinct) {                
                // Cubic inverse interpolation of f(x) at a, b, d, and e
                real q11 = (d - e) * fd / (fe - fd);
                real q21 = (b - d) * fb / (fd - fb);
                real q31 = (a - b) * fa / (fb - fa);
                real d21 = (b - d) * fd / (fd - fb);
                real d31 = (a - b) * fb / (fb - fa);
                      
                real q22 = (d21 - q11) * fb / (fe - fb);
                real q32 = (d31 - q21) * fa / (fd - fa);
                real d32 = (d31 - q21) * fd / (fd - fa);
                real q33 = (d32 - q22) * fa / (fe - fa);
                c = a + (q31 + q32 + q33);
                if (c!<>=0 || (c <= a) || (c >= b)) {
                    // DAC: If the interpolation predicts a or b, it's 
                    // probable that it's the actual root. Only allow this if
                    // we're already close to the root.                
                    if (c == a && a - b != a) {
                        c = nextUp(a);
                    }
                    else if (c == b && a - b != -b) {
                        c = nextDown(b);
                    } else {
                        ok = false;
                    }
                }
            }
            if (!ok) {
                // DAC: Alefeld doesn't explain why the number of newton steps
                // should vary.
                c = newtonQuadratic(distinct ? 3 : 2);
                if(c!<>=0 || (c <= a) || (c >= b)) {
                    // Failure, try a secant step:
                    c = secant_interpolate(a, b, fa, fb);
                }
            }
            ++itnum;                
            e = d;
            fe = fd;
            bracket(c);
            if( done || ( b == nextUp(a)) || tolerance(a, b))
                break whileloop;
            if (itnum == 2)
                continue whileloop;
        }
        // Now we take a double-length secant step:
        T u;
        R fu;
        if(fabs(fa) < fabs(fb)) {
            u = a;
            fu = fa;
        } else {
            u = b;
            fu = fb;
        }
        c = u - 2 * (fu / (fb - fa)) * (b - a);
        // DAC: If the secant predicts a value equal to an endpoint, it's
        // probably false.      
        if(c==a || c==b || c!<>=0 || fabs(c - u) > (b - a) / 2) {
            if ((a-b) == a || (b-a) == b) {
                if ( (a>0 && b<0) || (a<0 && b>0) ) c = 0;
                else {
                    if (a==0) c = ieeeMean(copysign(0.0L, b), b);
                    else if (b==0) c = ieeeMean(copysign(0.0L, a), a);
                    else c = ieeeMean(a, b);
                }
            } else {
                c = a + (b - a) / 2;
            }       
        }
        e = d;
        fe = fd;
        bracket(c);
        if(done || (b == nextUp(a)) || tolerance(a, b))
            break;

        // IMPROVE THE WORST-CASE PERFORMANCE       
        // We must ensure that the bounds reduce by a factor of 2 
        // in binary space! every iteration. If we haven't achieved this
        // yet, or if we don't yet know what the exponent is,
        // perform a binary chop.

        if( (a==0 || b==0 || 
            (fabs(a) >= 0.5 * fabs(b) && fabs(b) >= 0.5 * fabs(a))) 
            &&  (b - a) < 0.25 * (b0 - a0))  {
                baditer = 1;        
                continue;
            }
        // DAC: If this happens on consecutive iterations, we probably have a
        // pathological function. Perform a number of bisections equal to the
        // total number of consecutive bad iterations.
        
        if ((b - a) < 0.25 * (b0 - a0)) baditer = 1;
        for (int QQ = 0; QQ < baditer ;++QQ) {
            e = d;
            fe = fd;
    
            T w;
            if ((a>0 && b<0) ||(a<0 && b>0)) w = 0;
            else {
                T usea = a;
                T useb = b;
                if (a == 0) usea = copysign(0.0L, b);
                else if (b == 0) useb = copysign(0.0L, a);
                w = ieeeMean(usea, useb);
            }
            bracket(w);
        }
        ++baditer;
    }
    return Tuple!(T, T, R, R)(a, b, fa, fb);
}

unittest{
    
    int numProblems = 0;
    int numCalls;
    
    void testFindRoot(real delegate(real) f, real x1, real x2) {
        numCalls=0;
        ++numProblems;
        assert(x1<>=0 && x2<>=0);
        auto result = findRoot(f, x1, x2, f(x1), f(x2),
          (real lo, real hi) { return false; });
        
        auto flo = f(result._0);
        auto fhi = f(result._1);
        if (flo!=0) {
            assert(oppositeSigns(flo, fhi));
        }
    }
    
    // Test functions
    real cubicfn (real x) {
       ++numCalls;
       if (x>float.max) x = float.max;
       if (x<-double.max) x = -double.max;
       // This has a single real root at -59.286543284815
       return 0.386*x*x*x + 23*x*x + 15.7*x + 525.2;
    }
    // Test a function with more than one root.
    real multisine(real x) { ++numCalls; return sin(x); }
    testFindRoot( &multisine, 6, 90);
    testFindRoot(&cubicfn, -100, 100);    
    testFindRoot( &cubicfn, -double.max, real.max);
    
    
/* Tests from the paper:
 * "On Enclosing Simple Roots of Nonlinear Equations", G. Alefeld, F.A. Potra, 
 *   Yixun Shi, Mathematics of Computation 61, pp733-744 (1993).
 */
    // Parameters common to many alefeld tests.
    int n;
    real ale_a, ale_b;

    int powercalls = 0;
    
    real power(real x) {
        ++powercalls;
        ++numCalls;
        return pow(x, n) + double.min;
    }
    int [] power_nvals = [3, 5, 7, 9, 19, 25];
    // Alefeld paper states that pow(x,n) is a very poor case, where bisection
    // outperforms his method, and gives total numcalls = 
    // 921 for bisection (2.4 calls per bit), 1830 for Alefeld (4.76/bit), 
    // 2624 for brent (6.8/bit)
    // ... but that is for double, not real80.
    // This poor performance seems mainly due to catastrophic cancellation, 
    // which is avoided here by the use of ieeeMean().
    // I get: 231 (0.48/bit).
    // IE this is 10X faster in Alefeld's worst case
    numProblems=0;
    foreach(k; power_nvals) {
        n = k;
        testFindRoot(&power, -1, 10);
    }
    
    int powerProblems = numProblems;

    // Tests from Alefeld paper
        
    int [9] alefeldSums;
    real alefeld0(real x){
        ++alefeldSums[0];
        ++numCalls;
        real q =  sin(x) - x/2;
        for (int i=1; i<20; ++i)
            q+=(2*i-5.0)*(2*i-5.0)/((x-i*i)*(x-i*i)*(x-i*i));
        return q;
    }
   real alefeld1(real x) {
        ++numCalls;
       ++alefeldSums[1];
       return ale_a*x + exp(ale_b * x);
   }
   real alefeld2(real x) {
        ++numCalls;
       ++alefeldSums[2];
       return pow(x, n) - ale_a;
   }
   real alefeld3(real x) {
        ++numCalls;
       ++alefeldSums[3];
       return (1.0 +pow(1.0L-n, 2))*x - pow(1.0L-n*x, 2);
   }
   real alefeld4(real x) {
        ++numCalls;
       ++alefeldSums[4];
       return x*x - pow(1-x, n);
   }
   
   real alefeld5(real x) {
        ++numCalls;
       ++alefeldSums[5];
       return (1+pow(1.0L-n, 4))*x - pow(1.0L-n*x, 4);
   }
   
   real alefeld6(real x) {
        ++numCalls;
       ++alefeldSums[6];
       return exp(-n*x)*(x-1.01L) + pow(x, n);
   }
   
   real alefeld7(real x) {
        ++numCalls;
       ++alefeldSums[7];
       return (n*x-1)/((n-1)*x);
   }
   numProblems=0;
   testFindRoot(&alefeld0, PI_2, PI);
   for (n=1; n<=10; ++n) {
    testFindRoot(&alefeld0, n*n+1e-9L, (n+1)*(n+1)-1e-9L);
   }
   ale_a = -40; ale_b = -1;
   testFindRoot(&alefeld1, -9, 31);
   ale_a = -100; ale_b = -2;
   testFindRoot(&alefeld1, -9, 31);
   ale_a = -200; ale_b = -3;
   testFindRoot(&alefeld1, -9, 31);
   int [] nvals_3 = [1, 2, 5, 10, 15, 20];
   int [] nvals_5 = [1, 2, 4, 5, 8, 15, 20];
   int [] nvals_6 = [1, 5, 10, 15, 20];
   int [] nvals_7 = [2, 5, 15, 20];
  
    for(int i=4; i<12; i+=2) {
       n = i;
       ale_a = 0.2;
       testFindRoot(&alefeld2, 0, 5);
       ale_a=1;
       testFindRoot(&alefeld2, 0.95, 4.05);
       testFindRoot(&alefeld2, 0, 1.5);       
    }
    foreach(i; nvals_3) {
        n=i;
        testFindRoot(&alefeld3, 0, 1);
    }
    foreach(i; nvals_3) {
        n=i;
        testFindRoot(&alefeld4, 0, 1);
    }
    foreach(i; nvals_5) {
        n=i;
        testFindRoot(&alefeld5, 0, 1);
    }
    foreach(i; nvals_6) {
        n=i;
        testFindRoot(&alefeld6, 0, 1);
    }
    foreach(i; nvals_7) {
        n=i;
        testFindRoot(&alefeld7, 0.01L, 1);
    }   
    real worstcase(real x) { ++numCalls;
        return x<0.3*real.max? -0.999e-3 : 1.0;
    }
    testFindRoot(&worstcase, -real.max, real.max);
       
/*   
   int grandtotal=0;
   foreach(calls; alefeldSums) {
       grandtotal+=calls;
   }
   grandtotal-=2*numProblems;
   printf("\nALEFELD TOTAL = %d avg = %f (alefeld avg=19.3 for double)\n", 
   grandtotal, (1.0*grandtotal)/numProblems);
   powercalls -= 2*powerProblems;
   printf("POWER TOTAL = %d avg = %f ", powercalls, 
        (1.0*powercalls)/powerProblems);
*/        
}

template tabulateFixed(alias fun, uint n,
        real maxError, real left, real right)
{
    ReturnType!(fun) tabulateFixed(ParameterTypeTuple!(fun) arg)
    {
        alias ParameterTypeTuple!(fun)[0] num;
        static num[n] table;
        alias arg[0] x;
        enforce(left <= x && x < right);
        invariant i = cast(uint) (table.length
                * ((x - left) / (right - left)));
        assert(i < n);
        if (isnan(table[i])) {
            // initialize it
            auto x1 = left + i * (right - left) / n;
            auto x2 = left + (i + 1) * (right - left) / n;
            invariant y1 = fun(x1), y2 = fun(x2);
            invariant y = 2 * y1 * y2 / (y1 + y2);
            num wyda(num xx) { return fun(xx) - y; }
            auto bestX = findRoot(&wyda, x1, x2);
            table[i] = fun(bestX);
            invariant leftError = abs((table[i] - y1) / y1);
            enforce(leftError <= maxError, text(leftError, " > ", maxError));
            invariant rightError = abs((table[i] - y2) / y2);
            enforce(rightError <= maxError, text(rightError, " > ", maxError));
        }
        return table[i];
    }
}

unittest
{
    enum epsilon = 0.01;
    alias tabulateFixed!(tanh, 700, epsilon, 0.2, 3) fasttanh;
    uint testSize = 100000;
    auto rnd = Random(unpredictableSeed);
    foreach (i; 0 .. testSize) {
        invariant x = uniform(rnd, 0.2F, 3.0F);
        invariant float y = fasttanh(x), w = tanh(x);
        invariant e = abs(y - w) / w;
        //writefln("%.20f", e);
        enforce(e <= epsilon, text("x = ", x, ", fasttanh(x) = ", y,
                        ", tanh(x) = ", w, ", relerr = ", e));
    }
}
