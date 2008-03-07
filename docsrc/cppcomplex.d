Ddoc

$(COMMUNITY D Complex Types and C++ std::complex,

	How do D's complex numbers compare with C++'s std::complex class?

<h3>Syntactical Aesthetics</h3>

	In C++, the complex types are:

$(CCODE
complex&lt;float&gt;
complex&lt;double&gt;
complex&lt;long double&gt;
)

	C++ has no distinct imaginary type. D has 3 complex types and 3
	imaginary types:

------------
cfloat
cdouble
creal
ifloat
idouble
ireal
------------

	A C++ complex number can interact with an arithmetic literal, but
	since there is no imaginary type, imaginary numbers can only be
	created with the constructor syntax:

$(CCODE
complex&lt;long double&gt; a = 5;		// a = 5 + 0i
complex&lt;long double&gt; b(0,7);		// b = 0 + 7i
c = a + b + complex&lt;long double&gt;(0,7);	// c = 5 + 14i
)

	In D, an imaginary numeric literal has the 'i' suffix.
	The corresponding code would be the more natural:

------------
creal a = 5;		// a = 5 + 0i
ireal b = 7i;		// b = 7i
c = a + b + 7i;		// c = 5 + 14i
------------

	For more involved expressions involving constants:

------------
c = (6 + 2i - 1 + 3i) / 3i;
------------

	In C++, this would be:

$(CCODE
c = (complex&lt;double&gt;(6,2) + complex&lt;double&gt;(-1,3)) / complex&lt;double&gt;(0,3);
)

	or if an imaginary class were added to C++ it might be:

$(CCODE
c = (6 + imaginary&lt;double&gt;(2) - 1 + imaginary&lt;double&gt;(3)) / imaginary&lt;double&gt;(3);
)

	In other words, an imaginary number $(I nn) can be represented with
	just $(I nn)i rather than writing a constructor call
	complex&lt;long double&gt;(0,$(I nn)).

<h3>Efficiency</h3>

	The lack of an imaginary type in C++ means that operations on
	imaginary numbers wind up with a lot of extra computations done
	on the 0 real part. For example, adding two imaginary numbers
	in D is one add:

------------
ireal a, b, c;
c = a + b;
------------

	In C++, it is two adds, as the real parts get added too:

$(CCODE
c.re = a.re + b.re;
c.im = a.im + b.im;
)

	Multiply is worse, as 4 multiplies and two adds are done instead of
	one multiply:

$(CCODE
c.re = a.re * b.re - a.im * b.im;
c.im = a.im * b.re + a.re * b.im;
)

	Divide is the worst - D has one divide, whereas C++ implements
	complex division with typically one comparison, 3 divides,
	3 multiplies and 3 additions:

$(CCODE
if (fabs(b.re) < fabs(b.im))
{
    r = b.re / b.im;
    den = b.im + r * b.re;
    c.re = (a.re * r + a.im) / den;
    c.im = (a.im * r - a.re) / den;
}
else
{
    r = b.im / b.re;
    den = b.re + r * b.im;
    c.re = (a.re + r * a.im) / den;
    c.im = (a.im - r * a.re) / den;
}
)

	To avoid these efficiency concerns in C++, one could simulate
	an imaginary number using a double. For example, given the D:

------------
cdouble c;
idouble im;
c *= im;
------------

	it could be written in C++ as:

$(CCODE
complex&lt;double&gt; c;
double im;
c = complex&lt;double&gt;(-c.imag() * im, c.real() * im);
)

	but then the advantages of complex being a library type integrated
	in with the arithmetic operators have been lost.

<h3>Semantics</h3>

	Worst of all, the lack of an imaginary type can cause the wrong
	answer to be inadvertently produced.
	To quote <a href="http://www.cs.berkeley.edu/~wkahan/">
	Prof. Kahan</a>:

	$(BLOCKQUOTE 
	"A streamline goes astray when the complex functions SQRT and LOG
	are implemented, as is necessary in Fortran and in libraries
	currently distributed with C/C++ compilers, in a way that
	disregards the sign of 0.0 in IEEE 754 arithmetic and consequently
	violates identities like SQRT( CONJ( Z ) ) = CONJ( SQRT( Z ) ) and
	LOG( CONJ( Z ) ) = CONJ( LOG( Z ) ) whenever the COMPLEX variable Z
	takes negative real values. Such anomalies are unavoidable if
	Complex Arithmetic operates on pairs (x, y) instead of notional
	sums x + i*y of real and imaginary
	variables. The language of pairs is $(I incorrect) for Complex
	Arithmetic; it needs the Imaginary type."
	)

	The semantic problems are:

	$(UL 
	$(LI Consider the formula (1 - infinity*$(I i)) * $(I i) which
	should produce (infinity + $(I i)). However, if instead the second
	factor is (0 + $(I i)) rather than just $(I i), the result is
	(infinity + NaN*$(I i)), a spurious NaN was generated.
	)

	$(LI A distinct imaginary type preserves the sign of 0, necessary
	for calculations involving branch cuts.
	)
	)

	Appendix G of the C99 standard has recommendations for dealing
	with this problem. However, those recommendations are not part
	of the C++98 standard, and so cannot be portably relied upon.

<h3>References</h3>

	<a href="http://www.cs.berkeley.edu/~wkahan/JAVAhurt.pdf">
	How Java's Floating-Point Hurts Everyone Everywhere</a>
	Prof. W. Kahan and Joseph D. Darcy
	<p>

	<a href="http://www.cs.berkeley.edu/~wkahan/Curmudge.pdf">
	The Numerical Analyst as Computer Science Curmudgeon</a>
	by Prof. W. Kahan
	<p>

	"Branch Cuts for Complex Elementary Functions,
	or Much Ado About Nothing's Sign Bit" 
	by W. Kahan, ch.<br>
	7 in The State of the Art in Numerical Analysis (1987)
	ed. by M. Powell and A. Iserles for Oxford U.P.

)

Macros:
	TITLE=D Complex Types vs C++ std::complex
	WIKI=CPPcomplex

