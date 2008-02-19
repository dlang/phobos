Ddoc

$(SPEC_S Traits,

	$(P Traits are extensions to the language to enable
	programs, at compile time, to get at information
	internal to the compiler. This is also known as
	compile time reflection.
	It is done as a special, easily extended syntax (similar
	to Pragmas) so that new capabilities can be added
	as required.
	)

$(GRAMMAR
$(I TraitsExpression):
    $(B __traits) $(B $(LPAREN)) $(I TraitsKeyword) $(B ,) $(I TraitsArguments) $(B $(RPAREN))

$(I TraitsKeyword):
    $(B isAbstractClass)
    $(B isArithmetic)
    $(B isAssociativeArray)
    $(B isFinalClass)
    $(B isFloating)
    $(B isIntegral)
    $(B isScalar)
    $(B isStaticArray)
    $(B isUnsigned)
    $(B isVirtualFunction)
    $(B isAbstractFunction)
    $(B isFinalFunction)
    $(B hasMember)
    $(B getMember)
    $(B getVirtualFunctions)
    $(B classInstanceSize)
    $(B allMembers)
    $(B derivedMembers)
    $(B isSame)
    $(B compiles)

$(I TraitsArguments):
    $(I TraitsArgument)
    $(I TraitsArgument) $(B ,) $(I TraitsArguments)

$(I TraitsArgument):
    $(I AssignExpression)
    $(I Type)
)

$(H2 isArithmetic)

	$(P If the arguments are all either types that are arithmetic types,
	or expressions that are typed as arithmetic types, then $(B true)
	is returned.
	Otherwise, $(B false) is returned.
	If there are no arguments, $(B false) is returned.)

---
import std.stdio;

void main()
{
    int i;
    writefln(__traits(isArithmetic, int));
    writefln(__traits(isArithmetic, i, i+1, int));
    writefln(__traits(isArithmetic));
    writefln(__traits(isArithmetic, int*));
}
---

	$(P Prints:)

$(CONSOLE
true
true
false
false
)

$(H2 isFloating)

	$(P Works like $(B isArithmetic), except it's for floating
	point types (including imaginary and complex types).)

$(H2 isIntegral)

	$(P Works like $(B isArithmetic), except it's for integral
	types (including character types).)

$(H2 isScalar)

	$(P Works like $(B isArithmetic), except it's for scalar
	types.)

$(H2 isUnsigned)

	$(P Works like $(B isArithmetic), except it's for unsigned
	types.)

$(H2 isStaticArray)

	$(P Works like $(B isArithmetic), except it's for static array
	types.)

$(H2 isAssociativeArray)

	$(P Works like $(B isArithmetic), except it's for associative array
	types.)

$(H2 isAbstractClass)

	$(P If the arguments are all either types that are abstract classes,
	or expressions that are typed as abstract classes, then $(B true)
	is returned.
	Otherwise, $(B false) is returned.
	If there are no arguments, $(B false) is returned.)

---
import std.stdio;

abstract class C { int foo(); }

void main()
{
    C c;
    writefln(__traits(isAbstractClass, C));
    writefln(__traits(isAbstractClass, c, C));
    writefln(__traits(isAbstractClass));
    writefln(__traits(isAbstractClass, int*));
}
---

	$(P Prints:)

$(CONSOLE
true
true
false
false
)

$(H2 isFinalClass)

	$(P Works like $(B isAbstractClass), except it's for final
	classes.)

$(H2 isVirtualFunction)

	$(P Takes one argument. If that argument is a virtual function,
	$(B true) is returned, otherwise $(B false).
	)

---
import std.stdio;

struct S
{
  void bar() { }
}

class C
{
  void bar() { }
}

void main()
{
    writefln(__traits(isVirtualFunction, C.bar));  // true
    writefln(__traits(isVirtualFunction, S.bar));  // false
}
---

$(H2 isAbstractFunction)

	$(P Takes one argument. If that argument is an abstract function,
	$(B true) is returned, otherwise $(B false).
	)

---
import std.stdio;

struct S
{
  void bar() { }
}

class C
{
  void bar() { }
}

class AC
{
  abstract void foo();
}

void main()
{
    writefln(__traits(isAbstractFunction, C.bar));   // false
    writefln(__traits(isAbstractFunction, S.bar));   // false
    writefln(__traits(isAbstractFunction, AC.foo));  // true
}
---

$(H2 isFinalFunction)

	$(P Takes one argument. If that argument is a final function,
	$(B true) is returned, otherwise $(B false).
	)

---
import std.stdio;

struct S
{
  void bar() { }
}

class C
{
  void bar() { }
  final void foo();
}

final class FC
{
  void foo();
}

void main()
{
    writefln(__traits(isFinalFunction, C.bar));	  // false
    writefln(__traits(isFinalFunction, S.bar));	  // false
    writefln(__traits(isFinalFunction, C.foo));	  // true
    writefln(__traits(isFinalFunction, FC.foo));  // true
}
---

$(H2 hasMember)

	$(P The first argument is a type that has members, or
	is an expression of a type that has members.
	The second argument is a string.
	If the string is a valid property of the type,
	$(B true) is returned, otherwise $(B false).
	)

---
import std.stdio;

struct S
{
    int m;
}

void main()
{   S s;

    writefln(__traits(hasMember, S, "m")); // true
    writefln(__traits(hasMember, s, "m")); // true
    writefln(__traits(hasMember, S, "y")); // false
    writefln(__traits(hasMember, int, "sizeof")); // true
}
---

$(H2 getMember)

	$(P Takes two arguments, the second must be a string.
	The result is an expression formed from the first
	argument, followed by a '.', followed by the second
	argument as an identifier.
	)

---
import std.stdio;

struct S
{
    int mx;
    static int my;
}

void main()
{ S s;

  __traits(getMember, s, "mx") = 1;  // same as s.mx=1;
  writefln(__traits(getMember, s, "m" ~ "x")); // 1

  __traits(getMember, S, "mx") = 1;  // error, no this for S.mx
  __traits(getMember, S, "my") = 2;  // ok
}
---

$(H2 getVirtualFunctions)

	$(P The first argument is a class type or an expression of
	class type.
	The second argument is a string that matches the name of
	one of the functions of that class.
	The result is an array of the virtual overloads of that function.
	)

---
import std.stdio;

class D
{
    this() { }
    ~this() { }
    void foo() { }
    int foo(int) { return 2; }
}

void main()
{
    D d = new D();

    foreach (t; __traits(getVirtualFunctions, D, "foo"))
	writefln(typeid(typeof(t)));

    alias typeof(__traits(getVirtualFunctions, D, "foo")) b;
    foreach (t; b)
	writefln(typeid(t));

    auto i = __traits(getVirtualFunctions, d, "foo")[1](1);
    writefln(i);
}
---

	$(P Prints:)

$(CONSOLE
void()
int()
void()
int()
2
)

$(H2 classInstanceSize)

	$(P Takes a single argument, which must evaluate to either
	a class type or an expression of class type.
	The result
	is of type $(CODE size_t), and the value is the number of
	bytes in the runtime instance of the class type.
	It is based on the static type of a class, not the
	polymorphic type.
	)

$(H2 allMembers)

	$(P Takes a single argument, which must evaluate to either
	a type or an expression of type.
	An array of string literals is returned, each of which
	is the name of a member of that type combined with all
	of the members of the base classes (if the class is a type).
	No name is repeated.
	Builtin properties are not included.
	)

---
import std.stdio;

class D
{
    this() { }
    ~this() { }
    void foo() { }
    int foo(int) { return 0; }
}

void main()
{
    auto a = __traits(allMembers, D);
    writefln(a);
    // [_ctor,_dtor,foo,print,toString,toHash,opCmp,opEquals]
}
---

	$(P The order in which the strings appear in the result
	is not defined.)

$(H2 derivedMembers)

	$(P Takes a single argument, which must evaluate to either
	a type or an expression of type.
	An array of string literals is returned, each of which
	is the name of a member of that type.
	No name is repeated.
	Base class member names are not included.
	Builtin properties are not included.
	)

---
import std.stdio;

class D
{
    this() { }
    ~this() { }
    void foo() { }
    int foo(int) { return 0; }
}

void main()
{
    auto a = __traits(derivedMembers, D);
    writefln(a);	// [_ctor,_dtor,foo]
}
---

	$(P The order in which the strings appear in the result
	is not defined.)

$(H2 isSame)

	$(P Takes two arguments and returns bool $(B true) if they
	are the same symbol, $(B false) if not.)

---
import std.stdio;

struct S { }

int foo();
int bar();

void main()
{
    writefln(__traits(isSame, foo, foo)); // true
    writefln(__traits(isSame, foo, bar)); // false
    writefln(__traits(isSame, foo, S));   // false
    writefln(__traits(isSame, S, S));     // true
    writefln(__traits(isSame, std, S));   // false
    writefln(__traits(isSame, std, std)); // true
}
---

$(H2 compiles)

	$(P Returns a bool $(B true) if all of the arguments
	compile (are semantically correct).
	The arguments can be symbols, types, or expressions that
	are syntactically correct.
	The arguments cannot be statements or declarations.
	)

	$(P If there are no arguments, the result is $(B false).)

---
import std.stdio;

struct S
{
    static int s1;
    int s2;
}

int foo();
int bar();

void main()
{
    writefln(__traits(compiles));                      // false
    writefln(__traits(compiles, foo));                 // true
    writefln(__traits(compiles, foo + 1));             // true
    writefln(__traits(compiles, &foo + 1));            // false
    writefln(__traits(compiles, typeof(1)));           // true
    writefln(__traits(compiles, S.s1));                // true
    writefln(__traits(compiles, S.s3));                // false
    writefln(__traits(compiles, 1,2,3,int,long,std));  // true
    writefln(__traits(compiles, 3[1]));                // false
    writefln(__traits(compiles, 1,2,3,int,long,3[1])); // false
}
---

	$(P This is useful for:)

	$(UL
	$(LI Giving better error messages inside generic code than
	the sometimes hard to follow compiler ones.)
	$(LI Doing a finer grained specialization than template
	partial specialization allows for.)
	)

)

Macros:
	TITLE=Traits
	WIKI=Traits
	H2=<h2>$0</h2>

