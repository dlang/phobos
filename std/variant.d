// Written in the D programming language.

/**
 * This module implements a
 * $(LINK2 http://erdani.org/publications/cuj-04-2002.html,discriminated union)
 * type (a.k.a.
 * $(LINK2 http://en.wikipedia.org/wiki/Tagged_union,tagged union),
 * $(LINK2 http://en.wikipedia.org/wiki/Algebraic_data_type,algebraic type)).
 * Such types are useful
 * for type-uniform binary interfaces, interfacing with scripting
 * languages, and comfortable exploratory programming.
 *
 * Macros:
 *  WIKI = Phobos/StdVariant
 *
 * Synopsis:
 *
 * ----
 * Variant a; // Must assign before use, otherwise exception ensues
 * // Initialize with an integer; make the type int
 * Variant b = 42;
 * assert(b.type == typeid(int));
 * // Peek at the value
 * assert(b.peek!(int) !is null && *b.peek!(int) == 42);
 * // Automatically convert per language rules
 * auto x = b.get!(real);
 * // Assign any other type, including other variants
 * a = b;
 * a = 3.14;
 * assert(a.type == typeid(double));
 * // Implicit conversions work just as with built-in types
 * assert(a > b);
 * // Check for convertibility
 * assert(!a.convertsTo!(int)); // double not convertible to int
 * // Strings and all other arrays are supported
 * a = "now I'm a string";
 * assert(a == "now I'm a string");
 * a = new int[42]; // can also assign arrays
 * assert(a.length == 42);
 * a[5] = 7;
 * assert(a[5] == 7);
 * // Can also assign class values
 * class Foo {}
 * auto foo = new Foo;
 * a = foo;
 * assert(*a.peek!(Foo) == foo); // and full type information is preserved
 * ----
 *
 * Credits:
 *
 * Reviewed by Brad Roberts. Daniel Keep provided a detailed code
 * review prompting the following improvements: (1) better support for
 * arrays; (2) support for associative arrays; (3) friendlier behavior
 * towards the garbage collector.
 *
 * Copyright: Copyright Andrei Alexandrescu 2007 - 2009.
 * License:   <a href="http://www.boost.org/LICENSE_1_0.txt">Boost License 1.0</a>.
 * Authors:   $(WEB erdani.org, Andrei Alexandrescu)
 * Source:    $(PHOBOSSRC std/_variant.d)
 */
/*          Copyright Andrei Alexandrescu 2007 - 2009.
 * Distributed under the Boost Software License, Version 1.0.
 *    (See accompanying file LICENSE_1_0.txt or copy at
 *          http://www.boost.org/LICENSE_1_0.txt)
 */
module std.variant;

import std.traits, std.c.string, std.typetuple, std.conv, std.exception;
// version(unittest)
// {
    import std.exception, std.stdio;
//}

private template maxSize(T...)
{
    static if (T.length == 1)
    {
        enum size_t maxSize = T[0].sizeof;
    }
    else
    {
        enum size_t maxSize = T[0].sizeof >= maxSize!(T[1 .. $])
            ? T[0].sizeof : maxSize!(T[1 .. $]);
    }
}

struct This;

template AssociativeArray(T)
{
    enum bool valid = false;
    alias void Key;
    alias void Value;
}

template AssociativeArray(T : V[K], K, V)
{
    enum bool valid = true;
    alias K Key;
    alias V Value;
}

template This2Variant(V, T...)
{
    static if (T.length == 0) alias TypeTuple!() This2Variant;
    else static if (is(AssociativeArray!(T[0]).Key == This))
    {
        static if (is(AssociativeArray!(T[0]).Value == This))
            alias TypeTuple!(V[V],
                    This2Variant!(V, T[1 .. $])) This2Variant;
        else
            alias TypeTuple!(AssociativeArray!(T[0]).Value[V],
                    This2Variant!(V, T[1 .. $])) This2Variant;
    }
    else static if (is(AssociativeArray!(T[0]).Value == This))
        alias TypeTuple!(V[AssociativeArray!(T[0]).Key],
                This2Variant!(V, T[1 .. $])) This2Variant;
    else static if (is(T[0] == This[]))
        alias TypeTuple!(V[], This2Variant!(V, T[1 .. $])) This2Variant;
    else static if (is(T[0] == This*))
        alias TypeTuple!(V*, This2Variant!(V, T[1 .. $])) This2Variant;
    else
       alias TypeTuple!(T[0], This2Variant!(V, T[1 .. $])) This2Variant;
}

/**
 * $(D_PARAM VariantN) is a back-end type seldom used directly by user
 * code. Two commonly-used types using $(D_PARAM VariantN) as
 * back-end are:
 *
 * $(OL $(LI $(B Algebraic): A closed discriminated union with a
 * limited type universe (e.g., $(D_PARAM Algebraic!(int, double,
 * string)) only accepts these three types and rejects anything
 * else).) $(LI $(B Variant): An open discriminated union allowing an
 * unbounded set of types. The restriction is that the size of the
 * stored type cannot be larger than the largest built-in type. This
 * means that $(D_PARAM Variant) can accommodate all primitive types
 * and all user-defined types except for large $(D_PARAM struct)s.) )
 *
 * Both $(D_PARAM Algebraic) and $(D_PARAM Variant) share $(D_PARAM
 * VariantN)'s interface. (See their respective documentations below.)
 *
 * $(D_PARAM VariantN) is a discriminated union type parameterized
 * with the largest size of the types stored ($(D_PARAM maxDataSize))
 * and with the list of allowed types ($(D_PARAM AllowedTypes)). If
 * the list is empty, then any type up of size up to $(D_PARAM
 * maxDataSize) (rounded up for alignment) can be stored in a
 * $(D_PARAM VariantN) object.
 *
 */

struct VariantN(size_t maxDataSize, AllowedTypesX...)
{
    alias This2Variant!(VariantN, AllowedTypesX) AllowedTypes;

private:
    // Compute the largest practical size from maxDataSize
    struct SizeChecker
    {
        int function() fptr;
        ubyte[maxDataSize] data;
    }
    enum size = SizeChecker.sizeof - (int function()).sizeof;
    static assert(size >= (void*).sizeof);

    /** Tells whether a type $(D_PARAM T) is statically allowed for
     * storage inside a $(D_PARAM VariantN) object by looking
     * $(D_PARAM T) up in $(D_PARAM AllowedTypes). If $(D_PARAM
     * AllowedTypes) is empty, all types of size up to $(D_PARAM
     * maxSize) are allowed.
     */
    public template allowed(T)
    {
        enum bool allowed
            = is(T == VariantN)
            ||
            //T.sizeof <= size &&
            (AllowedTypes.length == 0 || staticIndexOf!(T, AllowedTypes) >= 0);
    }

    // Each internal operation is encoded with an identifier. See
    // the "handler" function below.
    enum OpID { getTypeInfo, get, compare, testConversion, toString,
            index, indexAssign, catAssign, copyOut, length,
            apply }

    // state
    sizediff_t function(OpID selector, ubyte[size]* store, void* data) fptr
        = &handler!(void);
    union
    {
        ubyte[size] store;
        // conservatively mark the region as pointers
        static if (size >= (void*).sizeof)
            void* p[size / (void*).sizeof];
    }

    // internals
    // Handler for an uninitialized value
    static sizediff_t handler(A : void)(OpID selector, ubyte[size]*, void* parm)
    {
        switch (selector)
        {
        case OpID.getTypeInfo:
            *cast(TypeInfo *) parm = typeid(A);
            break;
        case OpID.copyOut:
            auto target = cast(VariantN *) parm;
            target.fptr = &handler!(A);
            // no need to copy the data (it's garbage)
            break;
        case OpID.compare:
            auto rhs = cast(VariantN *) parm;
            return rhs.peek!(A)
                ? 0 // all uninitialized are equal
                : int.min; // uninitialized variant is not comparable otherwise
        case OpID.toString:
            string * target = cast(string*) parm;
            *target = "<Uninitialized VariantN>";
            break;
        case OpID.get:
        case OpID.testConversion:
        case OpID.index:
        case OpID.indexAssign:
        case OpID.catAssign:
        case OpID.length:
            throw new VariantException(
                "Attempt to use an uninitialized VariantN");
        default: assert(false, "Invalid OpID");
        }
        return 0;
    }

    // Handler for all of a type's operations
    static sizediff_t handler(A)(OpID selector, ubyte[size]* pStore, void* parm)
    {
        static A* getPtr(void* untyped)
        {
            if (untyped)
            {
                static if (A.sizeof <= size)
                    return cast(A*) untyped;
                else
                    return *cast(A**) untyped;
            }
            return null;
        }
        auto zis = getPtr(pStore);
        // Input: TypeInfo object
        // Output: target points to a copy of *me, if me was not null
        // Returns: true iff the A can be converted to the type represented
        // by the incoming TypeInfo
        static bool tryPutting(A* src, TypeInfo targetType, void* target)
        {
            alias TypeTuple!(A, ImplicitConversionTargets!A) AllTypes;
            foreach (T ; AllTypes)
            {
                if (targetType != typeid(T) &&
                        targetType != typeid(const(T)))
                {
                    static if (isImplicitlyConvertible!(T, immutable(T)))
                    {
                        if (targetType != typeid(immutable(T)))
                        {
                            continue;
                        }
                    }
                    else
                    {
                        continue;
                    }
                }
                // found!!!
                static if (is(typeof(*cast(T*) target = *src)))
                {
                    auto zat = cast(T*) target;
                    if (src)
                    {
                        assert(target, "target must be non-null");
                        *zat = *src;
                    }
                }
                else
                {
                    // type is not assignable
                    if (src) assert(false, A.stringof);
                }
                return true;
            }
            return false;
        }

        switch (selector)
        {
        case OpID.getTypeInfo:
            *cast(TypeInfo *) parm = typeid(A);
            break;
        case OpID.copyOut:
            auto target = cast(VariantN *) parm;
            assert(target);
            tryPutting(zis, typeid(A), cast(void*) getPtr(&target.store))
                || assert(false);
            target.fptr = &handler!(A);
            break;
        case OpID.get:
            return !tryPutting(zis, *cast(TypeInfo*) parm, parm);
        case OpID.testConversion:
            return !tryPutting(null, *cast(TypeInfo*) parm, null);
        case OpID.compare:
            auto rhsP = cast(VariantN *) parm;
            auto rhsType = rhsP.type;
            // Are we the same?
            if (rhsType == typeid(A))
            {
                // cool! Same type!
                auto rhsPA = getPtr(&rhsP.store);
                static if (is(typeof(A.init == A.init)))
                {
                    if (*rhsPA == *zis)
                    {
                        return 0;
                    }
                    static if (is(typeof(A.init < A.init)))
                    {
                        return *zis < *rhsPA ? -1 : 1;
                    }
                }
                else
                {
                    // type doesn't support ordering comparisons
                    return int.min;
                }
            } else if (rhsType == typeid(void))
            {
                // No support for ordering comparisons with
                // uninitialized vars
                return int.min;
            }
            VariantN temp;
            // Do I convert to rhs?
            if (tryPutting(zis, rhsType, &temp.store))
            {
                // cool, I do; temp's store contains my data in rhs's type!
                // also fix up its fptr
                temp.fptr = rhsP.fptr;
                // now lhsWithRhsType is a full-blown VariantN of rhs's type
                return temp.opCmp(*rhsP);
            }
            // Does rhs convert to zis?
            *cast(TypeInfo*) &temp.store = typeid(A);
            if (rhsP.fptr(OpID.get, &rhsP.store, &temp.store) == 0)
            {
                // cool! Now temp has rhs in my type!
                auto rhsPA = getPtr(&temp.store);
                static if (is(typeof(A.init == A.init)))
                {
                    if (*rhsPA == *zis)
                    {
                        return 0;
                    }
                    static if (is(typeof(A.init < A.init)))
                    {
                        return *zis < *rhsPA ? -1 : 1;
                    }
                }
                else
                {
                    // type doesn't support ordering comparisons
                    return int.min;
                }
            }
            return int.min; // dunno
        case OpID.toString:
            auto target = cast(string*) parm;
            static if (is(typeof(to!(string)(*zis))))
            {
                *target = to!(string)(*zis);
                break;
            }
            // TODO: The following test evaluates to true for shared objects.
            //       Use __traits for now until this is sorted out.
            // else static if (is(typeof((*zis).toString)))
            else static if (__traits(compiles, {(*zis).toString;}))
            {
                *target = (*zis).toString;
                break;
            }
            else
            {
                throw new VariantException(typeid(A), typeid(string));
            }

        case OpID.index:
            // Added allowed!(...) prompted by a bug report by Chris
            // Nicholson-Sauls.
            static if (isStaticArray!(A) && allowed!(typeof(A.init)))
            {
                enforce(0, "Not implemented");
            }
            static if (isDynamicArray!(A) && allowed!(typeof(A.init[0])))
            {
                // array type; input and output are the same VariantN
                auto result = cast(VariantN*) parm;
                size_t index = result.convertsTo!(int)
                    ? result.get!(int) : result.get!(size_t);
                *result = (*zis)[index];
                break;
            }
            else static if (isAssociativeArray!(A)
                    && allowed!(typeof(A.init.values[0])))
            {
                auto result = cast(VariantN*) parm;
                *result = (*zis)[result.get!(typeof(A.keys[0]))];
                break;
            }
            else
            {
                throw new VariantException(typeid(A), typeid(void[]));
            }

        case OpID.indexAssign:
            static if (isArray!(A) && is(typeof((*zis)[0] = (*zis)[0])))
            {
                // array type; result comes first, index comes second
                auto args = cast(VariantN*) parm;
                size_t index = args[1].convertsTo!(int)
                    ? args[1].get!(int) : args[1].get!(size_t);
                (*zis)[index] = args[0].get!(typeof((*zis)[0]));
                break;
            }
            else static if (isAssociativeArray!(A))
            {
                auto args = cast(VariantN*) parm;
                (*zis)[args[1].get!(typeof(A.keys[0]))]
                    = args[0].get!(typeof(A.values[0]));
                break;
            }
            else
            {
                throw new VariantException(typeid(A), typeid(void[]));
            }

        case OpID.catAssign:
            static if (is(typeof((*zis)[0])) && is(typeof((*zis) ~= *zis)))
            {
                // array type; parm is the element to append
                auto arg = cast(VariantN*) parm;
                alias typeof((*zis)[0]) E;
                if (arg[0].convertsTo!(E))
                {
                    // append one element to the array
                    (*zis) ~= [ arg[0].get!(E) ];
                }
                else
                {
                    // append a whole array to the array
                    (*zis) ~= arg[0].get!(A);
                }
                break;
            }
            else
            {
                throw new VariantException(typeid(A), typeid(void[]));
            }

        case OpID.length:
            static if (is(typeof(zis.length)))
            {
                return zis.length;
            }
            else
            {
                throw new VariantException(typeid(A), typeid(void[]));
            }

        case OpID.apply:
            assert(0);

        default: assert(false);
        }
        return 0;
    }

public:
    /** Constructs a $(D_PARAM VariantN) value given an argument of a
     * generic type. Statically rejects disallowed types.
     */

    this(T)(T value)
    {
        static assert(allowed!(T), "Cannot store a " ~ T.stringof
            ~ " in a " ~ VariantN.stringof);
        opAssign(value);
    }

    /** Assigns a $(D_PARAM VariantN) from a generic
     * argument. Statically rejects disallowed types. */

    VariantN opAssign(T)(T rhs)
    {
        //writeln(typeid(rhs));
        static assert(allowed!(T), "Cannot store a " ~ T.stringof
            ~ " in a " ~ VariantN.stringof ~ ". Valid types are "
                ~ AllowedTypes.stringof);
        static if (is(T : VariantN))
        {
            rhs.fptr(OpID.copyOut, &rhs.store, &this);
        }
        else static if (is(T : const(VariantN)))
        {
            static assert(false,
                    "Assigning Variant objects from const Variant"
                    " objects is currently not supported.");
        }
        else
        {
            static if (T.sizeof <= size)
            {
                // If T is a class we're only copying the reference, so it
                // should be safe to cast away shared so the memcpy will work.
                //
                // TODO: If a shared class has an atomic reference then using
                //       an atomic load may be more correct.  Just make sure
                //       to use the fastest approach for the load op.
                static if (is(T == class) && is(T == shared))
                    memcpy(&store, cast(const(void*)) &rhs, rhs.sizeof);
                else
                    memcpy(&store, &rhs, rhs.sizeof);
            }
            else
            {
                static if (__traits(compiles, {new T(rhs);}))
                {
                    auto p = new T(rhs);
                }
                else
                {
                    auto p = new T;
                    *p = rhs;
                }
                memcpy(&store, &p, p.sizeof);
            }
            fptr = &handler!(T);
        }
        return this;
    }

    /** Returns true if and only if the $(D_PARAM VariantN) object
     * holds a valid value (has been initialized with, or assigned
     * from, a valid value).
     * Example:
     * ----
     * Variant a;
     * assert(!a.hasValue);
     * Variant b;
     * a = b;
     * assert(!a.hasValue); // still no value
     * a = 5;
     * assert(a.hasValue);
     * ----
     */

    bool hasValue() const
    {
        // @@@BUG@@@ in compiler, the cast shouldn't be needed
        return cast(typeof(&handler!(void))) fptr != &handler!(void);
    }

    /**
     * If the $(D_PARAM VariantN) object holds a value of the
     * $(I exact) type $(D_PARAM T), returns a pointer to that
     * value. Otherwise, returns $(D_PARAM null). In cases
     * where $(D_PARAM T) is statically disallowed, $(D_PARAM
     * peek) will not compile.
     *
     * Example:
     * ----
     * Variant a = 5;
     * auto b = a.peek!(int);
     * assert(b !is null);
     * *b = 6;
     * assert(a == 6);
     * ----
     */
    T * peek(T)()
    {
        static if (!is(T == void))
            static assert(allowed!(T), "Cannot store a " ~ T.stringof
                    ~ " in a " ~ VariantN.stringof);
        return type == typeid(T) ? cast(T*) &store : null;
    }

    /**
     * Returns the $(D_PARAM typeid) of the currently held value.
     */

    TypeInfo type() const
    {
        TypeInfo result;
        fptr(OpID.getTypeInfo, null, &result);
        return result;
    }

    /**
     * Returns $(D_PARAM true) if and only if the $(D_PARAM VariantN)
     * object holds an object implicitly convertible to type $(D_PARAM
     * U). Implicit convertibility is defined as per
     * $(LINK2 std_traits.html#ImplicitConversionTargets,ImplicitConversionTargets).
     */

    bool convertsTo(T)()
    {
        TypeInfo info = typeid(T);
        return fptr(OpID.testConversion, null, &info) == 0;
    }

    // private T[] testing123(T)(T*);

    // /**
    //  * A workaround for the fact that functions cannot return
    //  * statically-sized arrays by value. Essentially $(D_PARAM
    //  * DecayStaticToDynamicArray!(T[N])) is an alias for $(D_PARAM
    //  * T[]) and $(D_PARAM DecayStaticToDynamicArray!(T)) is an alias
    //  * for $(D_PARAM T).
    //  */

    // template DecayStaticToDynamicArray(T)
    // {
    //     static if (isStaticArray!(T))
    //     {
    //         alias typeof(testing123(&T[0])) DecayStaticToDynamicArray;
    //     }
    //     else
    //     {
    //         alias T DecayStaticToDynamicArray;
    //     }
    // }

    // static assert(is(DecayStaticToDynamicArray!(immutable(char)[21]) ==
    //                  immutable(char)[]),
    //               DecayStaticToDynamicArray!(immutable(char)[21]).stringof);

    /**
     * Returns the value stored in the $(D_PARAM VariantN) object,
     * implicitly converted to the requested type $(D_PARAM T), in
     * fact $(D_PARAM DecayStaticToDynamicArray!(T)). If an implicit
     * conversion is not possible, throws a $(D_PARAM
     * VariantException).
     */

    T get(T)() if (!is(T == const))
    {
        union Buf
        {
            TypeInfo info;
            T result;
        };
        auto p = *cast(T**) &store;
        Buf buf = { typeid(T) };
        if (fptr(OpID.get, &store, &buf))
        {
            throw new VariantException(type, typeid(T));
        }
        return buf.result;
    }

    T get(T)() const if (is(T == const))
    {
        union Buf
        {
            TypeInfo info;
            Unqual!T result;
        };
        auto p = *cast(T**) &store;
        Buf buf = { typeid(T) };
        if (fptr(OpID.get, cast(typeof(&store)) &store, &buf))
        {
            throw new VariantException(type, typeid(T));
        }
        return buf.result;
    }

    /**
     * Returns the value stored in the $(D_PARAM VariantN) object,
     * explicitly converted (coerced) to the requested type $(D_PARAM
     * T). If $(D_PARAM T) is a string type, the value is formatted as
     * a string. If the $(D_PARAM VariantN) object is a string, a
     * parse of the string to type $(D_PARAM T) is attempted. If a
     * conversion is not possible, throws a $(D_PARAM
     * VariantException).
     */

    T coerce(T)()
    {
        static if (isNumeric!(T))
        {
            if (convertsTo!real())
            {
                // maybe optimize this fella; handle ints separately
                return to!T(get!real);
            }
            else if (convertsTo!(const(char)[]))
            {
                return to!T(get!(const(char)[]));
            }
            else
            {
                enforce(false, text("Type ", type(), " does not convert to ",
                                typeid(T)));
                assert(0);
            }
        }
        else static if (is(T : Object))
        {
            return to!(T)(get!(Object));
        }
        else static if (isSomeString!(T))
        {
            return to!(T)(toString);
        }
        else
        {
            // Fix for bug 1649
            static assert(false, "unsupported type for coercion");
        }
    }

    /**
     * Formats the stored value as a string.
     */

    string toString()
    {
        string result;
        fptr(OpID.toString, &store, &result) == 0 || assert(false);
        return result;
    }

    /**
     * Comparison for equality used by the "==" and "!="  operators.
     */

    // returns 1 if the two are equal
    bool opEquals(T)(T rhs)
    {
        static if (is(T == VariantN))
            alias rhs temp;
        else
            auto temp = Variant(rhs);
        return fptr(OpID.compare, &store, &temp) == 0;
    }

    /**
     * Ordering comparison used by the "<", "<=", ">", and ">="
     * operators. In case comparison is not sensible between the held
     * value and $(D_PARAM rhs), an exception is thrown.
     */

    int opCmp(T)(T rhs)
    {
        static if (is(T == VariantN))
            alias rhs temp;
        else
            auto temp = Variant(rhs);
        auto result = fptr(OpID.compare, &store, &temp);
        if (result == sizediff_t.min)
        {
            throw new VariantException(type, temp.type);
        }

        assert(result >= -1 && result <= 1);  // Should be true for opCmp.
        return cast(int) result;
    }

    /**
     * Computes the hash of the held value.
     */

    size_t toHash()
    {
        return type.getHash(&store);
    }

    private VariantN opArithmetic(T, string op)(T other)
    {
        VariantN result;
        static if (is(T == VariantN))
        {
            if (convertsTo!(uint) && other.convertsTo!(uint))
                result = mixin("get!(uint) " ~ op ~ " other.get!(uint)");
            else if (convertsTo!(int) && other.convertsTo!(int))
                result = mixin("get!(int) " ~ op ~ " other.get!(int)");
            else if (convertsTo!(ulong) && other.convertsTo!(ulong))
                result = mixin("get!(ulong) " ~ op ~ " other.get!(ulong)");
            else if (convertsTo!(long) && other.convertsTo!(long))
                result = mixin("get!(long) " ~ op ~ " other.get!(long)");
            else if (convertsTo!(double) && other.convertsTo!(double))
                result = mixin("get!(double) " ~ op ~ " other.get!(double)");
            else
                result = mixin("get!(real) " ~ op ~ " other.get!(real)");
        }
        else
        {
            if (is(typeof(T.max) : uint) && T.min == 0 && convertsTo!(uint))
                result = mixin("get!(uint) " ~ op ~ " other");
            else if (is(typeof(T.max) : int) && T.min < 0 && convertsTo!(int))
                result = mixin("get!(int) " ~ op ~ " other");
            else if (is(typeof(T.max) : ulong) && T.min == 0
                     && convertsTo!(ulong))
                result = mixin("get!(ulong) " ~ op ~ " other");
            else if (is(typeof(T.max) : long) && T.min < 0 && convertsTo!(long))
                result = mixin("get!(long) " ~ op ~ " other");
            else if (is(T : double) && convertsTo!(double))
                result = mixin("get!(double) " ~ op ~ " other");
            else
                result = mixin("get!(real) " ~ op ~ " other");
        }
        return result;
    }

    private VariantN opLogic(T, string op)(T other)
    {
        VariantN result;
        static if (is(T == VariantN))
        {
            if (convertsTo!(uint) && other.convertsTo!(uint))
                result = mixin("get!(uint) " ~ op ~ " other.get!(uint)");
            else if (convertsTo!(int) && other.convertsTo!(int))
                result = mixin("get!(int) " ~ op ~ " other.get!(int)");
            else if (convertsTo!(ulong) && other.convertsTo!(ulong))
                result = mixin("get!(ulong) " ~ op ~ " other.get!(ulong)");
            else
                result = mixin("get!(long) " ~ op ~ " other.get!(long)");
        }
        else
        {
            if (is(typeof(T.max) : uint) && T.min == 0 && convertsTo!(uint))
                result = mixin("get!(uint) " ~ op ~ " other");
            else if (is(typeof(T.max) : int) && T.min < 0 && convertsTo!(int))
                result = mixin("get!(int) " ~ op ~ " other");
            else if (is(typeof(T.max) : ulong) && T.min == 0
                     && convertsTo!(ulong))
                result = mixin("get!(ulong) " ~ op ~ " other");
            else
                result = mixin("get!(long) " ~ op ~ " other");
        }
        return result;
    }

    /**
     * Arithmetic between $(D_PARAM VariantN) objects and numeric
     * values. All arithmetic operations return a $(D_PARAM VariantN)
     * object typed depending on the types of both values
     * involved. The conversion rules mimic D's built-in rules for
     * arithmetic conversions.
     */

    // Adapted from http://www.prowiki.org/wiki4d/wiki.cgi?DanielKeep/Variant
    // arithmetic
    VariantN opAdd(T)(T rhs) { return opArithmetic!(T, "+")(rhs); }
    ///ditto
    VariantN opSub(T)(T rhs) { return opArithmetic!(T, "-")(rhs); }

    // Commenteed all _r versions for now because of ambiguities
    // arising when two Variants are used

    /////ditto
    // VariantN opSub_r(T)(T lhs)
    // {
    //     return VariantN(lhs).opArithmetic!(VariantN, "-")(this);
    // }
    ///ditto
    VariantN opMul(T)(T rhs) { return opArithmetic!(T, "*")(rhs); }
    ///ditto
    VariantN opDiv(T)(T rhs) { return opArithmetic!(T, "/")(rhs); }
    // ///ditto
    // VariantN opDiv_r(T)(T lhs)
    // {
    //     return VariantN(lhs).opArithmetic!(VariantN, "/")(this);
    // }
    ///ditto
    VariantN opMod(T)(T rhs) { return opArithmetic!(T, "%")(rhs); }
    // ///ditto
    // VariantN opMod_r(T)(T lhs)
    // {
    //     return VariantN(lhs).opArithmetic!(VariantN, "%")(this);
    // }
    ///ditto
    VariantN opAnd(T)(T rhs) { return opLogic!(T, "&")(rhs); }
    ///ditto
    VariantN opOr(T)(T rhs) { return opLogic!(T, "|")(rhs); }
    ///ditto
    VariantN opXor(T)(T rhs) { return opLogic!(T, "^")(rhs); }
    ///ditto
    VariantN opShl(T)(T rhs) { return opLogic!(T, "<<")(rhs); }
    // ///ditto
    // VariantN opShl_r(T)(T lhs)
    // {
    //     return VariantN(lhs).opLogic!(VariantN, "<<")(this);
    // }
    ///ditto
    VariantN opShr(T)(T rhs) { return opLogic!(T, ">>")(rhs); }
    // ///ditto
    // VariantN opShr_r(T)(T lhs)
    // {
    //     return VariantN(lhs).opLogic!(VariantN, ">>")(this);
    // }
    ///ditto
    VariantN opUShr(T)(T rhs) { return opLogic!(T, ">>>")(rhs); }
    // ///ditto
    // VariantN opUShr_r(T)(T lhs)
    // {
    //     return VariantN(lhs).opLogic!(VariantN, ">>>")(this);
    // }
    ///ditto
    VariantN opCat(T)(T rhs)
    {
        auto temp = this;
        temp ~= rhs;
        return temp;
    }
    // ///ditto
    // VariantN opCat_r(T)(T rhs)
    // {
    //     VariantN temp = rhs;
    //     temp ~= this;
    //     return temp;
    // }

    ///ditto
    VariantN opAddAssign(T)(T rhs)  { return this = this + rhs; }
    ///ditto
    VariantN opSubAssign(T)(T rhs)  { return this = this - rhs; }
    ///ditto
    VariantN opMulAssign(T)(T rhs)  { return this = this * rhs; }
    ///ditto
    VariantN opDivAssign(T)(T rhs)  { return this = this / rhs; }
    ///ditto
    VariantN opModAssign(T)(T rhs)  { return this = this % rhs; }
    ///ditto
    VariantN opAndAssign(T)(T rhs)  { return this = this & rhs; }
    ///ditto
    VariantN opOrAssign(T)(T rhs)   { return this = this | rhs; }
    ///ditto
    VariantN opXorAssign(T)(T rhs)  { return this = this ^ rhs; }
    ///ditto
    VariantN opShlAssign(T)(T rhs)  { return this = this << rhs; }
    ///ditto
    VariantN opShrAssign(T)(T rhs)  { return this = this >> rhs; }
    ///ditto
    VariantN opUShrAssign(T)(T rhs) { return this = this >>> rhs; }
    ///ditto
    VariantN opCatAssign(T)(T rhs)
    {
        auto toAppend = VariantN(rhs);
        fptr(OpID.catAssign, &store, &toAppend) == 0 || assert(false);
        return this;
    }

    /**
     * Array and associative array operations. If a $(D_PARAM
     * VariantN) contains an (associative) array, it can be indexed
     * into. Otherwise, an exception is thrown.
     *
     * Example:
     * ----
     * auto a = Variant(new int[10]);
     * a[5] = 42;
     * assert(a[5] == 42);
     * int[int] hash = [ 42:24 ];
     * a = hash;
     * assert(a[42] == 24);
     * ----
     *
     * Caveat:
     *
     * Due to limitations in current language, read-modify-write
     * operations $(D_PARAM op=) will not work properly:
     *
     * ----
     * Variant a = new int[10];
     * a[5] = 42;
     * a[5] += 8;
     * assert(a[5] == 50); // fails, a[5] is still 42
     * ----
     */
    VariantN opIndex(K)(K i)
    {
        auto result = VariantN(i);
        fptr(OpID.index, &store, &result) == 0 || assert(false);
        return result;
    }

    unittest
    {
        int[int] hash = [ 42:24 ];
        Variant v = hash;
        assert(v[42] == 24);
        v[42] = 5;
        assert(v[42] == 5);
    }

    /// ditto
    VariantN opIndexAssign(T, N)(T value, N i)
    {
        VariantN[2] args = [ VariantN(value), VariantN(i) ];
        fptr(OpID.indexAssign, &store, &args) == 0 || assert(false);
        return args[0];
    }

    /** If the $(D_PARAM VariantN) contains an (associative) array,
     * returns the length of that array. Otherwise, throws an
     * exception.
     */
    @property size_t length()
    {
        return cast(size_t) fptr(OpID.length, &store, null);
    }

    /**
       If the $(D VariantN) contains an array, applies $(D dg) to each
       element of the array in turn. Otherwise, throws an exception.
     */
    int opApply(Delegate)(scope Delegate dg) if (is(Delegate == delegate))
    {
        alias ParameterTypeTuple!(Delegate)[0] A;
        if (type() == typeid(A[]))
        {
            auto arr = get!(A[]);
            foreach (ref e; arr)
            {
                if (dg(e)) return 1;
            }
        }
        else static if (is(A == VariantN))
        {
            foreach (i; 0 .. length)
            {
                // @@@TODO@@@: find a better way to not confuse
                // clients who think they change values stored in the
                // Variant when in fact they are only changing tmp.
                auto tmp = this[i];
                debug scope(exit) assert(tmp == this[i]);
                if (dg(tmp)) return 1;
            }
        }
        else
        {
            enforce(false, text("Variant type ", type(),
                            " not iterable with values of type ",
                            A.stringof));
        }
        return 0;
    }
}

/**
 * Algebraic data type restricted to a closed set of possible
 * types. It's an alias for a $(D_PARAM VariantN) with an
 * appropriately-constructed maximum size. $(D_PARAM Algebraic) is
 * useful when it is desirable to restrict what a discriminated type
 * could hold to the end of defining simpler and more efficient
 * manipulation.
 *
 * Future additions to $(D_PARAM Algebraic) will allow compile-time
 * checking that all possible types are handled by user code,
 * eliminating a large class of errors.
 *
 * Bugs:
 *
 * Currently, $(D_PARAM Algebraic) does not allow recursive data
 * types. They will be allowed in a future iteration of the
 * implementation.
 *
 * Example:
 * ----
 * auto v = Algebraic!(int, double, string)(5);
 * assert(v.peek!(int));
 * v = 3.14;
 * assert(v.peek!(double));
 * // auto x = v.peek!(long); // won't compile, type long not allowed
 * // v = '1'; // won't compile, type char not allowed
 * ----
 */

template Algebraic(T...)
{
    alias VariantN!(maxSize!(T), T) Algebraic;
}

/**
$(D_PARAM Variant) is an alias for $(D_PARAM VariantN) instantiated
with the largest of $(D_PARAM creal), $(D_PARAM char[]), and $(D_PARAM
void delegate()). This ensures that $(D_PARAM Variant) is large enough
to hold all of D's predefined types, including all numeric types,
pointers, delegates, and class references.  You may want to use
$(D_PARAM VariantN) directly with a different maximum size either for
storing larger types, or for saving memory.
 */

alias VariantN!(maxSize!(creal, char[], void delegate())) Variant;

/**
 * Returns an array of variants constructed from $(D_PARAM args).
 * Example:
 * ----
 * auto a = variantArray(1, 3.14, "Hi!");
 * assert(a[1] == 3.14);
 * auto b = Variant(a); // variant array as variant
 * assert(b[1] == 3.14);
 * ----
 *
 * Code that needs functionality similar to the $(D_PARAM boxArray)
 * function in the $(D_PARAM std.boxer) module can achieve it like this:
 *
 * ----
 * // old
 * Box[] fun(...)
 * {
 *     ...
 *     return boxArray(_arguments, _argptr);
 * }
 * // new
 * Variant[] fun(T...)(T args)
 * {
 *     ...
 *     return variantArray(args);
 * }
 * ----
 *
 * This is by design. During construction the $(D_PARAM Variant) needs
 * static type information about the type being held, so as to store a
 * pointer to function for fast retrieval.
 */

Variant[] variantArray(T...)(T args)
{
    Variant[] result;
    foreach (arg; args)
    {
        result ~= Variant(arg);
    }
    return result;
}

/**
 * Thrown in three cases:
 *
 * $(OL $(LI An uninitialized Variant is used in any way except
 * assignment and $(D_PARAM hasValue);) $(LI A $(D_PARAM get) or
 * $(D_PARAM coerce) is attempted with an incompatible target type;)
 * $(LI A comparison between $(D_PARAM Variant) objects of
 * incompatible types is attempted.))
 *
 */

// @@@ BUG IN COMPILER. THE 'STATIC' BELOW SHOULD NOT COMPILE
static class VariantException : Exception
{
    /// The source type in the conversion or comparison
    TypeInfo source;
    /// The target type in the conversion or comparison
    TypeInfo target;
    this(string s)
    {
        super(s);
    }
    this(TypeInfo source, TypeInfo target)
    {
        super("Variant: attempting to use incompatible types "
                            ~ source.toString
                            ~ " and " ~ target.toString);
        this.source = source;
        this.target = target;
    }
}

unittest
{
    alias This2Variant!(char, int, This[int]) W1;
    alias TypeTuple!(int, char[int]) W2;
    static assert(is(W1 == W2));

    alias Algebraic!(void, string) var_t;
    var_t foo = "quux";
}

unittest
{
    // @@@BUG@@@
    // alias Algebraic!(real, This[], This[int], This[This]) A;
    // A v1, v2, v3;
    // v2 = 5.0L;
    // v3 = 42.0L;
    // //v1 = [ v2 ][];
    //  auto v = v1.peek!(A[]);
    // //writeln(v[0]);
    // v1 = [ 9 : v3 ];
    // //writeln(v1);
    // v1 = [ v3 : v3 ];
    // //writeln(v1);
}

unittest
{
    // try it with an oddly small size
    VariantN!(1) test;
    assert(test.size > 1);

    // variantArray tests
    auto heterogeneous = variantArray(1, 4.5, "hi");
    assert(heterogeneous.length == 3);
    auto variantArrayAsVariant = Variant(heterogeneous);
    assert(variantArrayAsVariant[0] == 1);
    assert(variantArrayAsVariant.length == 3);

    // array tests
    auto arr = Variant([1.2].dup);
    auto e = arr[0];
    assert(e == 1.2);
    arr[0] = 2.0;
    assert(arr[0] == 2);
    arr ~= 4.5;
    assert(arr[1] == 4.5);

    // general tests
    Variant a;
    auto b = Variant(5);
    assert(!b.peek!(real) && b.peek!(int));
    // assign
    a = *b.peek!(int);
    // comparison
    assert(a == b, a.type.toString ~ " " ~ b.type.toString);
    auto c = Variant("this is a string");
    assert(a != c);
    // comparison via implicit conversions
    a = 42; b = 42.0; assert(a == b);

    // try failing conversions
    bool failed = false;
    try
    {
        auto d = c.get!(int);
    }
    catch (Exception e)
    {
        //writeln(stderr, e.toString);
        failed = true;
    }
    assert(failed); // :o)

    // toString tests
    a = Variant(42); assert(a.toString == "42");
    a = Variant(42.22); assert(a.toString == "42.22");

    // coerce tests
    a = Variant(42.22); assert(a.coerce!(int) == 42);
    a = cast(short) 5; assert(a.coerce!(double) == 5);

    // Object tests
    class B1 {}
    class B2 : B1 {}
    a = new B2;
    assert(a.coerce!(B1) !is null);
    a = new B1;
// BUG: I can't get the following line to pass:
//    assert(collectException(a.coerce!(B2) is null));
    a = cast(Object) new B2; // lose static type info; should still work
    assert(a.coerce!(B2) !is null);

//     struct Big { int a[45]; }
//     a = Big.init;

    // hash
    assert(a.toHash != 0);
}

// tests adapted from
// http://www.dsource.org/projects/tango/browser/trunk/tango/core/Variant.d?rev=2601
unittest
{
    Variant v;

    assert(!v.hasValue);
    v = 42;
    assert( v.peek!(int) );
    assert( v.convertsTo!(long) );
    assert( v.get!(int) == 42 );
    assert( v.get!(long) == 42L );
    assert( v.get!(ulong) == 42uL );

    // should be string... @@@BUG IN COMPILER
    v = "Hello, World!"c;
    assert( v.peek!(string) );

    assert( v.get!(string) == "Hello, World!" );
    assert(!is(char[] : wchar[]));
    assert( !v.convertsTo!(wchar[]) );
    assert( v.get!(string) == "Hello, World!" );

    // Literal arrays are dynamically-typed
    v = cast(int[5]) [1,2,3,4,5];
    assert( v.peek!(int[5]) );
    assert( v.get!(int[5]) == [1,2,3,4,5] );

    {
        // @@@BUG@@@: array literals should have type T[], not T[5] (I guess)
        // v = [1,2,3,4,5];
        // assert( v.peek!(int[]) );
        // assert( v.get!(int[]) == [1,2,3,4,5] );
    }

    v = 3.1413;
    assert( v.peek!(double) );
    assert( v.convertsTo!(real) );
    //@@@ BUG IN COMPILER: DOUBLE SHOULD NOT IMPLICITLY CONVERT TO FLOAT
    assert( !v.convertsTo!(float) );
    assert( *v.peek!(double) == 3.1413 );

    auto u = Variant(v);
    assert( u.peek!(double) );
    assert( *u.peek!(double) == 3.1413 );

    // operators
    v = 38;
    assert( v + 4 == 42 );
    assert( 4 + v == 42 );
    assert( v - 4 == 34 );
    assert( Variant(4) - v == -34 );
    assert( v * 2 == 76 );
    assert( 2 * v == 76 );
    assert( v / 2 == 19 );
    assert( Variant(2) / v == 0 );
    assert( v % 2 == 0 );
    assert( Variant(2) % v == 2 );
    assert( (v & 6) == 6 );
    assert( (6 & v) == 6 );
    assert( (v | 9) == 47 );
    assert( (9 | v) == 47 );
    assert( (v ^ 5) == 35 );
    assert( (5 ^ v) == 35 );
    assert( v << 1 == 76 );
    assert( Variant(1) << Variant(2) == 4 );
    assert( v >> 1 == 19 );
    assert( Variant(4) >> Variant(2) == 1 );
    assert( Variant("abc") ~ "def" == "abcdef" );
    assert( Variant("abc") ~ Variant("def") == "abcdef" );

    v = 38;
    v += 4;
    assert( v == 42 );
    v = 38; v -= 4; assert( v == 34 );
    v = 38; v *= 2; assert( v == 76 );
    v = 38; v /= 2; assert( v == 19 );
    v = 38; v %= 2; assert( v == 0 );
    v = 38; v &= 6; assert( v == 6 );
    v = 38; v |= 9; assert( v == 47 );
    v = 38; v ^= 5; assert( v == 35 );
    v = 38; v <<= 1; assert( v == 76 );
    v = 38; v >>= 1; assert( v == 19 );
    v = 38; v += 1;  assert( v < 40 );

    v = "abc";
    v ~= "def";
    assert( v == "abcdef", *v.peek!(char[]) );
    assert( Variant(0) < Variant(42) );
    assert( Variant(42) > Variant(0) );
    assert( Variant(42) > Variant(0.1) );
    assert( Variant(42.1) > Variant(1) );
    assert( Variant(21) == Variant(21) );
    assert( Variant(0) != Variant(42) );
    assert( Variant("bar") == Variant("bar") );
    assert( Variant("foo") != Variant("bar") );

    {
        auto v1 = Variant(42);
        auto v2 = Variant("foo");
        auto v3 = Variant(1+2.0i);

        int[Variant] hash;
        hash[v1] = 0;
        hash[v2] = 1;
        hash[v3] = 2;

        assert( hash[v1] == 0 );
        assert( hash[v2] == 1 );
        assert( hash[v3] == 2 );
    }
    /+
    // @@@BUG@@@
    // dmd: mtype.c:3886: StructDeclaration* TypeAArray::getImpl(): Assertion `impl' failed.
    {
        int[char[]] hash;
        hash["a"] = 1;
        hash["b"] = 2;
        hash["c"] = 3;
        Variant vhash = hash;

        assert( vhash.get!(int[char[]])["a"] == 1 );
        assert( vhash.get!(int[char[]])["b"] == 2 );
        assert( vhash.get!(int[char[]])["c"] == 3 );
    }
    +/
}

unittest
{
    // bug 1558
    Variant va=1;
    Variant vb=-2;
    assert((va+vb).get!(int) == -1);
    assert((va-vb).get!(int) == 3);
}

unittest
{
    Variant a;
    a=5;
    Variant b;
    b=a;
    Variant[] c;
    c = variantArray(1, 2, 3.0, "hello", 4);
    assert(c[3] == "hello");
}

unittest
{
    Variant v = 5;
    assert (!__traits(compiles, v.coerce!(bool delegate())));
}


unittest
{
    struct Huge {
        real a, b, c, d, e, f, g;
    }

    Huge huge;
    huge.e = 42;
    Variant v;
    v = huge;  // Compile time error.
    assert(v.get!(Huge).e == 42);
}

unittest
{
    const x = Variant(42);
    auto y1 = x.get!(const int)();
    // @@@BUG@@@
    //auto y2 = x.get!(immutable int)();
}

// test iteration
unittest
{
    auto v = Variant([ 1, 2, 3, 4 ][]);
    auto j = 0;
    foreach (int i; v)
    {
        assert(i == ++j);
    }
    assert(j == 4);
}

// test convertibility
unittest
{
    auto v = Variant("abc".dup);
    assert(v.convertsTo!(char[]));
}

// http://d.puremagic.com/issues/show_bug.cgi?id=5424
unittest
{
    interface A {
        void func1();
    }
    static class AC: A {
        void func1() {
        }
    }

    A a = new AC();
    a.func1();
    Variant b = Variant(a);
}
