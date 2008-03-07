Ddoc

$(SPEC_S Arrays,

	$(P There are four kinds of arrays:)

    $(TABLE1
	$(TR $(TD int* p;)	$(TD Pointers to data))

	$(TR $(TD int[3] s;)	$(TD Static arrays))

	$(TR $(TD int[] a;)	$(TD Dynamic arrays))

	$(TR $(TD int[char[]] x;) $(TD <a href="#associative">Associative arrays</a>))
    )

<h3>Pointers</h3>

---------
int* p;
---------

	$(P These are simple pointers to data, analogous to C pointers.
	Pointers are provided for interfacing with C and for
	specialized systems work.
	There
	is no length associated with it, and so there is no way for the
	compiler or runtime to do bounds checking, etc., on it.
	Most conventional uses for pointers can be replaced with
	dynamic arrays, $(TT out) and $(TT ref) parameters,
	and reference types.
	)

<h3>Static Arrays</h3>

---------
int[3] s;
---------

	$(P These are analogous to C arrays. Static arrays are distinguished
	by having a length fixed at compile time.
	)

	$(P The total size of a static array cannot exceed 16Mb.
	A dynamic array should be used instead for such large arrays.
	)

	$(P A static array with a dimension of 0 is allowed, but no
	space is allocated for it. It's useful as the last member
	of a variable length struct, or as the degenerate case of
	a template expansion.
	)

<h3>Dynamic Arrays</h3>

---------
int[] a;
---------

	$(P Dynamic arrays consist of a length and a pointer to the array data.
	Multiple dynamic arrays can share all or parts of the array data.
	)

<h2>Array Declarations</h2>

	$(P There are two ways to declare arrays, prefix and postfix.
	The prefix form is the preferred method, especially for
	non-trivial types.
	)

<h4>Prefix Array Declarations</h4>

	$(P Prefix declarations appear before the identifier being
	declared and read right to left, so:
	)

---------
int[] a;	// dynamic array of ints
int[4][3] b;	// array of 3 arrays of 4 ints each
int[][5] c;	// array of 5 dynamic arrays of ints.
int*[]*[3] d;	// array of 3 pointers to dynamic arrays of pointers to ints
int[]* e;	// pointer to dynamic array of ints
---------


<h4>Postfix Array Declarations</h4>

	$(P Postfix declarations appear after the identifier being
	declared and read left to right.
	Each group lists equivalent declarations:
	)

---------
// dynamic array of ints
int[] a;
int a[];

// array of 3 arrays of 4 ints each
int[4][3] b;
int[4] b[3];
int b[3][4];

// array of 5 dynamic arrays of ints.
int[][5] c;
int[] c[5];
int c[5][];

// array of 3 pointers to dynamic arrays of pointers to ints
int*[]*[3] d;
int*[]* d[3];
int* (*d[3])[];

// pointer to dynamic array of ints
int[]* e;
int (*e)[];
---------

	$(P $(B Rationale:) The postfix form matches the way arrays are
	declared in C and C++, and supporting this form provides an
	easy migration path for programmers used to it.
	)

<h2>Usage</h2>

	$(P There are two broad kinds of operations to do on an array -
	affecting
	the handle to the array,
	and affecting the contents of the array.
	C only has
	operators to affect the handle. In D, both are accessible.
	)

	$(P The handle to an array is specified by naming the array, as
	in p, s or a:
	)

---------
int* p;
int[3] s;
int[] a;

int* q;
int[3] t;
int[] b;

p = q;		// p points to the same thing q does.
p = s;		// p points to the first element of the array s.
p = a;		// p points to the first element of the array a.

s = ...;	// error, since s is a compiled in static
		// reference to an array.

a = p;		// error, since the length of the array pointed
		// to by p is unknown
a = s;		// a is initialized to point to the s array
a = b;		// a points to the same array as b does
---------

<h2><a name="slicing">Slicing</a></h2>

	$(P $(I Slicing) an array means to specify a subarray of it.
	An array slice does not copy the data, it is only another
	reference to it.
	For example:
	)

---------
int[10] a;	// declare array of 10 ints
int[] b;

b = a[1..3];	// a[1..3] is a 2 element array consisting of
		// a[1] and a[2]
foo(b[1]);	// equivalent to foo(0)
a[2] = 3;
foo(b[1]);	// equivalent to foo(3)
---------

	$(P The [] is shorthand for a slice of the entire array.
	For example, the assignments to b:
	)

---------
int[10] a;
int[] b;

b = a;
b = a[];
b = a[0 .. a.length];
---------

	$(P are all semantically equivalent.
	)

	$(P Slicing
	is not only handy for referring to parts of other arrays,
	but for converting pointers into bounds-checked arrays:
	)

---------
int* p;
int[] b = p[0..8];
---------

<h2>Array Copying</h2>

	$(P When the slice operator appears as the lvalue of an assignment
	expression, it means that the contents of the array are the
	target of the assignment rather than a reference to the array.
	Array copying happens when the lvalue is a slice, and the rvalue
	is an array of or pointer to the same type.
	)

---------
int[3] s;
int[3] t;

s[] = t;		// the 3 elements of t[3] are copied into s[3]
s[] = t[];		// the 3 elements of t[3] are copied into s[3]
s[1..2] = t[0..1];	// same as s[1] = t[0]
s[0..2] = t[1..3];	// same as s[0] = t[1], s[1] = t[2]
s[0..4] = t[0..4];	// error, only 3 elements in s
s[0..2] = t;		// error, different lengths for lvalue and rvalue
---------

	$(P Overlapping copies are an error:)

---------
s[0..2] = s[1..3];	// error, overlapping copy
s[1..3] = s[0..2];	// error, overlapping copy
---------

	$(P Disallowing overlapping makes it possible for more aggressive
	parallel code optimizations than possible with the serial
	semantics of C.
	)

<h2>Array Setting</h2>

	$(P If a slice operator appears as the lvalue of an assignment
	expression, and the type of the rvalue is the same as the element
	type of the lvalue, then the lvalue's array contents
	are set to the rvalue.
	)

---------
int[3] s;
int* p;

s[] = 3;		// same as s[0] = 3, s[1] = 3, s[2] = 3
p[0..2] = 3;		// same as p[0] = 3, p[1] = 3
---------

<h2>Array Concatenation</h2>

	$(P The binary operator ~ is the $(I cat) operator. It is used
	to concatenate arrays:
	)

---------
int[] a;
int[] b;
int[] c;

a = b ~ c;	// Create an array from the concatenation of the
		// b and c arrays
---------

	$(P Many languages overload the + operator to mean concatenation.
	This confusingly leads to, does:
	)

---------
"10" + 3
---------

	$(P produce the number 13 or the string "103" as the result? It isn't
	obvious, and the language designers wind up carefully writing rules
	to disambiguate it - rules that get incorrectly implemented,
	overlooked, forgotten, and ignored. It's much better to have + mean
	addition, and a separate operator to be array concatenation.
	)

	$(P Similarly, the ~= operator means append, as in:
	)

---------
a ~= b;		// a becomes the concatenation of a and b
---------

	$(P Concatenation always creates a copy of its operands, even
	if one of the operands is a 0 length array, so:
	)

---------
a = b;			// a refers to b
a = b ~ c[0..0];	// a refers to a copy of b
---------


$(COMMENT
<h2>Array Operations</h2>

	$(P $(B Note): Array operations are not implemented.
	)

	$(P In general, (a[n..m] $(I op) e) is defined as:
	)

---------
for (i = n; i < m; i++)
    a[i] $(I op) e;
---------

	$(P So, for the expression:
	)

---------
a[] = b[] + 3;
---------

	$(P the result is equivalent to:)

---------
for (i = 0; i < a.length; i++)
    a[i] = b[i] + 3; 
---------

	$(P When more than one [] operator appears in an expression, the range
	represented by all must match.
	)

---------
a[1..3] = b[] + 3;	// error, 2 elements not same as 3 elements
---------
)


<h2>Pointer Arithmetic</h2>

---------
int[3] abc;			// static array of 3 ints
int[] def = [ 1, 2, 3 ];	// dynamic array of 3 ints

void dibb(int* array)
{
	array[2];		// means same thing as *(array + 2)
	*(array + 2);		// get 3rd element
}

void diss(int[] array)
{
	array[2];		// ok
	*(array + 2);		// error, array is not a pointer
}

void ditt(int[3] array)
{
	array[2];		// ok
	*(array + 2);		// error, array is not a pointer
}
---------

<h2>Rectangular Arrays</h2>

	$(P Experienced FORTRAN numerics programmers know that multidimensional 
	"rectangular" arrays for things like matrix operations are much faster than trying to 
	access them via pointers to pointers resulting from "array of pointers to array" semantics. 
	For example, the D syntax:
	)

---------
double[][] matrix;
---------

	$(P declares matrix as an array of pointers to arrays. (Dynamic arrays are implemented as 
	pointers to the array data.) Since the arrays can have varying sizes (being dynamically 
	sized), this is sometimes called "jagged" arrays. Even worse for optimizing the code, the 
	array rows can sometimes point to each other! Fortunately, D static arrays, while using 
	the same syntax, are implemented as a fixed rectangular layout:
	)

---------
double[3][3] matrix;
---------

	$(P declares a rectangular matrix with 3 rows and 3 columns, all contiguously in memory. In 
	other languages, this would be called a multidimensional array and be declared as:
	)
---------
double matrix[3,3];
---------

<h2>Array Length</h2>

	$(P Within the [ ] of a static or a dynamic array,
	the variable $(B length)
	is implicitly declared and set to the length of the array.
	The symbol $(B $) can also be so used.
	)

---------
int[4] foo;
int[]  bar = foo;
int*   p = &foo[0];

// These expressions are equivalent:
bar[]
bar[0 .. 4]
bar[0 .. $(B length)]
bar[0 .. $(B $)]
bar[0 .. bar.length]

p[0 .. length]		// 'length' is not defined, since p is not an array
bar[0]+length		// 'length' is not defined, out of scope of [ ]

bar[$(B length)-1]	// retrieves last element of the array
---------

<h2>Array Properties</h2>

	$(P Static array properties are:)

    $(TABLE1
	$(TR
	$(TD $(B .sizeof))
	$(TD Returns the array length multiplied by the number of
	bytes per array element.
	)
	)

	$(TR
	$(TD $(B .length))
	$(TD Returns the number of elements in the array.
	This is a fixed quantity for static arrays.
	It is of type $(B size_t).
	)
	)

	$(TR
	$(TD $(B .ptr))
	$(TD Returns a pointer to the first element of the array.
	)
	)

	$(TR
	$(TD $(B .dup))
	$(TD Create a dynamic array of the same size
	and copy the contents of the array into it.
	)
	)

	$(TR
	$(TD $(B .idup))
	$(TD Create a dynamic array of the same size
	and copy the contents of the array into it.
	The copy is typed as being invariant.
	$(I D 2.0 only)
	)
	)

	$(TR
	$(TD $(B .reverse))
	$(TD Reverses in place the order of the elements in the array.
	Returns the array.
	)
	)

	$(TR
	$(TD $(B .sort))
	$(TD Sorts in place the order of the elements in the array.
	Returns the array.
	)
	)

    )

	$(P Dynamic array properties are:)

    $(TABLE1
	$(TR
	$(TD $(B .sizeof))
	$(TD Returns the size of the dynamic array reference,
	which is 8 on 32 bit machines.
	)
	)

	$(TR
	$(TD $(B .length))
	$(TD Get/set number of elements in the array.
	It is of type $(B size_t).
	)
	)

	$(TR
	$(TD $(B .ptr))
	$(TD Returns a pointer to the first element of the array.
	)
	)

	$(TR
	$(TD $(B .dup))
	$(TD Create a dynamic array of the same size
	and copy the contents of the array into it.
	)
	)

	$(TR
	$(TD $(B .idup))
	$(TD Create a dynamic array of the same size
	and copy the contents of the array into it.
	The copy is typed as being invariant.
	$(I D 2.0 only)
	)
	)

	$(TR
	$(TD $(B .reverse))
	$(TD Reverses in place the order of the elements in the array.
	Returns the array.
	)
	)

	$(TR
	$(TD $(B .sort))
	$(TD Sorts in place the order of the elements in the array.
	Returns the array.
	)
	)

    )

	$(P For the $(B .sort) property to work on arrays of class
	objects, the class definition must define the function:
	$(TT int opCmp(Object)). This is used to determine the
	ordering of the class objects. Note that the parameter
	is of type $(TT Object), not the type of the class.)

	$(P For the $(B .sort) property to work on arrays of
	structs or unions, the struct or union definition must
	define the function:
	$(TT int opCmp(S)) or
	$(TT int opCmp(S*)).
	The type $(TT S) is the type of the struct or union.
	This function will determine the sort ordering.
	)

    $(P Examples:)

---------
p.length	// error, length not known for pointer
s.length	// compile time constant 3
a.length	// runtime value

p.dup		// error, length not known
s.dup		// creates an array of 3 elements, copies
		// elements s into it
a.dup		// creates an array of a.length elements, copies
		// elements of a into it
---------

<h3><a name="resize">Setting Dynamic Array Length</a></h3>

	$(P The $(B $(TT .length)) property of a dynamic array can be set
	as the lvalue of an = operator:
	)

---------
array.length = 7;
---------

	$(P This causes the array to be reallocated in place, and the existing
	contents copied over to the new array. If the new array length is
	shorter,
	only enough are copied to fill the new array. If the new array length
	is longer, the remainder is filled out with the default initializer.
	)

	$(P To maximize efficiency, the runtime always tries to resize the
	array in place to avoid extra copying. It will always do a copy
	if the new size is larger and the array was not allocated via the
	new operator or a previous
	resize operation.
	)

	$(P This means that if there is an array slice immediately following the
	array being resized, the resized array could overlap the slice; i.e.:
	)

---------
char[] a = new char[20];
char[] b = a[0..10];
char[] c = a[10..20];

b.length = 15;	// always resized in place because it is sliced
		// from a[] which has enough memory for 15 chars
b[11] = 'x';	// a[11] and c[1] are also affected

a.length = 1;
a.length = 20;	// no net change to memory layout

c.length = 12;	// always does a copy because c[] is not at the
		// start of a gc allocation block
c[5] = 'y';	// does not affect contents of a[] or b[]

a.length = 25;	// may or may not do a copy
a[3] = 'z';	// may or may not affect b[3] which still overlaps
		// the old a[3]
---------

	$(P To guarantee copying behavior, use the .dup property to ensure
	a unique array that can be resized.
	)

	$(P These issues also apply to concatenating arrays with the ~ and ~=
	operators.
	)

	$(P Resizing a dynamic array is a relatively expensive operation.
	So, while the following method of filling an array:
	)

---------
int[] array;
while (1)
{   c = getinput();
    if (!c)
       break;
    array.length = array.length + 1;
    array[array.length - 1] = c;
}
---------

	$(P will work, it will be inefficient. A more practical
	approach would be to minimize the number of resizes:
	)

---------
int[] array;
array.length = 100;        // guess
for (i = 0; 1; i++)
{   c = getinput();
     if (!c)
	break;
     if (i == array.length)
	array.length = array.length * 2;
     array[i] = c;
}
array.length = i;
---------

	$(P Picking a good initial guess is an art, but you usually can
	pick a value covering 99% of the cases.
	For example, when gathering user
	input from the console - it's unlikely to be longer than 80.
	)

<h3>Functions as Array Properties</h3>

	$(P If the first parameter to a function is an array, the
	function can be called as if it were a property of the array:
	)

---
int[] array;
void foo(int[] a, int x);

foo(array, 3);
array.foo(3);	// means the same thing
---

<h2><a name="bounds">Array Bounds Checking</a></h2>

	$(P It is an error to index an array with an index that is less than
	0 or greater than or equal to the array length. If an index is
	out of bounds, an ArrayBoundsError exception is raised if detected
	at runtime, and an error if detected at compile time.
	A program may not rely on array bounds checking happening, for
	example, the following program is incorrect:
	)

---------
try
{
    for (i = 0; ; i++)
    {
	array[i] = 5;
    }
}
catch (ArrayBoundsError)
{
    // terminate loop
}
---------

	The loop is correctly written:

---------
for (i = 0; i < array.length; i++)
{
    array[i] = 5;
}
---------

	$(P $(B Implementation Note:) Compilers should attempt to detect
	array bounds errors at compile time, for example:
	)

---------
int[3] foo;
int x = foo[3];		// error, out of bounds
---------

	$(P Insertion of array bounds checking code at runtime should be
	turned on and off
	with a compile time switch.
	)

<h2>Array Initialization</h2>

<h3>Default Initialization</h3>

	$(UL 
	$(LI Pointers are initialized to $(B null).)
	$(LI Static array contents are initialized to the default
	initializer for the array element type.)
	$(LI Dynamic arrays are initialized to having 0 elements.)
	$(LI Associative arrays are initialized to having 0 elements.)
	)

<h3>Void Initialization</h3>

	$(P Void initialization happens when the $(I Initializer) for
	an array is $(B void). What it means is that no initialization
	is done, i.e. the contents of the array will be undefined.
	This is most useful as an efficiency optimization.
	Void initializations are an advanced technique and should only be used
	when profiling indicates that it matters.
	)

<h3>Static Initialization of Static Arrays</h3>

	$(P Static initalizations are supplied by a list of array
	element values enclosed in [ ]. The values can be optionally
	preceded by an index and a :.
	If an index is not supplied, it is set to the previous index
	plus 1, or 0 if it is the first value.
	)

---------
int[3] a = [ 1:2, 3 ];		// a[0] = 0, a[1] = 2, a[2] = 3
---------

	$(P This is most handy when the array indices are given by enums:)

---------
enum Color { red, blue, green };

int value[Color.max + 1] = [ Color.blue:6, Color.green:2, Color.red:5 ];
---------

	$(P These arrays are static when they appear in global scope.
	Otherwise, they need to be marked with $(B const) or $(B static)
	storage classes to make them static arrays.)


<h2>Special Array Types</h2>

<a name="strings"><h3>Strings</h3></a>

	$(P A string is
	an array of characters. String literals are just
	an easy way to write character arrays.
	String literals are immutable (read only).
	)

$(V1
---------
char[] str;
char[] str1 = "abc";
str[0] = 'b';        // error, "abc" is read only, may crash
---------
)
$(V2
---------
char[] str1 = "abc";             // error, "abc" is not mutable
char[] str2 = "abc".dup;         // ok, make mutable copy
invariant(char)[] str3 = "abc";  // ok
---------
)
	$(P char[] strings are in UTF-8 format.
	wchar[] strings are in UTF-16 format.
	dchar[] strings are in UTF-32 format.
	)

	$(P Strings can be copied, compared, concatenated, and appended:)

---------
str1 = str2;
if (str1 < str3) ...
func(str3 ~ str4);
str4 ~= str1;
---------

	$(P with the obvious semantics. Any generated temporaries get cleaned up
	by the garbage collector (or by using alloca()). Not only that,
	this works with any 
	array not just a special String array.
	)

	$(P A pointer to a char can be generated:
	)

---------
char* p = &str[3];	// pointer to 4th element
char* p = str;		// pointer to 1st element
---------

	$(P Since strings, however, are not 0 terminated in D,
	when transferring a pointer
	to a string to C, add a terminating 0:
	)

---------
str ~= "\0";
---------

	$(P or use the function $(TT std.string.toStringz).)

	$(P The type of a string is determined by the semantic phase of
	compilation. The type is 
	one of: char[], wchar[], dchar[], and is determined by
	implicit conversion rules. 
	If there are two equally applicable implicit conversions,
	the result is an error. To 
	disambiguate these cases, a cast or a postfix of $(B c),
	$(B w) or $(B d) can be used:
	)

---------
cast(wchar [])"abc"	// this is an array of wchar characters
"abc"w			// so is this
---------

	$(P String literals that do not have a postfix character and that
	have not been cast can be implicitly converted between char[],
	wchar[], and dchar[] as necessary.
	)

---------
char c;
wchar w;
dchar d;

c = 'b';		// c is assigned the character 'b'
w = 'b';		// w is assigned the wchar character 'b'
w = 'bc';		// error - only one wchar character at a time
w = "b"[0];		// w is assigned the wchar character 'b'
w = \r[0];		// w is assigned the carriage return wchar character
d = 'd';		// d is assigned the character 'd'
---------

<h4>C's printf() and Strings</h4>

	$(P $(B printf()) is a C function and is not part of D. $(B printf())
	will print C strings, which are 0 terminated. There are two ways
	to use $(B printf()) with D strings. The first is to add a
	terminating 0, and cast the result to a char*:
	)

---------
str ~= "\0";
printf("the string is '%s'\n", cast(char*)str);
---------

	$(P or:)

---------
import std.string;
printf("the string is '%s'\n", std.string.toStringz(str));
---------

	$(P String literals already have a 0 appended to them, so
	can be used directly:)

-----------
printf("the string is '%s'\n", cast(char*)"string literal");
-----------

	$(P So, why does the first string literal to printf not need
	the cast? The first parameter is prototyped as a char*, and
	a string literal can be implicitly cast to a char*.
	The rest of the arguments to printf, however, are variadic
	(specified by ...),
	and a string literal is passed as a (length,pointer) combination
	to variadic parameters.)

	$(P The second way is to use the precision specifier. The way D arrays
	are laid out, the length comes first, so the following works:)

---------
printf("the string is '%.*s'\n", str);
---------

	$(P The best way is to use std.stdio.writefln, which can handle
	D strings:)

---------
import std.stdio;
writefln("the string is '%s'", str);
---------

<h3>Implicit Conversions</h3>

	$(P A pointer $(TT $(I T)*) can be implicitly converted to
	one of the following:)

	$(UL
	$(LI $(TT void*))
	)

	$(P A static array $(TT $(I T)[$(I dim)]) can be implicitly
	converted to
	one of the following:
	)

	$(UL 
	$(LI $(TT $(I T)[]))
	$(LI $(TT $(I U)[]))
	$(LI $(TT void[]))
	)

	$(P A dynamic array $(TT $(I T)[]) can be implicitly converted to
	one of the following:
	)

	$(UL 
	$(LI $(TT $(I U)[]))
	$(LI $(TT void[]))
	)

	$(P Where $(I U) is a base class of $(I T).)

<hr>
<h1><a name="associative">Associative Arrays</a></h1>

	$(P Associative arrays have an index that is not necessarily an integer,
	and can be sparsely populated. The index for an associative array
	is called the $(I key), and its type is called the $(I KeyType).
	)

	$(P Associative arrays are declared by placing the $(I KeyType)
	within the [] of an array declaration:
	)

---------
int[char[]] b;		// associative array b of ints that are
			// indexed by an array of characters.
			// The $(I KeyType) is char[]
b["hello"] = 3;		// set value associated with key "hello" to 3
func(b["hello"]);	// pass 3 as parameter to func()
---------

	$(P Particular keys in an associative array can be removed with the
	remove function:
	)

---------
b.$(B remove)("hello");
---------

	$(P The $(I InExpression) yields a pointer to the value
	if the key is in the associative array, or $(B null) if not:
	)

---------
int* p;
p = ("hello" $(B in) b);
if (p != $(B null))
	...
---------

	$(P $(I KeyType)s cannot be functions or voids.
	)

	$(P If the $(I KeyType) is a struct type, a default mechanism is used
	to compute the hash and comparisons of it based on the binary
	data within the struct value. A custom mechanism can be used
	by providing the following functions as struct members:
	)

---------
uint $(B toHash)();
int $(B opCmp)($(I KeyType)* s);
---------

	$(P For example:)

---------
import std.string;

struct MyString
{
    char[] str;

    uint $(B toHash)()
    {   uint hash;
	foreach (char c; s)
	    hash = (hash * 9) + c;
	return hash;
    }

    int $(B opCmp)(MyString* s)
    {
	return std.string.cmp(this.str, s.str);
    }
}
---------

<h3>Using Classes as the KeyType</h3>

	$(P Classes can be used as the $(I KeyType). For this to work,
	the class definition must override the following member functions
	of class $(TT Object):)

	$(UL
	$(LI $(TT hash_t toHash()))
	$(LI $(TT int opEquals(Object)))
	$(LI $(TT int opCmp(Object)))
	)

	$(P Note that the parameter to $(TT opCmp) and $(TT opEquals) is
	of type
	$(TT Object), not the type of the class in which it is defined.)

	$(P For example:)

---
class Foo
{
    int a, b;

    hash_t toHash() { return a + b; }

    int opEquals(Object o)
    {	Foo f = cast(Foo) o;
	return f && a == foo.a && b == foo.b;
    }

    int opCmp(Object o)
    {	Foo f = cast(Foo) o;
	if (!f)
	    return -1;
	if (a == foo.a)
	    return b - foo.b;
	return a - foo.a;
    }
}
---

	$(P The implementation may use either $(TT opEquals) or $(TT opCmp) or
	both. Care should be taken so that the results of
	$(TT opEquals) and $(TT opCmp) are consistent with each other when
	the class objects are the same or not.)

<h3>Using Structs or Unions as the KeyType</h3>

	$(P Structs or unions can be used as the $(I KeyType). For this to work,
	the struct or union definition must define the following
	member functions:)

	$(UL
	$(LI $(TT hash_t toHash()))
	$(LI $(TT int opEquals(S)) or $(TT int opEquals(S*)))
	$(LI $(TT int opCmp(S)) or $(TT int opCmp(S*)))
	)

	$(P Note that the parameter to $(TT opCmp) and $(TT opEquals)
	can be either the struct or union type, or a pointer to the struct
	or untion type.)

	$(P For example:)

---
struct S
{
    int a, b;

    hash_t toHash() { return a + b; }

    int opEquals(S s)
    {
	return a == s.a && b == s.b;
    }

    int opCmp(S* s)
    {
	if (a == s.a)
	    return b - s.b;
	return a - s.a;
    }
}
---

	$(P The implementation may use either $(TT opEquals) or $(TT opCmp) or
	both. Care should be taken so that the results of
	$(TT opEquals) and $(TT opCmp) are consistent with each other when
	the struct/union objects are the same or not.)

<h3>Properties</h3>

Properties for associative arrays are:

    $(TABLE1

	$(TR
	$(TD $(B .sizeof))
	$(TD Returns the size of the reference to the associative
	array; it is typically 8.
	)
	)

	$(TR
	$(TD $(B .length))
	$(TD Returns number of values in the associative array.
	Unlike for dynamic arrays, it is read-only.
	)
	)

	$(TR
	$(TD $(B .keys))
	$(TD Returns dynamic array, the elements of which are the keys in
	the associative array.
	)
	)

	$(TR
	$(TD $(B .values))
	$(TD Returns dynamic array, the elements of which are the values in
	the associative array.
	)
	)

	$(TR
	$(TD $(B .rehash))
	$(TD Reorganizes the associative array in place so that lookups
	are more efficient. rehash is effective when, for example,
	the program is done loading up a symbol table and now needs
	fast lookups in it.
	Returns a reference to the reorganized array.
	)
	)

    )

<hr>
<h3>Associative Array Example: word count</h3>

---------
import std.file;         // D file I/O
import std.stdio;

int main (char[][] args)
{
    int word_total;
    int line_total;
    int char_total;
    int[char[]] dictionary;

    writefln("   lines   words   bytes file");
    for (int i = 1; i < args.length; ++i)      // program arguments
    {
	char[] input;            // input buffer
	int w_cnt, l_cnt, c_cnt; // word, line, char counts
	int inword;
	int wstart;

	// read file into input[]
	input = cast(char[])std.file.read(args[i]);

	foreach (j, char c; input)
	{
	    if (c == '\n')
		    ++l_cnt;
	    if (c >= '0' && c <= '9')
	    {
	    }
	    else if (c >= 'a' && c <= 'z' ||
		    c >= 'A' && c <= 'Z')
	    {
		if (!inword)
		{
		    wstart = j;
		    inword = 1;
		    ++w_cnt;
		}
	    }
	    else if (inword)
	    {
		char[] word = input[wstart .. j];
		dictionary[word]++;        // increment count for word
		inword = 0;
	    }
	    ++c_cnt;
	}
	if (inword)
	{
	    char[] word = input[wstart .. input.length];
	    dictionary[word]++;
	}
	writefln("%8d%8d%8d %s", l_cnt, w_cnt, c_cnt, args[i]);
	line_total += l_cnt;
	word_total += w_cnt;
	char_total += c_cnt;
    }

    if (args.length > 2)
    {
	writef("-------------------------------------\n%8ld%8ld%8ld total",
		line_total, word_total, char_total);
    }

    writefln("-------------------------------------");
    foreach (word; dictionary.keys.sort)
    {
	writefln("%3d %s", dictionary[word], word);
    }
    return 0;
}
---------

)

Macros:
	TITLE=Arrays
	WIKI=Arrays

