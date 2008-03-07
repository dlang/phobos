Ddoc

$(SPEC_S Properties,

	$(P Every type and expression has properties that can be queried:)

$(TABLE1
$(TR $(TH Expression)	$(TH Value))
$(TR $(TD int.sizeof)	$(TD yields 4))
$(TR $(TD float.nan)	$(TD yields the floating point nan (Not A Number) value))
$(TR $(TD (float).nan)	$(TD yields the floating point nan value))
$(TR $(TD (3).sizeof)	$(TD yields 4 (because 3 is an int)))
$(TR $(TD 2.sizeof)	$(TD syntax error, since "2." is a floating point number))
$(TR $(TD int.init)	$(TD default initializer for int's))
$(TR $(TD int.mangleof)	$(TD yields the string "i"))
$(TR $(TD int.stringof)	$(TD yields the string "int"))
$(TR $(TD (1+2).stringof)	$(TD yields the string "1 + 2"))
)


$(SECTION2 Properties for All Types,

$(TABLE1
$(TR $(TH Property)	$(TH Description))
$(TR $(TD .init)	$(TD initializer))
$(TR $(TD .sizeof)	$(TD size in bytes (equivalent to C's sizeof(type))))
$(TR $(TD .alignof)	$(TD alignment size))
$(TR $(TD .mangleof)	$(TD string representing the 'mangled' representation of the type))
$(TR $(TD .stringof)	$(TD string representing the source representation of the type))
)

)

$(SECTION2 Properties for Integral Types,

$(TABLE1
$(TR $(TH Property)	$(TH Description))
$(TR $(TD .init)	$(TD initializer (0)))
$(TR $(TD .max)		$(TD maximum value))
$(TR $(TD .min)		$(TD minimum value))
)

)

$(SECTION2 Properties for Floating Point Types,

$(TABLE1
$(TR $(TH Property)	$(TH Description))
$(TR $(TD .init)	$(TD initializer (NaN)))
$(TR $(TD .infinity)	$(TD infinity value))
$(TR $(TD .nan)		$(TD NaN value))
$(TR $(TD .dig)		$(TD number of decimal digits of precision))
$(TR $(TD .epsilon)	$(TD smallest increment to the value 1))
$(TR $(TD .mant_dig)	$(TD number of bits in mantissa))
$(TR $(TD .max_10_exp)	$(TD maximum int value such that 10<sup>max_10_exp</sup> is representable))
$(TR $(TD .max_exp)	$(TD maximum int value such that 2<sup>max_exp-1</sup> is representable))
$(TR $(TD .min_10_exp)	$(TD minimum int value such that 10<sup>min_10_exp</sup> is representable as a normalized value))
$(TR $(TD .min_exp)	$(TD minimum int value such that 2<sup>min_exp-1</sup> is representable as a normalized value))
$(TR $(TD .max)		$(TD largest representable value that's not infinity))
$(TR $(TD .min)		$(TD smallest representable normalized value that's not 0))
$(TR $(TD .re)		$(TD real part))
$(TR $(TD .im)		$(TD imaginary part))
)

)

$(SECTION2 .init Property,

	$(P $(B .init) produces a constant expression that is the default
	initializer. If applied to a type, it is the default initializer
	for that type. If applied to a variable or field, it is the
	default initializer for that variable or field.
	For example:
	)

----------------
int a;
int b = 1;
typedef int t = 2;
t c;
t d = cast(t)3;

int.init	// is 0
a.init		// is 0
b.init		// is 1
t.init		// is 2
c.init		// is 2
d.init		// is 3

struct Foo
{
    int a;
    int b = 7;
}

Foo.a.init	// is 0
Foo.b.init	// is 7
----------------
)

$(SECTION2 .stringof Property,

	$(P $(B .stringof) produces a constant string that is the
	source representation of its prefix.
	If applied to a type, it is the string for that type.
	If applied to an expression, it is the source representation
	of that expression. Semantic analysis is not done
	for that expression.
	For example:
	)

----------------
struct Foo { }

enum Enum { RED }

typedef int myint;

void main()
{
    writefln((1+2).stringof);       // "1 + 2"
    writefln(Foo.stringof);         // "Foo"
    writefln(test.Foo.stringof);    // "test.Foo"
    writefln(int.stringof);         // "int"
    writefln((int*[5][]).stringof); // "int*[5][]"
    writefln(Enum.RED.stringof);    // "Enum.RED"
    writefln(test.myint.stringof);  // "test.myint"
    writefln((5).stringof);         // "5"
}
----------------

$(SECTION3 <a name="classproperties">Class and Struct Properties</a>,

	$(P Properties are member functions that can be syntactically treated
	as if they were fields. Properties can be read from or written to.
	A property is read by calling a method with no arguments;
	a property is written by calling a method with its argument
	being the value it is set to.
	)

	$(P A simple property would be:)

----------------
struct Foo
{
    int data() { return m_data; }	// read property

    int data(int value) { return m_data = value; } // write property

  private:
    int m_data;
}
----------------

	$(P To use it:)

----------------
int test()
{
    Foo f;

    f.data = 3;		// same as f.data(3);
    return f.data + 3;	// same as return f.data() + 3;
}
----------------

	$(P The absence of a read method means that the property is write-only.
	The absence of a write method means that the property is read-only.
	Multiple write methods can exist; the correct one is selected using
	the usual function overloading rules.
	)

	$(P In all the other respects, these methods are like any other methods.
	They can be static, have different linkages, be overloaded with
	methods with multiple parameters, have their address taken, etc.
	)

	$(P $(B Note:) Properties currently cannot be the lvalue of an
	$(I op)=, ++, or -- operator.
	)
)
)

)

Macros:
	TITLE=Properties
	 WIKI=Property

