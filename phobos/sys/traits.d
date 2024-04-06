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
              $(LREF isDynamicArray)
              $(LREF isFloatingPoint)
              $(LREF isInteger)
              $(LREF isNumeric)
              $(LREF isPointer)
              $(LREF isSignedInteger)
              $(LREF isStaticArray)
              $(LREF isUnsignedInteger)
    ))
    $(TR $(TD Aggregate Type traits) $(TD
              $(LREF EnumMembers)
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

    See_Also:
        $(DDSUBLINK dlang.org/spec/type, implicit-conversions, Spec on implicit conversions)
        $(DDSUBLINK spec/const3, implicit_qualifier_conversions, Spec for implicit qualifier conversions)
        $(LREF isQualifierConvertible)
  +/
enum isImplicitlyConvertible(From, To) = is(From : To);

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

    See_Also:
        $(DDSUBLINK spec/const3, implicit_qualifier_conversions, Spec for implicit qualifier conversions)
        $(LREF isImplicitlyConvertible)
  +/
enum isQualifierConvertible(From, To) = is(immutable From == immutable To) && is(From* : To*);

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

    // shared is of course also a qualifer.
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
