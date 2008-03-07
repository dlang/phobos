Ddoc

$(SPEC_S Portability Guide,

	$(P It's good software engineering practice to minimize gratuitous
	portability problems in the code.
	Techniques to minimize potential portability problems are:
	)

	$(UL 

	$(LI The integral and floating type sizes should be considered as
	minimums.
	Algorithms should be designed to continue to work properly if the
	type size increases.)

	$(LI Floating point computations can be carried out at a higher
	precision than the size of the floating point variable can hold.
	Floating point algorithms should continue to work properly if
	precision is arbitrarily increased.)

	$(LI Avoid depending on the order of side effects in a computation
	that may get reordered by the compiler. For example:

-------
a + b + c
-------

	$(P can be evaluated as (a + b) + c, a + (b + c), (a + c) + b, (c + b) + a,
	etc. Parentheses control operator precedence, parentheses do not
	control order of evaluation.
	)

	$(P Function parameters can be evaluated either left to right
	or right to left, depending on the particular calling conventions
	used.
	)

	$(P If the operands of an associative operator + or * are floating
	point values, the expression is not reordered.
	)
	)

	$(LI Avoid dependence on byte order; i.e. whether the CPU
	is big-endian or little-endian.)

	$(LI Avoid dependence on the size of a pointer or reference being
	the same size as a particular integral type.)

	$(LI If size dependencies are inevitable, put an $(TT assert) in
	the code to verify it:

-------
assert(int.sizeof == (int*).sizeof);
-------
	)
	)

<h2>32 to 64 Bit Portability</h2>

	$(P 64 bit processors and operating systems are here.
	With that in mind:
	)

	$(UL 

	$(LI Integral types will remain the same sizes between
	32 and 64 bit code.)

	$(LI Pointers and object references will increase in size
	from 4 bytes to 8 bytes going from 32 to 64 bit code.)

	$(LI Use $(B size_t) as an alias for an unsigned integral
	type that can span the address space.
	Array indices should be of type $(B size_t).)

	$(LI Use $(B ptrdiff_t) as an alias for a signed integral
	type that can span the address space.
	A type representing the difference between two pointers
	should be of type $(B ptrdiff_t).)

	$(LI The $(B .length), $(B .size), $(B .sizeof), $(B .offsetof)
	and $(B .alignof)
	properties will be of type $(B size_t).)

	)

<h2>Endianness</h2>

	$(P Endianness refers to the order in which multibyte types
	are stored. The two main orders are $(I big endian) and
	$(I little endian).
	The compiler predefines the version identifier
	$(B BigEndian) or $(B LittleEndian) depending on the order
	of the target system.
	The x86 systems are all little endian.
	)

	$(P The times when endianness matters are:)

	$(UL
	$(LI When reading data from an external source (like a file)
	written in a different
	endian format.)
	$(LI When reading or writing individual bytes of a multibyte
	type like $(B long)s or $(B double)s.)
	)

<h2>OS Specific Code</h2>

	$(P System specific code is handled by isolating the differences into
	separate modules. At compile time, the correct system specific
	module is imported.
	)

	$(P Minor differences can be handled by constant defined in a system
	specific import, and then using that constant in an
	$(I IfStatement) or $(I StaticIfStatement).
	)
)

Macros:
	TITLE=Portability
	WIKI=Portability

