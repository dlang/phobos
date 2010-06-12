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

// Rebindable references to const and immutable objects
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

Copyright: Copyright the respective authors, 2008-
License:   $(WEB boost.org/LICENSE_1_0.txt, Boost License 1.0).
Authors:   $(WEB erdani.org, Andrei Alexandrescu),
           $(WEB bartoszmilewski.wordpress.com, Bartosz Milewski),
           Don Clugston,
           Shin Fujishiro
 */
module std.typecons;
import core.stdc.stdlib, std.algorithm, std.array, std.contracts, std.conv,
    std.metastrings, std.traits, std.typetuple, core.memory;

/**
Encapsulates unique ownership of a resource.  Resource of type T is
deleted at the end of the scope, unless it is transferred.  The
transfer can be explicit, by calling $(D release), or implicit, when
returning Unique from a function. The resource can be a polymorphic
class object, in which case Unique behaves polymorphically too.

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
template Rebindable(T) if (is(T == class) || is(T == interface) || isArray!(T))
{
    static if (!is(T X == const(U), U) && !is(T X == immutable(U), U))
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
            void opAssign(Rebindable another)
            {
                stripped = another.stripped;
            }
            static if (is(T == const U))
            {
                // safely assign immutable to const
                void opAssign(Rebindable!(immutable U) another)
                {
                    stripped = another.stripped;
                }
            }
            this(T initializer)
            {
                opAssign(initializer);
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

    Rebindable!(immutable(C)) obj2;
    static assert(is(typeof(obj2.get) == immutable(C)));
    static assert(is(typeof(obj2.stripped) == C));
    obj2 = new immutable(C);
    assert(obj1.get !is null);

    // test opDot
    assert(obj2.foo == 42);

    interface I { final int foo() const { return 42; } }
    Rebindable!(I) obj3;
    static assert(is(typeof(obj3) == I));

    Rebindable!(const I) obj4;
    static assert(is(typeof(obj4.get) == const I));
    static assert(is(typeof(obj4.stripped) == I));
    static assert(is(typeof(obj4.foo()) == int));
    obj4 = new class I {};

    Rebindable!(immutable C) obj5i;
    Rebindable!(const C) obj5c;
    obj5c = obj5c;
    obj5c = obj5i;
    obj5i = obj5i;
    static assert(!__traits(compiles, obj5i = obj5c));
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


/**
$(D BlackHole!Base) is a subclass of $(D Base) which automatically implements
all abstract member functions in $(D Base) as do-nothing functions.  Each
auto-implemented function just returns the default value of the return type
without doing anything.

The name came from
$(WEB search.cpan.org/~sburke/Class-_BlackHole-0.04/lib/Class/_BlackHole.pm, Class::_BlackHole)
Perl module by Sean M. Burke.

Example:
--------------------
abstract class C
{
    int m_value;
    this(int v) { m_value = v; }
    int value() @property { return m_value; }

    abstract real realValue() @property;
    abstract void doSomething();
}

void main()
{
    auto c = new BlackHole!C(42);
    writeln(c.value);     // prints "42"

    // Abstract functions are implemented as do-nothing:
    writeln(c.realValue); // prints "NaN"
    c.doSomething();      // does nothing
}
--------------------

See_Also:
  AutoImplement, generateEmptyFunction
 */
template BlackHole(Base)
{
    alias AutoImplement!(Base, generateEmptyFunction, isAbstractFunction)
            BlackHole;
}

unittest
{
    // return default
    {
        interface I_1 { real test(); }
        auto o = new BlackHole!I_1;
        assert(o.test() !<>= 0); // NaN
    }
    // doc example
    {
        static class C
        {
            int m_value;
            this(int v) { m_value = v; }
            int value() @property { return m_value; }

            abstract real realValue() @property;
            abstract void doSomething();
        }

        auto c = new BlackHole!C(42);
        assert(c.value == 42);

        assert(c.realValue !<>= 0); // NaN
        c.doSomething();
    }
}


/**
$(D WhiteHole!Base) is a subclass of $(D Base) which automatically implements
all abstract member functions as throw-always functions.  Each auto-implemented
function fails with throwing an $(D Error) and does never return.  Useful for
trapping use of not-yet-implemented functions.

The name came from
$(WEB search.cpan.org/~mschwern/Class-_WhiteHole-0.04/lib/Class/_WhiteHole.pm, Class::_WhiteHole)
Perl module by Michael G Schwern.

Example:
--------------------
class C
{
    abstract void notYetImplemented();
}

void main()
{
    auto c = new WhiteHole!C;
    c.notYetImplemented(); // throws an Error
}
--------------------

BUGS:
  Nothrow functions cause program to abort in release mode because the trap is
  implemented with $(D assert(0)) for nothrow functions.

See_Also:
  AutoImplement, generateAssertTrap
 */
template WhiteHole(Base)
{
    alias AutoImplement!(Base, generateAssertTrap, isAbstractFunction)
            WhiteHole;
}

// / ditto
class NotImplementedError : Error
{
    this(string method)
    {
        super(method ~ " is not implemented");
    }
}

unittest
{
    // nothrow
    debug // see the BUGS above
    {
        interface I_1
        {
            void foo();
            void bar() nothrow;
        }
        auto o = new WhiteHole!I_1;
        uint trap;
        try { o.foo(); } catch (Error e) { ++trap; }
        assert(trap == 1);
        try { o.bar(); } catch (Error e) { ++trap; }
        assert(trap == 2);
    }
    // doc example
    {
        static class C
        {
            abstract void notYetImplemented();
        }

        auto c = new WhiteHole!C;
        try
        {
            c.notYetImplemented();
            assert(0);
        }
        catch (Error e) {}
    }
}


/**
$(D AutoImplement) automatically implements (by default) all abstract member
functions in the class or interface $(D Base) in specified way.

Params:
  how  = template which specifies _how functions will be implemented/overridden.

         Two arguments are passed to $(D how): the type $(D Base) and an alias
         to an implemented function.  Then $(D how) must return an implemented
         function body as a string.

         The generated function body can use these keywords:
         $(UL
            $(LI $(D a0), $(D a1), &hellip;: arguments passed to the function;)
            $(LI $(D args): a tuple of the arguments;)
            $(LI $(D self): an alias to the function itself;)
            $(LI $(D parent): an alias to the overridden function (if any).)
         )

        You may want to use templated property functions (instead of Implicit
        Template Properties) to generate complex functions:
--------------------
// Prints log messages for each call to overridden functions.
string generateLogger(C, alias fun)() @property
{
    enum qname = C.stringof ~ "." ~ __traits(identifier, fun);
    string stmt;

    stmt ~= q{ struct Importer { import std.stdio; } };
    stmt ~= `Importer.writeln$(LPAREN)"Log: ` ~ qname ~ `(", args, ")"$(RPAREN);`;
    static if (!__traits(isAbstractFunction, fun))
    {
        static if (is(typeof(return) == void))
            stmt ~= q{ parent(args); };
        else
            stmt ~= q{
                auto r = parent(args);
                Importer.writeln("--> ", r);
                return r;
            };
    }
    return stmt;
}
--------------------

  what = template which determines _what functions should be
         implemented/overridden.

         An argument is passed to $(D what): an alias to a non-final member
         function in $(D Base).  Then $(D what) must return a boolean value.
         Return $(D true) to indicate that the passed function should be
         implemented/overridden.

--------------------
// Sees if fun returns something.
template hasValue(alias fun)
{
    enum bool hasValue = !is(ReturnType!(fun) == void);
}
--------------------


Note:

Generated code is inserted in the scope of $(D std.typecons) module.  Thus,
any useful functions outside $(D std.typecons) cannot be used in the generated
code.  To workaround this problem, you may $(D import) necessary things in a
local struct, as done in the $(D generateLogger()) template in the above
example.


BUGS:

$(UL
 $(LI Variadic arguments to constructors are not forwarded to super.)
 $(LI Deep interface inheritance causes compile error with messages like
      "Error: function std.typecons._AutoImplement!(Foo)._AutoImplement.bar
      does not override any function".  [$(BUGZILLA 2525), $(BUGZILLA 3525)] )
 $(LI The $(D parent) keyword is actually a delegate to the super class'
      corresponding member function.  [$(BUGZILLA 2540)] )
 $(LI Using alias template parameter in $(D how) and/or $(D what) may cause
     strange compile error.  Use template tuple parameter instead to workaround
     this problem.  [$(BUGZILLA 4217)] )
)
 */
class AutoImplement(Base, alias how, alias what = isAbstractFunction) : Base
{
    private alias AutoImplement_Helper!(
            "autoImplement_helper_", "Base", Base, how, what )
             autoImplement_helper_;
    override mixin(autoImplement_helper_.code);
}

/*
 * Code-generating stuffs are encupsulated in this helper template so that
 * namespace pollusion, which can cause name confliction with Base's public
 * members, should be minimized.
 */
private template AutoImplement_Helper(string myName, string baseName,
        Base, alias generateMethodBody, alias cherrypickMethod)
{
private static:
    //:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::://
    // Internal stuffs
    //:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::://

    // this would be deprecated by std.typelist.Filter
    template staticFilter(alias pred, lst...)
    {
        alias staticFilterImpl!(pred, lst).result staticFilter;
    }
    template staticFilterImpl(alias pred, lst...)
    {
        static if (lst.length > 0)
        {
            alias staticFilterImpl!(pred, lst[1 .. $]).result tail;
            //
            static if (true && pred!(lst[0]))
                alias TypeTuple!(lst[0], tail) result;
            else
                alias tail result;
        }
        else
            alias TypeTuple!() result;
    }

    // Returns function overload sets in the class C, filtered with pred.
    template enumerateOverloads(C, alias pred)
    {
        alias enumerateOverloadsImpl!(C, pred, traits_allMembers!(C)).result
                enumerateOverloads;
    }
    template enumerateOverloadsImpl(C, alias pred, names...)
    {
        static if (names.length > 0)
        {
            alias staticFilter!(pred, MemberFunctionsTuple!(C, ""~names[0])) methods;
            alias enumerateOverloadsImpl!(C, pred, names[1 .. $]).result next;

            static if (methods.length > 0)
                alias TypeTuple!(OverloadSet!(""~names[0], methods), next) result;
            else
                alias next result;
        }
        else
            alias TypeTuple!() result;
    }


    //:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::://
    // Target functions
    //:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::://

    // Add a non-final check to the cherrypickMethod.
    template canonicalPicker(fun.../+[BUG 4217]+/)
    {
        enum bool canonicalPicker = !__traits(isFinalFunction, fun[0]) &&
                                    cherrypickMethod!(fun);
    }

    /*
     * A tuple of overload sets, each item of which consists of functions to be
     * implemented by the generated code.
     */
    alias enumerateOverloads!(Base, canonicalPicker) targetOverloadSets;

    /*
     * A tuple of the super class' constructors.  Used for forwarding
     * constructor calls.
     */
    static if (__traits(hasMember, Base, "__ctor"))
        alias OverloadSet!("__ctor", __traits(getOverloads, Base, "__ctor"))
                ctorOverloadSet;
    else
        alias OverloadSet!("__ctor") ctorOverloadSet; // empty


    //:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::://
    // Type information
    //:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::://

    /*
     * The generated code will be mixed into AutoImplement, which will be
     * instantiated in this module's scope.  Thus, any user-defined types are
     * out of scope and cannot be used directly (i.e. by their names).
     *
     * We will use FuncInfo instances for accessing return types and parameter
     * types of the implemented functions.  The instances will be populated to
     * the AutoImplement's scope in a certain way; see the populate() below.
     */

    // Returns the preferred identifier for the FuncInfo instance for the i-th
    // overloaded function with the name.
    template INTERNAL_FUNCINFO_ID(string name, size_t i)
    {
        enum string INTERNAL_FUNCINFO_ID = "F_" ~ name ~ "_" ~ toStringNow!(i);
    }

    /*
     * Insert FuncInfo instances about all the target functions here.  This
     * enables the generated code to access type information via, for example,
     * "autoImplement_helper_.F_foo_1".
     */
    template populate(overloads...)
    {
        static if (overloads.length > 0)
        {
            mixin populate!(overloads[0].name, overloads[0].contents);
            mixin populate!(overloads[1 .. $]);
        }
    }
    template populate(string name, methods...)
    {
        static if (methods.length > 0)
        {
            mixin populate!(name, methods[0 .. $ - 1]);
            //
            alias methods[$ - 1] target;
            enum ith = methods.length - 1;
            mixin( "alias FuncInfo!(target) " ~
                        INTERNAL_FUNCINFO_ID!(name, ith) ~ ";" );
        }
    }

    public mixin populate!(targetOverloadSets);
    public mixin populate!(  ctorOverloadSet );


    //:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::://
    // Code-generating policies
    //:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::://

    /* Common policy configurations for generating constructors and methods. */
    template CommonGeneratingPolicy()
    {
        // base class identifier which generated code should use
        enum string BASE_CLASS_ID = baseName;

        // FuncInfo instance identifier which generated code should use
        template FUNCINFO_ID(string name, size_t i)
        {
            enum string FUNCINFO_ID =
                myName ~ "." ~ INTERNAL_FUNCINFO_ID!(name, i);
        }
    }

    /* Policy configurations for generating constructors. */
    template ConstructorGeneratingPolicy()
    {
        mixin CommonGeneratingPolicy;

        /* Generates constructor body.  Just forward to the base class' one. */
        string generateFunctionBody(ctor.../+[BUG 4217]+/)() @property
        {
            enum varstyle = variadicFunctionStyle!(typeof(&ctor[0]));

            static if (varstyle & (Variadic.C | Variadic.D))
            {
                // the argptr-forwarding problem
                pragma(msg, "Warning: AutoImplement!(", Base, ") ",
                        "ignored variadic arguments to the constructor ",
                        FunctionTypeOf!(typeof(&ctor[0])) );
            }
            return "super(args);";
        }
    }

    /* Policy configurations for genearting target methods. */
    template MethodGeneratingPolicy()
    {
        mixin CommonGeneratingPolicy;

        /* Geneartes method body. */
        string generateFunctionBody(func.../+[BUG 4217]+/)() @property
        {
            return generateMethodBody!(Base, func); // given
        }
    }


    //:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::://
    // Generated code
    //:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::://

    alias MemberFunctionGenerator!( ConstructorGeneratingPolicy!() )
            ConstructorGenerator;
    alias MemberFunctionGenerator!( MethodGeneratingPolicy!() )
            MethodGenerator;

    public enum string code =
        ConstructorGenerator.generateCode!(  ctorOverloadSet ) ~ "\n" ~
             MethodGenerator.generateCode!(targetOverloadSets);

    debug (SHOW_GENERATED_CODE)
    {
        pragma(msg, "-------------------- < ", Base, " >");
        pragma(msg, code);
        pragma(msg, "--------------------");
    }
}

//debug = SHOW_GENERATED_CODE;
unittest
{
    // no function to implement
    {
        interface I_1 {}
        auto o = new BlackHole!I_1;
    }
    // parameters
    {
        interface I_3 { void test(int, in int, out int, ref int, lazy int); }
        auto o = new BlackHole!I_3;
    }
    // use of user-defined type
    {
        struct S {}
        interface I_4 { S test(); }
        auto o = new BlackHole!I_4;
    }
    // overloads
    {
        interface I_5
        {
            void test(string);
            real test(real);
            int  test();
            int  test() @property; // ?
        }
        auto o = new BlackHole!I_5;
    }
    // constructor forwarding
    {
        static class C_6
        {
            this(int n) { assert(n == 42); }
            this(string s) { assert(s == "Deeee"); }
            this(...) {}
        }
        auto o1 = new BlackHole!C_6(42);
        auto o2 = new BlackHole!C_6("Deeee");
        auto o3 = new BlackHole!C_6(1, 2, 3, 4);
    }
    // attributes
    {
        interface I_7
        {
            ref int test_ref();
            int test_pure() pure;
            int test_nothrow() nothrow;
            int test_property() @property;
            int test_safe() @safe;
            int test_trusted() @trusted;
            int test_system() @system;
            int test_pure_nothrow() pure nothrow;
        }
        auto o = new BlackHole!I_7;
    }
    // storage classes
    {
        interface I_8
        {
            void test_const() const;
            void test_immutable() immutable;
            void test_shared() shared;
            void test_shared_const() shared const;
        }
        auto o = new BlackHole!I_8;
    }
    /+ // deep inheritance
    {
    // XXX [BUG 2525,3525]
    // NOTE: [r494] func.c(504-571) FuncDeclaration::semantic()
        interface I { void foo(); }
        interface J : I {}
        interface K : J {}
        static abstract class C_9 : K {}
        auto o = new BlackHole!C_9;
    }+/
}


/*
Used by MemberFunctionGenerator.
 */
package template OverloadSet(string nam, T...)
{
    enum string name = nam;
    alias T contents;
}

/*
Used by MemberFunctionGenerator.
 */
package template FuncInfo(alias func, /+[BUG 4217 ?]+/ T = typeof(&func))
{
    alias         ReturnType!(T) RT;
    alias ParameterTypeTuple!(T) PT;
}
package template FuncInfo(Func)
{
    alias         ReturnType!(Func) RT;
    alias ParameterTypeTuple!(Func) PT;
}

/*
General-purpose member function generator.
--------------------
template GeneratingPolicy()
{
    // [optional] the name of the class where functions are derived
    enum string BASE_CLASS_ID;

    // [optional] define this if you have only function types
    enum bool WITHOUT_SYMBOL;

    // [optional] Returns preferred identifier for i-th parameter.
    template PARAMETER_VARIABLE_ID(size_t i);

    // Returns the identifier of the FuncInfo instance for the i-th overload
    // of the specified name.  The identifier must be accessible in the scope
    // where generated code is mixed.
    template FUNCINFO_ID(string name, size_t i);

    // Returns implemented function body as a string.  When WITHOUT_SYMBOL is
    // defined, the latter is used.
    template generateFunctionBody(alias func);
    template generateFunctionBody(string name, FuncType);
}
--------------------
 */
package template MemberFunctionGenerator(alias Policy)
{
private static:
    //:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::://
    // Internal stuffs
    //:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::://

    enum CONSTRUCTOR_NAME = "__ctor";

    // true if functions are derived from a base class
    enum WITH_BASE_CLASS = __traits(hasMember, Policy, "BASE_CLASS_ID");

    // true if functions are specified as types, not symbols
    enum WITHOUT_SYMBOL = __traits(hasMember, Policy, "WITHOUT_SYMBOL");

    // preferred identifier for i-th parameter variable
    static if (__traits(hasMember, Policy, "PARAMETER_VARIABLE_ID"))
    {
        alias Policy.PARAMETER_VARIABLE_ID PARAMETER_VARIABLE_ID;
    }
    else
    {
        template PARAMETER_VARIABLE_ID(size_t i)
        {
            enum string PARAMETER_VARIABLE_ID = "a" ~ toStringNow!(i);
                // default: a0, a1, ...
        }
    }

    // Returns a tuple consisting of 0,1,2,...,n-1.  For static foreach.
    template CountUp(size_t n)
    {
        static if (n > 0)
            alias TypeTuple!(CountUp!(n - 1), n - 1) CountUp;
        else
            alias TypeTuple!() CountUp;
    }


    //:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::://
    // Code generator
    //:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::://

    /*
     * Runs through all the target overload sets and generates D code which
     * implements all the functions in the overload sets.
     */
    public string generateCode(overloads...)() @property
    {
        string code = "";

        // run through all the overload sets
        foreach (i_; CountUp!(0 + overloads.length)) // workaround
        {
            enum i = 0 + i_; // workaround
            alias overloads[i] oset;

            code ~= generateCodeForOverloadSet!(oset);

            static if (WITH_BASE_CLASS && oset.name != CONSTRUCTOR_NAME)
            {
                // The generated function declarations may hide existing ones
                // in the base class (cf. HiddenFuncError), so we put an alias
                // declaration here to reveal possible hidden functions.
                code ~= Format!("alias %s.%s %s;\n",
                            Policy.BASE_CLASS_ID, // [BUG 2540] super.
                            oset.name, oset.name );
            }
        }
        return code;
    }

    // handle each overload set
    private string generateCodeForOverloadSet(alias oset)() @property
    {
        string code = "";

        foreach (i_; CountUp!(0 + oset.contents.length)) // workaround
        {
            enum i = 0 + i_; // workaround
            code ~= generateFunction!(
                    Policy.FUNCINFO_ID!(oset.name, i), oset.name,
                    oset.contents[i]) ~ "\n";
        }
        return code;
    }

    /*
     * Returns D code which implements the function func.  This function
     * actually generates only the declarator part; the function body part is
     * generated by the functionGenerator() policy.
     */
    public string generateFunction(
            string myFuncInfo, string name, func... )() @property
    {
        enum isCtor = (name == CONSTRUCTOR_NAME);

        string code; // the result

        /*** Function Declarator ***/
        {
            alias FunctionTypeOf!(func) Func;
            alias FunctionAttribute FA;
            enum atts     = functionAttributes!(func);
            enum realName = isCtor ? "this" : name;

            /* Made them CTFE funcs just for the sake of Format!(...) */

            // return type with optional "ref"
            static string make_returnType()
            {
                string rtype = "";

                if (!isCtor)
                {
                    if (atts & FA.REF) rtype ~= "ref ";
                    rtype ~= myFuncInfo ~ ".RT";
                }
                return rtype;
            }
            enum returnType = make_returnType();

            // function attributes attached after declaration
            static string make_postAtts()
            {
                string poatts = "";
                if (atts & FA.PURE    ) poatts ~= " pure";
                if (atts & FA.NOTHROW ) poatts ~= " nothrow";
                if (atts & FA.PROPERTY) poatts ~= " @property";
                if (atts & FA.SAFE    ) poatts ~= " @safe";
                if (atts & FA.TRUSTED ) poatts ~= " @trusted";
                return poatts;
            }
            enum postAtts = make_postAtts();

            // function storage class
            static string make_storageClass()
            {
                string postc = "";
                if (is(Func ==    shared)) postc ~= " shared";
                if (is(Func ==     const)) postc ~= " const";
                if (is(Func == immutable)) postc ~= " immutable";
                return postc;
            }
            enum storageClass = make_storageClass();

            //
            code ~= Format!("extern(%s) %s %s(%s) %s %s\n",
                    functionLinkage!(func),
                    returnType,
                    realName,
                    ""~generateParameters!(myFuncInfo, func),
                    postAtts, storageClass );
        }

        /*** Function Body ***/
        code ~= "{\n";
        {
            enum nparams = ParameterTypeTuple!(func).length;

            /* Declare keywords: args, self and parent. */
            string preamble;

            preamble ~= "alias TypeTuple!(" ~ enumerateParameters!(nparams) ~ ") args;\n";
            if (!isCtor)
            {
                preamble ~= "alias " ~ name ~ " self;\n";
                if (WITH_BASE_CLASS && !__traits(isAbstractFunction, func))
                    //preamble ~= "alias super." ~ name ~ " parent;\n"; // [BUG 2540]
                    preamble ~= "auto parent = &super." ~ name ~ ";\n";
            }

            // Function body
            static if (WITHOUT_SYMBOL)
                enum fbody = Policy.generateFunctionBody!(name, func);
            else
                enum fbody = Policy.generateFunctionBody!(func);

            code ~= preamble;
            code ~= fbody;
        }
        code ~= "}";

        return code;
    }

    /*
     * Returns D code which declares function parameters.
     * "ref int a0, real a1, ..."
     */
    private string generateParameters(string myFuncInfo, func...)() @property
    {
        alias ParameterStorageClass STC;
        alias ParameterStorageClassTuple!(func) stcs;
        enum nparams = stcs.length;

        string params = ""; // the result

        foreach (i, stc; stcs)
        {
            if (i > 0) params ~= ", ";

            // Parameter storage classes.
            if (stc & STC.SCOPE) params ~= "scope ";
            if (stc & STC.OUT  ) params ~= "out ";
            if (stc & STC.REF  ) params ~= "ref ";
            if (stc & STC.LAZY ) params ~= "lazy ";

            // Take parameter type from the FuncInfo.
            params ~= myFuncInfo ~ ".PT[" ~ toStringNow!(i) ~ "]";

            // Declare a parameter variable.
            params ~= " " ~ PARAMETER_VARIABLE_ID!(i);
        }

        // Add some ellipsis part if needed.
        final switch (variadicFunctionStyle!(func))
        {
            case Variadic.NO:
                break;

            case Variadic.C, Variadic.D:
                // (...) or (a, b, ...)
                params ~= (nparams == 0) ? "..." : ", ...";
                break;

            case Variadic.TYPESAFE:
                params ~= " ...";
                break;
        }

        return params;
    }

    // Returns D code which enumerates n parameter variables using comma as the
    // separator.  "a0, a1, a2, a3"
    private string enumerateParameters(size_t n)() @property
    {
        string params = "";

        foreach (i_; CountUp!(n))
        {
            enum i = 0 + i_; // workaround
            if (i > 0) params ~= ", ";
            params ~= PARAMETER_VARIABLE_ID!(i);
        }
        return params;
    }
}


/**
Predefined how-policies for $(D AutoImplement).  These templates are used by
$(D BlackHole) and $(D WhiteHole), respectively.
 */
template generateEmptyFunction(C, func.../+[BUG 4217]+/)
{
    static if (is(ReturnType!(func) == void))
        enum string generateEmptyFunction = q{
        };
    else static if (functionAttributes!(func) & FunctionAttribute.REF)
        enum string generateEmptyFunction = q{
            static typeof(return) dummy;
            return dummy;
        };
    else
        enum string generateEmptyFunction = q{
            return typeof(return).init;
        };
}

/// ditto
template generateAssertTrap(C, func.../+[BUG 4217]+/)
{
    static if (functionAttributes!(func) & FunctionAttribute.NOTHROW) //XXX
    {
        pragma(msg, "Warning: WhiteHole!(", C, ") used assert(0) instead "
                "of Error for the auto-implemented nothrow function ",
                C, ".", __traits(identifier, func));
        enum string generateAssertTrap =
            `assert(0, "` ~ C.stringof ~ "." ~ __traits(identifier, func)
                    ~ ` is not implemented");`;
    }
    else
        enum string generateAssertTrap =
            `throw new NotImplementedError("` ~ C.stringof ~ "."
                    ~ __traits(identifier, func) ~ `");`;
}

/**
Options regarding auto-initialization of a $(D RefCounted) object (see
the definition of $(D RefCounted) below).
 */
enum RefCountedAutoInitialize
{
    /// Do not auto-initialize the object
    no,
    /// Auto-initialize the object
    yes,
}

/**
Defines a reference-counted object containing a $(D T) value as
payload. $(D RefCounted) keeps track of all references of an object,
and when the reference count goes down to zero, frees the underlying
store. $(D RefCounted) uses $(D malloc) and $(D free) for operation.

$(D RefCounted) is unsafe and should be used with care. No references
to the payload should be escaped outside the $(D RefCounted) object.

The $(D autoInit) option makes the object ensure the store is
automatically initialized. Leaving $(D autoInit ==
RefCountedAutoInitialize.yes) (the default option) is convenient but
has the cost of a test whenever the payload is accessed. If $(D
autoInit == RefCountedAutoInitialize.no), user code must call either
$(D refCountedIsInitialized) or $(D refCountedEnsureInitialized)
before attempting to access the payload. Not doing so results in null
pointer dereference.

Example:
----
// A pair of an $(D int) and a $(D size_t) - the latter being the
// reference count - will be dynamically allocated
auto rc1 = RefCounted!int(5);
assert(rc1 == 5);
// No more allocation, add just one extra reference count
auto rc2 = rc1;
// Reference semantics
rc2 = 42;
assert(rc1 == 42);
// the pair will be freed when rc1 and rc2 go out of scope
----
 */
struct RefCounted(T, RefCountedAutoInitialize autoInit =
        RefCountedAutoInitialize.yes)
if (!is(T == class))
{
    private Tuple!(T, "payload_", size_t, "count_") * refCountedStore_;

    private void refCountedInitialize(A...)(A args)
    {
	const sz = (*refCountedStore_).sizeof;
        auto p = malloc(sz)[0 .. sz];
	if (sz >= size_t.sizeof && p.ptr)
	    GC.addRange(p.ptr, sz);
        emplace!T(p[0 .. T.sizeof], args);
        refCountedStore_ = cast(typeof(refCountedStore_)) p;
        refCountedStore_.count_ = 1;
    }

/**
Returns $(D true) if and only if the underlying store has been
allocated and initialized.
 */
    @property bool refCountedIsInitialized() const
    {
        return refCountedStore_ !is null;
    }

/**
Makes sure the payload was properly initialized. Such a call is
typically inserted before using the payload.
 */
    void refCountedEnsureInitialized()
    {
        if (refCountedIsInitialized()) return;
        refCountedInitialize();
    }

/**
Constructor that initializes the payload.

Postcondition: $(D refCountedIsInitialized)
 */
    this(A...)(A args) if (A.length > 0)
    {
        refCountedInitialize(args);
    }

/**
Constructor that tracks the reference count appropriately. If $(D
!refCountedIsInitialized), does nothing.
 */
    this(this)
    {
        if (!refCountedIsInitialized) return;
        ++refCountedStore_.count_;
    }

/**
Destructor that tracks the reference count appropriately. If $(D
!refCountedIsInitialized), does nothing. When the reference count goes
down to zero, calls $(D clear) agaist the payload and calls $(D free)
to deallocate the corresponding resource.
 */
    ~this()
    {
        if (!refCountedStore_ || --refCountedStore_.count_) return;
        // Done, deallocate
        clear(*refCountedStore_);
	if ((*refCountedStore_).sizeof >= size_t.sizeof && refCountedStore_)
	    GC.removeRange(refCountedStore_);
        free(refCountedStore_);
        refCountedStore_ = null;
    }

/**
Assignment operators
 */
    void opAssign(RefCounted!T rhs)
    {
        swap(refCountedStore_, rhs.refCountedStore_);
    }

/// Ditto
    void opAssign(T rhs)
    {
        refCountedPayload() = move(rhs);
    }

/**
Returns a reference to the payload. If (autoInit ==
RefCountedAutoInitialize.yes), calls $(D
refCountedEnsureInitialized). Otherwise, just issues $(D
assert(refCountedIsInitialized)).
 */
    alias refCountedPayload this;

/**
Returns a reference to the payload. If (autoInit ==
RefCountedAutoInitialize.yes), calls $(D
refCountedEnsureInitialized). Otherwise, just issues $(D
assert(refCountedIsInitialized)). Used with $(D alias
refCountedPayload this;), so callers can just use the $(D RefCounted)
object as a $(D T).
 */
    @property ref T refCountedPayload() {
        static if (autoInit == RefCountedAutoInitialize.yes)
        {
            refCountedEnsureInitialized();
        }
        else
        {
            assert(refCountedIsInitialized);
        }
        return refCountedStore_.payload_;
    }
}

unittest
{
    RefCounted!int* p;
    {
        auto rc1 = RefCounted!int(5);
        p = &rc1;
        assert(rc1 == 5);
        assert(rc1.refCountedStore_.count_ == 1);
        auto rc2 = rc1;
        assert(rc1.refCountedStore_.count_ == 2);
        // Reference semantics
        rc2 = 42;
        assert(rc1 == 42);
        rc2 = rc2;
        assert(rc2.refCountedStore_.count_ == 2);
        rc1 = rc2;
        assert(rc1.refCountedStore_.count_ == 2);
    }
    assert(p.refCountedStore_ == null);
}

