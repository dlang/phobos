Ddoc

$(SPEC_S Floating Point,

<h3>Floating Point Intermediate Values</h3>

	$(P On many computers, greater
	precision operations do not take any longer than lesser
	precision operations, so it makes numerical sense to use
	the greatest precision available for internal temporaries.
	The philosophy is not to dumb down the language to the lowest
	common hardware denominator, but to enable the exploitation
	of the best capabilities of target hardware.
	)

	$(P For floating point operations and expression intermediate values,
	a greater precision can be used than the type of the
	expression.
	Only the minimum precision is set by the types of the
	operands, not the maximum. $(B Implementation Note:) On Intel
	x86 machines, for example,
	it is expected (but not required) that the intermediate
	calculations be done to the full 80 bits of precision
	implemented by the hardware.
	)

	$(P It's possible that, due to greater use of temporaries and
	common subexpressions, optimized code may produce a more
	accurate answer than unoptimized code.
	)

	$(P Algorithms should be written to work based on the minimum
	precision of the calculation. They should not degrade or
	fail if the actual precision is greater. Float or double types,
	as opposed to the real (extended) type, should only be used for:
	)

	$(UL
	    $(LI reducing memory consumption for large arrays)
	    $(LI when speed is more important than accuracy)
	    $(LI data and function argument compatibility with C)
	)

<h3>Floating Point Constant Folding</h3>

	$(P Regardless of the type of the operands, floating point
	constant folding is done in $(B real) or greater precision.
	It is always done following IEEE 754 rules and round-to-nearest
	is used.)

	$(P Floating point constants are internally represented in
	the implementation in at least $(B real) precision, regardless
	of the constant's type. The extra precision is available for
	constant folding. Committing to the precision of the result is
	done as late as possible in the compilation process. For example:)

---
const float f = 0.2f;
writefln(f - 0.2);
---
	$(P will print 0. A non-const static variable's value cannot be
	propagated at compile time, so:)

---
static float f = 0.2f;
writefln(f - 0.2);
---
	$(P will print 2.98023e-09. Hex floating point constants can also
	be used when specific floating point bit patterns are needed that
	are unaffected by rounding. To find the hex value of 0.2f:)

---
import std.stdio;

void main()
{
    writefln("%a", 0.2f);
}
---
	$(P which is 0x1.99999ap-3. Using the hex constant:)

---
const float f = 0x1.99999ap-3f;
writefln(f - 0.2);
---

	$(P prints 2.98023e-09.)

	$(P Different compiler settings, optimization settings,
	and inlining settings can affect opportunities for constant
	folding, therefore the results of floating point calculations may differ
	depending on those settings.)

<h3>Complex and Imaginary types</h3>

	$(P In existing languages, there is an astonishing amount of effort expended in trying to jam a 
	complex type onto existing type definition facilities: templates, structs, operator 
	overloading, etc., and it all usually ultimately fails. It fails because the semantics of 
	complex operations can be subtle, and it fails because the compiler doesn't know what the 
	programmer is trying to do, and so cannot optimize the semantic implementation.
	)

	$(P This is all done to avoid adding a new type. Adding a new type means that the compiler 
	can make all the semantics of complex work "right". The programmer then can rely on a 
	correct (or at least fixable <g>) implementation of complex.
	)

	$(P Coming with the baggage of a complex type is the need for an imaginary type. An 
	imaginary type eliminates some subtle semantic issues, and improves performance by not 
	having to perform extra operations on the implied 0 real part.
	)

	$(P Imaginary literals have an i suffix:
	)

------
ireal j = 1.3i;
------

	$(P There is no particular complex literal syntax, just add a real and
	imaginary type:
	)

------
cdouble cd = 3.6 + 4i;
creal c = 4.5 + 2i;
------

	$(P Complex, real and imaginary numbers have two properties:
	)

<pre>
.re	get real part (0 for imaginary numbers)
.im	get imaginary part as a real (0 for real numbers)
</pre>

	$(P For example:
	)

<pre>
cd.re		is 4.5 double
cd.im		is 2 double
c.re		is 4.5 real
c.im		is 2 real
j.im		is 1.3 real
j.re		is 0 real
</pre>

<h3>Rounding Control</h3>

	$(P IEEE 754 floating point arithmetic includes the ability to set 4
	different rounding modes. 
	These are accessible via the functions in std.c.fenv.
	)

<h3>Exception Flags</h3>

	$(P IEEE 754 floating point arithmetic can set several flags based on what
	happened with a 
	computation:)

	$(TABLE
	$(TR $(TD FE_INVALID))
	$(TR $(TD FE_DENORMAL))
	$(TR $(TD FE_DIVBYZERO))
	$(TR $(TD FE_OVERFLOW))
	$(TR $(TD FE_UNDERFLOW))
	$(TR $(TD FE_INEXACT))
	)

	$(P These flags can be set/reset via the functions in std.c.fenv.)

<h3>Floating Point Comparisons</h3>

	$(P In addition to the usual &lt; &lt;= &gt; &gt;= == != comparison
	operators, D adds more that are 
	specific to floating point. These are
	!&lt;&gt;=
	&lt;&gt;
	&lt;&gt;=
	!&lt;=
	!&lt;
	!&gt;=
	!&gt;
	!&lt;&gt;
	and match the semantics for the 
	NCEG extensions to C.
	See $(LINK2 expression.html#floating_point_comparisons, Floating point comparisons).
	)
)

Macros:
	TITLE=Floating Point
	WIKI=Float

