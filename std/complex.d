// Written in the D programming language.

/**
Module that will replace the built-in types $(D cfloat), $(D cdouble),
$(D creal), $(D ifloat), $(D idouble), and $(D ireal).

Author:
$(WEB erdani.org, Andrei Alexandrescu)
<div id=quickindex></div>
*/

module std.complex;

import std.conv, std.math, std.stdio;

/**
Representation choices for the $(D Complex) type. Cartesian
representation is better when using additive operations and when real
and imaginary part are to be manipulated separately. Polar
representation is more advantageous when using multiplicative
operations and when modulus and angle are to be manipulated
separately.
*/

enum Representation
{
    /// Use Cartesian representation.
    cartesian,
    /// Use polar representation.
    polar
}

/**
Complex type parameterized with the numeric type (e.g. $(D float), $(D
double), or $(D real)) and the representation.
*/

struct Complex(Num, Representation rep = Representation.cartesian)
{
    version(ddoc) {
        Num getAngle();
    }
    static if (rep == Representation.cartesian)
    {
        Num re, im;
        Num getRe_() { return re; }
        Num getIm_() { return im; }
        Num getModulus_() { return sqrt(re * re + im * im); }
        Num getAngle_() { return atan2(im, re); }
    }
    else
    {
        Num modulus, angle;
        Num getRe_() { return modulus * cos(angle); }
        Num getIm_() { return modulus * sin(angle); }
        Num getModulus_() { return modulus; }
        Num getAngle_() { return angle; }
    }    
/** Gets the real component of the number. Might involve a
calculation, subject to representation. Use $(D x.re) to statically
enforce Cartesian representation.
*/
    alias getRe_ getRe;
/**
Gets the imaginary component of the number. Might involve a
calculation, subject to representation. Use $(D x.im) to statically
enforce Cartesian representation.
*/
    alias getIm_ getIm;
/**
Gets the modulus of the number. Might involve a calculation, subject
to representation. Use $(D x.modulus) to statically enforce polar
representation.
*/
    alias getModulus_ getModulus;
/**
Gets the angle of the number. Might involve a calculation, subject to
representation. Use $(D x.angle) to statically enforce polar
representation.
*/
    alias getAngle_ getAngle;
}

unittest
{
    // Complex!(double, Representation.cartesian) c1 = { 1, 1 };
    // auto c2 = Complex!(double, Representation.polar)(sqrt(2.0), PI / 4);
    // writeln(c2.getRe);
    // assert(approxEqual(c1.getRe, c2.getRe),
    //         text(c1.getRe, " != ", c2.getRe));
    // assert(approxEqual(c1.getIm, c2.getIm));
}
