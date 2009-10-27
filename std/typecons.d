// Written in the D programming language.

/**
This module implements a variety of type constructors, i.e., templates
that allow construction of new, useful general-purpose types.

Macros:

WIKI = Phobos/StdVariant
 
Synopsis:

----
// value tuples
alias Tuple!(float, "x", float, "y", float, "z") Coord;
Coord c;
c.field[1] = 1;   // access by index
c.z = 1;          // access by given name
alias Tuple!(string, string) DicEntry; // names can be omitted

// enumerated values with conversions to and from strings
mixin(defineEnum!("Openmode", "READ", "WRITE", "READWRITE", "APPEND"));
void foo()
{
    Openmode m = Openmode.READ;
    string s = enumToString(m);
    assert(s == "READ");
    Openmode m1;
    assert(enumFromString(s, m1) && m1 == m);
}

// Rebindable references to const and invariant objects
void bar()
{
    const w1 = new Widget, w2 = new Widget;
    w1.foo(); 
    // w1 = w2 would not work; can't rebind const object
    auto r = Rebindable!(const Widget)(w1);
    // invoke method as if r were a Widget object
    r.foo(); 
    // rebind r to refer to another object
    r = w2;
}
----

Copyright: Copyright Andrei Alexandrescu 2008 - 2009.
License:   <a href="http://www.boost.org/LICENSE_1_0.txt">Boost License 1.0</a>.
Authors:   $(WEB erdani.org, Andrei Alexandrescu),
           $(WEB bartoszmilewski.wordpress.com, Bartosz Milewski),
           Don Clugston

         Copyright Andrei Alexandrescu 2008 - 2009.
Distributed under the Boost Software License, Version 1.0.
   (See accompanying file LICENSE_1_0.txt or copy at
         http://www.boost.org/LICENSE_1_0.txt)
*/
module std.typecons;
import std.array, std.contracts, std.conv, std.metastrings, std.traits;

/**
Encapsulates unique ownership of a resource. 
Resource of type T is deleted at the end of the scope, unless it is transferred.
The transfer can be explicit, by calling $(D release), or implicit, when returning
Unique from a function. The resource can be a polymorphic class object, in which case
Unique behaves polymorphically too.

Example:
*/

struct Unique(T)
{
static if (is(T:Object))
    alias T RefT;
else
    alias T * RefT;
public:
/+ Doesn't work yet
    /** 
    The safe constructor. It creates the resource and 
    guarantees unique ownership of it (unless the constructor
    of $(D T) publishes aliases of $(D this)), 
    */
    this(A...)(A args)
    {
        _p = new T(args);
    }
+/

    /**
    Constructor that takes an rvalue.
    It will ensure uniqueness, as long as the rvalue
    isn't just a view on an lvalue (e.g., a cast)
    Typical usage:
    ----
    Unique!(Foo) f = new Foo;
    ----
    */
    this(RefT p)
    {
        writeln("Unique constructor with rvalue");
        _p = p;
    }
    /**
    Constructor that takes an lvalue. It nulls its source.
    The nulling will ensure uniqueness as long as there
    are no previous aliases to the source.
    */
    this(ref RefT p)
    {
        _p = p;
        writeln("Unique constructor nulling source");
        p = null;
        assert(p is null);
    }
/+ Doesn't work yet
    /** 
    Constructor that takes a Unique of a type that is convertible to our type:
    Disallow construction from lvalue (force the use of release on the source Unique)
    If the source is an rvalue, null its content, so the destrutctor doesn't delete it

    Typically used by the compiler to return $(D Unique) of derived type as $(D Unique) 
    of base type.

    Example:
    ----
    Unique!(Base) create()
    {
        Unique!(Derived) d = new Derived;
        return d; // Implicit Derived->Base conversion
    }
    ----
    */
    this(U)(ref Unique!(U) u) = null;
    this(U)(Unique!(U) u)
    {
        _p = u._p;
        u._p = null;
    }
+/

    ~this()
    {
        writeln("Unique destructor of ", (_p is null)? null: _p);
        delete _p;
        _p = null;
    }
    bool isEmpty() const
    {
        return _p is null;
    }
    /** Returns a unique rvalue. Nullifies the current contents */
    Unique release()
    {
        writeln("Release");
        auto u = Unique(_p);
        assert(_p is null);
        writeln("return from Release");
        return u;
    }
    /** Forwards member access to contents */
    RefT opDot() { return _p; }

/+ doesn't work yet!
    /**
    Postblit operator is undefined to prevent the cloning of $(D Unique) objects
    */
    this(this) = null;
 +/

private:
    RefT _p;
}

/+ doesn't work yet
unittest
{
    writeln("Unique class");
    class Bar
    {
        ~this() { writefln("    Bar destructor"); }
        int val() const { return 4; }
    }
    alias Unique!(Bar) UBar;
    UBar g(UBar u)
    {
        return u;
    }
    auto ub = UBar(new Bar);
    assert(!ub.isEmpty);
    assert(ub.val == 4);
    // should not compile
    // auto ub3 = g(ub);
    writeln("Calling g");
    auto ub2 = g(ub.release);
    assert(ub.isEmpty);
    assert(!ub2.isEmpty);
}

unittest
{
    writeln("Unique struct");
    struct Foo
    {
        ~this() { writefln("    Bar destructor"); }
        int val() const { return 3; }
    }
    alias Unique!(Foo) UFoo;
    
    UFoo f(UFoo u)
    {
        writeln("inside f");
        return u;
    }
    
    auto uf = UFoo(new Foo);
    assert(!uf.isEmpty);
    assert(uf.val == 3);
    // should not compile
    // auto uf3 = f(uf);
    writeln("Unique struct: calling f");
    auto uf2 = f(uf.release);
    assert(uf.isEmpty);
    assert(!uf2.isEmpty);
}
+/

private template tupleFields(uint index, T...)
{
    static if (!T.length)
    {
        enum string tupleFields = "";
    }
    else
    {
        static if (is(typeof(T[1]) : string))
        {
            enum string tupleFields = "Types["~ToString!(index)~"] "~T[1]~"; "
                ~ tupleFields!(index + 1, T[2 .. $]);
        }
        else
        {
            enum string tupleFields = "Types["~ToString!(index)~"] _"
                ~ToString!(index)~"; "
                ~ tupleFields!(index + 1, T[1 .. $]);
        }
    }
}

// Tuple
private template noStrings(T...)
{
    template A(U...) { alias U A; }
    static if (T.length == 0)
        alias A!() Result;
    else static if (is(typeof(T[0]) : string))
        alias noStrings!(T[1 .. $]).Result Result;
    else
        alias A!(T[0], noStrings!(T[1 .. $]).Result) Result;
}

/**
Tuple of values, for example $(D Tuple!(int, string)) is a record that
stores an $(D int) and a $(D string). $(D Tuple) can be used to bundle
values together, notably when returning multiple values from a
function. If $(D obj) is a tuple, the individual members are
accessible with the syntax $(D obj.field[0]) for the first field, $(D
obj.field[1]) for the second, and so on.

The choice of zero-based indexing instead of one-base indexing was
motivated by the ability to use value tuples with various compile-time
loop constructs (e.g. type tuple iteration), all of which use
zero-based indexing.

Example:

----
Tuple!(int, int) point;
// assign coordinates
point.field[0] = 5;
point.field[1] = 6;
// read coordinates
auto x = point.field[0];
auto y = point.[1];
----

Tuple members can be named. It is legal to mix named and unnamed
members. The method above is still applicable to all fields.

Example:

----
alias Tuple!(int, "index", string, "value") Entry;
Entry e;
e.index = 4;
e.value = "Hello";
assert(e.field[1] == "Hello");
assert(e.field[0] == 4);
----

Tuples with named fields are distinct types from tuples with unnamed
fields, i.e. each naming imparts a separate type for the tuple. Two
tuple differing in naming only are still distinct, even though they
might have the same structure.

Example:

----
Tuple!(int, "x", int, "y") point1;
Tuple!(int, int) point2;
assert(!is(typeof(point1) == typeof(point2))); // passes
----
*/
struct Tuple(T...)
{
public:
/**
   The type of the tuple's components.
*/
    alias noStrings!(T).Result Types;
    union
    {
        Types field;
        mixin(tupleFields!(0, T));
    }
    alias field expand;
    // @@@BUG 2800
    //alias field this;
/**
   Constructor taking one value for each field. Each argument must be
   implicitly assignable to the respective element of the target.
 */
    this(U...)(U values) if (U.length == Types.length)
    {
        foreach (i, Unused; Types)
        {
            field[i] = values[i];
        }
    }

/**
   Constructor taking a compatible tuple. Each element of the source
   must be implicitly assignable to the respective element of the
   target.
 */
    // @@@BUG@@@
    //this(U)(Tuple!(U) another)
    this(U)(U another)
    {
        static assert(U.Types.length == Types.length);
        foreach (i, Unused; Types)
        {
            field[i] = another.field[i];
        }
    }

/**
   Comparison for equality.
 */
    bool opEquals(T)(T rhs) if (is(typeof(T.field)))
    {
        static assert(field.length == rhs.field.length,
                "Length mismatch in attempting to compare a "
                ~typeof(this).stringof
                ~" with a "~typeof(rhs).stringof);
        foreach (i, f; field)
        {
            if (f != rhs.field[i]) return false;
        }
        return true;
    }

/**
   Comparison for ordering.
 */
    int opCmp(T)(T rhs) if (is(typeof(T.field)))
    {
        static assert(field.length == rhs.field.length,
                "Length mismatch in attempting to compare a "
                ~typeof(this).stringof
                ~" with a "~typeof(rhs).stringof);
        foreach (i, f; field)
        {
            if (f != rhs.field[i]) return f < rhs.field[i] ? -1 : 1;
        }
        return 0;
    }

/**
   Assignment from another tuple. Each element of the source must be
   implicitly assignable to the respective element of the target.
 */
    void opAssign(U)(U rhs) if (is(typeof(U.init.field[0])))
    {
        foreach (i, Unused; noStrings!(T).Result)
        {
            field[i] = rhs.field[i];
        }
    }
/**
   Takes a slice of the tuple.

   Example:

----
Tuple!(int, string, float, double) a;
a.field[1] = "abc";
a.field[2] = 4.5;
auto s = a.slice!(1, 3);
static assert(is(typeof(s) == Tuple!(string, float)));
assert(s.field[0] == "abc" && s.field[1] == 4.5);
----
 */
    ref Tuple!(Types[from .. to]) slice(uint from, uint to)()
    {
        return *cast(typeof(return) *) &(field[from]);
    }

    unittest
    {
        .Tuple!(int, string, float, double) a;
        a.field[1] = "abc";
        a.field[2] = 4.5;
        auto s = a.slice!(1, 3);
        static assert(is(typeof(s) == Tuple!(string, float)));
        assert(s.field[0] == "abc" && s.field[1] == 4.5);
    }

    static string toStringHeader = Tuple.stringof ~ "(";
    static string toStringFooter = ")";
    static string toStringSeparator = ", ";

/**
   Converts to string.
 */
    string toString()
    {
        char[] result;
        auto app = appender(&result);
        app.put(toStringHeader);
        foreach (i, Unused; noStrings!(T).Result)
        {
            static if (i > 0) result ~= toStringSeparator;
            static if (is(typeof(to!string(field[i]))))
                app.put(to!string(field[i]));
            else
                app.put(typeof(field[i]).stringof); 
        }
        app.put(toStringFooter);
        return assumeUnique(result);
    }
}

unittest
{
    {
        Tuple!(int, "a", int, "b") nosh;
        nosh.a = 5;
        nosh.b = 6;
        assert(nosh.a == 5);
        assert(nosh.b == 6);
    }
    {
        Tuple!(short, double) b;
        b.field[1] = 5;
        auto a = Tuple!(int, float)(b);
        assert(a.field[0] == 0 && a.field[1] == 5);
        a = Tuple!(int, float)(1, 2);
        assert(a.field[0] == 1 && a.field[1] == 2);
        auto c = Tuple!(int, "a", double, "b")(a);
        assert(c.field[0] == 1 && c.field[1] == 2);
    }
    Tuple!(int, int) nosh;
    nosh.field[0] = 5;
    assert(nosh.field[0] == 5);
    // Tuple!(int, int) nosh1;
    // assert(!is(typeof(nosh) == typeof(nosh1)));
    assert(nosh.toString == "Tuple!(int,int)(5, 0)", nosh.toString);
    Tuple!(int, short) yessh;
    nosh = yessh;

    Tuple!(int, "a", float, "b") x;
    static assert(x.a.offsetof == x.field[0].offsetof);
    static assert(x.b.offsetof == x.field[1].offsetof);
    x.b = 4.5;
    x.a = 5;
    assert(x.field[0] == 5 && x.field[1] == 4.5);
    assert(x.a == 5 && x.b == 4.5);

    {
        Tuple!(int, float) a, b;
        a.field[0] = 5;
        b.field[0] = 6;
        assert(a < b);
        a.field[0] = 6;
        b.field[0] = 6;
        a.field[1] = 7;
        b.field[1] = 6;
        assert(b < a);
    }
}

/**
Returns a $(D Tuple) object instantiated and initialized according to
the arguments.

Example:
----
auto value = tuple(5, 6.7, "hello");
assert(value.field[0] == 5);
assert(value.field[1] == 6.7);
assert(value.field[2] == "hello");
----
*/

Tuple!(T) tuple(T...)(T args)
{
    typeof(return) result;
    static if (T.length > 0) result.field = args;
    return result;
}

private template enumValuesImpl(string name, BaseType, long index, T...)
{
    static if (name.length)
    {
        enum string enumValuesImpl = "enum "~name~" : "~BaseType.stringof
            ~" { "~enumValuesImpl!("", BaseType, index, T)~"}\n";
    }
    else
    {
        static if (!T.length)
        {
            enum string enumValuesImpl = "";
        }
        else
        {
            static if (T.length == 1
                       || T.length > 1 && is(typeof(T[1]) : string))
            {
                enum string enumValuesImpl =  T[0]~" = "~ToString!(index)~", "
                    ~enumValuesImpl!("", BaseType, index + 1, T[1 .. $]);
            }
            else
            {
                enum string enumValuesImpl = T[0]~" = "~ToString!(T[1])~", "
                    ~enumValuesImpl!("", BaseType, T[1] + 1, T[2 .. $]);
            }
        }
    }
}

private template enumParserImpl(string name, bool first, T...)
{
    static if (first)
    {
        enum string enumParserImpl = "bool enumFromString(string s, ref "
            ~name~" v) {\n"
            ~enumParserImpl!(name, false, T)
            ~"return false;\n}\n";
    }
    else
    {
        static if (T.length)
            enum string enumParserImpl =
                "if (s == `"~T[0]~"`) return (v = "~name~"."~T[0]~"), true;\n"
                ~enumParserImpl!(name, false, T[1 .. $]);
        else
            enum string enumParserImpl = "";
    }
}

private template enumPrinterImpl(string name, bool first, T...)
{
    static if (first)
    {
        enum string enumPrinterImpl = "string enumToString("~name~" v) {\n"
            ~enumPrinterImpl!(name, false, T)~"\n}\n";
    }
    else
    {
        static if (T.length)
            enum string enumPrinterImpl =
                "if (v == "~name~"."~T[0]~") return `"~T[0]~"`;\n"
                ~enumPrinterImpl!(name, false, T[1 .. $]);
        else
            enum string enumPrinterImpl = "return null;";
    }
}

private template ValueTuple(T...)
{
    alias T ValueTuple;
}

private template StringsOnly(T...)
{
    static if (T.length == 1)
        static if (is(typeof(T[0]) : string))
            alias ValueTuple!(T[0]) StringsOnly;
        else
            alias ValueTuple!() StringsOnly;
    else
        static if (is(typeof(T[0]) : string))
            alias ValueTuple!(T[0], StringsOnly!(T[1 .. $])) StringsOnly;
        else
            alias ValueTuple!(StringsOnly!(T[1 .. $])) StringsOnly;
}

/**
Defines truly named enumerated values with parsing and stringizing
primitives.

Example:

----
mixin(defineEnum!("Abc", "A", "B", 5, "C"));
----

is equivalent to the following code:

----
enum Abc { A, B = 5, C }
string enumToString(Abc v) { ... }
Abc enumFromString(string s) { ... }
----

The $(D enumToString) function generates the unqualified names
of the enumerated values, i.e. "A", "B", and "C". The $(D
enumFromString) function expects one of "A", "B", and "C", and throws
an exception in any other case.

A base type can be specified for the enumeration like this:

----
mixin(defineEnum!("Abc", ubyte, "A", "B", "C", 255));
----

In this case the generated $(D enum) will have a $(D ubyte)
representation.  */

template defineEnum(string name, T...)
{
    static if (is(typeof(cast(T[0]) T[0].init)))
        enum string defineEnum =
            enumValuesImpl!(name, T[0], 0, T[1 .. $])
            ~ enumParserImpl!(name, true, StringsOnly!(T[1 .. $]))
            ~ enumPrinterImpl!(name, true, StringsOnly!(T[1 .. $]));
    else
        alias defineEnum!(name, int, T) defineEnum;
}

unittest
{
    mixin(defineEnum!("_24b455e148a38a847d65006bca25f7fe",
                      "A1", 1, "B1", "C1"));
    auto a = _24b455e148a38a847d65006bca25f7fe.A1;
    assert(enumToString(a) == "A1");
    _24b455e148a38a847d65006bca25f7fe b;
    assert(enumFromString("B1", b)
           && b == _24b455e148a38a847d65006bca25f7fe.B1);
}

/**
$(D Rebindable!(T)) is a simple, efficient wrapper that behaves just
like an object of type $(D T), except that you can reassign it to
refer to another object. For completeness, $(D Rebindable!(T)) aliases
itself away to $(D T) if $(D T) is a non-const object type. However,
$(D Rebindable!(T)) does not compile if $(D T) is a non-class type.

Regular $(D const) object references cannot be reassigned:

----
class Widget { int x; int y() const { return a; } }
const a = new Widget;
a.y();          // fine
a.x = 5;        // error! can't modify const a
a = new Widget; // error! can't modify const a
----

However, $(D Rebindable!(Widget)) does allow reassignment, while
otherwise behaving exactly like a $(D const Widget):

----
auto a = Rebindable!(const Widget)(new Widget);
a.y();          // fine
a.x = 5;        // error! can't modify const a
a = new Widget; // fine
----

You may want to use $(D Rebindable) when you want to have mutable
storage referring to $(D const) objects, for example an array of
references that must be sorted in place. $(D Rebindable) does not
break the soundness of D's type system and does not incur any of the
risks usually associated with $(D cast).

 */
template Rebindable(T) if (is(T : Object) || isArray!(T))
{
    static if (!is(T X == const(U), U) && !is(T X == invariant(U), U))
    {
        alias T Rebindable;
    }
    else static if (isArray!(T))
    {
        alias const(ElementType!(T))[] Rebindable;
    }
    else
    {
        struct Rebindable
        {
            private union
            {
                T original;
                U stripped;
            }
            void opAssign(T another)
            {
                stripped = cast(U) another;
            }
            static Rebindable opCall(T initializer)
            {
                Rebindable result;
                result = initializer;
                return result;
            }
            alias original get;
            T opDot() {
                return original;
            }
        }
    }
}

unittest
{
    class C { int foo() const { return 42; } }
    Rebindable!(C) obj0;
    static assert(is(typeof(obj0) == C));

    Rebindable!(const(C)) obj1;
    static assert(is(typeof(obj1.get) == const(C)), typeof(obj1.get).stringof);
    static assert(is(typeof(obj1.stripped) == C));
    obj1 = new C;
    assert(obj1.get !is null);
    obj1 = new const(C);
    assert(obj1.get !is null);

    Rebindable!(invariant(C)) obj2;
    static assert(is(typeof(obj2.get) == invariant(C)));
    static assert(is(typeof(obj2.stripped) == C));
    obj2 = new invariant(C);
    assert(obj1.get !is null);

    // test opDot
    assert(obj2.foo == 42);
}

/**
  Order the provided members to minimize size while preserving alignment.
  Returns a declaration to be mixed in.

Example:
---
struct Banner {
  mixin(alignForSize!(byte[6], double)(["name", "height"]));
}
---

  Alignment is not always optimal for 80-bit reals, nor for structs declared
  as align(1).
  BUG: bugzilla 2029 prevents the signature from being (string[] names...),
  so we need to use an ugly array literal instead.
*/
char [] alignForSize(E...)(string[E.length] names)
{
    // Sort all of the members by .alignof.
    // BUG: Alignment is not always optimal for align(1) structs
    // or 80-bit reals. 
    // TRICK: Use the fact that .alignof is always a power of 2,
    // and maximum 16 on extant systems. Thus, we can perform
    // a very limited radix sort.
    // Contains the members with .alignof = 64,32,16,8,4,2,1
    int [][] alignlist; // workaround for bugzilla 2569
    alignlist = [ [],[],[],[],[],[],[]]; // workaround for bugzilla 2562
    char[][] declaration;
    foreach(int i_bug,T; E) {
        int i = i_bug; // workaround for bugzilla 2564 (D2 only)
        declaration ~= T.stringof ~ " " ~ names[i].dup ~ ";\n";
        int a = T.alignof;
        int k = a>=64? 0 : a>=32? 1 : a>=16? 2 : a>=8? 3 : a>=4? 4 : a>=2? 5 : 6;
        alignlist[k]~=i;
    }
    char [] s;
    foreach(q; alignlist) {
      foreach(int i; q) {
        s~=  declaration[i];
      }
    }
    return s;
}

unittest {
    // assert(alignForSize!(int[], char[3], short, double[5])(["x", "y","z", "w"]) =="double[5u] w;\nint[] x;\nshort z;\nchar[3u] y;\n");
    struct Foo{ int x; }
    // assert(alignForSize!(ubyte, Foo, cdouble)(["x", "y","z"]) =="cdouble z;\nFoo y;\nubyte x;\n");    
}

/*--*
First-class reference type
*/
struct Ref(T)
{
    private T * _p;
    this(ref T value) { _p = &value; }
    ref T opDot() { return *_p; }
    /*ref*/ T opImplicitCastTo() { return *_p; }
    ref T value() { return *_p; }
    
    void opAssign(T value)
    {
        *_p = value;
    }
    void opAssign(T * value)
    {
        _p = value;
    }
}

unittest
{
    Ref!(int) x;
    int y = 42;
    x = &y;
    assert(x.value == 42);
    x = 5;
    assert(x.value == 5);
    assert(y == 5);
}

/+

/**
Defines a value paired with a distinctive "null" state that denotes
the absence of a valud value. If default constructed, a $(D
Nullable!T) object starts in the null state. Assigning it renders it
non-null. Calling $(D nullify) can nullify it again.

Example:
----
Nullable!int a;
assert(a.isNull);
a = 5;
assert(!a.isNull);
assert(a == 5);
----

Practically $(D Nullable!T) stores a $(D T) and a $(D bool). 
 */
struct Nullable(T)
{
    private T _value;
    private bool _isNull = true;

/**
Constructor initializing $(D this) with $(D value).
 */ 
    this(T value)
    {
        _value = value;
        _isNull = false;
    }

/**
Returns $(D true) if and only if $(D this) is in the null state.
 */ 
    bool isNull()
    {
        return _isNull;
    }

/**
Forces $(D this) to the null state.
 */ 
    void nullify()
    {
        // destroy
        //static if (is(typeof(_value.__dtor()))) _value.__dtor();
        _isNull = true;
    }

/**
Assigns $(D value) to the internally-held state. If the assignment
succeeds, $(D this) becomes non-null.
 */ 
    void opAssign(T value)
    {
        _value = value;
        _isNull = false;
    }

/**
Gets the value. Throws an exception if $(D this) is in the null
state. This function is also called for the implicit conversion to $(D
T).
 */
    ref T get()
    {
        enforce(!isNull);
        return _value;
    }

/**
Implicitly converts to $(D T). Throws an exception if $(D this) is in
the null state.
 */
    alias get this;
}

unittest
{
    Nullable!int a;
    assert(a.isNull);
    a = 5;
    assert(!a.isNull);
    assert(a == 5);
}

/**
Just like $(D Nullable!T), except that the null state is defined as a
particular value. For example, $(D Nullable!(uint, uint.max)) is an
$(D uint) that sets aside the value $(D uint.max) to denote a null
state. $(D Nullable!(T, nullValue)) is more storage-efficient than $(D
Nullable!T) because it does not need to store an extra $(D bool).
 */
struct Nullable(T, T nullValue)
{
    private T _value = nullValue;

/**
Constructor initializing $(D this) with $(D value).
 */ 
    this(T value)
    {
        _value = value;
    }
    
/**
Returns $(D true) if and only if $(D this) is in the null state.
 */ 
    bool isNull()
    {
        return _value == nullValue;
    }

/**
Forces $(D this) to the null state.
 */ 
    void nullify()
    {
        _value = nullValue;
    }

/**
Assigns $(D value) to the internally-held state. No null checks are
made.
 */ 
    void opAssign(T value)
    {
        _value = value;
    }
    
/**
Gets the value. Throws an exception if $(D this) is in the null
state. This function is also called for the implicit conversion to $(D
T).
 */
    ref T get()
    {
        enforce(!isNull);
        return _value;
    }

/**
Implicitly converts to $(D T). Throws an exception if $(D this) is in
the null state.
 */
    alias get this;
}

unittest
{
    Nullable!(int, int.min) a;
    assert(a.isNull);
    a = 5;
    assert(!a.isNull);
    assert(a == 5);
}

/**
Just like $(D Nullable!T), except that the object refers to a value
sitting elsewhere in memory. This makes assignments overwrite the
initially assigned value. Internally $(D NullableRef!T) only stores a
pointer to $(D T) (i.e., $(D Nullable!T.sizeof == (T*).sizeof)).
 */
struct NullableRef(T)
{
    private T* _value;

/**
Constructor binding $(D this) with $(D value).
 */ 
    this(T * value)
    {
        _value = value;
    }
    
/**
Binds the internal state to $(D value).
 */ 
    void bind(T * value)
    {
        _value = value;
    }
    
/**
Returns $(D true) if and only if $(D this) is in the null state.
 */ 
    bool isNull()
    {
        return _value is null;
    }

/**
Forces $(D this) to the null state.
 */ 
    void nullify()
    {
        _value = null;
    }

/**
Assigns $(D value) to the internally-held state. 
 */ 
    void opAssign(T value)
    {
        enforce(_value);
        *_value = value;
    }
    
/**
Gets the value. Throws an exception if $(D this) is in the null
state. This function is also called for the implicit conversion to $(D
T).
 */
    ref T get()
    {
        enforce(!isNull);
        return *_value;
    }

/**
Implicitly converts to $(D T). Throws an exception if $(D this) is in
the null state.
 */
    alias get this;
}

unittest
{
    int x = 5;
    auto a = NullableRef!(int)(&x);
    assert(!a.isNull);
    assert(a == 5);
    a = 42;
    assert(!a.isNull);
    assert(a == 42);
}

+/
