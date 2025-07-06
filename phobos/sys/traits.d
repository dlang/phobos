// Written in the D programming language
/++
    Templates which extract information about types and symbols at compile time.

    In the context of phobos.sys.traits, a "trait" is a template which provides
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

    Note that unless otherwise specified, the isXXXX and hasXXX traits in this
    module are checking for exact matches, so base types (e.g. with enums) and
    other implicit conversions do not factor into whether such traits are true
    or false. The type itself is being checked, not what it can be converted
    to.

    This is because these traits are often used in templated constraints, and
    having a type pass a template constraint based on an implicit conversion
    but then not have the implicit conversion actually take place (which it
    won't unless the template does something to force it internally) can lead
    to either compilation errors or subtle behavioral differences - and even
    when the conversion is done explicitly within a templated function, since
    it's not done at the call site, it can still lead to subtle bugs in some
    cases (e.g. if slicing a static array is involved).

    So, it's typically best to be explicit and clear about a template constraint
    accepting any kind of implicit conversion rather than having it buried in a
    trait where programmers stand a good chance of using the trait without
    realizing that enums might pass based on their base type - or that a type
    might pass based on some other implicit conversion.

    Regardless of what a trait is testing for, the documentation strives to be
    $(I very) clear about what the trait does, and of course, the names do try
    to make it clear as well - though obviously, only so much information can
    be put into a name, and some folks will misintrepret some symbols no matter
    how well they're named. So, please be sure that you clearly understand what
    these traits do when using them, since messing up template constraints can
    unfortunately be a great way to introduce subtle bugs into your program.
    Either way, of course, unit tests are your friends.

    $(SCRIPT inhibitQuickIndex = 1;)

    $(BOOKTABLE ,
    $(TR $(TH Category) $(TH Templates))
    $(TR $(TD Categories of types) $(TD
              $(LREF isAggregateType)
              $(LREF isDynamicArray)
              $(LREF isFloatingPoint)
              $(LREF isInstantiationOf)
              $(LREF isInteger)
              $(LREF isNumeric)
              $(LREF isPointer)
              $(LREF isSignedInteger)
              $(LREF isStaticArray)
              $(LREF isType)
              $(LREF isUnsignedInteger)
    ))
    $(TR $(TD Traits testing for type conversions) $(TD
              $(LREF isImplicitlyConvertible)
              $(LREF isQualifierConvertible)
    ))
    $(TR $(TD Traits for comparisons) $(TD
              $(LREF isEqual)
              $(LREF isSameSymbol)
              $(LREF isSameType)
    ))
    $(TR $(TD Function traits) $(TD
              $(LREF ToFunctionType)
    ))
    $(TR $(TD Aggregate Type Traits) $(TD
              $(LREF FieldNames)
              $(LREF FieldSymbols)
              $(LREF FieldTypes)
              $(LREF hasComplexAssignment)
              $(LREF hasComplexCopying)
              $(LREF hasComplexDestruction)
              $(LREF hasIndirections)
    ))
    $(TR $(TD General Types) $(TD
              $(LREF KeyType)
              $(LREF OriginalType)
              $(LREF PropertyType)
              $(LREF SymbolType)
              $(LREF ValueType)
    ))
    $(TR $(TD Traits for removing type qualfiers) $(TD
              $(LREF Unconst)
              $(LREF Unshared)
              $(LREF Unqualified)
    ))
    $(TR $(TD Type Constructors) $(TD
              $(LREF ConstOf)
              $(LREF ImmutableOf)
              $(LREF InoutOf)
              $(LREF SharedOf)
    ))
    $(TR $(TD Misc) $(TD
              $(LREF EnumMembers)
              $(LREF lvalueOf)
              $(LREF rvalueOf)
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
    Source:    $(PHOBOSSRC phobos/sys/traits)
+/
module phobos.sys.traits;

/++
    Whether the given type is an "aggregate type" - i.e. a struct, class,
    interface, or union. Enum types whose base type is an aggregate type are
    also considered aggregate types.
  +/
template isAggregateType(T)
{
    static if (is(T == enum))
        enum isAggregateType = isAggregateType!(OriginalType!T);
    else
        enum isAggregateType = is(T == struct) || is(T == class) || is(T == interface) || is(T == union);
}

///
@safe unittest
{
    struct S {}
    class C {}
    interface I {}
    union U {}

    static assert( isAggregateType!S);
    static assert( isAggregateType!C);
    static assert( isAggregateType!I);
    static assert( isAggregateType!U);
    static assert( isAggregateType!(const S));
    static assert( isAggregateType!(shared C));

    static assert(!isAggregateType!int);
    static assert(!isAggregateType!string);
    static assert(!isAggregateType!(S*));
    static assert(!isAggregateType!(C[]));
    static assert(!isAggregateType!(I[string]));

    enum ES : S { a = S.init }
    enum EC : C { a = C.init }
    enum EI : I { a = I.init }
    enum EU : U { a = U.init }

    static assert( isAggregateType!ES);
    static assert( isAggregateType!EC);
    static assert( isAggregateType!EI);
    static assert( isAggregateType!EU);
    static assert( isAggregateType!(const ES));
    static assert( isAggregateType!(const EC));
}

/++
    Whether the given type is a dynamic array (or what is sometimes referred to
    as a slice, since a dynamic array in D is a slice of memory).

    Note that this does not include implicit conversions or enum types. The
    type itself must be a dynamic array.

    Remember that D's dynamic arrays are essentially:
    ---
    struct DynamicArray(T)
    {
        size_t length;
        T* ptr;
    }
    ---
    where $(D ptr) points to the first element in the array, and $(D length) is
    the number of elements in the array.

    A dynamic array is not a pointer (unlike arrays in C/C++), and its elements
    do not live inside the dynamic array itself. The dynamic array is simply a
    slice of memory and does not own or manage its own memory. It can be a
    slice of any piece of memory, including GC-allocated memory, the stack,
    malloc-ed memory, etc. (with what kind of memory it is of course being
    determined by how the dynamic array was created in the first place)
    - though if you do any operations on it which end up requiring allocation
    (e.g. appending to it if it doesn't have the capacity to expand in-place,
    which it won't if it isn't a slice of GC-allocated memory), then that
    reallocation will result in the dynamic array being a slice of newly
    allocated, GC-backed memory (regardless of what it was a slice of before),
    since it's the GC that deals with those allocations.

    As long as code just accesses the elements or members of the dynamic array
    - or reduces its length so that it's a smaller slice - it will continue to
    point to whatever block of memory it pointed to originally. And because the
    GC makes sure that appending to a dynamic array does not stomp on the
    memory of any other dynamic arrays, appending to a dynamic array will not
    affect any other dynamic array which is a slice of that same block of
    memory whether a reallocation occurs or not.

    Regardless, since what allocated the memory that the dynamic array is a
    slice of is irrevelant to the type of the dynamic array, whether a given
    type is a dynamic array has nothing to do with the kind of memory that's
    backing it. A dynamic array which is a slice of a static array of $(D int)
    is the the same type as a dynamic array of $(D int) allocated with $(D new)
    - i.e. both are $(D int[]). So, this trait will not tell you anything about
    what kind of memory a dynamic array is a slice of. It just tells you
    whether the type is a dynamic array or not.

    If for some reason, it matters for a function what kind of memory backs one
    of its parameters which is a dynamic array, or it needs to be made clear
    whether the function will possibly cause that dynamic array to be
    reallocated, then that needs to be indicated by the documentation and
    cannot be enforced with a template constraint. A template constraint can
    enforce that a type used with a template meets certain criteria (e.g. that
    it's a dynamic array), but it cannot enforce anything about how the
    template actually uses the type.

    However, it $(D is) possible to enforce that a function doesn't use any
    operations on a dynamic array which might cause it to be reallocated by
    marking that function as $(D @nogc).

    In most cases though, code can be written to not care what kind of memory
    backs a dynamic array, because none of the operations on a dynamic array
    actually care what kind of memory it's a slice of. It mostly just matters
    when you need to track the lifetime of the memory, because it wasn't
    allocated by the GC, or when it matters whether a dynamic array could be
    reallocated or not (e.g. because the code needs to have that dynamic array
    continue to point to the same block of memory).

    See_Also:
        $(LREF isPointer)
        $(LREF isStaticArray)
        $(DDSUBLINK spec/arrays, , The language spec for arrays)
  +/
enum isDynamicArray(T) = is(T == U[], U);

///
@safe unittest
{
    // Some types which are dynamic arrays.
    static assert( isDynamicArray!(int[]));
    static assert( isDynamicArray!(const int[]));
    static assert( isDynamicArray!(inout int[]));
    static assert( isDynamicArray!(shared(int)[]));
    static assert( isDynamicArray!string);

    static assert( isDynamicArray!(typeof([1, 2, 3])));
    static assert( isDynamicArray!(typeof("dlang")));

    int[] arr;
    static assert( isDynamicArray!(typeof(arr)));

    // Some types which aren't dynamic arrays.
    static assert(!isDynamicArray!int);
    static assert(!isDynamicArray!(int*));
    static assert(!isDynamicArray!real);

    static struct S
    {
        int[] arr;
    }
    static assert(!isDynamicArray!S);

    // The struct itself isn't considered a dynamic array,
    // but its member variable is when checked directly.
    static assert( isDynamicArray!(typeof(S.arr)));

    // Static arrays.
    static assert(!isDynamicArray!(int[5]));
    static assert(!isDynamicArray!(const(int)[5]));

    int[2] sArr = [42, 97];
    static assert(!isDynamicArray!(typeof(sArr)));

    // While a static array is not a dynamic array,
    // a slice of a static array is a dynamic array.
    static assert( isDynamicArray!(typeof(sArr[])));

    // Dynamic array of static arrays.
    static assert( isDynamicArray!(long[3][]));

    // Static array of dynamic arrays.
    static assert(!isDynamicArray!(long[][3]));

    // Associative array.
    static assert(!isDynamicArray!(int[string]));

    // While typeof(null) gets treated as void[] in some contexts, it is
    // distinct from void[] and is not considered to be a dynamic array.
    static assert(!isDynamicArray!(typeof(null)));

    // However, naturally, if null is cast to a dynamic array, it's a
    // dynamic array, since the cast forces the type.
    static assert( isDynamicArray!(typeof(cast(int[]) null)));

    enum E : int[]
    {
        a = [1, 2, 3],
    }

    // Enums do not count.
    static assert(!isDynamicArray!E);

    static struct AliasThis
    {
        int[] arr;
        alias this = arr;
    }

    // Other implicit conversions do not count.
    static assert(!isDynamicArray!AliasThis);
}

@safe unittest
{
    import phobos.sys.meta : Alias, AliasSeq;

    static struct AliasThis(T)
    {
        T member;
        alias this = member;
    }

    foreach (Q; AliasSeq!(Alias, ConstOf, ImmutableOf, SharedOf))
    {
        foreach (T; AliasSeq!(int[], char[], string, long[3][], double[string][]))
        {
            enum E : Q!T { a = Q!T.init }

            static assert( isDynamicArray!(Q!T));
            static assert(!isDynamicArray!E);
            static assert(!isDynamicArray!(AliasThis!(Q!T)));
        }

        foreach (T; AliasSeq!(int, int[51], int[][2],
                              char[][int][11], immutable char[13u],
                              const(real)[1], const(real)[1][1], void[0]))
        {
            enum E : Q!T { a = Q!T.init }

            static assert(!isDynamicArray!(Q!T));
            static assert(!isDynamicArray!E);
            static assert(!isDynamicArray!(AliasThis!(Q!T)));
        }
    }
}

/++
    Whether type $(D T) is a static array.

    Note that this does not include implicit conversions or enum types. The
    type itself must be a static array. This is in contrast to
    $(D __traits(isStaticArray, T)) which is true for enums (but not for other
    implict conversions to static arrays).

    As explained in the module documentation, traits like this one are not true
    for enums (unlike most of the $(D __traits) traits) in order to avoid
    testing for implicit conversions by default with template constraints,
    since that tends to lead to subtle bugs when the code isn't carefully
    written to take implicit conversions into account.

    See also:
        $(DDSUBLINK spec/traits, isStaticArray, $(D __traits(isStaticArray, T)))
        $(DDSUBLINK spec/arrays, , The language spec for arrays)
  +/
enum isStaticArray(T) = is(T == U[n], U, size_t n);

///
@safe unittest
{
    // Some types which are static arrays.
    static assert( isStaticArray!(int[12]));
    static assert( isStaticArray!(const int[42]));
    static assert( isStaticArray!(inout int[0]));
    static assert( isStaticArray!(shared(int)[907]));
    static assert( isStaticArray!(immutable(char)[5]));

    // D doesn't have static array literals, but you get the same effect
    // by casting a dynamic array literal to a static array, and of course,
    // the result is typed as a static array.
    static assert( isStaticArray!(typeof(cast(int[3]) [1, 2, 3])));

    int[2] sArr = [1, 2];
    static assert( isStaticArray!(typeof(sArr)));

    // Some types which are not static arrays.
    static assert(!isStaticArray!int);
    static assert(!isStaticArray!(int*));
    static assert(!isStaticArray!real);

    static struct S
    {
        int[4] arr;
    }
    static assert(!isStaticArray!S);

    // The struct itself isn't considered a static array,
    // but its member variable is when checked directly.
    static assert( isStaticArray!(typeof(S.arr)));

    // Dynamic arrays.
    static assert(!isStaticArray!(int[]));
    static assert(!isStaticArray!(const(int)[]));
    static assert(!isStaticArray!string);

    int[] arr;
    static assert(!isStaticArray!(typeof(arr)));

    // A slice of a static array is of course not a static array,
    // because it's a dynamic array.
    static assert(!isStaticArray!(typeof(sArr[])));

    // Static array of dynamic arrays.
    static assert( isStaticArray!(long[][3]));

    // Dynamic array of static arrays.
    static assert(!isStaticArray!(long[3][]));

    // Associative array.
    static assert(!isStaticArray!(int[string]));

    // Of course, null is not considered to be a static array.
    static assert(!isStaticArray!(typeof(null)));

    enum E : int[3]
    {
        a = [1, 2, 3],
    }

    // Enums do not count.
    static assert(!isStaticArray!E);

    // This is where isStaticArray differs from __traits(isStaticArray, ...)
    static assert( __traits(isStaticArray, E));

    static struct AliasThis
    {
        int[] arr;
        alias this = arr;
    }

    // Other implicit conversions do not count.
    static assert(!isStaticArray!AliasThis);

    static assert(!__traits(isStaticArray, AliasThis));
}

@safe unittest
{
    import phobos.sys.meta : Alias, AliasSeq;

    static struct AliasThis(T)
    {
        T member;
        alias this = member;
    }

    foreach (Q; AliasSeq!(Alias, ConstOf, ImmutableOf, SharedOf))
    {
        foreach (T; AliasSeq!(int[51], int[][2],
                              char[][int][11], immutable char[13u],
                              const(real)[1], const(real)[1][1], void[0]))
        {
            enum E : Q!T { a = Q!T.init, }

            static assert( isStaticArray!(Q!T));
            static assert(!isStaticArray!E);
            static assert(!isStaticArray!(AliasThis!(Q!T)));
        }

        foreach (T; AliasSeq!(int, int[], char[], string, long[3][], double[string][]))
        {
            enum E : Q!T { a = Q!T.init, }

            static assert(!isStaticArray!(Q!T));
            static assert(!isStaticArray!E);
            static assert(!isStaticArray!(AliasThis!(Q!T)));
        }
    }
}

/++
    Whether the given type is one of the built-in integer types, ignoring all
    qualifiers.

    $(TABLE
        $(TR $(TH Integer Types))
        $(TR $(TD byte))
        $(TR $(TD ubyte))
        $(TR $(TD short))
        $(TR $(TD ushort))
        $(TR $(TD int))
        $(TR $(TD uint))
        $(TR $(TD long))
        $(TR $(TD ulong))
    )

    Note that this does not include implicit conversions or enum types. The
    type itself must be one of the built-in integer types.

    This trait does have some similarities with $(D __traits(isIntegral, T)),
    but $(D isIntegral) accepts a $(I lot) more types than isInteger does.
    isInteger is specifically for testing for the built-in integer types,
    whereas $(D isIntegral) tests for a whole set of types that are vaguely
    integer-like (including $(D bool), the three built-in character types, and
    some of the vector types from core.simd). So, for most code, isInteger is
    going to be more appropriate, but obviously, it depends on what the code is
    trying to do.

    See also:
        $(DDSUBLINK spec/traits, isIntegral, $(D __traits(isIntegral, T)))
        $(LREF isFloatingPoint)
        $(LREF isSignedInteger)
        $(LREF isNumeric)
        $(LREF isUnsignedInteger)
  +/
enum isInteger(T) = is(immutable T == immutable byte) ||
                    is(immutable T == immutable ubyte) ||
                    is(immutable T == immutable short) ||
                    is(immutable T == immutable ushort) ||
                    is(immutable T == immutable int) ||
                    is(immutable T == immutable uint) ||
                    is(immutable T == immutable long) ||
                    is(immutable T == immutable ulong);

///
@safe unittest
{
    // Some types which are integer types.
    static assert( isInteger!byte);
    static assert( isInteger!ubyte);
    static assert( isInteger!short);
    static assert( isInteger!ushort);
    static assert( isInteger!int);
    static assert( isInteger!uint);
    static assert( isInteger!long);
    static assert( isInteger!ulong);

    static assert( isInteger!(const ubyte));
    static assert( isInteger!(immutable short));
    static assert( isInteger!(inout int));
    static assert( isInteger!(shared uint));
    static assert( isInteger!(const shared ulong));

    static assert( isInteger!(typeof(42)));
    static assert( isInteger!(typeof(1234567890L)));

    int i;
    static assert( isInteger!(typeof(i)));

    // Some types which aren't integer types.
    static assert(!isInteger!bool);
    static assert(!isInteger!char);
    static assert(!isInteger!wchar);
    static assert(!isInteger!dchar);
    static assert(!isInteger!(int[]));
    static assert(!isInteger!(ubyte[4]));
    static assert(!isInteger!(int*));
    static assert(!isInteger!double);
    static assert(!isInteger!string);

    static struct S
    {
        int i;
    }
    static assert(!isInteger!S);

    // The struct itself isn't considered an integer,
    // but its member variable is when checked directly.
    static assert( isInteger!(typeof(S.i)));

    enum E : int
    {
        a = 42
    }

    // Enums do not count.
    static assert(!isInteger!E);

    static struct AliasThis
    {
        int i;
        alias this = i;
    }

    // Other implicit conversions do not count.
    static assert(!isInteger!AliasThis);
}

@safe unittest
{
    import phobos.sys.meta : Alias, AliasSeq;

    static struct AliasThis(T)
    {
        T member;
        alias this = member;
    }

    // The actual core.simd types available vary from system to system, so we
    // have to be a bit creative here. The reason that we're testing these types
    // is because __traits(isIntegral, T) accepts them, but isInteger is not
    // supposed to.
    template SIMDTypes()
    {
        import core.simd;

        alias SIMDTypes = AliasSeq!();
        static if (is(ubyte16))
            SIMDTypes = AliasSeq!(SIMDTypes, ubyte16);
        static if (is(int4))
            SIMDTypes = AliasSeq!(SIMDTypes, int4);
        static if (is(double2))
            SIMDTypes = AliasSeq!(SIMDTypes, double2);
        static if (is(void16))
            SIMDTypes = AliasSeq!(SIMDTypes, void16);
    }

    foreach (Q; AliasSeq!(Alias, ConstOf, ImmutableOf, SharedOf))
    {
        foreach (T; AliasSeq!(byte, ubyte, short, ushort, int, uint, long, ulong))
        {
            enum E : Q!T { a = Q!T.init }

            static assert( isInteger!(Q!T));
            static assert(!isInteger!E);
            static assert(!isInteger!(AliasThis!(Q!T)));
        }

        foreach (T; AliasSeq!(bool, char, wchar, dchar, float, double, real, SIMDTypes!(),
                              int[], ubyte[8], dchar[], void[], long*))
        {
            enum E : Q!T { a = Q!T.init }

            static assert(!isInteger!(Q!T));
            static assert(!isInteger!E);
            static assert(!isInteger!(AliasThis!(Q!T)));
        }
    }
}

/++
    Whether the given type is one of the built-in signed integer types, ignoring
    all qualifiers.

    $(TABLE
        $(TR $(TH Signed Integer Types))
        $(TR $(TD byte))
        $(TR $(TD short))
        $(TR $(TD int))
        $(TR $(TD long))
    )

    Note that this does not include implicit conversions or enum types. The
    type itself must be one of the built-in signed integer types.

    See also:
        $(LREF isFloatingPoint)
        $(LREF isInteger)
        $(LREF isNumeric)
        $(LREF isUnsignedInteger)
  +/
enum isSignedInteger(T) = is(immutable T == immutable byte) ||
                          is(immutable T == immutable short) ||
                          is(immutable T == immutable int) ||
                          is(immutable T == immutable long);

///
@safe unittest
{
    // Some types which are signed integer types.
    static assert( isSignedInteger!byte);
    static assert( isSignedInteger!short);
    static assert( isSignedInteger!int);
    static assert( isSignedInteger!long);

    static assert( isSignedInteger!(const byte));
    static assert( isSignedInteger!(immutable short));
    static assert( isSignedInteger!(inout int));
    static assert( isSignedInteger!(shared int));
    static assert( isSignedInteger!(const shared long));

    static assert( isSignedInteger!(typeof(42)));
    static assert( isSignedInteger!(typeof(1234567890L)));

    int i;
    static assert( isSignedInteger!(typeof(i)));

    // Some types which aren't signed integer types.
    static assert(!isSignedInteger!ubyte);
    static assert(!isSignedInteger!ushort);
    static assert(!isSignedInteger!uint);
    static assert(!isSignedInteger!ulong);

    static assert(!isSignedInteger!bool);
    static assert(!isSignedInteger!char);
    static assert(!isSignedInteger!wchar);
    static assert(!isSignedInteger!dchar);
    static assert(!isSignedInteger!(int[]));
    static assert(!isSignedInteger!(ubyte[4]));
    static assert(!isSignedInteger!(int*));
    static assert(!isSignedInteger!double);
    static assert(!isSignedInteger!string);

    static struct S
    {
        int i;
    }
    static assert(!isSignedInteger!S);

    // The struct itself isn't considered a signed integer,
    // but its member variable is when checked directly.
    static assert( isSignedInteger!(typeof(S.i)));

    enum E : int
    {
        a = 42
    }

    // Enums do not count.
    static assert(!isSignedInteger!E);

    static struct AliasThis
    {
        int i;
        alias this = i;
    }

    // Other implicit conversions do not count.
    static assert(!isSignedInteger!AliasThis);
}

@safe unittest
{
    import phobos.sys.meta : Alias, AliasSeq;

    static struct AliasThis(T)
    {
        T member;
        alias this = member;
    }

    // The actual core.simd types available vary from system to system, so we
    // have to be a bit creative here. The reason that we're testing these types
    // is because __traits(isIntegral, T) accepts them, but isSignedInteger is
    // not supposed to.
    template SIMDTypes()
    {
        import core.simd;

        alias SIMDTypes = AliasSeq!();
        static if (is(ubyte16))
            SIMDTypes = AliasSeq!(SIMDTypes, ubyte16);
        static if (is(int4))
            SIMDTypes = AliasSeq!(SIMDTypes, int4);
        static if (is(double2))
            SIMDTypes = AliasSeq!(SIMDTypes, double2);
        static if (is(void16))
            SIMDTypes = AliasSeq!(SIMDTypes, void16);
    }

    foreach (Q; AliasSeq!(Alias, ConstOf, ImmutableOf, SharedOf))
    {
        foreach (T; AliasSeq!(byte, short, int, long))
        {
            enum E : Q!T { a = Q!T.init }

            static assert( isSignedInteger!(Q!T));
            static assert(!isSignedInteger!E);
            static assert(!isSignedInteger!(AliasThis!(Q!T)));
        }

        foreach (T; AliasSeq!(ubyte, ushort, uint, ulong,
                              bool, char, wchar, dchar, float, double, real, SIMDTypes!(),
                              int[], ubyte[8], dchar[], void[], long*))
        {
            enum E : Q!T { a = Q!T.init }

            static assert(!isSignedInteger!(Q!T));
            static assert(!isSignedInteger!E);
            static assert(!isSignedInteger!(AliasThis!(Q!T)));
        }
    }
}

/++
    Whether the given type is one of the built-in unsigned integer types,
    ignoring all qualifiers.

    $(TABLE
        $(TR $(TH Integer Types))
        $(TR $(TD ubyte))
        $(TR $(TD ushort))
        $(TR $(TD uint))
        $(TR $(TD ulong))
    )

    Note that this does not include implicit conversions or enum types. The
    type itself must be one of the built-in unsigned integer types.

    This trait does have some similarities with $(D __traits(isUnsigned, T)),
    but $(D isUnsigned) accepts a $(I lot) more types than isUnsignedInteger
    does. isUnsignedInteger is specifically for testing for the built-in
    unsigned integer types, whereas $(D isUnsigned) tests for a whole set of
    types that are unsigned and vaguely integer-like (including $(D bool), the
    three built-in character types, and some of the vector types from
    core.simd). So, for most code, isUnsignedInteger is going to be more
    appropriate, but obviously, it depends on what the code is trying to do.

    See also:
        $(DDSUBLINK spec/traits, isUnsigned, $(D __traits(isUnsigned, T)))
        $(LREF isFloatingPoint)
        $(LREF isInteger)
        $(LREF isSignedInteger)
        $(LREF isNumeric)
  +/
enum isUnsignedInteger(T) = is(immutable T == immutable ubyte) ||
                            is(immutable T == immutable ushort) ||
                            is(immutable T == immutable uint) ||
                            is(immutable T == immutable ulong);

///
@safe unittest
{
    // Some types which are unsigned integer types.
    static assert( isUnsignedInteger!ubyte);
    static assert( isUnsignedInteger!ushort);
    static assert( isUnsignedInteger!uint);
    static assert( isUnsignedInteger!ulong);

    static assert( isUnsignedInteger!(const ubyte));
    static assert( isUnsignedInteger!(immutable ushort));
    static assert( isUnsignedInteger!(inout uint));
    static assert( isUnsignedInteger!(shared uint));
    static assert( isUnsignedInteger!(const shared ulong));

    static assert( isUnsignedInteger!(typeof(42u)));
    static assert( isUnsignedInteger!(typeof(1234567890UL)));

    uint u;
    static assert( isUnsignedInteger!(typeof(u)));

    // Some types which aren't unsigned integer types.
    static assert(!isUnsignedInteger!byte);
    static assert(!isUnsignedInteger!short);
    static assert(!isUnsignedInteger!int);
    static assert(!isUnsignedInteger!long);

    static assert(!isUnsignedInteger!bool);
    static assert(!isUnsignedInteger!char);
    static assert(!isUnsignedInteger!wchar);
    static assert(!isUnsignedInteger!dchar);
    static assert(!isUnsignedInteger!(int[]));
    static assert(!isUnsignedInteger!(ubyte[4]));
    static assert(!isUnsignedInteger!(int*));
    static assert(!isUnsignedInteger!double);
    static assert(!isUnsignedInteger!string);

    static struct S
    {
        uint u;
    }
    static assert(!isUnsignedInteger!S);

    // The struct itself isn't considered an unsigned integer,
    // but its member variable is when checked directly.
    static assert( isUnsignedInteger!(typeof(S.u)));

    enum E : uint
    {
        a = 42
    }

    // Enums do not count.
    static assert(!isUnsignedInteger!E);

    static struct AliasThis
    {
        uint u;
        alias this = u;
    }

    // Other implicit conversions do not count.
    static assert(!isUnsignedInteger!AliasThis);
}

@safe unittest
{
    import phobos.sys.meta : Alias, AliasSeq;

    static struct AliasThis(T)
    {
        T member;
        alias this = member;
    }

    // The actual core.simd types available vary from system to system, so we
    // have to be a bit creative here. The reason that we're testing these types
    // is because __traits(isIntegral, T) and __traits(isUnsigned, T) accept
    // them, but isUnsignedInteger is not supposed to.
    template SIMDTypes()
    {
        import core.simd;

        alias SIMDTypes = AliasSeq!();
        static if (is(ubyte16))
            SIMDTypes = AliasSeq!(SIMDTypes, ubyte16);
        static if (is(int4))
            SIMDTypes = AliasSeq!(SIMDTypes, int4);
        static if (is(double2))
            SIMDTypes = AliasSeq!(SIMDTypes, double2);
        static if (is(void16))
            SIMDTypes = AliasSeq!(SIMDTypes, void16);
    }

    foreach (Q; AliasSeq!(Alias, ConstOf, ImmutableOf, SharedOf))
    {
        foreach (T; AliasSeq!(ubyte, ushort, uint, ulong))
        {
            enum E : Q!T { a = Q!T.init }

            static assert( isUnsignedInteger!(Q!T));
            static assert(!isUnsignedInteger!E);
            static assert(!isUnsignedInteger!(AliasThis!(Q!T)));
        }

        foreach (T; AliasSeq!(byte, short, int, long,
                              bool, char, wchar, dchar, float, double, real, SIMDTypes!(),
                              int[], ubyte[8], dchar[], void[], long*))
        {
            enum E : Q!T { a = Q!T.init }

            static assert(!isUnsignedInteger!(Q!T));
            static assert(!isUnsignedInteger!E);
            static assert(!isUnsignedInteger!(AliasThis!(Q!T)));
        }
    }
}

/++
    Whether the given type is one of the built-in floating-point types, ignoring
    all qualifiers.

    $(TABLE
        $(TR $(TH Floating-Point Types))
        $(TR $(TD float))
        $(TR $(TD double))
        $(TR $(TD real))
    )

    Note that this does not include implicit conversions or enum types. The
    type itself must be one of the built-in floating-point types.

    This trait does have some similarities with $(D __traits(isFloating, T)),
    but $(D isFloating) accepts more types than isFloatingPoint does.
    isFloatingPoint is specifically for testing for the built-in floating-point
    types, whereas $(D isFloating) tests for a whole set of types that are
    vaguely float-like (including enums with a base type which is a
    floating-point type and some of the vector types from core.simd). So, for
    most code, isFloatingPoint is going to be more appropriate, but obviously,
    it depends on what the code is trying to do.

    See also:
        $(DDSUBLINK spec/traits, isFloating, $(D __traits(isFloating, T)))
        $(LREF isInteger)
        $(LREF isSignedInteger)
        $(LREF isNumeric)
        $(LREF isUnsignedInteger)
  +/
enum isFloatingPoint(T) = is(immutable T == immutable float) ||
                          is(immutable T == immutable double) ||
                          is(immutable T == immutable real);

///
@safe unittest
{
    // Some types which are floating-point types.
    static assert( isFloatingPoint!float);
    static assert( isFloatingPoint!double);
    static assert( isFloatingPoint!real);

    static assert( isFloatingPoint!(const float));
    static assert( isFloatingPoint!(immutable float));
    static assert( isFloatingPoint!(inout double));
    static assert( isFloatingPoint!(shared double));
    static assert( isFloatingPoint!(const shared real));

    static assert( isFloatingPoint!(typeof(42.0)));
    static assert( isFloatingPoint!(typeof(42f)));
    static assert( isFloatingPoint!(typeof(1e5)));
    static assert( isFloatingPoint!(typeof(97.4L)));

    double d;
    static assert( isFloatingPoint!(typeof(d)));

    // Some types which aren't floating-point types.
    static assert(!isFloatingPoint!bool);
    static assert(!isFloatingPoint!char);
    static assert(!isFloatingPoint!dchar);
    static assert(!isFloatingPoint!int);
    static assert(!isFloatingPoint!long);
    static assert(!isFloatingPoint!(float[]));
    static assert(!isFloatingPoint!(double[4]));
    static assert(!isFloatingPoint!(real*));
    static assert(!isFloatingPoint!string);

    static struct S
    {
        double d;
    }
    static assert(!isFloatingPoint!S);

    // The struct itself isn't considered a floating-point type,
    // but its member variable is when checked directly.
    static assert( isFloatingPoint!(typeof(S.d)));

    enum E : double
    {
        a = 12.34
    }

    // Enums do not count.
    static assert(!isFloatingPoint!E);

    static struct AliasThis
    {
        double d;
        alias this = d;
    }

    // Other implicit conversions do not count.
    static assert(!isFloatingPoint!AliasThis);
}

@safe unittest
{
    import phobos.sys.meta : Alias, AliasSeq;

    static struct AliasThis(T)
    {
        T member;
        alias this = member;
    }

    // The actual core.simd types available vary from system to system, so we
    // have to be a bit creative here. The reason that we're testing these types
    // is because __traits(isFloating, T) accepts them, but isFloatingPoint is
    // not supposed to.
    template SIMDTypes()
    {
        import core.simd;

        alias SIMDTypes = AliasSeq!();
        static if (is(int4))
            SIMDTypes = AliasSeq!(SIMDTypes, int4);
        static if (is(double2))
            SIMDTypes = AliasSeq!(SIMDTypes, double2);
        static if (is(void16))
            SIMDTypes = AliasSeq!(SIMDTypes, void16);
    }

    foreach (Q; AliasSeq!(Alias, ConstOf, ImmutableOf, SharedOf))
    {
        foreach (T; AliasSeq!(float, double, real))
        {
            enum E : Q!T { a = Q!T.init }

            static assert( isFloatingPoint!(Q!T));
            static assert(!isFloatingPoint!E);
            static assert(!isFloatingPoint!(AliasThis!(Q!T)));
        }

        foreach (T; AliasSeq!(bool, char, wchar, dchar, byte, ubyte, short, ushort,
                              int, uint, long, ulong, SIMDTypes!(),
                              int[], float[8], real[], void[], double*))
        {
            enum E : Q!T { a = Q!T.init }

            static assert(!isFloatingPoint!(Q!T));
            static assert(!isFloatingPoint!E);
            static assert(!isFloatingPoint!(AliasThis!(Q!T)));
        }
    }
}

/++
    Whether the given type is one of the built-in numeric types, ignoring all
    qualifiers. It's equivalent to $(D isInteger!T || isFloatingPoint!T), but
    it only involves a single template instantation instead of two.

    $(TABLE
        $(TR $(TH Numeric Types))
        $(TR $(TD byte))
        $(TR $(TD ubyte))
        $(TR $(TD short))
        $(TR $(TD ushort))
        $(TR $(TD int))
        $(TR $(TD uint))
        $(TR $(TD long))
        $(TR $(TD ulong))
        $(TR $(TD float))
        $(TR $(TD double))
        $(TR $(TD real))
    )

    Note that this does not include implicit conversions or enum types. The
    type itself must be one of the built-in numeric types.

    See_Also:
        $(LREF isFloatingPoint)
        $(LREF isInteger)
        $(LREF isSignedInteger)
        $(LREF isUnsignedInteger)
  +/
enum isNumeric(T) = is(immutable T == immutable byte) ||
                    is(immutable T == immutable ubyte) ||
                    is(immutable T == immutable short) ||
                    is(immutable T == immutable ushort) ||
                    is(immutable T == immutable int) ||
                    is(immutable T == immutable uint) ||
                    is(immutable T == immutable long) ||
                    is(immutable T == immutable ulong) ||
                    is(immutable T == immutable float) ||
                    is(immutable T == immutable double) ||
                    is(immutable T == immutable real);

///
@safe unittest
{
    // Some types which are numeric types.
    static assert( isNumeric!byte);
    static assert( isNumeric!ubyte);
    static assert( isNumeric!short);
    static assert( isNumeric!ushort);
    static assert( isNumeric!int);
    static assert( isNumeric!uint);
    static assert( isNumeric!long);
    static assert( isNumeric!ulong);
    static assert( isNumeric!float);
    static assert( isNumeric!double);
    static assert( isNumeric!real);

    static assert( isNumeric!(const short));
    static assert( isNumeric!(immutable int));
    static assert( isNumeric!(inout uint));
    static assert( isNumeric!(shared long));
    static assert( isNumeric!(const shared real));

    static assert( isNumeric!(typeof(42)));
    static assert( isNumeric!(typeof(1234657890L)));
    static assert( isNumeric!(typeof(42.0)));
    static assert( isNumeric!(typeof(42f)));
    static assert( isNumeric!(typeof(1e5)));
    static assert( isNumeric!(typeof(97.4L)));

    int i;
    static assert( isNumeric!(typeof(i)));

    // Some types which aren't numeric types.
    static assert(!isNumeric!bool);
    static assert(!isNumeric!char);
    static assert(!isNumeric!dchar);
    static assert(!isNumeric!(int[]));
    static assert(!isNumeric!(double[4]));
    static assert(!isNumeric!(real*));
    static assert(!isNumeric!string);

    static struct S
    {
        int i;
    }
    static assert(!isNumeric!S);

    // The struct itself isn't considered a numeric type,
    // but its member variable is when checked directly.
    static assert( isNumeric!(typeof(S.i)));

    enum E : int
    {
        a = 42
    }

    // Enums do not count.
    static assert(!isNumeric!E);

    static struct AliasThis
    {
        int i;
        alias this = i;
    }

    // Other implicit conversions do not count.
    static assert(!isNumeric!AliasThis);
}

@safe unittest
{
    import phobos.sys.meta : Alias, AliasSeq;

    static struct AliasThis(T)
    {
        T member;
        alias this = member;
    }

    // The actual core.simd types available vary from system to system, so we
    // have to be a bit creative here. The reason that we're testing these types
    // is because __traits(isInteger, T) and __traits(isFloating, T) accept
    // them, but isNumeric is not supposed to.
    template SIMDTypes()
    {
        import core.simd;

        alias SIMDTypes = AliasSeq!();
        static if (is(int4))
            SIMDTypes = AliasSeq!(SIMDTypes, int4);
        static if (is(double2))
            SIMDTypes = AliasSeq!(SIMDTypes, double2);
        static if (is(void16))
            SIMDTypes = AliasSeq!(SIMDTypes, void16);
    }

    foreach (Q; AliasSeq!(Alias, ConstOf, ImmutableOf, SharedOf))
    {
        foreach (T; AliasSeq!(byte, ubyte, short, ushort, int, uint, long, ulong, float, double, real))
        {
            enum E : Q!T { a = Q!T.init }

            static assert( isNumeric!(Q!T));
            static assert(!isNumeric!E);
            static assert(!isNumeric!(AliasThis!(Q!T)));
        }

        foreach (T; AliasSeq!(bool, char, wchar, dchar, SIMDTypes!(),
                              int[], float[8], real[], void[], double*))
        {
            enum E : Q!T { a = Q!T.init }

            static assert(!isNumeric!(Q!T));
            static assert(!isNumeric!E);
            static assert(!isNumeric!(AliasThis!(Q!T)));
        }
    }
}

/++
    Whether the given type is a pointer.

    Note that this does not include implicit conversions or enum types. The
    type itself must be a pointer.

    Also, remember that unlike C/C++, D's arrays are not pointers. Rather, a
    dynamic array in D is a slice of memory which has a member which is a
    pointer to its first element and another member which is the length of the
    array as $(D size_t). So, a dynamic array / slice has a $(D ptr) member
    which is a pointer, but the dynamic array itself is not a pointer.

    See_Also:
        $(LREF isDynamicArray)
  +/
enum isPointer(T) = is(T == U*, U);

///
@system unittest
{
    // Some types which are pointers.
    static assert( isPointer!(bool*));
    static assert( isPointer!(int*));
    static assert( isPointer!(int**));
    static assert( isPointer!(real*));
    static assert( isPointer!(string*));

    static assert( isPointer!(const int*));
    static assert( isPointer!(immutable int*));
    static assert( isPointer!(inout int*));
    static assert( isPointer!(shared int*));
    static assert( isPointer!(const shared int*));

    static assert( isPointer!(typeof("foobar".ptr)));

    int* ptr;
    static assert( isPointer!(typeof(ptr)));

    int i;
    static assert( isPointer!(typeof(&i)));

    // Some types which aren't pointers.
    static assert(!isPointer!bool);
    static assert(!isPointer!int);
    static assert(!isPointer!dchar);
    static assert(!isPointer!(int[]));
    static assert(!isPointer!(double[4]));
    static assert(!isPointer!string);

    static struct S
    {
        int* ptr;
    }
    static assert(!isPointer!S);

    // The struct itself isn't considered a numeric type,
    // but its member variable is when checked directly.
    static assert( isPointer!(typeof(S.ptr)));

    enum E : immutable(char*)
    {
        a = "foobar".ptr
    }

    // Enums do not count.
    static assert(!isPointer!E);

    static struct AliasThis
    {
        int* ptr;
        alias this = ptr;
    }

    // Other implicit conversions do not count.
    static assert(!isPointer!AliasThis);
}

@safe unittest
{
    import phobos.sys.meta : Alias, AliasSeq;

    static struct AliasThis(T)
    {
        T member;
        alias this = member;
    }

    static struct S
    {
        int i;
    }

    foreach (Q; AliasSeq!(Alias, ConstOf, ImmutableOf, SharedOf))
    {
        foreach (T; AliasSeq!(long*, S*, S**, S***, double[]*))
        {
            enum E : Q!T { a = Q!T.init }

            static assert( isPointer!(Q!T));
            static assert(!isPointer!E);
            static assert(!isPointer!(AliasThis!(Q!T)));
        }

        foreach (T; AliasSeq!(bool, char, wchar, dchar, byte, int, uint, long,
                              int[], float[8], real[], void[]))
        {
            enum E : Q!T { a = Q!T.init }

            static assert(!isPointer!(Q!T));
            static assert(!isPointer!E);
            static assert(!isPointer!(AliasThis!(Q!T)));
        }
    }
}

/++
    Evaluates to $(D true) if given a type and $(D false) for all other symbols.

    This is equivalent to $(D is(T)), but some people may find using a named
    trait to be clearer, and it can be used in conjunction with templates that
    take a template predicate (such as those in phobos.sys.meta), which can't
    be done with naked is expressions.

    See_Also:
        $(DDSUBLINK dlang.org/spec/expression.html, is-type, Spec on the related is expression)
  +/
enum isType(T) = true;

/// Ditto
enum isType(alias sym) = false;

///
@safe unittest
{
    static assert( isType!int);
    static assert( isType!(int[]));
    static assert( isType!string);
    static assert( isType!(int[int]));
    static assert( isType!(ubyte*));
    static assert( isType!void);

    int i;
    static assert(!isType!i);
    static assert( isType!(typeof(i)));

    struct S {}
    static assert( isType!S);
    static assert(!isType!(S.init));

    class C {}
    static assert( isType!C);
    static assert(!isType!(C.init));

    interface I {}
    static assert( isType!I);
    static assert(!isType!(I.init));

    union U {}
    static assert( isType!U);
    static assert(!isType!(U.init));

    static void func() {}
    static assert(!isType!func);
    static assert( isType!(typeof(func)));

    void funcWithContext() { ++i; }
    static assert(!isType!funcWithContext);
    static assert( isType!(typeof(funcWithContext)));

    int function() funcPtr;
    static assert(!isType!funcPtr);
    static assert( isType!(typeof(funcPtr)));

    int delegate() del;
    static assert(!isType!del);
    static assert( isType!(typeof(del)));

    template Templ() {}
    static assert(!isType!Templ);
    static assert(!isType!(Templ!()));

    template TemplWithType()
    {
        struct S {}
    }
    static assert(!isType!TemplWithType);
    static assert(!isType!(TemplWithType!()));
    static assert( isType!(TemplWithType!().S));

    struct TemplType() {}
    static assert(!isType!TemplType);
    static assert( isType!(TemplType!()));
}

/++
    Evaluates to $(D true) if the given type or symbol is an instantiation of
    the given template.

    The overload which takes $(D T) operates on types and indicates whether an
    aggregate type (i.e. struct, class, interface, or union) is an
    instantiation of the given template.

    The overload which takes $(D Symbol) operates on function templates,
    because unlike with aggregate types, the type of a function does not retain
    the fact that it was instantiated from a template. So, for functions, it's
    necessary to pass the function itself as a symbol rather than pass the type
    of the function.

    The overload which takes $(D Symbol) also works with templates which are
    not types or functions.

    The single-argument overload makes it so that it can be partially
    instantiated with the first argument, which will often be necessary with
    template predicates.
  +/
template isInstantiationOf(alias Template, T)
if (__traits(isTemplate, Template))
{
    enum isInstantiationOf = is(T == Template!Args, Args...);
}

/++ Ditto +/
template isInstantiationOf(alias Template, alias Symbol)
if (__traits(isTemplate, Template))
{
    enum impl(alias T : Template!Args, Args...) = true;
    enum impl(alias T) = false;
    enum isInstantiationOf = impl!Symbol;
}

/++ Ditto +/
template isInstantiationOf(alias Template)
if (__traits(isTemplate, Template))
{
    enum isInstantiationOf(T) = is(T == Template!Args, Args...);

    template isInstantiationOf(alias Symbol)
    {
        enum impl(alias T : Template!Args, Args...) = true;
        enum impl(alias T) = false;
        enum isInstantiationOf = impl!Symbol;
    }
}

/// Examples of templated types.
@safe unittest
{
    static struct S(T) {}
    static class C(T) {}

    static assert( isInstantiationOf!(S, S!int));
    static assert( isInstantiationOf!(S, S!int));
    static assert( isInstantiationOf!(S, S!string));
    static assert( isInstantiationOf!(S, const S!string));
    static assert( isInstantiationOf!(S, shared S!string));
    static assert(!isInstantiationOf!(S, int));
    static assert(!isInstantiationOf!(S, C!int));
    static assert(!isInstantiationOf!(S, C!string));
    static assert(!isInstantiationOf!(S, C!(S!int)));

    static assert( isInstantiationOf!(C, C!int));
    static assert( isInstantiationOf!(C, C!string));
    static assert( isInstantiationOf!(C, const C!string));
    static assert( isInstantiationOf!(C, shared C!string));
    static assert(!isInstantiationOf!(C, int));
    static assert(!isInstantiationOf!(C, S!int));
    static assert(!isInstantiationOf!(C, S!string));
    static assert(!isInstantiationOf!(C, S!(C!int)));

    static struct Variadic(T...) {}

    static assert( isInstantiationOf!(Variadic, Variadic!()));
    static assert( isInstantiationOf!(Variadic, Variadic!int));
    static assert( isInstantiationOf!(Variadic, Variadic!(int, string)));
    static assert( isInstantiationOf!(Variadic, Variadic!(int, string, int)));
    static assert( isInstantiationOf!(Variadic, const Variadic!(int, short)));
    static assert( isInstantiationOf!(Variadic, shared Variadic!(int, short)));
    static assert(!isInstantiationOf!(Variadic, int));
    static assert(!isInstantiationOf!(Variadic, S!int));
    static assert(!isInstantiationOf!(Variadic, C!int));

    static struct ValueArg(int i) {}
    static assert( isInstantiationOf!(ValueArg, ValueArg!42));
    static assert( isInstantiationOf!(ValueArg, ValueArg!256));
    static assert( isInstantiationOf!(ValueArg, const ValueArg!1024));
    static assert( isInstantiationOf!(ValueArg, shared ValueArg!1024));
    static assert(!isInstantiationOf!(ValueArg, int));
    static assert(!isInstantiationOf!(ValueArg, S!int));

    int i;

    static struct AliasArg(alias Symbol) {}
    static assert( isInstantiationOf!(AliasArg, AliasArg!42));
    static assert( isInstantiationOf!(AliasArg, AliasArg!int));
    static assert( isInstantiationOf!(AliasArg, AliasArg!i));
    static assert( isInstantiationOf!(AliasArg, const AliasArg!i));
    static assert( isInstantiationOf!(AliasArg, shared AliasArg!i));
    static assert(!isInstantiationOf!(AliasArg, int));
    static assert(!isInstantiationOf!(AliasArg, S!int));

    // An uninstantiated template is not an instance of any template,
    // not even itself.
    static assert(!isInstantiationOf!(S, S));
    static assert(!isInstantiationOf!(S, C));
    static assert(!isInstantiationOf!(C, C));
    static assert(!isInstantiationOf!(C, S));

    // Variables of a templated type are not considered instantiations of that
    // type. For templated types, the overload which takes a type must be used.
    S!int s;
    C!string c;
    static assert(!isInstantiationOf!(S, s));
    static assert(!isInstantiationOf!(C, c));
}

// Examples of templated functions.
@safe unittest
{
    static int foo(T...)() { return 42; }
    static void bar(T...)(T var) {}
    static void baz(T)(T var) {}
    static bool frobozz(alias pred)(int) { return true; }

    static assert( isInstantiationOf!(foo, foo!int));
    static assert( isInstantiationOf!(foo, foo!string));
    static assert( isInstantiationOf!(foo, foo!(int, string)));
    static assert(!isInstantiationOf!(foo, bar!int));
    static assert(!isInstantiationOf!(foo, bar!string));
    static assert(!isInstantiationOf!(foo, bar!(int, string)));

    static assert( isInstantiationOf!(bar, bar!int));
    static assert( isInstantiationOf!(bar, bar!string));
    static assert( isInstantiationOf!(bar, bar!(int, string)));
    static assert(!isInstantiationOf!(bar, foo!int));
    static assert(!isInstantiationOf!(bar, foo!string));
    static assert(!isInstantiationOf!(bar, foo!(int, string)));

    static assert( isInstantiationOf!(baz, baz!int));
    static assert( isInstantiationOf!(baz, baz!string));
    static assert(!isInstantiationOf!(baz, foo!(int, string)));

    static assert( isInstantiationOf!(frobozz, frobozz!(a => a)));
    static assert( isInstantiationOf!(frobozz, frobozz!(a => a > 2)));
    static assert(!isInstantiationOf!(frobozz, baz!int));

    // Unfortunately, the function type is not considered an instantiation of
    // the template, because that information is not part of the type, unlike
    // with templated structs or classes.
    static assert(!isInstantiationOf!(foo, typeof(foo!int)));
    static assert(!isInstantiationOf!(bar, typeof(bar!int)));
}

// Examples of templates which aren't types or functions.
@safe unittest
{
    template SingleArg(T) {}
    template Variadic(T...) {}
    template ValueArg(string s) {}
    template Alias(alias symbol) {}

    static assert( isInstantiationOf!(SingleArg, SingleArg!int));
    static assert( isInstantiationOf!(SingleArg, SingleArg!string));
    static assert(!isInstantiationOf!(SingleArg, int));
    static assert(!isInstantiationOf!(SingleArg, Variadic!int));

    static assert( isInstantiationOf!(Variadic, Variadic!()));
    static assert( isInstantiationOf!(Variadic, Variadic!int));
    static assert( isInstantiationOf!(Variadic, Variadic!string));
    static assert( isInstantiationOf!(Variadic, Variadic!(short, int, long)));
    static assert(!isInstantiationOf!(Variadic, int));
    static assert(!isInstantiationOf!(Variadic, SingleArg!int));

    static assert( isInstantiationOf!(ValueArg, ValueArg!"dlang"));
    static assert( isInstantiationOf!(ValueArg, ValueArg!"foobar"));
    static assert(!isInstantiationOf!(ValueArg, string));
    static assert(!isInstantiationOf!(ValueArg, Variadic!string));

    int i;

    static assert( isInstantiationOf!(Alias, Alias!int));
    static assert( isInstantiationOf!(Alias, Alias!42));
    static assert( isInstantiationOf!(Alias, Alias!i));
    static assert(!isInstantiationOf!(Alias, int));
    static assert(!isInstantiationOf!(Alias, SingleArg!int));
}

/// Examples of partial instantation.
@safe unittest
{
    static struct SingleArg(T) {}
    static struct Variadic(T...) {}

    alias isSingleArg = isInstantiationOf!SingleArg;
    alias isVariadic = isInstantiationOf!Variadic;

    static assert( isSingleArg!(SingleArg!int));
    static assert( isSingleArg!(const SingleArg!int));
    static assert(!isSingleArg!int);
    static assert(!isSingleArg!(Variadic!int));

    static assert( isVariadic!(Variadic!()));
    static assert( isVariadic!(Variadic!int));
    static assert( isVariadic!(shared Variadic!int));
    static assert( isVariadic!(Variadic!(int, string)));
    static assert(!isVariadic!int);
    static assert(!isVariadic!(SingleArg!int));

    T foo(T)(T t) { return t; }
    T likeFoo(T)(T t) { return t; }
    bool bar(alias pred)(int i) { return pred(i); }

    alias isFoo = isInstantiationOf!foo;
    alias isBar = isInstantiationOf!bar;

    static assert( isFoo!(foo!int));
    static assert( isFoo!(foo!string));
    static assert(!isFoo!int);
    static assert(!isFoo!(likeFoo!int));
    static assert(!isFoo!(bar!(a => true)));

    static assert( isBar!(bar!(a => true)));
    static assert( isBar!(bar!(a => a > 2)));
    static assert(!isBar!int);
    static assert(!isBar!(foo!int));
    static assert(!isBar!(likeFoo!int));
}

/++
    Evaluates to an $(D AliasSeq) containing the members of an enum type.

    The elements of the $(D AliasSeq) are in the same order as they are in the
    enum declaration.

    An enum can have multiple members with the same value, so if code needs the
    enum values to be unique (e.g. if it's generating a switch statement from
    them), then $(REF Unique, phobos, sys, meta) can be used to filter out the
    duplicate values - e.g. $(D Unique!(isEqual, EnumMembers!E)).
  +/
template EnumMembers(E)
if (is(E == enum))
{
    import phobos.sys.meta : AliasSeq;

    alias EnumMembers = AliasSeq!();
    static foreach (member; __traits(allMembers, E))
        EnumMembers = AliasSeq!(EnumMembers, __traits(getMember, E, member));
}

/// Create an array of enum values.
@safe unittest
{
    enum Sqrts : real
    {
        one = 1,
        two = 1.41421,
        three = 1.73205
    }
    auto sqrts = [EnumMembers!Sqrts];
    assert(sqrts == [Sqrts.one, Sqrts.two, Sqrts.three]);
}

/++
    A generic function $(D rank(v)) in the following example uses this template
    for finding a member $(D e) in an enum type $(D E).
 +/
@safe unittest
{
    // Returns i if e is the i-th member of E.
    static size_t rank(E)(E e)
    if (is(E == enum))
    {
        static foreach (i, member; EnumMembers!E)
        {
            if (e == member)
                return i;
        }
        assert(0, "Not an enum member");
    }

    enum Mode
    {
        read = 1,
        write = 2,
        map = 4
    }
    assert(rank(Mode.read) == 0);
    assert(rank(Mode.write) == 1);
    assert(rank(Mode.map) == 2);
}

/// Use EnumMembers to generate a switch statement using static foreach.
@safe unittest
{
    static class Foo
    {
        string calledMethod;
        void foo() @safe { calledMethod = "foo"; }
        void bar() @safe { calledMethod = "bar"; }
        void baz() @safe { calledMethod = "baz"; }
    }

    enum FuncName : string { foo = "foo", bar = "bar", baz = "baz" }

    auto foo = new Foo;

    s: final switch (FuncName.bar)
    {
        static foreach (member; EnumMembers!FuncName)
        {
            // Generate a case for each enum value.
            case member:
            {
                // Call foo.{enum value}().
                __traits(getMember, foo, member)();
                break s;
            }
        }
    }

    // Since we passed FuncName.bar to the switch statement, the bar member
    // function was called.
    assert(foo.calledMethod == "bar");
}

@safe unittest
{
    {
        enum A { a }
        static assert([EnumMembers!A] == [A.a]);
        enum B { a, b, c, d, e }
        static assert([EnumMembers!B] == [B.a, B.b, B.c, B.d, B.e]);
    }
    {
        enum A : string { a = "alpha", b = "beta" }
        static assert([EnumMembers!A] == [A.a, A.b]);

        static struct S
        {
            int value;
            int opCmp(S rhs) const nothrow { return value - rhs.value; }
        }
        enum B : S { a = S(1), b = S(2), c = S(3) }
        static assert([EnumMembers!B] == [B.a, B.b, B.c]);
    }
    {
        enum A { a = 0, b = 0, c = 1, d = 1, e }
        static assert([EnumMembers!A] == [A.a, A.b, A.c, A.d, A.e]);
    }
    {
        enum E { member, a = 0, b = 0 }

        static assert(__traits(isSame, EnumMembers!E[0], E.member));
        static assert(__traits(isSame, EnumMembers!E[1], E.a));
        static assert(__traits(isSame, EnumMembers!E[2], E.b));

        static assert(__traits(identifier, EnumMembers!E[0]) == "member");
        static assert(__traits(identifier, EnumMembers!E[1]) == "a");
        static assert(__traits(identifier, EnumMembers!E[2]) == "b");
    }
}

// https://issues.dlang.org/show_bug.cgi?id=14561: huge enums
@safe unittest
{
    static string genEnum()
    {
        string result = "enum TLAs {";
        foreach (c0; '0' .. '2' + 1)
        {
            foreach (c1; '0' .. '9' + 1)
            {
                foreach (c2; '0' .. '9' + 1)
                {
                    foreach (c3; '0' .. '9' + 1)
                    {
                        result ~= '_';
                        result ~= c0;
                        result ~= c1;
                        result ~= c2;
                        result ~= c3;
                        result ~= ',';
                    }
                }
            }
        }
        result ~= '}';
        return result;
    }
    mixin(genEnum);
    static assert(EnumMembers!TLAs[0] == TLAs._0000);
    static assert(EnumMembers!TLAs[$ - 1] == TLAs._2999);
}

/++
    Whether the type $(D From) is implicitly convertible to the type $(D To).

    Note that template constraints should be very careful about when they test
    for implicit conversions and in general should prefer to either test for an
    exact set of types or for types which compile with a particular piece of
    code rather than being designed to accept any type which implicitly converts
    to a particular type.

    This is because having a type pass a template constraint based on an
    implicit conversion but then not have the implicit conversion actually take
    place (which it won't unless the template does something to force it
    internally) can lead to either compilation errors or subtle behavioral
    differences - and even when the conversion is done explicitly within a
    templated function, since it's not done at the call site, it can still lead
    to subtle bugs in some cases (e.g. if slicing a static array is involved).

    For situations where code needs to verify that a type is implicitly
    convertible based solely on its qualifiers, $(LREF isQualifierConvertible)
    would be a more appropriate choice than isImplicitlyConvertible.

    Given how trivial the $(D is) expression for isImplicitlyConvertible is -
    $(D is(To : From)) - this trait is provided primarily so that it can be
    used in conjunction with templates that use a template predicate (such as
    many of the templates in phobos.sys.meta).

    The single-argument overload makes it so that it can be partially
    instantiated with the first argument, which will often be necessary with
    template predicates.

    See_Also:
        $(DDSUBLINK dlang.org/spec/type, implicit-conversions, Spec on implicit conversions)
        $(DDSUBLINK spec/const3, implicit_qualifier_conversions, Spec for implicit qualifier conversions)
        $(LREF isQualifierConvertible)
  +/
enum isImplicitlyConvertible(From, To) = is(From : To);

/++ Ditto +/
template isImplicitlyConvertible(From)
{
    enum isImplicitlyConvertible(To) = is(From : To);
}

///
@safe unittest
{
    static assert( isImplicitlyConvertible!(byte, long));
    static assert( isImplicitlyConvertible!(ushort, long));
    static assert( isImplicitlyConvertible!(int, long));
    static assert( isImplicitlyConvertible!(long, long));
    static assert( isImplicitlyConvertible!(ulong, long));

    static assert( isImplicitlyConvertible!(ubyte, int));
    static assert( isImplicitlyConvertible!(short, int));
    static assert( isImplicitlyConvertible!(int, int));
    static assert( isImplicitlyConvertible!(uint, int));
    static assert(!isImplicitlyConvertible!(long, int));
    static assert(!isImplicitlyConvertible!(ulong, int));

    static assert(!isImplicitlyConvertible!(int, string));
    static assert(!isImplicitlyConvertible!(int, int[]));
    static assert(!isImplicitlyConvertible!(int, int*));

    static assert(!isImplicitlyConvertible!(string, int));
    static assert(!isImplicitlyConvertible!(int[], int));
    static assert(!isImplicitlyConvertible!(int*, int));

    // For better or worse, bool and the built-in character types will
    // implicitly convert to integer or floating-point types if the target type
    // is large enough. Sometimes, this is desirable, whereas at other times,
    // it can have very surprising results, so it's one reason why code should
    // be very careful when testing for implicit conversions.
    static assert( isImplicitlyConvertible!(bool, int));
    static assert( isImplicitlyConvertible!(char, int));
    static assert( isImplicitlyConvertible!(wchar, int));
    static assert( isImplicitlyConvertible!(dchar, int));

    static assert( isImplicitlyConvertible!(bool, ubyte));
    static assert( isImplicitlyConvertible!(char, ubyte));
    static assert(!isImplicitlyConvertible!(wchar, ubyte));
    static assert(!isImplicitlyConvertible!(dchar, ubyte));

    static assert( isImplicitlyConvertible!(bool, double));
    static assert( isImplicitlyConvertible!(char, double));
    static assert( isImplicitlyConvertible!(wchar, double));
    static assert( isImplicitlyConvertible!(dchar, double));

    // Value types can be implicitly converted regardless of their qualifiers
    // thanks to the fact that they're copied.
    static assert( isImplicitlyConvertible!(int, int));
    static assert( isImplicitlyConvertible!(const int, int));
    static assert( isImplicitlyConvertible!(immutable int, int));
    static assert( isImplicitlyConvertible!(inout int, int));

    static assert( isImplicitlyConvertible!(int, const int));
    static assert( isImplicitlyConvertible!(int, immutable int));
    static assert( isImplicitlyConvertible!(int, inout int));

    // Reference types are far more restrictive about which implicit conversions
    // they allow, because qualifiers in D are transitive.
    static assert( isImplicitlyConvertible!(int*, int*));
    static assert(!isImplicitlyConvertible!(const int*, int*));
    static assert(!isImplicitlyConvertible!(immutable int*, int*));

    static assert( isImplicitlyConvertible!(int*, const int*));
    static assert( isImplicitlyConvertible!(const int*, const int*));
    static assert( isImplicitlyConvertible!(immutable int*, const int*));

    static assert(!isImplicitlyConvertible!(int*, immutable int*));
    static assert(!isImplicitlyConvertible!(const int*, immutable int*));
    static assert( isImplicitlyConvertible!(immutable int*, immutable int*));

    // Note that inout gets a bit weird, since it's only used with function
    // parameters, and it's a stand-in for whatever mutability qualifiers the
    // type actually has. So, a function parameter that's inout accepts any
    // mutability, but you can't actually implicitly convert to inout, because
    // it's unknown within the function what the actual mutability of the type
    // is. It will differ depending on the function arguments of a specific
    // call to that function, so the same code has to work with all combinations
    // of mutability qualifiers.
    static assert(!isImplicitlyConvertible!(int*, inout int*));
    static assert(!isImplicitlyConvertible!(const int*, inout int*));
    static assert(!isImplicitlyConvertible!(immutable int*, inout int*));
    static assert( isImplicitlyConvertible!(inout int*, inout int*));

    static assert(!isImplicitlyConvertible!(inout int*, int*));
    static assert( isImplicitlyConvertible!(inout int*, const int*));
    static assert(!isImplicitlyConvertible!(inout int*, immutable int*));

    // Enums implicitly convert to their base type.
    enum E : int
    {
        a = 42
    }
    static assert( isImplicitlyConvertible!(E, int));
    static assert( isImplicitlyConvertible!(E, long));
    static assert(!isImplicitlyConvertible!(E, int[]));

    // Structs only implicit convert to another type via declaring an
    // alias this.
    static struct S
    {
        int i;
    }
    static assert(!isImplicitlyConvertible!(S, int));
    static assert(!isImplicitlyConvertible!(S, long));
    static assert(!isImplicitlyConvertible!(S, string));

    static struct AliasThis
    {
        int i;
        alias this = i;
    }
    static assert( isImplicitlyConvertible!(AliasThis, int));
    static assert( isImplicitlyConvertible!(AliasThis, long));
    static assert(!isImplicitlyConvertible!(AliasThis, string));

    static struct AliasThis2
    {
        AliasThis at;
        alias this = at;
    }
    static assert( isImplicitlyConvertible!(AliasThis2, AliasThis));
    static assert( isImplicitlyConvertible!(AliasThis2, int));
    static assert( isImplicitlyConvertible!(AliasThis2, long));
    static assert(!isImplicitlyConvertible!(AliasThis2, string));

    static struct AliasThis3
    {
        AliasThis2 at;
        alias this = at;
    }
    static assert( isImplicitlyConvertible!(AliasThis3, AliasThis2));
    static assert( isImplicitlyConvertible!(AliasThis3, AliasThis));
    static assert( isImplicitlyConvertible!(AliasThis3, int));
    static assert( isImplicitlyConvertible!(AliasThis3, long));
    static assert(!isImplicitlyConvertible!(AliasThis3, string));

    // D does not support implicit conversions via construction.
    static struct Cons
    {
        this(int i)
        {
            this.i = i;
        }

        int i;
    }
    static assert(!isImplicitlyConvertible!(int, Cons));

    // Classes support implicit conversion based on their class and
    // interface hierarchies.
    static interface I1 {}
    static class Base : I1 {}

    static interface I2 {}
    static class Foo : Base, I2 {}

    static class Bar : Base {}

    static assert( isImplicitlyConvertible!(Base, Base));
    static assert(!isImplicitlyConvertible!(Base, Foo));
    static assert(!isImplicitlyConvertible!(Base, Bar));
    static assert( isImplicitlyConvertible!(Base, I1));
    static assert(!isImplicitlyConvertible!(Base, I2));

    static assert( isImplicitlyConvertible!(Foo, Base));
    static assert( isImplicitlyConvertible!(Foo, Foo));
    static assert(!isImplicitlyConvertible!(Foo, Bar));
    static assert( isImplicitlyConvertible!(Foo, I1));
    static assert( isImplicitlyConvertible!(Foo, I2));

    static assert( isImplicitlyConvertible!(Bar, Base));
    static assert(!isImplicitlyConvertible!(Bar, Foo));
    static assert( isImplicitlyConvertible!(Bar, Bar));
    static assert( isImplicitlyConvertible!(Bar, I1));
    static assert(!isImplicitlyConvertible!(Bar, I2));

    static assert(!isImplicitlyConvertible!(I1, Base));
    static assert(!isImplicitlyConvertible!(I1, Foo));
    static assert(!isImplicitlyConvertible!(I1, Bar));
    static assert( isImplicitlyConvertible!(I1, I1));
    static assert(!isImplicitlyConvertible!(I1, I2));

    static assert(!isImplicitlyConvertible!(I2, Base));
    static assert(!isImplicitlyConvertible!(I2, Foo));
    static assert(!isImplicitlyConvertible!(I2, Bar));
    static assert(!isImplicitlyConvertible!(I2, I1));
    static assert( isImplicitlyConvertible!(I2, I2));

    // Note that arrays are not implicitly convertible even when their elements
    // are implicitly convertible.
    static assert(!isImplicitlyConvertible!(ubyte[], uint[]));
    static assert(!isImplicitlyConvertible!(Foo[], Base[]));
    static assert(!isImplicitlyConvertible!(Bar[], Base[]));

    // However, like with pointers, dynamic arrays are convertible based on
    // constness.
    static assert( isImplicitlyConvertible!(Base[], const Base[]));
    static assert( isImplicitlyConvertible!(Base[], const(Base)[]));
    static assert(!isImplicitlyConvertible!(Base[], immutable(Base)[]));
    static assert(!isImplicitlyConvertible!(const Base[], immutable Base[]));
    static assert( isImplicitlyConvertible!(const Base[], const Base[]));
    static assert(!isImplicitlyConvertible!(const Base[], immutable Base[]));
}

/++
    isImplicitlyConvertible can be used with partial instantiation so that it
    can be passed to a template which takes a unary predicate.
  +/
@safe unittest
{
    import phobos.sys.meta : AliasSeq, all, indexOf;

    // byte is implicitly convertible to byte, short, int, and long.
    static assert(all!(isImplicitlyConvertible!byte, short, int, long));

    // const(char)[] at index 2 is the first type in the AliasSeq which string
    // can be implicitly converted to.
    alias Types = AliasSeq!(int, char[], const(char)[], string, int*);
    static assert(indexOf!(isImplicitlyConvertible!string, Types) == 2);
}

/++
    Whether $(D From) is
    $(DDSUBLINK spec/const3, implicit_qualifier_conversions, qualifier-convertible)
    to $(D To).

    This is testing whether $(D From) and $(D To) are the same type - minus the
    qualifiers - and whether the qualifiers on $(D From) can be implicitly
    converted to the qualifiers on $(D To). No other implicit conversions are
    taken into account.

    For instance, $(D const int*) is not implicitly convertible to $(D int*),
    because that would violate $(D const). That means that $(D const) is not
    qualifier convertible to mutable. And as such, $(I any) $(D const) type
    is not qualifier convertible to a mutable type even if it's implicitly
    convertible. E.G. $(D const int) is implicitly convertible to $(D int),
    because it can be copied to avoid violating $(D const), but it's still not
    qualifier convertible, because $(D const) types in general cannot be
    implicitly converted to mutable.

    The exact types being tested matter, because they need to be the same
    (minus the qualifiers) in order to be considered convertible, but beyond
    that, all that matters for the conversion is whether those qualifers would
    be convertible regardless of which types they were on. So, if you're having
    trouble picturing whether $(D From) would be qualifier convertible to
    $(D To), then consider which conversions would be allowed from $(D From[])
    to $(D To[]) (and remember that dynamic arrays are only implicitly
    convertible based on their qualifers).

    The $(DDSUBLINK spec/const3, implicit_qualifier_conversions, spec) provides
    a table of which qualifiers can be implcitly converted to which other
    qualifers (and of course, there a bunch of examples below).

    So, isQualifierConvertible can be used in a case like
    $(D isQualifierConvertible!(ReturnType!(typeof(foo(bar))), const char),
    which would be testing that the return type of $(D foo(bar)) was $(D char),
    $(D const char), or $(D immutable char) (since those are the only types
    which are qualifier convertible to $(D const char)).

    This is in contrast to
    $(D isImplicitlyConvertible!(ReturnType!(typeof(foo(bar))), const char),
    which would be $(D true) for $(I any) type which was implicitly convertible
    to $(D const char) rather than just $(D char), $(D const char), and
    $(D immutable char).

    The single-argument overload makes it so that it can be partially
    instantiated with the first argument, which will often be necessary with
    template predicates.

    See_Also:
        $(DDSUBLINK spec/const3, implicit_qualifier_conversions, Spec for implicit qualifier conversions)
        $(LREF isImplicitlyConvertible)
  +/
enum isQualifierConvertible(From, To) = is(immutable From == immutable To) && is(From* : To*);

/++ Ditto +/
template isQualifierConvertible(From)
{
    enum isQualifierConvertible(To) =  is(immutable From == immutable To) && is(From* : To*);
}

///
@safe unittest
{
    // i.e. char* -> const char*
    static assert( isQualifierConvertible!(char, const char));

    // i.e. const char* -> char*
    static assert(!isQualifierConvertible!(const char, char));

    static assert( isQualifierConvertible!(int, int));
    static assert( isQualifierConvertible!(int, const int));
    static assert(!isQualifierConvertible!(int, immutable int));

    static assert(!isQualifierConvertible!(const int, int));
    static assert( isQualifierConvertible!(const int, const int));
    static assert(!isQualifierConvertible!(const int, immutable int));

    static assert(!isQualifierConvertible!(immutable int, int));
    static assert( isQualifierConvertible!(immutable int, const int));
    static assert( isQualifierConvertible!(immutable int, immutable int));

    // Note that inout gets a bit weird, since it's only used with function
    // parameters, and it's a stand-in for whatever mutability qualifiers the
    // type actually has. So, a function parameter that's inout accepts any
    // mutability, but you can't actually implicitly convert to inout, because
    // it's unknown within the function what the actual mutability of the type
    // is. It will differ depending on the function arguments of a specific
    // call to that function, so the same code has to work with all combinations
    // of mutability qualifiers.
    static assert(!isQualifierConvertible!(int, inout int));
    static assert(!isQualifierConvertible!(const int, inout int));
    static assert(!isQualifierConvertible!(immutable int, inout int));
    static assert( isQualifierConvertible!(inout int, inout int));

    static assert(!isQualifierConvertible!(inout int, int));
    static assert( isQualifierConvertible!(inout int, const int));
    static assert(!isQualifierConvertible!(inout int, immutable int));

    // shared is of course also a qualifier.
    static assert(!isQualifierConvertible!(int, shared int));
    static assert(!isQualifierConvertible!(int, const shared int));
    static assert(!isQualifierConvertible!(const int, shared int));
    static assert(!isQualifierConvertible!(const int, const shared int));
    static assert(!isQualifierConvertible!(immutable int, shared int));
    static assert( isQualifierConvertible!(immutable int, const shared int));

    static assert(!isQualifierConvertible!(shared int, int));
    static assert(!isQualifierConvertible!(shared int, const int));
    static assert(!isQualifierConvertible!(shared int, immutable int));
    static assert( isQualifierConvertible!(shared int, shared int));
    static assert( isQualifierConvertible!(shared int, const shared int));

    static assert(!isQualifierConvertible!(const shared int, int));
    static assert(!isQualifierConvertible!(const shared int, const int));
    static assert(!isQualifierConvertible!(const shared int, immutable int));
    static assert(!isQualifierConvertible!(const shared int, shared int));
    static assert( isQualifierConvertible!(const shared int, const shared int));

    // Implicit conversions don't count unless they're based purely on
    // qualifiers.
    enum E : int
    {
        a = 1
    }

    static assert(!isQualifierConvertible!(E, int));
    static assert(!isQualifierConvertible!(E, const int));
    static assert( isQualifierConvertible!(E, E));
    static assert( isQualifierConvertible!(E, const E));
    static assert(!isQualifierConvertible!(E, immutable E));

    static struct AliasThis
    {
        int i;
        alias this = i;
    }

    static assert(!isQualifierConvertible!(AliasThis, int));
    static assert(!isQualifierConvertible!(AliasThis, const int));
    static assert( isQualifierConvertible!(AliasThis, AliasThis));
    static assert( isQualifierConvertible!(AliasThis, const AliasThis));
    static assert(!isQualifierConvertible!(AliasThis, immutable AliasThis));

    // The qualifiers are irrelevant if the types aren't the same when
    // stripped of all qualifers.
    static assert(!isQualifierConvertible!(int, long));
    static assert(!isQualifierConvertible!(int, const long));
    static assert(!isQualifierConvertible!(string, const(ubyte)[]));
}

/++
    isQualifierConvertible can be used with partial instantiation so that it
    can be passed to a template which takes a unary predicate.
  +/
@safe unittest
{
    import phobos.sys.meta : AliasSeq, all, indexOf;

    // byte is qualifier convertible to byte and const byte.
    static assert(all!(isQualifierConvertible!byte, byte, const byte));

    // const(char[]) at index 2 is the first type in the AliasSeq which string
    // is qualifier convertible to.
    alias Types = AliasSeq!(int, char[], const(char[]), string, int*);
    static assert(indexOf!(isQualifierConvertible!string, Types) == 2);
}

@safe unittest
{
    import phobos.sys.meta : AliasSeq;

    alias Types = AliasSeq!(int, const int, shared int, inout int, const shared int,
                            const inout int, inout shared int, const inout shared int, immutable int);

    // https://dlang.org/spec/const3.html#implicit_qualifier_conversions
    enum _ = 0;
    static immutable bool[Types.length][Types.length] conversions = [
    //   m   c   s   i   cs  ci  is  cis im
        [1,  1,  _,  _,  _,  _,  _,  _,  _],  // mutable
        [_,  1,  _,  _,  _,  _,  _,  _,  _],  // const
        [_,  _,  1,  _,  1,  _,  _,  _,  _],  // shared
        [_,  1,  _,  1,  _,  1,  _,  _,  _],  // inout
        [_,  _,  _,  _,  1,  _,  _,  _,  _],  // const shared
        [_,  1,  _,  _,  _,  1,  _,  _,  _],  // const inout
        [_,  _,  _,  _,  1,  _,  1,  1,  _],  // inout shared
        [_,  _,  _,  _,  1,  _,  _,  1,  _],  // const inout shared
        [_,  1,  _,  _,  1,  1,  _,  1,  1],  // immutable
    ];

    foreach (i, From; Types)
    {
        foreach (j, To; Types)
        {
            static assert(isQualifierConvertible!(From, To) == conversions[i][j],
                          "`isQualifierConvertible!(" ~ From.stringof ~ ", " ~ To.stringof ~ ")`" ~
                          " should be `" ~ (conversions[i][j] ? "true`" : "false`"));
        }
    }
}

/++
    Whether the given values are equal per $(D ==).

    All this does is $(D lhs == rhs) but in an eponymous template, so most code
    shouldn't use it. It's intended to be used in conjunction with templates
    that take a template predicate - such as those in phobos.sys.meta.

    The single-argument overload makes it so that it can be partially
    instantiated with the first argument, which will often be necessary with
    template predicates.

    Note that in most cases, even when comparing values at compile time, using
    isEqual makes no sense, because you can use CTFE to just compare two values
    (or expressions which evaluate to values), but in rare cases where you need
    to compare symbols in an $(D AliasSeq) by value with a template predicate
    while still leaving them as symbols in an $(D AliasSeq), then isEqual would
    be needed.

    A prime example of this would be $(D Unique!(isEqual, EnumMembers!MyEnum)),
    which results in an $(D AliasSeq) containing the list of members of
    $(D MyEnum) but without any duplicate values (e.g. to use when doing code
    generation to create a final switch).

    Alternatively, code such as $(D [EnumMembers!MyEnum].sort().unique()) could
    be used to get a dynamic array of the enum members with no duplicate values
    via CTFE, thus avoiding the need for template predicates or anything from
    phobos.sys.meta. However, you then have a dynamic array of enum values
    rather than an $(D AliasSeq) of symbols for those enum members, which
    affects what you can do with type introspection. So, which approach is
    better depends on what the code needs to do with the enum members.

    In general, however, if code doesn't need an $(D AliasSeq), and an array of
    values will do the trick, then it's more efficient to operate on an array of
    values with CTFE and avoid using isEqual or other templates to operate on
    the values as an $(D AliasSeq).

    See_Also:
        $(LREF isSameSymbol)
        $(LREF isSameType)
  +/
enum isEqual(alias lhs, alias rhs) = lhs == rhs;

/++ Ditto +/
template isEqual(alias lhs)
{
    enum isEqual(alias rhs) = lhs == rhs;
}

/// It acts just like ==, but it's a template.
@safe unittest
{
    enum a = 42;

    static assert( isEqual!(a, 42));
    static assert( isEqual!(20, 10 + 10));

    static assert(!isEqual!(a, 120));
    static assert(!isEqual!(77, 19 * 7 + 2));

    // b cannot be read at compile time, so it won't work with isEqual.
    int b = 99;
    static assert(!__traits(compiles, isEqual!(b, 99)));
}

/++
    Comparing some of the differences between an $(D AliasSeq) of enum members
    and an array of enum values created from an $(D AliasSeq) of enum members.
  +/
@safe unittest
{
    import phobos.sys.meta : AliasSeq, Unique;

    enum E
    {
        a = 0,
        b = 22,
        c = 33,
        d = 0,
        e = 256,
        f = 33,
        g = 7
    }

    alias uniqueMembers = Unique!(isEqual, EnumMembers!E);
    static assert(uniqueMembers.length == 5);

    static assert(__traits(isSame, uniqueMembers[0], E.a));
    static assert(__traits(isSame, uniqueMembers[1], E.b));
    static assert(__traits(isSame, uniqueMembers[2], E.c));
    static assert(__traits(isSame, uniqueMembers[3], E.e));
    static assert(__traits(isSame, uniqueMembers[4], E.g));

    static assert(__traits(identifier, uniqueMembers[0]) == "a");
    static assert(__traits(identifier, uniqueMembers[1]) == "b");
    static assert(__traits(identifier, uniqueMembers[2]) == "c");
    static assert(__traits(identifier, uniqueMembers[3]) == "e");
    static assert(__traits(identifier, uniqueMembers[4]) == "g");

    // Same value but different symbol.
    static assert(uniqueMembers[0] == E.d);
    static assert(!__traits(isSame, uniqueMembers[0], E.d));

    // is expressions compare types, not symbols or values, and these AliasSeqs
    // contain the list of symbols for the enum members, not types, so the is
    // expression evaluates to false even though the symbols are the same.
    static assert(!is(uniqueMembers == AliasSeq!(E.a, E.b, E.c, E.e, E.g)));

    // Once the members are converted to an array, the types are the same, and
    // the values are the same, but the symbols are not the same. Instead of
    // being the symbols E.a, E.b, etc., they're just values with the type E
    // which match the values of E.a, E.b, etc.
    enum arr = [uniqueMembers];
    static assert(is(typeof(arr) == E[]));

    static assert(arr == [E.a, E.b, E.c, E.e, E.g]);
    static assert(arr == [E.d, E.b, E.f, E.e, E.g]);

    static assert(!__traits(isSame, arr[0], E.a));
    static assert(!__traits(isSame, arr[1], E.b));
    static assert(!__traits(isSame, arr[2], E.c));
    static assert(!__traits(isSame, arr[3], E.e));
    static assert(!__traits(isSame, arr[4], E.g));

    // Since arr[0] is just a value of type E, it's no longer the symbol, E.a,
    // even though its type is E, and its value is the same as that of E.a. And
    // unlike the actual members of an enum, an element of an array does not
    // have an identifier, so __traits(identifier, ...) doesn't work with it.
    static assert(!__traits(compiles, __traits(identifier, arr[0])));

    // Similarly, once an enum member from the AliasSeq is assigned to a
    // variable, __traits(identifer, ...) operates on the variable, not the
    // symbol from the AliasSeq or the value of the variable.
    auto var = uniqueMembers[0];
    static assert(__traits(identifier, var) == "var");

    // The same with a manifest constant.
    enum constant = uniqueMembers[0];
    static assert(__traits(identifier, constant) == "constant");
}

/++
    Whether the given symbols are the same symbol.

    All this does is $(D __traits(isSame, lhs, rhs)), so most code shouldn't
    use it. It's intended to be used in conjunction with templates that take a
    template predicate - such as those in phobos.sys.meta.

    The single-argument overload makes it so that it can be partially
    instantiated with the first argument, which will often be necessary with
    template predicates.

    See_Also:
        $(DDSUBLINK spec/traits, isSame, $(D __traits(isSame, lhs, rhs)))
        $(LREF isEqual)
        $(LREF isSameType)
  +/
enum isSameSymbol(alias lhs, alias rhs) = __traits(isSame, lhs, rhs);

/++ Ditto +/
template isSameSymbol(alias lhs)
{
    enum isSameSymbol(alias rhs) = __traits(isSame, lhs, rhs);
}

///
@safe unittest
{
    int i;
    int j;
    real r;

    static assert( isSameSymbol!(i, i));
    static assert(!isSameSymbol!(i, j));
    static assert(!isSameSymbol!(i, r));

    static assert(!isSameSymbol!(j, i));
    static assert( isSameSymbol!(j, j));
    static assert(!isSameSymbol!(j, r));

    static assert(!isSameSymbol!(r, i));
    static assert(!isSameSymbol!(r, j));
    static assert( isSameSymbol!(r, r));

    auto foo() { return 0; }
    auto bar() { return 0; }

    static assert( isSameSymbol!(foo, foo));
    static assert(!isSameSymbol!(foo, bar));
    static assert(!isSameSymbol!(foo, i));

    static assert(!isSameSymbol!(bar, foo));
    static assert( isSameSymbol!(bar, bar));
    static assert(!isSameSymbol!(bar, i));

    // Types are symbols too. However, in most cases, they should be compared
    // as types, not symbols (be it with is expressions or with isSameType),
    // because the results aren't consistent between scalar types and
    // user-defined types with regards to type qualifiers when they're compared
    // as symbols.
    static assert( isSameSymbol!(double, double));
    static assert(!isSameSymbol!(double, const double));
    static assert(!isSameSymbol!(double, int));
    static assert( isSameSymbol!(Object, Object));
    static assert( isSameSymbol!(Object, const Object));

    static assert(!isSameSymbol!(i, int));
    static assert( isSameSymbol!(typeof(i), int));

    // Lambdas can be compared with __traits(isSame, ...),
    // so they can be compared with isSameSymbol.
    static assert( isSameSymbol!(a => a + 42, a => a + 42));
    static assert(!isSameSymbol!(a => a + 42, a => a + 99));

    // Partial instantiation allows it to be used with templates that expect
    // a predicate that takes only a single argument.
    import phobos.sys.meta : AliasSeq, indexOf;
    alias Types = AliasSeq!(i, j, r, int, long, foo);
    static assert(indexOf!(isSameSymbol!j, Types) == 1);
    static assert(indexOf!(isSameSymbol!int, Types) == 3);
    static assert(indexOf!(isSameSymbol!bar, Types) == -1);
}

/++
    Whether the given types are the same type.

    All this does is $(D is(T == U)), so most code shouldn't use it. It's
    intended to be used in conjunction with templates that take a template
    predicate - such as those in phobos.sys.meta.

    The single-argument overload makes it so that it can be partially
    instantiated with the first argument, which will often be necessary with
    template predicates.

    See_Also:
        $(LREF isEqual)
        $(LREF isSameSymbol)
  +/
enum isSameType(T, U) = is(T == U);

/++ Ditto +/
template isSameType(T)
{
    enum isSameType(U) = is(T == U);
}

///
@safe unittest
{
    static assert( isSameType!(long, long));
    static assert(!isSameType!(long, const long));
    static assert(!isSameType!(long, string));
    static assert( isSameType!(string, string));

    int i;
    real r;
    static assert( isSameType!(int, typeof(i)));
    static assert(!isSameType!(int, typeof(r)));

    static assert(!isSameType!(real, typeof(i)));
    static assert( isSameType!(real, typeof(r)));

    // Partial instantiation allows it to be used with templates that expect
    // a predicate that takes only a single argument.
    import phobos.sys.meta : AliasSeq, indexOf;
    alias Types = AliasSeq!(float, string, int, double);
    static assert(indexOf!(isSameType!int, Types) == 2);
}

/++
    Converts a function type, function pointer type, or delegate type to the
    corresponding function type.

    For a function, the result is the same as the given type.

    For a function pointer or delegate, the result is the same as it would be
    for a function with the same return type, the same set of parameters, and
    the same set of attributes.

    Another way to look at it would be that it's the type that comes from
    dereferencing the function pointer. And while it's not technically possible
    to dereference a delegate, it's conceptually the same thing, since a
    delegate is essentially a fat pointer to a function in the sense that it
    contains a pointer to a function and a pointer to the function's context.
    The result of ToFunctionType is the type of that function.

    Note that code which has a symbol which is a function should use
    $(LREF SymbolType) rather than $(K_TYPEOF) to get the type of the function
    in order to avoid issues with regards to $(K_PROPERTY) (see the
    documentation for $(LREF SymbolType) for details).

    See_Also:
        $(LREF SymbolType)
  +/
template ToFunctionType(T)
if (is(T == return))
{
    // Function pointers.
    static if (is(T == U*, U) && is(U == function))
        alias ToFunctionType = U;
    // Delegates.
    else static if (is(T U == delegate))
        alias ToFunctionType = U;
    // Functions.
    else
        alias ToFunctionType = T;
}

///
@safe unittest
{
    static string func(int) { return ""; }
    auto funcPtr = &func;

    static assert( is(ToFunctionType!(SymbolType!func) == SymbolType!func));
    static assert( is(ToFunctionType!(SymbolType!funcPtr) == SymbolType!func));
    static assert(!is(SymbolType!funcPtr == function));
    static assert( is(ToFunctionType!(SymbolType!funcPtr) == function));

    int var;
    int funcWithContext(string) { return var; }
    auto funcDel = &funcWithContext;

    static assert( is(ToFunctionType!(SymbolType!funcWithContext) ==
                      SymbolType!funcWithContext));
    static assert( is(ToFunctionType!(SymbolType!funcDel) ==
                      SymbolType!funcWithContext));
    static assert( is(SymbolType!funcWithContext == function));
    static assert(!is(SymbolType!funcDel == function));
    static assert( is(SymbolType!funcDel == delegate));
    static assert( is(ToFunctionType!(SymbolType!funcDel) == function));

    static @property int prop() { return 0; }
    static assert( is(SymbolType!prop == function));
    static assert(!is(SymbolType!prop == delegate));
    static assert( is(SymbolType!prop == return));
    static assert( is(SymbolType!prop ==
                      ToFunctionType!(int function() @property @safe pure
                                                     nothrow @nogc)));
    static assert( is(ToFunctionType!(SymbolType!prop) == SymbolType!prop));

    // This is an example of why SymbolType should be used rather than typeof
    // when using ToFunctionType (or getting the type of any symbol which might
    // be a function when you want the actual type of the symbol and don't want
    // to end up with its return type instead).
    static assert( is(typeof(prop) == int));
    static assert(!is(typeof(prop) == function));
    static assert(!__traits(compiles, ToFunctionType!(typeof(prop))));

    auto propPtr = &prop;
    static assert(!is(typeof(propPtr) == function));
    static assert(!is(SymbolType!propPtr == function));
    //static assert( isFunctionPointer!(typeof(propPtr))); // commented out until isFunctionPointer is added
    static assert( is(ToFunctionType!(SymbolType!propPtr) == function));

    static assert( is(SymbolType!propPtr ==
                      int function() @property @safe pure nothrow @nogc));
    static assert(!is(ToFunctionType!(SymbolType!propPtr) ==
                      int function() @property @safe pure nothrow @nogc));
    static assert( is(ToFunctionType!(SymbolType!propPtr) ==
                      ToFunctionType!(int function() @property @safe pure
                                                     nothrow @nogc)));

    @property void propWithContext(int i) { var += i; }
    static assert( is(SymbolType!propWithContext == function));
    static assert( is(SymbolType!propWithContext ==
                      ToFunctionType!(void function(int) @property @safe pure
                                                         nothrow @nogc)));
    static assert( is(ToFunctionType!(SymbolType!propWithContext) ==
                      SymbolType!propWithContext));

    // typeof fails to compile with setter properties, complaining about there
    // not being enough arguments, because it's treating the function as an
    // expression - and since such an expression would call the function, the
    // expression isn't valid if there aren't enough function arguments.
    static assert(!__traits(compiles, typeof(propWithContext)));

    auto propDel = &propWithContext;
    static assert(!is(SymbolType!propDel == function));
    static assert( is(SymbolType!propDel == delegate));
    static assert( is(SymbolType!propDel == return));
    static assert( is(ToFunctionType!(SymbolType!propDel) == function));
    static assert( is(ToFunctionType!(SymbolType!propDel) ==
                      SymbolType!propWithContext));

    static assert( is(SymbolType!propDel ==
                      void delegate(int) @property @safe pure nothrow @nogc));
    static assert(!is(ToFunctionType!(SymbolType!propDel) ==
                      void delegate(int) @property @safe pure nothrow @nogc));
    static assert(!is(ToFunctionType!(SymbolType!propDel) ==
                      void function(int) @property @safe pure nothrow @nogc));
    static assert( is(ToFunctionType!(SymbolType!propDel) ==
                      ToFunctionType!(void function(int) @property @safe pure
                                                         nothrow @nogc)));

    static struct S
    {
        string foo(int);
        string bar(int, int);
        @property void prop(string);
    }

    static assert( is(ToFunctionType!(SymbolType!(S.foo)) ==
                      ToFunctionType!(string function(int))));
    static assert( is(ToFunctionType!(SymbolType!(S.bar)) ==
                      ToFunctionType!(string function(int, int))));
    static assert( is(ToFunctionType!(SymbolType!(S.prop)) ==
                      ToFunctionType!(void function(string) @property)));
}

@safe unittest
{
    // Unfortunately, in this case, we get linker errors when taking the address
    // of the functions if we avoid inference by not giving function bodies.
    // So if we don't want to list all of those attributes in the tests, we have
    // to stop the inference in another way.
    static int var;
    static void killAttributes() @system { ++var; throw new Exception("message"); }

    static struct S
    {
        int func1() { killAttributes(); return 0; }
        void func2(int) { killAttributes(); }

        static int func3() { killAttributes(); return 0; }
        static void func4(int) { killAttributes(); }

        @property int func5() { killAttributes(); return 0; }
        @property void func6(int) { killAttributes(); }
    }

    static assert( is(SymbolType!(S.func1) == ToFunctionType!(int function())));
    static assert( is(SymbolType!(S.func2) == ToFunctionType!(void function(int))));
    static assert( is(SymbolType!(S.func3) == ToFunctionType!(int function())));
    static assert( is(SymbolType!(S.func4) == ToFunctionType!(void function(int))));
    static assert( is(SymbolType!(S.func5) == ToFunctionType!(int function() @property)));
    static assert( is(SymbolType!(S.func6) == ToFunctionType!(void function(int) @property)));

    static assert( is(ToFunctionType!(SymbolType!(S.func1)) == ToFunctionType!(int function())));
    static assert( is(ToFunctionType!(SymbolType!(S.func2)) == ToFunctionType!(void function(int))));
    static assert( is(ToFunctionType!(SymbolType!(S.func3)) == ToFunctionType!(int function())));
    static assert( is(ToFunctionType!(SymbolType!(S.func4)) == ToFunctionType!(void function(int))));
    static assert( is(ToFunctionType!(SymbolType!(S.func5)) == ToFunctionType!(int function() @property)));
    static assert( is(ToFunctionType!(SymbolType!(S.func6)) ==
                      ToFunctionType!(void function(int) @property)));

    auto ptr1 = &S.init.func1;
    auto ptr2 = &S.init.func2;
    auto ptr3 = &S.func3;
    auto ptr4 = &S.func4;
    auto ptr5 = &S.init.func5;
    auto ptr6 = &S.init.func6;

    // For better or worse, static member functions can be accessed through
    // instance of the type as well as through the type.
    auto ptr3Instance = &S.init.func3;
    auto ptr4Instance = &S.init.func4;

    static assert( is(SymbolType!ptr1 == int delegate()));
    static assert( is(SymbolType!ptr2 == void delegate(int)));
    static assert( is(SymbolType!ptr3 == int function()));
    static assert( is(SymbolType!ptr4 == void function(int)));
    static assert( is(SymbolType!ptr5 == int delegate() @property));
    static assert( is(SymbolType!ptr6 == void delegate(int) @property));

    static assert( is(SymbolType!ptr3Instance == int function()));
    static assert( is(SymbolType!ptr4Instance == void function(int)));

    static assert( is(ToFunctionType!(SymbolType!ptr1) == ToFunctionType!(int function())));
    static assert( is(ToFunctionType!(SymbolType!ptr2) == ToFunctionType!(void function(int))));
    static assert( is(ToFunctionType!(SymbolType!ptr3) == ToFunctionType!(int function())));
    static assert( is(ToFunctionType!(SymbolType!ptr4) == ToFunctionType!(void function(int))));
    static assert( is(ToFunctionType!(SymbolType!ptr5) == ToFunctionType!(int function() @property)));
    static assert( is(ToFunctionType!(SymbolType!ptr6) == ToFunctionType!(void function(int) @property)));

    static assert( is(ToFunctionType!(SymbolType!ptr3Instance) == ToFunctionType!(int function())));
    static assert( is(ToFunctionType!(SymbolType!ptr4Instance) == ToFunctionType!(void function(int))));
}

/++
    Evaluates to an $(D AliasSeq) of the names (as $(D string)s) of the member
    variables of an aggregate type (i.e. a struct, class, interface, or union).

    These are fields which take up memory space within an instance of the type
    (i.e. not enums / manifest constants, since they don't take up memory
    space, and not static member variables, since they don't take up memory
    space within an instance).

    Hidden fields (like the virtual function table pointer or the context
    pointer for nested types) are not included.

    For classes, only the direct member variables are included and not those
    of any base classes.

    For interfaces, the result of FieldNames is always empty, because
    interfaces cannot have member variables. However, because interfaces are
    aggregate types, they work with FieldNames for consistency so that code
    that's written to work on aggregate types doesn't have to worry about
    whether it's dealing with an interface.

    See_Also:
        $(LREF FieldSymbols)
        $(LREF FieldTypes)
        $(DDSUBLINK spec/struct.html, struct_instance_properties, $(D tupleof))
  +/
template FieldNames(T)
if (isAggregateType!T)
{
    import phobos.sys.meta : AliasSeq;

    static if (is(T == struct) && __traits(isNested, T))
        private alias Fields = AliasSeq!(T.tupleof[0 .. $ - 1]);
    else
        private alias Fields = T.tupleof;

    alias FieldNames = AliasSeq!();
    static foreach (Field; Fields)
        FieldNames = AliasSeq!(FieldNames, Field.stringof);
}

///
@safe unittest
{
    import phobos.sys.meta : AliasSeq;

    struct S
    {
        int x;
        float y;
    }
    static assert(FieldNames!S == AliasSeq!("x", "y"));

    // Since the AliasSeq contains values, all of which are of the same type,
    // it can be used to create a dynamic array, which would be more
    // efficient than operating on an AliasSeq in the cases where an
    // AliasSeq is not necessary.
    static assert([FieldNames!S] == ["x", "y"]);

    class C
    {
        // static variables are not included.
        static int var;

        // Manifest constants are not included.
        enum lang = "dlang";

        // Functions are not included, even if they're @property functions.
        @property int foo() { return 42; }

        string s;
        int i;
        int[] arr;
    }
    static assert(FieldNames!C == AliasSeq!("s", "i", "arr"));

    static assert([FieldNames!C] == ["s", "i", "arr"]);

    // Only direct member variables are included. Member variables from any base
    // classes are not.
    class D : C
    {
        real r;
    }
    static assert(FieldNames!D == AliasSeq!"r");

    static assert([FieldNames!D] == ["r"]);

    // FieldNames will always be empty for an interface, since it's not legal
    // for interfaces to have member variables.
    interface I
    {
    }
    static assert(FieldNames!I.length == 0);

    union U
    {
        int i;
        double d;
        long l;
        S s;
    }
    static assert(FieldNames!U == AliasSeq!("i", "d", "l", "s"));

    static assert([FieldNames!U] == ["i", "d", "l", "s"]);;

    // FieldNames only operates on aggregate types.
    static assert(!__traits(compiles, FieldNames!int));
    static assert(!__traits(compiles, FieldNames!(S*)));
    static assert(!__traits(compiles, FieldNames!(C[])));
}

@safe unittest
{
    import phobos.sys.meta : AliasSeq;

    {
        static struct S0 {}
        static assert(FieldNames!S0.length == 0);

        static struct S1 { int a; }
        static assert(FieldNames!S1 == AliasSeq!"a");

        static struct S2 { int a; string b; }
        static assert(FieldNames!S2 == AliasSeq!("a", "b"));

        static struct S3 { int a; string b; real c; }
        static assert(FieldNames!S3 == AliasSeq!("a", "b", "c"));
    }
    {
        int i;
        struct S0 { void foo() { i = 0; }}
        static assert(FieldNames!S0.length == 0);
        static assert(__traits(isNested, S0));

        struct S1 { int a; void foo() { i = 0; } }
        static assert(FieldNames!S1 == AliasSeq!"a");
        static assert(__traits(isNested, S1));

        struct S2 { int a; string b; void foo() { i = 0; } }
        static assert(FieldNames!S2 == AliasSeq!("a", "b"));
        static assert(__traits(isNested, S2));

        struct S3 { int a; string b; real c; void foo() { i = 0; } }
        static assert(FieldNames!S3 == AliasSeq!("a", "b", "c"));
        static assert(__traits(isNested, S3));
    }
    {
        static class C0 {}
        static assert(FieldNames!C0.length == 0);

        static class C1 { int a; }
        static assert(FieldNames!C1 == AliasSeq!"a");

        static class C2 { int a; string b; }
        static assert(FieldNames!C2 == AliasSeq!("a", "b"));

        static class C3 { int a; string b; real c; }
        static assert(FieldNames!C3 == AliasSeq!("a", "b", "c"));

        static class D0 : C3 {}
        static assert(FieldNames!D0.length == 0);

        static class D1 : C3 { bool x; }
        static assert(FieldNames!D1 == AliasSeq!"x");

        static class D2 : C3 { bool x; int* y; }
        static assert(FieldNames!D2 == AliasSeq!("x", "y"));

        static class D3 : C3 { bool x; int* y; short[] z; }
        static assert(FieldNames!D3 == AliasSeq!("x", "y", "z"));
    }
    {
        int i;
        class C0 { void foo() { i = 0; }}
        static assert(FieldNames!C0.length == 0);
        static assert(__traits(isNested, C0));

        class C1 { int a; void foo() { i = 0; } }
        static assert(FieldNames!C1 == AliasSeq!"a");
        static assert(__traits(isNested, C1));

        class C2 { int a; string b; void foo() { i = 0; } }
        static assert(FieldNames!C2 == AliasSeq!("a", "b"));
        static assert(__traits(isNested, C2));

        class C3 { int a; string b; real c; void foo() { i = 0; } }
        static assert(FieldNames!C3 == AliasSeq!("a", "b", "c"));
        static assert(__traits(isNested, C3));

        class D0 : C3 {}
        static assert(FieldNames!D0.length == 0);
        static assert(__traits(isNested, D0));

        class D1 : C3 { bool x; }
        static assert(FieldNames!D1 == AliasSeq!"x");
        static assert(__traits(isNested, D1));

        class D2 : C3 { bool x; int* y; }
        static assert(FieldNames!D2 == AliasSeq!("x", "y"));
        static assert(__traits(isNested, D2));

        class D3 : C3 { bool x; int* y; short[] z; }
        static assert(FieldNames!D3 == AliasSeq!("x", "y", "z"));
        static assert(__traits(isNested, D3));
    }
    {
        static union U0 {}
        static assert(FieldNames!U0.length == 0);

        static union U1 { int a; }
        static assert(FieldNames!U1 == AliasSeq!"a");

        static union U2 { int a; string b; }
        static assert(FieldNames!U2 == AliasSeq!("a", "b"));

        static union U3 { int a; string b; real c; }
        static assert(FieldNames!U3 == AliasSeq!("a", "b", "c"));
    }
    {
        static struct S
        {
            enum e = 42;
            static str = "foobar";

            string name() { return "foo"; }

            int[] arr;

            struct Inner1 { int i; }

            static struct Inner2 { long gnol; }

            union { int a; string b; }

            alias Foo = Inner1;
        }

        static assert(FieldNames!S == AliasSeq!("arr", "a", "b"));
        static assert(FieldNames!(const S) == AliasSeq!("arr", "a", "b"));
        static assert(FieldNames!(S.Inner1) == AliasSeq!"i");
        static assert(FieldNames!(S.Inner2) == AliasSeq!"gnol");
    }
}

/++
    Evaluates to an $(D AliasSeq) of the symbols for the member variables of an
    aggregate type (i.e. a struct, class, interface, or union).

    These are fields which take up memory space within an instance of the type
    (i.e. not enums / manifest constants, since they don't take up memory
    space, and not static member variables, since they don't take up memory
    space within an instance).

    Hidden fields (like the virtual function table pointer or the context
    pointer for nested types) are not included.

    For classes, only the direct member variables are included and not those
    of any base classes.

    For interfaces, the result of FieldSymbols is always empty, because
    interfaces cannot have member variables. However, because interfaces are
    aggregate types, they work with FieldSymbols for consistency so that code
    that's written to work on aggregate types doesn't have to worry about
    whether it's dealing with an interface.

    In most cases, $(D FieldSymbols!T) has the same result as $(D T.tupleof).
    The difference is that for nested structs with a context pointer,
    $(D T.tupleof) includes the context pointer, whereas $(D FieldSymbols!T)
    does not. For non-nested structs, and for classes, interfaces, and unions,
    $(D FieldSymbols!T) and $(D T.tupleof) are the same.

    So, for most cases, $(D T.tupleof) is sufficient and avoids instantiating
    an additional template, but FieldSymbols is provided so that the code that
    needs to avoid including context pointers in the list of fields can do so
    without the programmer having to figure how to do that correctly. It also
    provides a template that's equivalent to what $(LREF FieldNames) and
    $(LREF FieldTypes) do in terms of which fields it gives (the difference of
    course then being whether you get the symbols, names, or types for the
    fields), whereas the behavior for $(D tupleof) is subtly different.

    See_Also:
        $(LREF FieldNames)
        $(LREF FieldTypes)
        $(DDSUBLINK spec/struct.html, struct_instance_properties, $(D tupleof))
        $(DDSUBLINK spec/traits, isNested, $(D __traits(isNested, ...))).
        $(DDSUBLINK spec/traits, isSame, $(D __traits(isSame, ...))).
  +/
template FieldSymbols(T)
if (isAggregateType!T)
{
    static if (is(T == struct) && __traits(isNested, T))
    {
        import phobos.sys.meta : AliasSeq;
        alias FieldSymbols = AliasSeq!(T.tupleof[0 .. $ - 1]);
    }
    else
        alias FieldSymbols = T.tupleof;
}

///
@safe unittest
{
    import phobos.sys.meta : AliasSeq;

    struct S
    {
        int x;
        float y;
    }
    static assert(__traits(isSame, FieldSymbols!S, AliasSeq!(S.x, S.y)));

    // FieldSymbols!S and S.tupleof are the same, because S is not nested.
    static assert(__traits(isSame, FieldSymbols!S, S.tupleof));

    // Note that type qualifiers _should_ be passed on to the result, but due
    // to https://issues.dlang.org/show_bug.cgi?id=24516, they aren't.
    // FieldTypes does not have this problem, because it aliases the types
    // rather than the symbols, so if you need the types from the symbols, you
    // should use either FieldTypes or tupleof until the compiler bug has been
    // fixed (and if you use tupleof, you need to avoid aliasing the result
    // before getting the types from it).
    static assert(is(typeof(FieldSymbols!S[0]) == int));

    // These currently fail when they shouldn't:
    //static assert(is(typeof(FieldSymbols!(const S)[0]) == const int));
    //static assert(is(typeof(FieldSymbols!(shared S)[0]) == shared int));

    class C
    {
        // static variables are not included.
        static int var;

        // Manifest constants are not included.
        enum lang = "dlang";

        // Functions are not included, even if they're @property functions.
        @property int foo() { return 42; }

        string s;
        int i;
        int[] arr;
    }
    static assert(__traits(isSame, FieldSymbols!C, AliasSeq!(C.s, C.i, C.arr)));

    // FieldSymbols!C and C.tupleof have the same symbols, because they are
    // always the same for classes.
    static assert(__traits(isSame, FieldSymbols!C, C.tupleof));

    // Only direct member variables are included. Member variables from any base
    // classes are not.
    class D : C
    {
        real r;
    }
    static assert(__traits(isSame, FieldSymbols!D, AliasSeq!(D.r)));
    static assert(__traits(isSame, FieldSymbols!D, D.tupleof));

    // FieldSymbols will always be empty for an interface, since it's not legal
    // for interfaces to have member variables.
    interface I
    {
    }
    static assert(FieldSymbols!I.length == 0);
    static assert(I.tupleof.length == 0);

    union U
    {
        int i;
        double d;
        long l;
        S s;
    }
    static assert(__traits(isSame, FieldSymbols!U, AliasSeq!(U.i, U.d, U.l, U.s)));

    // FieldSymbols!C and C.tupleof have the same symbols, because they are
    // always the same for unions.
    static assert(__traits(isSame, FieldSymbols!U, U.tupleof));

    // FieldSymbols only operates on aggregate types.
    static assert(!__traits(compiles, FieldSymbols!int));
    static assert(!__traits(compiles, FieldSymbols!(S*)));
    static assert(!__traits(compiles, FieldSymbols!(C[])));
}

/// Some examples with nested types.
@safe unittest
{
    import phobos.sys.meta : AliasSeq;

    int outside;

    struct S
    {
        long l;
        string s;

        void foo() { outside = 2; }
    }
    static assert(__traits(isNested, S));
    static assert(__traits(isSame, FieldSymbols!S, AliasSeq!(S.l, S.s)));

    // FieldSymbols!S and S.tupleof are not the same, because S is nested, and
    // the context pointer to the outer scope is included in S.tupleof, whereas
    // it is excluded from FieldSymbols!S.
    static assert(__traits(isSame, S.tupleof[0 .. $ - 1], AliasSeq!(S.l, S.s)));
    static assert(S.tupleof[$ - 1].stringof == "this");

    class C
    {
        bool b;
        int* ptr;

        void foo() { outside = 7; }
    }
    static assert(__traits(isNested, C));
    static assert(__traits(isSame, FieldSymbols!C, AliasSeq!(C.b, C.ptr)));

    // FieldSymbols!C and C.tupleof have the same symbols, because they are
    // always the same for classes. No context pointer is provided as part of
    // tupleof for nested classes.
    static assert(__traits(isSame, FieldSymbols!C, C.tupleof));

    // __traits(isNested, ...) is never true for interfaces or unions, since
    // they cannot have a context pointer to an outer scope. So, tupleof and
    // FieldSymbols will always be the same for interfaces and unions.
}

@safe unittest
{
    import phobos.sys.meta : AliasSeq;

    {
        static struct S0 {}
        static assert(FieldSymbols!S0.length == 0);

        static struct S1 { int a; }
        static assert(__traits(isSame, FieldSymbols!S1, AliasSeq!(S1.a)));

        static struct S2 { int a; string b; }
        static assert(__traits(isSame, FieldSymbols!S2, AliasSeq!(S2.a, S2.b)));

        static struct S3 { int a; string b; real c; }
        static assert(__traits(isSame, FieldSymbols!S3, AliasSeq!(S3.a, S3.b, S3.c)));
    }
    {
        int i;
        struct S0 { void foo() { i = 0; }}
        static assert(FieldSymbols!S0.length == 0);
        static assert(__traits(isNested, S0));

        struct S1 { int a; void foo() { i = 0; } }
        static assert(__traits(isSame, FieldSymbols!S1, AliasSeq!(S1.a)));
        static assert(__traits(isNested, S1));

        struct S2 { int a; string b; void foo() { i = 0; } }
        static assert(__traits(isSame, FieldSymbols!S2, AliasSeq!(S2.a, S2.b)));
        static assert(__traits(isNested, S2));

        struct S3 { int a; string b; real c; void foo() { i = 0; } }
        static assert(__traits(isSame, FieldSymbols!S3, AliasSeq!(S3.a, S3.b, S3.c)));
        static assert(__traits(isNested, S3));
    }
    {
        static class C0 {}
        static assert(FieldSymbols!C0.length == 0);

        static class C1 { int a; }
        static assert(__traits(isSame, FieldSymbols!C1, AliasSeq!(C1.a)));

        static class C2 { int a; string b; }
        static assert(__traits(isSame, FieldSymbols!C2, AliasSeq!(C2.a, C2.b)));

        static class C3 { int a; string b; real c; }
        static assert(__traits(isSame, FieldSymbols!C3, AliasSeq!(C3.a, C3.b, C3.c)));

        static class D0 : C3 {}
        static assert(FieldSymbols!D0.length == 0);

        static class D1 : C3 { bool x; }
        static assert(__traits(isSame, FieldSymbols!D1, AliasSeq!(D1.x)));

        static class D2 : C3 { bool x; int* y; }
        static assert(__traits(isSame, FieldSymbols!D2, AliasSeq!(D2.x, D2.y)));

        static class D3 : C3 { bool x; int* y; short[] z; }
        static assert(__traits(isSame, FieldSymbols!D3, AliasSeq!(D3.x, D3.y, D3.z)));
    }
    {
        int i;
        class C0 { void foo() { i = 0; }}
        static assert(FieldSymbols!C0.length == 0);
        static assert(__traits(isNested, C0));

        class C1 { int a; void foo() { i = 0; } }
        static assert(__traits(isSame, FieldSymbols!C1, AliasSeq!(C1.a)));
        static assert(__traits(isNested, C1));

        class C2 { int a; string b; void foo() { i = 0; } }
        static assert(__traits(isSame, FieldSymbols!C2, AliasSeq!(C2.a, C2.b)));
        static assert(__traits(isNested, C2));

        class C3 { int a; string b; real c; void foo() { i = 0; } }
        static assert(__traits(isSame, FieldSymbols!C3, AliasSeq!(C3.a, C3.b, C3.c)));
        static assert(__traits(isNested, C3));

        class D0 : C3 {}
        static assert(FieldSymbols!D0.length == 0);
        static assert(__traits(isNested, D0));

        class D1 : C3 { bool x; }
        static assert(__traits(isSame, FieldSymbols!D1, AliasSeq!(D1.x)));
        static assert(__traits(isNested, D1));

        class D2 : C3 { bool x; int* y; }
        static assert(__traits(isSame, FieldSymbols!D2, AliasSeq!(D2.x, D2.y)));
        static assert(__traits(isNested, D2));

        class D3 : C3 { bool x; int* y; short[] z; }
        static assert(__traits(isSame, FieldSymbols!D3, AliasSeq!(D3.x, D3.y, D3.z)));
        static assert(__traits(isNested, D3));
    }
    {
        static union U0 {}
        static assert(FieldSymbols!U0.length == 0);

        static union U1 { int a; }
        static assert(__traits(isSame, FieldSymbols!U1, AliasSeq!(U1.a)));

        static union U2 { int a; string b; }
        static assert(__traits(isSame, FieldSymbols!U2, AliasSeq!(U2.a, U2.b)));

        static union U3 { int a; string b; real c; }
        static assert(__traits(isSame, FieldSymbols!U3, AliasSeq!(U3.a, U3.b, U3.c)));
    }
    {
        static struct S
        {
            enum e = 42;
            static str = "foobar";

            string name() { return "foo"; }

            int[] arr;

            struct Inner1 { int i; }

            static struct Inner2 { long gnol; }

            union { int a; string b; }

            alias Foo = Inner1;
        }

        static assert(__traits(isSame, FieldSymbols!S, AliasSeq!(S.arr, S.a, S.b)));
        static assert(__traits(isSame, FieldSymbols!(const S), AliasSeq!(S.arr, S.a, S.b)));
        static assert(__traits(isSame, FieldSymbols!(S.Inner1), AliasSeq!(S.Inner1.i)));
        static assert(__traits(isSame, FieldSymbols!(S.Inner2), AliasSeq!(S.Inner2.gnol)));
    }
}

/++
    Evaluates to an $(D AliasSeq) of the types of the member variables of an
    aggregate type (i.e. a struct, class, interface, or union).

    These are fields which take up memory space within an instance of the type
    (i.e. not enums / manifest constants, since they don't take up memory
    space, and not static member variables, since they don't take up memory
    space within an instance).

    Hidden fields (like the virtual function table pointer or the context
    pointer for nested types) are not included.

    For classes, only the direct member variables are included and not those
    of any base classes.

    For interfaces, the result of FieldTypes is always empty, because
    interfaces cannot have member variables. However, because interfaces are
    aggregate types, they work with FieldTypes for consistency so that code
    that's written to work on aggregate types doesn't have to worry about
    whether it's dealing with an interface.

    See_Also:
        $(LREF FieldNames)
        $(LREF FieldSymbols)
        $(DDSUBLINK spec/struct.html, struct_instance_properties, $(D tupleof))
  +/
template FieldTypes(T)
if (isAggregateType!T)
{
    static if (is(T == struct) && __traits(isNested, T))
        alias FieldTypes = typeof(T.tupleof[0 .. $ - 1]);
    else
        alias FieldTypes = typeof(T.tupleof);
}

///
@safe unittest
{
    import phobos.sys.meta : AliasSeq;

    struct S
    {
        int x;
        float y;
    }
    static assert(is(FieldTypes!S == AliasSeq!(int, float)));

    // Type qualifers will be passed on to the result.
    static assert(is(FieldTypes!(const S) == AliasSeq!(const int, const float)));
    static assert(is(FieldTypes!(shared S) == AliasSeq!(shared int, shared float)));

    class C
    {
        // static variables are not included.
        static int var;

        // Manifest constants are not included.
        enum lang = "dlang";

        // Functions are not included, even if they're @property functions.
        @property int foo() { return 42; }

        string s;
        int i;
        int[] arr;
    }
    static assert(is(FieldTypes!C == AliasSeq!(string, int, int[])));

    // Only direct member variables are included. Member variables from any base
    // classes are not.
    class D : C
    {
        real r;
    }
    static assert(is(FieldTypes!D == AliasSeq!real));

    // FieldTypes will always be empty for an interface, since it's not legal
    // for interfaces to have member variables.
    interface I
    {
    }
    static assert(FieldTypes!I.length == 0);

    union U
    {
        int i;
        double d;
        long l;
        S s;
    }
    static assert(is(FieldTypes!U == AliasSeq!(int, double, long, S)));

    // FieldTypes only operates on aggregate types.
    static assert(!__traits(compiles, FieldTypes!int));
    static assert(!__traits(compiles, FieldTypes!(S*)));
    static assert(!__traits(compiles, FieldTypes!(C[])));
}

@safe unittest
{
    import phobos.sys.meta : AliasSeq;

    {
        static struct S0 {}
        static assert(FieldTypes!S0.length == 0);

        static struct S1 { int a; }
        static assert(is(FieldTypes!S1 == AliasSeq!int));

        static struct S2 { int a; string b; }
        static assert(is(FieldTypes!S2 == AliasSeq!(int, string)));

        static struct S3 { int a; string b; real c; }
        static assert(is(FieldTypes!S3 == AliasSeq!(int, string, real)));
    }
    {
        int i;
        struct S0 { void foo() { i = 0; }}
        static assert(FieldTypes!S0.length == 0);
        static assert(__traits(isNested, S0));

        struct S1 { int a; void foo() { i = 0; } }
        static assert(is(FieldTypes!S1 == AliasSeq!int));
        static assert(__traits(isNested, S1));

        struct S2 { int a; string b; void foo() { i = 0; } }
        static assert(is(FieldTypes!S2 == AliasSeq!(int, string)));
        static assert(__traits(isNested, S2));

        struct S3 { int a; string b; real c; void foo() { i = 0; } }
        static assert(is(FieldTypes!S3 == AliasSeq!(int, string, real)));
        static assert(__traits(isNested, S3));
    }
    {
        static class C0 {}
        static assert(FieldTypes!C0.length == 0);

        static class C1 { int a; }
        static assert(is(FieldTypes!C1 == AliasSeq!int));

        static class C2 { int a; string b; }
        static assert(is(FieldTypes!C2 == AliasSeq!(int, string)));

        static class C3 { int a; string b; real c; }
        static assert(is(FieldTypes!C3 == AliasSeq!(int, string, real)));

        static class D0 : C3 {}
        static assert(FieldTypes!D0.length == 0);

        static class D1 : C3 { bool x; }
        static assert(is(FieldTypes!D1 == AliasSeq!bool));

        static class D2 : C3 { bool x; int* y; }
        static assert(is(FieldTypes!D2 == AliasSeq!(bool, int*)));

        static class D3 : C3 { bool x; int* y; short[] z; }
        static assert(is(FieldTypes!D3 == AliasSeq!(bool, int*, short[])));
    }
    {
        int i;
        class C0 { void foo() { i = 0; }}
        static assert(FieldTypes!C0.length == 0);
        static assert(__traits(isNested, C0));

        class C1 { int a; void foo() { i = 0; } }
        static assert(is(FieldTypes!C1 == AliasSeq!int));
        static assert(__traits(isNested, C1));

        class C2 { int a; string b; void foo() { i = 0; } }
        static assert(is(FieldTypes!C2 == AliasSeq!(int, string)));
        static assert(__traits(isNested, C2));

        class C3 { int a; string b; real c; void foo() { i = 0; } }
        static assert(is(FieldTypes!C3 == AliasSeq!(int, string, real)));
        static assert(__traits(isNested, C3));

        class D0 : C3 {}
        static assert(FieldTypes!D0.length == 0);
        static assert(__traits(isNested, D0));

        class D1 : C3 { bool x; }
        static assert(is(FieldTypes!D1 == AliasSeq!bool));
        static assert(__traits(isNested, D1));

        class D2 : C3 { bool x; int* y; }
        static assert(is(FieldTypes!D2 == AliasSeq!(bool, int*)));
        static assert(__traits(isNested, D2));

        class D3 : C3 { bool x; int* y; short[] z; }
        static assert(is(FieldTypes!D3 == AliasSeq!(bool, int*, short[])));
        static assert(__traits(isNested, D3));
    }
    {
        static union U0 {}
        static assert(FieldTypes!U0.length == 0);

        static union U1 { int a; }
        static assert(is(FieldTypes!U1 == AliasSeq!int));

        static union U2 { int a; string b; }
        static assert(is(FieldTypes!U2 == AliasSeq!(int, string)));

        static union U3 { int a; string b; real c; }
        static assert(is(FieldTypes!U3 == AliasSeq!(int, string, real)));
    }
    {
        static struct S
        {
            enum e = 42;
            static str = "foobar";

            string name() { return "foo"; }

            int[] arr;

            struct Inner1 { int i; }

            static struct Inner2 { long gnol; }

            union { int a; string b; }

            alias Foo = Inner1;
        }

        static assert(is(FieldTypes!S == AliasSeq!(int[], int, string)));
        static assert(is(FieldTypes!(const S) == AliasSeq!(const(int[]), const int, const string)));
        static assert(is(FieldTypes!(S.Inner1) == AliasSeq!int));
        static assert(is(FieldTypes!(S.Inner2) == AliasSeq!long));
    }
}

/++
    Whether assigning to a variable of the given type involves either a
    user-defined $(D opAssign) or a compiler-generated $(D opAssign) rather than
    using the default assignment behavior (which would use $(D memcpy)). The
    $(D opAssign) must accept the same type (with compatible qualifiers) as the
    type which the $(D opAssign) is declared on for it to count for
    hasComplexAssignment.

    The compiler will generate an $(D opAssign) for a struct when a member
    variable of that struct defines an $(D opAssign). It will also generate one
    when the struct has a postblit constructor or destructor (and those can be
    either user-defined or compiler-generated).

    However, due to $(BUGZILLA 24834), the compiler does not currently generate
    an $(D opAssign) for structs that define a copy constructor, and so
    hasComplexAssignment is $(D false) for such types unless they have an
    explicit $(D opAssign), or the compiler generates one due to a member
    variable having an $(D opAssign).

    Note that hasComplexAssignment is also $(D true) for static arrays whose
    element type has an $(D opAssign), since while the static array itself does
    not have an $(D opAssign), the compiler must use the $(D opAssign) of the
    elements when assigning to the static array.

    Due to $(BUGZILLA 24833), enums never have complex assignment even if their
    base type does. Their $(D opAssign) is never called, resulting in incorrect
    behavior for such enums. So, because the compiler does not treat them as
    having complex assignment, hasComplexAssignment is $(D false) for them.

    No other types (including class references, pointers, and unions)
    ever have an $(D opAssign) and thus hasComplexAssignment is never $(D true)
    for them. It is particularly important to note that unions never have an
    $(D opAssign), so if a struct contains a union which contains one or more
    members which have an $(D opAssign), that struct will have to have a
    user-defined $(D opAssign) which explicitly assigns to the correct member
    of the union if you don't want the current value of the union to simply be
    memcopied when assigning to the struct.

    One big reason that code would need to worry about hasComplexAssignment is
    if void initialization is used anywhere. While it might be okay to assign
    to uninitialized memory for a type where assignment does a memcopy,
    assigning to uninitialized memory will cause serious issues with any
    $(D opAssign) which looks at the object before assigning to it (e.g.
    because the type uses reference counting). In such cases,
    $(REF copyEmplace, core, sys, lifetime) needs to be used instead of
    assignment.

    See_Also:
        $(LREF hasComplexCopying)
        $(LREF hasComplexDestruction)
        $(DDSUBLINK spec/operatoroverloading, assignment,
                    The language spec for overloading assignment)
        $(DDSUBLINK spec/struct, assign-overload,
                    The language spec for $(D opAssign) on structs)
  +/
template hasComplexAssignment(T)
{
    import core.internal.traits : hasElaborateAssign;
    alias hasComplexAssignment = hasElaborateAssign!T;
}

///
@safe unittest
{
    static assert(!hasComplexAssignment!int);
    static assert(!hasComplexAssignment!real);
    static assert(!hasComplexAssignment!string);
    static assert(!hasComplexAssignment!(int[]));
    static assert(!hasComplexAssignment!(int[42]));
    static assert(!hasComplexAssignment!(int[string]));
    static assert(!hasComplexAssignment!Object);

    static struct NoOpAssign
    {
        int i;
    }
    static assert(!hasComplexAssignment!NoOpAssign);

    // For complex assignment, the parameter type must match the type of the
    // struct (with compatible qualifiers), but refness does not matter (though
    // it will obviously affect whether rvalues will be accepted as well as
    // whether non-copyable types will be accepted).
    static struct HasOpAssign
    {
        void opAssign(HasOpAssign) {}
    }
    static assert( hasComplexAssignment!HasOpAssign);
    static assert(!hasComplexAssignment!(const(HasOpAssign)));

    static struct HasOpAssignRef
    {
        void opAssign(ref HasOpAssignRef) {}
    }
    static assert( hasComplexAssignment!HasOpAssignRef);
    static assert(!hasComplexAssignment!(const(HasOpAssignRef)));

    static struct HasOpAssignAutoRef
    {
        void opAssign()(auto ref HasOpAssignAutoRef) {}
    }
    static assert( hasComplexAssignment!HasOpAssignAutoRef);
    static assert(!hasComplexAssignment!(const(HasOpAssignAutoRef)));

    // Assigning a mutable value works when opAssign takes const, because
    // mutable implicitly converts to const, but assigning to a const variable
    // does not work, so normally, a const object is not considered to have
    // complex assignment.
    static struct HasOpAssignC
    {
        void opAssign(const HasOpAssignC) {}
    }
    static assert( hasComplexAssignment!HasOpAssignC);
    static assert(!hasComplexAssignment!(const(HasOpAssignC)));

    // If opAssign is const, then assigning to a const variable will work, and a
    // const object will have complex assignment. However, such a type would
    // not normally make sense, since it can't actually be mutated by opAssign.
    static struct HasConstOpAssignC
    {
        void opAssign(const HasConstOpAssignC) const {}
    }
    static assert( hasComplexAssignment!HasConstOpAssignC);
    static assert( hasComplexAssignment!(const(HasConstOpAssignC)));

    // For a type to have complex assignment, the types must match aside from
    // the qualifiers. So, an opAssign which takes another type does not count
    // as complex assignment.
    static struct OtherOpAssign
    {
        void opAssign(int) {}
    }
    static assert(!hasComplexAssignment!OtherOpAssign);

    // The return type doesn't matter for complex assignment, though normally,
    // opAssign should either return a reference to the this reference (so that
    // assignments can be chained) or void.
    static struct HasOpAssignWeirdRet
    {
        int opAssign(HasOpAssignWeirdRet) { return 42; }
    }
    static assert( hasComplexAssignment!HasOpAssignWeirdRet);

    // The compiler will generate an assignment operator if a member variable
    // has one.
    static struct HasMemberWithOpAssign
    {
        HasOpAssign s;
    }
    static assert( hasComplexAssignment!HasMemberWithOpAssign);

    // The compiler will generate an assignment operator if the type has a
    // postblit constructor or a destructor.
    static struct HasDtor
    {
        ~this() {}
    }
    static assert( hasComplexAssignment!HasDtor);

    // If a struct has @disabled opAssign (and thus assigning to a variable of
    // that type will result in a compilation error), then
    // hasComplexAssignment is false.
    // Code that wants to check whether assignment works will need to test that
    // assigning to a variable of that type compiles (which could need to test
    // both an lvalue and an rvalue depending on the exact sort of assignment
    // the code is actually going to do).
    static struct DisabledOpAssign
    {
        @disable void opAssign(DisabledOpAssign);
    }
    static assert(!hasComplexAssignment!DisabledOpAssign);
    static assert(!__traits(compiles, { DisabledOpAssign s;
                                        s = rvalueOf!DisabledOpAssign;
                                        s = lvalueOf!DisabledOpAssign; }));
    static assert(!is(typeof({ DisabledOpAssign s;
                               s = rvalueOf!DisabledOpAssign;
                               s = lvalueOf!DisabledOpAssign; })));

    // Static arrays have complex assignment if their elements do.
    static assert( hasComplexAssignment!(HasOpAssign[1]));

    // Static arrays with no elements do not have complex assignment, because
    // there's nothing to assign to.
    static assert(!hasComplexAssignment!(HasOpAssign[0]));

    // Dynamic arrays do not have complex assignment, because assigning to them
    // just slices them rather than assigning to their elements. Assigning to
    // an array with a slice operation - e.g. arr[0 .. 5] = other[0 .. 5]; -
    // does use opAssign if the elements have it, but since assigning to the
    // array itself does not, hasComplexAssignment is false for dynamic arrays.
    static assert(!hasComplexAssignment!(HasOpAssign[]));

    // Classes and unions do not have complex assignment even if they have
    // members which do.
    class C
    {
        HasOpAssign s;
    }
    static assert(!hasComplexAssignment!C);

    union U
    {
        HasOpAssign s;
    }
    static assert(!hasComplexAssignment!U);

    // https://issues.dlang.org/show_bug.cgi?id=24833
    // This static assertion fails, because the compiler
    // currently ignores assignment operators for enum types.
    enum E : HasOpAssign { a = HasOpAssign.init }
    //static assert( hasComplexAssignment!E);
}

@safe unittest
{
    import phobos.sys.meta : AliasSeq;

    {
        struct S1 { int i; }
        struct S2 { real r; }
        struct S3 { string s; }
        struct S4 { int[] arr; }
        struct S5 { int[0] arr; }
        struct S6 { int[42] arr; }
        struct S7 { int[string] aa; }

        static foreach (T; AliasSeq!(S1, S2, S3, S4, S5, S6, S7))
        {
            static assert(!hasComplexAssignment!T);
            static assert(!hasComplexAssignment!(T[0]));
            static assert(!hasComplexAssignment!(T[42]));
            static assert(!hasComplexAssignment!(T[]));
        }
    }

    // Basic variations of opAssign.
    {
        static struct S { void opAssign(S) {} }
        static assert( hasComplexAssignment!S);

        static struct S2 { S s; }
        static assert( hasComplexAssignment!S2);
    }
    {
        static struct S { void opAssign(ref S) {} }
        static assert( hasComplexAssignment!S);

        static struct S2 { S s; }
        static assert( hasComplexAssignment!S2);
    }
    {
        static struct S { void opAssign()(auto ref S) {} }
        static assert( hasComplexAssignment!S);

        static struct S2 { S s; }
        static assert( hasComplexAssignment!S2);
    }
    {
        static struct S { ref opAssign(S) { return this; } }
        static assert( hasComplexAssignment!S);

        static struct S2 { S s; }
        static assert( hasComplexAssignment!S2);
    }
    {
        static struct S { ref opAssign(ref S) { return this; } }
        static assert( hasComplexAssignment!S);

        static struct S2 { S s; }
        static assert( hasComplexAssignment!S2);
    }
    {
        static struct S { ref opAssign()(auto ref S) { return this; } }
        static assert( hasComplexAssignment!S);

        static struct S2 { S s; }
        static assert( hasComplexAssignment!S2);
    }
    {
        static struct S { ref opAssign(T)(auto ref T) { return this; } }
        static assert( hasComplexAssignment!S);

        static struct S2 { S s; }
        static assert( hasComplexAssignment!S2);
    }

    // Non-complex opAssign.
    {
        static struct S { ref opAssign(int) { return this; } }
        static assert(!hasComplexAssignment!S);

        static struct S2 { S s; }
        static assert(!hasComplexAssignment!S2);
    }
    {
        struct Other {}
        static struct S { ref opAssign(Other) { return this; } }
        static assert(!hasComplexAssignment!S);

        static struct S2 { S s; }
        static assert(!hasComplexAssignment!S2);
    }

    // Multiple opAssigns.
    {
        static struct S
        {
            void opAssign(S) {}
            void opAssign(int) {}
        }
        static assert( hasComplexAssignment!S);

        static struct S2 { S s; }
        static assert( hasComplexAssignment!S2);
    }
    {
        // This just flips the order of the previous test to catch potential
        // bugs related to the order of declaration, since that's occasionally
        // popped up in the compiler in other contexts.
        static struct S
        {
            void opAssign(int) {}
            void opAssign(S) {}
        }
        static assert( hasComplexAssignment!S);

        static struct S2 { S s; }
        static assert( hasComplexAssignment!S2);
    }
    {
        static struct S
        {
            void opAssign(S) {}
            void opAssign(ref S) {}
            void opAssign(const ref S) {}
        }
        static assert( hasComplexAssignment!S);

        static struct S2 { S s; }
        static assert( hasComplexAssignment!S2);
    }

    // Make sure that @disabled alternate opAssigns don't cause issues.
    {
        static struct S
        {
            void opAssign(S) {}
            @disable void opAssign(ref S) {}
        }
        static assert( hasComplexAssignment!S);

        // See https://issues.dlang.org/show_bug.cgi?id=24854
        // The compiler won't generate any opAssign (even if it theoretically
        // can) if the member variable has an @disabled opAssign which counts as
        // complex assignment.
        static struct S2 { S s; }
        static assert(!hasComplexAssignment!S2);
    }
    {
        static struct S
        {
            void opAssign(T)(T) {}
            @disable void opAssign(T)(ref T) {}
        }
        static assert( hasComplexAssignment!S);

        static struct S2 { S s; }
        static assert(!hasComplexAssignment!S2);
    }
    {
        static struct S
        {
            @disable void opAssign(S) {}
            void opAssign(ref S) {}
        }
        static assert( hasComplexAssignment!S);

        static struct S2 { S s; }
        static assert(!hasComplexAssignment!S2);
    }
    {
        static struct S
        {
            @disable void opAssign(T)(T) {}
            void opAssign(T)(ref T) {}
        }
        static assert( hasComplexAssignment!S);

        static struct S2 { S s; }
        static assert(!hasComplexAssignment!S2);
    }
    {
        static struct S
        {
            void opAssign(S) {}
            @disable void opAssign(int) {}
        }
        static assert( hasComplexAssignment!S);

        static struct S2 { S s; }
        static assert( hasComplexAssignment!S2);
    }
    {
        // The same as the previous test but in reverse order just to catch
        // compiler bugs related to the order of declaration.
        static struct S
        {
            @disable void opAssign(int) {}
            void opAssign(S) {}
        }
        static assert( hasComplexAssignment!S);

        static struct S2 { S s; }
        static assert( hasComplexAssignment!S2);
    }

    // Generated opAssign due to other functions.
    {
        static struct S { this(this) {} }
        static assert( hasComplexAssignment!S);

        static struct S2 { S s; }
        static assert( hasComplexAssignment!S2);
    }
    // https://issues.dlang.org/show_bug.cgi?id=24834
    /+
    {
        static struct S { this(ref S) {} }
        static assert( hasComplexAssignment!S);

        static struct S2 { S s; }
        static assert( hasComplexAssignment!S2);
    }
    +/
    {
        static struct S { ~this() {}  }
        static assert( hasComplexAssignment!S);

        static struct S2 { S s; }
        static assert( hasComplexAssignment!S2);
    }

    {
        static struct S
        {
            this(this) {}
            @disable void opAssign()(auto ref S) {}
        }
        static assert(!hasComplexAssignment!S);

        static struct S2 { S s; }
        static assert(!hasComplexAssignment!S2);
    }
    {
        static struct S
        {
            this(this) {}
            void opAssign()(auto ref S) {}
            @disable void opAssign(int) {}
        }
        static assert( hasComplexAssignment!S);

        static struct S2 { S s; }
        static assert( hasComplexAssignment!S2);
    }

    // Static arrays
    {
        static struct S { void opAssign(S) {} }
        static assert( hasComplexAssignment!S);

        static assert(!hasComplexAssignment!(S[0]));
        static assert( hasComplexAssignment!(S[12]));
        static assert(!hasComplexAssignment!(S[]));

        static struct S2 { S[42] s; }
        static assert( hasComplexAssignment!S2);
    }
}

/++
    Whether copying an object of the given type involves either a user-defined
    copy / postblit constructor or a compiler-generated copy / postblit
    constructor rather than using the default copying behavior (which would use
    $(D memcpy)).

    The compiler will generate a copy / postblit constructor for a struct when
    a member variable of that struct defines a copy / postblit constructor.

    Note that hasComplexCopying is also $(D true) for static arrays whose
    element type has a copy constructor or postblit constructor, since while
    the static array itself does not have a copy constructor or postblit
    constructor, the compiler must use the copy / postblit constructor of the
    elements when copying the static array.

    Due to $(BUGZILLA 24833), enums never have complex copying even if their
    base type does. Their copy / postblit constructor is never called,
    resulting in incorrect behavior for such enums. So, because the compiler
    does not treat them as having complex copying, hasComplexCopying is
    $(D false) for them.

    No other types (including class references, pointers, and unions) ever have
    a copy constructor or postblit constructor and thus hasComplexCopying is
    never $(D true) for them. It is particularly important to note that unions
    never have a copy constructor or postblit constructor, so if a struct
    contains a union which contains one or more members which have a copy
    constructor or postblit constructor, that struct will have to have a
    user-defined copy constructor or posthblit constructor which explicitly
    copies the correct member of the union if you don't want the current value
    of the union to simply be memcopied when copying the struct.

    If a particular piece of code cares about the existence of a copy
    constructor or postblit constructor specifically rather than if a type has
    one or the other, the traits
    $(DDSUBLINK spec/traits, hasCopyConstructor, $(D __traits(hasCopyConstructor, T)))
    and
    $(DDSUBLINK spec/traits, hasPostblit, $(D __traits(hasPostblit, T))) can
    be used, though note that they will not be true for static arrays.

    See_Also:
        $(LREF hasComplexAssignment)
        $(LREF hasComplexDestruction)
        $(DDSUBLINK spec/traits, hasCopyConstructor, $(D __traits(hasCopyConstructor, T)))
        $(DDSUBLINK spec/traits, hasPostblit, $(D __traits(hasPostblit, T)))
        $(DDSUBLINK spec/traits, isCopyable, $(D __traits(isCopyable, T)))
        $(DDSUBLINK spec/structs, struct-copy-constructor, The language spec for copy constructors)
        $(DDSUBLINK spec/structs, struct-postblit, The language spec for postblit constructors)
  +/
template hasComplexCopying(T)
{
    import core.internal.traits : hasElaborateCopyConstructor;
    alias hasComplexCopying = hasElaborateCopyConstructor!T;
}

///
@safe unittest
{
    static assert(!hasComplexCopying!int);
    static assert(!hasComplexCopying!real);
    static assert(!hasComplexCopying!string);
    static assert(!hasComplexCopying!(int[]));
    static assert(!hasComplexCopying!(int[42]));
    static assert(!hasComplexCopying!(int[string]));
    static assert(!hasComplexCopying!Object);

    static struct NoCopyCtor1
    {
        int i;
    }
    static assert(!hasComplexCopying!NoCopyCtor1);
    static assert(!__traits(hasCopyConstructor, NoCopyCtor1));
    static assert(!__traits(hasPostblit, NoCopyCtor1));

    static struct NoCopyCtor2
    {
        int i;

        this(int i)
        {
            this.i = i;
        }
    }
    static assert(!hasComplexCopying!NoCopyCtor2);
    static assert(!__traits(hasCopyConstructor, NoCopyCtor2));
    static assert(!__traits(hasPostblit, NoCopyCtor2));

    struct HasCopyCtor
    {
        this(ref HasCopyCtor)
        {
        }
    }
    static assert( hasComplexCopying!HasCopyCtor);
    static assert( __traits(hasCopyConstructor, HasCopyCtor));
    static assert(!__traits(hasPostblit, HasCopyCtor));

    // hasComplexCopying does not take constness into account.
    // Code that wants to check whether copying works will need to test
    // __traits(isCopyable, T) or test that copying compiles.
    static assert( hasComplexCopying!(const HasCopyCtor));
    static assert( __traits(hasCopyConstructor, const HasCopyCtor));
    static assert(!__traits(hasPostblit, const HasCopyCtor));
    static assert(!__traits(isCopyable, const HasCopyCtor));
    static assert(!__traits(compiles, { const HasCopyCtor h;
                                        auto h2 = h; }));
    static assert(!is(typeof({ const HasCopyCtor h1;
                               auto h2 = h1; })));

    // An rvalue constructor is not a copy constructor.
    struct HasRValueCtor
    {
        this(HasRValueCtor)
        {
        }
    }
    static assert(!hasComplexCopying!HasRValueCtor);
    static assert(!__traits(hasCopyConstructor, HasRValueCtor));
    static assert(!__traits(hasPostblit, HasRValueCtor));

    struct HasPostblit
    {
        this(this)
        {
        }
    }
    static assert( hasComplexCopying!HasPostblit);
    static assert(!__traits(hasCopyConstructor, HasPostblit));
    static assert( __traits(hasPostblit, HasPostblit));

    // The compiler will generate a copy constructor if a member variable
    // has one.
    static struct HasMemberWithCopyCtor
    {
        HasCopyCtor s;
    }
    static assert( hasComplexCopying!HasMemberWithCopyCtor);

    // The compiler will generate a postblit constructor if a member variable
    // has one.
    static struct HasMemberWithPostblit
    {
        HasPostblit s;
    }
    static assert( hasComplexCopying!HasMemberWithPostblit);

    // If a struct has @disabled copying, hasComplexCopying is still true.
    // Code that wants to check whether copying works will need to test
    // __traits(isCopyable, T) or test that copying compiles.
    static struct DisabledCopying
    {
        @disable this(this);
        @disable this(ref DisabledCopying);
    }
    static assert( hasComplexCopying!DisabledCopying);
    static assert(!__traits(isCopyable, DisabledCopying));
    static assert(!__traits(compiles, { DisabledCopying dc1;
                                        auto dc2 = dc1; }));
    static assert(!is(typeof({ DisabledCopying dc1;
                               auto dc2 = dc1; })));

    // Static arrays have complex copying if their elements do.
    static assert( hasComplexCopying!(HasCopyCtor[1]));
    static assert( hasComplexCopying!(HasPostblit[1]));

    // Static arrays with no elements do not have complex copying, because
    // there's nothing to copy.
    static assert(!hasComplexCopying!(HasCopyCtor[0]));
    static assert(!hasComplexCopying!(HasPostblit[0]));

    // Dynamic arrays do not have complex copying, because copying them
    // just slices them rather than copying their elements.
    static assert(!hasComplexCopying!(HasCopyCtor[]));
    static assert(!hasComplexCopying!(HasPostblit[]));

    // Classes and unions do not have complex copying even if they have
    // members which do.
    class C
    {
        HasCopyCtor s;
    }
    static assert(!hasComplexCopying!C);

    union U
    {
        HasCopyCtor s;
    }
    static assert(!hasComplexCopying!U);

    // https://issues.dlang.org/show_bug.cgi?id=24833
    // This static assertion fails, because the compiler
    // currently ignores assignment operators for enum types.
    enum E : HasCopyCtor { a = HasCopyCtor.init }
    //static assert( hasComplexCopying!E);
}

@safe unittest
{
    import phobos.sys.meta : AliasSeq;

    {
        struct S1 { int i; }
        struct S2 { real r; }
        struct S3 { string s; }
        struct S4 { int[] arr; }
        struct S5 { int[0] arr; }
        struct S6 { int[42] arr; }
        struct S7 { int[string] aa; }

        static foreach (T; AliasSeq!(S1, S2, S3, S4, S5, S6, S7))
        {
            static assert(!hasComplexCopying!T);
            static assert(!hasComplexCopying!(T[0]));
            static assert(!hasComplexCopying!(T[42]));
            static assert(!hasComplexCopying!(T[]));
        }
    }

    // Basic variations of copy constructors.
    {
        static struct S { this(ref S) {} }
        static assert( hasComplexCopying!S);

        static struct S2 { S s; }
        static assert( hasComplexCopying!S2);
    }
    {
        static struct S { this(const ref S) const {} }
        static assert( hasComplexCopying!S);

        static struct S2 { S s; }
        static assert( hasComplexCopying!S2);
    }
    {
        static struct S
        {
            this(ref S) {}
            this(const ref S) const {}
        }
        static assert( hasComplexCopying!S);

        static struct S2 { S s; }
        static assert( hasComplexCopying!S2);
    }
    {
        static struct S { this(inout ref S) inout {} }
        static assert( hasComplexCopying!S);

        static struct S2 { S s; }
        static assert( hasComplexCopying!S2);
    }
    {
        static struct S { this(scope ref S) {} }
        static assert( hasComplexCopying!S);

        static struct S2 { S s; }
        static assert( hasComplexCopying!S2);
    }
    {
        static struct S { this(scope ref S) scope {} }
        static assert( hasComplexCopying!S);

        static struct S2 { S s; }
        static assert( hasComplexCopying!S2);
    }
    {
        static struct S { this(ref S) @safe {} }
        static assert( hasComplexCopying!S);

        static struct S2 { S s; }
        static assert( hasComplexCopying!S2);
    }
    {
        static struct S { this(ref S) nothrow {} }
        static assert( hasComplexCopying!S);

        static struct S2 { S s; }
        static assert( hasComplexCopying!S2);
    }
    {
        static struct S { this(scope inout ref S) inout scope @safe pure nothrow @nogc {} }
        static assert( hasComplexCopying!S);

        static struct S2 { S s; }
        static assert( hasComplexCopying!S2);
    }

    // Basic variations of postblit constructors.
    {
        static struct S { this(this) {} }
        static assert( hasComplexCopying!S);

        static struct S2 { S s; }
        static assert( hasComplexCopying!S2);
    }
    {
        static struct S { this(this) scope @safe pure nothrow @nogc {} }
        static assert( hasComplexCopying!S);

        static struct S2 { S s; }
        static assert( hasComplexCopying!S2);
    }

    // Rvalue constructors.
    {
        static struct S { this(S) {} }
        static assert(!hasComplexCopying!S);

        static struct S2 { S s; }
        static assert(!hasComplexCopying!S2);
    }
    {
        static struct S { this(const S) const {} }
        static assert(!hasComplexCopying!S);

        static struct S2 { S s; }
        static assert(!hasComplexCopying!S2);
    }
    {
        static struct S
        {
            this(S) {}
            this(const S) const {}
        }
        static assert(!hasComplexCopying!S);

        static struct S2 { S s; }
        static assert(!hasComplexCopying!S2);
    }
    {
        static struct S { this(inout S) inout {} }
        static assert(!hasComplexCopying!S);

        static struct S2 { S s; }
        static assert(!hasComplexCopying!S2);
    }
    {
        static struct S { this(S) @safe {} }
        static assert(!hasComplexCopying!S);

        static struct S2 { S s; }
        static assert(!hasComplexCopying!S2);
    }
    {
        static struct S { this(S) nothrow {} }
        static assert(!hasComplexCopying!S);

        static struct S2 { S s; }
        static assert(!hasComplexCopying!S2);
    }
    {
        static struct S { this(inout S) inout @safe pure nothrow @nogc {} }
        static assert(!hasComplexCopying!S);

        static struct S2 { S s; }
        static assert(!hasComplexCopying!S2);
    }

    // @disabled copy constructors.
    {
        static struct S { @disable this(ref S) {} }
        static assert( hasComplexCopying!S);

        static struct S2 { S s; }
        static assert( hasComplexCopying!S2);
    }
    {
        static struct S { @disable this(const ref S) const {} }
        static assert( hasComplexCopying!S);

        static struct S2 { S s; }
        static assert( hasComplexCopying!S2);
    }
    {
        static struct S
        {
            @disable this(ref S) {}
            this(const ref S) const {}
        }
        static assert( hasComplexCopying!S);

        static struct S2 { S s; }
        static assert( hasComplexCopying!S2);
    }
    {
        static struct S
        {
            this(ref S) {}
            @disable this(const ref S) const {}
        }
        static assert( hasComplexCopying!S);

        static struct S2 { S s; }
        static assert( hasComplexCopying!S2);
    }
    {
        static struct S
        {
            @disable this(ref S) {}
            @disable this(const ref S) const {}
        }
        static assert( hasComplexCopying!S);

        static struct S2 { S s; }
        static assert( hasComplexCopying!S2);
    }

    // Static arrays
    {
        static struct S { this(ref S) {} }
        static assert( hasComplexCopying!S);

        static assert(!hasComplexCopying!(S[0]));
        static assert( hasComplexCopying!(S[12]));
        static assert(!hasComplexCopying!(S[]));

        static struct S2 { S[42] s; }
        static assert( hasComplexCopying!S2);
    }
    {
        static struct S { this(this) {} }
        static assert( hasComplexCopying!S);

        static assert(!hasComplexCopying!(S[0]));
        static assert( hasComplexCopying!(S[12]));
        static assert(!hasComplexCopying!(S[]));

        static struct S2 { S[42] s; }
        static assert( hasComplexCopying!S2);
    }
}

/++
    Whether the given type has either a user-defined destructor or a
    compiler-generated destructor.

    The compiler will generate a destructor for a struct when a member variable
    of that struct defines a destructor.

    Note that hasComplexDestruction is also $(D true) for static arrays whose
    element type has a destructor, since while the static array itself does not
    have a destructor, the compiler must use the destructor of the elements
    when destroying the static array.

    Due to $(BUGZILLA 24833), enums never have complex destruction even if their
    base type does. Their destructor is never called, resulting in incorrect
    behavior for such enums. So, because the compiler does not treat them as
    having complex destruction, hasComplexDestruction is $(D false) for them.

    Note that while the $(DDSUBLINK spec/class, destructors, language spec)
    currently refers to $(D ~this()) on classes as destructors (whereas the
    runtime refers to them as finalizers, and they're arguably finalizers
    rather than destructors given how they work), classes are not considered to
    have complex destruction. Under normal circumstances, it's just the GC or
    $(REF1 destroy, object) which calls the destructor / finalizer on a class
    (and it's not guaranteed that a class destructor / finalizer will even ever
    be called), which is in stark contrast to structs, which normally live on
    the stack and need to be destroyed when they leave scope. So,
    hasComplexDestruction is concerned with whether that type will have a
    destructor that's run when it leaves scope and not with what happens when
    the GC destroys an object prior to freeing its memory.

    No other types (including pointers and unions) ever have a destructor and
    thus hasComplexDestruction is never $(D true) for them. It is particularly
    important to note that unions never have a destructor, so if a struct
    contains a union which contains one or more members which have a
    destructor, that struct will have to have a user-defined destructor which
    explicitly calls $(REF1 destroy, object) on the correct member of the
    union if you want the object in question to be destroyed properly.

    See_Also:
        $(LREF hasComplexAssignment)
        $(LREF hasComplexCopying)
        $(REF destroy, object)
        $(DDSUBLINK spec/structs, struct-destructor, The language spec for destructors)
        $(DDSUBLINK spec/class, destructors, The language spec for class finalizers)
  +/
template hasComplexDestruction(T)
{
    import core.internal.traits : hasElaborateDestructor;
    alias hasComplexDestruction = hasElaborateDestructor!T;
}

///
@safe unittest
{
    static assert(!hasComplexDestruction!int);
    static assert(!hasComplexDestruction!real);
    static assert(!hasComplexDestruction!string);
    static assert(!hasComplexDestruction!(int[]));
    static assert(!hasComplexDestruction!(int[42]));
    static assert(!hasComplexDestruction!(int[string]));
    static assert(!hasComplexDestruction!Object);

    static struct NoDtor
    {
        int i;
    }
    static assert(!hasComplexDestruction!NoDtor);

    struct HasDtor
    {
        ~this() {}
    }
    static assert( hasComplexDestruction!HasDtor);

    // The compiler will generate a destructor if a member variable has one.
    static struct HasMemberWithDtor
    {
        HasDtor s;
    }
    static assert( hasComplexDestruction!HasMemberWithDtor);

    // If a struct has @disabled destruction, hasComplexDestruction is still
    // true. Code that wants to check whether destruction works can either
    // test for whether the __xdtor member is disabled, or it can test whether
    // code that will destroy the object compiles. That being said, a disabled
    // destructor probably isn't very common in practice, because about all that
    // such a type is good for is being allocated on the heap.
    static struct DisabledDtor
    {
        @disable ~this() {}
    }
    static assert( hasComplexDestruction!DisabledDtor);
    static assert( __traits(isDisabled,
                            __traits(getMember, DisabledDtor, "__xdtor")));

    // A type with a disabled destructor cannot be created on the stack or used
    // in any way that would ever trigger a destructor, making it pretty much
    // useless outside of providing a way to force a struct to be allocated on
    // the heap - though that could be useful in some situations, since it
    // it makes it possible to have a type that has to be a reference type but
    // which doesn't have the overhead of a class.
    static assert(!__traits(compiles, { DisabledDtor d; }));
    static assert( __traits(compiles, { auto d = new DisabledDtor; }));

    // Static arrays have complex destruction if their elements do.
    static assert( hasComplexDestruction!(HasDtor[1]));

    // Static arrays with no elements do not have complex destruction, because
    // there's nothing to destroy.
    static assert(!hasComplexDestruction!(HasDtor[0]));

    // Dynamic arrays do not have complex destruction, because their elements
    // are contained in the memory that the dynamic array is a slice of and not
    // in the dynamic array itself, so there's nothing to destroy when a
    // dynamic array leaves scope.
    static assert(!hasComplexDestruction!(HasDtor[]));

    // Classes and unions do not have complex copying even if they have
    // members which do.
    class C
    {
        HasDtor s;
    }
    static assert(!hasComplexDestruction!C);

    union U
    {
        HasDtor s;
    }
    static assert(!hasComplexDestruction!U);

    // https://issues.dlang.org/show_bug.cgi?id=24833
    // This static assertion fails, because the compiler
    // currently ignores assignment operators for enum types.
    enum E : HasDtor { a = HasDtor.init }
    //static assert( hasComplexDestruction!E);
}

@safe unittest
{
    import phobos.sys.meta : AliasSeq;

    {
        struct S1 { int i; }
        struct S2 { real r; }
        struct S3 { string s; }
        struct S4 { int[] arr; }
        struct S5 { int[0] arr; }
        struct S6 { int[42] arr; }
        struct S7 { int[string] aa; }

        static foreach (T; AliasSeq!(S1, S2, S3, S4, S5, S6, S7))
        {
            static assert(!hasComplexDestruction!T);
            static assert(!hasComplexDestruction!(T[0]));
            static assert(!hasComplexDestruction!(T[42]));
            static assert(!hasComplexDestruction!(T[]));
        }
    }

    // Basic variations of destructors.
    {
        static struct S { ~this() {} }
        static assert( hasComplexDestruction!S);

        static struct S2 { S s; }
        static assert( hasComplexDestruction!S2);
    }
    {
        static struct S { ~this() const {} }
        static assert( hasComplexDestruction!S);

        static struct S2 { S s; }
        static assert( hasComplexDestruction!S2);
    }
    {
        static struct S { ~this() @safe {} }
        static assert( hasComplexDestruction!S);

        static struct S2 { S s; }
        static assert( hasComplexDestruction!S2);
    }
    {
        static struct S { ~this() @safe pure nothrow @nogc {} }
        static assert( hasComplexDestruction!S);

        static struct S2 { S s; }
        static assert( hasComplexDestruction!S2);
    }

    // @disabled destructors.
    {
        static struct S { @disable ~this() {} }
        static assert( __traits(isDisabled,
                                __traits(getMember, S, "__xdtor")));

        static struct S2 { S s; }
        static assert( hasComplexDestruction!S2);
        static assert( __traits(isDisabled,
                                __traits(getMember, S2, "__xdtor")));
    }

    // Static arrays
    {
        static struct S { ~this() {} }
        static assert( hasComplexDestruction!S);

        static assert(!hasComplexDestruction!(S[0]));
        static assert( hasComplexDestruction!(S[12]));
        static assert(!hasComplexDestruction!(S[]));

        static struct S2 { S[42] s; }
        static assert( hasComplexDestruction!S2);
    }
}

/++
    Evaluates to $(D true) if the given type is one or more of the following,
    or if it's a struct, union, or static array which contains one or more of
    the following:

    $(OL $(LI A raw pointer)
         $(LI A class reference)
         $(LI An interface reference)
         $(LI A dynamic array)
         $(LI An associative array)
         $(LI A delegate)
         $(LI A struct with a
              $(DDSUBLINK spec/traits, isNested, $(D context pointer)).))

    Note that function pointers are not considered to have indirections, because
    they do not point to any data (whereas a delegate has a context pointer
    and therefore has data that it points to).

    Also, while static arrays do not have indirections unless their element
    type has indirections, static arrays with an element type of $(D void) are
    considered to have indirections by hasIndirections, because it's unknown
    what type their elements actually are, so they $(I might) have
    indirections, and thus, the conservative approach is to assume that they do
    have indirections.

    Static arrays with length 0 do not have indirections no matter what their
    element type is, since they don't actually have any elements.
  +/
version (StdDdoc) template hasIndirections(T)
{
    import core.internal.traits : _hasIndirections = hasIndirections;
    alias hasIndirections = _hasIndirections!T;
}
else
{
    import core.internal.traits : _hasIndirections = hasIndirections;
    alias hasIndirections = _hasIndirections;
}

///
@safe unittest
{
    static class C {}
    static interface I {}

    static assert( hasIndirections!(int*));
    static assert( hasIndirections!C);
    static assert( hasIndirections!I);
    static assert( hasIndirections!(int[]));
    static assert( hasIndirections!(int[string]));
    static assert( hasIndirections!(void delegate()));
    static assert( hasIndirections!(string delegate(int)));

    static assert(!hasIndirections!(void function()));
    static assert(!hasIndirections!int);

    static assert(!hasIndirections!(ubyte[9]));
    static assert( hasIndirections!(ubyte[9]*));
    static assert( hasIndirections!(ubyte*[9]));
    static assert(!hasIndirections!(ubyte*[0]));
    static assert( hasIndirections!(ubyte[]));

    static assert( hasIndirections!(void[]));
    static assert( hasIndirections!(void[42]));

    static struct NoContext
    {
        int i;
    }

    int local;

    struct HasContext
    {
        int foo() { return local; }
    }

    struct HasMembersWithIndirections
    {
        int* ptr;
    }

    static assert(!hasIndirections!NoContext);
    static assert( hasIndirections!HasContext);
    static assert( hasIndirections!HasMembersWithIndirections);

    union U1
    {
        int i;
        float f;
    }
    static assert(!hasIndirections!U1);

    union U2
    {
        int i;
        int[] arr;
    }
    static assert( hasIndirections!U2);
}

// hasIndirections with types which aren't aggregate types.
@safe unittest
{
    import phobos.sys.meta : AliasSeq;

    alias testWithQualifiers = assertWithQualifiers!hasIndirections;

    foreach (T; AliasSeq!(bool, byte, ubyte, short, ushort, int, uint, long, ulong,
                          float, double, real, char, wchar, dchar, int function(string), void))
    {
        mixin testWithQualifiers!(T, false);
        mixin testWithQualifiers!(T*, true);
        mixin testWithQualifiers!(T[], true);

        mixin testWithQualifiers!(T[42], is(T == void));
        mixin testWithQualifiers!(T[0], false);

        mixin testWithQualifiers!(T*[42], true);
        mixin testWithQualifiers!(T*[0], false);

        mixin testWithQualifiers!(T[][42], true);
        mixin testWithQualifiers!(T[][0], false);
    }

    foreach (T; AliasSeq!(int[int], int delegate(string)))
    {
        mixin testWithQualifiers!(T, true);
        mixin testWithQualifiers!(T*, true);
        mixin testWithQualifiers!(T[], true);

        mixin testWithQualifiers!(T[42], true);
        mixin testWithQualifiers!(T[0], false);

        mixin testWithQualifiers!(T*[42], true);
        mixin testWithQualifiers!(T*[0], false);

        mixin testWithQualifiers!(T[][42], true);
        mixin testWithQualifiers!(T[][0], false);
    }
}

// hasIndirections with structs.
@safe unittest
{
    import phobos.sys.meta : AliasSeq;

    alias testWithQualifiers = assertWithQualifiers!hasIndirections;

    {
        struct S {}
        mixin testWithQualifiers!(S, false);
    }
    {
        static struct S {}
        mixin testWithQualifiers!(S, false);
    }
    {
        struct S { void foo() {} }
        mixin testWithQualifiers!(S, true);
    }
    {
        static struct S { void foo() {} }
        mixin testWithQualifiers!(S, false);
    }

    // Structs with members which aren't aggregate types and don't have indirections.
    foreach (T; AliasSeq!(bool, byte, ubyte, short, ushort, int, uint, long, ulong,
                          float, double, real, char, wchar, dchar, int function(string)))
    {
        // No indirections.
        {
            struct S { T member; }
            mixin testWithQualifiers!(S, false);
        }
        {
            struct S { const T member; }
            mixin testWithQualifiers!(S, false);
        }
        {
            struct S { immutable T member; }
            mixin testWithQualifiers!(S, false);
        }
        {
            struct S { shared T member; }
            mixin testWithQualifiers!(S, false);
        }

        {
            static struct S { T member; void foo() {} }
            mixin testWithQualifiers!(S, false);
        }
        {
            static struct S { const T member; void foo() {} }
            mixin testWithQualifiers!(S, false);
        }
        {
            static struct S { immutable T member; void foo() {} }
            mixin testWithQualifiers!(S, false);
        }
        {
            static struct S { shared T member; void foo() {} }
            mixin testWithQualifiers!(S, false);
        }

        // Has context pointer.
        {
            struct S { T member; void foo() {} }
            mixin testWithQualifiers!(S, true);
        }
        {
            struct S { const T member; void foo() {} }
            mixin testWithQualifiers!(S, true);
        }
        {
            struct S { immutable T member; void foo() {} }
            mixin testWithQualifiers!(S, true);
        }
        {
            struct S { shared T member; void foo() {} }
            mixin testWithQualifiers!(S, true);
        }

        {
            T local;
            struct S { void foo() { auto v = local; } }
            mixin testWithQualifiers!(S, true);
        }
        {
            const T local;
            struct S { void foo() { auto v = local; } }
            mixin testWithQualifiers!(S, true);
        }
        {
            immutable T local;
            struct S { void foo() { auto v = local; } }
            mixin testWithQualifiers!(S, true);
        }
        {
            shared T local;
            struct S { void foo() @trusted { auto v = cast() local; } }
            mixin testWithQualifiers!(S, true);
        }

        // Pointers.
        {
            struct S { T* member; }
            mixin testWithQualifiers!(S, true);
        }
        {
            struct S { const(T)* member; }
            mixin testWithQualifiers!(S, true);
        }
        {
            struct S { const T* member; }
            mixin testWithQualifiers!(S, true);
        }
        {
            struct S { immutable T* member; }
            mixin testWithQualifiers!(S, true);
        }
        {
            struct S { shared T* member; }
            mixin testWithQualifiers!(S, true);
        }

        // Dynamic arrays.
        {
            struct S { T[] member; }
            mixin testWithQualifiers!(S, true);
        }
        {
            struct S { const(T)[] member; }
            mixin testWithQualifiers!(S, true);
        }
        {
            struct S { const T[] member; }
            mixin testWithQualifiers!(S, true);
        }
        {
            struct S { immutable T[] member; }
            mixin testWithQualifiers!(S, true);
        }
        {
            struct S { shared T[] member; }
            mixin testWithQualifiers!(S, true);
        }

        // Static arrays.
        {
            struct S { T[1] member; }
            mixin testWithQualifiers!(S, false);
        }
        {
            struct S { const(T)[1] member; }
            mixin testWithQualifiers!(S, false);
        }
        {
            struct S { const T[1] member; }
            mixin testWithQualifiers!(S, false);
        }
        {
            struct S { immutable T[1] member; }
            mixin testWithQualifiers!(S, false);
        }
        {
            struct S { shared T[1] member; }
            mixin testWithQualifiers!(S, false);
        }

        // Static arrays of pointers.
        {
            struct S { T*[1] member; }
            mixin testWithQualifiers!(S, true);
        }
        {
            struct S { const(T)*[1] member; }
            mixin testWithQualifiers!(S, true);
        }
        {
            struct S { const(T*)[1] member; }
            mixin testWithQualifiers!(S, true);
        }
        {
            struct S { const T*[1] member; }
            mixin testWithQualifiers!(S, true);
        }
        {
            struct S { immutable T*[1] member; }
            mixin testWithQualifiers!(S, true);
        }
        {
            struct S { shared T*[1] member; }
            mixin testWithQualifiers!(S, true);
        }

        {
            struct S { T*[0] member; }
            mixin testWithQualifiers!(S, false);
        }
        {
            struct S { const(T)*[0] member; }
            mixin testWithQualifiers!(S, false);
        }
        {
            struct S { const(T*)[0] member; }
            mixin testWithQualifiers!(S, false);
        }
        {
            struct S { const T*[0] member; }
            mixin testWithQualifiers!(S, false);
        }
        {
            struct S { immutable T*[0] member; }
            mixin testWithQualifiers!(S, false);
        }
        {
            struct S { shared T*[0] member; }
            mixin testWithQualifiers!(S, false);
        }

        // Static arrays of dynamic arrays.
        {
            struct S { T[][1] member; }
            mixin testWithQualifiers!(S, true);
        }
        {
            struct S { const(T)[][1] member; }
            mixin testWithQualifiers!(S, true);
        }
        {
            struct S { const(T[])[1] member; }
            mixin testWithQualifiers!(S, true);
        }
        {
            struct S { const T[][1] member; }
            mixin testWithQualifiers!(S, true);
        }
        {
            struct S { immutable T[][1] member; }
            mixin testWithQualifiers!(S, true);
        }
        {
            struct S { shared T[][1] member; }
            mixin testWithQualifiers!(S, true);
        }

        {
            struct S { T[][0] member; }
            mixin testWithQualifiers!(S, false);
        }
        {
            struct S { const(T)[][0] member; }
            mixin testWithQualifiers!(S, false);
        }
        {
            struct S { const(T[])[0] member; }
            mixin testWithQualifiers!(S, false);
        }
        {
            struct S { const T[][0] member; }
            mixin testWithQualifiers!(S, false);
        }
        {
            struct S { immutable T[][0] member; }
            mixin testWithQualifiers!(S, false);
        }
        {
            struct S { shared T[][0] member; }
            mixin testWithQualifiers!(S, false);
        }
    }

    // Structs with arrays of void.
    {
        {
            static struct S { void[] member; }
            mixin testWithQualifiers!(S, true);
        }
        {
            static struct S { void[1] member; }
            mixin testWithQualifiers!(S, true);
        }
        {
            static struct S { void[0] member; }
            mixin testWithQualifiers!(S, false);
        }
    }

    // Structs with multiple members, testing pointer types.
    {
        static struct S { int i; bool b; }
        mixin testWithQualifiers!(S, false);
    }
    {
        static struct S { int* i; bool b; }
        mixin testWithQualifiers!(S, true);
    }
    {
        static struct S { int i; bool* b; }
        mixin testWithQualifiers!(S, true);
    }
    {
        static struct S { int* i; bool* b; }
        mixin testWithQualifiers!(S, true);
    }

    // Structs with multiple members, testing dynamic arrays.
    {
        static struct S { int[] arr; }
        mixin testWithQualifiers!(S, true);
    }
    {
        static struct S { int i; int[] arr; }
        mixin testWithQualifiers!(S, true);
    }
    {
        static struct S { int[] arr; int i; }
        mixin testWithQualifiers!(S, true);
    }

    // Structs with multiple members, testing static arrays.
    {
        static struct S { int[1] arr; }
        mixin testWithQualifiers!(S, false);
    }
    {
        static struct S { int i; int[1] arr; }
        mixin testWithQualifiers!(S, false);
    }
    {
        static struct S { int[1] arr; int i; }
        mixin testWithQualifiers!(S, false);
    }

    {
        static struct S { int*[0] arr; }
        mixin testWithQualifiers!(S, false);
    }
    {
        static struct S { int i; int*[0] arr; }
        mixin testWithQualifiers!(S, false);
    }
    {
        static struct S { int*[0] arr; int i; }
        mixin testWithQualifiers!(S, false);
    }

    {
        static struct S { string[42] arr; }
        mixin testWithQualifiers!(S, true);
    }
    {
        static struct S { int i; string[42] arr; }
        mixin testWithQualifiers!(S, true);
    }
    {
        static struct S { string[42] arr; int i; }
        mixin testWithQualifiers!(S, true);
    }

    // Structs with associative arrays.
    {
        static struct S { int[string] aa; }
        mixin testWithQualifiers!(S, true);
    }
    {
        static struct S { int i; int[string] aa; }
        mixin testWithQualifiers!(S, true);
    }
    {
        static struct S { int[string] aa; int i; }
        mixin testWithQualifiers!(S, true);
    }

    {
        static struct S { int[42][int] aa; }
        mixin testWithQualifiers!(S, true);
    }
    {
        static struct S { int[0][int] aa; }
        mixin testWithQualifiers!(S, true);
    }

    // Structs with classes.
    {
        class C {}
        struct S { C c; }
        mixin testWithQualifiers!(S, true);
    }
    {
        interface I {}
        struct S { I i; }
        mixin testWithQualifiers!(S, true);
    }

    // Structs with delegates.
    {
        struct S { void delegate() d; }
        mixin testWithQualifiers!(S, true);
    }
    {
        struct S { int delegate(int) d; }
        mixin testWithQualifiers!(S, true);
    }

    // Structs multiple layers deep.
    {
        struct S1 { int i; }
        struct S2 { S1 s; }
        struct S3 { S2 s; }
        struct S4 { S3 s; }
        struct S5 { S4 s; }
        struct S6 { S5 s; }
        struct S7 { S6[0] s; }
        struct S8 { S7 s; }
        struct S9 { S8 s; }
        struct S10 { S9 s; }
        mixin testWithQualifiers!(S1, false);
        mixin testWithQualifiers!(S2, false);
        mixin testWithQualifiers!(S3, false);
        mixin testWithQualifiers!(S4, false);
        mixin testWithQualifiers!(S5, false);
        mixin testWithQualifiers!(S6, false);
        mixin testWithQualifiers!(S7, false);
        mixin testWithQualifiers!(S8, false);
        mixin testWithQualifiers!(S9, false);
        mixin testWithQualifiers!(S10, false);
    }
    {
        struct S1 { int* i; }
        struct S2 { S1 s; }
        struct S3 { S2 s; }
        struct S4 { S3 s; }
        struct S5 { S4 s; }
        struct S6 { S5 s; }
        struct S7 { S6[0] s; }
        struct S8 { S7 s; }
        struct S9 { S8 s; }
        struct S10 { S9 s; }
        mixin testWithQualifiers!(S1, true);
        mixin testWithQualifiers!(S2, true);
        mixin testWithQualifiers!(S3, true);
        mixin testWithQualifiers!(S4, true);
        mixin testWithQualifiers!(S5, true);
        mixin testWithQualifiers!(S6, true);
        mixin testWithQualifiers!(S7, false);
        mixin testWithQualifiers!(S8, false);
        mixin testWithQualifiers!(S9, false);
        mixin testWithQualifiers!(S10, false);
    }
}

// hasIndirections with unions.
@safe unittest
{
    import phobos.sys.meta : AliasSeq;

    alias testWithQualifiers = assertWithQualifiers!hasIndirections;

    {
        union U {}
        mixin testWithQualifiers!(U, false);
    }
    {
        static union U {}
        mixin testWithQualifiers!(U, false);
    }

    // Unions with members which aren't aggregate types and don't have indirections.
    foreach (T; AliasSeq!(bool, byte, ubyte, short, ushort, int, uint, long, ulong,
                          float, double, real, char, wchar, dchar, int function(string)))
    {
        // No indirections.
        {
            union U { T member; }
            mixin testWithQualifiers!(U, false);
        }
        {
            union U { const T member; }
            mixin testWithQualifiers!(U, false);
        }
        {
            union U { immutable T member; }
            mixin testWithQualifiers!(U, false);
        }
        {
            union U { shared T member; }
            mixin testWithQualifiers!(U, false);
        }

        // Pointers.
        {
            union U { T* member; }
            mixin testWithQualifiers!(U, true);
        }
        {
            union U { const(T)* member; }
            mixin testWithQualifiers!(U, true);
        }
        {
            union U { const T* member; }
            mixin testWithQualifiers!(U, true);
        }
        {
            union U { immutable T* member; }
            mixin testWithQualifiers!(U, true);
        }
        {
            union U { shared T* member; }
            mixin testWithQualifiers!(U, true);
        }

        // Dynamic arrays.
        {
            union U { T[] member; }
            mixin testWithQualifiers!(U, true);
        }
        {
            union U { const(T)[] member; }
            mixin testWithQualifiers!(U, true);
        }
        {
            union U { const T[] member; }
            mixin testWithQualifiers!(U, true);
        }
        {
            union U { immutable T[] member; }
            mixin testWithQualifiers!(U, true);
        }
        {
            union U { shared T[] member; }
            mixin testWithQualifiers!(U, true);
        }

        // Static arrays.
        {
            union U { T[1] member; }
            mixin testWithQualifiers!(U, false);
        }
        {
            union U { const(T)[1] member; }
            mixin testWithQualifiers!(U, false);
        }
        {
            union U { const T[1] member; }
            mixin testWithQualifiers!(U, false);
        }
        {
            union U { immutable T[1] member; }
            mixin testWithQualifiers!(U, false);
        }
        {
            union U { shared T[1] member; }
            mixin testWithQualifiers!(U, false);
        }

        // Static arrays of pointers.
        {
            union U { T*[1] member; }
            mixin testWithQualifiers!(U, true);
        }
        {
            union U { const(T)*[1] member; }
            mixin testWithQualifiers!(U, true);
        }
        {
            union U { const(T*)[1] member; }
            mixin testWithQualifiers!(U, true);
        }
        {
            union U { const T*[1] member; }
            mixin testWithQualifiers!(U, true);
        }
        {
            union U { immutable T*[1] member; }
            mixin testWithQualifiers!(U, true);
        }
        {
            union U { shared T*[1] member; }
            mixin testWithQualifiers!(U, true);
        }

        {
            union U { T*[0] member; }
            mixin testWithQualifiers!(U, false);
        }
        {
            union U { const(T)*[0] member; }
            mixin testWithQualifiers!(U, false);
        }
        {
            union U { const(T*)[0] member; }
            mixin testWithQualifiers!(U, false);
        }
        {
            union U { const T*[0] member; }
            mixin testWithQualifiers!(U, false);
        }
        {
            union U { immutable T*[0] member; }
            mixin testWithQualifiers!(U, false);
        }
        {
            union U { shared T*[0] member; }
            mixin testWithQualifiers!(U, false);
        }

        // Static arrays of dynamic arrays.
        {
            union U { T[][1] member; }
            mixin testWithQualifiers!(U, true);
        }
        {
            union U { const(T)[][1] member; }
            mixin testWithQualifiers!(U, true);
        }
        {
            union U { const(T[])[1] member; }
            mixin testWithQualifiers!(U, true);
        }
        {
            union U { const T[][1] member; }
            mixin testWithQualifiers!(U, true);
        }
        {
            union U { immutable T[][1] member; }
            mixin testWithQualifiers!(U, true);
        }
        {
            union U { shared T[][1] member; }
            mixin testWithQualifiers!(U, true);
        }

        {
            union U { T[][0] member; }
            mixin testWithQualifiers!(U, false);
        }
        {
            union U { const(T)[][0] member; }
            mixin testWithQualifiers!(U, false);
        }
        {
            union U { const(T[])[0] member; }
            mixin testWithQualifiers!(U, false);
        }
        {
            union U { const T[][0] member; }
            mixin testWithQualifiers!(U, false);
        }
        {
            union U { immutable T[][0] member; }
            mixin testWithQualifiers!(U, false);
        }
        {
            union U { shared T[][0] member; }
            mixin testWithQualifiers!(U, false);
        }
    }

    // Unions with arrays of void.
    {
        {
            static union U { void[] member; }
            mixin testWithQualifiers!(U, true);
        }
        {
            static union U { void[1] member; }
            mixin testWithQualifiers!(U, true);
        }
        {
            static union U { void[0] member; }
            mixin testWithQualifiers!(U, false);
        }
    }

    // Unions with multiple members, testing pointer types.
    {
        static union U { int i; bool b; }
        mixin testWithQualifiers!(U, false);
    }
    {
        static union U { int* i; bool b; }
        mixin testWithQualifiers!(U, true);
    }
    {
        static union U { int i; bool* b; }
        mixin testWithQualifiers!(U, true);
    }
    {
        static union U { int* i; bool* b; }
        mixin testWithQualifiers!(U, true);
    }

    // Unions with multiple members, testing dynamic arrays.
    {
        static union U { int[] arr; }
        mixin testWithQualifiers!(U, true);
    }
    {
        static union U { int i; int[] arr; }
        mixin testWithQualifiers!(U, true);
    }
    {
        static union U { int[] arr; int i; }
        mixin testWithQualifiers!(U, true);
    }

    // Unions with multiple members, testing static arrays.
    {
        static union U { int[1] arr; }
        mixin testWithQualifiers!(U, false);
    }
    {
        static union U { int i; int[1] arr; }
        mixin testWithQualifiers!(U, false);
    }
    {
        static union U { int[1] arr; int i; }
        mixin testWithQualifiers!(U, false);
    }

    {
        static union U { int*[0] arr; }
        mixin testWithQualifiers!(U, false);
    }
    {
        static union U { int i; int*[0] arr; }
        mixin testWithQualifiers!(U, false);
    }
    {
        static union U { int*[0] arr; int i; }
        mixin testWithQualifiers!(U, false);
    }

    {
        static union U { string[42] arr; }
        mixin testWithQualifiers!(U, true);
    }
    {
        static union U { int i; string[42] arr; }
        mixin testWithQualifiers!(U, true);
    }
    {
        static union U { string[42] arr; int i; }
        mixin testWithQualifiers!(U, true);
    }

    // Unions with associative arrays.
    {
        static union U { int[string] aa; }
        mixin testWithQualifiers!(U, true);
    }
    {
        static union U { int i; int[string] aa; }
        mixin testWithQualifiers!(U, true);
    }
    {
        static union U { int[string] aa; int i; }
        mixin testWithQualifiers!(U, true);
    }

    {
        static union U { int[42][int] aa; }
        mixin testWithQualifiers!(U, true);
    }
    {
        static union U { int[0][int] aa; }
        mixin testWithQualifiers!(U, true);
    }

    // Unions with classes.
    {
        class C {}
        union U { C c; }
        mixin testWithQualifiers!(U, true);
    }
    {
        interface I {}
        union U { I i; }
        mixin testWithQualifiers!(U, true);
    }

    // Unions with delegates.
    {
        union U { void delegate() d; }
        mixin testWithQualifiers!(U, true);
    }
    {
        union U { int delegate(int) d; }
        mixin testWithQualifiers!(U, true);
    }

    // Unions multiple layers deep.
    {
        union U1 { int i; }
        union U2 { U1 s; }
        union U3 { U2 s; }
        union U4 { U3 s; }
        union U5 { U4 s; }
        union U6 { U5 s; }
        union U7 { U6[0] s; }
        union U8 { U7 s; }
        union U9 { U8 s; }
        union U10 { U9 s; }
        mixin testWithQualifiers!(U1, false);
        mixin testWithQualifiers!(U2, false);
        mixin testWithQualifiers!(U3, false);
        mixin testWithQualifiers!(U4, false);
        mixin testWithQualifiers!(U5, false);
        mixin testWithQualifiers!(U6, false);
        mixin testWithQualifiers!(U7, false);
        mixin testWithQualifiers!(U8, false);
        mixin testWithQualifiers!(U9, false);
        mixin testWithQualifiers!(U10, false);
    }
    {
        union U1 { int* i; }
        union U2 { U1 s; }
        union U3 { U2 s; }
        union U4 { U3 s; }
        union U5 { U4 s; }
        union U6 { U5 s; }
        union U7 { U6[0] s; }
        union U8 { U7 s; }
        union U9 { U8 s; }
        union U10 { U9 s; }
        mixin testWithQualifiers!(U1, true);
        mixin testWithQualifiers!(U2, true);
        mixin testWithQualifiers!(U3, true);
        mixin testWithQualifiers!(U4, true);
        mixin testWithQualifiers!(U5, true);
        mixin testWithQualifiers!(U6, true);
        mixin testWithQualifiers!(U7, false);
        mixin testWithQualifiers!(U8, false);
        mixin testWithQualifiers!(U9, false);
        mixin testWithQualifiers!(U10, false);
    }
}

// hasIndirections with classes and interfaces
@safe unittest
{
    import phobos.sys.meta : AliasSeq;

    alias testWithQualifiers = assertWithQualifiers!hasIndirections;

    {
        class C {}
        mixin testWithQualifiers!(C, true);
    }

    foreach (T; AliasSeq!(bool, byte, ubyte, short, ushort, int, uint, long, ulong,
                          float, double, real, char, wchar, dchar, int function(string),
                          int[int], string delegate(int)))
    {
        {
            class C { T member; }
            mixin testWithQualifiers!(C, true);
        }
        {
            class C { const T member; }
            mixin testWithQualifiers!(C, true);
        }
        {
            class C { immutable T member; }
            mixin testWithQualifiers!(C, true);
        }
        {
            class C { shared T member; }
            mixin testWithQualifiers!(C, true);
        }
    }

    {
        interface I {}
        mixin testWithQualifiers!(I, true);
    }
}

/++
    Takes a type which is an associative array and evaluates to the type of the
    keys in that associative array.

    See_Also:
        $(LREF ValueType)
  +/
alias KeyType(V : V[K], K) = K;

///
@safe unittest
{
    static assert(is(KeyType!(int[string]) == string));
    static assert(is(KeyType!(string[int]) == int));

    static assert(is(KeyType!(string[const int]) == const int));
    static assert(is(KeyType!(const int[string]) == string));

    struct S
    {
        int i;
    }

    string[S] aa1;
    static assert(is(KeyType!(typeof(aa1)) == S));

    S[string] aa2;
    static assert(is(KeyType!(typeof(aa2)) == string));

    KeyType!(typeof(aa1)) key1 = S(42);
    KeyType!(typeof(aa2)) key2 = "foo";

    // Key types with indirections have their inner layers treated as const
    // by the compiler, because the values of keys can't change, or the hash
    // value could change, putting the associative array in an invalid state.
    static assert(is(KeyType!(bool[string[]]) == const(string)[]));
    static assert(is(KeyType!(bool[int*]) == const(int)*));

    // If the given type is not an AA, then KeyType won't compile.
    static assert(!__traits(compiles, KeyType!int));
    static assert(!__traits(compiles, KeyType!(int[])));
}

/++
    Takes a type which is an associative array and evaluates to the type of the
    values in that associative array.

    See_Also:
        $(LREF KeyType)
  +/
alias ValueType(V : V[K], K) = V;

///
@safe unittest
{
    static assert(is(ValueType!(int[string]) == int));
    static assert(is(ValueType!(string[int]) == string));

    static assert(is(ValueType!(string[const int]) == string));
    static assert(is(ValueType!(const int[string]) == const int));

    struct S
    {
        int i;
    }

    string[S] aa1;
    static assert(is(ValueType!(typeof(aa1)) == string));

    S[string] aa2;
    static assert(is(ValueType!(typeof(aa2)) == S));

    ValueType!(typeof(aa1)) value1 = "foo";
    ValueType!(typeof(aa2)) value2 = S(42);

    // If the given type is not an AA, then ValueType won't compile.
    static assert(!__traits(compiles, ValueType!int));
    static assert(!__traits(compiles, ValueType!(int[])));
}

/++
    Evaluates to the original / ultimate base type of an enum type - or for
    non-enum types, it evaluates to the type that it's given.

    If the base type of the given enum type is not an enum, then the result of
    OriginalType is its direct base type. However, if the base type of the
    given enum is also an enum, then OriginalType gives the ultimate base type
    - that is, it keeps getting the base type for each succesive enum in the
    chain until it gets to a base type that isn't an enum, and that's the
    result. So, the result will never be an enum type.

    If the given type has any qualifiers, the result will have those same
    qualifiers.
  +/
version (StdDdoc) template OriginalType(T)
{
    import core.internal.traits : CoreOriginalType = OriginalType;
    alias OriginalType = CoreOriginalType!T;
}
else
{
    import core.internal.traits : CoreOriginalType = OriginalType;
    alias OriginalType = CoreOriginalType;
}

///
@safe unittest
{
    enum E { a, b, c }
    static assert(is(OriginalType!E == int));

    enum F : E { x = E.a }
    static assert(is(OriginalType!F == int));

    enum G : F { y = F.x }
    static assert(is(OriginalType!G == int));
    static assert(is(OriginalType!(const G) == const int));
    static assert(is(OriginalType!(immutable G) == immutable int));
    static assert(is(OriginalType!(shared G) == shared int));

    enum C : char { a = 'a', b = 'b' }
    static assert(is(OriginalType!C == char));

    enum D : string { d = "dlang" }
    static assert(is(OriginalType!D == string));

    static assert(is(OriginalType!int == int));
    static assert(is(OriginalType!(const long) == const long));
    static assert(is(OriginalType!string == string));

    // OriginalType gets the base type of enums and for all other types gives
    // the same type back. It does nothing special for other types - like
    // classes - where one could talk about the type having a base type.
    class Base {}
    class Derived : Base {}
    static assert(is(OriginalType!Base == Base));
    static assert(is(OriginalType!Derived == Derived));
}

/++
    PropertyType evaluates to the type of the symbol as an expression (i.e. the
    type of the expression when the symbol is used in an expression by itself),
    and SymbolType evaluates to the type of the given symbol as a symbol (i.e.
    the type of the symbol itself).

    Unlike with $(K_TYPEOF), $(K_PROPERTY) has no effect on the result of
    either PropertyType or SymbolType.

    TLDR, PropertyType should be used when code is going to use a symbol as if
    it were a getter property (without caring whether the symbol is a variable
    or a function), and the code needs to know the type of that property and
    $(I not) the type of the symbol itself (since with functions, they're not
    the same thing). So, it's treating the symbol as an expression on its own
    and giving the type of that expression rather than giving the type of the
    symbol itself. And it's named PropertyType rather than something like
    $(D ExpressionType), because it's used in situations where the code is
    treating the symbol as a getter property, and it does not operate on
    expressions in general. SymbolType should then be used in situations where
    the code needs to know the type of the symbol itself.

    As for why PropertyType and SymbolType are necessary, and $(K_TYPEOF) is
    not sufficient, $(K_TYPEOF) gives both the types of symbols and the types
    of expressions. When it's given something that's clearly an expression -
    e.g. $(D typeof(foo + bar)) or $(D typeof(foo())), then the result is the
    type of that expression. However, when $(K_TYPEOF) is given a symbol, what
    $(K_TYPEOF) does depends on the symbol, which can make using it correctly
    in generic code difficult.

    For symbols that don't have types, naturally, $(K_TYPEOF) doesn't even
    compile (e.g. $(D typeof(int)) won't compile, because in D, types don't
    themselves have types), so the question is what happens with $(K_TYPEOF)
    and symbols which do have types.

    For symbols which have types and are not functions, what $(K_TYPEOF) does
    is straightforward, because there is no difference between the type of the
    symbol and the type of the expression - e.g. if $(D foo) is a variable of
    type $(K_INT), then $(D typeof(foo)) would be $(K_INT), because the
    variable itself is of type $(K_INT), and if the variable is used as an
    expression (e.g. when it's returned from a function or passed to a
    function), then that expression is also of type $(K_INT).

    However, for functions (particularly functions which don't require
    arguments), things aren't as straightforward. Should $(D typeof(foo)) give
    the type of the function itself or the type of the expression? If parens
    always had to be used when calling a function, then $(D typeof(foo)) would
    clearly be the type of the function itself, whereas $(D typeof(foo()))
    would be the type of the expression (which would be the return type of the
    function so long as $(D foo) could be called with no arguments, and it
    wouldn't compile otherwise, because the expression would be invalid).
    However, because parens are optional when calling a function that has no
    arguments, $(D typeof(foo)) is ambiguous. There's no way to know which the
    programmer actually intended, but the compiler has to either make it an
    error or choose between giving the type of the symbol or the type of the
    expression.

    So, the issue here is functions which can be treated as getter properties,
    because they can be called without parens and thus syntactically look
    exactly like a variable when they're used. Any function which requires
    arguments (including when a function is used as a setter property) does not
    have this problem, because it isn't a valid expression when used on its own
    (it needs to be assigned to or called with parens in order to be a valid
    expression).

    What the compiler currently does when it encounters this ambiguity depends
    on the $(K_PROPERTY) attribute. If the function does not have the
    $(K_PROPERTY) attribute, then $(D typeof(foo)) will give the type of the
    symbol - e.g. $(D int()) if the signature for $(D foo) were $(D int foo()).
    However, if the function $(I does) have the $(K_PROPERTY) attribute, then
    $(D typeof(foo)) will give the type of the expression. So, if $(D foo) were
    $(D @property int foo()), then $(D typeof(foo)) would give $(K_INT) rather
    than $(D int()). The idea behind this is that $(K_PROPERTY) functions are
    supposed to act like variables, and using $(K_TYPEOF) on a variable of type
    $(K_INT) would give $(K_INT), not $(D int()). So, with this behavior of
    $(K_TYPEOF), a $(K_PROPERTY) function is closer to being a drop-in
    replacement for a variable.

    The problem with this though is two-fold. One, it means that $(K_TYPEOF)
    cannot be relied on to give the type of the symbol when given a symbol on
    its own, forcing code that needs the actual type of the symbol to work
    around $(K_PROPERTY). And two, because parens are optional on functions
    which can be called without arguments, whether the function is marked with
    $(K_PROPERTY) or not is irrevelant to whether the symbol is going to be
    used as if it were a variable, and so it's irrelevant to code that's trying
    to get the type of the expression when the symbol is used like a getter
    property. If optional parens were removed from the language (as was
    originally the intent when $(K_PROPERTY) was introduced), then that would
    fix the second problem, but it would still leave the first problem.

    So, $(K_PROPERTY) is solving the problem in the wrong place. It's the code
    doing the type introspection which needs to decide whether to get the type
    of a symbol as if it were a getter property or whether to get the type of
    the symbol itself. It's the type introspection code which knows which is
    relevant for what it's doing, and a function could be used both in code
    which needs to treat it as a getter property and in code which needs to get
    the type of the symbol itself (e.g. because it needs to get the attributes
    on the function).

    All of this means that $(K_TYPEOF) by itself is unreliable when used on a
    symbol. In practice, the programmer needs to indicate whether they want the
    type of the symbol itself or the type of the symbol as a getter property in
    an expression, and leaving it up to $(K_TYPEOF) is simply too error-prone.
    So, ideally, $(K_TYPEOF) would be split up into two separate constructs,
    but that would involve adding more keywords (and break a lot of existing
    code if $(K_TYPEOF) were actually removed).

    So, phobos.sys.traits provides SymbolType and PropertyType. They're both
    traits that take a symbol and give the type for that symbol. However,
    SymbolType gives the type of the symbol itself, whereas PropertyType gives
    the type of the symbol as if it were used as a getter property in an
    expression. Neither is affected by whether the symbol is marked with
    $(K_PROPERTY). So, code that needs to get information about the symbol
    itself should use SymbolType rather than $(K_TYPEOF) or PropertyType,
    whereas code that needs to get the type of the symbol as a getter property
    within an expression should use PropertyType.

    The use of $(K_TYPEOF) should then be restricted to situations where code
    is getting the type of an expression which isn't a symbol (or code where
    it's already known that the symbol isn't a function). Also, since
    template alias parameters only accept symbols, any expressions which aren't
    symbols won't compile with SymbolType or PropertyType anyway.

    SymbolType and PropertyType must be given a symbol which has a type (so,
    not something like a type or an uninstantiated template). Symbols
    which don't have types will fail the template constraint.

    For both SymbolType and PropertyType, if they are given a symbol which has
    a type, and that symbol is not a function, the result will be the same as
    $(K_TYPEOF) (since in such cases, the type of the symbol and the type of
    the expression are the same). The difference comes in with functions.

    When SymbolType is given any symbol which is a function, the result will be
    the type of the function itself regardless of whether the function is
    marked with $(K_PROPERTY). This makes it so that in all situations where
    the type of the symbol is needed, SymbolType can be used to get the type of
    the symbol without having to worry about whether it's a function marked
    with $(K_PROPERTY).

    When PropertyType is given any function which can be used as a getter
    property, the result will be the type of the symbol as an expression - i.e.
    the return type of the function (in effect, this means that it treats all
    functions as if they were marked with $(K_PROPERTY)). Whether the function
    is actually marked with $(K_PROPERTY) or not is irrelevant.

    If PropertyType is given any function which which cannot be used as a
    getter property (i.e. it requires arguments or returns $(K_VOID)), the
    template constraint will reject it, and PropertyType will fail to compile.
    This is equivalent to what $(K_TYPEOF) does when it's given a $(K_PROPERTY)
    function which is a setter, since it's not a valid expression on its own.

    So, for $(D PropertyType!foo), if $(D foo) is a function, the result is
    equivalent to $(D typeof(foo())) (and for non-functions, it's equivalent to
    $(D typeof(foo))).

    To summarize, SymbolType should be used when code needs to get the type of
    the symbol itself; PropertyType should be used when code needs to get the
    type of the symbol when it's used in an expression as a getter property
    (generally because the code doesn't care whether the symbol is a variable
    or a function); and $(K_TYPEOF) should be used when getting the type of an
    expression which is not a symbol.

    See_Also:
        $(DDSUBLINK spec/type, typeof, The language spec for typeof)
  +/
template PropertyType(alias sym)
if (is(typeof(sym)) && (!is(typeof(sym) == return) ||
                        (is(typeof(sym())) && !is(typeof(sym()) == void))))
{
    // This handles functions which don't have a context pointer.
    static if (is(typeof(&sym) == T*, T) && is(T == function))
    {
        // Note that we can't use is(T R == return) to get the return type,
        // because the first overload isn't necessarily the getter function,
        // and is(T R == return) will give us the first overload if the function
        // doesn't have @property on it (whereas if it does have @property, it
        // will give use the getter if there is one). However, we at least know
        // that there's a getter function, because the template constraint
        // validates that sym() compiles (and returns something) if it's a
        // function, function pointer, or delegate.
        alias PropertyType = typeof(sym());
    }
    // This handles functions which do have a context pointer.
    else static if (is(typeof(&sym) T == delegate) && is(T R == return))
    {
        // See the comment above for why we can't get the return type the
        // normal way.
        alias PropertyType = typeof(sym());
    }
    // This handles everything which isn't a function.
    else
        alias PropertyType = typeof(sym);
}

/++ Ditto +/
template SymbolType(alias sym)
if (!is(sym))
{
    // This handles functions which don't have a context pointer.
    static if (is(typeof(&sym) == T*, T) && is(T == function))
        alias SymbolType = T;
    // This handles functions which do have a context pointer.
    else static if (is(typeof(&sym) T == delegate))
        alias SymbolType = T;
    // This handles everything which isn't a function.
    else
        alias SymbolType = typeof(sym);
}

///
@safe unittest
{
    int i;
    static assert( is(SymbolType!i == int));
    static assert( is(PropertyType!i == int));
    static assert( is(typeof(i) == int));

    string str;
    static assert( is(SymbolType!str == string));
    static assert( is(PropertyType!str == string));
    static assert( is(typeof(str) == string));

    // ToFunctionType is used here to get around the fact that we don't have a
    // way to write out function types in is expressions (whereas we can write
    // out the type of a function pointer), which is a consequence of not being
    // able to declare variables with a function type (as opposed to a function
    // pointer type). That being said, is expressions are pretty much the only
    // place where writing out a function type would make sense.

    // The function type has more attributes than the function declaration,
    // because the attributes are inferred for nested functions.

    static string func() { return ""; }
    static assert( is(SymbolType!func ==
                      ToFunctionType!(string function()
                                      @safe pure nothrow @nogc)));
    static assert( is(PropertyType!func == string));
    static assert( is(typeof(func) == SymbolType!func));

    int function() funcPtr;
    static assert( is(SymbolType!funcPtr == int function()));
    static assert( is(PropertyType!funcPtr == int function()));
    static assert( is(typeof(funcPtr) == int function()));

    int delegate() del;
    static assert( is(SymbolType!del == int delegate()));
    static assert( is(PropertyType!del == int delegate()));
    static assert( is(typeof(del) == int delegate()));

    @property static int prop() { return 0; }
    static assert( is(SymbolType!prop ==
                      ToFunctionType!(int function()
                                      @property @safe pure nothrow @nogc)));
    static assert( is(PropertyType!prop == int));
    static assert( is(typeof(prop) == PropertyType!prop));

    // Functions which cannot be used as getter properties (i.e. they require
    // arguments and/or return void) do not compile with PropertyType.
    static int funcWithArg(int i) { return i; }
    static assert( is(SymbolType!funcWithArg ==
                      ToFunctionType!(int function(int)
                                      @safe pure nothrow @nogc)));
    static assert(!__traits(compiles, PropertyType!funcWithArg));
    static assert( is(typeof(funcWithArg) == SymbolType!funcWithArg));

    // Setter @property functions also don't work with typeof, because typeof
    // gets the type of the expression rather than the type of the symbol when
    // the symbol is a function with @property, and a setter property is not a
    // valid expression on its own.
    @property static void prop2(int) {}
    static assert( is(SymbolType!prop2 ==
                      ToFunctionType!(void function(int)
                                      @property @safe pure nothrow @nogc)));
    static assert(!__traits(compiles, PropertyType!prop2));
    static assert(!__traits(compiles, typeof(prop2)));

    // Expressions which aren't symbols don't work with alias parameters and
    // thus don't work with SymbolType or PropertyType.
    static assert(!__traits(compiles, PropertyType!(i + 42)));
    static assert(!__traits(compiles, SymbolType!(i + 42)));
    static assert( is(typeof(i + 42) == int));

    // typeof will work with a function that takes arguments so long as it's
    // used in a proper expression.
    static assert( is(typeof(funcWithArg(42)) == int));
    static assert( is(typeof(prop2 = 42) == void));
    static assert( is(typeof(prop2(42)) == void));
}

/++
    With templated types or functions, a specific instantiation should be
    passed to SymbolType or PropertyType, not the symbol for the template
    itself. If $(K_TYPEOF), SymbolType, or PropertyType is used on a template
    (rather than an instantiation of the template), the result will be
    $(K_VOID), because the template itself does not have a type.
  +/
@safe unittest
{
    static T func(T)() { return T.init; }

    static assert(is(SymbolType!func == void));
    static assert(is(PropertyType!func == void));
    static assert(is(typeof(func) == void));

    static assert(is(SymbolType!(func!int) ==
                     ToFunctionType!(int function()
                                     @safe pure nothrow @nogc)));
    static assert(is(PropertyType!(func!int) == int));
    static assert(is(typeof(func!int) == SymbolType!(func!int)));

    static assert(is(SymbolType!(func!string) ==
                     ToFunctionType!(string function()
                                     @safe pure nothrow @nogc)));
    static assert(is(PropertyType!(func!string) == string));
    static assert(is(typeof(func!string) == SymbolType!(func!string)));
}

/++
    If a function is overloaded, then when using it as a symbol to pass to
    $(K_TYPEOF), the compiler typically selects the first overload. However, if
    the functions are marked with $(K_PROPERTY), and one of the overloads is a
    getter property, then $(K_TYPEOF) will select the getter property (or fail
    to compile if they're all setter properties). This is because it's getting
    the type of the function as an expression rather than doing introspection
    on the function itself.

    SymbolType always gives the type of the first overload (effectively ignoring
    $(K_PROPERTY)), and PropertyType always gives the getter ovrerload
    (effectively treating all functions as if they had $(K_PROPERTY)).

    If code needs to get the symbol for a specific overload, then
    $(DDSUBLINK spec/traits, getOverloads, $(D __traits(getOverloads, ...))
    must be used.

    In general, $(getOverloads) should be used when using SymbolType, since
    there's no guarantee that the first one is the correct one (and often, code
    will need to check all of the overloads), whereas with PropertyType, it
    doesn't usually make sense to get specific overloads, because there can
    only ever be one overload which works as a getter property, and using
    PropertyType on the symbol for the function will give that overload if it's
    present, regardless of which overload is first (and it will fail to compile
    if there is no overload which can be called as a getter).
  +/
@safe unittest
{
    static struct S
    {
        string foo();
        void foo(string);
        bool foo(string, int);

        @property void bar(int);
        @property int bar();
    }

    {
        static assert( is(SymbolType!(S.foo) ==
                          ToFunctionType!(string function())));
        static assert( is(PropertyType!(S.foo) == string));
        static assert( is(typeof(S.foo) == SymbolType!(S.foo)));

        alias overloads = __traits(getOverloads, S, "foo");

        // string foo();
        static assert( is(SymbolType!(overloads[0]) == function));
        static assert( is(PropertyType!(overloads[0]) == string));
        static assert( is(typeof(overloads[0]) == function));

        static assert( is(SymbolType!(overloads[0]) ==
                          ToFunctionType!(string function())));
        static assert( is(typeof(overloads[0]) == SymbolType!(overloads[0])));

        // void foo(string);
        static assert( is(SymbolType!(overloads[1]) == function));
        static assert(!__traits(compiles, PropertyType!(overloads[1])));
        static assert( is(typeof(overloads[1]) == function));

        static assert( is(SymbolType!(overloads[1]) ==
                          ToFunctionType!(void function(string))));
        static assert( is(typeof(overloads[1]) == SymbolType!(overloads[1])));

        // void foo(string, int);
        static assert( is(SymbolType!(overloads[2]) == function));
        static assert(!__traits(compiles, PropertyType!(overloads[2])));
        static assert( is(typeof(overloads[2]) == function));

        static assert( is(SymbolType!(overloads[2]) ==
                          ToFunctionType!(bool function(string, int))));
        static assert( is(typeof(overloads[2]) == SymbolType!(overloads[2])));
    }
    {
        static assert( is(SymbolType!(S.bar) ==
                          ToFunctionType!(void function(int) @property)));
        static assert( is(PropertyType!(S.bar) == int));
        static assert( is(typeof(S.bar) == PropertyType!(S.bar)));

        alias overloads = __traits(getOverloads, S, "bar");

        // @property void bar(int);
        static assert( is(SymbolType!(overloads[0]) == function));
        static assert(!__traits(compiles, PropertyType!(overloads[0])));
        static assert(!__traits(compiles, typeof(overloads[0])));

        static assert( is(SymbolType!(overloads[0]) ==
                          ToFunctionType!(void function(int) @property)));

        // @property int bar();
        static assert( is(SymbolType!(overloads[1]) == function));
        static assert( is(PropertyType!(overloads[1]) == int));
        static assert( is(typeof(overloads[1]) == PropertyType!(overloads[1])));

        static assert( is(SymbolType!(overloads[1]) ==
                          ToFunctionType!(int function() @property)));
    }
}

@safe unittest
{
    {
        string str;
        int i;

        static assert(!__traits(compiles, SymbolType!int));
        static assert(!__traits(compiles, SymbolType!(str ~ "more str")));
        static assert(!__traits(compiles, SymbolType!(i + 42)));
        static assert(!__traits(compiles, SymbolType!(&i)));

        static assert(!__traits(compiles, PropertyType!int));
        static assert(!__traits(compiles, PropertyType!(str ~ "more str")));
        static assert(!__traits(compiles, PropertyType!(i + 42)));
        static assert(!__traits(compiles, PropertyType!(&i)));
    }

    static assert( is(SymbolType!42 == int));
    static assert( is(SymbolType!"dlang" == string));

    int var;

    int funcWithContext() { return var; }
    static assert( is(SymbolType!funcWithContext ==
                      ToFunctionType!(int function()
                                      @safe pure nothrow @nogc)));
    static assert( is(PropertyType!funcWithContext == int));
    static assert( is(typeof(funcWithContext) == SymbolType!funcWithContext));

    @property int propWithContext() { return var; }
    static assert( is(SymbolType!propWithContext == function));
    static assert( is(SymbolType!propWithContext ==
                      ToFunctionType!(int function() @property @safe pure nothrow @nogc)));
    static assert( is(PropertyType!propWithContext == int));
    static assert( is(typeof(propWithContext) == PropertyType!propWithContext));

    // For those who might be confused by this sort of declaration, this is a
    // property function which returns a function pointer that takes no
    // arguments and returns int, which gets an even uglier signature when
    // writing out the type for a pointer to such a property function.
    static int function() propFuncPtr() @property { return null; }
    static assert( is(SymbolType!propFuncPtr == function));
    static assert( is(SymbolType!propFuncPtr ==
                      ToFunctionType!(int function() function() @property @safe pure nothrow @nogc)));
    static assert( is(PropertyType!propFuncPtr == int function()));
    static assert( is(typeof(propFuncPtr) == PropertyType!propFuncPtr));

    static int delegate() propDel() @property { return null; }
    static assert( is(SymbolType!propDel == function));
    static assert( is(SymbolType!propDel ==
                      ToFunctionType!(int delegate() function() @property @safe pure nothrow @nogc)));
    static assert( is(PropertyType!propDel == int delegate()));
    static assert( is(typeof(propDel) == PropertyType!propDel));

    int function() propFuncPtrWithContext() @property { ++var; return null; }
    static assert( is(SymbolType!propFuncPtrWithContext == function));
    static assert( is(SymbolType!propFuncPtrWithContext ==
                      ToFunctionType!(int function() function() @property @safe pure nothrow @nogc)));
    static assert( is(PropertyType!propFuncPtrWithContext == int function()));
    static assert( is(typeof(propFuncPtrWithContext) == PropertyType!propFuncPtrWithContext));

    int delegate() propDelWithContext() @property { ++var; return null; }
    static assert( is(SymbolType!propDelWithContext == function));
    static assert( is(SymbolType!propDelWithContext ==
                      ToFunctionType!(int delegate() function() @property @safe pure nothrow @nogc)));
    static assert( is(PropertyType!propDelWithContext == int delegate()));
    static assert( is(typeof(propDelWithContext) == PropertyType!propDelWithContext));

    const int ci;
    static assert( is(SymbolType!ci == const int));
    static assert( is(PropertyType!ci == const int));
    static assert( is(typeof(ci) == PropertyType!ci));

    shared int si;
    static assert( is(SymbolType!si == shared int));
    static assert( is(PropertyType!si == shared int));
    static assert( is(typeof(si) == PropertyType!si));

    static struct S
    {
        int i;
        @disable this(this);
    }
    static assert(!__traits(isCopyable, S));

    S s;
    static assert( is(SymbolType!s == S));
    static assert( is(PropertyType!s == S));
    static assert( is(typeof(s) == SymbolType!s));

    static ref S foo();
    static void bar(ref S);

    static @property ref S bob();
    static @property void sally(ref S);

    // The aliases are due to https://github.com/dlang/dmd/issues/17505
    // Apparently, aliases are special-cased to work with function pointer
    // signatures which return by ref, and we can't do it elsewhere.
    alias FooPtr = ref S function();
    static assert( is(SymbolType!foo == ToFunctionType!FooPtr));
    static assert( is(PropertyType!foo == S));
    static assert( is(typeof(foo) == SymbolType!foo));

    static assert( is(SymbolType!bar == ToFunctionType!(void function(ref S))));
    static assert(!__traits(compiles, PropertyType!bar));
    static assert( is(typeof(bar) == SymbolType!bar));

    alias BobPtr = ref S function() @property;
    static assert( is(SymbolType!bob == ToFunctionType!BobPtr));
    static assert( is(PropertyType!bob == S));
    static assert( is(typeof(bob) == S));
    static assert( is(typeof(bob) == PropertyType!bob));

    static assert( is(SymbolType!sally == ToFunctionType!(void function(ref S) @property)));
    static assert(!__traits(compiles, PropertyType!sally));
    static assert(!__traits(compiles, typeof(sally)));

    string defaultArgs1(int i = 0);
    void defaultArgs2(string, int i = 0);

    static assert( is(SymbolType!defaultArgs1 == ToFunctionType!(string function(int))));
    static assert( is(PropertyType!defaultArgs1 == string));
    static assert( is(typeof(defaultArgs1) == SymbolType!defaultArgs1));

    static assert( is(SymbolType!defaultArgs2 == ToFunctionType!(void function(string, int))));
    static assert(!__traits(compiles, PropertyType!defaultArgs2));
    static assert( is(typeof(defaultArgs2) == SymbolType!defaultArgs2));

    @property string defaultArgsProp1(int i = 0);
    @property void defaultArgsProp2(string, int i = 0);

    static assert( is(SymbolType!defaultArgsProp1 == ToFunctionType!(string function(int) @property)));
    static assert( is(PropertyType!defaultArgsProp1 == string));
    static assert( is(typeof(defaultArgsProp1) == PropertyType!defaultArgsProp1));

    static assert( is(SymbolType!defaultArgsProp2 == ToFunctionType!(void function(string, int) @property)));
    static assert(!__traits(compiles, PropertyType!defaultArgsProp2));
    static assert(!__traits(compiles, typeof(defaultArgsProp2)));

    int returningSetter(string);
    @property int returningSetterProp(string);

    static assert( is(SymbolType!returningSetter == ToFunctionType!(int function(string))));
    static assert(!__traits(compiles, PropertyType!returningSetter));
    static assert( is(typeof(returningSetter) == SymbolType!returningSetter));

    static assert( is(SymbolType!returningSetterProp == ToFunctionType!(int function(string) @property)));
    static assert(!__traits(compiles, PropertyType!returningSetterProp));
    static assert(!__traits(compiles, typeof(returningSetterProp)));
}

// These are for the next unittest block to test overloaded free functions (in
// addition to the overloaded member functions and static functions that it
// tests). That way, if there are any differences in how free functions and
// member functions are handled, we'll catch those bugs (be they compiler bugs
// or bugs in phobos.sys.traits).
version (PhobosUnittest)
{
    private void modFunc1();
    private void modFunc1(string);
    private int modFunc1(string, int);

    private int modFunc2();
    private int modFunc2(string);
    private string modFunc2(string, int);

    private void modFunc3(int*);
    private void modFunc3(float);
    private string modFunc3(int a = 0);

    private int modGetterFirst();
    private void modGetterFirst(int);

    private void modSetterFirst(int);
    private int modSetterFirst();

    private void modSetterOnly(string);
    private void modSetterOnly(int);

    private @property int modPropGetterFirst();
    private @property void modPropGetterFirst(int);

    private @property void modPropSetterFirst(int);
    private @property int modPropSetterFirst();

    private @property void modPropSetterOnly(string);
    private @property void modPropSetterOnly(int);

    private int function() @property modGetterFirstFuncPtr();
    private void modGetterFirstFuncPtr(int function() @property);

    private void modSetterFirstFuncPtr(int function() @property);
    private int function() @property modSetterFirstFuncPtr();

    private int function() @property modPropGetterFirstFuncPtr() @property;
    private void modPropGetterFirstFuncPtr(int function() @property) @property;

    private void modPropSetterFirstFuncPtr(int function() @property) @property;
    private int function() @property modPropSetterFirstFuncPtr() @property;
}

@safe unittest
{
    // Note that with overloads without @property, typeof gives the first
    // overload, whereas with overloads with @property, typeof gives the return
    // type of the getter overload no matter where it is in the order.
    // PropertyType needs to always give the getter overload whether @property
    // is used or not, since that's the type of the symbol when used as a
    // getter property in an expression.
    {
        alias module_ = __traits(parent, __traits(parent, {}));

        // void modFunc1();
        // void modFunc1(string);
        // int modFunc1(string, int);
        {
            static assert( is(SymbolType!modFunc1 == ToFunctionType!(void function())));
            static assert(!__traits(compiles, PropertyType!modFunc1));
            static assert( is(typeof(modFunc1) == SymbolType!modFunc1));

            alias overloads = __traits(getOverloads, module_, "modFunc1");
            static assert(overloads.length == 3);

            static assert( is(SymbolType!(overloads[0]) == ToFunctionType!(void function())));
            static assert(!__traits(compiles, PropertyType!(overloads[0])));
            static assert( is(typeof(overloads[0]) == SymbolType!(overloads[0])));

            static assert( is(SymbolType!(overloads[1]) == ToFunctionType!(void function(string))));
            static assert(!__traits(compiles, PropertyType!(overloads[1])));
            static assert( is(typeof(overloads[1]) == SymbolType!(overloads[1])));

            static assert( is(SymbolType!(overloads[2]) == ToFunctionType!(int function(string, int))));
            static assert(!__traits(compiles, PropertyType!(overloads[2])));
            static assert( is(typeof(overloads[2]) == SymbolType!(overloads[2])));
        }

        // int modFunc2();
        // int modFunc2(string);
        // string modFunc2(string, int);
        {
            static assert( is(SymbolType!modFunc2 == ToFunctionType!(int function())));
            static assert( is(PropertyType!modFunc2 == int));
            static assert( is(typeof(modFunc2) == SymbolType!modFunc2));

            alias overloads = __traits(getOverloads, module_, "modFunc2");
            static assert(overloads.length == 3);

            static assert( is(SymbolType!(overloads[0]) == ToFunctionType!(int function())));
            static assert( is(PropertyType!(overloads[0]) == int));
            static assert( is(typeof(overloads[0]) == SymbolType!(overloads[0])));

            static assert( is(SymbolType!(overloads[1]) == ToFunctionType!(int function(string))));
            static assert(!__traits(compiles, PropertyType!(overloads[1])));
            static assert( is(typeof(overloads[1]) == SymbolType!(overloads[1])));

            static assert( is(SymbolType!(overloads[2]) == ToFunctionType!(string function(string, int))));
            static assert(!__traits(compiles, PropertyType!(overloads[2])));
            static assert( is(typeof(overloads[2]) == SymbolType!(overloads[2])));
        }

        // void modFunc3(int*);
        // void modFunc3(float);
        // string modFunc3(int a = 0);
        {
            static assert( is(SymbolType!modFunc3 == ToFunctionType!(void function(int*))));
            static assert( is(PropertyType!modFunc3 == string));
            static assert( is(typeof(modFunc3) == SymbolType!modFunc3));

            alias overloads = __traits(getOverloads, module_, "modFunc3");
            static assert(overloads.length == 3);

            static assert( is(SymbolType!(overloads[0]) == ToFunctionType!(void function(int*))));
            static assert(!__traits(compiles, PropertyType!(overloads[0])));
            static assert( is(typeof(overloads[0]) == SymbolType!(overloads[0])));

            static assert( is(SymbolType!(overloads[1]) == ToFunctionType!(void function(float))));
            static assert(!__traits(compiles, PropertyType!(overloads[1])));
            static assert( is(typeof(overloads[1]) == SymbolType!(overloads[1])));

            static assert( is(SymbolType!(overloads[2]) == ToFunctionType!(string function(int))));
            static assert( is(PropertyType!(overloads[2]) == string));
            static assert( is(typeof(overloads[2]) == SymbolType!(overloads[2])));
        }

        // int modGetterFirst();
        // void modGetterFirst(int);
        {
            static assert( is(SymbolType!modGetterFirst == ToFunctionType!(int function())));
            static assert( is(PropertyType!modGetterFirst == int));
            static assert( is(typeof(modGetterFirst) == SymbolType!modGetterFirst));

            alias overloads = __traits(getOverloads, module_, "modGetterFirst");
            static assert(overloads.length == 2);

            static assert( is(SymbolType!(overloads[0]) == ToFunctionType!(int function())));
            static assert( is(PropertyType!(overloads[0]) == int));
            static assert( is(typeof(overloads[0]) == SymbolType!(overloads[0])));

            static assert( is(SymbolType!(overloads[1]) == ToFunctionType!(void function(int))));
            static assert(!__traits(compiles, PropertyType!(overloads[1])));
            static assert( is(typeof(overloads[1]) == SymbolType!(overloads[1])));
        }

        // void modSetterFirst(int);
        // int modSetterFirst();
        {
            static assert( is(SymbolType!modSetterFirst == ToFunctionType!(void function(int))));
            static assert( is(PropertyType!modSetterFirst == int));
            static assert( is(typeof(modSetterFirst) == SymbolType!modSetterFirst));

            alias overloads = __traits(getOverloads, module_, "modSetterFirst");
            static assert(overloads.length == 2);

            static assert( is(SymbolType!(overloads[0]) == ToFunctionType!(void function(int))));
            static assert(!__traits(compiles, PropertyType!(overloads[0])));
            static assert( is(typeof(overloads[0]) == SymbolType!(overloads[0])));

            static assert( is(SymbolType!(overloads[1]) == ToFunctionType!(int function())));
            static assert( is(PropertyType!(overloads[1]) == int));
            static assert( is(typeof(overloads[1]) == SymbolType!(overloads[1])));
        }

        // void modSetterOnly(string);
        // void modSetterOnly(int);
        {
            static assert( is(SymbolType!modSetterOnly == ToFunctionType!(void function(string))));
            static assert(!__traits(compiles, PropertyType!modSetterOnly));
            static assert( is(typeof(modSetterOnly) == SymbolType!modSetterOnly));

            alias overloads = __traits(getOverloads, module_, "modSetterOnly");
            static assert(overloads.length == 2);

            static assert( is(SymbolType!(overloads[0]) == ToFunctionType!(void function(string))));
            static assert(!__traits(compiles, PropertyType!(overloads[0])));
            static assert( is(typeof(overloads[0]) == SymbolType!(overloads[0])));

            static assert( is(SymbolType!(overloads[1]) == ToFunctionType!(void function(int))));
            static assert(!__traits(compiles, PropertyType!(overloads[1])));
            static assert( is(typeof(overloads[1]) == SymbolType!(overloads[1])));
        }

        // @property int modPropGetterFirst();
        // @property void modPropGetterFirst(int);
        {
            static assert( is(SymbolType!modPropGetterFirst == ToFunctionType!(int function() @property)));
            static assert( is(PropertyType!modPropGetterFirst == int));
            static assert( is(typeof(modPropGetterFirst) == PropertyType!modPropGetterFirst));

            alias overloads = __traits(getOverloads, module_, "modPropGetterFirst");
            static assert(overloads.length == 2);

            static assert( is(SymbolType!(overloads[0]) == ToFunctionType!(int function() @property)));
            static assert( is(PropertyType!(overloads[0]) == int));
            static assert( is(typeof(overloads[0]) == PropertyType!(overloads[0])));

            static assert( is(SymbolType!(overloads[1]) == ToFunctionType!(void function(int) @property)));
            static assert(!__traits(compiles, PropertyType!(overloads[1])));
            static assert(!__traits(compiles, typeof((overloads[1]))));
        }

        // @property void modPropSetterFirst(int);
        // @property int modPropSetterFirst();
        {
            static assert( is(SymbolType!modPropSetterFirst == ToFunctionType!(void function(int) @property)));
            static assert( is(PropertyType!modPropSetterFirst == int));
            static assert( is(typeof(modPropSetterFirst) == PropertyType!modPropSetterFirst));

            alias overloads = __traits(getOverloads, module_, "modPropSetterFirst");
            static assert(overloads.length == 2);

            static assert( is(SymbolType!(overloads[0]) == ToFunctionType!(void function(int) @property)));
            static assert(!__traits(compiles, PropertyType!(overloads[0])));
            static assert(!__traits(compiles, typeof(overloads[0])));

            static assert( is(SymbolType!(overloads[1]) == ToFunctionType!(int function() @property)));
            static assert( is(PropertyType!(overloads[1]) == int));
            static assert( is(typeof(overloads[1]) == PropertyType!(overloads[1])));
        }

        // @property void modPropSetterOnly(string);
        // @property void modPropSetterOnly(int);
        {
            static assert( is(SymbolType!modPropSetterOnly == ToFunctionType!(void function(string) @property)));
            static assert(!__traits(compiles, PropertyType!modPropSetterOnly));
            static assert(!__traits(compiles, typeof(modPropSetterOnly)));

            alias overloads = __traits(getOverloads, module_, "modPropSetterOnly");
            static assert(overloads.length == 2);

            static assert( is(SymbolType!(overloads[0]) == ToFunctionType!(void function(string) @property)));
            static assert(!__traits(compiles, PropertyType!(overloads[0])));
            static assert(!__traits(compiles, typeof(overloads[0])));

            static assert( is(SymbolType!(overloads[1]) == ToFunctionType!(void function(int) @property)));
            static assert(!__traits(compiles, PropertyType!(overloads[1])));
            static assert(!__traits(compiles, typeof(overloads[1])));
        }

        // int function() @property modGetterFirstFuncPtr();
        // void modGetterFirstFuncPtr(int function() @property);
        {
            static assert( is(SymbolType!modGetterFirstFuncPtr ==
                              ToFunctionType!(int function() @property function())));
            static assert( is(PropertyType!modGetterFirstFuncPtr == int function() @property));
            static assert( is(typeof(modGetterFirstFuncPtr) == SymbolType!modGetterFirstFuncPtr));

            alias overloads = __traits(getOverloads, module_, "modGetterFirstFuncPtr");
            static assert(overloads.length == 2);

            static assert( is(SymbolType!(overloads[0]) == ToFunctionType!(int function() @property function())));
            static assert( is(PropertyType!(overloads[0]) == int function() @property));
            static assert( is(typeof(overloads[0]) == SymbolType!(overloads[0])));

            static assert( is(SymbolType!(overloads[1]) == ToFunctionType!(void function(int function() @property))));
            static assert(!__traits(compiles, PropertyType!(overloads[1])));
            static assert( is(typeof(overloads[1]) == SymbolType!(overloads[1])));
        }

        // void modSetterFirstFuncPtr(int function() @property);
        // int function() @property modSetterFirstFuncPtr();
        {
            static assert( is(SymbolType!modSetterFirstFuncPtr ==
                              ToFunctionType!(void function(int function() @property))));
            static assert( is(PropertyType!modSetterFirstFuncPtr == int function() @property));
            static assert( is(typeof(modSetterFirstFuncPtr) == SymbolType!modSetterFirstFuncPtr));

            alias overloads = __traits(getOverloads, module_, "modSetterFirstFuncPtr");
            static assert(overloads.length == 2);

            static assert( is(SymbolType!(overloads[0]) == ToFunctionType!(void function(int function() @property))));
            static assert(!__traits(compiles, PropertyType!(overloads[0])));
            static assert( is(typeof(overloads[0]) == SymbolType!(overloads[0])));

            static assert( is(SymbolType!(overloads[1]) == ToFunctionType!(int function() @property function())));
            static assert( is(PropertyType!(overloads[1]) == int function() @property));
            static assert( is(typeof(overloads[1]) == SymbolType!(overloads[1])));
        }

        // int function() @property modPropGetterFirstFuncPtr() @property;
        // void modPropGetterFirstFuncPtr(int function() @property) @property;
        {
            static assert( is(SymbolType!modPropGetterFirstFuncPtr ==
                              ToFunctionType!(int function() @property function() @property)));
            static assert( is(PropertyType!modPropGetterFirstFuncPtr == int function() @property));
            static assert( is(typeof(modPropGetterFirstFuncPtr) == PropertyType!modPropGetterFirstFuncPtr));

            alias overloads = __traits(getOverloads, module_, "modPropGetterFirstFuncPtr");
            static assert(overloads.length == 2);

            static assert( is(SymbolType!(overloads[0]) ==
                              ToFunctionType!(int function() @property function() @property)));
            static assert( is(PropertyType!(overloads[0]) == int function() @property));
            static assert( is(typeof(overloads[0]) == PropertyType!(overloads[0])));

            static assert( is(SymbolType!(overloads[1]) ==
                              ToFunctionType!(void function(int function() @property) @property)));
            static assert(!__traits(compiles, PropertyType!(overloads[1])));
            static assert(!__traits(compiles, typeof((overloads[1]))));
        }

        // void modPropSetterFirstFuncPtr(int function() @property) @property;
        // int function() @property modPropSetterFirstFuncPtr() @property;
        {
            static assert( is(SymbolType!modPropSetterFirstFuncPtr ==
                              ToFunctionType!(void function(int function() @property) @property)));
            static assert( is(PropertyType!modPropSetterFirstFuncPtr == int function() @property));
            static assert( is(typeof(modPropSetterFirstFuncPtr) == PropertyType!modPropSetterFirstFuncPtr));

            alias overloads = __traits(getOverloads, module_, "modPropSetterFirstFuncPtr");
            static assert(overloads.length == 2);

            static assert( is(SymbolType!(overloads[0]) ==
                              ToFunctionType!(void function(int function() @property) @property)));
            static assert(!__traits(compiles, PropertyType!(overloads[0])));
            static assert(!__traits(compiles, typeof(overloads[0])));

            static assert( is(SymbolType!(overloads[1]) ==
                              ToFunctionType!(int function() @property function() @property)));
            static assert( is(PropertyType!(overloads[1]) == int function() @property));
            static assert( is(typeof(overloads[1]) == PropertyType!(overloads[1])));
        }
    }

    {
        static struct S
        {
            int[] arr1;
            immutable bool[] arr2;

            void foo();
            static void bar();

            long bob();
            void sally(long);

            @property long propGetter();
            @property void propSetter(int[]);

            static @property long staticPropGetter();
            static @property void staticPropSetter(int[]);

            void func1();
            void func1(int[]);
            long func1(int[], long);

            long func2();
            long func2(int[]);
            int[] func2(int[], long);

            void func3(long*);
            void func3(real);
            int[] func3(long a = 0);

            long getterFirst();
            void getterFirst(long);

            void setterFirst(long);
            long setterFirst();

            void setterOnly(int[]);
            void setterOnly(long);

            static long staticGetterFirst();
            static void staticGetterFirst(long);

            static void staticSetterFirst(long);
            static long staticSetterFirst();

            static void staticSetterOnly(int[]);
            static void staticSetterOnly(long);

            @property long propGetterFirst();
            @property void propGetterFirst(long);

            @property void propSetterFirst(long);
            @property long propSetterFirst();

            @property void propSetterOnly(int[]);
            @property void propSetterOnly(long);

            static @property long staticPropGetterFirst();
            static @property void staticPropGetterFirst(long);

            static @property void staticPropSetterFirst(long);
            static @property long staticPropSetterFirst();

            static @property void staticPropSetterOnly(int[]);
            static @property void staticPropSetterOnly(long);

            long function() @property getterFirstFuncPtr();
            void getterFirstFuncPtr(long function() @property);

            void setterFirstFuncPtr(long function() @property);
            long function() @property setterFirstFuncPtr();

            long function() @property propGetterFirstFuncPtr() @property;
            void propGetterFirstFuncPtr(long function() @property) @property;

            void propSetterFirstFuncPtr(long function() @property) @property;
            long function() @property propSetterFirstFuncPtr() @property;

            static long delegate() @property staticGetterFirstDel();
            static void staticGetterFirstDel(long delegate() @property);

            static void staticSetterFirstDel(long delegate() @property);
            static long delegate() @property staticSetterFirstDel();

            static long delegate() @property staticPropGetterFirstDel() @property;
            static void staticPropGetterFirstDel(long delegate() @property) @property;

            static void staticPropSetterFirstDel(long delegate() @property) @property;
            static long delegate() @property staticPropSetterFirstDel() @property;
        }

        // int[] arr1;
        // immutable bool[] arr2;
        static assert( is(SymbolType!(S.arr1) == int[]));
        static assert( is(PropertyType!(S.arr1) == int[]));
        static assert( is(typeof(S.arr1) == int[]));

        static assert( is(SymbolType!(S.arr2) == immutable bool[]));
        static assert( is(PropertyType!(S.arr2) == immutable bool[]));
        static assert( is(typeof(S.arr2) == immutable bool[]));

        // void foo();
        static assert( is(SymbolType!(S.foo) == function));
        static assert( is(SymbolType!(S.foo) == ToFunctionType!(void function())));
        static assert(!__traits(compiles, PropertyType!(S.foo)));
        static assert( is(typeof(S.foo) == SymbolType!(S.foo)));

        //static void bar();
        static assert( is(SymbolType!(S.bar) == function));
        static assert( is(SymbolType!(S.bar) == ToFunctionType!(void function())));
        static assert(!__traits(compiles, PropertyType!(S.bar)));
        static assert( is(typeof(S.bar) == SymbolType!(S.bar)));

        // long bob();
        static assert( is(SymbolType!(S.bob) == function));
        static assert( is(SymbolType!(S.bob) == ToFunctionType!(long function())));
        static assert( is(PropertyType!(S.bob) == long));
        static assert( is(typeof(S.bob) == SymbolType!(S.bob)));

        // void sally(long);
        static assert( is(SymbolType!(S.sally) == function));
        static assert( is(SymbolType!(S.sally) == ToFunctionType!(void function(long))));
        static assert(!__traits(compiles, PropertyType!(S.sally)));
        static assert( is(typeof(S.sally) == SymbolType!(S.sally)));

        // @property long propGetter();
        static assert( is(SymbolType!(S.propGetter) == function));
        static assert( is(SymbolType!(S.propGetter) == ToFunctionType!(long function() @property)));
        static assert( is(PropertyType!(S.propGetter) == long));
        static assert( is(typeof(S.propGetter) == PropertyType!(S.propGetter)));

        // @property void propSetter(int[]);
        static assert( is(SymbolType!(S.propSetter) == function));
        static assert( is(SymbolType!(S.propSetter) == ToFunctionType!(void function(int[]) @property)));
        static assert(!__traits(compiles, PropertyType!(S.propSetter)));
        static assert(!__traits(compiles, typeof(S.propSetter)));

        // static @property long staticPropGetter();
        static assert( is(SymbolType!(S.staticPropGetter) == function));
        static assert( is(SymbolType!(S.staticPropGetter) == ToFunctionType!(long function() @property)));
        static assert( is(PropertyType!(S.staticPropGetter) == long));
        static assert( is(typeof(S.staticPropGetter) == PropertyType!(S.staticPropGetter)));

        // static @property void staticPropSetter(int[]);
        static assert( is(SymbolType!(S.staticPropSetter) == function));
        static assert( is(SymbolType!(S.staticPropSetter) == ToFunctionType!(void function(int[]) @property)));
        static assert(!__traits(compiles, PropertyType!(S.staticPropSetter)));
        static assert(!__traits(compiles, typeof(S.staticPropSetter)));

        // void func1();
        // void func1(int[]);
        // long func1(int[], long);
        {
            static assert( is(SymbolType!(S.func1) == ToFunctionType!(void function())));
            static assert(!__traits(compiles, PropertyType!(S.func1)));
            static assert( is(typeof((S.func1)) == SymbolType!(S.func1)));

            alias overloads = __traits(getOverloads, S, "func1");
            static assert(overloads.length == 3);

            static assert( is(SymbolType!(overloads[0]) == ToFunctionType!(void function())));
            static assert(!__traits(compiles, PropertyType!(overloads[0])));
            static assert( is(typeof(overloads[0]) == SymbolType!(overloads[0])));

            static assert( is(SymbolType!(overloads[1]) == ToFunctionType!(void function(int[]))));
            static assert(!__traits(compiles, PropertyType!(overloads[1])));
            static assert( is(typeof(overloads[1]) == SymbolType!(overloads[1])));

            static assert( is(SymbolType!(overloads[2]) == ToFunctionType!(long function(int[], long))));
            static assert(!__traits(compiles, PropertyType!(overloads[2])));
            static assert( is(typeof(overloads[2]) == SymbolType!(overloads[2])));
        }

        // long func2();
        // long func2(int[]);
        // int[] func2(int[], long);
        {
            static assert( is(SymbolType!(S.func2) == ToFunctionType!(long function())));
            static assert( is(PropertyType!(S.func2) == long));
            static assert( is(typeof((S.func2)) == SymbolType!(S.func2)));

            alias overloads = __traits(getOverloads, S, "func2");
            static assert(overloads.length == 3);

            static assert( is(SymbolType!(overloads[0]) == ToFunctionType!(long function())));
            static assert( is(PropertyType!(overloads[0]) == long));
            static assert( is(typeof(overloads[0]) == SymbolType!(overloads[0])));

            static assert( is(SymbolType!(overloads[1]) == ToFunctionType!(long function(int[]))));
            static assert(!__traits(compiles, PropertyType!(overloads[1])));
            static assert( is(typeof(overloads[1]) == SymbolType!(overloads[1])));

            static assert( is(SymbolType!(overloads[2]) == ToFunctionType!(int[] function(int[], long))));
            static assert(!__traits(compiles, PropertyType!(overloads[2])));
            static assert( is(typeof(overloads[2]) == SymbolType!(overloads[2])));
        }

        // void func3(long*);
        // void func3(real);
        // int[] func3(long a = 0);
        {
            static assert( is(SymbolType!(S.func3) == ToFunctionType!(void function(long*))));
            static assert( is(PropertyType!(S.func3) == int[]));
            static assert( is(typeof((S.func3)) == SymbolType!(S.func3)));

            alias overloads = __traits(getOverloads, S, "func3");
            static assert(overloads.length == 3);

            static assert( is(SymbolType!(overloads[0]) == ToFunctionType!(void function(long*))));
            static assert(!__traits(compiles, PropertyType!(overloads[0])));
            static assert( is(typeof(overloads[0]) == SymbolType!(overloads[0])));

            static assert( is(SymbolType!(overloads[1]) == ToFunctionType!(void function(real))));
            static assert(!__traits(compiles, PropertyType!(overloads[1])));
            static assert( is(typeof(overloads[1]) == SymbolType!(overloads[1])));

            static assert( is(SymbolType!(overloads[2]) == ToFunctionType!(int[] function(long))));
            static assert( is(PropertyType!(overloads[2]) == int[]));
            static assert( is(typeof(overloads[2]) == SymbolType!(overloads[2])));
        }

        // long getterFirst();
        // void getterFirst(long);
        {
            static assert( is(SymbolType!(S.getterFirst) == ToFunctionType!(long function())));
            static assert( is(PropertyType!(S.getterFirst) == long));
            static assert( is(typeof((S.getterFirst)) == SymbolType!(S.getterFirst)));

            alias overloads = __traits(getOverloads, S, "getterFirst");
            static assert(overloads.length == 2);

            static assert( is(SymbolType!(overloads[0]) == ToFunctionType!(long function())));
            static assert( is(PropertyType!(overloads[0]) == long));
            static assert( is(typeof(overloads[0]) == SymbolType!(overloads[0])));

            static assert( is(SymbolType!(overloads[1]) == ToFunctionType!(void function(long))));
            static assert(!__traits(compiles, PropertyType!(overloads[1])));
            static assert( is(typeof(overloads[1]) == SymbolType!(overloads[1])));
        }

        // void setterFirst(long);
        // long setterFirst();
        {
            static assert( is(SymbolType!(S.setterFirst) == ToFunctionType!(void function(long))));
            static assert( is(PropertyType!(S.setterFirst) == long));
            static assert( is(typeof((S.setterFirst)) == SymbolType!(S.setterFirst)));

            alias overloads = __traits(getOverloads, S, "setterFirst");
            static assert(overloads.length == 2);

            static assert( is(SymbolType!(overloads[0]) == ToFunctionType!(void function(long))));
            static assert(!__traits(compiles, PropertyType!(overloads[0])));
            static assert( is(typeof(overloads[0]) == SymbolType!(overloads[0])));

            static assert( is(SymbolType!(overloads[1]) == ToFunctionType!(long function())));
            static assert( is(PropertyType!(overloads[1]) == long));
            static assert( is(typeof(overloads[1]) == SymbolType!(overloads[1])));
        }

        // void setterOnly(int[]);
        // void setterOnly(long);
        {
            static assert( is(SymbolType!(S.setterOnly) == ToFunctionType!(void function(int[]))));
            static assert(!__traits(compiles, PropertyType!(S.setterOnly)));
            static assert( is(typeof((S.setterOnly)) == SymbolType!(S.setterOnly)));

            alias overloads = __traits(getOverloads, S, "setterOnly");
            static assert(overloads.length == 2);

            static assert( is(SymbolType!(overloads[0]) == ToFunctionType!(void function(int[]))));
            static assert(!__traits(compiles, PropertyType!(overloads[0])));
            static assert( is(typeof(overloads[0]) == SymbolType!(overloads[0])));

            static assert( is(SymbolType!(overloads[1]) == ToFunctionType!(void function(long))));
            static assert(!__traits(compiles, PropertyType!(overloads[1])));
            static assert( is(typeof(overloads[1]) == SymbolType!(overloads[1])));
        }

        // long staticGetterFirst();
        // void staticGetterFirst(long);
        {
            static assert( is(SymbolType!(S.staticGetterFirst) == ToFunctionType!(long function())));
            static assert( is(PropertyType!(S.staticGetterFirst) == long));
            static assert( is(typeof((S.staticGetterFirst)) == SymbolType!(S.staticGetterFirst)));

            alias overloads = __traits(getOverloads, S, "staticGetterFirst");
            static assert(overloads.length == 2);

            static assert( is(SymbolType!(overloads[0]) == ToFunctionType!(long function())));
            static assert( is(PropertyType!(overloads[0]) == long));
            static assert( is(typeof(overloads[0]) == SymbolType!(overloads[0])));

            static assert( is(SymbolType!(overloads[1]) == ToFunctionType!(void function(long))));
            static assert(!__traits(compiles, PropertyType!(overloads[1])));
            static assert( is(typeof(overloads[1]) == SymbolType!(overloads[1])));
        }

        // void staticSetterFirst(long);
        // long staticSetterFirst();
        {
            static assert( is(SymbolType!(S.staticSetterFirst) == ToFunctionType!(void function(long))));
            static assert( is(PropertyType!(S.staticSetterFirst) == long));
            static assert( is(typeof((S.staticSetterFirst)) == SymbolType!(S.staticSetterFirst)));

            alias overloads = __traits(getOverloads, S, "staticSetterFirst");
            static assert(overloads.length == 2);

            static assert( is(SymbolType!(overloads[0]) == ToFunctionType!(void function(long))));
            static assert(!__traits(compiles, PropertyType!(overloads[0])));
            static assert( is(typeof(overloads[0]) == SymbolType!(overloads[0])));

            static assert( is(SymbolType!(overloads[1]) == ToFunctionType!(long function())));
            static assert( is(PropertyType!(overloads[1]) == long));
            static assert( is(typeof(overloads[1]) == SymbolType!(overloads[1])));
        }

        // void staticSetterOnly(int[]);
        // void staticSetterOnly(long);
        {
            static assert( is(SymbolType!(S.staticSetterOnly) == ToFunctionType!(void function(int[]))));
            static assert(!__traits(compiles, PropertyType!(S.staticSetterOnly)));
            static assert( is(typeof((S.staticSetterOnly)) == SymbolType!(S.staticSetterOnly)));

            alias overloads = __traits(getOverloads, S, "staticSetterOnly");
            static assert(overloads.length == 2);

            static assert( is(SymbolType!(overloads[0]) == ToFunctionType!(void function(int[]))));
            static assert(!__traits(compiles, PropertyType!(overloads[0])));
            static assert( is(typeof(overloads[0]) == SymbolType!(overloads[0])));

            static assert( is(SymbolType!(overloads[1]) == ToFunctionType!(void function(long))));
            static assert(!__traits(compiles, PropertyType!(overloads[1])));
            static assert( is(typeof(overloads[1]) == SymbolType!(overloads[1])));
        }

        // @property long propGetterFirst();
        // @property void propGetterFirst(long);
        {
            static assert( is(SymbolType!(S.propGetterFirst) == ToFunctionType!(long function() @property)));
            static assert( is(PropertyType!(S.propGetterFirst) == long));
            static assert( is(typeof((S.propGetterFirst)) == PropertyType!(S.propGetterFirst)));

            alias overloads = __traits(getOverloads, S, "propGetterFirst");
            static assert(overloads.length == 2);

            static assert( is(SymbolType!(overloads[0]) == ToFunctionType!(long function() @property)));
            static assert( is(PropertyType!(overloads[0]) == long));
            static assert( is(typeof(overloads[0]) == PropertyType!(overloads[0])));

            static assert( is(SymbolType!(overloads[1]) == ToFunctionType!(void function(long) @property)));
            static assert(!__traits(compiles, PropertyType!(overloads[1])));
            static assert(!__traits(compiles, typeof((overloads[1]))));
        }

        // @property void propSetterFirst(long);
        // @property long propSetterFirst();
        {
            static assert( is(SymbolType!(S.propSetterFirst) == ToFunctionType!(void function(long) @property)));
            static assert( is(PropertyType!(S.propSetterFirst) == long));
            static assert( is(typeof((S.propSetterFirst)) == PropertyType!(S.propSetterFirst)));

            alias overloads = __traits(getOverloads, S, "propSetterFirst");
            static assert(overloads.length == 2);

            static assert( is(SymbolType!(overloads[0]) == ToFunctionType!(void function(long) @property)));
            static assert(!__traits(compiles, PropertyType!(overloads[0])));
            static assert(!__traits(compiles, typeof(overloads[0])));

            static assert( is(SymbolType!(overloads[1]) == ToFunctionType!(long function() @property)));
            static assert( is(PropertyType!(overloads[1]) == long));
            static assert( is(typeof(overloads[1]) == PropertyType!(overloads[1])));
        }

        // @property void propSetterOnly(int[]);
        // @property void propSetterOnly(long);
        {
            static assert( is(SymbolType!(S.propSetterOnly) == ToFunctionType!(void function(int[]) @property)));
            static assert(!__traits(compiles, PropertyType!(S.propSetterOnly)));
            static assert(!__traits(compiles, typeof((S.propSetterOnly))));

            alias overloads = __traits(getOverloads, S, "propSetterOnly");
            static assert(overloads.length == 2);

            static assert( is(SymbolType!(overloads[0]) == ToFunctionType!(void function(int[]) @property)));
            static assert(!__traits(compiles, PropertyType!(overloads[0])));
            static assert(!__traits(compiles, typeof(overloads[0])));

            static assert( is(SymbolType!(overloads[1]) == ToFunctionType!(void function(long) @property)));
            static assert(!__traits(compiles, PropertyType!(overloads[1])));
            static assert(!__traits(compiles, typeof(overloads[1])));
        }

        // @property long staticPropGetterFirst();
        // @property void staticPropGetterFirst(long);
        {
            static assert( is(SymbolType!(S.staticPropGetterFirst) == ToFunctionType!(long function() @property)));
            static assert( is(PropertyType!(S.staticPropGetterFirst) == long));
            static assert( is(typeof((S.staticPropGetterFirst)) == PropertyType!(S.staticPropGetterFirst)));

            alias overloads = __traits(getOverloads, S, "staticPropGetterFirst");
            static assert(overloads.length == 2);

            static assert( is(SymbolType!(overloads[0]) == ToFunctionType!(long function() @property)));
            static assert( is(PropertyType!(overloads[0]) == long));
            static assert( is(typeof(overloads[0]) == PropertyType!(overloads[0])));

            static assert( is(SymbolType!(overloads[1]) == ToFunctionType!(void function(long) @property)));
            static assert(!__traits(compiles, PropertyType!(overloads[1])));
            static assert(!__traits(compiles, typeof((overloads[1]))));
        }

        // @property void staticPropSetterFirst(long);
        // @property long staticPropSetterFirst();
        {
            static assert( is(SymbolType!(S.staticPropSetterFirst) == ToFunctionType!(void function(long) @property)));
            static assert( is(PropertyType!(S.staticPropSetterFirst) == long));
            static assert( is(typeof((S.staticPropSetterFirst)) == PropertyType!(S.staticPropSetterFirst)));

            alias overloads = __traits(getOverloads, S, "staticPropSetterFirst");
            static assert(overloads.length == 2);

            static assert( is(SymbolType!(overloads[0]) == ToFunctionType!(void function(long) @property)));
            static assert(!__traits(compiles, PropertyType!(overloads[0])));
            static assert(!__traits(compiles, typeof(overloads[0])));

            static assert( is(SymbolType!(overloads[1]) == ToFunctionType!(long function() @property)));
            static assert( is(PropertyType!(overloads[1]) == long));
            static assert( is(typeof(overloads[1]) == PropertyType!(overloads[1])));
        }

        // @property void staticPropSetterOnly(int[]);
        // @property void staticPropSetterOnly(long);
        {
            static assert( is(SymbolType!(S.staticPropSetterOnly) == ToFunctionType!(void function(int[]) @property)));
            static assert(!__traits(compiles, PropertyType!(S.staticPropSetterOnly)));
            static assert(!__traits(compiles, typeof((S.staticPropSetterOnly))));

            alias overloads = __traits(getOverloads, S, "staticPropSetterOnly");
            static assert(overloads.length == 2);

            static assert( is(SymbolType!(overloads[0]) == ToFunctionType!(void function(int[]) @property)));
            static assert(!__traits(compiles, PropertyType!(overloads[0])));
            static assert(!__traits(compiles, typeof(overloads[0])));

            static assert( is(SymbolType!(overloads[1]) == ToFunctionType!(void function(long) @property)));
            static assert(!__traits(compiles, PropertyType!(overloads[1])));
            static assert(!__traits(compiles, typeof(overloads[1])));
        }

        // long function() @property getterFirstFuncPtr();
        // void getterFirstFuncPtr(long function() @property);
        {
            static assert( is(SymbolType!(S.getterFirstFuncPtr) ==
                              ToFunctionType!(long function() @property function())));
            static assert( is(PropertyType!(S.getterFirstFuncPtr) == long function() @property));
            static assert( is(typeof((S.getterFirstFuncPtr)) == SymbolType!(S.getterFirstFuncPtr)));

            alias overloads = __traits(getOverloads, S, "getterFirstFuncPtr");
            static assert(overloads.length == 2);

            static assert( is(SymbolType!(overloads[0]) == ToFunctionType!(long function() @property function())));
            static assert( is(PropertyType!(overloads[0]) == long function() @property));
            static assert( is(typeof(overloads[0]) == SymbolType!(overloads[0])));

            static assert( is(SymbolType!(overloads[1]) == ToFunctionType!(void function(long function() @property))));
            static assert(!__traits(compiles, PropertyType!(overloads[1])));
            static assert( is(typeof(overloads[1]) == SymbolType!(overloads[1])));
        }

        // void setterFirstFuncPtr(long function() @property);
        // long function() @property setterFirstFuncPtr();
        {
            static assert( is(SymbolType!(S.setterFirstFuncPtr) ==
                              ToFunctionType!(void function(long function() @property))));
            static assert( is(PropertyType!(S.setterFirstFuncPtr) == long function() @property));
            static assert( is(typeof((S.setterFirstFuncPtr)) == SymbolType!(S.setterFirstFuncPtr)));

            alias overloads = __traits(getOverloads, S, "setterFirstFuncPtr");
            static assert(overloads.length == 2);

            static assert( is(SymbolType!(overloads[0]) == ToFunctionType!(void function(long function() @property))));
            static assert(!__traits(compiles, PropertyType!(overloads[0])));
            static assert( is(typeof(overloads[0]) == SymbolType!(overloads[0])));

            static assert( is(SymbolType!(overloads[1]) == ToFunctionType!(long function() @property function())));
            static assert( is(PropertyType!(overloads[1]) == long function() @property));
            static assert( is(typeof(overloads[1]) == SymbolType!(overloads[1])));
        }

        // long function() @property propGetterFirstFuncPtr() @property;
        // void propGetterFirstFuncPtr(long function() @property) @property;
        {
            static assert( is(SymbolType!(S.propGetterFirstFuncPtr) ==
                              ToFunctionType!(long function() @property function() @property)));
            static assert( is(PropertyType!(S.propGetterFirstFuncPtr) == long function() @property));
            static assert( is(typeof((S.propGetterFirstFuncPtr)) == PropertyType!(S.propGetterFirstFuncPtr)));

            alias overloads = __traits(getOverloads, S, "propGetterFirstFuncPtr");
            static assert(overloads.length == 2);

            static assert( is(SymbolType!(overloads[0]) ==
                              ToFunctionType!(long function() @property function() @property)));
            static assert( is(PropertyType!(overloads[0]) == long function() @property));
            static assert( is(typeof(overloads[0]) == PropertyType!(overloads[0])));

            static assert( is(SymbolType!(overloads[1]) ==
                              ToFunctionType!(void function(long function() @property) @property)));
            static assert(!__traits(compiles, PropertyType!(overloads[1])));
            static assert(!__traits(compiles, typeof((overloads[1]))));
        }

        // void propSetterFirstFuncPtr(long function() @property) @property;
        // long function() @property propSetterFirstFuncPtr() @property;
        {
            static assert( is(SymbolType!(S.propSetterFirstFuncPtr) ==
                              ToFunctionType!(void function(long function() @property) @property)));
            static assert( is(PropertyType!(S.propSetterFirstFuncPtr) == long function() @property));
            static assert( is(typeof((S.propSetterFirstFuncPtr)) == PropertyType!(S.propSetterFirstFuncPtr)));

            alias overloads = __traits(getOverloads, S, "propSetterFirstFuncPtr");
            static assert(overloads.length == 2);

            static assert( is(SymbolType!(overloads[0]) ==
                              ToFunctionType!(void function(long function() @property) @property)));
            static assert(!__traits(compiles, PropertyType!(overloads[0])));
            static assert(!__traits(compiles, typeof(overloads[0])));

            static assert( is(SymbolType!(overloads[1]) ==
                              ToFunctionType!(long function() @property function() @property)));
            static assert( is(PropertyType!(overloads[1]) == long function() @property));
            static assert( is(typeof(overloads[1]) == PropertyType!(overloads[1])));
        }

        // long function() @property staticGetterFirstDel();
        // void staticGetterFirstDel(long function() @property);
        {
            static assert( is(SymbolType!(S.staticGetterFirstDel) ==
                              ToFunctionType!(long delegate() @property function())));
            static assert( is(PropertyType!(S.staticGetterFirstDel) == long delegate() @property));
            static assert( is(typeof((S.staticGetterFirstDel)) == SymbolType!(S.staticGetterFirstDel)));

            alias overloads = __traits(getOverloads, S, "staticGetterFirstDel");
            static assert(overloads.length == 2);

            static assert( is(SymbolType!(overloads[0]) == ToFunctionType!(long delegate() @property function())));
            static assert( is(PropertyType!(overloads[0]) == long delegate() @property));
            static assert( is(typeof(overloads[0]) == SymbolType!(overloads[0])));

            static assert( is(SymbolType!(overloads[1]) == ToFunctionType!(void function(long delegate() @property))));
            static assert(!__traits(compiles, PropertyType!(overloads[1])));
            static assert( is(typeof(overloads[1]) == SymbolType!(overloads[1])));
        }

        // void setterFirstDel(long function() @property);
        // long function() @property setterFirstDel();
        {
            static assert( is(SymbolType!(S.staticSetterFirstDel) ==
                              ToFunctionType!(void function(long delegate() @property))));
            static assert( is(PropertyType!(S.staticSetterFirstDel) == long delegate() @property));
            static assert( is(typeof((S.staticSetterFirstDel)) == SymbolType!(S.staticSetterFirstDel)));

            alias overloads = __traits(getOverloads, S, "staticSetterFirstDel");
            static assert(overloads.length == 2);

            static assert( is(SymbolType!(overloads[0]) == ToFunctionType!(void function(long delegate() @property))));
            static assert(!__traits(compiles, PropertyType!(overloads[0])));
            static assert( is(typeof(overloads[0]) == SymbolType!(overloads[0])));

            static assert( is(SymbolType!(overloads[1]) == ToFunctionType!(long delegate() @property function())));
            static assert( is(PropertyType!(overloads[1]) == long delegate() @property));
            static assert( is(typeof(overloads[1]) == SymbolType!(overloads[1])));
        }

        // long function() @property staticPropGetterFirstDel() @property;
        // void staticPropGetterFirstDel(long function() @property) @property;
        {
            static assert( is(SymbolType!(S.staticPropGetterFirstDel) ==
                              ToFunctionType!(long delegate() @property function() @property)));
            static assert( is(PropertyType!(S.staticPropGetterFirstDel) == long delegate() @property));
            static assert( is(typeof((S.staticPropGetterFirstDel)) == PropertyType!(S.staticPropGetterFirstDel)));

            alias overloads = __traits(getOverloads, S, "staticPropGetterFirstDel");
            static assert(overloads.length == 2);

            static assert( is(SymbolType!(overloads[0]) ==
                              ToFunctionType!(long delegate() @property function() @property)));
            static assert( is(PropertyType!(overloads[0]) == long delegate() @property));
            static assert( is(typeof(overloads[0]) == PropertyType!(overloads[0])));

            static assert( is(SymbolType!(overloads[1]) ==
                              ToFunctionType!(void function(long delegate() @property) @property)));
            static assert(!__traits(compiles, PropertyType!(overloads[1])));
            static assert(!__traits(compiles, typeof((overloads[1]))));
        }

        // void propSetterFirstDel(long function() @property) @property;
        // long function() @property propSetterFirstDel() @property;
        {
            static assert( is(SymbolType!(S.staticPropSetterFirstDel) ==
                              ToFunctionType!(void function(long delegate() @property) @property)));
            static assert( is(PropertyType!(S.staticPropSetterFirstDel) == long delegate() @property));
            static assert( is(typeof((S.staticPropSetterFirstDel)) == PropertyType!(S.staticPropSetterFirstDel)));

            alias overloads = __traits(getOverloads, S, "staticPropSetterFirstDel");
            static assert(overloads.length == 2);

            static assert( is(SymbolType!(overloads[0]) ==
                              ToFunctionType!(void function(long delegate() @property) @property)));
            static assert(!__traits(compiles, PropertyType!(overloads[0])));
            static assert(!__traits(compiles, typeof(overloads[0])));

            static assert( is(SymbolType!(overloads[1]) ==
                              ToFunctionType!(long delegate() @property function() @property)));
            static assert( is(PropertyType!(overloads[1]) == long delegate() @property));
            static assert( is(typeof(overloads[1]) == PropertyType!(overloads[1])));
        }
    }
    {
        static interface I
        {
            void foo();
            static void bar();

            int func1();
            void func1(int);

            void func2(int);
            int func2();

            @property void prop1(int);
            @property int prop1();

            @property int prop2();
            @property void prop2(int);

            static @property string staticProp();
            static @property void staticProp(real);

            @property void extraProp(string);

            int defaultArg1(string str = "foo");
            void defaultArg1(int, string str = "foo");

            void defaultArg2(int, string str = "foo");
            int defaultArg2(string str = "foo");

            @property int defaultArgProp1(string str = "foo");
            @property void defaultArgProp1(int, string str = "foo");

            @property void defaultArgProp2(int, string str = "foo");
            @property int defaultArgProp2(string str = "foo");

            string defaultArgInDerived1(int);
            void defaultArgInDerived1(string, int);

            void defaultArgInDerived2(string, int);
            string defaultArgInDerived2(int);

            @property string defaultArgInDerivedProp1(int);
            @property void defaultArgInDerivedProp1(string, int);

            @property void defaultArgInDerivedProp2(string, int);
            @property string defaultArgInDerivedProp2(int);
        }

        {
            // void foo()
            static assert( is(SymbolType!(I.foo) == ToFunctionType!(void function())));
            static assert(!__traits(compiles, PropertyType!(I.foo)));
            static assert( is(typeof(I.foo) == SymbolType!(I.foo)));

            // static void bar()
            static assert( is(SymbolType!(I.bar) == ToFunctionType!(void function())));
            static assert(!__traits(compiles, PropertyType!(I.bar)));
            static assert( is(typeof(I.bar) == SymbolType!(I.bar)));

            // int func1();
            // void func1(int);
            {
                static assert( is(SymbolType!(I.func1) == ToFunctionType!(int function())));
                static assert( is(PropertyType!(I.func1) == int));
                static assert( is(typeof(I.func1) == SymbolType!(I.func1)));

                alias overloads = __traits(getOverloads, I, "func1");
                static assert(overloads.length == 2);

                static assert( is(SymbolType!(overloads[0]) == ToFunctionType!(int function())));
                static assert( is(PropertyType!(overloads[0]) == int));
                static assert( is(typeof(overloads[0]) == SymbolType!(overloads[0])));

                static assert( is(SymbolType!(overloads[1]) == ToFunctionType!(void function(int))));
                static assert(!__traits(compiles, PropertyType!(overloads[1])));
                static assert( is(typeof(overloads[1]) == SymbolType!(overloads[1])));
            }

            // void func2(int);
            // int func2();
            {
                static assert( is(SymbolType!(I.func2) == ToFunctionType!(void function(int))));
                static assert( is(PropertyType!(I.func2) == int));
                static assert( is(typeof(I.func2) == SymbolType!(I.func2)));

                alias overloads = __traits(getOverloads, I, "func2");
                static assert(overloads.length == 2);

                static assert( is(SymbolType!(overloads[0]) == ToFunctionType!(void function(int))));
                static assert(!__traits(compiles, PropertyType!(overloads[0])));
                static assert( is(typeof(overloads[0]) == SymbolType!(overloads[0])));

                static assert( is(SymbolType!(overloads[1]) == ToFunctionType!(int function())));
                static assert( is(PropertyType!(overloads[1]) == int));
                static assert( is(typeof(overloads[1]) == SymbolType!(overloads[1])));
            }

            // @property void prop1(int);
            // @property int prop1();
            {
                static assert( is(SymbolType!(I.prop1) == ToFunctionType!(void function(int) @property)));
                static assert( is(PropertyType!(I.prop1) == int));
                static assert( is(typeof(I.prop1) == PropertyType!(I.prop1)));

                alias overloads = __traits(getOverloads, I, "prop1");
                static assert(overloads.length == 2);

                static assert( is(SymbolType!(overloads[0]) == ToFunctionType!(void function(int) @property)));
                static assert(!__traits(compiles, PropertyType!(overloads[0])));
                static assert(!__traits(compiles, typeof(overloads[0])));

                static assert( is(SymbolType!(overloads[1]) == ToFunctionType!(int function() @property)));
                static assert( is(PropertyType!(overloads[1]) == int));
                static assert( is(typeof(overloads[1]) == PropertyType!(overloads[1])));
            }

            // @property int prop2();
            // @property void prop2(int);
            {
                static assert( is(SymbolType!(I.prop2) == ToFunctionType!(int function() @property)));
                static assert( is(PropertyType!(I.prop2) == int));
                static assert( is(typeof(I.prop2) == PropertyType!(I.prop2)));

                alias overloads = __traits(getOverloads, I, "prop2");
                static assert(overloads.length == 2);

                static assert( is(SymbolType!(overloads[0]) == ToFunctionType!(int function() @property)));
                static assert( is(PropertyType!(overloads[0]) == int));
                static assert( is(typeof(overloads[0]) == PropertyType!(overloads[0])));

                static assert( is(SymbolType!(overloads[1]) == ToFunctionType!(void function(int) @property)));
                static assert(!__traits(compiles, PropertyType!(overloads[1])));
                static assert(!__traits(compiles, typeof(overloads[1])));
            }

            // static @property string staticProp();
            // static @property void staticProp(real);
            {
                static assert( is(SymbolType!(I.staticProp) == ToFunctionType!(string function() @property)));
                static assert( is(PropertyType!(I.staticProp) == string));
                static assert( is(typeof(I.staticProp) == PropertyType!(I.staticProp)));

                alias overloads = __traits(getOverloads, I, "staticProp");
                static assert(overloads.length == 2);

                static assert( is(SymbolType!(overloads[0]) == ToFunctionType!(string function() @property)));
                static assert( is(PropertyType!(overloads[0]) == string));
                static assert( is(typeof(overloads[0]) == PropertyType!(overloads[0])));

                static assert( is(SymbolType!(overloads[1]) == ToFunctionType!(void function(real) @property)));
                static assert(!__traits(compiles, PropertyType!(overloads[1])));
                static assert(!__traits(compiles, typeof(overloads[1])));
            }

            // @property void extraProp(string);
            {
                static assert( is(SymbolType!(I.extraProp) == ToFunctionType!(void function(string) @property)));
                static assert(!__traits(compiles, PropertyType!(I.extraProp)));
                static assert(!__traits(compiles, typeof(I.extraProp)));

                alias overloads = __traits(getOverloads, I, "extraProp");
                static assert(overloads.length == 1);

                static assert( is(SymbolType!(overloads[0]) == ToFunctionType!(void function(string) @property)));
                static assert(!__traits(compiles, PropertyType!(overloads[0])));
                static assert(!__traits(compiles, typeof(overloads[0])));
            }

            // int defaultArg1(string str = "foo");
            // void defaultArg1(int, string str = "foo");
            {
                static assert( is(SymbolType!(I.defaultArg1) == ToFunctionType!(int function(string))));
                static assert( is(PropertyType!(I.defaultArg1) == int));
                static assert( is(typeof(I.defaultArg1) == SymbolType!(I.defaultArg1)));

                alias overloads = __traits(getOverloads, I, "defaultArg1");
                static assert(overloads.length == 2);

                static assert( is(SymbolType!(overloads[0]) == ToFunctionType!(int function(string))));
                static assert( is(PropertyType!(overloads[0]) == int));
                static assert( is(typeof(overloads[0]) == SymbolType!(overloads[0])));

                static assert( is(SymbolType!(overloads[1]) == ToFunctionType!(void function(int, string))));
                static assert(!__traits(compiles, PropertyType!(overloads[1])));
                static assert( is(typeof(overloads[1]) == SymbolType!(overloads[1])));
            }

            // void defaultArg2(int, string str = "foo");
            // int defaultArg2(string str = "foo");
            {
                static assert( is(SymbolType!(I.defaultArg2) == ToFunctionType!(void function(int, string))));
                static assert( is(PropertyType!(I.defaultArg2) == int));
                static assert( is(typeof(I.defaultArg2) == SymbolType!(I.defaultArg2)));

                alias overloads = __traits(getOverloads, I, "defaultArg2");
                static assert(overloads.length == 2);

                static assert( is(SymbolType!(overloads[0]) == ToFunctionType!(void function(int, string))));
                static assert(!__traits(compiles, PropertyType!(overloads[0])));
                static assert( is(typeof(overloads[0]) == SymbolType!(overloads[0])));

                static assert( is(SymbolType!(overloads[1]) == ToFunctionType!(int function(string))));
                static assert( is(PropertyType!(overloads[1]) == int));
                static assert( is(typeof(overloads[1]) == SymbolType!(overloads[1])));
            }

            // @property int defaultArgProp1(string str = "foo");
            // @property void defaultArgProp1(int, string str = "foo");
            {
                static assert( is(SymbolType!(I.defaultArgProp1) == ToFunctionType!(int function(string) @property)));
                static assert( is(PropertyType!(I.defaultArgProp1) == int));
                static assert( is(typeof(I.defaultArgProp1) == PropertyType!(I.defaultArgProp1)));

                alias overloads = __traits(getOverloads, I, "defaultArgProp1");
                static assert(overloads.length == 2);

                static assert( is(SymbolType!(overloads[0]) == ToFunctionType!(int function(string) @property)));
                static assert( is(PropertyType!(overloads[0]) == int));
                static assert( is(typeof(overloads[0]) == PropertyType!(overloads[0])));

                static assert( is(SymbolType!(overloads[1]) == ToFunctionType!(void function(int, string) @property)));
                static assert(!__traits(compiles, PropertyType!(overloads[1])));
                static assert(!__traits(compiles, typeof(overloads[1])));
            }

            // @property void defaultArgProp2(int, string str = "foo");
            // @property int defaultArgProp2(string str = "foo");
            {
                static assert( is(SymbolType!(I.defaultArgProp2) ==
                                  ToFunctionType!(void function(int, string) @property)));
                static assert( is(PropertyType!(I.defaultArgProp2) == int));
                static assert( is(typeof(I.defaultArgProp2) == PropertyType!(I.defaultArgProp2)));

                alias overloads = __traits(getOverloads, I, "defaultArgProp2");
                static assert(overloads.length == 2);

                static assert( is(SymbolType!(overloads[0]) == ToFunctionType!(void function(int, string) @property)));
                static assert(!__traits(compiles, PropertyType!(overloads[0])));
                static assert(!__traits(compiles, typeof(overloads[0])));

                static assert( is(SymbolType!(overloads[1]) == ToFunctionType!(int function(string) @property)));
                static assert( is(PropertyType!(overloads[1]) == int));
                static assert( is(typeof(overloads[1]) == PropertyType!(overloads[1])));
            }

            // string defaultArgInDerived1(int);
            // void defaultArgInDerived1(string, int);
            {
                static assert( is(SymbolType!(I.defaultArgInDerived1) == ToFunctionType!(string function(int))));
                static assert(!__traits(compiles, PropertyType!(I.defaultArgInDerived1)));
                static assert( is(typeof(I.defaultArgInDerived1) == SymbolType!(I.defaultArgInDerived1)));

                alias overloads = __traits(getOverloads, I, "defaultArgInDerived1");
                static assert(overloads.length == 2);

                static assert( is(SymbolType!(overloads[0]) == ToFunctionType!(string function(int))));
                static assert(!__traits(compiles, PropertyType!(overloads[0])));
                static assert( is(typeof(overloads[0]) == SymbolType!(overloads[0])));

                static assert( is(SymbolType!(overloads[1]) == ToFunctionType!(void function(string, int))));
                static assert(!__traits(compiles, PropertyType!(overloads[1])));
                static assert( is(typeof(overloads[1]) == SymbolType!(overloads[1])));
            }

            // void defaultArgInDerived2(string, int);
            // string defaultArgInDerived2(int);
            {
                static assert( is(SymbolType!(I.defaultArgInDerived2) == ToFunctionType!(void function(string, int))));
                static assert(!__traits(compiles, PropertyType!(I.defaultArgInDerived2)));
                static assert( is(typeof(I.defaultArgInDerived2) == SymbolType!(I.defaultArgInDerived2)));

                alias overloads = __traits(getOverloads, I, "defaultArgInDerived2");
                static assert(overloads.length == 2);

                static assert( is(SymbolType!(overloads[0]) == ToFunctionType!(void function(string, int))));
                static assert(!__traits(compiles, PropertyType!(overloads[0])));
                static assert( is(typeof(overloads[0]) == SymbolType!(overloads[0])));

                static assert( is(SymbolType!(overloads[1]) == ToFunctionType!(string function(int))));
                static assert(!__traits(compiles, PropertyType!(overloads[1])));
                static assert( is(typeof(overloads[1]) == SymbolType!(overloads[1])));
            }

            // @property string defaultArgInDerivedProp1(int);
            // @property void defaultArgInDerivedProp1(string, int);
            {
                static assert( is(SymbolType!(I.defaultArgInDerivedProp1) ==
                                  ToFunctionType!(string function(int) @property)));
                static assert(!__traits(compiles, PropertyType!(I.defaultArgInDerivedProp1)));
                static assert(!__traits(compiles, typeof(I.defaultArgInDerivedProp1)));

                alias overloads = __traits(getOverloads, I, "defaultArgInDerivedProp1");
                static assert(overloads.length == 2);

                static assert( is(SymbolType!(overloads[0]) == ToFunctionType!(string function(int) @property)));
                static assert(!__traits(compiles, PropertyType!(overloads[0])));
                static assert(!__traits(compiles, typeof(overloads[0])));

                static assert( is(SymbolType!(overloads[1]) == ToFunctionType!(void function(string, int) @property)));
                static assert(!__traits(compiles, PropertyType!(overloads[1])));
                static assert(!__traits(compiles, typeof(overloads[0])));
            }

            // @property void defaultArgInDerivedProp2(string, int);
            // @property string defaultArgInDerivedProp2(int);
            {
                static assert( is(SymbolType!(I.defaultArgInDerivedProp2) ==
                                  ToFunctionType!(void function(string, int) @property)));
                static assert(!__traits(compiles, PropertyType!(I.defaultArgInDerivedProp2)));
                static assert(!__traits(compiles, typeof(I.defaultArgInDerivedProp2)));

                alias overloads = __traits(getOverloads, I, "defaultArgInDerivedProp2");
                static assert(overloads.length == 2);

                static assert( is(SymbolType!(overloads[0]) == ToFunctionType!(void function(string, int) @property)));
                static assert(!__traits(compiles, PropertyType!(overloads[0])));
                static assert(!__traits(compiles, typeof(overloads[0])));

                static assert( is(SymbolType!(overloads[1]) == ToFunctionType!(string function(int) @property)));
                static assert(!__traits(compiles, PropertyType!(overloads[1])));
                static assert(!__traits(compiles, typeof(overloads[1])));
            }
        }

        // For whatever reason, the virtual functions have to have bodies, or
        // the linker complains, even though the functions aren't actually
        // called anywhere, but having them implement the functions which are in
        // the interface at least gets rid of the attribute inference.
        static class C1 : I
        {
            shared int i;
            string s;

            override void foo() {}

            // This shadows the one in the interface, and it has a different
            // signature, so it makes sure that we're getting the right one.
            static int bar();

            final void baz();

            override int func1() { return 0; }
            override void func1(int) {}

            override void func2(int) {}
            override int func2() { return 0; }

            override @property void prop1(int) {}
            override @property int prop1() { return 0; }

            override @property int prop2() { return 0; }
            override @property void prop2(int) {}

            override @property void extraProp(string) {}
            @property bool extraProp() { return true; }

            override int defaultArg1(string str = "foo") { return 42; }
            override void defaultArg1(int, string str = "foo") {}

            // This tests the case where the derived type doesn't provide
            // default arguments even though the interface does.
            override void defaultArg2(int, string str) {}
            override int defaultArg2(string str) { return 42; }

            override @property int defaultArgProp1(string str = "foo") { return 42; }
            override @property void defaultArgProp1(int, string str = "foo") {}

            // This tests the case where the derived type doesn't provide
            // default arguments even though the interface does.
            override @property void defaultArgProp2(int, string str) {}
            override @property int defaultArgProp2(string str) { return 42; }

            override string defaultArgInDerived1(int i = 0) { return ""; }
            override void defaultArgInDerived1(string, int i = 0) {}

            override void defaultArgInDerived2(string, int i = 0) {}
            override string defaultArgInDerived2(int i = 0) { return ""; }

            @property string defaultArgInDerivedProp1(int i = 0) { return ""; }
            @property void defaultArgInDerivedProp1(string, int i = 0) {}

            @property void defaultArgInDerivedProp2(string, int i = 0) {}
            @property string defaultArgInDerivedProp2(int i = 0) { return ""; }
        }

        {
            // shared int i;
            // string s;
            static assert( is(SymbolType!(C1.i) == shared int));
            static assert( is(PropertyType!(C1.i) == shared int));
            static assert( is(typeof(C1.i) == shared int));

            static assert( is(SymbolType!(C1.s) == string));
            static assert( is(PropertyType!(C1.s) == string));
            static assert( is(typeof(C1.s) == string));

            // override void foo()
            static assert( is(SymbolType!(C1.foo) == ToFunctionType!(void function())));
            static assert(!__traits(compiles, PropertyType!(C1.foo)));
            static assert( is(typeof(C1.foo) == SymbolType!(C1.foo)));

            // static int bar()
            static assert( is(SymbolType!(C1.bar) == ToFunctionType!(int function())));
            static assert( is(PropertyType!(C1.bar) == int));
            static assert( is(typeof(C1.bar) == SymbolType!(C1.bar)));

            // void baz()
            static assert( is(SymbolType!(C1.baz) == ToFunctionType!(void function())));
            static assert(!__traits(compiles, PropertyType!(C1.baz)));
            static assert( is(typeof(C1.baz) == SymbolType!(C1.baz)));

            // override int func1();
            // override void func1(int);
            {
                static assert( is(SymbolType!(C1.func1) == ToFunctionType!(int function())));
                static assert( is(PropertyType!(C1.func1) == int));
                static assert( is(typeof(C1.func1) == SymbolType!(C1.func1)));

                alias overloads = __traits(getOverloads, C1, "func1");
                static assert(overloads.length == 2);

                static assert( is(SymbolType!(overloads[0]) == ToFunctionType!(int function())));
                static assert( is(PropertyType!(overloads[0]) == int));
                static assert( is(typeof(overloads[0]) == SymbolType!(overloads[0])));

                static assert( is(SymbolType!(overloads[1]) == ToFunctionType!(void function(int))));
                static assert(!__traits(compiles, PropertyType!(overloads[1])));
                static assert( is(typeof(overloads[1]) == SymbolType!(overloads[1])));
            }

            // override void func2(int);
            // override int func2();
            {
                static assert( is(SymbolType!(C1.func2) == ToFunctionType!(void function(int))));
                static assert( is(PropertyType!(C1.func2) == int));
                static assert( is(typeof(C1.func2) == SymbolType!(C1.func2)));

                alias overloads = __traits(getOverloads, C1, "func2");
                static assert(overloads.length == 2);

                static assert( is(SymbolType!(overloads[0]) == ToFunctionType!(void function(int))));
                static assert(!__traits(compiles, PropertyType!(overloads[0])));
                static assert( is(typeof(overloads[0]) == SymbolType!(overloads[0])));

                static assert( is(SymbolType!(overloads[1]) == ToFunctionType!(int function())));
                static assert( is(PropertyType!(overloads[1]) == int));
                static assert( is(typeof(overloads[1]) == SymbolType!(overloads[1])));
            }

            // override @property void prop1(int);
            // override @property int prop1();
            {
                static assert( is(SymbolType!(C1.prop1) == ToFunctionType!(void function(int) @property)));
                static assert( is(PropertyType!(C1.prop1) == int));
                static assert( is(typeof(C1.prop1) == PropertyType!(C1.prop1)));

                alias overloads = __traits(getOverloads, C1, "prop1");
                static assert(overloads.length == 2);

                static assert( is(SymbolType!(overloads[0]) == ToFunctionType!(void function(int) @property)));
                static assert(!__traits(compiles, PropertyType!(overloads[0])));
                static assert(!__traits(compiles, typeof(overloads[0])));

                static assert( is(SymbolType!(overloads[1]) == ToFunctionType!(int function() @property)));
                static assert( is(PropertyType!(overloads[1]) == int));
                static assert( is(typeof(overloads[1]) == PropertyType!(overloads[1])));
            }

            // override @property int prop2();
            // override @property void prop2(int);
            {
                static assert( is(SymbolType!(C1.prop2) == ToFunctionType!(int function() @property)));
                static assert( is(PropertyType!(C1.prop2) == int));
                static assert( is(typeof(C1.prop2) == PropertyType!(C1.prop2)));

                alias overloads = __traits(getOverloads, C1, "prop2");
                static assert(overloads.length == 2);

                static assert( is(SymbolType!(overloads[0]) == ToFunctionType!(int function() @property)));
                static assert( is(PropertyType!(overloads[0]) == int));
                static assert( is(typeof(overloads[0]) == PropertyType!(overloads[0])));

                static assert( is(SymbolType!(overloads[1]) == ToFunctionType!(void function(int) @property)));
                static assert(!__traits(compiles, PropertyType!(overloads[1])));
                static assert(!__traits(compiles, typeof(overloads[1])));
            }

            // Actually on I, not C1.
            // static @property string staticProp();
            // static @property void staticProp(real);
            {
                static assert( is(SymbolType!(C1.staticProp) == ToFunctionType!(string function() @property)));
                static assert( is(PropertyType!(C1.staticProp) == string));
                static assert( is(typeof(C1.staticProp) == PropertyType!(C1.staticProp)));

                alias overloads = __traits(getOverloads, C1, "staticProp");
                static assert(overloads.length == 2);

                static assert( is(SymbolType!(overloads[0]) == ToFunctionType!(string function() @property)));
                static assert( is(PropertyType!(overloads[0]) == string));
                static assert( is(typeof(overloads[0]) == PropertyType!(overloads[0])));

                static assert( is(SymbolType!(overloads[1]) == ToFunctionType!(void function(real) @property)));
                static assert(!__traits(compiles, PropertyType!(overloads[1])));
                static assert(!__traits(compiles, typeof(overloads[1])));
            }

            // override @property void extraProp(string);
            // @property bool extraProp() { return true; }
            {
                static assert( is(SymbolType!(C1.extraProp) == ToFunctionType!(void function(string) @property)));
                static assert( is(PropertyType!(C1.extraProp) == bool));
                static assert( is(typeof(C1.extraProp) == bool));

                alias overloads = __traits(getOverloads, C1, "extraProp");
                static assert(overloads.length == 2);

                static assert( is(SymbolType!(overloads[0]) == ToFunctionType!(void function(string) @property)));
                static assert(!__traits(compiles, PropertyType!(overloads[0])));
                static assert(!__traits(compiles, typeof(overloads[0])));

                static assert( is(SymbolType!(overloads[1]) == ToFunctionType!(bool function() @property)));
                static assert( is(PropertyType!(overloads[1]) == bool));
                static assert( is(typeof(overloads[1]) == bool));
            }

            // override int defaultArg1(string str = "foo");
            // override void defaultArg1(int, string str = "foo");
            {
                static assert( is(SymbolType!(C1.defaultArg1) == ToFunctionType!(int function(string))));
                static assert( is(PropertyType!(C1.defaultArg1) == int));
                static assert( is(typeof(C1.defaultArg1) == SymbolType!(C1.defaultArg1)));

                alias overloads = __traits(getOverloads, C1, "defaultArg1");
                static assert(overloads.length == 2);

                static assert( is(SymbolType!(overloads[0]) == ToFunctionType!(int function(string))));
                static assert( is(PropertyType!(overloads[0]) == int));
                static assert( is(typeof(overloads[0]) == SymbolType!(overloads[0])));

                static assert( is(SymbolType!(overloads[1]) == ToFunctionType!(void function(int, string))));
                static assert(!__traits(compiles, PropertyType!(overloads[1])));
                static assert( is(typeof(overloads[1]) == SymbolType!(overloads[1])));
            }

            // I provides default arguments, but C1 does not.
            // override void defaultArg2(int, string);
            // override int defaultArg2(string);
            {
                static assert( is(SymbolType!(C1.defaultArg2) == ToFunctionType!(void function(int, string))));
                static assert(!__traits(compiles, PropertyType!(C1.defaultArg2)));
                static assert( is(typeof(C1.defaultArg2) == SymbolType!(C1.defaultArg2)));

                alias overloads = __traits(getOverloads, C1, "defaultArg2");
                static assert(overloads.length == 2);

                static assert( is(SymbolType!(overloads[0]) == ToFunctionType!(void function(int, string))));
                static assert(!__traits(compiles, PropertyType!(overloads[0])));
                static assert( is(typeof(overloads[0]) == SymbolType!(overloads[0])));

                static assert( is(SymbolType!(overloads[1]) == ToFunctionType!(int function(string))));
                static assert(!__traits(compiles, PropertyType!(overloads[1])));
                static assert( is(typeof(overloads[1]) == SymbolType!(overloads[1])));
            }

            // override @property int defaultArgProp1(string str = "foo");
            // override @property void defaultArgProp1(int, string str = "foo");
            {
                static assert( is(SymbolType!(C1.defaultArgProp1) == ToFunctionType!(int function(string) @property)));
                static assert( is(PropertyType!(C1.defaultArgProp1) == int));
                static assert( is(typeof(C1.defaultArgProp1) == PropertyType!(C1.defaultArgProp1)));

                alias overloads = __traits(getOverloads, C1, "defaultArgProp1");
                static assert(overloads.length == 2);

                static assert( is(SymbolType!(overloads[0]) == ToFunctionType!(int function(string) @property)));
                static assert( is(PropertyType!(overloads[0]) == int));
                static assert( is(typeof(overloads[0]) == PropertyType!(overloads[0])));

                static assert( is(SymbolType!(overloads[1]) == ToFunctionType!(void function(int, string) @property)));
                static assert(!__traits(compiles, PropertyType!(overloads[1])));
                static assert(!__traits(compiles, typeof(overloads[1])));
            }

            // I provides default arguments, but C1 does not.
            // override @property void defaultArgProp2(int, string str);
            // override @property int defaultArgProp2(string str);
            {
                static assert( is(SymbolType!(C1.defaultArgProp2) ==
                                  ToFunctionType!(void function(int, string) @property)));
                static assert(!__traits(compiles, PropertyType!(C1.defaultArgProp2)));
                static assert(!__traits(compiles, typeof(C1.defaultArgProp2)));

                alias overloads = __traits(getOverloads, C1, "defaultArgProp2");
                static assert(overloads.length == 2);

                static assert( is(SymbolType!(overloads[0]) == ToFunctionType!(void function(int, string) @property)));
                static assert(!__traits(compiles, PropertyType!(overloads[0])));
                static assert(!__traits(compiles, typeof(overloads[0])));

                static assert( is(SymbolType!(overloads[1]) == ToFunctionType!(int function(string) @property)));
                static assert(!__traits(compiles, PropertyType!(overloads[1])));
                static assert(!__traits(compiles, typeof(overloads[1])));
            }

            // I does not provide default arguments, but C1 does.
            // override string defaultArgInDerived1(int i = 0);
            // override void defaultArgInDerived1(string, int i = 0);
            {
                static assert( is(SymbolType!(C1.defaultArgInDerived1) == ToFunctionType!(string function(int))));
                static assert( is(PropertyType!(C1.defaultArgInDerived1) == string));
                static assert( is(typeof(C1.defaultArgInDerived1) == SymbolType!(C1.defaultArgInDerived1)));

                alias overloads = __traits(getOverloads, C1, "defaultArgInDerived1");
                static assert(overloads.length == 2);

                static assert( is(SymbolType!(overloads[0]) == ToFunctionType!(string function(int))));
                static assert( is(PropertyType!(overloads[0]) == string));
                static assert( is(typeof(overloads[0]) == SymbolType!(overloads[0])));

                static assert( is(SymbolType!(overloads[1]) == ToFunctionType!(void function(string, int))));
                static assert(!__traits(compiles, PropertyType!(overloads[1])));
                static assert( is(typeof(overloads[1]) == SymbolType!(overloads[1])));
            }

            // I does not provide default arguments, but C1 does.
            // override void defaultArgInDerived2(string, int i = 0);
            // override string defaultArgInDerived2(int i = 0);
            {
                static assert( is(SymbolType!(C1.defaultArgInDerived2) == ToFunctionType!(void function(string, int))));
                static assert( is(PropertyType!(C1.defaultArgInDerived2) == string));
                static assert( is(typeof(C1.defaultArgInDerived2) == SymbolType!(C1.defaultArgInDerived2)));

                alias overloads = __traits(getOverloads, C1, "defaultArgInDerived2");
                static assert(overloads.length == 2);

                static assert( is(SymbolType!(overloads[0]) == ToFunctionType!(void function(string, int))));
                static assert(!__traits(compiles, PropertyType!(overloads[0])));
                static assert( is(typeof(overloads[0]) == SymbolType!(overloads[0])));

                static assert( is(SymbolType!(overloads[1]) == ToFunctionType!(string function(int))));
                static assert( is(PropertyType!(overloads[1]) == string));
                static assert( is(typeof(overloads[1]) == SymbolType!(overloads[1])));
            }

            // I does not provide default arguments, but C1 does.
            // override @property string defaultArgInDerivedProp1(int i = 0);
            // override @property void defaultArgInDerivedProp1(string, int i = 0);
            {
                static assert( is(SymbolType!(C1.defaultArgInDerivedProp1) ==
                                  ToFunctionType!(string function(int) @property)));
                static assert( is(PropertyType!(C1.defaultArgInDerivedProp1) == string));
                static assert( is(typeof(C1.defaultArgInDerivedProp1) == string));

                alias overloads = __traits(getOverloads, C1, "defaultArgInDerivedProp1");
                static assert(overloads.length == 2);

                static assert( is(SymbolType!(overloads[0]) == ToFunctionType!(string function(int) @property)));
                static assert( is(PropertyType!(overloads[0]) == string));
                static assert( is(typeof(overloads[0]) == string));

                static assert( is(SymbolType!(overloads[1]) == ToFunctionType!(void function(string, int) @property)));
                static assert(!__traits(compiles, PropertyType!(overloads[1])));
                static assert(!__traits(compiles, typeof(overloads[1])));
            }

            // I does not provide default arguments, but C1 does.
            // override @property void defaultArgInDerivedProp2(string, int i = 0);
            // override @property string defaultArgInDerivedProp2(int i = 0);
            {
                static assert( is(SymbolType!(C1.defaultArgInDerivedProp2) ==
                                  ToFunctionType!(void function(string, int) @property)));
                static assert( is(PropertyType!(C1.defaultArgInDerivedProp2) == string));
                static assert( is(typeof(C1.defaultArgInDerivedProp2) == string));

                alias overloads = __traits(getOverloads, C1, "defaultArgInDerivedProp2");
                static assert(overloads.length == 2);

                static assert( is(SymbolType!(overloads[0]) == ToFunctionType!(void function(string, int) @property)));
                static assert(!__traits(compiles, PropertyType!(overloads[0])));
                static assert(!__traits(compiles, typeof(overloads[0])));

                static assert( is(SymbolType!(overloads[1]) == ToFunctionType!(string function(int) @property)));
                static assert( is(PropertyType!(overloads[1]) == string));
                static assert( is(typeof(overloads[1]) == string));
            }
        }

        // Changes the function order (and has different extraProps).
        // It also provides default arguments when C1 does not.
        static class C2 : I
        {
            real r;
            bool b;
            int* ptr;

            @property long extraProp() { return 42; }
            override @property void extraProp(string) {}
            @property void extraProp(int) {}

            override void foo() {}

            @property string defaultArgInDerivedProp2(int i = 0) { return "dlang"; }
            @property void defaultArgInDerivedProp2(string, int i = 0) {}

            string defaultArgInDerived2(int i = 0) { return "dlang"; }
            void defaultArgInDerived2(string, int i = 0) {}

            void defaultArgInDerived1(string, int i = 0) {}
            string defaultArgInDerived1(int i = 0) { return "dlang"; }

            @property void defaultArgInDerivedProp1(string, int i = 0) {}
            @property string defaultArgInDerivedProp1(int i = 0) { return "dlang"; }

            override void defaultArg2(int, string str = "bar") {}
            override int defaultArg2(string str = "bar") { return 0; }

            override @property int defaultArgProp2(string str = "bar") { return 0; }
            override @property void defaultArgProp2(int, string str = "bar") {}

            override @property void defaultArgProp1(int, string str = "bar") {}
            override @property int defaultArgProp1(string str = "bar") { return 0; }

            override void defaultArg1(int, string str = "bar") {}
            override int defaultArg1(string str = "bar") { return 0; }

            override @property void prop2(int) {}
            override @property int prop2() { return 0; }

            override @property void prop1(int) {}
            override @property int prop1() { return 0; }

            override void func2(int) {}
            override int func2() { return 0; }

            override int func1() { return 0; }
            override void func1(int) {}
        }

        {
            // real r;
            // bool b;
            // int* ptr;

            static assert( is(SymbolType!(C2.r) == real));
            static assert( is(PropertyType!(C2.r) == real));
            static assert( is(typeof(C2.r) == real));

            static assert( is(SymbolType!(C2.b) == bool));
            static assert( is(PropertyType!(C2.b) == bool));
            static assert( is(typeof(C2.b) == bool));

            static assert( is(SymbolType!(C2.ptr) == int*));
            static assert( is(PropertyType!(C2.ptr) == int*));
            static assert( is(typeof(C2.ptr) == int*));

            // Actually on I, not C2.
            // static @property string staticProp();
            // static @property void staticProp(real);
            {
                static assert( is(SymbolType!(C2.staticProp) == ToFunctionType!(string function() @property)));
                static assert( is(PropertyType!(C2.staticProp) == string));
                static assert( is(typeof(C2.staticProp) == PropertyType!(C2.staticProp)));

                alias overloads = __traits(getOverloads, C2, "staticProp");
                static assert(overloads.length == 2);

                static assert( is(SymbolType!(overloads[0]) == ToFunctionType!(string function() @property)));
                static assert( is(PropertyType!(overloads[0]) == string));
                static assert( is(typeof(overloads[0]) == PropertyType!(overloads[0])));

                static assert( is(SymbolType!(overloads[1]) == ToFunctionType!(void function(real) @property)));
                static assert(!__traits(compiles, PropertyType!(overloads[1])));
                static assert(!__traits(compiles, typeof(overloads[1])));
            }

            // @property long extraProp() { return 42; }
            // override @property void extraProp(string) {}
            // @property void extraProp(int) {}
            {
                static assert( is(SymbolType!(C2.extraProp) == ToFunctionType!(long function() @property)));
                static assert( is(PropertyType!(C2.extraProp) == long));
                static assert( is(typeof(C2.extraProp) == long));

                alias overloads = __traits(getOverloads, C2, "extraProp");
                static assert(overloads.length == 3);

                static assert( is(SymbolType!(overloads[0]) == ToFunctionType!(long function() @property)));
                static assert( is(PropertyType!(overloads[0]) == long));
                static assert( is(typeof(overloads[0]) == long));

                static assert( is(SymbolType!(overloads[1]) == ToFunctionType!(void function(string) @property)));
                static assert(!__traits(compiles, PropertyType!(overloads[1])));
                static assert(!__traits(compiles, typeof(overloads[1])));

                static assert( is(SymbolType!(overloads[2]) == ToFunctionType!(void function(int) @property)));
                static assert(!__traits(compiles, PropertyType!(overloads[2])));
                static assert(!__traits(compiles, typeof(overloads[2])));
            }

            // override void foo()
            static assert( is(SymbolType!(C2.foo) == ToFunctionType!(void function())));
            static assert(!__traits(compiles, PropertyType!(C2.foo)));
            static assert( is(typeof(C2.foo) == SymbolType!(C2.foo)));

            // I does not provide default arguments, but C2 does.
            // @property string defaultArgInDerivedProp2(int i = 0);
            // @property void defaultArgInDerivedProp2(string, int i = 0);
            {
                static assert( is(SymbolType!(C2.defaultArgInDerivedProp2) ==
                                  ToFunctionType!(string function(int) @property)));
                static assert( is(PropertyType!(C2.defaultArgInDerivedProp2) == string));
                static assert( is(typeof(C2.defaultArgInDerivedProp2) == string));

                alias overloads = __traits(getOverloads, C2, "defaultArgInDerivedProp2");
                static assert(overloads.length == 2);

                static assert( is(SymbolType!(overloads[0]) == ToFunctionType!(string function(int) @property)));
                static assert( is(PropertyType!(overloads[0]) == string));
                static assert( is(typeof(overloads[0]) == string));

                static assert( is(SymbolType!(overloads[1]) == ToFunctionType!(void function(string, int) @property)));
                static assert(!__traits(compiles, PropertyType!(overloads[1])));
                static assert(!__traits(compiles, typeof(overloads[1])));
            }

            // I does not provide default arguments, but C2 does.
            // string defaultArgInDerived2(int i = 0);
            // void defaultArgInDerived2(string, int i = 0);
            {
                static assert( is(SymbolType!(C2.defaultArgInDerived2) == ToFunctionType!(string function(int))));
                static assert( is(PropertyType!(C2.defaultArgInDerived2) == string));
                static assert( is(typeof(C2.defaultArgInDerived2) == SymbolType!(C2.defaultArgInDerived2)));

                alias overloads = __traits(getOverloads, C2, "defaultArgInDerived2");
                static assert(overloads.length == 2);

                static assert( is(SymbolType!(overloads[0]) == ToFunctionType!(string function(int))));
                static assert( is(PropertyType!(overloads[0]) == string));
                static assert( is(typeof(overloads[0]) == SymbolType!(overloads[0])));

                static assert( is(SymbolType!(overloads[1]) == ToFunctionType!(void function(string, int))));
                static assert(!__traits(compiles, PropertyType!(overloads[1])));
                static assert( is(typeof(overloads[1]) == SymbolType!(overloads[1])));
            }

            // I does not provide default arguments, but C2 does.
            // void defaultArgInDerived1(string, int i = 0);
            // string defaultArgInDerived1(int i = 0);
            {
                static assert( is(SymbolType!(C2.defaultArgInDerived1) == ToFunctionType!(void function(string, int))));
                static assert( is(PropertyType!(C2.defaultArgInDerived1) == string));
                static assert( is(typeof(C2.defaultArgInDerived1) == SymbolType!(C2.defaultArgInDerived1)));

                alias overloads = __traits(getOverloads, C2, "defaultArgInDerived1");
                static assert(overloads.length == 2);

                static assert( is(SymbolType!(overloads[0]) == ToFunctionType!(void function(string, int))));
                static assert(!__traits(compiles, PropertyType!(overloads[0])));
                static assert( is(typeof(overloads[0]) == SymbolType!(overloads[0])));

                static assert( is(SymbolType!(overloads[1]) == ToFunctionType!(string function(int))));
                static assert( is(PropertyType!(overloads[1]) == string));
                static assert( is(typeof(overloads[1]) == SymbolType!(overloads[1])));
            }

            // I does not provide default arguments, but C2 does.
            // @property void defaultArgInDerivedProp1(string, int i = 0);
            // @property string defaultArgInDerivedProp1(int i = 0);
            {
                static assert( is(SymbolType!(C2.defaultArgInDerivedProp1) ==
                                  ToFunctionType!(void function(string, int) @property)));
                static assert( is(PropertyType!(C2.defaultArgInDerivedProp1) == string));
                static assert( is(typeof(C2.defaultArgInDerivedProp1) == string));

                alias overloads = __traits(getOverloads, C2, "defaultArgInDerivedProp1");
                static assert(overloads.length == 2);

                static assert( is(SymbolType!(overloads[0]) == ToFunctionType!(void function(string, int) @property)));
                static assert(!__traits(compiles, PropertyType!(overloads[0])));
                static assert(!__traits(compiles, typeof(overloads[0])));

                static assert( is(SymbolType!(overloads[1]) == ToFunctionType!(string function(int) @property)));
                static assert( is(PropertyType!(overloads[1]) == string));
                static assert( is(typeof(overloads[1]) == string));
            }

            // override void defaultArg2(int, string str = "bar");
            // override int defaultArg2(string str = "bar");
            {
                static assert( is(SymbolType!(C2.defaultArg2) == ToFunctionType!(void function(int, string))));
                static assert( is(PropertyType!(C2.defaultArg2) == int));
                static assert( is(typeof(C2.defaultArg2) == SymbolType!(C2.defaultArg2)));

                alias overloads = __traits(getOverloads, C2, "defaultArg2");
                static assert(overloads.length == 2);

                static assert( is(SymbolType!(overloads[0]) == ToFunctionType!(void function(int, string))));
                static assert(!__traits(compiles, PropertyType!(overloads[0])));
                static assert( is(typeof(overloads[0]) == SymbolType!(overloads[0])));

                static assert( is(SymbolType!(overloads[1]) == ToFunctionType!(int function(string))));
                static assert( is(PropertyType!(overloads[1]) == int));
                static assert( is(typeof(overloads[1]) == SymbolType!(overloads[1])));
            }

            // override @property int defaultArgProp2(string str = "bar");
            // override @property void defaultArgProp2(int, string str = "bar");
            {
                static assert( is(SymbolType!(C2.defaultArgProp2) ==
                                  ToFunctionType!(int function(string) @property)));
                static assert( is(PropertyType!(C2.defaultArgProp2) == int));
                static assert( is(typeof(C2.defaultArgProp2) == PropertyType!(C2.defaultArgProp2)));

                alias overloads = __traits(getOverloads, C2, "defaultArgProp2");
                static assert(overloads.length == 2);

                static assert( is(SymbolType!(overloads[0]) == ToFunctionType!(int function(string) @property)));
                static assert( is(PropertyType!(overloads[0]) == int));
                static assert( is(typeof(overloads[0]) == PropertyType!(overloads[0])));

                static assert( is(SymbolType!(overloads[1]) == ToFunctionType!(void function(int, string) @property)));
                static assert(!__traits(compiles, PropertyType!(overloads[1])));
                static assert(!__traits(compiles, typeof(overloads[1])));
            }

            // override @property void defaultArgProp1(int, string str = "bar");
            // override @property int defaultArgProp1(string str = "bar");
            {

                static assert( is(SymbolType!(C2.defaultArgProp1) ==
                                  ToFunctionType!(void function(int, string) @property)));
                static assert( is(PropertyType!(C2.defaultArgProp1) == int));
                static assert( is(typeof(C2.defaultArgProp1) == PropertyType!(C2.defaultArgProp1)));

                alias overloads = __traits(getOverloads, C2, "defaultArgProp1");
                static assert(overloads.length == 2);

                static assert( is(SymbolType!(overloads[0]) == ToFunctionType!(void function(int, string) @property)));
                static assert(!__traits(compiles, PropertyType!(overloads[0])));
                static assert(!__traits(compiles, typeof(overloads[0])));

                static assert( is(SymbolType!(overloads[1]) == ToFunctionType!(int function(string) @property)));
                static assert( is(PropertyType!(overloads[1]) == int));
                static assert( is(typeof(overloads[1]) == PropertyType!(overloads[1])));
            }

            // override void defaultArg1(int, string str = "bar");
            // override int defaultArg1(string str = "bar");
            {
                static assert( is(SymbolType!(C2.defaultArg1) == ToFunctionType!(void function(int, string))));
                static assert( is(PropertyType!(C2.defaultArg1) == int));
                static assert( is(typeof(C2.defaultArg1) == SymbolType!(C2.defaultArg1)));

                alias overloads = __traits(getOverloads, C2, "defaultArg1");
                static assert(overloads.length == 2);

                static assert( is(SymbolType!(overloads[0]) == ToFunctionType!(void function(int, string))));
                static assert(!__traits(compiles, PropertyType!(overloads[0])));
                static assert( is(typeof(overloads[0]) == SymbolType!(overloads[0])));

                static assert( is(SymbolType!(overloads[1]) == ToFunctionType!(int function(string))));
                static assert( is(PropertyType!(overloads[1]) == int));
                static assert( is(typeof(overloads[1]) == SymbolType!(overloads[1])));
            }

            // override @property void prop2(int);
            // override @property int prop2();
            {
                static assert( is(SymbolType!(C2.prop2) == ToFunctionType!(void function(int) @property)));
                static assert( is(PropertyType!(C2.prop2) == int));
                static assert( is(typeof(C2.prop2) == PropertyType!(C2.prop2)));

                alias overloads = __traits(getOverloads, C2, "prop2");
                static assert(overloads.length == 2);

                static assert( is(SymbolType!(overloads[0]) == ToFunctionType!(void function(int) @property)));
                static assert(!__traits(compiles, PropertyType!(overloads[0])));
                static assert(!__traits(compiles, typeof(overloads[0])));

                static assert( is(SymbolType!(overloads[1]) == ToFunctionType!(int function() @property)));
                static assert( is(PropertyType!(overloads[1]) == int));
                static assert( is(typeof(overloads[1]) == PropertyType!(overloads[1])));
            }

            // override @property void prop1(int);
            // override @property int prop1();
            {
                static assert( is(SymbolType!(C2.prop1) == ToFunctionType!(void function(int) @property)));
                static assert( is(PropertyType!(C2.prop1) == int));
                static assert( is(typeof(C2.prop1) == PropertyType!(C2.prop1)));

                alias overloads = __traits(getOverloads, C2, "prop1");
                static assert(overloads.length == 2);

                static assert( is(SymbolType!(overloads[0]) == ToFunctionType!(void function(int) @property)));
                static assert(!__traits(compiles, PropertyType!(overloads[0])));
                static assert(!__traits(compiles, typeof(overloads[0])));

                static assert( is(SymbolType!(overloads[1]) == ToFunctionType!(int function() @property)));
                static assert( is(PropertyType!(overloads[1]) == int));
                static assert( is(typeof(overloads[1]) == PropertyType!(overloads[1])));
            }

            // override void func2(int);
            // override int func2();
            {
                static assert( is(SymbolType!(C2.func2) == ToFunctionType!(void function(int))));
                static assert( is(PropertyType!(C2.func2) == int));
                static assert( is(typeof(C2.func2) == SymbolType!(C2.func2)));

                alias overloads = __traits(getOverloads, C2, "func2");
                static assert(overloads.length == 2);

                static assert( is(SymbolType!(overloads[0]) == ToFunctionType!(void function(int))));
                static assert(!__traits(compiles, PropertyType!(overloads[0])));
                static assert( is(typeof(overloads[0]) == SymbolType!(overloads[0])));

                static assert( is(SymbolType!(overloads[1]) == ToFunctionType!(int function())));
                static assert( is(PropertyType!(overloads[1]) == int));
                static assert( is(typeof(overloads[1]) == SymbolType!(overloads[1])));
            }

            // override int func1();
            // override void func1(int);
            {
                static assert( is(SymbolType!(C2.func1) == ToFunctionType!(int function())));
                static assert( is(PropertyType!(C2.func1) == int));
                static assert( is(typeof(C2.func1) == SymbolType!(C2.func1)));

                alias overloads = __traits(getOverloads, C2, "func1");
                static assert(overloads.length == 2);

                static assert( is(SymbolType!(overloads[0]) == ToFunctionType!(int function())));
                static assert( is(PropertyType!(overloads[0]) == int));
                static assert( is(typeof(overloads[0]) == SymbolType!(overloads[0])));

                static assert( is(SymbolType!(overloads[1]) == ToFunctionType!(void function(int))));
                static assert(!__traits(compiles, PropertyType!(overloads[1])));
                static assert( is(typeof(overloads[1]) == SymbolType!(overloads[1])));
            }
        }

        static class C3 : C2
        {
            const(short)* ptr;
        }

        {
            // real r; (from C2)
            // bool b; (from C2)
            // const(short)* ptr; (shadows C2.ptr)
            static assert( is(SymbolType!(C3.r) == real));
            static assert( is(PropertyType!(C3.r) == real));
            static assert( is(typeof(C3.r) == real));

            static assert( is(SymbolType!(C3.b) == bool));
            static assert( is(PropertyType!(C3.b) == bool));
            static assert( is(typeof(C3.b) == bool));

            static assert( is(SymbolType!(C3.ptr) == const(short)*));
            static assert( is(PropertyType!(C3.ptr) == const(short)*));
            static assert( is(typeof(C3.ptr) == const(short)*));

            // Actually on I, not C3.
            // static @property string staticProp();
            // static @property void staticProp(real);
            {
                static assert( is(SymbolType!(C3.staticProp) == ToFunctionType!(string function() @property)));
                static assert( is(PropertyType!(C3.staticProp) == string));
                static assert( is(typeof(C3.staticProp) == PropertyType!(C3.staticProp)));

                alias overloads = __traits(getOverloads, C3, "staticProp");
                static assert(overloads.length == 2);

                static assert( is(SymbolType!(overloads[0]) == ToFunctionType!(string function() @property)));
                static assert( is(PropertyType!(overloads[0]) == string));
                static assert( is(typeof(overloads[0]) == PropertyType!(overloads[0])));

                static assert( is(SymbolType!(overloads[1]) == ToFunctionType!(void function(real) @property)));
                static assert(!__traits(compiles, PropertyType!(overloads[1])));
                static assert(!__traits(compiles, typeof(overloads[1])));
            }

            // @property long extraProp() { return 42; }
            // override @property void extraProp(string) {}
            // @property void extraProp(int) {}
            {
                static assert( is(SymbolType!(C3.extraProp) == ToFunctionType!(long function() @property)));
                static assert( is(PropertyType!(C3.extraProp) == long));
                static assert( is(typeof(C3.extraProp) == long));

                alias overloads = __traits(getOverloads, C3, "extraProp");
                static assert(overloads.length == 3);

                static assert( is(SymbolType!(overloads[0]) == ToFunctionType!(long function() @property)));
                static assert( is(PropertyType!(overloads[0]) == long));
                static assert( is(typeof(overloads[0]) == long));

                static assert( is(SymbolType!(overloads[1]) == ToFunctionType!(void function(string) @property)));
                static assert(!__traits(compiles, PropertyType!(overloads[1])));
                static assert(!__traits(compiles, typeof(overloads[1])));

                static assert( is(SymbolType!(overloads[2]) == ToFunctionType!(void function(int) @property)));
                static assert(!__traits(compiles, PropertyType!(overloads[2])));
                static assert(!__traits(compiles, typeof(overloads[2])));
            }

            // override void foo()
            static assert( is(SymbolType!(C3.foo) == ToFunctionType!(void function())));
            static assert(!__traits(compiles, PropertyType!(C3.foo)));
            static assert( is(typeof(C3.foo) == SymbolType!(C3.foo)));

            // I does not provide default arguments, but C2 does.
            // @property string defaultArgInDerivedProp2(int i = 0);
            // @property void defaultArgInDerivedProp2(string, int i = 0);
            {
                static assert( is(SymbolType!(C3.defaultArgInDerivedProp2) ==
                                  ToFunctionType!(string function(int) @property)));
                static assert( is(PropertyType!(C3.defaultArgInDerivedProp2) == string));
                static assert( is(typeof(C3.defaultArgInDerivedProp2) == string));

                alias overloads = __traits(getOverloads, C3, "defaultArgInDerivedProp2");
                static assert(overloads.length == 2);

                static assert( is(SymbolType!(overloads[0]) == ToFunctionType!(string function(int) @property)));
                static assert( is(PropertyType!(overloads[0]) == string));
                static assert( is(typeof(overloads[0]) == string));

                static assert( is(SymbolType!(overloads[1]) == ToFunctionType!(void function(string, int) @property)));
                static assert(!__traits(compiles, PropertyType!(overloads[1])));
                static assert(!__traits(compiles, typeof(overloads[1])));
            }

            // I does not provide default arguments, but C2 does.
            // string defaultArgInDerived2(int i = 0);
            // void defaultArgInDerived2(string, int i = 0);
            {
                static assert( is(SymbolType!(C3.defaultArgInDerived2) == ToFunctionType!(string function(int))));
                static assert( is(PropertyType!(C3.defaultArgInDerived2) == string));
                static assert( is(typeof(C3.defaultArgInDerived2) == SymbolType!(C3.defaultArgInDerived2)));

                alias overloads = __traits(getOverloads, C3, "defaultArgInDerived2");
                static assert(overloads.length == 2);

                static assert( is(SymbolType!(overloads[0]) == ToFunctionType!(string function(int))));
                static assert( is(PropertyType!(overloads[0]) == string));
                static assert( is(typeof(overloads[0]) == SymbolType!(overloads[0])));

                static assert( is(SymbolType!(overloads[1]) == ToFunctionType!(void function(string, int))));
                static assert(!__traits(compiles, PropertyType!(overloads[1])));
                static assert( is(typeof(overloads[1]) == SymbolType!(overloads[1])));
            }

            // I does not provide default arguments, but C2 does.
            // void defaultArgInDerived1(string, int i = 0);
            // string defaultArgInDerived1(int i = 0);
            {
                static assert( is(SymbolType!(C3.defaultArgInDerived1) == ToFunctionType!(void function(string, int))));
                static assert( is(PropertyType!(C3.defaultArgInDerived1) == string));
                static assert( is(typeof(C3.defaultArgInDerived1) == SymbolType!(C3.defaultArgInDerived1)));

                alias overloads = __traits(getOverloads, C3, "defaultArgInDerived1");
                static assert(overloads.length == 2);

                static assert( is(SymbolType!(overloads[0]) == ToFunctionType!(void function(string, int))));
                static assert(!__traits(compiles, PropertyType!(overloads[0])));
                static assert( is(typeof(overloads[0]) == SymbolType!(overloads[0])));

                static assert( is(SymbolType!(overloads[1]) == ToFunctionType!(string function(int))));
                static assert( is(PropertyType!(overloads[1]) == string));
                static assert( is(typeof(overloads[1]) == SymbolType!(overloads[1])));
            }

            // I does not provide default arguments, but C2 does.
            // @property void defaultArgInDerivedProp1(string, int i = 0);
            // @property string defaultArgInDerivedProp1(int i = 0);
            {
                static assert( is(SymbolType!(C3.defaultArgInDerivedProp1) ==
                                  ToFunctionType!(void function(string, int) @property)));
                static assert( is(PropertyType!(C3.defaultArgInDerivedProp1) == string));
                static assert( is(typeof(C3.defaultArgInDerivedProp1) == string));

                alias overloads = __traits(getOverloads, C3, "defaultArgInDerivedProp1");
                static assert(overloads.length == 2);

                static assert( is(SymbolType!(overloads[0]) == ToFunctionType!(void function(string, int) @property)));
                static assert(!__traits(compiles, PropertyType!(overloads[0])));
                static assert(!__traits(compiles, typeof(overloads[0])));

                static assert( is(SymbolType!(overloads[1]) == ToFunctionType!(string function(int) @property)));
                static assert( is(PropertyType!(overloads[1]) == string));
                static assert( is(typeof(overloads[1]) == string));
            }

            // override void defaultArg2(int, string str = "bar");
            // override int defaultArg2(string str = "bar");
            {
                static assert( is(SymbolType!(C3.defaultArg2) == ToFunctionType!(void function(int, string))));
                static assert( is(PropertyType!(C3.defaultArg2) == int));
                static assert( is(typeof(C3.defaultArg2) == SymbolType!(C3.defaultArg2)));

                alias overloads = __traits(getOverloads, C3, "defaultArg2");
                static assert(overloads.length == 2);

                static assert( is(SymbolType!(overloads[0]) == ToFunctionType!(void function(int, string))));
                static assert(!__traits(compiles, PropertyType!(overloads[0])));
                static assert( is(typeof(overloads[0]) == SymbolType!(overloads[0])));

                static assert( is(SymbolType!(overloads[1]) == ToFunctionType!(int function(string))));
                static assert( is(PropertyType!(overloads[1]) == int));
                static assert( is(typeof(overloads[1]) == SymbolType!(overloads[1])));
            }

            // override @property int defaultArgProp2(string str = "bar");
            // override @property void defaultArgProp2(int, string str = "bar");
            {
                static assert( is(SymbolType!(C3.defaultArgProp2) ==
                                  ToFunctionType!(int function(string) @property)));
                static assert( is(PropertyType!(C3.defaultArgProp2) == int));
                static assert( is(typeof(C3.defaultArgProp2) == PropertyType!(C3.defaultArgProp2)));

                alias overloads = __traits(getOverloads, C3, "defaultArgProp2");
                static assert(overloads.length == 2);

                static assert( is(SymbolType!(overloads[0]) == ToFunctionType!(int function(string) @property)));
                static assert( is(PropertyType!(overloads[0]) == int));
                static assert( is(typeof(overloads[0]) == PropertyType!(overloads[0])));

                static assert( is(SymbolType!(overloads[1]) == ToFunctionType!(void function(int, string) @property)));
                static assert(!__traits(compiles, PropertyType!(overloads[1])));
                static assert(!__traits(compiles, typeof(overloads[1])));
            }

            // override @property void defaultArgProp1(int, string str = "bar");
            // override @property int defaultArgProp1(string str = "bar");
            {

                static assert( is(SymbolType!(C3.defaultArgProp1) ==
                                  ToFunctionType!(void function(int, string) @property)));
                static assert( is(PropertyType!(C3.defaultArgProp1) == int));
                static assert( is(typeof(C3.defaultArgProp1) == PropertyType!(C3.defaultArgProp1)));

                alias overloads = __traits(getOverloads, C3, "defaultArgProp1");
                static assert(overloads.length == 2);

                static assert( is(SymbolType!(overloads[0]) == ToFunctionType!(void function(int, string) @property)));
                static assert(!__traits(compiles, PropertyType!(overloads[0])));
                static assert(!__traits(compiles, typeof(overloads[0])));

                static assert( is(SymbolType!(overloads[1]) == ToFunctionType!(int function(string) @property)));
                static assert( is(PropertyType!(overloads[1]) == int));
                static assert( is(typeof(overloads[1]) == PropertyType!(overloads[1])));
            }

            // override void defaultArg1(int, string str = "bar");
            // override int defaultArg1(string str = "bar");
            {
                static assert( is(SymbolType!(C3.defaultArg1) == ToFunctionType!(void function(int, string))));
                static assert( is(PropertyType!(C3.defaultArg1) == int));
                static assert( is(typeof(C3.defaultArg1) == SymbolType!(C3.defaultArg1)));

                alias overloads = __traits(getOverloads, C3, "defaultArg1");
                static assert(overloads.length == 2);

                static assert( is(SymbolType!(overloads[0]) == ToFunctionType!(void function(int, string))));
                static assert(!__traits(compiles, PropertyType!(overloads[0])));
                static assert( is(typeof(overloads[0]) == SymbolType!(overloads[0])));

                static assert( is(SymbolType!(overloads[1]) == ToFunctionType!(int function(string))));
                static assert( is(PropertyType!(overloads[1]) == int));
                static assert( is(typeof(overloads[1]) == SymbolType!(overloads[1])));
            }

            // override @property void prop2(int);
            // override @property int prop2();
            {
                static assert( is(SymbolType!(C3.prop2) == ToFunctionType!(void function(int) @property)));
                static assert( is(PropertyType!(C3.prop2) == int));
                static assert( is(typeof(C3.prop2) == PropertyType!(C3.prop2)));

                alias overloads = __traits(getOverloads, C3, "prop2");
                static assert(overloads.length == 2);

                static assert( is(SymbolType!(overloads[0]) == ToFunctionType!(void function(int) @property)));
                static assert(!__traits(compiles, PropertyType!(overloads[0])));
                static assert(!__traits(compiles, typeof(overloads[0])));

                static assert( is(SymbolType!(overloads[1]) == ToFunctionType!(int function() @property)));
                static assert( is(PropertyType!(overloads[1]) == int));
                static assert( is(typeof(overloads[1]) == PropertyType!(overloads[1])));
            }

            // override @property void prop1(int);
            // override @property int prop1();
            {
                static assert( is(SymbolType!(C3.prop1) == ToFunctionType!(void function(int) @property)));
                static assert( is(PropertyType!(C3.prop1) == int));
                static assert( is(typeof(C3.prop1) == PropertyType!(C3.prop1)));

                alias overloads = __traits(getOverloads, C3, "prop1");
                static assert(overloads.length == 2);

                static assert( is(SymbolType!(overloads[0]) == ToFunctionType!(void function(int) @property)));
                static assert(!__traits(compiles, PropertyType!(overloads[0])));
                static assert(!__traits(compiles, typeof(overloads[0])));

                static assert( is(SymbolType!(overloads[1]) == ToFunctionType!(int function() @property)));
                static assert( is(PropertyType!(overloads[1]) == int));
                static assert( is(typeof(overloads[1]) == PropertyType!(overloads[1])));
            }

            // override void func2(int);
            // override int func2();
            {
                static assert( is(SymbolType!(C3.func2) == ToFunctionType!(void function(int))));
                static assert( is(PropertyType!(C3.func2) == int));
                static assert( is(typeof(C3.func2) == SymbolType!(C3.func2)));

                alias overloads = __traits(getOverloads, C3, "func2");
                static assert(overloads.length == 2);

                static assert( is(SymbolType!(overloads[0]) == ToFunctionType!(void function(int))));
                static assert(!__traits(compiles, PropertyType!(overloads[0])));
                static assert( is(typeof(overloads[0]) == SymbolType!(overloads[0])));

                static assert( is(SymbolType!(overloads[1]) == ToFunctionType!(int function())));
                static assert( is(PropertyType!(overloads[1]) == int));
                static assert( is(typeof(overloads[1]) == SymbolType!(overloads[1])));
            }

            // override int func1();
            // override void func1(int);
            {
                static assert( is(SymbolType!(C3.func1) == ToFunctionType!(int function())));
                static assert( is(PropertyType!(C3.func1) == int));
                static assert( is(typeof(C3.func1) == SymbolType!(C3.func1)));

                alias overloads = __traits(getOverloads, C3, "func1");
                static assert(overloads.length == 2);

                static assert( is(SymbolType!(overloads[0]) == ToFunctionType!(int function())));
                static assert( is(PropertyType!(overloads[0]) == int));
                static assert( is(typeof(overloads[0]) == SymbolType!(overloads[0])));

                static assert( is(SymbolType!(overloads[1]) == ToFunctionType!(void function(int))));
                static assert(!__traits(compiles, PropertyType!(overloads[1])));
                static assert( is(typeof(overloads[1]) == SymbolType!(overloads[1])));
            }
        }
    }
}

// This is probably overkill, since it's arguably testing the compiler more
// than it's testing SymbolType or ToFunctionType, but with various tests
// either using inference for all attributes or not providing a body to avoid
// it entirely, it seemed prudent to add some tests where the attributes being
// inferred were better controlled, and it does help ensure that SymbolType
// and ToFunctionType behave as expected in each case.
@safe unittest
{
    static int var;

    // Since these are actually called below (even if those functions aren't
    // called) we can't play the trick of not providing a body to set all of
    // the attributes, because we get linker errors when the functions below
    // call these functions.
    static void useGC() @safe pure nothrow { new int; }
    static void throws() @safe pure @nogc { Exception e; throw e; }
    static void impure() @safe nothrow @nogc { ++var; }
    static void unsafe() @system pure nothrow @nogc { int i; int* ptr = &i; }

    {
        static void func() { useGC(); }
        static assert( is(typeof(func) == ToFunctionType!(void function() @safe pure nothrow)));
        static assert( is(SymbolType!func == ToFunctionType!(void function() @safe pure nothrow)));
    }
    {
        static void func() { throws(); }
        static assert( is(typeof(func) == ToFunctionType!(void function() @safe pure @nogc)));
        static assert( is(SymbolType!func == ToFunctionType!(void function() @safe pure @nogc)));
    }
    {
        static void func() { impure(); }
        static assert( is(typeof(func) == ToFunctionType!(void function() @safe nothrow @nogc)));
        static assert( is(SymbolType!func == ToFunctionType!(void function() @safe nothrow @nogc)));
    }
    {
        static void func() { unsafe(); }
        static assert( is(typeof(func) == ToFunctionType!(void function() @system pure nothrow @nogc)));

        // Doubling the test shouldn't be necessary, but since the order of the
        // attributes isn't supposed to matter, it seemed prudent to have at
        // least one test that used a different order.
        static assert( is(SymbolType!func == ToFunctionType!(void function() @system pure nothrow @nogc)));
        static assert( is(SymbolType!func == ToFunctionType!(void function() @nogc nothrow pure @system)));
    }
    {
        static void func() { useGC(); throws(); }
        static assert( is(typeof(func) == ToFunctionType!(void function() @safe pure)));
        static assert( is(SymbolType!func == ToFunctionType!(void function() @safe pure)));
    }
    {
        static void func() { throws(); impure(); }
        static assert( is(typeof(func) == ToFunctionType!(void function() @safe @nogc)));
        static assert( is(SymbolType!func == ToFunctionType!(void function() @safe @nogc)));
    }
    {
        static void func() { impure(); unsafe(); }
        static assert( is(typeof(func) == ToFunctionType!(void function() @system nothrow @nogc)));
        static assert( is(SymbolType!func == ToFunctionType!(void function() @system nothrow @nogc)));
    }
    {
        static void func() { useGC(); unsafe(); }
        static assert( is(typeof(func) == ToFunctionType!(void function() @system pure nothrow)));
        static assert( is(SymbolType!func == ToFunctionType!(void function() @system pure nothrow)));
    }
    {
        static void func() { useGC(); throws(); impure(); unsafe(); }
        static assert( is(typeof(func) == ToFunctionType!(void function() @system)));
        static assert( is(SymbolType!func == ToFunctionType!(void function() @system)));
    }
    {
        static void func() @trusted { useGC(); throws(); impure(); unsafe(); }
        static assert( is(typeof(func) == ToFunctionType!(void function() @trusted)));
        static assert( is(SymbolType!func == ToFunctionType!(void function() @trusted)));
    }
}

/++
    Removes the outer layer of $(D const), $(D inout), or $(D immutable)
    from type $(D T).

    If none of those qualifiers have been applied to the outer layer of
    type $(D T), then the result is $(D T).

    For the built-in scalar types (that is $(D bool), the character types, and
    the numeric types), they only have one layer, so $(D const U) simply becomes
    $(D U).

    Where the layers come in is pointers and arrays. $(D const(U*)) becomes
    $(D const(U)*), and $(D const(U[])), becomes $(D const(U)[]). So, a pointer
    goes from being fully $(D const) to being a mutable pointer to $(D const),
    and a dynamic array goes from being fully $(D const) to being a mutable
    dynamic array of $(D const) elements. And if there are multiple layers of
    pointers or arrays, it's just that outer layer which is affected - e.g.
    $(D const(U**)) would become $(D const(U*)*).

    For user-defined types, the effect is that $(D const U) becomes $(D U), and
    how that affects member variables depends on the type of the member
    variable. If a member variable is explicitly marked with any mutability
    qualifiers, then it will continue to have those qualifiers even after
    Unconst has stripped all mutability qualifiers from the containing type.
    However, if a mutability qualifier was on the member variable only because
    the containing type had that qualifier, then when Unconst removes the
    qualifier from the containing type, it is removed from the member variable
    as well.

    Also, Unconst has no effect on what a templated type is instantiated
    with, so if a templated type is instantiated with a template argument which
    has a mutability qualifier, the template instantiation will not change.
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
        const int* cPtr;
        shared int* sPtr;
    }

    const S s;
    static assert(is(typeof(s) == const S));
    static assert(is(typeof(typeof(s).ptr) == const int*));
    static assert(is(typeof(typeof(s).cPtr) == const int*));
    static assert(is(typeof(typeof(s).sPtr) == const shared int*));

    // For user-defined types, all mutability qualifiers that are applied to
    // member variables only because the containing type has them are removed,
    // but the ones that are directly on those member variables remain.

    // const S -> S
    static assert(is(Unconst!(typeof(s)) == S));
    static assert(is(typeof(Unconst!(typeof(s)).ptr) == int*));
    static assert(is(typeof(Unconst!(typeof(s)).cPtr) == const int*));
    static assert(is(typeof(Unconst!(typeof(s)).sPtr) == shared int*));

    static struct Foo(T)
    {
        T* ptr;
    }

    // The qualifier on the type is removed, but the qualifier on the template
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
    by Unshared. Only explicit $(D shared) is removed.

    For the built-in scalar types (that is $(D bool), the character types, and
    the numeric types), they only have one layer, so $(D shared U) simply
    becomes $(D U).

    Where the layers come in is pointers and arrays. $(D shared(U*)) becomes
    $(D shared(U)*), and $(D shared(U[])), becomes $(D shared(U)[]). So, a
    pointer goes from being fully $(D shared) to being a mutable pointer to
    $(D shared), and a dynamic array goes from being fully $(D shared) to being
    a mutable dynamic array of $(D shared) elements. And if there are multiple
    layers of pointers or arrays, it's just that outer layer which is affected
    - e.g. $(D shared(U**)) would become $(D shared(U*)*).

    For user-defined types, the effect is that $(D shared U) becomes $(D U),
    and how that affects member variables depends on the type of the member
    variable. If a member variable is explicitly marked with $(D shared), then
    it will continue to be $(D shared) even after Unshared has stripped
    $(D shared) from the containing type. However, if $(D shared) was on the
    member variable only because the containing type was $(D shared), then when
    Unshared removes the qualifier from the containing type, it is removed from
    the member variable as well.

    Also, Unshared has no effect on what a templated type is instantiated
    with, so if a templated type is instantiated with a template argument which
    has a type qualifier, the template instantiation will not change.
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
        const int* cPtr;
        shared int* sPtr;
    }

    shared S s;
    static assert(is(typeof(s) == shared S));
    static assert(is(typeof(typeof(s).ptr) == shared int*));
    static assert(is(typeof(typeof(s).cPtr) == const shared int*));
    static assert(is(typeof(typeof(s).sPtr) == shared int*));

    // For user-defined types, if shared is applied to a member variable only
    // because the containing type is shared, then shared is removed from that
    // member variable, but if the member variable is directly marked as shared,
    // then it continues to be shared.

    // shared S -> S
    static assert(is(Unshared!(typeof(s)) == S));
    static assert(is(typeof(Unshared!(typeof(s)).ptr) == int*));
    static assert(is(typeof(Unshared!(typeof(s)).cPtr) == const int*));
    static assert(is(typeof(Unshared!(typeof(s)).sPtr) == shared int*));

    static struct Foo(T)
    {
        T* ptr;
    }

    // The qualifier on the type is removed, but the qualifier on the template
    // argument is not.
    static assert(is(Unshared!(shared(Foo!(shared int))) == Foo!(shared int)));
    static assert(is(Unshared!(Foo!(shared int)) == Foo!(shared int)));
    static assert(is(Unshared!(shared(Foo!int)) == Foo!int));
}

/++
    Removes the outer layer of all type qualifiers from type $(D T) - this
    includes $(D shared).

    If no type qualifiers have been applied to the outer layer of type $(D T),
    then the result is $(D T).

    For the built-in scalar types (that is $(D bool), the character types, and
    the numeric types), they only have one layer, so $(D const U) simply becomes
    $(D U).

    Where the layers come in is pointers and arrays. $(D const(U*)) becomes
    $(D const(U)*), and $(D const(U[])), becomes $(D const(U)[]). So, a pointer
    goes from being fully $(D const) to being a mutable pointer to $(D const),
    and a dynamic array goes from being fully $(D const) to being a mutable
    dynamic array of $(D const) elements. And if there are multiple layers of
    pointers or arrays, it's just that outer layer which is affected - e.g.
    $(D shared(U**)) would become $(D shared(U*)*).

    For user-defined types, the effect is that $(D const U) becomes $(D U), and
    how that affects member variables depends on the type of the member
    variable. If a member variable is explicitly marked with any qualifiers,
    then it will continue to have those qualifiers even after Unqualified has
    stripped all qualifiers from the containing type. However, if a qualifier
    was on the member variable only because the containing type had that
    qualifier, then when Unqualified removes the qualifier from the containing
    type, it is removed from the member variable as well.

    Also, Unqualified has no effect on what a templated type is instantiated
    with, so if a templated type is instantiated with a template argument which
    has a type qualifier, the template instantiation will not change.

    Note that in most cases, $(LREF Unconst) or $(LREF Unshared) should be used
    rather than Unqualified, because in most cases, code is not designed to
    work with $(D shared) and thus doing type checks which remove $(D shared)
    will allow $(D shared) types to pass template constraints when they won't
    actually work with the code. And when code is designed to work with
    $(D shared), it's often the case that the type checks need to take
    $(D const) into account in order to avoid accidentally mutating $(D const)
    data and violating the type system.

    In particular, historically, a lot of D code has used
    $(REF Unqual, std, traits) (which is equivalent to phobos.sys.traits'
    Unqualified) when the programmer's intent was to remove $(D const), and
    $(D shared) wasn't actually considered at all. And in such cases, the code
    really should use $(LREF Unconst) instead.

    But of course, if a template constraint or $(D static if) really needs to
    strip off both the mutability qualifiers and $(D shared) for what it's
    testing for, then that's what Unqualified is for. It's just that it's best
    practice to use $(LREF Unconst) when it's not clear that $(D shared) should
    be removed as well.

    Also, note that $(D is(immutable T == immutable U))) is equivalent to
    $(D is(Unqualified!T == Unqualified!U)) (using $(D immutable) converts
    $(D const), $(D inout), and $(D shared) to $(D immutable), whereas using
    Unqualified strips off all type qualifiers, but the resulting comparison is
    the same as long as $(D immutable) is used on both sides or Unqualified is
    used on both sides)). So, in cases where code needs to compare two types to
    see whether they're the same while ignoring all qualifiers, it's generally
    better to use $(D immutable) on both types rather than using Unqualfied on
    both types, since that avoids needing to instantiate a template, and those
    instantiations can really add up when a project has a lot of templates
    with template constraints, $(D static if)s, and other forms of conditional
    compilation that need to compare types.
  +/
template Unqualified(T)
{
    import core.internal.traits : CoreUnqualified = Unqual;
    alias Unqualified = CoreUnqualified!(T);
}

///
@safe unittest
{
    static assert(is(Unqualified!(                   int) == int));
    static assert(is(Unqualified!(             const int) == int));
    static assert(is(Unqualified!(       inout       int) == int));
    static assert(is(Unqualified!(       inout const int) == int));
    static assert(is(Unqualified!(shared             int) == int));
    static assert(is(Unqualified!(shared       const int) == int));
    static assert(is(Unqualified!(shared inout       int) == int));
    static assert(is(Unqualified!(shared inout const int) == int));
    static assert(is(Unqualified!(         immutable int) == int));

    // Only the outer layer of immutable is removed.
    // immutable(int[]) -> immutable(int)[]
    alias ImmIntArr = immutable(int[]);
    static assert(is(Unqualified!ImmIntArr == immutable(int)[]));

    // Only the outer layer of const is removed.
    // const(int*) -> const(int)*
    alias ConstIntPtr = const(int*);
    static assert(is(Unqualified!ConstIntPtr == const(int)*));

    // const(int)* -> const(int)*
    alias PtrToConstInt = const(int)*;
    static assert(is(Unqualified!PtrToConstInt == const(int)*));

    // Only the outer layer of shared is removed.
    // shared(int*) -> shared(int)*
    alias SharedIntPtr = shared(int*);
    static assert(is(Unqualified!SharedIntPtr == shared(int)*));

    // shared(int)* -> shared(int)*
    alias PtrToSharedInt = shared(int)*;
    static assert(is(Unqualified!PtrToSharedInt == shared(int)*));

    // Both const and shared are removed from the outer layer.
    // shared const int[] -> shared(const(int))[]
    alias SharedConstIntArr = shared const(int[]);
    static assert(is(Unqualified!SharedConstIntArr == shared(const(int))[]));

    static struct S
    {
        int* ptr;
        const int* cPtr;
        shared int* sPtr;
    }

    shared const S s;
    static assert(is(typeof(s) == shared const S));
    static assert(is(typeof(typeof(s).ptr) == shared const int*));
    static assert(is(typeof(typeof(s).cPtr) == shared const int*));
    static assert(is(typeof(typeof(s).sPtr) == shared const int*));

    // For user-defined types, all qualifiers that are applied to member
    // variables only because the containing type has them are removed, but the
    // ones that are directly on those member variables remain.

    // shared const S -> S
    static assert(is(Unqualified!(typeof(s)) == S));
    static assert(is(typeof(Unqualified!(typeof(s)).ptr) == int*));
    static assert(is(typeof(Unqualified!(typeof(s)).cPtr) == const int*));
    static assert(is(typeof(Unqualified!(typeof(s)).sPtr) == shared int*));

    static struct Foo(T)
    {
        T* ptr;
    }

    // The qualifiers on the type are removed, but the qualifiers on the
    // template argument are not.
    static assert(is(Unqualified!(const(Foo!(const int))) == Foo!(const int)));
    static assert(is(Unqualified!(Foo!(const int)) == Foo!(const int)));
    static assert(is(Unqualified!(const(Foo!int)) == Foo!int));
}

/++
    Applies $(D const) to the given type.

    This is primarily useful in conjunction with templates that take a template
    predicate (such as many of the templates in phobos.sys.meta), since while in
    most cases, you can simply do $(D const T) or $(D const(T)) to make $(D T)
    $(D const), with something like $(REF Map, phobos, sys, meta), you need to
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

    import phobos.sys.meta : AliasSeq, Map;

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
    predicate (such as many of the templates in phobos.sys.meta), since while in
    most cases, you can simply do $(D immutable T) or $(D immutable(T)) to make
    $(D T) $(D immutable), with something like $(REF Map, phobos, sys, meta),
    you need to pass a template to be applied.

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

    import phobos.sys.meta : AliasSeq, Map;

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
    predicate (such as many of the templates in phobos.sys.meta), since while in
    most cases, you can simply do $(D inout T) or $(D inout(T)) to make $(D T)
    $(D inout), with something like $(REF Map, phobos, sys, meta), you need to
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

    import phobos.sys.meta : AliasSeq, Map;

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
    predicate (such as many of the templates in phobos.sys.meta), since while in
    most cases, you can simply do $(D shared T) or $(D shared(T)) to make $(D T)
    $(D shared), with something like $(REF Map, phobos, sys, meta), you need to
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

    import phobos.sys.meta : AliasSeq, Map;

    alias Types = AliasSeq!(int, long,
                            bool*, ubyte[],
                            string, immutable(string));
    alias WithShared = Map!(SharedOf, Types);
    static assert(is(WithShared ==
                     AliasSeq!(shared int, shared long,
                               shared(bool*), shared(ubyte[]),
                               shared(string), immutable(string))));
}

// Needed for rvalueOf/lvalueOf because
// "inout on return means inout must be on a parameter as well"
private struct __InoutWorkaroundStruct {}

/++
    Creates an lvalue or rvalue of type T to be used in conjunction with
    $(D is(typeof(...))) or
    $(DDSUBLINK spec/traits, compiles, $(D __traits(compiles, ...))).

    The idea is that some traits or other forms of conditional compilation need
    to verify that a particular piece of code compiles with an rvalue or an
    lvalue of a specific type, and these $(D @property) functions allow you to
    get an rvalue or lvalue of a specific type to use within an expression that
    is then tested to see whether it compiles.

    They're $(D @property) functions so that using $(D typeof) on them gives
    the return type rather than the type of the function.

    Note that these functions are $(I not) defined, so if they're actually used
    outside of type introspection, they'll result in linker errors. They're
    entirely for testing that a particular piece of code compiles with an rvalue
    or lvalue of the given type.

    The $(D __InoutWorkaroundStruct) parameter is entirely to make it so that
    these work when the given type has the $(D inout) qualifier, since the
    language requires that a function that returns an $(D inout) type also have
    an $(D inout) type as a parameter. It should just be ignored.
  +/
@property T rvalueOf(T)(inout __InoutWorkaroundStruct = __InoutWorkaroundStruct.init);

/++ Ditto +/
@property ref T lvalueOf(T)(inout __InoutWorkaroundStruct = __InoutWorkaroundStruct.init);

///
@safe unittest
{
    static int foo(int);
    static assert(is(typeof(foo(lvalueOf!int)) == int));
    static assert(is(typeof(foo(rvalueOf!int)) == int));

    static bool bar(ref int);
    static assert(is(typeof(bar(lvalueOf!int)) == bool));
    static assert(!is(typeof(bar(rvalueOf!int))));

    static assert( is(typeof({ lvalueOf!int = 42; })));
    static assert(!is(typeof({ rvalueOf!int = 42; })));

    static struct S {}
    static assert( is(typeof({ lvalueOf!S = S.init; })));
    static assert(!is(typeof({ rvalueOf!S = S.init; })));

    static struct NoAssign
    {
        @disable void opAssign(ref NoAssign);
    }
    static assert(!is(typeof({ lvalueOf!NoAssign = NoAssign.init; })));
    static assert(!is(typeof({ rvalueOf!NoAssign = NoAssign.init; })));
}

@system unittest
{
    import phobos.sys.meta : AliasSeq;

    void needLvalue(T)(ref T);
    static struct S {}
    int i;
    struct Nested { void f() { ++i; } }

    static foreach (T; AliasSeq!(int, const int, immutable int, inout int, string, S, Nested, Object))
    {
        static assert(!__traits(compiles, needLvalue(rvalueOf!T)));
        static assert( __traits(compiles, needLvalue(lvalueOf!T)));
        static assert(is(typeof(rvalueOf!T) == T));
        static assert(is(typeof(lvalueOf!T) == T));
    }

    static assert(!__traits(compiles, rvalueOf!int = 1));
    static assert( __traits(compiles, lvalueOf!byte = 127));
    static assert(!__traits(compiles, lvalueOf!byte = 128));
}

// We may want to add this as some sort of public test helper in the future in
// whatever module would be appropriate for that.
private template assertWithQualifiers(alias Pred, T, bool expected)
{
    static assert(Pred!T == expected);
    static assert(Pred!(const T) == expected);
    static assert(Pred!(inout T) == expected);
    static assert(Pred!(immutable T) == expected);
    static assert(Pred!(shared T) == expected);

    static if (is(T == U*, U))
    {
        static assert(Pred!(const(U)*) == expected);
        static assert(Pred!(inout(U)*) == expected);
        static assert(Pred!(immutable(U)*) == expected);
        static assert(Pred!(shared(U)*) == expected);
    }
    else static if (is(T == U[], U))
    {
        static assert(Pred!(const(U)[]) == expected);
        static assert(Pred!(inout(U)[]) == expected);
        static assert(Pred!(immutable(U)[]) == expected);
        static assert(Pred!(shared(U)[]) == expected);
    }
    else static if (is(T == U[n], U, size_t n))
    {
        static assert(Pred!(const(U)[n]) == expected);
        static assert(Pred!(inout(U)[n]) == expected);
        static assert(Pred!(immutable(U)[n]) == expected);
        static assert(Pred!(shared(U)[n]) == expected);
    }
}

private template assertWithQualifiers(alias Pred)
{
    alias assertWithQualifiers(T, bool expected) = .assertWithQualifiers!(Pred, T, expected);
}

@safe unittest
{
    mixin assertWithQualifiers!(isPointer, int*, true);
    mixin assertWithQualifiers!(isPointer, int, false);

    alias test = assertWithQualifiers!isPointer;
    mixin test!(int*, true);
    mixin test!(int, false);
}
