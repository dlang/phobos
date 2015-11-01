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
alias Coord = Tuple!(float, "x", float, "y", float, "z");
Coord c;
c[1] = 1;       // access by index
c.z = 1;        // access by given name
alias DicEntry = Tuple!(string, string); // names can be omitted

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
           Shin Fujishiro,
           Kenji Hara
 */
module std.experimental.typecons;

import std.meta; // : AliasSeq, allSatisfy;
import std.traits;

import std.typecons: Tuple, tuple, Bind,
       isImplicitlyConvertible, mixinAll, staticIota;

private
{
    pragma(mangle, "_d_toObject")
    extern(C) pure nothrow Object typecons_d_toObject(void* p);
}

/*
 * Avoids opCast operator overloading.
 */
private template dynamicCast(T)
if (is(T == class) || is(T == interface))
{
    @trusted
    T dynamicCast(S)(inout S source)
    if (is(S == class) || is(S == interface))
    {
        static if (is(Unqual!S : Unqual!T))
        {
            import std.traits : QualifierOf;
            alias Qual = QualifierOf!S; // SharedOf or MutableOf
            alias TmpT = Qual!(Unqual!T);
            inout(TmpT) tmp = source;   // bypass opCast by implicit conversion
            return *cast(T*)(&tmp);     // + variable pointer cast + dereference
        }
        else
        {
            return cast(T)typecons_d_toObject(*cast(void**)(&source));
        }
    }
}

unittest
{
    class C { @disable opCast(T)() {} }
    auto c = new C;
    static assert(!__traits(compiles, cast(Object)c));
    auto o = dynamicCast!Object(c);
    assert(c is o);

    interface I { @disable opCast(T)() {} Object instance(); }
    interface J { @disable opCast(T)() {} Object instance(); }
    class D : I, J { Object instance() { return this; } }
    I i = new D();
    static assert(!__traits(compiles, cast(J)i));
    J j = dynamicCast!J(i);
    assert(i.instance() is j.instance());
}

/**
 * Supports structural based typesafe conversion.
 *
 * If $(D Source) has structural conformance with the $(D interface) $(D Targets),
 * wrap creates internal wrapper class which inherits $(D Targets) and
 * wrap $(D src) object, then return it.
 */
template wrap(Targets...)
if (Targets.length >= 1 && allSatisfy!(isMutable, Targets))
{
    import std.meta : staticMap;

    // strict upcast
    auto wrap(Source)(inout Source src) @trusted pure nothrow
    if (Targets.length == 1 && is(Source : Targets[0]))
    {
        alias T = Select!(is(Source == shared), shared Targets[0], Targets[0]);
        return dynamicCast!(inout T)(src);
    }
    // structural upcast
    template wrap(Source)
    if (!allSatisfy!(Bind!(isImplicitlyConvertible, Source), Targets))
    {
        auto wrap(inout Source src)
        {
            static assert(hasRequireMethods!(),
                          "Source "~Source.stringof~
                          " does not have structural conformance to "~
                          Targets.stringof);

            alias T = Select!(is(Source == shared), shared Impl, Impl);
            return new inout T(src);
        }

        template FuncInfo(string s, F)
        {
            enum name = s;
            alias type = F;
        }

        // Concat all Targets function members into one tuple
        template Concat(size_t i = 0)
        {
            static if (i >= Targets.length)
                alias Concat = AliasSeq!();
            else
            {
                alias Concat = AliasSeq!(GetOverloadedMethods!(Targets[i]), Concat!(i + 1));
            }
        }
        // Remove duplicated functions based on the identifier name and function type covariance
        template Uniq(members...)
        {
            static if (members.length == 0)
                alias Uniq = AliasSeq!();
            else
            {
                alias func = members[0];
                enum  name = __traits(identifier, func);
                alias type = FunctionTypeOf!func;
                template check(size_t i, mem...)
                {
                    static if (i >= mem.length)
                        enum ptrdiff_t check = -1;
                    else
                    {
                        enum ptrdiff_t check =
                            __traits(identifier, func) == __traits(identifier, mem[i]) &&
                            !is(DerivedFunctionType!(type, FunctionTypeOf!(mem[i])) == void)
                          ? i : check!(i + 1, mem);
                    }
                }
                enum ptrdiff_t x = 1 + check!(0, members[1 .. $]);
                static if (x >= 1)
                {
                    alias typex = DerivedFunctionType!(type, FunctionTypeOf!(members[x]));
                    alias remain = Uniq!(members[1 .. x], members[x + 1 .. $]);

                    static if (remain.length >= 1 && remain[0].name == name &&
                               !is(DerivedFunctionType!(typex, remain[0].type) == void))
                    {
                        alias F = DerivedFunctionType!(typex, remain[0].type);
                        alias Uniq = AliasSeq!(FuncInfo!(name, F), remain[1 .. $]);
                    }
                    else
                        alias Uniq = AliasSeq!(FuncInfo!(name, typex), remain);
                }
                else
                {
                    alias Uniq = AliasSeq!(FuncInfo!(name, type), Uniq!(members[1 .. $]));
                }
            }
        }
        alias TargetMembers = Uniq!(Concat!());             // list of FuncInfo
        alias SourceMembers = GetOverloadedMethods!Source;  // list of function symbols

        // Check whether all of SourceMembers satisfy covariance target in TargetMembers
        template hasRequireMethods(size_t i = 0)
        {
            static if (i >= TargetMembers.length)
                enum hasRequireMethods = true;
            else
            {
                enum hasRequireMethods =
                    findCovariantFunction!(TargetMembers[i], Source, SourceMembers) != -1 &&
                    hasRequireMethods!(i + 1);
            }
        }

        // Internal wrapper class
        final class Impl : Structural, Targets
        {
        private:
            Source _wrap_source;

            this(       inout Source s)        inout @safe pure nothrow { _wrap_source = s; }
            this(shared inout Source s) shared inout @safe pure nothrow { _wrap_source = s; }

            // BUG: making private should work with NVI.
            protected final inout(Object) _wrap_getSource() inout @trusted
            {
                return dynamicCast!(inout Object)(_wrap_source);
            }

            import std.conv : to;
            import std.functional : forward;
            template generateFun(size_t i)
            {
                enum name = TargetMembers[i].name;
                enum fa = functionAttributes!(TargetMembers[i].type);
                static @property stc()
                {
                    string r;
                    if (fa & FunctionAttribute.property)    r ~= "@property ";
                    if (fa & FunctionAttribute.ref_)        r ~= "ref ";
                    if (fa & FunctionAttribute.pure_)       r ~= "pure ";
                    if (fa & FunctionAttribute.nothrow_)    r ~= "nothrow ";
                    if (fa & FunctionAttribute.trusted)     r ~= "@trusted ";
                    if (fa & FunctionAttribute.safe)        r ~= "@safe ";
                    return r;
                }
                static @property mod()
                {
                    alias type = AliasSeq!(TargetMembers[i].type)[0];
                    string r;
                    static if (is(type == immutable))       r ~= " immutable";
                    else
                    {
                        static if (is(type == shared))      r ~= " shared";
                        static if (is(type == const))       r ~= " const";
                        else static if (is(type == inout))  r ~= " inout";
                        //else  --> mutable
                    }
                    return r;
                }
                enum n = to!string(i);
                static if (fa & FunctionAttribute.property)
                {
                    static if (Parameters!(TargetMembers[i].type).length == 0)
                        enum fbody = "_wrap_source."~name;
                    else
                        enum fbody = "_wrap_source."~name~" = forward!args";
                }
                else
                {
                        enum fbody = "_wrap_source."~name~"(forward!args)";
                }
                enum generateFun =
                    "override "~stc~"ReturnType!(TargetMembers["~n~"].type) "
                    ~ name~"(Parameters!(TargetMembers["~n~"].type) args) "~mod~
                    "{ return "~fbody~"; }";
            }

        public:
            mixin mixinAll!(
                staticMap!(generateFun, staticIota!(0, TargetMembers.length)));
        }
    }
}
/// ditto
template wrap(Targets...)
if (Targets.length >= 1 && !allSatisfy!(isMutable, Targets))
{
    import std.meta : staticMap;

    alias wrap = .wrap!(staticMap!(Unqual, Targets));
}

// Internal class to support dynamic cross-casting
private interface Structural
{
    inout(Object) _wrap_getSource() inout @safe pure nothrow;
}

/**
 * Extract object which wrapped by $(D wrap).
 */
template unwrap(Target)
if (isMutable!Target)
{
    // strict downcast
    auto unwrap(Source)(inout Source src) @trusted pure nothrow
    if (is(Target : Source))
    {
        alias T = Select!(is(Source == shared), shared Target, Target);
        return dynamicCast!(inout T)(src);
    }
    // structural downcast
    auto unwrap(Source)(inout Source src) @trusted pure nothrow
    if (!is(Target : Source))
    {
        alias T = Select!(is(Source == shared), shared Target, Target);
        Object o = dynamicCast!(Object)(src);   // remove qualifier
        do
        {
            if (auto a = dynamicCast!(Structural)(o))
            {
                if (auto d = dynamicCast!(inout T)(o = a._wrap_getSource()))
                    return d;
            }
            else if (auto d = dynamicCast!(inout T)(o))
                return d;
            else
                break;
        } while (o);
        return null;
    }
}
/// ditto
template unwrap(Target)
if (!isMutable!Target)
{
    alias unwrap = .unwrap!(Unqual!Target);
}

///
unittest
{
    interface Quack
    {
        int quack();
        @property int height();
    }
    interface Flyer
    {
        @property int height();
    }
    class Duck : Quack
    {
        int quack() { return 1; }
        @property int height() { return 10; }
    }
    class Human
    {
        int quack() { return 2; }
        @property int height() { return 20; }
    }

    Duck d1 = new Duck();
    Human h1 = new Human();

    interface Refleshable
    {
        int reflesh();
    }
    // does not have structural conformance
    static assert(!__traits(compiles, d1.wrap!Refleshable));
    static assert(!__traits(compiles, h1.wrap!Refleshable));

    // strict upcast
    Quack qd = d1.wrap!Quack;
    assert(qd is d1);
    assert(qd.quack() == 1);    // calls Duck.quack
    // strict downcast
    Duck d2 = qd.unwrap!Duck;
    assert(d2 is d1);

    // structural upcast
    Quack qh = h1.wrap!Quack;
    assert(qh.quack() == 2);    // calls Human.quack
    // structural downcast
    Human h2 = qh.unwrap!Human;
    assert(h2 is h1);

    // structural upcast (two steps)
    Quack qx = h1.wrap!Quack;   // Human -> Quack
    Flyer fx = qx.wrap!Flyer;   // Quack -> Flyer
    assert(fx.height == 20);    // calls Human.height
    // strucural downcast (two steps)
    Quack qy = fx.unwrap!Quack; // Flyer -> Quack
    Human hy = qy.unwrap!Human; // Quack -> Human
    assert(hy is h1);
    // strucural downcast (one step)
    Human hz = fx.unwrap!Human; // Flyer -> Human
    assert(hz is h1);
}
///
unittest
{
    interface A { int run(); }
    interface B { int stop(); @property int status(); }
    class X
    {
        int run() { return 1; }
        int stop() { return 2; }
        @property int status() { return 3; }
    }

    auto x = new X();
    auto ab = x.wrap!(A, B);
    A a = ab;
    B b = ab;
    assert(a.run() == 1);
    assert(b.stop() == 2);
    assert(b.status == 3);
    static assert(functionAttributes!(typeof(ab).status) & FunctionAttribute.property);
}
unittest
{
    class A
    {
        int draw()              { return 1; }
        int draw(int v)         { return v; }

        int draw() const        { return 2; }
        int draw() shared       { return 3; }
        int draw() shared const { return 4; }
        int draw() immutable    { return 5; }
    }
    interface Drawable
    {
        int draw();
        int draw() const;
        int draw() shared;
        int draw() shared const;
        int draw() immutable;
    }
    interface Drawable2
    {
        int draw(int v);
    }

    auto ma = new A();
    auto sa = new shared A();
    auto ia = new immutable A();
    {
                     Drawable  md = ma.wrap!Drawable;
               const Drawable  cd = ma.wrap!Drawable;
              shared Drawable  sd = sa.wrap!Drawable;
        shared const Drawable scd = sa.wrap!Drawable;
           immutable Drawable  id = ia.wrap!Drawable;
        assert( md.draw() == 1);
        assert( cd.draw() == 2);
        assert( sd.draw() == 3);
        assert(scd.draw() == 4);
        assert( id.draw() == 5);
    }
    {
        Drawable2 d = ma.wrap!Drawable2;
        static assert(!__traits(compiles, d.draw()));
        assert(d.draw(10) == 10);
    }
}
unittest
{
    // Bugzilla 10377
    import std.range, std.algorithm;

    interface MyInputRange(T)
    {
        @property T front();
        void popFront();
        @property bool empty();
    }

    //auto o = iota(0,10,1).inputRangeObject();
    //pragma(msg, __traits(allMembers, typeof(o)));
    auto r = iota(0,10,1).inputRangeObject().wrap!(MyInputRange!int)();
    assert(equal(r, [0, 1, 2, 3, 4, 5, 6, 7, 8, 9]));
}
unittest
{
    // Bugzilla 10536
    interface Interface
    {
        int foo();
    }
    class Pluggable
    {
        int foo() { return 1; }
        @disable void opCast(T, this X)();  // !
    }

    Interface i = new Pluggable().wrap!Interface;
    assert(i.foo() == 1);
}
unittest
{
    // Enhancement 10538
    interface Interface
    {
        int foo();
        int bar(int);
    }
    class Pluggable
    {
        int opDispatch(string name, A...)(A args) { return 100; }
    }

    Interface i = wrap!Interface(new Pluggable());
    assert(i.foo() == 100);
    assert(i.bar(10) == 100);
}

{

    {
        {
        }
        {

            {
            }
        }
    }
}

// find a function from Fs that has same identifier and covariant type with f
private template findCovariantFunction(alias finfo, Source, Fs...)
{
    template check(size_t i = 0)
    {
        static if (i >= Fs.length)
            enum ptrdiff_t check = -1;
        else
        {
            enum ptrdiff_t check =
                (finfo.name == __traits(identifier, Fs[i])) &&
                isCovariantWith!(FunctionTypeOf!(Fs[i]), finfo.type)
              ? i : check!(i + 1);
        }
    }
    enum x = check!();
    static if (x == -1 && is(typeof(Source.opDispatch)))
    {
        alias Params = Parameters!(finfo.type);
        enum ptrdiff_t findCovariantFunction =
            is(typeof((             Source).init.opDispatch!(finfo.name)(Params.init))) ||
            is(typeof((       const Source).init.opDispatch!(finfo.name)(Params.init))) ||
            is(typeof((   immutable Source).init.opDispatch!(finfo.name)(Params.init))) ||
            is(typeof((      shared Source).init.opDispatch!(finfo.name)(Params.init))) ||
            is(typeof((shared const Source).init.opDispatch!(finfo.name)(Params.init)))
          ? ptrdiff_t.max : -1;
    }
    else
        enum ptrdiff_t findCovariantFunction = x;
}
