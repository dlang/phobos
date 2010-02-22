// Written in the D programming language.

/**
 * Templates with which to extract information about
 * types at compile time.
 *
 * Macros:
 *  WIKI = Phobos/StdTraits
 *
 * Copyright: Copyright Digital Mars 2005 - 2009.
 * License:   <a href="http://www.boost.org/LICENSE_1_0.txt">Boost License 1.0</a>.
 * Authors:   $(WEB digitalmars.com, Walter Bright),
 *            Tomasz Stachowiak ($(D isExpressionTuple)),
 *            $(WEB erdani.org, Andrei Alexandrescu)
 *
 *          Copyright Digital Mars 2005 - 2009.
 * Distributed under the Boost Software License, Version 1.0.
 *    (See accompanying file LICENSE_1_0.txt or copy at
 *          http://www.boost.org/LICENSE_1_0.txt)
 */
module std.traits;
import std.typetuple;

/***
 * Get the type of the return value from a function,
 * a pointer to function, a delegate, a struct
 * with an opCall, a pointer to a struct with an opCall,
 * or a class with an opCall.
 * Example:
 * ---
 * import std.traits;
 * int foo();
 * ReturnType!(foo) x;   // x is declared as int
 * ---
 */
template ReturnType(alias dg)
{
    static if (is(typeof(dg)))        // if dg is an expression
        alias ReturnType!(typeof(dg), void) ReturnType;
    else                        // dg is a type
        alias ReturnType!(dg, void) ReturnType;
}

template ReturnType(dg, dummy = void)
{
    static if (is(dg R == return))
        alias R ReturnType;
    else static if (is(dg T : T*))
        alias ReturnType!(T, void) ReturnType;
    else static if (is(typeof(&dg.opCall) == return))
        alias ReturnType!(typeof(&dg.opCall), void) ReturnType;
    else
        static assert(0, "argument has no return type");
}

unittest
{
    struct G
    {
        int opCall (int i) { return 1;}
    }

    alias ReturnType!(G) ShouldBeInt;
    static assert(is(ShouldBeInt == int));

    G g;
    static assert(is(ReturnType!(g) == int));

    G* p;
    alias ReturnType!(p) pg;
    static assert(is(pg == int));

    class C
    {
        int opCall (int i) { return 1;}
    }

    static assert(is(ReturnType!(C) == int));

    C c;
    static assert(is(ReturnType!(c) == int));
}

/***
Get, as a tuple, the types of the parameters to a function, a pointer
to function, a delegate, a struct with an $(D opCall), a pointer to a
struct with an $(D opCall), or a class with an $(D opCall).
 
Example:
---
import std.traits;
int foo(int, long);
void bar(ParameterTypeTuple!(foo));      // declares void bar(int, long);
void abc(ParameterTypeTuple!(foo)[1]);   // declares void abc(long);
---
*/
template ParameterTypeTuple(alias dg)
{
    static if (is(typeof(dg)))  // if dg is an expression
        alias ParameterTypeTuple!(typeof(dg), void) ParameterTypeTuple;
    else
        alias ParameterTypeTuple!(dg, void) ParameterTypeTuple;
}

/** ditto */
template ParameterTypeTuple(dg, dummy = void)
{
    static if (is(dg P == function))
        alias P ParameterTypeTuple;
    else static if (is(dg P == delegate))
        alias ParameterTypeTuple!P ParameterTypeTuple;
    else static if (is(dg P == P*))
        alias ParameterTypeTuple!P ParameterTypeTuple;
    else static if (is(typeof(&dg.opCall) == return))
        alias ParameterTypeTuple!(typeof(&dg.opCall), void) ParameterTypeTuple;
    else
        static assert(0, "argument has no parameters");
}

unittest
{
    int foo(int i, bool b) { return 0; }
    static assert (is(ParameterTypeTuple!(foo) == TypeTuple!(int, bool)));
    static assert (is(ParameterTypeTuple!(typeof(&foo))
        == TypeTuple!(int, bool)));
    struct S { real opCall(real r, int i) { return 0.0; } }
    S s;
    static assert (is(ParameterTypeTuple!(S) == TypeTuple!(real, int)));
    static assert (is(ParameterTypeTuple!(S*) == TypeTuple!(real, int)));
    static assert (is(ParameterTypeTuple!(s) == TypeTuple!(real, int)));
}

/***
 * Get the types of the fields of a struct or class.
 * This consists of the fields that take up memory space,
 * excluding the hidden fields like the virtual function
 * table pointer.
 */

template FieldTypeTuple(S)
{
    static if (is(S == struct) || is(S == class) || is(S == union))
        alias typeof(S.tupleof) FieldTypeTuple;
    else
        alias TypeTuple!(S) FieldTypeTuple;
        //static assert(0, "argument is not struct or class");
}

// // FieldOffsetsTuple
// private template FieldOffsetsTupleImpl(size_t n, T...)
// {
//     static if (T.length == 0)
//     {
//         alias TypeTuple!() Result;
//     }
//     else
//     {
//         //private alias FieldTypeTuple!(T[0]) Types;
//         private enum size_t myOffset =
//             ((n + T[0].alignof - 1) / T[0].alignof) * T[0].alignof;
//         static if (is(T[0] == struct))
//         {
//             alias FieldTypeTuple!(T[0]) MyRep;
//             alias FieldOffsetsTupleImpl!(myOffset, MyRep, T[1 .. $]).Result
//                 Result;
//         }
//         else
//         {
//             private enum size_t mySize = T[0].sizeof;
//             alias TypeTuple!(myOffset) Head;
//             static if (is(T == union))
//             {
//                 alias FieldOffsetsTupleImpl!(myOffset, T[1 .. $]).Result
//                     Tail;
//             }
//             else
//             {
//                 alias FieldOffsetsTupleImpl!(myOffset + mySize,
//                                              T[1 .. $]).Result
//                     Tail;
//             }
//             alias TypeTuple!(Head, Tail) Result;
//         }
//     }
// }

// template FieldOffsetsTuple(T...)
// {
//     alias FieldOffsetsTupleImpl!(0, T).Result FieldOffsetsTuple;
// }

// unittest
// {
//     alias FieldOffsetsTuple!(int) T1;
//     assert(T1.length == 1 && T1[0] == 0);
//     //
//     struct S2 { char a; int b; char c; double d; char e, f; }
//     alias FieldOffsetsTuple!(S2) T2;
//     //pragma(msg, T2);
//     static assert(T2.length == 6
//            && T2[0] == 0 && T2[1] == 4 && T2[2] == 8 && T2[3] == 16
//                   && T2[4] == 24&& T2[5] == 25);
//     //
//     class C { int a, b, c, d; }
//     struct S3 { char a; C b; char c; }
//     alias FieldOffsetsTuple!(S3) T3;
//     //pragma(msg, T2);
//     static assert(T3.length == 3
//            && T3[0] == 0 && T3[1] == 4 && T3[2] == 8);
//     //
//     struct S4 { char a; union { int b; char c; } int d; }
//     alias FieldOffsetsTuple!(S4) T4;
//     //pragma(msg, FieldTypeTuple!(S4));
//     static assert(T4.length == 4
//            && T4[0] == 0 && T4[1] == 4 && T4[2] == 8);
// }

// /***
// Get the offsets of the fields of a struct or class.
// */

// template FieldOffsetsTuple(S)
// {
//     static if (is(S == struct) || is(S == class))
//         alias typeof(S.tupleof) FieldTypeTuple;
//     else
//         static assert(0, "argument is not struct or class");
// }

/***
Get the primitive types of the fields of a struct or class, in
topological order.

Example:
----
struct S1 { int a; float b; }
struct S2 { char[] a; union { S1 b; S1 * c; } }
alias RepresentationTypeTuple!(S2) R;
assert(R.length == 4
    && is(R[0] == char[]) && is(R[1] == int)
    && is(R[2] == float) && is(R[3] == S1*));
----
*/

template RepresentationTypeTuple(T...)
{
    static if (T.length == 0)
    {
        alias TypeTuple!() RepresentationTypeTuple;
    }
    else
    {
        static if (is(T[0] == struct) || is(T[0] == union))
// @@@BUG@@@ this should work
//             alias .RepresentationTypes!(T[0].tupleof)
//                 RepresentationTypes;
            alias .RepresentationTypeTuple!(FieldTypeTuple!(T[0]),
                                            T[1 .. $])
                RepresentationTypeTuple;
        else static if (is(T[0] U == typedef))
        {
            alias .RepresentationTypeTuple!(FieldTypeTuple!(U),
                                            T[1 .. $])
                RepresentationTypeTuple;
        }
        else
        {
            alias TypeTuple!(T[0], RepresentationTypeTuple!(T[1 .. $]))
                RepresentationTypeTuple;
        }
    }
}

unittest
{
    alias RepresentationTypeTuple!(int) S1;
    static assert(is(S1 == TypeTuple!(int)));
    struct S2 { int a; }
    static assert(is(RepresentationTypeTuple!(S2) == TypeTuple!(int)));
    struct S3 { int a; char b; }
    static assert(is(RepresentationTypeTuple!(S3) == TypeTuple!(int, char)));
    struct S4 { S1 a; int b; S3 c; }
    static assert(is(RepresentationTypeTuple!(S4) ==
                     TypeTuple!(int, int, int, char)));

    struct S11 { int a; float b; }
    struct S21 { char[] a; union { S11 b; S11 * c; } }
    alias RepresentationTypeTuple!(S21) R;
    assert(R.length == 4
           && is(R[0] == char[]) && is(R[1] == int)
           && is(R[2] == float) && is(R[3] == S11*));
}

/*
RepresentationOffsets
*/

// private template Repeat(size_t n, T...)
// {
//     static if (n == 0) alias TypeTuple!() Repeat;
//     else alias TypeTuple!(T, Repeat!(n - 1, T)) Repeat;
// }

// template RepresentationOffsetsImpl(size_t n, T...)
// {
//     static if (T.length == 0)
//     {
//         alias TypeTuple!() Result;
//     }
//     else
//     {
//         private enum size_t myOffset =
//             ((n + T[0].alignof - 1) / T[0].alignof) * T[0].alignof;
//         static if (!is(T[0] == union))
//         {
//             alias Repeat!(n, FieldTypeTuple!(T[0])).Result
//                 Head;
//         }
//         static if (is(T[0] == struct))
//         {
//             alias .RepresentationOffsetsImpl!(n, FieldTypeTuple!(T[0])).Result
//                 Head;
//         }
//         else
//         {
//             alias TypeTuple!(myOffset) Head;
//         }
//         alias TypeTuple!(Head,
//                          RepresentationOffsetsImpl!(
//                              myOffset + T[0].sizeof, T[1 .. $]).Result)
//             Result;
//     }
// }

// template RepresentationOffsets(T)
// {
//     alias RepresentationOffsetsImpl!(0, T).Result
//         RepresentationOffsets;
// }

// unittest
// {
//     struct S1 { char c; int i; }
//     alias RepresentationOffsets!(S1) Offsets;
//     static assert(Offsets[0] == 0);
//     //pragma(msg, Offsets[1]);
//     static assert(Offsets[1] == 4);
// }

// hasRawAliasing

private template HasRawPointerImpl(T...)
{
    static if (T.length == 0)
    {
        enum result = false;
    }
    else
    {
        static if (is(T[0] foo : U*, U))
            enum hasRawAliasing = !is(U == invariant);
        else static if (is(T[0] foo : U[], U))
            enum hasRawAliasing = !is(U == invariant);
        else
            enum hasRawAliasing = false;
        enum result = hasRawAliasing || HasRawPointerImpl!(T[1 .. $]).result;
    }
}

/*
Statically evaluates to $(D true) if and only if $(D T)'s
representation contains at least one field of pointer or array type.
Members of class types are not considered raw pointers. Pointers to
invariant objects are not considered raw aliasing.

Example:
---
// simple types
static assert(!hasRawAliasing!(int));
static assert(hasRawAliasing!(char*));
// references aren't raw pointers
static assert(!hasRawAliasing!(Object));
// built-in arrays do contain raw pointers
static assert(hasRawAliasing!(int[]));
// aggregate of simple types
struct S1 { int a; double b; }
static assert(!hasRawAliasing!(S1));
// indirect aggregation
struct S2 { S1 a; double b; }
static assert(!hasRawAliasing!(S2));
// struct with a pointer member
struct S3 { int a; double * b; }
static assert(hasRawAliasing!(S3));
// struct with an indirect pointer member
struct S4 { S3 a; double b; }
static assert(hasRawAliasing!(S4));
----
*/
private template hasRawAliasing(T...)
{
    enum hasRawAliasing
        = HasRawPointerImpl!(RepresentationTypeTuple!(T)).result;
}

unittest
{
// simple types
    static assert(!hasRawAliasing!(int));
    static assert(hasRawAliasing!(char*));
// references aren't raw pointers
    static assert(!hasRawAliasing!(Object));
    static assert(!hasRawAliasing!(int));
    struct S1 { int z; }
    static assert(!hasRawAliasing!(S1));
    struct S2 { int* z; }
    static assert(hasRawAliasing!(S2));
    struct S3 { int a; int* z; int c; }
    static assert(hasRawAliasing!(S3));
    struct S4 { int a; int z; int c; }
    static assert(!hasRawAliasing!(S4));
    struct S5 { int a; Object z; int c; }
    static assert(!hasRawAliasing!(S5));
    union S6 { int a; int b; }
    static assert(!hasRawAliasing!(S6));
    union S7 { int a; int * b; }
    static assert(hasRawAliasing!(S7));
    typedef int* S8;
    static assert(hasRawAliasing!(S8));
    enum S9 { a };
    static assert(!hasRawAliasing!(S9));
    // indirect members
    struct S10 { S7 a; int b; }
    static assert(hasRawAliasing!(S10));
    struct S11 { S6 a; int b; }
    static assert(!hasRawAliasing!(S11));
}

/*
Statically evaluates to $(D true) if and only if $(D T)'s
representation includes at least one non-invariant object reference.
*/

private template hasObjects(T...)
{
    static if (T.length == 0)
    {
        enum hasObjects = false;
    }
    else static if (is(T[0] U == typedef))
    {
        enum hasObjects = hasObjects!(U, T[1 .. $]);
    }
    else static if (is(T[0] == struct))
    {
        enum hasObjects = hasObjects!(
            RepresentationTypeTuple!(T[0]), T[1 .. $]);
    }
    else
    {
        enum hasObjects = is(T[0] == class) || hasObjects!(T[1 .. $]);
    }
}

/**
Returns $(D true) if and only if $(D T)'s representation includes at
least one of the following: $(OL $(LI a raw pointer $(D U*) and $(D U)
is not invariant;) $(LI an array $(D U[]) and $(D U) is not
invariant;) $(LI a reference to a class type $(D C) and $(D C) is not
invariant.))
*/

template hasAliasing(T...)
{
    enum hasAliasing = hasRawAliasing!(T) || hasObjects!(T);
}

unittest
{
    struct S1 { int a; Object b; }
    static assert(hasAliasing!(S1));
    struct S2 { string a; }
    static assert(!hasAliasing!(S2));
}

/***
 * Get a $(D_PARAM TypeTuple) of the base class and base interfaces of
 * this class or interface. $(D_PARAM BaseTypeTuple!(Object)) returns
 * the empty type tuple.
 * 
 * Example:
 * ---
 * import std.traits, std.typetuple, std.stdio;
 * interface I { }
 * class A { }
 * class B : A, I { }
 *
 * void main()
 * {
 *     alias BaseTypeTuple!(B) TL;
 *     writeln(typeid(TL));        // prints: (A,I)
 * }
 * ---
 */

template BaseTypeTuple(A)
{
    static if (is(A P == super))
        alias P BaseTypeTuple;
    else
            static assert(0, "argument is not a class or interface");
}

unittest
{
    interface I1 { }
    interface I2 { }
    interface I12 : I1, I2 { }
    static assert(is(BaseTypeTuple!I12 == TypeTuple!(I1, I2)));
    interface I3 : I1 { }
    interface I123 : I1, I2, I3 { }
    static assert(is(BaseTypeTuple!I123 == TypeTuple!(I1, I2, I3)));
}

unittest
{
    interface I1 { }
    interface I2 { }
    class A { }
    class C : A, I1, I2 { }

    alias BaseTypeTuple!(C) TL;
    assert(TL.length == 3);
    assert(is (TL[0] == A));
    assert(is (TL[1] == I1));
    assert(is (TL[2] == I2));

    assert(BaseTypeTuple!(Object).length == 0);
}

/**
 * Get a $(D_PARAM TypeTuple) of $(I all) base classes of this class,
 * in decreasing order. Interfaces are not included. $(D_PARAM
 * BaseClassesTuple!(Object)) yields the empty type tuple.
 *
 * Example:
 * ---
 * import std.traits, std.typetuple, std.stdio;
 * interface I { }
 * class A { }
 * class B : A, I { }
 * class C : B { }
 *
 * void main()
 * {
 *     alias BaseClassesTuple!(C) TL;
 *     writeln(typeid(TL));        // prints: (B,A,Object)
 * }
 * ---
 */

template BaseClassesTuple(T)
{
    static if (is(T == Object))
    {
        alias TypeTuple!() BaseClassesTuple;
    }
    static if (is(BaseTypeTuple!(T)[0] == Object))
    {
        alias TypeTuple!(Object) BaseClassesTuple;
    }
    else
    {
        alias TypeTuple!(BaseTypeTuple!(T)[0],
                         BaseClassesTuple!(BaseTypeTuple!(T)[0]))
            BaseClassesTuple;
    }
}

/**
 * Get a $(D_PARAM TypeTuple) of $(I all) interfaces directly or
 * indirectly inherited by this class or interface. Interfaces do not
 * repeat if multiply implemented. $(D_PARAM InterfacesTuple!(Object))
 * yields the empty type tuple.
 *
 * Example:
 * ---
 * import std.traits, std.typetuple, std.stdio;
 * interface I1 { }
 * interface I2 { }
 * class A : I1, I2 { }
 * class B : A, I1 { }
 * class C : B { }
 *
 * void main()
 * {
 *     alias InterfacesTuple!(C) TL;
 *     writeln(typeid(TL));        // prints: (I1, I2)
 * }
 * ---
 */

template InterfacesTuple(T)
{
    static if (is(T S == super) && S.length)
        alias NoDuplicates!(InterfacesTuple_Flatten!(S))
            InterfacesTuple;
    else
        alias TypeTuple!() InterfacesTuple;
}

// internal
private template InterfacesTuple_Flatten(H, T...)
{
    static if (T.length)
    {
        alias TypeTuple!(
                InterfacesTuple_Flatten!(H),
                InterfacesTuple_Flatten!(T))
            InterfacesTuple_Flatten;
    }
    else
    {
        static if (is(H == interface))
            alias TypeTuple!(H, InterfacesTuple!(H))
                InterfacesTuple_Flatten;
        else
            alias InterfacesTuple!(H) InterfacesTuple_Flatten;
    }
}

unittest
{
    struct Test1_WorkaroundForBug2986 {
        // doc example
        interface I1 {}
        interface I2 {}
        class A : I1, I2 { }
        class B : A, I1 { }
        class C : B { }
        alias InterfacesTuple!(C) TL;
        static assert(is(TL[0] == I1) && is(TL[1] == I2));
     }
    struct Test2_WorkaroundForBug2986 {
        interface Iaa {}
        interface Iab {}
        interface Iba {}
        interface Ibb {}
        interface Ia : Iaa, Iab {}
        interface Ib : Iba, Ibb {}
        interface I : Ia, Ib {}
        interface J {}
        class B : J {}
        class C : B, Ia, Ib {}
        static assert(is(InterfacesTuple!(I) ==
                        TypeTuple!(Ia, Iaa, Iab, Ib, Iba, Ibb)));
        static assert(is(InterfacesTuple!(C) ==
                        TypeTuple!(J, Ia, Iaa, Iab, Ib, Iba, Ibb)));
    }
}

/**
 * Get a $(D_PARAM TypeTuple) of $(I all) base classes of $(D_PARAM
 * T), in decreasing order, followed by $(D_PARAM T)'s
 * interfaces. $(D_PARAM TransitiveBaseTypeTuple!(Object)) yields the
 * empty type tuple.
 *
 * Example:
 * ---
 * import std.traits, std.typetuple, std.stdio;
 * interface I { }
 * class A { }
 * class B : A, I { }
 * class C : B { }
 *
 * void main()
 * {
 *     alias TransitiveBaseTypeTuple!(C) TL;
 *     writeln(typeid(TL));        // prints: (B,A,Object,I)
 * }
 * ---
 */

template TransitiveBaseTypeTuple(T)
{
    static if (is(T == Object))
        alias TypeTuple!() TransitiveBaseTypeTuple;
    else
        alias TypeTuple!(BaseClassesTuple!(T),
            InterfacesTuple!(T))
            TransitiveBaseTypeTuple;
}

unittest
{
    interface J1 {}
    interface J2 {}
    class B1 {}
    class B2 : B1, J1, J2 {}
    class B3 : B2, J1 {}
    alias TransitiveBaseTypeTuple!(B3) TL;
    assert(TL.length == 5);
    assert(is (TL[0] == B2));
    assert(is (TL[1] == B1));
    assert(is (TL[2] == Object));
    assert(is (TL[3] == J1));
    assert(is (TL[4] == J2));
    
    assert(TransitiveBaseTypeTuple!(Object).length == 0);
}

/**
Get the type that all types can be implicitly converted to. Useful
e.g. in figuring out an array type from a bunch of initializing
values. Returns $(D_PARAM void) if passed an empty list, or if the
types have no common type.

Example:

----
alias CommonType!(int, long, short) X;
assert(is(X == long));
alias CommonType!(int, char[], short) Y;
assert(is(Y == void));
----
*/
template CommonType(T...)
{
    static if (!T.length)
        alias void CommonType;
    else static if (T.length == 1)
        alias T[0] CommonType;
    else static if (is(typeof(true ? T[0].init : T[1].init) U))
        alias CommonType!(U, T[2 .. $]) CommonType;
    else
        alias void CommonType;
}

unittest
{
    alias CommonType!(int, long, short) X;
    assert(is(X == long));
    alias CommonType!(char[], int, long, short) Y;
    assert(is(Y == void), Y.stringof);
}

/**
 * Returns a tuple with all possible target types of an implicit
 * conversion of a value of type $(D_PARAM T).
 *
 * Important note:
 *
 * The possible targets are computed more conservatively than the D
 * 2.005 compiler does, eliminating all dangerous conversions. For
 * example, $(D_PARAM ImplicitConversionTargets!(double)) does not
 * include $(D_PARAM float).
 */

template ImplicitConversionTargets(T)
{
    static if (is(T == bool))
        alias TypeTuple!(byte, ubyte, short, ushort, int, uint, long, ulong,
            float, double, real, char, wchar, dchar)
            ImplicitConversionTargets;
    else static if (is(T == byte))
        alias TypeTuple!(short, ushort, int, uint, long, ulong,
            float, double, real, char, wchar, dchar)
            ImplicitConversionTargets;
    else static if (is(T == ubyte))
        alias TypeTuple!(short, ushort, int, uint, long, ulong,
            float, double, real, char, wchar, dchar)
            ImplicitConversionTargets;
    else static if (is(T == short))
        alias TypeTuple!(ushort, int, uint, long, ulong,
            float, double, real)
            ImplicitConversionTargets;
    else static if (is(T == ushort))
        alias TypeTuple!(int, uint, long, ulong, float, double, real)
            ImplicitConversionTargets;
    else static if (is(T == int))
        alias TypeTuple!(long, ulong, float, double, real)
            ImplicitConversionTargets;
    else static if (is(T == uint))
        alias TypeTuple!(long, ulong, float, double, real)
            ImplicitConversionTargets;
    else static if (is(T == long))
        alias TypeTuple!(float, double, real)
            ImplicitConversionTargets;
    else static if (is(T == ulong))
        alias TypeTuple!(float, double, real)
            ImplicitConversionTargets;
    else static if (is(T == float))
        alias TypeTuple!(double, real)
            ImplicitConversionTargets;
    else static if (is(T == double))
        alias TypeTuple!(real)
            ImplicitConversionTargets;
    else static if (is(T == char))
        alias TypeTuple!(wchar, dchar, byte, ubyte, short, ushort,
            int, uint, long, ulong, float, double, real)
            ImplicitConversionTargets;
    else static if (is(T == wchar))
        alias TypeTuple!(wchar, dchar, short, ushort, int, uint, long, ulong,
            float, double, real)
            ImplicitConversionTargets;
    else static if (is(T == dchar))
        alias TypeTuple!(wchar, dchar, int, uint, long, ulong,
            float, double, real)
            ImplicitConversionTargets;
    else static if(is(T : Object))
        alias TransitiveBaseTypeTuple!(T) ImplicitConversionTargets;
    else static if (is(T : void*))
        alias TypeTuple!(void*) ImplicitConversionTargets;
    else
        alias TypeTuple!() ImplicitConversionTargets;
}

unittest
{
    assert(is(ImplicitConversionTargets!(double)[0] == real));
}

/**
Is $(D From) implicitly convertible to $(D To)?
 */

template isImplicitlyConvertible(From, To)
{
    enum bool isImplicitlyConvertible = is(typeof({
                        void fun(To) {}
                        From f;
                        fun(f);
                    }()));
}

unittest
{
    static assert(isImplicitlyConvertible!(immutable(char), char));
    static assert(isImplicitlyConvertible!(const(char), char));
    static assert(isImplicitlyConvertible!(char, wchar));
    static assert(!isImplicitlyConvertible!(wchar, char));
}

/**
 * Detect whether T is a built-in integral type. Types $(D bool), $(D
 * char), $(D wchar), and $(D dchar) are not considered integral.
 */

template isIntegral(T)
{
    enum bool isIntegral = staticIndexOf!(Unqual!(T), byte,
            ubyte, short, ushort, int, uint, long, ulong) >= 0;
}

unittest
{
    assert(isIntegral!(byte));
    assert(isIntegral!(const(byte)));
    assert(isIntegral!(immutable(byte)));
    //assert(isIntegral!(shared(byte)));
    //assert(isIntegral!(shared(const(byte))));

    //assert(isIntegral!(ubyte));
    //assert(isIntegral!(const(ubyte)));
    //assert(isIntegral!(immutable(ubyte)));
    //assert(isIntegral!(shared(ubyte)));
    //assert(isIntegral!(shared(const(ubyte))));

    //assert(isIntegral!(short));
    //assert(isIntegral!(const(short)));
    assert(isIntegral!(immutable(short)));
    //assert(isIntegral!(shared(short)));
    //assert(isIntegral!(shared(const(short))));

    assert(isIntegral!(ushort));
    assert(isIntegral!(const(ushort)));
    assert(isIntegral!(immutable(ushort)));
    //assert(isIntegral!(shared(ushort)));
    //assert(isIntegral!(shared(const(ushort))));

    assert(isIntegral!(int));
    assert(isIntegral!(const(int)));
    assert(isIntegral!(immutable(int)));
    //assert(isIntegral!(shared(int)));
    //assert(isIntegral!(shared(const(int))));

    assert(isIntegral!(uint));
    assert(isIntegral!(const(uint)));
    assert(isIntegral!(immutable(uint)));
    //assert(isIntegral!(shared(uint)));
    //assert(isIntegral!(shared(const(uint))));

    assert(isIntegral!(long));
    assert(isIntegral!(const(long)));
    assert(isIntegral!(immutable(long)));
    //assert(isIntegral!(shared(long)));
    //assert(isIntegral!(shared(const(long))));

    assert(isIntegral!(ulong));
    assert(isIntegral!(const(ulong)));
    assert(isIntegral!(immutable(ulong)));
    //assert(isIntegral!(shared(ulong)));
    //assert(isIntegral!(shared(const(ulong))));

    assert(!isIntegral!(float));
}

/**
 * Detect whether T is a built-in floating point type.
 */

template isFloatingPoint(T)
{
    enum bool isFloatingPoint = staticIndexOf!(Unqual!(T),
            float, double, real) >= 0;
}

unittest
{
    foreach (F; TypeTuple!(float, double, real))
    {
        F a = 5.5;
        static assert(isFloatingPoint!(typeof(a)));
        const F b = 5.5;
        static assert(isFloatingPoint!(typeof(b)));
        immutable F c = 5.5;
        static assert(isFloatingPoint!(typeof(c)));
    }
    foreach (T; TypeTuple!(int, long, char))
    {
        T a;
        static assert(!isFloatingPoint!(typeof(a)));
        const T b = 0;
        static assert(!isFloatingPoint!(typeof(b)));
        immutable T c = 0;
        static assert(!isFloatingPoint!(typeof(c)));
    }
}

/**
Detect whether T is a built-in numeric type (integral or floating
point).
 */

template isNumeric(T)
{
    enum bool isNumeric = isIntegral!(T) || isFloatingPoint!(T);
}

/**
Detect whether T is one of the built-in string types
 */

template isSomeString(T)
{
    enum isSomeString = isNarrowString!T || is(T : const(dchar[]));
}

unittest
{
    static assert(!isSomeString!(int));
    static assert(!isSomeString!(int[]));
    static assert(!isSomeString!(byte[]));
    static assert(isSomeString!(char[]));
    static assert(isSomeString!(dchar[]));
    static assert(isSomeString!(string));
    static assert(isSomeString!(wstring));
    static assert(isSomeString!(dstring));
    static assert(isSomeString!(char[4]));
}

template isNarrowString(T)
{
    enum isNarrowString = is(T : const(char[])) || is(T : const(wchar[]));
}

unittest
{
    static assert(!isNarrowString!(int));
    static assert(!isNarrowString!(int[]));
    static assert(!isNarrowString!(byte[]));
    static assert(isNarrowString!(char[]));
    static assert(!isNarrowString!(dchar[]));
    static assert(isNarrowString!(string));
    static assert(isNarrowString!(wstring));
    static assert(!isNarrowString!(dstring));
    static assert(isNarrowString!(char[4]));
}

/**
Detect whether T is one of the built-in character types
 */

template isSomeChar(T)
{
    enum isSomeChar = staticIndexOf!(Unqual!T, char, wchar, dchar) >= 0;
}

unittest
{
    static assert(!isSomeChar!(int));
    static assert(!isSomeChar!(int));
    static assert(!isSomeChar!(byte));
    static assert(isSomeChar!(char));
    static assert(isSomeChar!(dchar));
    static assert(!isSomeChar!(string));
    static assert(!isSomeChar!(wstring));
    static assert(!isSomeChar!(dstring));
    static assert(!isSomeChar!(char[4]));
}

/**
 * Detect whether T is an associative array type
 */

template isAssociativeArray(T)
{
    enum bool isAssociativeArray =
        is(typeof(T.keys)) && is(typeof(T.values));
}

static assert(!isAssociativeArray!(int));
static assert(!isAssociativeArray!(int[]));
static assert(isAssociativeArray!(int[int]));
static assert(isAssociativeArray!(int[string]));
static assert(isAssociativeArray!(invariant(char[5])[int]));

/**
 * Detect whether type T is a static array.
 */
template isStaticArray(T : U[N], U, size_t N)
{
    enum bool isStaticArray = true;
}

template isStaticArray(T)
{
    enum bool isStaticArray = false;
}

static assert (isStaticArray!(int[51]));
static assert (isStaticArray!(int[][2]));
static assert (isStaticArray!(char[][int][11]));
static assert (!isStaticArray!(const(int)[]));
static assert (!isStaticArray!(invariant(int)[]));
static assert (!isStaticArray!(const(int)[4][]));
static assert (!isStaticArray!(int[]));
static assert (!isStaticArray!(int[char]));
static assert (!isStaticArray!(int[1][]));
static assert (isStaticArray!(invariant char[13u]));
static assert (isStaticArray!(const(real)[1]));
static assert (isStaticArray!(const(real)[1][1]));
//static assert (isStaticArray!(typeof("string literal")));
static assert (isStaticArray!(void[0]));
static assert (!isStaticArray!(int[int]));
static assert (!isStaticArray!(int));

/**
 * Detect whether type T is a dynamic array.
 */
template isDynamicArray(T, U = void)
{
    enum bool isDynamicArray = false;
}

template isDynamicArray(T : U[], U)
{
  enum bool isDynamicArray = !isStaticArray!(T);
}

static assert(isDynamicArray!(int[]));
static assert(!isDynamicArray!(int[5]));

/**
 * Detect whether type T is an array.
 */
template isArray(T)
{
    enum bool isArray = isStaticArray!(T) || isDynamicArray!(T);
}

static assert(isArray!(int[]));
static assert(isArray!(int[5]));
static assert(!isArray!(uint));
static assert(!isArray!(uint[uint]));
static assert(isArray!(void[]));

/**
 * Detect whether type $(D T) is a pointer.
 */
template isPointer(T)
{
    static if (is(T P == U*, U))
    {
        enum bool isPointer = true;
    }
    else
    {
        enum bool isPointer = false;
    }
}

static assert(isPointer!(int*));
static assert(!isPointer!(uint));
static assert(!isPointer!(uint[uint]));
static assert(!isPointer!(char[]));
static assert(isPointer!(void*));

/**
 * Tells whether the tuple T is an expression tuple.
 */
template isExpressionTuple(T ...)
{
    static if (is(void function(T)))
        enum bool isExpressionTuple = false;
    else
        enum bool isExpressionTuple = true;
}

/**
 * Returns the corresponding unsigned type for T. T must be a numeric
 * integral type, otherwise a compile-time error occurs.
 */

template Unsigned(T) {
    static if (is(T == byte)) alias ubyte Unsigned;
    else static if (is(T == short)) alias ushort Unsigned;
    else static if (is(T == int)) alias uint Unsigned;
    else static if (is(T == long)) alias ulong Unsigned;
    else static if (is(T == ubyte)) alias ubyte Unsigned;
    else static if (is(T == ushort)) alias ushort Unsigned;
    else static if (is(T == uint)) alias uint Unsigned;
    else static if (is(T == ulong)) alias ulong Unsigned;
    else static if (is(T == char)) alias char Unsigned;
    else static if (is(T == wchar)) alias wchar Unsigned;
    else static if (is(T == dchar)) alias dchar Unsigned;
    else static if(is(T == enum))
    {
        static if (T.sizeof == 1) alias ubyte Unsigned;
        else static if (T.sizeof == 2) alias ushort Unsigned;
        else static if (T.sizeof == 4) alias uint Unsigned;
        else static if (T.sizeof == 8) alias ulong Unsigned;
        else static assert(false, "Type " ~ T.stringof
                           ~ " does not have an Unsigned counterpart");
    }
    else static if (is(T == immutable))
    {
        alias immutable(Unsigned!(Unqual!T)) Unsigned;
    }
    else static if (is(T == const))
    {
        alias const(Unsigned!(Unqual!T)) Unsigned;
    }
    else static assert(false, "Type " ~ T.stringof
                       ~ " does not have an Unsigned counterpart");
}

unittest
{
    alias Unsigned!(int) U;
    assert(is(U == uint));
    alias Unsigned!(const(int)) U1;
    assert(is(U1 == const(uint)), U1.stringof);
    alias Unsigned!(immutable(int)) U2;
    assert(is(U2 == immutable(uint)), U2.stringof);
    //struct S {}
    //alias Unsigned!(S) U2;
    //alias Unsigned!(double) U3;
}

/**
Returns the most negative value of the numeric type T.
*/

template mostNegative(T)
{
    static if (is(typeof(T.min_normal))) enum mostNegative = -T.max;
    else static if (T.min == 0) enum byte mostNegative = 0;
    else enum mostNegative = T.min;
}

unittest
{
    static assert(mostNegative!(float) == -float.max);
    static assert(mostNegative!(uint) == 0);
    static assert(mostNegative!(long) == long.min);
}

/**
Removes all qualifiers, if any, from type $(D T).

Example:
----
static assert(is(Unqual!(int) == int));
static assert(is(Unqual!(const int) == int));
static assert(is(Unqual!(immutable int) == int));
----
 */
template Unqual(T) { alias T Unqual; }
/// Ditto
template Unqual(T : const(U), U) { alias U Unqual; }
/// Ditto
template Unqual(T : immutable(U), U) { alias U Unqual; }
/// Ditto
//template Unqual(T : shared(U), U) { alias U Unqual; }

unittest
{
    static assert(is(Unqual!(int) == int));
    static assert(is(Unqual!(const int) == int));
    static assert(is(Unqual!(immutable int) == int));
    alias immutable(int[]) ImmIntArr;
    static assert(is(Unqual!(ImmIntArr) == immutable(int)[]));
}

/**
Evaluates to $(D TypeTuple!(F[T[0]], F[T[1]], ..., F[T[$ - 1]])).

Example:
----
alias staticMap!(Unqual, int, const int, immutable int) T;
static assert(is(T == TypeTuple!(int, int, int)));
----
 */
template staticMap(alias F, T...)
{
    static if (T.length == 1)
    {
        alias F!(T[0]) staticMap;
    }
    else
    {
        alias TypeTuple!(F!(T[0]), staticMap!(F, T[1 .. $])) staticMap;
    }
}

unittest
{
    alias staticMap!(Unqual, int, const int, immutable int) T;
    static assert(is(T == TypeTuple!(int, int, int)));
}

/**
Evaluates to $(D F[T[0]] && F[T[1]] && ... && F[T[$ - 1]]).

Example:
----
static assert(!allSatisfy!(isIntegral, int, double));
static assert(allSatisfy!(isIntegral, int, long));
----
 */
template allSatisfy(alias F, T...)
{
    static if (T.length == 1)
    {
        alias F!(T[0]) allSatisfy;
    }
    else
    {
        enum bool allSatisfy = F!(T[0]) && allSatisfy!(F, T[1 .. $]);
    }
}

unittest
{
    static assert(!allSatisfy!(isIntegral, int, double));
    static assert(allSatisfy!(isIntegral, int, long));
}

/**
Aliases itself to $(D T) if the boolean $(D condition) is $(D true)
and to $(D F) otherwise.

Example:
----
alias Select!(size_t.sizeof == 4, int, long) Int;
----
 */
template Select(bool condition, T, F)
{
    static if (condition) alias T Select;
    else alias F Select;
}

unittest
{
    static assert(is(Select!(true, int, long) == int));
    static assert(is(Select!(false, int, long) == long));
}

/**
If $(D cond) is $(D true), returns $(D a) without evaluating $(D
b). Otherwise, returns $(D b) without evaluating $(D a).
 */
A select(bool cond : true, A, B)(A a, lazy B b) { return a; }
/// Ditto
B select(bool cond : false, A, B)(lazy A a, B b) { return b; }
