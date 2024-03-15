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
    $(TR $(TD Traits for removing type qualfiers) $(TD
              $(LREF isDynamicArray)
              $(LREF isFloatingPoint)
              $(LREF isInteger)
              $(LREF isNumeric)
              $(LREF isPointer)
              $(LREF isStaticArray)
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
    Source:    $(PHOBOSSRC lib/sys/traits)
+/
module lib.sys.traits;

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
    import lib.sys.meta : Alias, AliasSeq;

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
enum bool isStaticArray(T) = is(T == U[n], U, size_t n);

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
    import lib.sys.meta : Alias, AliasSeq;

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

    This trait does have some similarities to $(D __traits(isIntegral, T)), but
    $(D isIntegral) accepts a $(D lot) more types than isInteger does.
    isInteger is specifically for testing for the built-in integer types,
    whereas $(D isIntegral) tests for a whole set of types that are vaguely
    integer-like (including $(D bool), the three built-in character types, and
    some of the vector types from core.simd). So, for most code, isInteger is
    going to be more appropriate, but obviously, it depends on what the code is
    trying to do.

    See also:
        $(DDSUBLINK spec/traits, isIntegral, $(D __traits(isIntegral, T)))
        $(LREF isFloatingPoint)
        $(LREF isNumeric)
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
    import lib.sys.meta : Alias, AliasSeq;

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

    This trait does have some similarities to $(D __traits(isFloating, T)), but
    $(D isFloating) accepts more types than isFloatingPoint does.
    isFloatingPoint is specifically for testing for the built-in floating-point
    types, whereas $(D isFloating) tests for a whole set of types that are
    vaguely float-like (including enums with a base type which is a
    floating-point type and some of the vector types from core.simd). So, for
    most code, isFloatingPoint is going to be more appropriate, but obviously,
    it depends on what the code is trying to do.

    See also:
        $(DDSUBLINK spec/traits, isFloating, $(D __traits(isFloating, T)))
        $(LREF isInteger)
        $(LREF isNumeric)
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
    import lib.sys.meta : Alias, AliasSeq;

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
    import lib.sys.meta : Alias, AliasSeq;

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
    import lib.sys.meta : Alias, AliasSeq;

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
    Removes the outer layer of $(D const), $(D inout), or $(D immutable)
    from type $(D T).

    If none of those qualifiers have been applied to the outer layer of
    type $(D T), then the result is $(D T).

    For the built-in, scalar types (that is $(D bool), the character types, and
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
    by Unshared. Only explicit $(D shared) is removed.

    For the built-in, scalar types (that is $(D bool), the character types, and
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

    // The qualifer on the type is removed, but the qualifier on the template
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

    For the built-in, scalar types (that is $(D bool), the character types, and
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
    $(REF Unqual, std, traits) (which is equivalent to lib.sys.traits'
    Unqualified) when the programmer's intent was to remove $(D const), and
    $(D shared) wasn't actually considered at all. And in such cases, the code
    really should use $(LREF Unconst) instead.

    But of course, if a template constraint or $(D static if) really needs to
    strip off both the mutability qualifers and $(D shared) for what it's
    testing for, then that's what Unqualified is for. It's just that it's best
    practice to use $(LREF Unconst) when it's not clear that $(D shared) should
    be removed as well.
  +/
version (StdDdoc) template Unqualified(T)
{
    import core.internal.traits : CoreUnqualified = Unqual;
    alias Unqualified = CoreUnqualified!(T);
}
else
{
    import core.internal.traits : CoreUnqualified = Unqual;
    alias Unqualified = CoreUnqualified;
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

    // The qualifers on the type are removed, but the qualifiers on the
    // template argument are not.
    static assert(is(Unqualified!(const(Foo!(const int))) == Foo!(const int)));
    static assert(is(Unqualified!(Foo!(const int)) == Foo!(const int)));
    static assert(is(Unqualified!(const(Foo!int)) == Foo!int));
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
