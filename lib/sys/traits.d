// Written in the D programming language
/++
    Templates which extract information about types and symbols at compile time.

    In the context of lib.sys.traits, a "trait" is a template which provides
    information about a type or symbol. Most traits evaluate to
    $(D true) or $(D false), telling the code using it whether the given
    arguments match / have that specific trait (e.g. whether the given type is
    a dynamic array or whether the given function is $(D @safe)). However, some
    traits may provide other kinds of information about a type (e.g. the trait
    could evaluate to the base type for an enum type, or it could strip
    $(D const) from the type to provide the mutable version of that type).

    These traits are then used primarily in template constraints so that they
    can test that the template arguments meet the criteria required by those
    templates, though they can be useful in a variety of compile-time contexts
    (e.g. the condition of a $(D static if)).

    $(SCRIPT inhibitQuickIndex = 1;)

    $(BOOKTABLE ,
    $(TR $(TH Category) $(TH Templates))
    $(TR $(TD Traits for removing type qualfiers) $(TD
              $(LREF Unconst)
              $(LREF Unshared)
              $(LREF Unqual)
    ))
    $(TR $(TD Type Constructors) $(TD
             $(LREF ConstOf)
             $(LREF ImmutableOf)
             $(LREF InoutOf)
             $(LREF SharedOf)
    ))
    )

    Copyright: Copyright The D Language Foundation 2005 - 2024.
    License:   $(HTTP www.boost.org/LICENSE_1_0.txt, Boost License 1.0).
    Authors:   $(HTTP jmdavisprog.com, Jonathan M Davis)
               $(HTTP digitalmars.com, Walter Bright),
               Tomasz Stachowiak (`isExpressions`),
               $(HTTP erdani.org, Andrei Alexandrescu),
               Shin Fujishiro,
               $(HTTP octarineparrot.com, Robert Clipsham),
               $(HTTP klickverbot.at, David Nadlinger),
               Kenji Hara,
               Shoichi Kato
    Source:    $(PHOBOSSRC lib/sys/traits)
+/
module lib.sys.traits;

/++
    Removes the outer layer of $(D const), $(D inout), or $(D immutable)
    from type $(D T).

    If none of those qualifiers have been applied to the outer layer of
    type $(D T), then the result is $(D T).

    Due to limitations with D's type system, user-defined types have the type
    qualifier removed entirely if present. The types of the member variables
    themselves are unaffected beyond how removing the type qualifier from the
    type containing them affects them (e.g. an $(D int*) member that is
    $(D const(int*)) because the type containing it is $(D const) becomes
    $(D int*) when Unconst is used on the containing type, because $(D const)
    is removed from the containing type. The member does not become
    $(D const(int)*) as would occur if Unconst were used directly on a
    $(D const(int*))).

    Also, Unconst has no effect on what a templated type is instantiated with,
    so if a templated type is instantiated with a template argument which is a
    const type, the template instantiation will not change.
  +/
version (StdDdoc) template Unconst(T)
{
    import core.internal.traits : CoreUnconst = Unconst;
    alias Unconst = CoreUnconst!T;
}
else
{
    import core.internal.traits : CoreUnconst = Unconst;
    alias Unconst = CoreUnconst;
}

///
@safe unittest
{
    static assert(is(Unconst!(                   int) == int));
    static assert(is(Unconst!(             const int) == int));
    static assert(is(Unconst!(       inout       int) == int));
    static assert(is(Unconst!(       inout const int) == int));
    static assert(is(Unconst!(shared             int) == shared int));
    static assert(is(Unconst!(shared       const int) == shared int));
    static assert(is(Unconst!(shared inout       int) == shared int));
    static assert(is(Unconst!(shared inout const int) == shared int));
    static assert(is(Unconst!(         immutable int) == int));

    // Only the outer layer of immutable is removed.
    // immutable(int[]) -> immutable(int)[]
    alias ImmIntArr = immutable(int[]);
    static assert(is(Unconst!ImmIntArr == immutable(int)[]));

    // Only the outer layer of const is removed.
    // immutable(int*) -> immutable(int)*
    alias ConstIntPtr = const(int*);
    static assert(is(Unconst!ConstIntPtr == const(int)*));

    // const(int)* -> const(int)*
    alias PtrToConstInt = const(int)*;
    static assert(is(Unconst!PtrToConstInt == const(int)*));

    static struct S
    {
        int* ptr;
    }

    const S s;
    static assert(is(typeof(s) == const S));
    static assert(is(typeof(typeof(s).ptr) == const int*));

    // For user-defined types, the const qualifier is removed entirely.
    // const S -> S
    static assert(is(Unconst!(typeof(s)) == S));
    static assert(is(typeof(Unconst!(typeof(s)).ptr) == int*));

    static struct Foo(T)
    {
        T* ptr;
    }

    // The qualifer on the type is removed, but the qualifier on the template
    // argument is not.
    static assert(is(Unconst!(const(Foo!(const int))) == Foo!(const int)));
    static assert(is(Unconst!(Foo!(const int)) == Foo!(const int)));
    static assert(is(Unconst!(const(Foo!int)) == Foo!int));
}

/++
    Removes the outer layer of $(D shared) from type $(D T).

    If $(D shared) has not been applied to the outer layer of type $(D T), then
    the result is $(D T).

    Note that while $(D immutable) is implicitly $(D shared), it is unaffected
    by Unshared. Only explict $(D shared) is removed.

    Due to limitations with D's type system, user-defined types have the type
    qualifier removed entirely if present. The types of the member variables
    themselves are unaffected beyond how removing the type qualifier from the
    type containing them affects them (e.g. an $(D int*) member that is
    $(D shared(int*)) because the type containing it is $(D shared) becomes
    $(D int*) when Unshared is used on the containing type, because $(D shared)
    is removed from the containing type. The member does not become
    $(D shared(int)*) as would occur if Unshared were used directly on a
    $(D shared(int*))).

    Also, Unshared has no effect on what a templated type is instantiated with,
    so if a templated type is instantiated with a template argument which is a
    shared type, the template instantiation will not change.
  +/
template Unshared(T)
{
    static if (is(T == shared U, U))
        alias Unshared = U;
    else
        alias Unshared = T;
}

///
@safe unittest
{
    static assert(is(Unshared!(                   int) == int));
    static assert(is(Unshared!(             const int) == const int));
    static assert(is(Unshared!(       inout       int) == inout int));
    static assert(is(Unshared!(       inout const int) == inout const int));
    static assert(is(Unshared!(shared             int) == int));
    static assert(is(Unshared!(shared       const int) == const int));
    static assert(is(Unshared!(shared inout       int) == inout int));
    static assert(is(Unshared!(shared inout const int) == inout const int));
    static assert(is(Unshared!(         immutable int) == immutable int));

    // Only the outer layer of shared is removed.
    // shared(int[]) -> shared(int)[]
    alias SharedIntArr = shared(int[]);
    static assert(is(Unshared!SharedIntArr == shared(int)[]));

    // Only the outer layer of shared is removed.
    // shared(int*) -> shared(int)*
    alias SharedIntPtr = shared(int*);
    static assert(is(Unshared!SharedIntPtr == shared(int)*));

    // shared(int)* -> shared(int)*
    alias PtrToSharedInt = shared(int)*;
    static assert(is(Unshared!PtrToSharedInt == shared(int)*));

    // immutable is unaffected
    alias ImmutableArr = immutable(int[]);
    static assert(is(Unshared!ImmutableArr == immutable(int[])));

    static struct S
    {
        int* ptr;
    }

    shared S s;
    static assert(is(typeof(s) == shared S));
    static assert(is(typeof(typeof(s).ptr) == shared int*));

    // For user-defined types, the shared qualifier is removed entirely.
    // shared S -> S
    static assert(is(Unshared!(typeof(s)) == S));
    static assert(is(typeof(Unshared!(typeof(s)).ptr) == int*));

    static struct Foo(T)
    {
        T* ptr;
    }

    // The qualifer on the type is affected, but the qualifier on the template
    // argument is not.
    static assert(is(Unshared!(shared(Foo!(shared int))) == Foo!(shared int)));
    static assert(is(Unshared!(Foo!(shared int)) == Foo!(shared int)));
    static assert(is(Unshared!(shared(Foo!int)) == Foo!int));
}

/++
    Removes the outer layer of all type qualifiers from type $(D T).

    If no type qualifiers have been applied to the outer layer of type $(D T),
    then the result is $(D T).

    Due to limitations with D's type system, user-defined types have the type
    qualifier removed entirely if present. The types of the member variables
    themselves are unaffected beyond how removing the type qualifier from the
    type containing them affects them (e.g. a $(D int*) member that is
    $(D const(int*)) because the type containing it is $(D const) becomes
    $(D int*) when Unqual is used on the containing type, because $(D const)
    is removed from the containing type. The member does not become
    $(D const(int)*) as would occur if Unqual were used directly on a
    $(D const(int*))).

    Also, Unqual has no effect on what a templated type is instantiated with,
    so if a templated type is instantiated with a template argument which has a
    type qualifier, the template instantiation will not change.

    Note that in most cases, $(LREF Unconst) or $(LREF Unshared) should be used
    rather than Unqual, because in most cases, code is not designed to work with
    $(D shared) and thus doing type checks which remove $(D shared) will allow
    $(D shared) types to pass template constraints when they won't actually
    work with the code. And when code is designed to work with $(D shared),
    it's often the case that the type checks need to take $(D const) into
    account to work properly.

    In particular, historically, a lot of D code has used Unqual when the
    programmer's intent was to remove $(D const), and $(D shared) wasn't
    actually considered at all. And in such cases, the code really should use
    $(LREF Unconst) instead.

    But of course, if a template constraint or $(D static if) really needs to
    strip off both the mutability qualifers and $(D shared) for what it's
    testing for, then that's what Unqual is for.
  +/
version (StdDdoc) template Unqual(T)
{
    import core.internal.traits : CoreUnqual = Unqual;
    alias Unqual = CoreUnqual!(T);
}
else
{
    import core.internal.traits : CoreUnqual = Unqual;
    alias Unqual = CoreUnqual;
}

@safe unittest
{
    static assert(is(Unqual!(                   int) == int));
    static assert(is(Unqual!(             const int) == int));
    static assert(is(Unqual!(       inout       int) == int));
    static assert(is(Unqual!(       inout const int) == int));
    static assert(is(Unqual!(shared             int) == int));
    static assert(is(Unqual!(shared       const int) == int));
    static assert(is(Unqual!(shared inout       int) == int));
    static assert(is(Unqual!(shared inout const int) == int));
    static assert(is(Unqual!(         immutable int) == int));

    // Only the outer layer of immutable is removed.
    // immutable(int[]) -> immutable(int)[]
    alias ImmIntArr = immutable(int[]);
    static assert(is(Unqual!ImmIntArr == immutable(int)[]));

    // Only the outer layer of const is removed.
    // const(int*) -> const(int)*
    alias ConstIntPtr = const(int*);
    static assert(is(Unqual!ConstIntPtr == const(int)*));

    // const(int)* -> const(int)*
    alias PtrToConstInt = const(int)*;
    static assert(is(Unqual!PtrToConstInt == const(int)*));

    // Only the outer layer of shared is removed.
    // shared(int*) -> shared(int)*
    alias SharedIntPtr = shared(int*);
    static assert(is(Unqual!SharedIntPtr == shared(int)*));

    // shared(int)* -> shared(int)*
    alias PtrToSharedInt = shared(int)*;
    static assert(is(Unqual!PtrToSharedInt == shared(int)*));

    // Both const and shared are removed from the outer layer.
    // shared const int[] -> shared(const(int))[]
    alias SharedConstIntArr = shared const(int[]);
    static assert(is(Unqual!SharedConstIntArr == shared(const(int))[]));

    static struct S
    {
        int* ptr;
    }

    shared const S s;
    static assert(is(typeof(s) == shared const S));
    static assert(is(typeof(typeof(s).ptr) == shared const int*));

    // For user-defined types, the qualifiers are removed entirely.
    // shared const S -> S
    static assert(is(Unqual!(typeof(s)) == S));
    static assert(is(typeof(Unqual!(typeof(s)).ptr) == int*));

    static struct Foo(T)
    {
        T* ptr;
    }

    // The qualifers on the type are affected, but the qualifiers on the
    // template argument is not.
    static assert(is(Unqual!(const(Foo!(const int))) == Foo!(const int)));
    static assert(is(Unqual!(Foo!(const int)) == Foo!(const int)));
    static assert(is(Unqual!(const(Foo!int)) == Foo!int));
}

/++
    Applies $(D const) to the given type.

    This is primarily useful in conjunction with templates that take a template
    predicate (such as many of the templates in lib.sys.meta), since while in
    most cases, you can simply do $(D const T) or $(D const(T)) to make $(D T)
    $(D const), with something like $(REF Map, lib, sys, meta), you need to
    pass a template to be applied.

    See_Also:
        $(LREF ImmutableOf)
        $(LREF InoutOf)
        $(LREF SharedOf)
  +/
alias ConstOf(T) = const T;

///
@safe unittest
{
    static assert(is(ConstOf!int == const int));
    static assert(is(ConstOf!(const int) == const int));
    static assert(is(ConstOf!(inout int) == inout const int));
    static assert(is(ConstOf!(shared int) == const shared int));

    // Note that const has no effect on immutable.
    static assert(is(ConstOf!(immutable int) == immutable int));

    import lib.sys.meta : AliasSeq, Map;

    alias Types = AliasSeq!(int, long,
                            bool*, ubyte[],
                            string, immutable(string));
    alias WithConst = Map!(ConstOf, Types);
    static assert(is(WithConst ==
                     AliasSeq!(const int, const long,
                               const(bool*), const(ubyte[]),
                               const(string), immutable(string))));
}

/++
    Applies $(D immutable) to the given type.

    This is primarily useful in conjunction with templates that take a template
    predicate (such as many of the templates in lib.sys.meta), since while in
    most cases, you can simply do $(D immutable T) or $(D immutable(T)) to make
    $(D T) $(D immutable), with something like $(REF Map, lib, sys, meta), you
    need to pass a template to be applied.

    See_Also:
        $(LREF ConstOf)
        $(LREF InoutOf)
        $(LREF SharedOf)
  +/
alias ImmutableOf(T) = immutable T;

///
@safe unittest
{
    static assert(is(ImmutableOf!int == immutable int));

    // Note that immutable overrides const and inout.
    static assert(is(ImmutableOf!(const int) == immutable int));
    static assert(is(ImmutableOf!(inout int) == immutable int));

    // Note that immutable overrides shared, since immutable is implicitly
    // shared.
    static assert(is(ImmutableOf!(shared int) == immutable int));

    static assert(is(ImmutableOf!(immutable int) == immutable int));

    import lib.sys.meta : AliasSeq, Map;

    alias Types = AliasSeq!(int, long,
                            bool*, ubyte[],
                            string, immutable(string));
    alias WithImmutable = Map!(ImmutableOf, Types);
    static assert(is(WithImmutable ==
                     AliasSeq!(immutable int, immutable long,
                               immutable(bool*), immutable(ubyte[]),
                               immutable(string), immutable(string))));
}

/++
    Applies $(D inout) to the given type.

    This is primarily useful in conjunction with templates that take a template
    predicate (such as many of the templates in lib.sys.meta), since while in
    most cases, you can simply do $(D inout T) or $(D inout(T)) to make $(D T)
    $(D inout), with something like $(REF Map, lib, sys, meta), you need to
    pass a template to be applied.

    See_Also:
        $(LREF ConstOf)
        $(LREF ImmutableOf)
        $(LREF SharedOf)
  +/
alias InoutOf(T) = inout T;

///
@safe unittest
{
    static assert(is(InoutOf!int == inout int));
    static assert(is(InoutOf!(const int) == inout const int));
    static assert(is(InoutOf!(inout int) == inout int));
    static assert(is(InoutOf!(shared int) == inout shared int));

    // Note that inout has no effect on immutable.
    static assert(is(InoutOf!(immutable int) == immutable int));

    import lib.sys.meta : AliasSeq, Map;

    alias Types = AliasSeq!(int, long,
                            bool*, ubyte[],
                            string, immutable(string));
    alias WithInout = Map!(InoutOf, Types);
    static assert(is(WithInout ==
                     AliasSeq!(inout int, inout long,
                               inout(bool*), inout(ubyte[]),
                               inout(string), immutable(string))));
}

/++
    Applies $(D shared) to the given type.

    This is primarily useful in conjunction with templates that take a template
    predicate (such as many of the templates in lib.sys.meta), since while in
    most cases, you can simply do $(D shared T) or $(D shared(T)) to make $(D T)
    $(D shared), with something like $(REF Map, lib, sys, meta), you need to
    pass a template to be applied.

    See_Also:
        $(LREF ConstOf)
        $(LREF ImmutableOf)
        $(LREF InoutOf)
  +/
alias SharedOf(T) = shared T;

///
@safe unittest
{
    static assert(is(SharedOf!int == shared int));
    static assert(is(SharedOf!(const int) == const shared int));
    static assert(is(SharedOf!(inout int) == inout shared int));
    static assert(is(SharedOf!(shared int) == shared int));

    // Note that shared has no effect on immutable, since immutable is
    // implicitly shared.
    static assert(is(SharedOf!(immutable int) == immutable int));

    import lib.sys.meta : AliasSeq, Map;

    alias Types = AliasSeq!(int, long,
                            bool*, ubyte[],
                            string, immutable(string));
    alias WithShared = Map!(SharedOf, Types);
    static assert(is(WithShared ==
                     AliasSeq!(shared int, shared long,
                               shared(bool*), shared(ubyte[]),
                               shared(string), immutable(string))));
}
