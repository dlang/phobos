Ddoc

$(COMMUNITY Core Language Features vs Library Implementation,


	$(P D offers several capabilities built in to the core language
	that are implemented as libraries in other languages such
	as C++:
	)

	$(OL 
	$(LI Dynamic Arrays)
	$(LI Strings)
	$(LI Associative Arrays)
	$(LI Complex numbers)
	)

	$(P Some consider this as evidence of language bloat, rather than
	a useful feature.
	So why not implement each of these as standardized library types?
	)

	$(P Some general initial observations:
	)

	$(OL 

	$(LI Each of them is heavily used. This means that even small
	improvements in usability are worth reaching for.
	)

	$(LI Being a core language feature means that the compiler can
	issue better and more to the point error messages when a type
	is used incorrectly.
	Library implementations tend to give notoriously obtuse messages
	based on the internal details of those implementations.
	)

	$(LI Library features cannot invent new syntax, new operators,
	or new tokens.
	)

	$(LI Library implementations tend to require a lot of compile
	time processing of the implementation, over and over for each compile,
	that slows down compilation.
	)

	$(LI Library implementations are supposed to provide flexibility
	to the end user. But if they are standardized, standardized to the
	point of the compiler being allowed to recognized them as special
	(the C++ Standard allows this), then they become just as inflexible
	as builtin core features.
	)

	$(LI The ability to define new library types, while having greatly
	advanced in the last few years, still leaves a lot to be desired
	in smoothly integrating it into the existing language.
	Rough edges, clumsy syntax, and odd corner cases abound.
	)

	)

	$(P More specific comments:
	)

$(SECTION2 Dynamic Arrays,

	$(P C++ has builtin core arrays. It's just that they don't work very
	well. Rather than fix them, several different array types were
	created as part of the C++ Standard Template Library, each covering
	a different deficiency in the builtin arrays. These
	include:
	)

	$(UL 
	$(LI $(TT basic_string))
	$(LI $(TT vector))
	$(LI $(TT valarray))
	$(LI $(TT deque))
	$(LI $(TT slice_array))
	$(LI $(TT gslice_array))
	$(LI $(TT mask_array))
	$(LI $(TT indirect_array))
	)

	$(P Fixing the builtin array support means the need for each of these
	variations just evaporates. There's one array type that covers
	it all, only one thing to learn, and no problems getting one array
	type to work with another array type.
	)

	$(P As usual, a builtin type lets us create syntactic sugar for it.
	This starts with having an array literal, and follows with some
	new operators specific to arrays. A library array implementation
	has to make due with overloading existing operators.
	The indexing operator, $(TT a[i]), it shares with C++.
	Added are the array concatenation operator $(TT ~), array append operator
	$(TT ~=), array slice operator $(TT a[i..j]),
	and the array vector operator
	$(TT a[]).
	)

	$(P The ~ and ~= concatenation operators resolve a problem that comes
	up when only existing operators can be overloaded. Usually, + is
	pressed into service as concatenation for library array
	implementations. But that winds up precluding having + mean
	array vector addition. Furthermore, concatenation has nothing in
	common with addition, and using the same operator for both is
	confusing.
	)
)


$(SECTION2 Strings,

	$(P A <a href="cppstrings.html">detailed comparison with C++'s std::string</a>.
	)

	$(P C++ has, of course, builtin string support in the form of string
	literals and char arrays. It's just that they suffer from all
	the weaknesses of C++ builtin arrays.
	)

	$(P But after all, what is a string if not an array of characters?
	If the builtin array problems are fixed, doesn't that resolve
	the string problems as well? It does. It seems odd at first that
	D doesn't have a string class, but since manipulating strings
	is nothing more than manipulating arrays of characters, if arrays
	work, there's nothing a class adds to it.
	)

	$(P Furthermore, the oddities resulting from builtin string literals
	not being of the same type as the library string class type go
	away.
	)
)


$(SECTION2 Associative Arrays,

	$(P The main benefit for this is, once again, syntactic sugar.
	An associative array keying off of a type $(TT T) and storing an
	$(TT int) value is naturally written
	as:
	)

---------------
int[T] foo;
---------------

	$(P rather than:
	)

---------------
import std.associativeArray;
...
std.associativeArray.AA!(T, int) foo;
---------------

	$(P Builtin associative arrays also offer the possibility of having
	associative array literals, which are an often requested additional
	feature.
	)
)


$(SECTION2 Complex Numbers,

	$(P A $(LINK2 cppcomplex.html, detailed comparison with C++'s std::complex).
	)

	$(P The most compelling reason is compatibility with C's imaginary
	and complex floating point types.
	Next, is the ability to have imaginary floating point literals.
	Isn't:
	)

---------------
c = (6 + 2i - 1 + 3i) / 3i;
---------------

	$(P far preferable than writing:
	)

---------------
c = (complex!(double)(6,2) + complex!(double)(-1,3)) / complex!(double)(0,3);
---------------

	$(P ? It's no contest.
	)
)

)

Macros:
	TITLE=D Builtin Rationale
	WIKI=builtins

