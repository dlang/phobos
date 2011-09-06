// Written in the D programming language.

/**
This module implements a variety of type constructors, i.e., templates
that allow construction of new, useful general-purpose types.

Source:    $(PHOBOSSRC std/_typecons.d)

Macros:

WIKI = Phobos/StdVariant

Synopsis:

----
// value tuples
alias Tuple!(float, "x", float, "y", float, "z") Coord;
Coord c;
c[1] = 1;       // access by index
c.z = 1;        // access by given name
alias Tuple!(string, string) DicEntry; // names can be omitted

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
import core.memory, core.stdc.stdlib;
import std.algorithm, std.array, std.conv, std.exception, std.format,
    std.metastrings, std.stdio, std.traits, std.typetuple, std.range;

version(unittest) import core.vararg;

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


/**
Tuple of values, for example $(D Tuple!(int, string)) is a record that
stores an $(D int) and a $(D string). $(D Tuple) can be used to bundle
values together, notably when returning multiple values from a
function. If $(D obj) is a tuple, the individual members are
accessible with the syntax $(D obj[0]) for the first field, $(D obj[1])
for the second, and so on.

The choice of zero-based indexing instead of one-base indexing was
motivated by the ability to use value tuples with various compile-time
loop constructs (e.g. type tuple iteration), all of which use
zero-based indexing.

Example:

----
Tuple!(int, int) point;
// assign coordinates
point[0] = 5;
point[1] = 6;
// read coordinates
auto x = point[0];
auto y = point[1];
----

Tuple members can be named. It is legal to mix named and unnamed
members. The method above is still applicable to all fields.

Example:

----
alias Tuple!(int, "index", string, "value") Entry;
Entry e;
e.index = 4;
e.value = "Hello";
assert(e[1] == "Hello");
assert(e[0] == 4);
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
struct Tuple(Specs...)
{
private:

    // Parse (type,name) pairs (FieldSpecs) out of the specified
    // arguments. Some fields would have name, others not.
    template parseSpecs(Specs...)
    {
        static if (Specs.length == 0)
        {
            alias TypeTuple!() parseSpecs;
        }
        else static if (is(Specs[0]))
        {
            static if (is(typeof(Specs[1]) : string))
            {
                alias TypeTuple!(FieldSpec!(Specs[0 .. 2]),
                                 parseSpecs!(Specs[2 .. $])) parseSpecs;
            }
            else
            {
                alias TypeTuple!(FieldSpec!(Specs[0]),
                                 parseSpecs!(Specs[1 .. $])) parseSpecs;
            }
        }
        else
        {
            static assert(0, "Attempted to instantiate Tuple with an "
                            ~"invalid argument: "~ Specs[0].stringof);
        }
    }

    template FieldSpec(T, string s = "")
    {
        alias T Type;
        alias s name;
    }

    alias parseSpecs!Specs fieldSpecs;

    // Used with staticMap.
    template extractType(alias spec) { alias spec.Type extractType; }
    template extractName(alias spec) { alias spec.name extractName; }

    // Generates named fields as follows:
    //    alias Identity!(field[0]) name_0;
    //    alias Identity!(field[1]) name_1;
    //      :
    // NOTE: field[k] is an expression (which yields a symbol of a
    //       variable) and can't be aliased directly.
    static string injectNamedFields()
    {
        string decl = "";
        foreach (i, name; staticMap!(extractName, fieldSpecs))
        {
            enum    field = Format!("Identity!(field[%s])",i);
            enum numbered = Format!("_%s", i);
            decl ~= Format!("alias %s %s;", field, numbered);
            if (name.length != 0)
            {
                decl ~= Format!("alias %s %s;", numbered, name);
            }
        }
        return decl;
    }

    // Returns Specs for a subtuple this[from .. to] preserving field
    // names if any.
    template sliceSpecs(size_t from, size_t to)
    {
        alias staticMap!(expandSpec,
                         fieldSpecs[from .. to]) sliceSpecs;
    }

    template expandSpec(alias spec)
    {
        static if (spec.name.length == 0)
        {
            alias TypeTuple!(spec.Type) expandSpec;
        }
        else
        {
            alias TypeTuple!(spec.Type, spec.name) expandSpec;
        }
    }

public:
/**
   The type of the tuple's components.
*/
    alias staticMap!(extractType, fieldSpecs) Types;

    Types field;
    mixin(injectNamedFields());
    alias field expand;
    alias field this;

    // This mitigates breakage of old code now that std.range.Zip uses
    // Tuple instead of the old Proxy.  It's intentionally lacking ddoc
    // because it should eventually be deprecated.
    auto at(size_t index)() {
        return field[index];
    }

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
    this(U)(U another) if (isTuple!U)
    {
        static assert(field.length == another.field.length,
                      "Length mismatch in attempting to construct a "
                      ~ typeof(this).stringof ~" with a "~ U.stringof);
        foreach (i, T; Types)
        {
            field[i] = another.field[i];
        }
    }

/**
   Comparison for equality.
 */
    bool opEquals(R)(R rhs) if (isTuple!R)
    {
        static assert(field.length == rhs.field.length,
                "Length mismatch in attempting to compare a "
                ~typeof(this).stringof
                ~" with a "~typeof(rhs).stringof);
        foreach (i, Unused; Types)
        {
            if (field[i] != rhs.field[i]) return false;
        }
        return true;
    }

/**
   Comparison for ordering.
 */
    int opCmp(R)(R rhs) if (isTuple!R)
    {
        static assert(field.length == rhs.field.length,
                "Length mismatch in attempting to compare a "
                ~typeof(this).stringof
                ~" with a "~typeof(rhs).stringof);
        foreach (i, Unused; Types)
        {
            if (field[i] != rhs.field[i])
            {
                return field[i] < rhs.field[i] ? -1 : 1;
            }
        }
        return 0;
    }

/**
   Assignment from another tuple. Each element of the source must be
   implicitly assignable to the respective element of the target.
 */
    void opAssign(R)(R rhs) if (isTuple!R)
    {
        static assert(field.length == rhs.field.length,
                      "Length mismatch in attempting to assign a "
                     ~ R.stringof ~" to a "~ typeof(this).stringof);
        // Do not swap; opAssign should be called on the fields.
        foreach (i, Unused; Types)
        {
            field[i] = rhs.field[i];
        }
    }

    deprecated void assign(R)(R rhs) if (isTuple!R)
    {
        this = rhs;
    }

    // @@@BUG4424@@@ workaround
    private mixin template _workaround4424()
    {
        @disable void opAssign(typeof(this) );
    }
    mixin _workaround4424;

/**
   Takes a slice of the tuple.

   Example:

----
Tuple!(int, string, float, double) a;
a[1] = "abc";
a[2] = 4.5;
auto s = a.slice!(1, 3);
static assert(is(typeof(s) == Tuple!(string, float)));
assert(s[0] == "abc" && s[1] == 4.5);
----
 */
    @property
    ref Tuple!(sliceSpecs!(from, to)) slice(uint from, uint to)()
    {
        return *cast(typeof(return) *) &(field[from]);
    }

/**
   The length of the tuple.
 */
    enum length = field.length;

/**
   Converts to string.
 */
    string toString()
    {
        enum header = typeof(this).stringof ~ "(",
             footer = ")",
             separator = ", ";

        Appender!string app;
        app.put(header);
        foreach (i, Unused; Types)
        {
            static if (i > 0)
            {
                app.put(separator);
            }
            // TODO: Change this once toString() works for shared objects.
            static if (is(Unused == class) && is(Unused == shared))
                formattedWrite(app, "%s", field[i].stringof);
            else
            {
                FormatSpec!char f;  // "%s"
                formatElement(app, field[i], f);
            }
        }
        app.put(footer);
        return app.data;
    }
}

private template Identity(alias T)
{
    alias T Identity;
}

unittest
{
    {
        Tuple!(int, "a", int, "b") nosh;
        static assert(nosh.length == 2);
        nosh.a = 5;
        nosh.b = 6;
        assert(nosh.a == 5);
        assert(nosh.b == 6);
    }
    {
        Tuple!(short, double) b;
        static assert(b.length == 2);
        b[1] = 5;
        auto a = Tuple!(int, real)(b);
        assert(a[0] == 0 && a[1] == 5);
        a = Tuple!(int, real)(1, 2);
        assert(a[0] == 1 && a[1] == 2);
        auto c = Tuple!(int, "a", double, "b")(a);
        assert(c[0] == 1 && c[1] == 2);
    }
    {
        Tuple!(int, real) nosh;
        nosh[0] = 5;
        nosh[1] = 0;
        assert(nosh[0] == 5 && nosh[1] == 0);
        assert(nosh.toString == "Tuple!(int,real)(5, 0)", nosh.toString);
        Tuple!(int, int) yessh;
        nosh = yessh;
    }
    {
        Tuple!(int, string) t;
        t[0] = 10;
        t[1] = "str";
        assert(t[0] == 10 && t[1] == "str");
        assert(t.toString == `Tuple!(int,string)(10, "str")`, t.toString);
    }
    {
        Tuple!(int, "a", double, "b") x;
        static assert(x.a.offsetof == x[0].offsetof);
        static assert(x.b.offsetof == x[1].offsetof);
        x.b = 4.5;
        x.a = 5;
        assert(x[0] == 5 && x[1] == 4.5);
        assert(x.a == 5 && x.b == 4.5);
    }
    // indexing
    {
        Tuple!(int, real) t;
        static assert(is(typeof(t[0]) == int));
        static assert(is(typeof(t[1]) == real));
        int* p0 = &t[0];
        real* p1 = &t[1];
        t[0] = 10;
        t[1] = -200.0L;
        assert(*p0 == t[0]);
        assert(*p1 == t[1]);
    }
    // slicing
    {
        Tuple!(int, "x", real, "y", double, "z", string) t;
        t[0] = 10;
        t[1] = 11;
        t[2] = 12;
        t[3] = "abc";
        auto a = t.slice!(0, 3);
        assert(a.length == 3);
        assert(a.x == t.x);
        assert(a.y == t.y);
        assert(a.z == t.z);
        auto b = t.slice!(2, 4);
        assert(b.length == 2);
        assert(b.z == t.z);
        assert(b[1] == t[3]);
    }
    // nesting
    {
        Tuple!(Tuple!(int, real), Tuple!(string, "s")) t;
        static assert(is(typeof(t[0]) == Tuple!(int, real)));
        static assert(is(typeof(t[1]) == Tuple!(string, "s")));
        static assert(is(typeof(t[0][0]) == int));
        static assert(is(typeof(t[0][1]) == real));
        static assert(is(typeof(t[1].s) == string));
        t[0] = tuple(10, 20.0L);
        t[1].s = "abc";
        assert(t[0][0] == 10);
        assert(t[0][1] == 20.0L);
        assert(t[1].s == "abc");
    }
    // non-POD
    {
        static struct S
        {
            int count;
            this(this) { ++count; }
            ~this() { --count; }
            void opAssign(S rhs) { count = rhs.count; }
        }
        Tuple!(S, S) ss;
        Tuple!(S, S) ssCopy = ss;
        assert(ssCopy[0].count == 1);
        assert(ssCopy[1].count == 1);
        ssCopy[1] = ssCopy[0];
        assert(ssCopy[1].count == 2);
    }
    // bug 2800
    {
        static struct R
        {
            Tuple!(int, int) _front;
            @property ref Tuple!(int, int) front() { return _front;  }
            @property bool empty() { return _front[0] >= 10; }
            void popFront() { ++_front[0]; }
        }
        foreach (a; R())
        {
            static assert(is(typeof(a) == Tuple!(int, int)));
            assert(0 <= a[0] && a[0] < 10);
            assert(a[1] == 0);
        }
    }
    // Construction with compatible tuple
    {
        Tuple!(int, int) x;
        x[0] = 10;
        x[1] = 20;
        Tuple!(int, "a", double, "b") y = x;
        assert(y.a == 10);
        assert(y.b == 20);
        // incompatible
        static assert(!__traits(compiles, Tuple!(int, int)(y)));
    }
}

/**
Returns a $(D Tuple) object instantiated and initialized according to
the arguments.

Example:
----
auto value = tuple(5, 6.7, "hello");
assert(value[0] == 5);
assert(value[1] == 6.7);
assert(value[2] == "hello");
----
*/

Tuple!(T) tuple(T...)(T args)
{
    typeof(return) result;
    static if (T.length > 0) result.field = args;
    return result;
}

/**
Returns $(D true) if and only if $(D T) is an instance of the
$(D Tuple) struct template.
 */
template isTuple(T)
{
    static if (is(Unqual!T Unused : Tuple!Specs, Specs...))
    {
        enum isTuple = true;
    }
    else
    {
        enum isTuple = false;
    }
}

unittest
{
    static assert(isTuple!(Tuple!()));
    static assert(isTuple!(Tuple!(int)));
    static assert(isTuple!(Tuple!(int, real, string)));
    static assert(isTuple!(Tuple!(int, "x", real, "y")));
    static assert(isTuple!(Tuple!(int, Tuple!(real), string)));

    static assert(isTuple!(const Tuple!(int)));
    static assert(isTuple!(immutable Tuple!(int)));

    static assert(!isTuple!(int));
    static assert(!isTuple!(const int));

    struct S {}
    static assert(!isTuple!(S));
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

deprecated template defineEnum(string name, T...)
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
            void opAssign(T another) pure nothrow
            {
                stripped = cast(U) another;
            }
            void opAssign(Rebindable another) pure nothrow
            {
                stripped = another.stripped;
            }
            static if (is(T == const U))
            {
                // safely assign immutable to const
                void opAssign(Rebindable!(immutable U) another) pure nothrow
                {
                    stripped = another.stripped;
                }
            }

            this(T initializer) pure nothrow
            {
                opAssign(initializer);
            }

            @property ref T get() pure nothrow
            {
                return original;
            }
            @property ref const(T) get() const pure nothrow
            {
                return original;
            }

            alias get this;
        }
    }
}

/**
Convenience function for creating a $(D Rebindable) using automatic type
inference.
*/
Rebindable!(T) rebindable(T)(T obj)
if (is(T == class) || is(T == interface) || isArray!(T))
{
    typeof(return) ret;
    ret = obj;
    return ret;
}

/**
This function simply returns the $(D Rebindable) object passed in.  It's useful
in generic programming cases when a given object may be either a regular
$(D class) or a $(D Rebindable).
*/
Rebindable!(T) rebindable(T)(Rebindable!(T) obj)
{
    return obj;
}

unittest
{
    interface CI { const int foo(); }
    class C : CI { int foo() const { return 42; } }
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

    // Test the convenience functions.
    auto obj5convenience = rebindable(obj5i);
    assert(obj5convenience is obj5i);

    auto obj6 = rebindable(new immutable(C));
    static assert(is(typeof(obj6) == Rebindable!(immutable C)));
    assert(obj6.foo == 42);

    auto obj7 = rebindable(new C);
    CI interface1 = obj7;
    auto interfaceRebind1 = rebindable(interface1);
    assert(interfaceRebind1.foo == 42);

    const interface2 = interface1;
    auto interfaceRebind2 = rebindable(interface2);
    assert(interfaceRebind2.foo == 42);

    auto arr = [1,2,3,4,5];
    const arrConst = arr;
    assert(rebindable(arr) == arr);
    assert(rebindable(arrConst) == arr);
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
*/
string alignForSize(E...)(string[] names...)
{
    // Sort all of the members by .alignof.
    // BUG: Alignment is not always optimal for align(1) structs
    // or 80-bit reals or 64-bit primitives on x86.
    // TRICK: Use the fact that .alignof is always a power of 2,
    // and maximum 16 on extant systems. Thus, we can perform
    // a very limited radix sort.
    // Contains the members with .alignof = 64,32,16,8,4,2,1

    assert(E.length == names.length,
        "alignForSize: There should be as many member names as the types");

    string[7] declaration = ["", "", "", "", "", "", ""];

    foreach (i, T; E) {
        auto a = T.alignof;
        auto k = a>=64? 0 : a>=32? 1 : a>=16? 2 : a>=8? 3 : a>=4? 4 : a>=2? 5 : 6;
        declaration[k] ~= T.stringof ~ " " ~ names[i] ~ ";\n";
    }

    auto s = "";
    foreach (decl; declaration)
        s ~= decl;
    return s;
}

unittest {
    enum x = alignForSize!(int[], char[3], short, double[5])("x", "y","z", "w");
    struct Foo{ int x; }
    enum y = alignForSize!(ubyte, Foo, cdouble)("x", "y","z");

    static if(size_t.sizeof == uint.sizeof)
    {
        enum passNormalX = x == "double[5u] w;\nint[] x;\nshort z;\nchar[3u] y;\n";
        enum passNormalY = y == "cdouble z;\nFoo y;\nubyte x;\n";

        enum passAbnormalX = x == "int[] x;\ndouble[5u] w;\nshort z;\nchar[3u] y;\n";
        enum passAbnormalY = y == "Foo y;\ncdouble z;\nubyte x;\n";
        // ^ blame http://d.puremagic.com/issues/show_bug.cgi?id=231

        static assert(passNormalX || double.alignof <= (int[]).alignof && passAbnormalX);
        static assert(passNormalY || double.alignof <= int.alignof && passAbnormalY);
    }
    else
    {
        static assert(x == "int[] x;\ndouble[5LU] w;\nshort z;\nchar[3LU] y;\n");
        static assert(y == "cdouble z;\nFoo y;\nubyte x;\n");
    }
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

/**
Defines a value paired with a distinctive "null" state that denotes
the absence of a value. If default constructed, a $(D
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
    @property bool isNull() const
    {
        return _isNull;
    }

/**
Forces $(D this) to the null state.
 */
    void nullify()
    {
        clear(_value);
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
    @property ref T get()
    {
        enforce(!isNull);
        return _value;
    }
    //@@@BUG3748@@@: inout does not work properly.
    //               need to define a separate 'const' version
    @property ref const(T) get() const
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
    assertThrown(a.get);
    a = 5;
    assert(!a.isNull);
    assert(a == 5);
    //@@@BUG5188@@@
    //assert(a != 3);
    assert(a.get != 3);
    a.nullify();
    assert(a.isNull);
    a = 3;
    assert(a == 3);
    a *= 6;
    assert(a == 18);
    a.nullify();
    assertThrown(a += 2);
}
unittest
{
    auto k = Nullable!int(74);
    assert(k == 74);
    k.nullify();
    assert(k.isNull);
}
unittest
{
    static int f(in Nullable!int x) {
        return x.isNull ? 42 : x.get;
    }
    Nullable!int a;
    assert(f(a) == 42);
    a = 8;
    assert(f(a) == 8);
    a.nullify();
    assert(f(a) == 42);
}
unittest
{
    static struct S { int x; }
    Nullable!S s;
    assert(s.isNull);
    s = S(6);
    assert(s == S(6));
    //@@@BUG5188@@@
    //assert(s != S(0));
    assert(s.get != S(0));
    s.x = 9190;
    assert(s.x == 9190);
    s.nullify();
    assertThrown(s.x = 9441);
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
    @property bool isNull() const
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
    @property ref T get()
    {
        enforce(!isNull);
        return _value;
    }
    //@@@BUG3748@@@
    @property ref const(T) get() const
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
    assertThrown(a.get);
    a = 5;
    assert(!a.isNull);
    assert(a == 5);
    static assert(a.sizeof == int.sizeof);
}
unittest
{
    auto a = Nullable!(int, int.min)(8);
    assert(a == 8);
    a.nullify();
    assert(a.isNull);
}
unittest
{
    static int f(in Nullable!(int, int.min) x) {
        return x.isNull ? 42 : x.get;
    }
    Nullable!(int, int.min) a;
    assert(f(a) == 42);
    a = 8;
    assert(f(a) == 8);
    a.nullify();
    assert(f(a) == 42);
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
    @property bool isNull() const
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
    @property ref T get()
    {
        enforce(!isNull);
        return *_value;
    }
    //@@@BUG3748@@@
    @property ref const(T) get() const
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
    int x = 5, y = 7;
    auto a = NullableRef!(int)(&x);
    assert(!a.isNull);
    assert(a == 5);
    assert(x == 5);
    a = 42;
    assert(x == 42);
    assert(!a.isNull);
    assert(a == 42);
    a.nullify();
    assert(x == 42);
    assert(a.isNull);
    assertThrown(a.get);
    assertThrown(a = 71);
    a.bind(&y);
    assert(a == 7);
    y = 135;
    assert(a == 135);
}
unittest
{
    static int f(in NullableRef!int x) {
        return x.isNull ? 42 : x.get;
    }
    int x = 5;
    auto a = NullableRef!int(&x);
    assert(f(a) == 5);
    a.nullify();
    assert(f(a) == 42);
}

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
    mixin(autoImplement_helper_.code);
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

            static if (varstyle & (Variadic.c | Variadic.d))
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
                    if (atts & FA.ref_) rtype ~= "ref ";
                    rtype ~= myFuncInfo ~ ".RT";
                }
                return rtype;
            }
            enum returnType = make_returnType();

            // function attributes attached after declaration
            static string make_postAtts()
            {
                string poatts = "";
                if (atts & FA.pure_   ) poatts ~= " pure";
                if (atts & FA.nothrow_) poatts ~= " nothrow";
                if (atts & FA.property) poatts ~= " @property";
                if (atts & FA.safe    ) poatts ~= " @safe";
                if (atts & FA.trusted ) poatts ~= " @trusted";
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
            if (isAbstractFunction!func)
                code ~= "override ";
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
            if (stc & STC.scope_) params ~= "scope ";
            if (stc & STC.out_  ) params ~= "out ";
            if (stc & STC.ref_  ) params ~= "ref ";
            if (stc & STC.lazy_ ) params ~= "lazy ";

            // Take parameter type from the FuncInfo.
            params ~= myFuncInfo ~ ".PT[" ~ toStringNow!(i) ~ "]";

            // Declare a parameter variable.
            params ~= " " ~ PARAMETER_VARIABLE_ID!(i);
        }

        // Add some ellipsis part if needed.
        final switch (variadicFunctionStyle!(func))
        {
            case Variadic.no:
                break;

            case Variadic.c, Variadic.d:
                // (...) or (a, b, ...)
                params ~= (nparams == 0) ? "..." : ", ...";
                break;

            case Variadic.typesafe:
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
    else static if (functionAttributes!(func) & FunctionAttribute.ref_)
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
    static if (functionAttributes!(func) & FunctionAttribute.nothrow_) //XXX
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
    struct _RefCounted
    {
        private Tuple!(T, "_payload", size_t, "_count") * _store;
        debug(RefCounted)
        {
            private bool _debugging = false;
            @property bool debugging() const
            {
                return _debugging;
            }
            @property void debugging(bool d)
            {
                if (d != _debugging)
                {
                    writeln(typeof(this).stringof, "@",
                            cast(void*) _store,
                            d ? ": starting debug" : ": ending debug");
                }
                _debugging = d;
            }
        }

        private void initialize(A...)(A args)
        {
            const sz = (*_store).sizeof;
            auto p = malloc(sz)[0 .. sz];
            if (sz >= size_t.sizeof && p.ptr)
            {
                GC.addRange(p.ptr, sz);
            }
            emplace(cast(T*) p.ptr, args);
            _store = cast(typeof(_store)) p.ptr;
            _store._count = 1;
            debug(RefCounted) if (debugging) writeln(typeof(this).stringof,
                "@", cast(void*) _store, ": initialized with ",
                    A.stringof);
        }

        /**
           Returns $(D true) if and only if the underlying store has been
           allocated and initialized.
        */
        @property bool isInitialized() const
        {
            return _store !is null;
        }

        /**
           Makes sure the payload was properly initialized. Such a
           call is typically inserted before using the payload.
        */
        void ensureInitialized()
        {
            if (!isInitialized) initialize();
        }

    }
    _RefCounted RefCounted;

/**
Constructor that initializes the payload.

Postcondition: $(D refCountedIsInitialized)
 */
    this(A...)(A args) if (A.length > 0)
    {
        RefCounted.initialize(args);
    }

/**
Constructor that tracks the reference count appropriately. If $(D
!refCountedIsInitialized), does nothing.
 */
    this(this)
    {
        if (!RefCounted.isInitialized) return;
        ++RefCounted._store._count;
        debug(RefCounted) if (RefCounted.debugging)
                 writeln(typeof(this).stringof,
                "@", cast(void*) RefCounted._store, ": bumped refcount to ",
                RefCounted._store._count);
    }

/**
Destructor that tracks the reference count appropriately. If $(D
!refCountedIsInitialized), does nothing. When the reference count goes
down to zero, calls $(D clear) agaist the payload and calls $(D free)
to deallocate the corresponding resource.
 */
    ~this()
    {
        if (!RefCounted._store) return;
        assert(RefCounted._store._count > 0);
        if (--RefCounted._store._count)
        {
            debug(RefCounted) if (RefCounted.debugging)
                     writeln(typeof(this).stringof,
                    "@", cast(void*)RefCounted._store,
                    ": decrement refcount to ", RefCounted._store._count);
            return;
        }
        debug(RefCounted) if (RefCounted.debugging)
        {
            write(typeof(this).stringof,
                    "@", cast(void*)RefCounted._store, ": freeing... ");
            stdout.flush();
        }
        // Done, deallocate
        assert(RefCounted._store);
        clear(RefCounted._store._payload);
        if (hasIndirections!T && RefCounted._store)
            GC.removeRange(RefCounted._store);
        free(RefCounted._store);
        RefCounted._store = null;
        debug(RefCounted) if (RefCounted.debugging) writeln("done!");
    }

/**
Assignment operators
 */
    void opAssign(typeof(this) rhs)
    {
        swap(RefCounted._store, rhs.RefCounted._store);
    }

/// Ditto
    void opAssign(T rhs)
    {
        RefCounted._store._payload = move(rhs);
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
    @property ref T refCountedPayload()
    {
        static if (autoInit == RefCountedAutoInitialize.yes)
        {
            RefCounted.ensureInitialized();
        }
        else
        {
            assert(RefCounted.isInitialized);
        }
        return RefCounted._store._payload;
    }

//
    @property ref const(T) refCountedPayload() const
    {
        static if (autoInit == RefCountedAutoInitialize.yes)
        {
            // @@@
            //refCountedEnsureInitialized();
            assert(RefCounted.isInitialized);
        }
        else
        {
            assert(RefCounted.isInitialized);
        }
        return RefCounted._store._payload;
    }
}

unittest
{
    RefCounted!int* p;
    {
        auto rc1 = RefCounted!int(5);
        p = &rc1;
        assert(rc1 == 5);
        assert(rc1.RefCounted._store._count == 1);
        auto rc2 = rc1;
        assert(rc1.RefCounted._store._count == 2);
        // Reference semantics
        rc2 = 42;
        assert(rc1 == 42);
        rc2 = rc2;
        assert(rc2.RefCounted._store._count == 2);
        rc1 = rc2;
        assert(rc1.RefCounted._store._count == 2);
    }
    assert(p.RefCounted._store == null);

    // RefCounted as a member
    struct A
    {
        RefCounted!int x;
        this(int y)
        {
            x.RefCounted.initialize(y);
        }
        A copy()
        {
            auto another = this;
            return another;
        }
    }
    auto a = A(4);
    auto b = a.copy();
    if (a.x.RefCounted._store._count != 2) {
        stderr.writeln("*** BUG 4356 still unfixed");
    }
}

// 6606
unittest
{
    union U {
       size_t i;
       void* p;
    }

    struct S {
       U u;
    }

    alias RefCounted!S SRC;
}

/**
Allocates a $(D class) object right inside the current scope,
therefore avoiding the overhead of $(D new). This facility is unsafe;
it is the responsibility of the user to not escape a reference to the
object outside the scope.

Example:
----
unittest
{
    class A { int x; }
    auto a1 = scoped!A();
    auto a2 = scoped!A();
    a1.x = 42;
    a2.x = 53;
    assert(a1.x == 42);
}
----
 */
@system Scoped!T scoped(T, Args...)(Args args) if (is(T == class))
{
    Scoped!T result;

    static if (Args.length == 0)
    {
        result.Scoped_store[] = typeid(T).init[];
        static if (is(typeof(T.init.__ctor())))
        {
            result.Scoped_payload.__ctor();
        }
    }
    else
    {
        emplace!T(cast(void[]) result.Scoped_store, args);
    }

    return result;
}

private struct Scoped(T)
{
    private byte[__traits(classInstanceSize, T)] Scoped_store = void;
    @property T Scoped_payload()
    {
        return cast(T) (Scoped_store.ptr);
    }
    alias Scoped_payload this;

    @disable this(this)
    {
        writeln("Illegal call to Scoped this(this)");
        assert(false);
    }

    ~this()
    {
        destroy(Scoped_payload);
        if ((cast(void**) Scoped_store.ptr)[1]) // if monitor is not null
        {
            _d_monitordelete(Scoped_payload, true);
        }
    }
}

// Used by scoped() above
private extern (C) static void _d_monitordelete(Object h, bool det);

/*
  Used by scoped() above.  Calls the destructors of an object
  transitively up the inheritance path, but work properly only if the
  static type of the object (T) is known.
 */
private void destroy(T)(T obj) if (is(T == class))
{
    static if (is(typeof(obj.__dtor())))
    {
        obj.__dtor();
    }
    static if (!is(T == Object) && is(T Base == super))
    {
        Base[0] b = obj;
        destroy(b);
    }
}

unittest
{
    class A { int x = 1; }
    auto a1 = scoped!A();
    assert(a1.x == 1);
    auto a2 = scoped!A();
    a1.x = 42;
    a2.x = 53;
    assert(a1.x == 42);
}

unittest
{
    class A { int x = 1; this() { x = 2; } }
    auto a1 = scoped!A();
    assert(a1.x == 2);
    auto a2 = scoped!A();
    a1.x = 42;
    a2.x = 53;
    assert(a1.x == 42);
}

unittest
{
    class A { int x = 1; this(int y) { x = y; } ~this() {} }
    auto a1 = scoped!A(5);
    assert(a1.x == 5);
    auto a2 = scoped!A();
    a1.x = 42;
    a2.x = 53;
    assert(a1.x == 42);
}

unittest
{
    class A { static bool dead; ~this() { dead = true; } }
    class B : A { static bool dead; ~this() { dead = true; } }
    {
        auto b = scoped!B;
    }
    assert(B.dead, "asdasd");
    assert(A.dead, "asdasd");
}

unittest
{
    // bug4500
    class A
    {
        this() { a = this; }
        this(int i) { a = this; }
        A a;
        bool check() { return this is a; }
    }

    auto a1 = scoped!A;
    assert(a1.check());

    auto a2 = scoped!A(1);
    assert(a2.check());

    a1.a = a1;
    assert(a1.check());
}

unittest
{
    static class A
    {
        static int sdtor;

        this() { ++sdtor; assert(sdtor == 1); }
        ~this() { assert(sdtor == 1); --sdtor; }
    }

    interface Bob {}

    static class ABob : A, Bob
    {
        this() { ++sdtor; assert(sdtor == 2); }
        ~this() { assert(sdtor == 2); --sdtor; }
    }

    A.sdtor = 0;
    scope(exit) assert(A.sdtor == 0);
    auto abob = scoped!ABob();
}

/**
Defines a simple, self-documenting yes/no flag. This makes it easy for
APIs to define functions accepting flags without resorting to $(D
bool), which is opaque in calls, and without needing to define an
enumerated type separately. Using $(D Flag!"Name") instead of $(D
bool) makes the flag's meaning visible in calls. Each yes/no flag has
its own type, which makes confusions and mix-ups impossible.

Example:
----
// Before
string getLine(bool keepTerminator)
{
    ...
    if (keepTerminator) ...
    ...
}
...
// Code calling getLine (usually far away from its definition) can't
// be understood without looking at the documentation, even by users
// familiar with the API. Assuming the reverse meaning
// (i.e. "ignoreTerminator") and inserting the wrong code compiles and
// runs with erroneous results.
auto line = getLine(false);

// After
string getLine(Flag!"KeepTerminator" keepTerminator)
{
    ...
    if (keepTerminator) ...
    ...
}
...
// Code calling getLine can be easily read and understood even by
// people not fluent with the API.
auto line = getLine(Flag!"KeepTerminator".yes);
----

Passing categorical data by means of unstructured $(D bool)
parameters is classified under "simple-data coupling" by Steve
McConnell in the $(LUCKY Code Complete) book, along with three other
kinds of coupling. The author argues citing several studies that
coupling has a negative effect on code quality. $(D Flag) offers a
simple structuring method for passing yes/no flags to APIs.

As a perk, the flag's name may be any string and as such can include
characters not normally allowed in identifiers, such as
spaces and dashes.
 */
template Flag(string name) {
    ///
    enum Flag : bool
    {
        /**
         When creating a value of type $(D Flag!"Name"), use $(D
         Flag!"Name".no) for the negative option. When using a value
         of type $(D Flag!"Name"), compare it against $(D
         Flag!"Name".no) or just $(D false) or $(D 0).  */
        no = false,

        /** When creating a value of type $(D Flag!"Name"), use $(D
         Flag!"Name".yes) for the affirmative option. When using a
         value of type $(D Flag!"Name"), compare it against $(D
         Flag!"Name".yes).
        */
        yes = true
    }
}

/**
Convenience names that allow using e.g. $(D yes!"encryption") instead of
$(D Flag!"encryption".yes) and $(D no!"encryption") instead of $(D
Flag!"encryption".no).
*/
struct Yes
{
    static auto @property opDispatch(string name)() { return
    Flag!name.yes; }
}
//template yes(string name) { enum Flag!name yes = Flag!name.yes; }

/// Ditto
struct No
{
    static auto @property opDispatch(string name)() { return
    Flag!name.no; }
}
//template no(string name) { enum Flag!name no = Flag!name.no; }

unittest
{
    Flag!"abc" flag1;
    assert(flag1 == Flag!"abc".no);
    assert(flag1 == No.abc);
    assert(!flag1);
    if (flag1) assert(false);
    flag1 = Yes.abc;
    assert(flag1);
    if (!flag1) assert(false);
    if (flag1) {} else assert(false);
    assert(flag1 == Yes.abc);
}

