// Written in the D programming language.

/**
 * Templates which extract information about types and symbols at compile time.
 *
 * $(SCRIPT inhibitQuickIndex = 1;)
 *
 * $(DIVC quickindex,
 * $(BOOKTABLE ,
 * $(TR $(TH Category) $(TH Templates))
 * $(TR $(TD Symbol Name _traits) $(TD
 *           $(LREF fullyQualifiedName)
 *           $(LREF moduleName)
 *           $(LREF packageName)
 * ))
 * $(TR $(TD Function _traits) $(TD
 *           $(LREF arity)
 *           $(LREF functionAttributes)
 *           $(LREF functionLinkage)
 *           $(LREF FunctionTypeOf)
 *           $(LREF isSafe)
 *           $(LREF isUnsafe)
 *           $(LREF ParameterDefaultValueTuple)
 *           $(LREF ParameterIdentifierTuple)
 *           $(LREF ParameterStorageClassTuple)
 *           $(LREF ParameterTypeTuple)
 *           $(LREF ReturnType)
 *           $(LREF SetFunctionAttributes)
 *           $(LREF variadicFunctionStyle)
 * ))
 * $(TR $(TD Aggregate Type _traits) $(TD
 *           $(LREF BaseClassesTuple)
 *           $(LREF BaseTypeTuple)
 *           $(LREF classInstanceAlignment)
 *           $(LREF EnumMembers)
 *           $(LREF FieldNameTuple)
 *           $(LREF FieldTypeTuple)
 *           $(LREF hasAliasing)
 *           $(LREF hasElaborateAssign)
 *           $(LREF hasElaborateCopyConstructor)
 *           $(LREF hasElaborateDestructor)
 *           $(LREF hasIndirections)
 *           $(LREF hasMember)
 *           $(LREF hasNested)
 *           $(LREF hasUnsharedAliasing)
 *           $(LREF InterfacesTuple)
 *           $(LREF isNested)
 *           $(LREF MemberFunctionsTuple)
 *           $(LREF RepresentationTypeTuple)
 *           $(LREF TemplateArgsOf)
 *           $(LREF TemplateOf)
 *           $(LREF TransitiveBaseTypeTuple)
 * ))
 * $(TR $(TD Type Conversion) $(TD
 *           $(LREF CommonType)
 *           $(LREF ImplicitConversionTargets)
 *           $(LREF isAssignable)
 *           $(LREF isCovariantWith)
 *           $(LREF isImplicitlyConvertible)
 * ))
 * <!--$(TR $(TD SomethingTypeOf) $(TD
 *           $(LREF BooleanTypeOf)
 *           $(LREF IntegralTypeOf)
 *           $(LREF FloatingPointTypeOf)
 *           $(LREF NumericTypeOf)
 *           $(LREF UnsignedTypeOf)
 *           $(LREF SignedTypeOf)
 *           $(LREF CharTypeOf)
 *           $(LREF StaticArrayTypeOf)
 *           $(LREF DynamicArrayTypeOf)
 *           $(LREF ArrayTypeOf)
 *           $(LREF StringTypeOf)
 *           $(LREF AssocArrayTypeOf)
 *           $(LREF BuiltinTypeOf)
 * ))-->
 * $(TR $(TD Categories of types) $(TD
 *           $(LREF isAggregateType)
 *           $(LREF isArray)
 *           $(LREF isAssociativeArray)
 *           $(LREF isBasicType)
 *           $(LREF isBoolean)
 *           $(LREF isBuiltinType)
 *           $(LREF isDynamicArray)
 *           $(LREF isFloatingPoint)
 *           $(LREF isIntegral)
 *           $(LREF isNarrowString)
 *           $(LREF isNumeric)
 *           $(LREF isPointer)
 *           $(LREF isScalarType)
 *           $(LREF isSigned)
 *           $(LREF isSomeChar)
 *           $(LREF isSomeString)
 *           $(LREF isStaticArray)
 *           $(LREF isUnsigned)
 * ))
 * $(TR $(TD Type behaviours) $(TD
 *           $(LREF isAbstractClass)
 *           $(LREF isAbstractFunction)
 *           $(LREF isCallable)
 *           $(LREF isDelegate)
 *           $(LREF isExpressionTuple)
 *           $(LREF isFinalClass)
 *           $(LREF isFinalFunction)
 *           $(LREF isFunctionPointer)
 *           $(LREF isInstanceOf)
 *           $(LREF isIterable)
 *           $(LREF isMutable)
 *           $(LREF isSomeFunction)
 *           $(LREF isTypeTuple)
 * ))
 * $(TR $(TD General Types) $(TD
 *           $(LREF ForeachType)
 *           $(LREF KeyType)
 *           $(LREF Largest)
 *           $(LREF mostNegative)
 *           $(LREF OriginalType)
 *           $(LREF PointerTarget)
 *           $(LREF Signed)
 *           $(LREF Unqual)
 *           $(LREF Unsigned)
 *           $(LREF ValueType)
 * ))
 * $(TR $(TD Misc) $(TD
 *           $(LREF mangledName)
 *           $(LREF Select)
 *           $(LREF select)
 * ))
 * )
 * )
 *
 * Macros:
 *  WIKI = Phobos/StdTraits
 *
 * Copyright: Copyright Digital Mars 2005 - 2009.
 * License:   $(WEB www.boost.org/LICENSE_1_0.txt, Boost License 1.0).
 * Authors:   $(WEB digitalmars.com, Walter Bright),
 *            Tomasz Stachowiak ($(D isExpressionTuple)),
 *            $(WEB erdani.org, Andrei Alexandrescu),
 *            Shin Fujishiro,
 *            $(WEB octarineparrot.com, Robert Clipsham),
 *            $(WEB klickverbot.at, David Nadlinger),
 *            Kenji Hara,
 *            Shoichi Kato
 * Source:    $(PHOBOSSRC std/_traits.d)
 */
/*          Copyright Digital Mars 2005 - 2009.
 * Distributed under the Boost Software License, Version 1.0.
 *    (See accompanying file LICENSE_1_0.txt or copy at
 *          http://www.boost.org/LICENSE_1_0.txt)
 */
module std.traits;

import std.typetuple;

///////////////////////////////////////////////////////////////////////////////
// Functions
///////////////////////////////////////////////////////////////////////////////

// Petit demangler
// (this or similar thing will eventually go to std.demangle if necessary
//  ctfe stuffs are available)
private
{
    struct Demangle(T)
    {
        T       value;  // extracted information
        string  rest;
    }

    /* Demangles mstr as the storage class part of Argument. */
    Demangle!uint demangleParameterStorageClass(string mstr)
    {
        uint pstc = 0; // parameter storage class

        // Argument --> Argument2 | M Argument2
        if (mstr.length > 0 && mstr[0] == 'M')
        {
            pstc |= ParameterStorageClass.scope_;
            mstr  = mstr[1 .. $];
        }

        // Argument2 --> Type | J Type | K Type | L Type
        ParameterStorageClass stc2;

        switch (mstr.length ? mstr[0] : char.init)
        {
            case 'J': stc2 = ParameterStorageClass.out_;  break;
            case 'K': stc2 = ParameterStorageClass.ref_;  break;
            case 'L': stc2 = ParameterStorageClass.lazy_; break;
            default : break;
        }
        if (stc2 != ParameterStorageClass.init)
        {
            pstc |= stc2;
            mstr  = mstr[1 .. $];
        }

        return Demangle!uint(pstc, mstr);
    }

    /* Demangles mstr as FuncAttrs. */
    Demangle!uint demangleFunctionAttributes(string mstr)
    {
        enum LOOKUP_ATTRIBUTE =
        [
            'a': FunctionAttribute.pure_,
            'b': FunctionAttribute.nothrow_,
            'c': FunctionAttribute.ref_,
            'd': FunctionAttribute.property,
            'e': FunctionAttribute.trusted,
            'f': FunctionAttribute.safe,
            'i': FunctionAttribute.nogc
        ];
        uint atts = 0;

        // FuncAttrs --> FuncAttr | FuncAttr FuncAttrs
        // FuncAttr  --> empty | Na | Nb | Nc | Nd | Ne | Nf
        // except 'Ng' == inout, because it is a qualifier of function type
        while (mstr.length >= 2 && mstr[0] == 'N' && mstr[1] != 'g')
        {
            if (FunctionAttribute att = LOOKUP_ATTRIBUTE[ mstr[1] ])
            {
                atts |= att;
                mstr  = mstr[2 .. $];
            }
            else assert(0);
        }
        return Demangle!uint(atts, mstr);
    }

    alias IntegralTypeList      = TypeTuple!(byte, ubyte, short, ushort, int, uint, long, ulong);
    alias SignedIntTypeList     = TypeTuple!(byte, short, int, long);
    alias UnsignedIntTypeList   = TypeTuple!(ubyte, ushort, uint, ulong);
    alias FloatingPointTypeList = TypeTuple!(float, double, real);
    alias ImaginaryTypeList     = TypeTuple!(ifloat, idouble, ireal);
    alias ComplexTypeList       = TypeTuple!(cfloat, cdouble, creal);
    alias NumericTypeList       = TypeTuple!(IntegralTypeList, FloatingPointTypeList);
    alias CharTypeList          = TypeTuple!(char, wchar, dchar);
}
package
{
    // Add specific qualifier to the given type T
    template MutableOf(T)     { alias MutableOf     =              T  ; }
    template InoutOf(T)       { alias InoutOf       =        inout(T) ; }
    template ConstOf(T)       { alias ConstOf       =        const(T) ; }
    template SharedOf(T)      { alias SharedOf      =       shared(T) ; }
    template SharedInoutOf(T) { alias SharedInoutOf = shared(inout(T)); }
    template SharedConstOf(T) { alias SharedConstOf = shared(const(T)); }
    template ImmutableOf(T)   { alias ImmutableOf   =    immutable(T) ; }

    unittest
    {
        static assert(is(    MutableOf!int ==              int));
        static assert(is(      InoutOf!int ==        inout int));
        static assert(is(      ConstOf!int ==        const int));
        static assert(is(     SharedOf!int == shared       int));
        static assert(is(SharedInoutOf!int == shared inout int));
        static assert(is(SharedConstOf!int == shared const int));
        static assert(is(  ImmutableOf!int ==    immutable int));
    }

    // Get qualifier template from the given type T
    template QualifierOf(T)
    {
             static if (is(T == shared(const U), U)) alias QualifierOf = SharedConstOf;
        else static if (is(T ==        const U , U)) alias QualifierOf = ConstOf;
        else static if (is(T == shared(inout U), U)) alias QualifierOf = SharedInoutOf;
        else static if (is(T ==        inout U , U)) alias QualifierOf = InoutOf;
        else static if (is(T ==    immutable U , U)) alias QualifierOf = ImmutableOf;
        else static if (is(T ==       shared U , U)) alias QualifierOf = SharedOf;
        else                                         alias QualifierOf = MutableOf;
    }

    unittest
    {
        alias Qual1 = QualifierOf!(             int);   static assert(is(Qual1!long ==              long));
        alias Qual2 = QualifierOf!(       inout int);   static assert(is(Qual2!long ==        inout long));
        alias Qual3 = QualifierOf!(       const int);   static assert(is(Qual3!long ==        const long));
        alias Qual4 = QualifierOf!(shared       int);   static assert(is(Qual4!long == shared       long));
        alias Qual5 = QualifierOf!(shared inout int);   static assert(is(Qual5!long == shared inout long));
        alias Qual6 = QualifierOf!(shared const int);   static assert(is(Qual6!long == shared const long));
        alias Qual7 = QualifierOf!(   immutable int);   static assert(is(Qual7!long ==    immutable long));
    }
}

version(unittest)
{
    alias TypeQualifierList = TypeTuple!(MutableOf, ConstOf, SharedOf, SharedConstOf, ImmutableOf);

    struct SubTypeOf(T)
    {
        T val;
        alias val this;
    }
}

private alias parentOf(alias sym) = Identity!(__traits(parent, sym));
private alias parentOf(alias sym : T!Args, alias T, Args...) = Identity!(__traits(parent, T));

/**
 * Get the full package name for the given symbol.
 */
template packageName(alias T)
{
    import std.algorithm : startsWith;

    static if (__traits(compiles, parentOf!T))
        enum parent = packageName!(parentOf!T);
    else
        enum string parent = null;

    static if (T.stringof.startsWith("package "))
        enum packageName = (parent.length ? parent ~ '.' : "") ~ T.stringof[8 .. $];
    else static if (parent)
        enum packageName = parent;
    else
        static assert(false, T.stringof ~ " has no parent");
}

///
unittest
{
    import std.traits;
    static assert(packageName!packageName == "std");
}

unittest
{
    import std.array;

    // Commented out because of dmd @@@BUG8922@@@
    // static assert(packageName!std == "std");  // this package (currently: "std.std")
    static assert(packageName!(std.traits) == "std");     // this module
    static assert(packageName!packageName == "std");      // symbol in this module
    static assert(packageName!(std.array) == "std");  // other module from same package

    import core.sync.barrier;  // local import
    static assert(packageName!core == "core");
    static assert(packageName!(core.sync) == "core.sync");
    static assert(packageName!Barrier == "core.sync");

    struct X12287(T) { T i; }
    static assert(packageName!(X12287!int.i) == "std");
}

version (none) version(unittest) //Please uncomment me when changing packageName to test global imports
{
    import core.sync.barrier;  // global import
    static assert(packageName!core == "core");
    static assert(packageName!(core.sync) == "core.sync");
    static assert(packageName!Barrier == "core.sync");
}

/**
 * Get the module name (including package) for the given symbol.
 */
template moduleName(alias T)
{
    import std.algorithm : startsWith;

    static assert(!T.stringof.startsWith("package "), "cannot get the module name for a package");

    static if (T.stringof.startsWith("module "))
    {
        static if (__traits(compiles, packageName!T))
            enum packagePrefix = packageName!T ~ '.';
        else
            enum packagePrefix = "";

        enum moduleName = packagePrefix ~ T.stringof[7..$];
    }
    else
        alias moduleName = moduleName!(parentOf!T); // If you use enum, it will cause compiler ICE
}

///
unittest
{
    import std.traits;
    static assert(moduleName!moduleName == "std.traits");
}

unittest
{
    import std.array;

    static assert(!__traits(compiles, moduleName!std));
    static assert(moduleName!(std.traits) == "std.traits");            // this module
    static assert(moduleName!moduleName == "std.traits");              // symbol in this module
    static assert(moduleName!(std.array) == "std.array");      // other module
    static assert(moduleName!(std.array.array) == "std.array");  // symbol in other module

    import core.sync.barrier;  // local import
    static assert(!__traits(compiles, moduleName!(core.sync)));
    static assert(moduleName!(core.sync.barrier) == "core.sync.barrier");
    static assert(moduleName!Barrier == "core.sync.barrier");

    struct X12287(T) { T i; }
    static assert(moduleName!(X12287!int.i) == "std.traits");
}

version (none) version(unittest) //Please uncomment me when changing moduleName to test global imports
{
    import core.sync.barrier;  // global import
    static assert(!__traits(compiles, moduleName!(core.sync)));
    static assert(moduleName!(core.sync.barrier) == "core.sync.barrier");
    static assert(moduleName!Barrier == "core.sync.barrier");
}

/***
 * Get the fully qualified name of a type or a symbol. Can act as an intelligent type/symbol to string  converter.

Example:
-----------------
module myModule;
struct MyStruct {}
static assert(fullyQualifiedName!(const MyStruct[]) == "const(myModule.MyStruct[])");
-----------------
*/
template fullyQualifiedName(T...)
    if (T.length == 1)
{

    static if (is(T))
        enum fullyQualifiedName = fqnType!(T[0], false, false, false, false);
    else
        enum fullyQualifiedName = fqnSym!(T[0]);
}

///
unittest
{
    static assert(fullyQualifiedName!fullyQualifiedName == "std.traits.fullyQualifiedName");
}

version(unittest)
{
    // Used for both fqnType and fqnSym unittests
    private struct QualifiedNameTests
    {
        struct Inner
        {
        }

        ref const(Inner[string]) func( ref Inner var1, lazy scope string var2 );
        Inner inoutFunc(inout Inner) inout;
        shared(const(Inner[string])[]) data;
        const Inner delegate(double, string) @safe nothrow deleg;
        inout(int) delegate(inout int) inout inoutDeleg;
        Inner function(out double, string) funcPtr;
        extern(C) Inner function(double, string) cFuncPtr;

        extern(C) void cVarArg(int, ...);
        void dVarArg(...);
        void dVarArg2(int, ...);
        void typesafeVarArg(int[] ...);

        Inner[] array;
        Inner[16] sarray;
        Inner[Inner] aarray;
        const(Inner[const(Inner)]) qualAarray;

        shared(immutable(Inner) delegate(ref double, scope string) const shared @trusted nothrow) attrDeleg;

        struct Data(T) { int x; }
        void tfunc(T...)(T args) {}

        template Inst(alias A) { int x; }

        class Test12309(T, int x, string s) {}
    }

    private enum QualifiedEnum
    {
        a = 42
    }
}

private template fqnSym(alias T : X!A, alias X, A...)
{
    template fqnTuple(T...)
    {
        static if (T.length == 0)
            enum fqnTuple = "";
        else static if (T.length == 1)
        {
            static if (isExpressionTuple!T)
                enum fqnTuple = T[0].stringof;
            else
                enum fqnTuple = fullyQualifiedName!(T[0]);
        }
        else
            enum fqnTuple = fqnTuple!(T[0]) ~ ", " ~ fqnTuple!(T[1 .. $]);
    }

    enum fqnSym =
        fqnSym!(__traits(parent, X)) ~
        '.' ~ __traits(identifier, X) ~ "!(" ~ fqnTuple!A ~ ")";
}

private template fqnSym(alias T)
{
    static if (__traits(compiles, __traits(parent, T)))
        enum parentPrefix = fqnSym!(__traits(parent, T)) ~ '.';
    else
        enum parentPrefix = null;

    static string adjustIdent(string s)
    {
        import std.algorithm : skipOver, findSplit;

        if (s.skipOver("package ") || s.skipOver("module "))
            return s;
        return s.findSplit("(")[0];
    }
    enum fqnSym = parentPrefix ~ adjustIdent(__traits(identifier, T));
}

unittest
{
    alias fqn = fullyQualifiedName;

    // Make sure those 2 are the same
    static assert(fqnSym!fqn == fqn!fqn);

    static assert(fqn!fqn == "std.traits.fullyQualifiedName");

    alias qnTests = QualifiedNameTests;
    enum prefix = "std.traits.QualifiedNameTests.";
    static assert(fqn!(qnTests.Inner)           == prefix ~ "Inner");
    static assert(fqn!(qnTests.func)            == prefix ~ "func");
    static assert(fqn!(qnTests.Data!int)        == prefix ~ "Data!(int)");
    static assert(fqn!(qnTests.Data!int.x)      == prefix ~ "Data!(int).x");
    static assert(fqn!(qnTests.tfunc!(int[]))   == prefix ~ "tfunc!(int[])");
    static assert(fqn!(qnTests.Inst!(Object))   == prefix ~ "Inst!(object.Object)");
    static assert(fqn!(qnTests.Inst!(Object).x) == prefix ~ "Inst!(object.Object).x");

    static assert(fqn!(qnTests.Test12309!(int, 10, "str"))
                                                == prefix ~ "Test12309!(int, 10, \"str\")");

    import core.sync.barrier;
    static assert(fqn!Barrier == "core.sync.barrier.Barrier");
}

private template fqnType(T,
    bool alreadyConst, bool alreadyImmutable, bool alreadyShared, bool alreadyInout)
{
    import std.format : format;

    // Convenience tags
    enum {
        _const = 0,
        _immutable = 1,
        _shared = 2,
        _inout = 3
    }

    alias qualifiers   = TypeTuple!(is(T == const), is(T == immutable), is(T == shared), is(T == inout));
    alias noQualifiers = TypeTuple!(false, false, false, false);

    string storageClassesString(uint psc)() @property
    {
        alias PSC = ParameterStorageClass;

        return format("%s%s%s%s",
            psc & PSC.scope_ ? "scope " : "",
            psc & PSC.out_ ? "out " : "",
            psc & PSC.ref_ ? "ref " : "",
            psc & PSC.lazy_ ? "lazy " : ""
        );
    }

    string parametersTypeString(T)() @property
    {
        alias parameters   = ParameterTypeTuple!(T);
        alias parameterStC = ParameterStorageClassTuple!(T);

        enum variadic = variadicFunctionStyle!T;
        static if (variadic == Variadic.no)
            enum variadicStr = "";
        else static if (variadic == Variadic.c)
            enum variadicStr = ", ...";
        else static if (variadic == Variadic.d)
            enum variadicStr = parameters.length ? ", ..." : "...";
        else static if (variadic == Variadic.typesafe)
            enum variadicStr = " ...";
        else
            static assert(0, "New variadic style has been added, please update fullyQualifiedName implementation");

        static if (parameters.length)
        {
            import std.algorithm : map;
            import std.range : join, zip;

            string result = join(
                map!(a => format("%s%s", a[0], a[1]))(
                    zip([staticMap!(storageClassesString, parameterStC)],
                        [staticMap!(fullyQualifiedName, parameters)])
                ),
                ", "
            );

            return result ~= variadicStr;
        }
        else
            return variadicStr;
    }

    string linkageString(T)() @property
    {
        enum linkage = functionLinkage!T;

        if (linkage != "D")
            return format("extern(%s) ", linkage);
        else
            return "";
    }

    string functionAttributeString(T)() @property
    {
        alias FA = FunctionAttribute;
        enum attrs = functionAttributes!T;

        static if (attrs == FA.none)
            return "";
        else
            return format("%s%s%s%s%s%s",
                 attrs & FA.pure_ ? " pure" : "",
                 attrs & FA.nothrow_ ? " nothrow" : "",
                 attrs & FA.ref_ ? " ref" : "",
                 attrs & FA.property ? " @property" : "",
                 attrs & FA.trusted ? " @trusted" : "",
                 attrs & FA.safe ? " @safe" : ""
            );
    }

    string addQualifiers(string typeString,
        bool addConst, bool addImmutable, bool addShared, bool addInout)
    {
        auto result = typeString;
        if (addShared)
        {
            result = format("shared(%s)", result);
        }
        if (addConst || addImmutable || addInout)
        {
            result = format("%s(%s)",
                addConst ? "const" :
                    addImmutable ? "immutable" : "inout",
                result
            );
        }
        return result;
    }

    // Convenience template to avoid copy-paste
    template chain(string current)
    {
        enum chain = addQualifiers(current,
            qualifiers[_const]     && !alreadyConst,
            qualifiers[_immutable] && !alreadyImmutable,
            qualifiers[_shared]    && !alreadyShared,
            qualifiers[_inout]     && !alreadyInout);
    }

    static if (is(T == string))
    {
        enum fqnType = "string";
    }
    else static if (is(T == wstring))
    {
        enum fqnType = "wstring";
    }
    else static if (is(T == dstring))
    {
        enum fqnType = "dstring";
    }
    else static if (isBasicType!T && !is(T == enum))
    {
        enum fqnType = chain!((Unqual!T).stringof);
    }
    else static if (isAggregateType!T || is(T == enum))
    {
        enum fqnType = chain!(fqnSym!T);
    }
    else static if (isStaticArray!T)
    {
        import std.conv;

        enum fqnType = chain!(
            format("%s[%s]", fqnType!(typeof(T.init[0]), qualifiers), T.length)
        );
    }
    else static if (isArray!T)
    {
        enum fqnType = chain!(
            format("%s[]", fqnType!(typeof(T.init[0]), qualifiers))
        );
    }
    else static if (isAssociativeArray!T)
    {
        enum fqnType = chain!(
            format("%s[%s]", fqnType!(ValueType!T, qualifiers), fqnType!(KeyType!T, noQualifiers))
        );
    }
    else static if (isSomeFunction!T)
    {
        static if (is(T F == delegate))
        {
            enum qualifierString = format("%s%s",
                is(F == shared) ? " shared" : "",
                is(F == inout) ? " inout" :
                is(F == immutable) ? " immutable" :
                is(F == const) ? " const" : ""
            );
            enum formatStr = "%s%s delegate(%s)%s%s";
            enum fqnType = chain!(
                format(formatStr, linkageString!T, fqnType!(ReturnType!T, noQualifiers),
                    parametersTypeString!(T), functionAttributeString!T, qualifierString)
            );
        }
        else
        {
            static if (isFunctionPointer!T)
                enum formatStr = "%s%s function(%s)%s";
            else
                enum formatStr = "%s%s(%s)%s";

            enum fqnType = chain!(
                format(formatStr, linkageString!T, fqnType!(ReturnType!T, noQualifiers),
                    parametersTypeString!(T), functionAttributeString!T)
            );
        }
    }
    else static if (isPointer!T)
    {
        enum fqnType = chain!(
            format("%s*", fqnType!(PointerTarget!T, qualifiers))
        );
    }
    else static if (is(T : __vector(V[N]), V, size_t N))
    {
        enum fqnType = chain!(
            format("__vector(%s[%s])", fqnType!(V, qualifiers), N)
        );
   }
    else
        // In case something is forgotten
        static assert(0, "Unrecognized type " ~ T.stringof ~ ", can't convert to fully qualified string");
}

unittest
{
    import std.format : format;
    alias fqn = fullyQualifiedName;

    // Verify those 2 are the same for simple case
    alias Ambiguous = const(QualifiedNameTests.Inner);
    static assert(fqn!Ambiguous == fqnType!(Ambiguous, false, false, false, false));

    // Main tests
    enum inner_name = "std.traits.QualifiedNameTests.Inner";
    with (QualifiedNameTests)
    {
        // Special cases
        static assert(fqn!(string) == "string");
        static assert(fqn!(wstring) == "wstring");
        static assert(fqn!(dstring) == "dstring");

        // Basic qualified name
        static assert(fqn!(Inner) == inner_name);
        static assert(fqn!(QualifiedEnum) == "std.traits.QualifiedEnum"); // type
        static assert(fqn!(QualifiedEnum.a) == "std.traits.QualifiedEnum.a"); // symbol

        // Array types
        static assert(fqn!(typeof(array)) == format("%s[]", inner_name));
        static assert(fqn!(typeof(sarray)) == format("%s[16]", inner_name));
        static assert(fqn!(typeof(aarray)) == format("%s[%s]", inner_name, inner_name));

        // qualified key for AA
        static assert(fqn!(typeof(qualAarray)) == format("const(%s[const(%s)])", inner_name, inner_name));

        // Qualified composed data types
        static assert(fqn!(typeof(data)) == format("shared(const(%s[string])[])", inner_name));

        // Function types + function attributes
        static assert(fqn!(typeof(func)) == format("const(%s[string])(ref %s, scope lazy string) ref", inner_name, inner_name));
        static assert(fqn!(typeof(inoutFunc)) == format("inout(%s(inout(%s)))", inner_name, inner_name));
        static assert(fqn!(typeof(deleg)) == format("const(%s delegate(double, string) nothrow @safe)", inner_name));
        static assert(fqn!(typeof(inoutDeleg)) == "inout(int) delegate(inout(int)) inout");
        static assert(fqn!(typeof(funcPtr)) == format("%s function(out double, string)", inner_name));
        static assert(fqn!(typeof(cFuncPtr)) == format("extern(C) %s function(double, string)", inner_name));

        // Delegate type with qualified function type
        static assert(fqn!(typeof(attrDeleg)) == format("shared(immutable(%s) "~
            "delegate(ref double, scope string) nothrow @trusted shared const)", inner_name));

        // Variable argument function types
        static assert(fqn!(typeof(cVarArg)) == "extern(C) void(int, ...)");
        static assert(fqn!(typeof(dVarArg)) == "void(...)");
        static assert(fqn!(typeof(dVarArg2)) == "void(int, ...)");
        static assert(fqn!(typeof(typesafeVarArg)) == "void(int[] ...)");

        // SIMD vector
        static if (is(__vector(float[4])))
        {
            static assert(fqn!(__vector(float[4])) == "__vector(float[4])");
        }
    }
}

/***
 * Get the type of the return value from a function,
 * a pointer to function, a delegate, a struct
 * with an opCall, a pointer to a struct with an opCall,
 * or a class with an $(D opCall). Please note that $(D_KEYWORD ref)
 * is not part of a type, but the attribute of the function
 * (see template $(LREF functionAttributes)).
 */
template ReturnType(func...)
    if (func.length == 1 && isCallable!func)
{
    static if (is(FunctionTypeOf!func R == return))
        alias ReturnType = R;
    else
        static assert(0, "argument has no return type");
}

///
unittest
{
    int foo();
    ReturnType!foo x;   // x is declared as int
}

unittest
{
    struct G
    {
        int opCall (int i) { return 1;}
    }

    alias ShouldBeInt = ReturnType!G;
    static assert(is(ShouldBeInt == int));

    G g;
    static assert(is(ReturnType!g == int));

    G* p;
    alias pg = ReturnType!p;
    static assert(is(pg == int));

    class C
    {
        int opCall (int i) { return 1;}
    }

    static assert(is(ReturnType!C == int));

    C c;
    static assert(is(ReturnType!c == int));

    class Test
    {
        int prop() @property { return 0; }
    }
    alias R_Test_prop = ReturnType!(Test.prop);
    static assert(is(R_Test_prop == int));

    alias R_dglit = ReturnType!((int a) { return a; });
    static assert(is(R_dglit == int));
}

/***
Get, as a tuple, the types of the parameters to a function, a pointer
to function, a delegate, a struct with an $(D opCall), a pointer to a
struct with an $(D opCall), or a class with an $(D opCall).
*/
template ParameterTypeTuple(func...)
    if (func.length == 1 && isCallable!func)
{
    static if (is(FunctionTypeOf!func P == function))
        alias ParameterTypeTuple = P;
    else
        static assert(0, "argument has no parameters");
}

///
unittest
{
    int foo(int, long);
    void bar(ParameterTypeTuple!foo);      // declares void bar(int, long);
    void abc(ParameterTypeTuple!foo[1]);   // declares void abc(long);
}

unittest
{
    int foo(int i, bool b) { return 0; }
    static assert(is(ParameterTypeTuple!foo == TypeTuple!(int, bool)));
    static assert(is(ParameterTypeTuple!(typeof(&foo)) == TypeTuple!(int, bool)));

    struct S { real opCall(real r, int i) { return 0.0; } }
    S s;
    static assert(is(ParameterTypeTuple!S == TypeTuple!(real, int)));
    static assert(is(ParameterTypeTuple!(S*) == TypeTuple!(real, int)));
    static assert(is(ParameterTypeTuple!s == TypeTuple!(real, int)));

    class Test
    {
        int prop() @property { return 0; }
    }
    alias P_Test_prop = ParameterTypeTuple!(Test.prop);
    static assert(P_Test_prop.length == 0);

    alias P_dglit = ParameterTypeTuple!((int a){});
    static assert(P_dglit.length == 1);
    static assert(is(P_dglit[0] == int));
}

/**
Returns the number of arguments of function $(D func).
arity is undefined for variadic functions.
*/
template arity(alias func)
    if ( isCallable!func && variadicFunctionStyle!func == Variadic.no )
{
    enum size_t arity = ParameterTypeTuple!func.length;
}

///
unittest {
    void foo(){}
    static assert(arity!foo==0);
    void bar(uint){}
    static assert(arity!bar==1);
    void variadicFoo(uint...){}
    static assert(__traits(compiles,arity!variadicFoo)==false);
}

/**
Returns a tuple consisting of the storage classes of the parameters of a
function $(D func).
 */
enum ParameterStorageClass : uint
{
    /**
     * These flags can be bitwise OR-ed together to represent complex storage
     * class.
     */
    none   = 0,
    scope_ = 0b000_1,  /// ditto
    out_   = 0b001_0,  /// ditto
    ref_   = 0b010_0,  /// ditto
    lazy_  = 0b100_0,  /// ditto
}

/// ditto
template ParameterStorageClassTuple(func...)
    if (func.length == 1 && isCallable!func)
{
    alias Func = Unqual!(FunctionTypeOf!func);

    /*
     * TypeFuncion:
     *     CallConvention FuncAttrs Arguments ArgClose Type
     */
    alias Params = ParameterTypeTuple!Func;

    // chop off CallConvention and FuncAttrs
    enum margs = demangleFunctionAttributes(mangledName!Func[1 .. $]).rest;

    // demangle Arguments and store parameter storage classes in a tuple
    template demangleNextParameter(string margs, size_t i = 0)
    {
        static if (i < Params.length)
        {
            enum demang = demangleParameterStorageClass(margs);
            enum skip = mangledName!(Params[i]).length; // for bypassing Type
            enum rest = demang.rest;

            alias demangleNextParameter =
                TypeTuple!(
                    demang.value + 0, // workaround: "not evaluatable at ..."
                    demangleNextParameter!(rest[skip .. $], i + 1)
                );
        }
        else // went thru all the parameters
        {
            alias demangleNextParameter = TypeTuple!();
        }
    }

    alias ParameterStorageClassTuple = demangleNextParameter!margs;
}

///
unittest
{
    alias STC = ParameterStorageClass; // shorten the enum name

    void func(ref int ctx, out real result, real param)
    {
    }
    alias pstc = ParameterStorageClassTuple!func;
    static assert(pstc.length == 3); // three parameters
    static assert(pstc[0] == STC.ref_);
    static assert(pstc[1] == STC.out_);
    static assert(pstc[2] == STC.none);
}

unittest
{
    alias STC = ParameterStorageClass;

    void noparam() {}
    static assert(ParameterStorageClassTuple!noparam.length == 0);

    void test(scope int, ref int, out int, lazy int, int) { }
    alias test_pstc = ParameterStorageClassTuple!test;
    static assert(test_pstc.length == 5);
    static assert(test_pstc[0] == STC.scope_);
    static assert(test_pstc[1] == STC.ref_);
    static assert(test_pstc[2] == STC.out_);
    static assert(test_pstc[3] == STC.lazy_);
    static assert(test_pstc[4] == STC.none);

    interface Test
    {
        void test_const(int) const;
        void test_sharedconst(int) shared const;
    }
    Test testi;

    alias test_const_pstc = ParameterStorageClassTuple!(Test.test_const);
    static assert(test_const_pstc.length == 1);
    static assert(test_const_pstc[0] == STC.none);

    alias test_sharedconst_pstc = ParameterStorageClassTuple!(testi.test_sharedconst);
    static assert(test_sharedconst_pstc.length == 1);
    static assert(test_sharedconst_pstc[0] == STC.none);

    alias dglit_pstc = ParameterStorageClassTuple!((ref int a) {});
    static assert(dglit_pstc.length == 1);
    static assert(dglit_pstc[0] == STC.ref_);

    // Bugzilla 9317
    static inout(int) func(inout int param) { return param; }
    static assert(ParameterStorageClassTuple!(typeof(func))[0] == STC.none);
}


/**
Get, as a tuple, the identifiers of the parameters to a function symbol.
 */
template ParameterIdentifierTuple(func...)
    if (func.length == 1 && isCallable!func)
{
    static if (is(FunctionTypeOf!func PT == __parameters))
    {
        template Get(size_t i)
        {
            static if (!isFunctionPointer!func && !isDelegate!func
                       // Unnamed parameters yield CT error.
                       && is(typeof(__traits(identifier, PT[i..i+1]))x))
            {
                enum Get = __traits(identifier, PT[i..i+1]);
            }
            else
            {
                enum Get = "";
            }
        }
    }
    else
    {
        static assert(0, func[0].stringof ~ "is not a function");

        // Define dummy entities to avoid pointless errors
        template Get(size_t i) { enum Get = ""; }
        alias PT = TypeTuple!();
    }

    template Impl(size_t i = 0)
    {
        static if (i == PT.length)
            alias Impl = TypeTuple!();
        else
            alias Impl = TypeTuple!(Get!i, Impl!(i+1));
    }

    alias ParameterIdentifierTuple = Impl!();
}

///
unittest
{
    int foo(int num, string name, int);
    static assert([ParameterIdentifierTuple!foo] == ["num", "name", ""]);
}

unittest
{
    alias PIT = ParameterIdentifierTuple;

    void bar(int num, string name, int[] array){}
    static assert([PIT!bar] == ["num", "name", "array"]);

    // might be changed in the future?
    void function(int num, string name) fp;
    static assert([PIT!fp] == ["", ""]);

    // might be changed in the future?
    void delegate(int num, string name, int[long] aa) dg;
    static assert([PIT!dg] == ["", "", ""]);

    interface Test
    {
        @property string getter();
        @property void setter(int a);
        Test method(int a, long b, string c);
    }
    static assert([PIT!(Test.getter)] == []);
    static assert([PIT!(Test.setter)] == ["a"]);
    static assert([PIT!(Test.method)] == ["a", "b", "c"]);

/+
    // depends on internal
    void baw(int, string, int[]){}
    static assert([PIT!baw] == ["_param_0", "_param_1", "_param_2"]);

    // depends on internal
    void baz(TypeTuple!(int, string, int[]) args){}
    static assert([PIT!baz] == ["_param_0", "_param_1", "_param_2"]);
+/
}


/**
Get, as a tuple, the default value of the parameters to a function symbol.
If a parameter doesn't have the default value, $(D void) is returned instead.
 */
template ParameterDefaultValueTuple(func...)
    if (func.length == 1 && isCallable!func)
{
    static if (is(FunctionTypeOf!(func[0]) PT == __parameters))
    {
        template Get(size_t i)
        {
            enum ParamName = ParameterIdentifierTuple!(func[0])[i];
            static if (ParamName.length)
                enum get = (PT[i..i+1]) => mixin(ParamName);
            else // Unnamed parameter
                enum get = (PT[i..i+1] __args) => __args[0];
            static if (is(typeof(get())))
                enum Get = get();
            else
                alias Get = void;
                // If default arg doesn't exist, returns void instead.
        }
    }
    else static if (is(FunctionTypeOf!func PT == __parameters))
    {
        template Get(size_t i)
        {
            enum Get = "";
        }
    }
    else
    {
        static assert(0, func[0].stringof ~ "is not a function");

        // Define dummy entities to avoid pointless errors
        template Get(size_t i) { enum Get = ""; }
        alias PT = TypeTuple!();
    }

    template Impl(size_t i = 0)
    {
        static if (i == PT.length)
            alias Impl = TypeTuple!();
        else
            alias Impl = TypeTuple!(Get!i, Impl!(i+1));
    }

    alias ParameterDefaultValueTuple = Impl!();
}

///
unittest
{
    int foo(int num, string name = "hello", int[] = [1,2,3]);
    static assert(is(ParameterDefaultValueTuple!foo[0] == void));
    static assert(   ParameterDefaultValueTuple!foo[1] == "hello");
    static assert(   ParameterDefaultValueTuple!foo[2] == [1,2,3]);
}

unittest
{
    alias PDVT = ParameterDefaultValueTuple;

    void bar(int n = 1, string s = "hello"){}
    static assert(PDVT!bar.length == 2);
    static assert(PDVT!bar[0] == 1);
    static assert(PDVT!bar[1] == "hello");
    static assert(is(typeof(PDVT!bar) == typeof(TypeTuple!(1, "hello"))));

    void baz(int x, int n = 1, string s = "hello"){}
    static assert(PDVT!baz.length == 3);
    static assert(is(PDVT!baz[0] == void));
    static assert(   PDVT!baz[1] == 1);
    static assert(   PDVT!baz[2] == "hello");
    static assert(is(typeof(PDVT!baz) == typeof(TypeTuple!(void, 1, "hello"))));

    // bug 10800 - property functions return empty string
    @property void foo(int x = 3) { }
    static assert(PDVT!foo.length == 1);
    static assert(PDVT!foo[0] == 3);
    static assert(is(typeof(PDVT!foo) == typeof(TypeTuple!(3))));

    struct Colour
    {
        ubyte a,r,g,b;

        static immutable Colour white = Colour(255,255,255,255);
    }
    void bug8106(Colour c = Colour.white){}
    //pragma(msg, PDVT!bug8106);
    static assert(PDVT!bug8106[0] == Colour.white);
}


/**
Returns the attributes attached to a function $(D func).
 */
enum FunctionAttribute : uint
{
    /**
     * These flags can be bitwise OR-ed together to represent a complex attribute.
     */
    none       = 0,
    pure_      = 1 << 0,  /// ditto
    nothrow_   = 1 << 1,  /// ditto
    ref_       = 1 << 2,  /// ditto
    property   = 1 << 3,  /// ditto
    trusted    = 1 << 4,  /// ditto
    safe       = 1 << 5,  /// ditto
    nogc       = 1 << 6,  /// ditto
    system     = 1 << 7,  /// ditto
    const_     = 1 << 8,  /// ditto
    immutable_ = 1 << 9,  /// ditto
    inout_     = 1 << 10, /// ditto
    shared_    = 1 << 11, /// ditto
}

/// ditto
template functionAttributes(func...)
    if (func.length == 1 && isCallable!func)
{
    // @bug: workaround for opCall
    alias FuncSym = Select!(is(typeof(__traits(getFunctionAttributes, func))),
                            func, Unqual!(FunctionTypeOf!func));

    enum FunctionAttribute functionAttributes =
        extractAttribFlags!(__traits(getFunctionAttributes, FuncSym))();
}

///
unittest
{
    import std.traits : functionAttributes, FunctionAttribute;

    alias FA = FunctionAttribute; // shorten the enum name

    real func(real x) pure nothrow @safe
    {
        return x;
    }
    static assert(functionAttributes!func & FA.pure_);
    static assert(functionAttributes!func & FA.safe);
    static assert(!(functionAttributes!func & FA.trusted)); // not @trusted
}

unittest
{
    alias FA = FunctionAttribute;

    struct S
    {
        int noF() { return 0; }
        int constF() const { return 0; }
        int immutableF() immutable { return 0; }
        int inoutF() inout { return 0; }
        int sharedF() shared { return 0; }

        int x;
        ref int refF() return { return x; }
        int propertyF() @property { return 0; }
        int nothrowF() nothrow { return 0; }
        int nogcF() @nogc { return 0; }

        int systemF() @system { return 0; }
        int trustedF() @trusted { return 0; }
        int safeF() @safe { return 0; }

        int pureF() pure { return 0; }
    }

    static assert(functionAttributes!(S.noF) == FA.system);
    static assert(functionAttributes!(typeof(S.noF)) == FA.system);

    static assert(functionAttributes!(S.constF) == (FA.const_ | FA.system));
    static assert(functionAttributes!(typeof(S.constF)) == (FA.const_ | FA.system));

    static assert(functionAttributes!(S.immutableF) == (FA.immutable_ | FA.system));
    static assert(functionAttributes!(typeof(S.immutableF)) == (FA.immutable_ | FA.system));

    static assert(functionAttributes!(S.inoutF) == (FA.inout_ | FA.system));
    static assert(functionAttributes!(typeof(S.inoutF)) == (FA.inout_ | FA.system));

    static assert(functionAttributes!(S.sharedF) == (FA.shared_ | FA.system));
    static assert(functionAttributes!(typeof(S.sharedF)) == (FA.shared_ | FA.system));

    static assert(functionAttributes!(S.refF) == (FA.ref_ | FA.system));
    static assert(functionAttributes!(typeof(S.refF)) == (FA.ref_ | FA.system));

    static assert(functionAttributes!(S.propertyF) == (FA.property | FA.system));
    static assert(functionAttributes!(typeof(&S.propertyF)) == (FA.property | FA.system));

    static assert(functionAttributes!(S.nothrowF) == (FA.nothrow_ | FA.system));
    static assert(functionAttributes!(typeof(S.nothrowF)) == (FA.nothrow_ | FA.system));

    static assert(functionAttributes!(S.nogcF) == (FA.nogc | FA.system));
    static assert(functionAttributes!(typeof(S.nogcF)) == (FA.nogc | FA.system));

    static assert(functionAttributes!(S.systemF) == FA.system);
    static assert(functionAttributes!(typeof(S.systemF)) == FA.system);

    static assert(functionAttributes!(S.trustedF) == FA.trusted);
    static assert(functionAttributes!(typeof(S.trustedF)) == FA.trusted);

    static assert(functionAttributes!(S.safeF) == FA.safe);
    static assert(functionAttributes!(typeof(S.safeF)) == FA.safe);

    static assert(functionAttributes!(S.pureF) == (FA.pure_ | FA.system));
    static assert(functionAttributes!(typeof(S.pureF)) == (FA.pure_ | FA.system));

    int pure_nothrow() nothrow pure { return 0; }
    void safe_nothrow() @safe nothrow { }
    static ref int static_ref_property() @property { return *(new int); }
    ref int ref_property() @property { return *(new int); }

    static assert(functionAttributes!(pure_nothrow) == (FA.pure_ | FA.nothrow_ | FA.system));
    static assert(functionAttributes!(typeof(pure_nothrow)) == (FA.pure_ | FA.nothrow_ | FA.system));

    static assert(functionAttributes!(safe_nothrow) == (FA.safe | FA.nothrow_));
    static assert(functionAttributes!(typeof(safe_nothrow)) == (FA.safe | FA.nothrow_));

    static assert(functionAttributes!(static_ref_property) == (FA.property | FA.ref_ | FA.system));
    static assert(functionAttributes!(typeof(&static_ref_property)) == (FA.property | FA.ref_ | FA.system));

    static assert(functionAttributes!(ref_property) == (FA.property | FA.ref_ | FA.system));
    static assert(functionAttributes!(typeof(&ref_property)) == (FA.property | FA.ref_ | FA.system));

    struct S2
    {
        int pure_const() const pure { return 0; }
        int pure_sharedconst() const shared pure { return 0; }
    }

    static assert(functionAttributes!(S2.pure_const) == (FA.const_ | FA.pure_ | FA.system));
    static assert(functionAttributes!(typeof(S2.pure_const)) == (FA.const_ | FA.pure_ | FA.system));

    static assert(functionAttributes!(S2.pure_sharedconst) == (FA.const_ | FA.shared_ | FA.pure_ | FA.system));
    static assert(functionAttributes!(typeof(S2.pure_sharedconst)) == (FA.const_ | FA.shared_ | FA.pure_ | FA.system));

    static assert(functionAttributes!((int a) { }) == (FA.pure_ | FA.nothrow_ | FA.nogc | FA.safe));
    static assert(functionAttributes!(typeof((int a) { })) == (FA.pure_ | FA.nothrow_ | FA.nogc | FA.safe));

    auto safeDel = delegate() @safe { };
    static assert(functionAttributes!(safeDel) == (FA.pure_ | FA.nothrow_ | FA.nogc | FA.safe));
    static assert(functionAttributes!(typeof(safeDel)) == (FA.pure_ | FA.nothrow_ | FA.nogc | FA.safe));

    auto trustedDel = delegate() @trusted { };
    static assert(functionAttributes!(trustedDel) == (FA.pure_ | FA.nothrow_ | FA.nogc | FA.trusted));
    static assert(functionAttributes!(typeof(trustedDel)) == (FA.pure_ | FA.nothrow_ | FA.nogc | FA.trusted));

    auto systemDel = delegate() @system { };
    static assert(functionAttributes!(systemDel) == (FA.pure_ | FA.nothrow_ | FA.nogc | FA.system));
    static assert(functionAttributes!(typeof(systemDel)) == (FA.pure_ | FA.nothrow_ | FA.nogc | FA.system));
}

private FunctionAttribute extractAttribFlags(Attribs...)()
{
    auto res = FunctionAttribute.none;

    foreach (attrib; Attribs)
    {
        switch (attrib) with (FunctionAttribute)
        {
            case "pure":      res |= pure_; break;
            case "nothrow":   res |= nothrow_; break;
            case "ref":       res |= ref_; break;
            case "@property": res |= property; break;
            case "@trusted":  res |= trusted; break;
            case "@safe":     res |= safe; break;
            case "@nogc":     res |= nogc; break;
            case "@system":   res |= system; break;
            case "const":     res |= const_; break;
            case "immutable": res |= immutable_; break;
            case "inout":     res |= inout_; break;
            case "shared":    res |= shared_; break;
            default: assert(0, attrib);
        }
    }

    return res;
}


/**
$(D true) if $(D func) is $(D @safe) or $(D @trusted).
 */
template isSafe(alias func)
    if(isCallable!func)
{
    enum isSafe = (functionAttributes!func & FunctionAttribute.safe) != 0 ||
                  (functionAttributes!func & FunctionAttribute.trusted) != 0;
}

///
unittest
{
    @safe    int add(int a, int b) {return a+b;}
    @trusted int sub(int a, int b) {return a-b;}
    @system  int mul(int a, int b) {return a*b;}

    static assert( isSafe!add);
    static assert( isSafe!sub);
    static assert(!isSafe!mul);
}


unittest
{
    //Member functions
    interface Set
    {
        int systemF() @system;
        int trustedF() @trusted;
        int safeF() @safe;
    }
    static assert( isSafe!(Set.safeF));
    static assert( isSafe!(Set.trustedF));
    static assert(!isSafe!(Set.systemF));

    //Functions
    @safe static safeFunc() {}
    @trusted static trustedFunc() {}
    @system static systemFunc() {}

    static assert( isSafe!safeFunc);
    static assert( isSafe!trustedFunc);
    static assert(!isSafe!systemFunc);

    //Delegates
    auto safeDel = delegate() @safe {};
    auto trustedDel = delegate() @trusted {};
    auto systemDel = delegate() @system {};

    static assert( isSafe!safeDel);
    static assert( isSafe!trustedDel);
    static assert(!isSafe!systemDel);

    //Lambdas
    static assert( isSafe!({safeDel();}));
    static assert( isSafe!({trustedDel();}));
    static assert(!isSafe!({systemDel();}));

    //Static opCall
    struct SafeStatic { @safe static SafeStatic opCall() { return SafeStatic.init; } }
    struct TrustedStatic { @trusted static TrustedStatic opCall() { return TrustedStatic.init; } }
    struct SystemStatic { @system static SystemStatic opCall() { return SystemStatic.init; } }

    static assert( isSafe!(SafeStatic()));
    static assert( isSafe!(TrustedStatic()));
    static assert(!isSafe!(SystemStatic()));

    //Non-static opCall
    struct Safe { @safe Safe opCall() { return Safe.init; } }
    struct Trusted { @trusted Trusted opCall() { return Trusted.init; } }
    struct System { @system System opCall() { return System.init; } }

    static assert( isSafe!(Safe.init()));
    static assert( isSafe!(Trusted.init()));
    static assert(!isSafe!(System.init()));
}


/**
$(D true) if $(D func) is $(D @system).
*/
template isUnsafe(alias func)
{
    enum isUnsafe = !isSafe!func;
}

///
unittest
{
    @safe    int add(int a, int b) {return a+b;}
    @trusted int sub(int a, int b) {return a-b;}
    @system  int mul(int a, int b) {return a*b;}

    static assert(!isUnsafe!add);
    static assert(!isUnsafe!sub);
    static assert( isUnsafe!mul);
}

unittest
{
    //Member functions
    interface Set
    {
        int systemF() @system;
        int trustedF() @trusted;
        int safeF() @safe;
    }
    static assert(!isUnsafe!(Set.safeF));
    static assert(!isUnsafe!(Set.trustedF));
    static assert( isUnsafe!(Set.systemF));

    //Functions
    @safe static safeFunc() {}
    @trusted static trustedFunc() {}
    @system static systemFunc() {}

    static assert(!isUnsafe!safeFunc);
    static assert(!isUnsafe!trustedFunc);
    static assert( isUnsafe!systemFunc);

    //Delegates
    auto safeDel = delegate() @safe {};
    auto trustedDel = delegate() @trusted {};
    auto systemDel = delegate() @system {};

    static assert(!isUnsafe!safeDel);
    static assert(!isUnsafe!trustedDel);
    static assert( isUnsafe!systemDel);

    //Lambdas
    static assert(!isUnsafe!({safeDel();}));
    static assert(!isUnsafe!({trustedDel();}));
    static assert( isUnsafe!({systemDel();}));

    //Static opCall
    struct SafeStatic { @safe static SafeStatic opCall() { return SafeStatic.init; } }
    struct TrustedStatic { @trusted static TrustedStatic opCall() { return TrustedStatic.init; } }
    struct SystemStatic { @system static SystemStatic opCall() { return SystemStatic.init; } }

    static assert(!isUnsafe!(SafeStatic()));
    static assert(!isUnsafe!(TrustedStatic()));
    static assert( isUnsafe!(SystemStatic()));

    //Non-static opCall
    struct Safe { @safe Safe opCall() { return Safe.init; } }
    struct Trusted { @trusted Trusted opCall() { return Trusted.init; } }
    struct System { @system System opCall() { return System.init; } }

    static assert(!isUnsafe!(Safe.init()));
    static assert(!isUnsafe!(Trusted.init()));
    static assert( isUnsafe!(System.init()));
}


/**
$(RED Deprecated. It's badly named and provides redundant functionality. It was
also badly broken prior to 2.060 (bug# 8362), so any code which uses it
probably needs to be changed anyway. Please use $(D allSatisfy(isSafe, ...))
instead. This will be removed in June 2015.)

$(D true) all functions are $(D isSafe).

Example
-------------
@safe    int add(int a, int b) {return a+b;}
@trusted int sub(int a, int b) {return a-b;}
@system  int mul(int a, int b) {return a*b;}

static assert( areAllSafe!(add, add));
static assert( areAllSafe!(add, sub));
static assert(!areAllSafe!(sub, mul));
-------------
*/
deprecated("Please use allSatisfy(isSafe, ...) instead.")
template areAllSafe(funcs...)
    if (funcs.length > 0)
{
    static if (funcs.length == 1)
    {
        enum areAllSafe = isSafe!(funcs[0]);
    }
    else static if (isSafe!(funcs[0]))
    {
        enum areAllSafe = areAllSafe!(funcs[1..$]);
    }
    else
    {
        enum areAllSafe = false;
    }
}

// Verify Example
deprecated unittest
{
    @safe    int add(int a, int b) {return a+b;}
    @trusted int sub(int a, int b) {return a-b;}
    @system  int mul(int a, int b) {return a*b;}

    static assert( areAllSafe!(add, add));
    static assert( areAllSafe!(add, sub));
    static assert(!areAllSafe!(sub, mul));
}

deprecated unittest
{
    interface Set
    {
        int systemF() @system;
        int trustedF() @trusted;
        int safeF() @safe;
    }
    static assert( areAllSafe!((int a){}, Set.safeF));
    static assert( areAllSafe!((int a){}, Set.safeF, Set.trustedF));
    static assert(!areAllSafe!(Set.trustedF, Set.systemF));
}


/**
Returns the calling convention of function as a string.
*/
template functionLinkage(func...)
    if (func.length == 1 && isCallable!func)
{
    alias Func = Unqual!(FunctionTypeOf!func);

    enum string functionLinkage =
        [
            'F': "D",
            'U': "C",
            'W': "Windows",
            'V': "Pascal",
            'R': "C++"
        ][ mangledName!Func[0] ];
}

///
unittest
{
    import std.stdio : writeln, printf;

    string a = functionLinkage!(writeln!(string, int));
    assert(a == "D"); // extern(D)

    auto fp = &printf;
    string b = functionLinkage!fp;
    assert(b == "C"); // extern(C)
}

unittest
{
    extern(D) void Dfunc() {}
    extern(C) void Cfunc() {}
    static assert(functionLinkage!Dfunc == "D");
    static assert(functionLinkage!Cfunc == "C");

    interface Test
    {
        void const_func() const;
        void sharedconst_func() shared const;
    }
    static assert(functionLinkage!(Test.const_func) == "D");
    static assert(functionLinkage!(Test.sharedconst_func) == "D");

    static assert(functionLinkage!((int a){}) == "D");
}


/**
Determines what kind of variadic parameters function has.
 */
enum Variadic
{
    no,       /// Function is not variadic.
    c,        /// Function is a _C-style variadic function.
              /// Function is a _D-style variadic function, which uses
    d,        /// __argptr and __arguments.
    typesafe, /// Function is a typesafe variadic function.
}

/// ditto
template variadicFunctionStyle(func...)
    if (func.length == 1 && isCallable!func)
{
    alias Func = Unqual!(FunctionTypeOf!func);

    // TypeFuncion --> CallConvention FuncAttrs Arguments ArgClose Type
    enum callconv = functionLinkage!Func;
    enum mfunc = mangledName!Func;
    enum mtype = mangledName!(ReturnType!Func);
    static assert(mfunc[$ - mtype.length .. $] == mtype, mfunc ~ "|" ~ mtype);

    enum argclose = mfunc[$ - mtype.length - 1];
    static assert(argclose >= 'X' && argclose <= 'Z');

    enum Variadic variadicFunctionStyle =
        argclose == 'X' ? Variadic.typesafe :
        argclose == 'Y' ? (callconv == "C") ? Variadic.c : Variadic.d :
        Variadic.no; // 'Z'
}

///
unittest
{
    void func() {}
    static assert(variadicFunctionStyle!func == Variadic.no);

    extern(C) int printf(in char*, ...);
    static assert(variadicFunctionStyle!printf == Variadic.c);
}

unittest
{
    import core.vararg;

    extern(D) void novar() {}
    extern(C) void cstyle(int, ...) {}
    extern(D) void dstyle(...) {}
    extern(D) void typesafe(int[]...) {}

    static assert(variadicFunctionStyle!novar == Variadic.no);
    static assert(variadicFunctionStyle!cstyle == Variadic.c);
    static assert(variadicFunctionStyle!dstyle == Variadic.d);
    static assert(variadicFunctionStyle!typesafe == Variadic.typesafe);

    static assert(variadicFunctionStyle!((int[] a...) {}) == Variadic.typesafe);
}


/**
Get the function type from a callable object $(D func).

Using builtin $(D typeof) on a property function yields the types of the
property value, not of the property function itself.  Still,
$(D FunctionTypeOf) is able to obtain function types of properties.

Note:
Do not confuse function types with function pointer types; function types are
usually used for compile-time reflection purposes.
 */
template FunctionTypeOf(func...)
    if (func.length == 1 && isCallable!func)
{
    static if (is(typeof(& func[0]) Fsym : Fsym*) && is(Fsym == function) || is(typeof(& func[0]) Fsym == delegate))
    {
        alias FunctionTypeOf = Fsym; // HIT: (nested) function symbol
    }
    else static if (is(typeof(& func[0].opCall) Fobj == delegate))
    {
        alias FunctionTypeOf = Fobj; // HIT: callable object
    }
    else static if (is(typeof(& func[0].opCall) Ftyp : Ftyp*) && is(Ftyp == function))
    {
        alias FunctionTypeOf = Ftyp; // HIT: callable type
    }
    else static if (is(func[0] T) || is(typeof(func[0]) T))
    {
        static if (is(T == function))
            alias FunctionTypeOf = T;    // HIT: function
        else static if (is(T Fptr : Fptr*) && is(Fptr == function))
            alias FunctionTypeOf = Fptr; // HIT: function pointer
        else static if (is(T Fdlg == delegate))
            alias FunctionTypeOf = Fdlg; // HIT: delegate
        else
            static assert(0);
    }
    else
        static assert(0);
}

///
unittest
{
    class C
    {
        int value() @property { return 0; }
    }
    static assert(is( typeof(C.value) == int ));
    static assert(is( FunctionTypeOf!(C.value) == function ));
}

unittest
{
    int test(int a) { return 0; }
    int propGet() @property { return 0; }
    int propSet(int a) @property { return 0; }
    int function(int) test_fp;
    int delegate(int) test_dg;
    static assert(is( typeof(test) == FunctionTypeOf!(typeof(test)) ));
    static assert(is( typeof(test) == FunctionTypeOf!test ));
    static assert(is( typeof(test) == FunctionTypeOf!test_fp ));
    static assert(is( typeof(test) == FunctionTypeOf!test_dg ));
    alias int GetterType() @property;
    alias int SetterType(int) @property;
    static assert(is( FunctionTypeOf!propGet == GetterType ));
    static assert(is( FunctionTypeOf!propSet == SetterType ));

    interface Prop { int prop() @property; }
    Prop prop;
    static assert(is( FunctionTypeOf!(Prop.prop) == GetterType ));
    static assert(is( FunctionTypeOf!(prop.prop) == GetterType ));

    class Callable { int opCall(int) { return 0; } }
    auto call = new Callable;
    static assert(is( FunctionTypeOf!call == typeof(test) ));

    struct StaticCallable { static int opCall(int) { return 0; } }
    StaticCallable stcall_val;
    StaticCallable* stcall_ptr;
    static assert(is( FunctionTypeOf!stcall_val == typeof(test) ));
    static assert(is( FunctionTypeOf!stcall_ptr == typeof(test) ));

    interface Overloads
    {
        void test(string);
        real test(real);
        int  test();
        int  test() @property;
    }
    alias ov = TypeTuple!(__traits(getVirtualFunctions, Overloads, "test"));
    alias F_ov0 = FunctionTypeOf!(ov[0]);
    alias F_ov1 = FunctionTypeOf!(ov[1]);
    alias F_ov2 = FunctionTypeOf!(ov[2]);
    alias F_ov3 = FunctionTypeOf!(ov[3]);
    static assert(is(F_ov0* == void function(string)));
    static assert(is(F_ov1* == real function(real)));
    static assert(is(F_ov2* == int function()));
    static assert(is(F_ov3* == int function() @property));

    alias F_dglit = FunctionTypeOf!((int a){ return a; });
    static assert(is(F_dglit* : int function(int)));
}

/**
 * Constructs a new function or delegate type with the same basic signature
 * as the given one, but different attributes (including linkage).
 *
 * This is especially useful for adding/removing attributes to/from types in
 * generic code, where the actual type name cannot be spelt out.
 *
 * Params:
 *    T = The base type.
 *    linkage = The desired linkage of the result type.
 *    attrs = The desired $(LREF FunctionAttribute)s of the result type.
 */
template SetFunctionAttributes(T, string linkage, uint attrs)
    if (isFunctionPointer!T || isDelegate!T)
{
    mixin({
        import std.algorithm : canFind;

        static assert(!(attrs & FunctionAttribute.trusted) ||
            !(attrs & FunctionAttribute.safe),
            "Cannot have a function/delegate that is both trusted and safe.");

        enum linkages = ["D", "C", "Windows", "Pascal", "C++", "System"];
        static assert(canFind(linkages, linkage), "Invalid linkage '" ~
            linkage ~ "', must be one of " ~ linkages.stringof ~ ".");

        string result = "alias ";

        static if (linkage != "D")
            result ~= "extern(" ~ linkage ~ ") ";

        static if (attrs & FunctionAttribute.ref_)
            result ~= "ref ";

        result ~= "ReturnType!T";

        static if (isDelegate!T)
            result ~= " delegate";
        else
            result ~= " function";

        result ~= "(";

        static if (ParameterTypeTuple!T.length > 0)
            result ~= "ParameterTypeTuple!T";

        enum varStyle = variadicFunctionStyle!T;
        static if (varStyle == Variadic.c)
            result ~= ", ...";
        else static if (varStyle == Variadic.d)
            result ~= "...";
        else static if (varStyle == Variadic.typesafe)
            result ~= "...";

        result ~= ")";

        static if (attrs & FunctionAttribute.pure_)
            result ~= " pure";
        static if (attrs & FunctionAttribute.nothrow_)
            result ~= " nothrow";
        static if (attrs & FunctionAttribute.property)
            result ~= " @property";
        static if (attrs & FunctionAttribute.trusted)
            result ~= " @trusted";
        static if (attrs & FunctionAttribute.safe)
            result ~= " @safe";
        static if (attrs & FunctionAttribute.nogc)
            result ~= " @nogc";
        static if (attrs & FunctionAttribute.system)
            result ~= " @system";
        static if (attrs & FunctionAttribute.const_)
            result ~= " const";
        static if (attrs & FunctionAttribute.immutable_)
            result ~= " immutable";
        static if (attrs & FunctionAttribute.inout_)
            result ~= " inout";
        static if (attrs & FunctionAttribute.shared_)
            result ~= " shared";

        result ~= " SetFunctionAttributes;";
        return result;
    }());
}

/// Ditto
template SetFunctionAttributes(T, string linkage, uint attrs)
    if (is(T == function))
{
    // To avoid a lot of syntactic headaches, we just use the above version to
    // operate on the corresponding function pointer type and then remove the
    // indirection again.
    alias SetFunctionAttributes = FunctionTypeOf!(SetFunctionAttributes!(T*, linkage, attrs));
}

///
unittest
{
    alias ExternC(T) = SetFunctionAttributes!(T, "C", functionAttributes!T);

    auto assumePure(T)(T t)
        if (isFunctionPointer!T || isDelegate!T)
    {
        enum attrs = functionAttributes!T | FunctionAttribute.pure_;
        return cast(SetFunctionAttributes!(T, functionLinkage!T, attrs)) t;
    }
}

version (unittest)
{
    // Some function types to test.
    int sc(scope int, ref int, out int, lazy int, int);
    extern(System) int novar();
    extern(C) int cstyle(int, ...);
    extern(D) int dstyle(...);
    extern(D) int typesafe(int[]...);
}
unittest
{
    import std.algorithm : reduce;

    alias FA = FunctionAttribute;
    foreach (BaseT; TypeTuple!(typeof(&sc), typeof(&novar), typeof(&cstyle),
        typeof(&dstyle), typeof(&typesafe)))
    {
        foreach (T; TypeTuple!(BaseT, FunctionTypeOf!BaseT))
        (){ // avoid slow optimizations for large functions @@@BUG@@@ 2396
            enum linkage = functionLinkage!T;
            enum attrs = functionAttributes!T;

            static assert(is(SetFunctionAttributes!(T, linkage, attrs) == T),
                "Identity check failed for: " ~ T.stringof);

            // Check that all linkage types work (D-style variadics require D linkage).
            static if (variadicFunctionStyle!T != Variadic.d)
            {
                foreach (newLinkage; TypeTuple!("D", "C", "Windows", "Pascal", "C++"))
                {
                    alias New = SetFunctionAttributes!(T, newLinkage, attrs);
                    static assert(functionLinkage!New == newLinkage,
                        "Linkage test failed for: " ~ T.stringof ~ ", " ~ newLinkage ~
                        " (got " ~ New.stringof ~ ")");
                }
            }

            // Add @safe.
            alias T1 = SetFunctionAttributes!(T, functionLinkage!T, FA.safe);
            static assert(functionAttributes!T1 == FA.safe);

            // Add all known attributes, excluding conflicting ones.
            enum allAttrs = reduce!"a | b"([EnumMembers!FA])
                & ~FA.safe & ~FA.property & ~FA.const_ & ~FA.immutable_ & ~FA.inout_ & ~FA.shared_ & ~FA.system;

            alias T2 = SetFunctionAttributes!(T1, functionLinkage!T, allAttrs);
            static assert(functionAttributes!T2 == allAttrs);

            // Strip all attributes again.
            alias T3 = SetFunctionAttributes!(T2, functionLinkage!T, FA.none);
            static assert(is(T3 == T));
        }();
    }
}


//::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::://
// Aggregate Types
//::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::://

/**
Determines whether $(D T) has its own context pointer.
$(D T) must be either $(D class), $(D struct), or $(D union).
*/
template isNested(T)
    if(is(T == class) || is(T == struct) || is(T == union))
{
    enum isNested = __traits(isNested, T);
}

///
unittest
{
    static struct S { }
    static assert(!isNested!S);

    int i;
    struct NestedStruct { void f() { ++i; } }
    static assert(isNested!NestedStruct);
}

/**
Determines whether $(D T) or any of its representation types
have a context pointer.
*/
template hasNested(T)
{
    static if(isStaticArray!T && T.length)
        enum hasNested = hasNested!(typeof(T.init[0]));
    else static if(is(T == class) || is(T == struct) || is(T == union))
        enum hasNested = isNested!T ||
            anySatisfy!(.hasNested, FieldTypeTuple!T);
    else
        enum hasNested = false;
}

///
unittest
{
    static struct S { }

    int i;
    struct NS { void f() { ++i; } }

    static assert(!hasNested!(S[2]));
    static assert(hasNested!(NS[2]));
}

unittest
{
    static assert(!__traits(compiles, isNested!int));
    static assert(!hasNested!int);

    static struct StaticStruct { }
    static assert(!isNested!StaticStruct);
    static assert(!hasNested!StaticStruct);

    int i;
    struct NestedStruct { void f() { ++i; } }
    static assert( isNested!NestedStruct);
    static assert( hasNested!NestedStruct);
    static assert( isNested!(immutable NestedStruct));
    static assert( hasNested!(immutable NestedStruct));

    static assert(!__traits(compiles, isNested!(NestedStruct[1])));
    static assert( hasNested!(NestedStruct[1]));
    static assert(!hasNested!(NestedStruct[0]));

    struct S1 { NestedStruct nested; }
    static assert(!isNested!S1);
    static assert( hasNested!S1);

    static struct S2 { NestedStruct nested; }
    static assert(!isNested!S2);
    static assert( hasNested!S2);

    static struct S3 { NestedStruct[0] nested; }
    static assert(!isNested!S3);
    static assert(!hasNested!S3);

    static union U { NestedStruct nested; }
    static assert(!isNested!U);
    static assert( hasNested!U);

    static class StaticClass { }
    static assert(!isNested!StaticClass);
    static assert(!hasNested!StaticClass);

    class NestedClass { void f() { ++i; } }
    static assert( isNested!NestedClass);
    static assert( hasNested!NestedClass);
    static assert( isNested!(immutable NestedClass));
    static assert( hasNested!(immutable NestedClass));

    static assert(!__traits(compiles, isNested!(NestedClass[1])));
    static assert( hasNested!(NestedClass[1]));
    static assert(!hasNested!(NestedClass[0]));
}


/***
 * Get as a typetuple the types of the fields of a struct, class, or union.
 * This consists of the fields that take up memory space,
 * excluding the hidden fields like the virtual function
 * table pointer or a context pointer for nested types.
 * If $(D T) isn't a struct, class, or union returns typetuple
 * with one element $(D T).
 */
template FieldTypeTuple(T)
{
    static if (is(T == struct) || is(T == union))
        alias FieldTypeTuple = typeof(T.tupleof[0 .. $ - isNested!T]);
    else static if (is(T == class))
        alias FieldTypeTuple = typeof(T.tupleof);
    else
        alias FieldTypeTuple = TypeTuple!T;
}

///
unittest
{
    struct S { int x; float y; }
    static assert(is(FieldTypeTuple!S == TypeTuple!(int, float)));
}

unittest
{
    static assert(is(FieldTypeTuple!int == TypeTuple!int));

    static struct StaticStruct1 { }
    static assert(is(FieldTypeTuple!StaticStruct1 == TypeTuple!()));

    static struct StaticStruct2 { int a, b; }
    static assert(is(FieldTypeTuple!StaticStruct2 == TypeTuple!(int, int)));

    int i;

    struct NestedStruct1 { void f() { ++i; } }
    static assert(is(FieldTypeTuple!NestedStruct1 == TypeTuple!()));

    struct NestedStruct2 { int a; void f() { ++i; } }
    static assert(is(FieldTypeTuple!NestedStruct2 == TypeTuple!int));

    class NestedClass { int a; void f() { ++i; } }
    static assert(is(FieldTypeTuple!NestedClass == TypeTuple!int));
}


//Required for FieldNameTuple
private enum NameOf(alias T) = T.stringof;

/**
 * Get as an expression tuple the names of the fields of a struct, class, or
 * union. This consists of the fields that take up memory space, excluding the
 * hidden fields like the virtual function table pointer or a context pointer
 * for nested types. If $(D T) isn't a struct, class, or union returns an
 * expression tuple with an empty string.
 */
template FieldNameTuple(T)
{
    static if (is(T == struct) || is(T == union))
        alias FieldNameTuple = staticMap!(NameOf, T.tupleof[0 .. $ - isNested!T]);
    else static if (is(T == class))
        alias FieldNameTuple = staticMap!(NameOf, T.tupleof);
    else
        alias FieldNameTuple = TypeTuple!"";
}

///
unittest
{
    struct S { int x; float y; }
    static assert(FieldNameTuple!S == TypeTuple!("x", "y"));
    static assert(FieldNameTuple!int == TypeTuple!"");
}

unittest
{
    static assert(FieldNameTuple!int == TypeTuple!"");

    static struct StaticStruct1 { }
    static assert(is(FieldNameTuple!StaticStruct1 == TypeTuple!()));

    static struct StaticStruct2 { int a, b; }
    static assert(FieldNameTuple!StaticStruct2 == TypeTuple!("a", "b"));

    int i;

    struct NestedStruct1 { void f() { ++i; } }
    static assert(is(FieldNameTuple!NestedStruct1 == TypeTuple!()));

    struct NestedStruct2 { int a; void f() { ++i; } }
    static assert(FieldNameTuple!NestedStruct2 == TypeTuple!"a");

    class NestedClass { int a; void f() { ++i; } }
    static assert(FieldNameTuple!NestedClass == TypeTuple!"a");
}


/***
Get the primitive types of the fields of a struct or class, in
topological order.
*/
template RepresentationTypeTuple(T)
{
    template Impl(T...)
    {
        static if (T.length == 0)
        {
            alias Impl = TypeTuple!();
        }
        else
        {
            import std.typecons : Rebindable;

            static if (is(T[0] R: Rebindable!R))
            {
                alias Impl = Impl!(Impl!R, T[1 .. $]);
            }
            else  static if (is(T[0] == struct) || is(T[0] == union))
            {
                // @@@BUG@@@ this should work
                //alias .RepresentationTypes!(T[0].tupleof)
                //    RepresentationTypes;
                alias Impl = Impl!(FieldTypeTuple!(T[0]), T[1 .. $]);
            }
            else
            {
                alias Impl = TypeTuple!(T[0], Impl!(T[1 .. $]));
            }
        }
    }

    static if (is(T == struct) || is(T == union) || is(T == class))
    {
        alias RepresentationTypeTuple = Impl!(FieldTypeTuple!T);
    }
    else
    {
        alias RepresentationTypeTuple = Impl!T;
    }
}

///
unittest
{
    struct S1 { int a; float b; }
    struct S2 { char[] a; union { S1 b; S1 * c; } }
    alias R = RepresentationTypeTuple!S2;
    assert(R.length == 4
        && is(R[0] == char[]) && is(R[1] == int)
        && is(R[2] == float) && is(R[3] == S1*));
}

unittest
{
    alias S1 = RepresentationTypeTuple!int;
    static assert(is(S1 == TypeTuple!int));

    struct S2 { int a; }
    struct S3 { int a; char b; }
    struct S4 { S1 a; int b; S3 c; }
    static assert(is(RepresentationTypeTuple!S2 == TypeTuple!int));
    static assert(is(RepresentationTypeTuple!S3 == TypeTuple!(int, char)));
    static assert(is(RepresentationTypeTuple!S4 == TypeTuple!(int, int, int, char)));

    struct S11 { int a; float b; }
    struct S21 { char[] a; union { S11 b; S11 * c; } }
    alias R = RepresentationTypeTuple!S21;
    assert(R.length == 4
           && is(R[0] == char[]) && is(R[1] == int)
           && is(R[2] == float) && is(R[3] == S11*));

    class C { int a; float b; }
    alias R1 = RepresentationTypeTuple!C;
    static assert(R1.length == 2 && is(R1[0] == int) && is(R1[1] == float));

    /* Issue 6642 */
    import std.typecons : Rebindable;

    struct S5 { int a; Rebindable!(immutable Object) b; }
    alias R2 = RepresentationTypeTuple!S5;
    static assert(R2.length == 2 && is(R2[0] == int) && is(R2[1] == immutable(Object)));
}

/*
Statically evaluates to $(D true) if and only if $(D T)'s
representation contains at least one field of pointer or array type.
Members of class types are not considered raw pointers. Pointers to
immutable objects are not considered raw aliasing.
*/
private template hasRawAliasing(T...)
{
    template Impl(T...)
    {
        static if (T.length == 0)
        {
            enum Impl = false;
        }
        else
        {
            static if (is(T[0] foo : U*, U) && !isFunctionPointer!(T[0]))
                enum has = !is(U == immutable);
            else static if (is(T[0] foo : U[], U) && !isStaticArray!(T[0]))
                enum has = !is(U == immutable);
            else static if (isAssociativeArray!(T[0]))
                enum has = !is(T[0] == immutable);
            else
                enum has = false;

            enum Impl = has || Impl!(T[1 .. $]);
        }
    }

    enum hasRawAliasing = Impl!(RepresentationTypeTuple!T);
}

///
unittest
{
    // simple types
    static assert(!hasRawAliasing!int);
    static assert( hasRawAliasing!(char*));
    // references aren't raw pointers
    static assert(!hasRawAliasing!Object);
    // built-in arrays do contain raw pointers
    static assert( hasRawAliasing!(int[]));
    // aggregate of simple types
    struct S1 { int a; double b; }
    static assert(!hasRawAliasing!S1);
    // indirect aggregation
    struct S2 { S1 a; double b; }
    static assert(!hasRawAliasing!S2);
}

unittest
{
    // struct with a pointer member
    struct S3 { int a; double * b; }
    static assert( hasRawAliasing!S3);
    // struct with an indirect pointer member
    struct S4 { S3 a; double b; }
    static assert( hasRawAliasing!S4);
    struct S5 { int a; Object z; int c; }
    static assert( hasRawAliasing!S3);
    static assert( hasRawAliasing!S4);
    static assert(!hasRawAliasing!S5);

    union S6 { int a; int b; }
    union S7 { int a; int * b; }
    static assert(!hasRawAliasing!S6);
    static assert( hasRawAliasing!S7);

    static assert(!hasRawAliasing!(void delegate()));
    static assert(!hasRawAliasing!(void delegate() const));
    static assert(!hasRawAliasing!(void delegate() immutable));
    static assert(!hasRawAliasing!(void delegate() shared));
    static assert(!hasRawAliasing!(void delegate() shared const));
    static assert(!hasRawAliasing!(const(void delegate())));
    static assert(!hasRawAliasing!(immutable(void delegate())));

    struct S8 { void delegate() a; int b; Object c; }
    class S12 { typeof(S8.tupleof) a; }
    class S13 { typeof(S8.tupleof) a; int* b; }
    static assert(!hasRawAliasing!S8);
    static assert(!hasRawAliasing!S12);
    static assert( hasRawAliasing!S13);

    enum S9 { a }
    static assert(!hasRawAliasing!S9);

    // indirect members
    struct S10 { S7 a; int b; }
    struct S11 { S6 a; int b; }
    static assert( hasRawAliasing!S10);
    static assert(!hasRawAliasing!S11);

    static assert( hasRawAliasing!(int[string]));
    static assert(!hasRawAliasing!(immutable(int[string])));
}

/*
Statically evaluates to $(D true) if and only if $(D T)'s
representation contains at least one non-shared field of pointer or
array type.  Members of class types are not considered raw pointers.
Pointers to immutable objects are not considered raw aliasing.
*/
private template hasRawUnsharedAliasing(T...)
{
    template Impl(T...)
    {
        static if (T.length == 0)
        {
            enum Impl = false;
        }
        else
        {
            static if (is(T[0] foo : U*, U) && !isFunctionPointer!(T[0]))
                enum has = !is(U == immutable) && !is(U == shared);
            else static if (is(T[0] foo : U[], U) && !isStaticArray!(T[0]))
                enum has = !is(U == immutable) && !is(U == shared);
            else static if (isAssociativeArray!(T[0]))
                enum has = !is(T[0] == immutable) && !is(T[0] == shared);
            else
                enum has = false;

            enum Impl = has || Impl!(T[1 .. $]);
        }
    }

    enum hasRawUnsharedAliasing = Impl!(RepresentationTypeTuple!T);
}

///
unittest
{
    // simple types
    static assert(!hasRawUnsharedAliasing!int);
    static assert( hasRawUnsharedAliasing!(char*));
    static assert(!hasRawUnsharedAliasing!(shared char*));
    // references aren't raw pointers
    static assert(!hasRawUnsharedAliasing!Object);
    // built-in arrays do contain raw pointers
    static assert( hasRawUnsharedAliasing!(int[]));
    static assert(!hasRawUnsharedAliasing!(shared int[]));
    // aggregate of simple types
    struct S1 { int a; double b; }
    static assert(!hasRawUnsharedAliasing!S1);
    // indirect aggregation
    struct S2 { S1 a; double b; }
    static assert(!hasRawUnsharedAliasing!S2);
    // struct with a pointer member
    struct S3 { int a; double * b; }
    static assert( hasRawUnsharedAliasing!S3);
    struct S4 { int a; shared double * b; }
    static assert(!hasRawUnsharedAliasing!S4);
}

unittest
{
    // struct with a pointer member
    struct S3 { int a; double * b; }
    static assert( hasRawUnsharedAliasing!S3);
    struct S4 { int a; shared double * b; }
    static assert(!hasRawUnsharedAliasing!S4);
    // struct with an indirect pointer member
    struct S5 { S3 a; double b; }
    static assert( hasRawUnsharedAliasing!S5);
    struct S6 { S4 a; double b; }
    static assert(!hasRawUnsharedAliasing!S6);
    struct S7 { int a; Object z;      int c; }
    static assert( hasRawUnsharedAliasing!S5);
    static assert(!hasRawUnsharedAliasing!S6);
    static assert(!hasRawUnsharedAliasing!S7);

    union S8  { int a; int b; }
    union S9  { int a; int* b; }
    union S10 { int a; shared int* b; }
    static assert(!hasRawUnsharedAliasing!S8);
    static assert( hasRawUnsharedAliasing!S9);
    static assert(!hasRawUnsharedAliasing!S10);

    static assert(!hasRawUnsharedAliasing!(void delegate()));
    static assert(!hasRawUnsharedAliasing!(void delegate() const));
    static assert(!hasRawUnsharedAliasing!(void delegate() immutable));
    static assert(!hasRawUnsharedAliasing!(void delegate() shared));
    static assert(!hasRawUnsharedAliasing!(void delegate() shared const));
    static assert(!hasRawUnsharedAliasing!(const(void delegate())));
    static assert(!hasRawUnsharedAliasing!(const(void delegate() const)));
    static assert(!hasRawUnsharedAliasing!(const(void delegate() immutable)));
    static assert(!hasRawUnsharedAliasing!(const(void delegate() shared)));
    static assert(!hasRawUnsharedAliasing!(const(void delegate() shared const)));
    static assert(!hasRawUnsharedAliasing!(immutable(void delegate())));
    static assert(!hasRawUnsharedAliasing!(immutable(void delegate() const)));
    static assert(!hasRawUnsharedAliasing!(immutable(void delegate() immutable)));
    static assert(!hasRawUnsharedAliasing!(immutable(void delegate() shared)));
    static assert(!hasRawUnsharedAliasing!(immutable(void delegate() shared const)));
    static assert(!hasRawUnsharedAliasing!(shared(void delegate())));
    static assert(!hasRawUnsharedAliasing!(shared(void delegate() const)));
    static assert(!hasRawUnsharedAliasing!(shared(void delegate() immutable)));
    static assert(!hasRawUnsharedAliasing!(shared(void delegate() shared)));
    static assert(!hasRawUnsharedAliasing!(shared(void delegate() shared const)));
    static assert(!hasRawUnsharedAliasing!(shared(const(void delegate()))));
    static assert(!hasRawUnsharedAliasing!(shared(const(void delegate() const))));
    static assert(!hasRawUnsharedAliasing!(shared(const(void delegate() immutable))));
    static assert(!hasRawUnsharedAliasing!(shared(const(void delegate() shared))));
    static assert(!hasRawUnsharedAliasing!(shared(const(void delegate() shared const))));
    static assert(!hasRawUnsharedAliasing!(void function()));

    enum S13 { a }
    static assert(!hasRawUnsharedAliasing!S13);

    // indirect members
    struct S14 { S9  a; int b; }
    struct S15 { S10 a; int b; }
    struct S16 { S6  a; int b; }
    static assert( hasRawUnsharedAliasing!S14);
    static assert(!hasRawUnsharedAliasing!S15);
    static assert(!hasRawUnsharedAliasing!S16);

    static assert( hasRawUnsharedAliasing!(int[string]));
    static assert(!hasRawUnsharedAliasing!(shared(int[string])));
    static assert(!hasRawUnsharedAliasing!(immutable(int[string])));

    struct S17
    {
        void delegate() shared a;
        void delegate() immutable b;
        void delegate() shared const c;
        shared(void delegate()) d;
        shared(void delegate() shared) e;
        shared(void delegate() immutable) f;
        shared(void delegate() shared const) g;
        immutable(void delegate()) h;
        immutable(void delegate() shared) i;
        immutable(void delegate() immutable) j;
        immutable(void delegate() shared const) k;
        shared(const(void delegate())) l;
        shared(const(void delegate() shared)) m;
        shared(const(void delegate() immutable)) n;
        shared(const(void delegate() shared const)) o;
    }
    struct S18 { typeof(S17.tupleof) a; void delegate() p; }
    struct S19 { typeof(S17.tupleof) a; Object p; }
    struct S20 { typeof(S17.tupleof) a; int* p; }
    class S21 { typeof(S17.tupleof) a; }
    class S22 { typeof(S17.tupleof) a; void delegate() p; }
    class S23 { typeof(S17.tupleof) a; Object p; }
    class S24 { typeof(S17.tupleof) a; int* p; }
    static assert(!hasRawUnsharedAliasing!S17);
    static assert(!hasRawUnsharedAliasing!(immutable(S17)));
    static assert(!hasRawUnsharedAliasing!(shared(S17)));
    static assert(!hasRawUnsharedAliasing!S18);
    static assert(!hasRawUnsharedAliasing!(immutable(S18)));
    static assert(!hasRawUnsharedAliasing!(shared(S18)));
    static assert(!hasRawUnsharedAliasing!S19);
    static assert(!hasRawUnsharedAliasing!(immutable(S19)));
    static assert(!hasRawUnsharedAliasing!(shared(S19)));
    static assert( hasRawUnsharedAliasing!S20);
    static assert(!hasRawUnsharedAliasing!(immutable(S20)));
    static assert(!hasRawUnsharedAliasing!(shared(S20)));
    static assert(!hasRawUnsharedAliasing!S21);
    static assert(!hasRawUnsharedAliasing!(immutable(S21)));
    static assert(!hasRawUnsharedAliasing!(shared(S21)));
    static assert(!hasRawUnsharedAliasing!S22);
    static assert(!hasRawUnsharedAliasing!(immutable(S22)));
    static assert(!hasRawUnsharedAliasing!(shared(S22)));
    static assert(!hasRawUnsharedAliasing!S23);
    static assert(!hasRawUnsharedAliasing!(immutable(S23)));
    static assert(!hasRawUnsharedAliasing!(shared(S23)));
    static assert( hasRawUnsharedAliasing!S24);
    static assert(!hasRawUnsharedAliasing!(immutable(S24)));
    static assert(!hasRawUnsharedAliasing!(shared(S24)));
    struct S25 {}
    class S26 {}
    interface S27 {}
    union S28 {}
    static assert(!hasRawUnsharedAliasing!S25);
    static assert(!hasRawUnsharedAliasing!S26);
    static assert(!hasRawUnsharedAliasing!S27);
    static assert(!hasRawUnsharedAliasing!S28);
}

/*
Statically evaluates to $(D true) if and only if $(D T)'s
representation includes at least one non-immutable object reference.
*/

private template hasObjects(T...)
{
    static if (T.length == 0)
    {
        enum hasObjects = false;
    }
    else static if (is(T[0] == struct))
    {
        enum hasObjects = hasObjects!(
            RepresentationTypeTuple!(T[0]), T[1 .. $]);
    }
    else
    {
        enum hasObjects = ((is(T[0] == class) || is(T[0] == interface))
            && !is(T[0] == immutable)) || hasObjects!(T[1 .. $]);
    }
}

/*
Statically evaluates to $(D true) if and only if $(D T)'s
representation includes at least one non-immutable non-shared object
reference.
*/
private template hasUnsharedObjects(T...)
{
    static if (T.length == 0)
    {
        enum hasUnsharedObjects = false;
    }
    else static if (is(T[0] == struct))
    {
        enum hasUnsharedObjects = hasUnsharedObjects!(
            RepresentationTypeTuple!(T[0]), T[1 .. $]);
    }
    else
    {
        enum hasUnsharedObjects = ((is(T[0] == class) || is(T[0] == interface)) &&
                                !is(T[0] == immutable) && !is(T[0] == shared)) ||
            hasUnsharedObjects!(T[1 .. $]);
    }
}

/**
Returns $(D true) if and only if $(D T)'s representation includes at
least one of the following: $(OL $(LI a raw pointer $(D U*) and $(D U)
is not immutable;) $(LI an array $(D U[]) and $(D U) is not
immutable;) $(LI a reference to a class or interface type $(D C) and $(D C) is
not immutable.) $(LI an associative array that is not immutable.)
$(LI a delegate.))
*/
template hasAliasing(T...)
{
    import std.typecons : Rebindable;

    static if (T.length && is(T[0] : Rebindable!R, R))
    {
        enum hasAliasing = hasAliasing!(R, T[1 .. $]);
    }
    else
    {
        template isAliasingDelegate(T)
        {
            enum isAliasingDelegate = isDelegate!T
                                  && !is(T == immutable)
                                  && !is(FunctionTypeOf!T == immutable);
        }
        enum hasAliasing = hasRawAliasing!T || hasObjects!T ||
            anySatisfy!(isAliasingDelegate, T, RepresentationTypeTuple!T);
    }
}

///
unittest
{
    struct S1 { int a; Object b; }
    struct S2 { string a; }
    struct S3 { int a; immutable Object b; }
    struct S4 { float[3] vals; }
    static assert( hasAliasing!S1);
    static assert(!hasAliasing!S2);
    static assert(!hasAliasing!S3);
    static assert(!hasAliasing!S4);
}

unittest
{
    static assert( hasAliasing!(uint[uint]));
    static assert(!hasAliasing!(immutable(uint[uint])));
    static assert( hasAliasing!(void delegate()));
    static assert( hasAliasing!(void delegate() const));
    static assert(!hasAliasing!(void delegate() immutable));
    static assert( hasAliasing!(void delegate() shared));
    static assert( hasAliasing!(void delegate() shared const));
    static assert( hasAliasing!(const(void delegate())));
    static assert( hasAliasing!(const(void delegate() const)));
    static assert(!hasAliasing!(const(void delegate() immutable)));
    static assert( hasAliasing!(const(void delegate() shared)));
    static assert( hasAliasing!(const(void delegate() shared const)));
    static assert(!hasAliasing!(immutable(void delegate())));
    static assert(!hasAliasing!(immutable(void delegate() const)));
    static assert(!hasAliasing!(immutable(void delegate() immutable)));
    static assert(!hasAliasing!(immutable(void delegate() shared)));
    static assert(!hasAliasing!(immutable(void delegate() shared const)));
    static assert( hasAliasing!(shared(const(void delegate()))));
    static assert( hasAliasing!(shared(const(void delegate() const))));
    static assert(!hasAliasing!(shared(const(void delegate() immutable))));
    static assert( hasAliasing!(shared(const(void delegate() shared))));
    static assert( hasAliasing!(shared(const(void delegate() shared const))));
    static assert(!hasAliasing!(void function()));

    interface I;
    static assert( hasAliasing!I);

    import std.typecons : Rebindable;
    static assert( hasAliasing!(Rebindable!(const Object)));
    static assert(!hasAliasing!(Rebindable!(immutable Object)));
    static assert( hasAliasing!(Rebindable!(shared Object)));
    static assert( hasAliasing!(Rebindable!Object));

    struct S5
    {
        void delegate() immutable b;
        shared(void delegate() immutable) f;
        immutable(void delegate() immutable) j;
        shared(const(void delegate() immutable)) n;
    }
    struct S6 { typeof(S5.tupleof) a; void delegate() p; }
    static assert(!hasAliasing!S5);
    static assert( hasAliasing!S6);

    struct S7 { void delegate() a; int b; Object c; }
    class S8 { int a; int b; }
    class S9 { typeof(S8.tupleof) a; }
    class S10 { typeof(S8.tupleof) a; int* b; }
    static assert( hasAliasing!S7);
    static assert( hasAliasing!S8);
    static assert( hasAliasing!S9);
    static assert( hasAliasing!S10);
    struct S11 {}
    class S12 {}
    interface S13 {}
    union S14 {}
    static assert(!hasAliasing!S11);
    static assert( hasAliasing!S12);
    static assert( hasAliasing!S13);
    static assert(!hasAliasing!S14);
}
/**
Returns $(D true) if and only if $(D T)'s representation includes at
least one of the following: $(OL $(LI a raw pointer $(D U*);) $(LI an
array $(D U[]);) $(LI a reference to a class type $(D C).)
$(LI an associative array.) $(LI a delegate.))
 */
template hasIndirections(T)
{
    static if (is(T == struct) || is(T == union))
        enum hasIndirections = anySatisfy!(.hasIndirections, FieldTypeTuple!T);
    else static if (isStaticArray!T && is(T : E[N], E, size_t N))
        enum hasIndirections = is(E == void) ? true : hasIndirections!E;
    else static if (isFunctionPointer!T)
        enum hasIndirections = false;
    else
        enum hasIndirections = isPointer!T || isDelegate!T || isDynamicArray!T ||
            isAssociativeArray!T || is (T == class) || is(T == interface);
}

///
unittest
{
    static assert( hasIndirections!(int[string]));
    static assert( hasIndirections!(void delegate()));
    static assert( hasIndirections!(void delegate() immutable));
    static assert( hasIndirections!(immutable(void delegate())));
    static assert( hasIndirections!(immutable(void delegate() immutable)));

    static assert(!hasIndirections!(void function()));
    static assert( hasIndirections!(void*[1]));
    static assert(!hasIndirections!(byte[1]));
}

unittest
{
    // void static array hides actual type of bits, so "may have indirections".
    static assert( hasIndirections!(void[1]));
    interface I {}
    struct S1 {}
    struct S2 { int a; }
    struct S3 { int a; int b; }
    struct S4 { int a; int* b; }
    struct S5 { int a; Object b; }
    struct S6 { int a; string b; }
    struct S7 { int a; immutable Object b; }
    struct S8 { int a; immutable I b; }
    struct S9 { int a; void delegate() b; }
    struct S10 { int a; immutable(void delegate()) b; }
    struct S11 { int a; void delegate() immutable b; }
    struct S12 { int a; immutable(void delegate() immutable) b; }
    class S13 {}
    class S14 { int a; }
    class S15 { int a; int b; }
    class S16 { int a; Object b; }
    class S17 { string a; }
    class S18 { int a; immutable Object b; }
    class S19 { int a; immutable(void delegate() immutable) b; }
    union S20 {}
    union S21 { int a; }
    union S22 { int a; int b; }
    union S23 { int a; Object b; }
    union S24 { string a; }
    union S25 { int a; immutable Object b; }
    union S26 { int a; immutable(void delegate() immutable) b; }
    static assert( hasIndirections!I);
    static assert(!hasIndirections!S1);
    static assert(!hasIndirections!S2);
    static assert(!hasIndirections!S3);
    static assert( hasIndirections!S4);
    static assert( hasIndirections!S5);
    static assert( hasIndirections!S6);
    static assert( hasIndirections!S7);
    static assert( hasIndirections!S8);
    static assert( hasIndirections!S9);
    static assert( hasIndirections!S10);
    static assert( hasIndirections!S12);
    static assert( hasIndirections!S13);
    static assert( hasIndirections!S14);
    static assert( hasIndirections!S15);
    static assert( hasIndirections!S16);
    static assert( hasIndirections!S17);
    static assert( hasIndirections!S18);
    static assert( hasIndirections!S19);
    static assert(!hasIndirections!S20);
    static assert(!hasIndirections!S21);
    static assert(!hasIndirections!S22);
    static assert( hasIndirections!S23);
    static assert( hasIndirections!S24);
    static assert( hasIndirections!S25);
    static assert( hasIndirections!S26);
}

unittest //12000
{
    static struct S(T)
    {
        static assert(hasIndirections!T);
    }

    static class A(T)
    {
        S!A a;
    }

    A!int dummy;
}

/**
Returns $(D true) if and only if $(D T)'s representation includes at
least one of the following: $(OL $(LI a raw pointer $(D U*) and $(D U)
is not immutable or shared;) $(LI an array $(D U[]) and $(D U) is not
immutable or shared;) $(LI a reference to a class type $(D C) and
$(D C) is not immutable or shared.) $(LI an associative array that is not
immutable or shared.) $(LI a delegate that is not shared.))
*/

template hasUnsharedAliasing(T...)
{
    import std.typecons : Rebindable;

    static if (!T.length)
    {
        enum hasUnsharedAliasing = false;
    }
    else static if (is(T[0] R: Rebindable!R))
    {
        enum hasUnsharedAliasing = hasUnsharedAliasing!R;
    }
    else
    {
        template unsharedDelegate(T)
        {
            enum bool unsharedDelegate = isDelegate!T
                                     && !is(T == shared)
                                     && !is(T == shared)
                                     && !is(T == immutable)
                                     && !is(FunctionTypeOf!T == shared)
                                     && !is(FunctionTypeOf!T == immutable);
        }

        enum hasUnsharedAliasing =
            hasRawUnsharedAliasing!(T[0]) ||
            anySatisfy!(unsharedDelegate, RepresentationTypeTuple!(T[0])) ||
            hasUnsharedObjects!(T[0]) ||
            hasUnsharedAliasing!(T[1..$]);
    }
}

///
unittest
{
    struct S1 { int a; Object b; }
    struct S2 { string a; }
    struct S3 { int a; immutable Object b; }
    static assert( hasUnsharedAliasing!S1);
    static assert(!hasUnsharedAliasing!S2);
    static assert(!hasUnsharedAliasing!S3);

    struct S4 { int a; shared Object b; }
    struct S5 { char[] a; }
    struct S6 { shared char[] b; }
    struct S7 { float[3] vals; }
    static assert(!hasUnsharedAliasing!S4);
    static assert( hasUnsharedAliasing!S5);
    static assert(!hasUnsharedAliasing!S6);
    static assert(!hasUnsharedAliasing!S7);
}

unittest
{
    /* Issue 6642 */
    import std.typecons : Rebindable;
    struct S8 { int a; Rebindable!(immutable Object) b; }
    static assert(!hasUnsharedAliasing!S8);

    static assert( hasUnsharedAliasing!(uint[uint]));

    static assert( hasUnsharedAliasing!(void delegate()));
    static assert( hasUnsharedAliasing!(void delegate() const));
    static assert(!hasUnsharedAliasing!(void delegate() immutable));
    static assert(!hasUnsharedAliasing!(void delegate() shared));
    static assert(!hasUnsharedAliasing!(void delegate() shared const));
}

unittest
{
    import std.typecons : Rebindable;
    static assert( hasUnsharedAliasing!(const(void delegate())));
    static assert( hasUnsharedAliasing!(const(void delegate() const)));
    static assert(!hasUnsharedAliasing!(const(void delegate() immutable)));
    static assert(!hasUnsharedAliasing!(const(void delegate() shared)));
    static assert(!hasUnsharedAliasing!(const(void delegate() shared const)));
    static assert(!hasUnsharedAliasing!(immutable(void delegate())));
    static assert(!hasUnsharedAliasing!(immutable(void delegate() const)));
    static assert(!hasUnsharedAliasing!(immutable(void delegate() immutable)));
    static assert(!hasUnsharedAliasing!(immutable(void delegate() shared)));
    static assert(!hasUnsharedAliasing!(immutable(void delegate() shared const)));
    static assert(!hasUnsharedAliasing!(shared(void delegate())));
    static assert(!hasUnsharedAliasing!(shared(void delegate() const)));
    static assert(!hasUnsharedAliasing!(shared(void delegate() immutable)));
    static assert(!hasUnsharedAliasing!(shared(void delegate() shared)));
    static assert(!hasUnsharedAliasing!(shared(void delegate() shared const)));
    static assert(!hasUnsharedAliasing!(shared(const(void delegate()))));
    static assert(!hasUnsharedAliasing!(shared(const(void delegate() const))));
    static assert(!hasUnsharedAliasing!(shared(const(void delegate() immutable))));
    static assert(!hasUnsharedAliasing!(shared(const(void delegate() shared))));
    static assert(!hasUnsharedAliasing!(shared(const(void delegate() shared const))));
    static assert(!hasUnsharedAliasing!(void function()));

    interface I {}
    static assert(hasUnsharedAliasing!I);

    static assert( hasUnsharedAliasing!(Rebindable!(const Object)));
    static assert(!hasUnsharedAliasing!(Rebindable!(immutable Object)));
    static assert(!hasUnsharedAliasing!(Rebindable!(shared Object)));
    static assert( hasUnsharedAliasing!(Rebindable!Object));

    /* Issue 6979 */
    static assert(!hasUnsharedAliasing!(int, shared(int)*));
    static assert( hasUnsharedAliasing!(int, int*));
    static assert( hasUnsharedAliasing!(int, const(int)[]));
    static assert( hasUnsharedAliasing!(int, shared(int)*, Rebindable!Object));
    static assert(!hasUnsharedAliasing!(shared(int)*, Rebindable!(shared Object)));
    static assert(!hasUnsharedAliasing!());

    struct S9
    {
        void delegate() shared a;
        void delegate() immutable b;
        void delegate() shared const c;
        shared(void delegate()) d;
        shared(void delegate() shared) e;
        shared(void delegate() immutable) f;
        shared(void delegate() shared const) g;
        immutable(void delegate()) h;
        immutable(void delegate() shared) i;
        immutable(void delegate() immutable) j;
        immutable(void delegate() shared const) k;
        shared(const(void delegate())) l;
        shared(const(void delegate() shared)) m;
        shared(const(void delegate() immutable)) n;
        shared(const(void delegate() shared const)) o;
    }
    struct S10 { typeof(S9.tupleof) a; void delegate() p; }
    struct S11 { typeof(S9.tupleof) a; Object p; }
    struct S12 { typeof(S9.tupleof) a; int* p; }
    class S13 { typeof(S9.tupleof) a; }
    class S14 { typeof(S9.tupleof) a; void delegate() p; }
    class S15 { typeof(S9.tupleof) a; Object p; }
    class S16 { typeof(S9.tupleof) a; int* p; }
    static assert(!hasUnsharedAliasing!S9);
    static assert(!hasUnsharedAliasing!(immutable(S9)));
    static assert(!hasUnsharedAliasing!(shared(S9)));
    static assert( hasUnsharedAliasing!S10);
    static assert(!hasUnsharedAliasing!(immutable(S10)));
    static assert(!hasUnsharedAliasing!(shared(S10)));
    static assert( hasUnsharedAliasing!S11);
    static assert(!hasUnsharedAliasing!(immutable(S11)));
    static assert(!hasUnsharedAliasing!(shared(S11)));
    static assert( hasUnsharedAliasing!S12);
    static assert(!hasUnsharedAliasing!(immutable(S12)));
    static assert(!hasUnsharedAliasing!(shared(S12)));
    static assert( hasUnsharedAliasing!S13);
    static assert(!hasUnsharedAliasing!(immutable(S13)));
    static assert(!hasUnsharedAliasing!(shared(S13)));
    static assert( hasUnsharedAliasing!S14);
    static assert(!hasUnsharedAliasing!(immutable(S14)));
    static assert(!hasUnsharedAliasing!(shared(S14)));
    static assert( hasUnsharedAliasing!S15);
    static assert(!hasUnsharedAliasing!(immutable(S15)));
    static assert(!hasUnsharedAliasing!(shared(S15)));
    static assert( hasUnsharedAliasing!S16);
    static assert(!hasUnsharedAliasing!(immutable(S16)));
    static assert(!hasUnsharedAliasing!(shared(S16)));
    struct S17 {}
    class S18 {}
    interface S19 {}
    union S20 {}
    static assert(!hasUnsharedAliasing!S17);
    static assert( hasUnsharedAliasing!S18);
    static assert( hasUnsharedAliasing!S19);
    static assert(!hasUnsharedAliasing!S20);
}

/**
 True if $(D S) or any type embedded directly in the representation of $(D S)
 defines an elaborate copy constructor. Elaborate copy constructors are
 introduced by defining $(D this(this)) for a $(D struct).

 Classes and unions never have elaborate copy constructors.
 */
template hasElaborateCopyConstructor(S)
{
    static if(isStaticArray!S && S.length)
    {
        enum bool hasElaborateCopyConstructor = hasElaborateCopyConstructor!(typeof(S.init[0]));
    }
    else static if(is(S == struct))
    {
        enum hasElaborateCopyConstructor = hasMember!(S, "__postblit")
            || anySatisfy!(.hasElaborateCopyConstructor, FieldTypeTuple!S);
    }
    else
    {
        enum bool hasElaborateCopyConstructor = false;
    }
}

///
unittest
{
    static assert(!hasElaborateCopyConstructor!int);

    static struct S1 { }
    static struct S2 { this(this) {} }
    static struct S3 { S2 field; }
    static struct S4 { S3[1] field; }
    static struct S5 { S3[] field; }
    static struct S6 { S3[0] field; }
    static struct S7 { @disable this(); S3 field; }
    static assert(!hasElaborateCopyConstructor!S1);
    static assert( hasElaborateCopyConstructor!S2);
    static assert( hasElaborateCopyConstructor!(immutable S2));
    static assert( hasElaborateCopyConstructor!S3);
    static assert( hasElaborateCopyConstructor!(S3[1]));
    static assert(!hasElaborateCopyConstructor!(S3[0]));
    static assert( hasElaborateCopyConstructor!S4);
    static assert(!hasElaborateCopyConstructor!S5);
    static assert(!hasElaborateCopyConstructor!S6);
    static assert( hasElaborateCopyConstructor!S7);
}

/**
   True if $(D S) or any type directly embedded in the representation of $(D S)
   defines an elaborate assignment. Elaborate assignments are introduced by
   defining $(D opAssign(typeof(this))) or $(D opAssign(ref typeof(this)))
   for a $(D struct) or when there is a compiler-generated $(D opAssign).

   A type $(D S) gets compiler-generated $(D opAssign) in case it has
   an elaborate copy constructor or elaborate destructor.

   Classes and unions never have elaborate assignments.

   Note: Structs with (possibly nested) postblit operator(s) will have a
   hidden yet elaborate compiler generated assignment operator (unless
   explicitly disabled).
 */
template hasElaborateAssign(S)
{
    static if(isStaticArray!S && S.length)
    {
        enum bool hasElaborateAssign = hasElaborateAssign!(typeof(S.init[0]));
    }
    else static if(is(S == struct))
    {
        enum hasElaborateAssign = is(typeof(S.init.opAssign(rvalueOf!S))) ||
                                  is(typeof(S.init.opAssign(lvalueOf!S))) ||
            anySatisfy!(.hasElaborateAssign, FieldTypeTuple!S);
    }
    else
    {
        enum bool hasElaborateAssign = false;
    }
}

///
unittest
{
    static assert(!hasElaborateAssign!int);

    static struct S  { void opAssign(S) {} }
    static assert( hasElaborateAssign!S);
    static assert(!hasElaborateAssign!(const(S)));

    static struct S1 { void opAssign(ref S1) {} }
    static struct S2 { void opAssign(int) {} }
    static struct S3 { S s; }
    static assert( hasElaborateAssign!S1);
    static assert(!hasElaborateAssign!S2);
    static assert( hasElaborateAssign!S3);
    static assert( hasElaborateAssign!(S3[1]));
    static assert(!hasElaborateAssign!(S3[0]));
}

unittest
{
    static struct S  { void opAssign(S) {} }
    static struct S4
    {
        void opAssign(U)(U u) {}
        @disable void opAssign(U)(ref U u);
    }
    static assert( hasElaborateAssign!S4);

    static struct S41
    {
        void opAssign(U)(ref U u) {}
        @disable void opAssign(U)(U u);
    }
    static assert( hasElaborateAssign!S41);

    static struct S5 { @disable this(); this(int n){ s = S(); } S s; }
    static assert( hasElaborateAssign!S5);

    static struct S6 { this(this) {} }
    static struct S7 { this(this) {} @disable void opAssign(S7); }
    static struct S8 { this(this) {} @disable void opAssign(S8); void opAssign(int) {} }
    static struct S9 { this(this) {}                             void opAssign(int) {} }
    static struct S10 { ~this() { } }
    static assert( hasElaborateAssign!S6);
    static assert(!hasElaborateAssign!S7);
    static assert(!hasElaborateAssign!S8);
    static assert( hasElaborateAssign!S9);
    static assert( hasElaborateAssign!S10);
    static struct SS6 { S6 s; }
    static struct SS7 { S7 s; }
    static struct SS8 { S8 s; }
    static struct SS9 { S9 s; }
    static assert( hasElaborateAssign!SS6);
    static assert( hasElaborateAssign!SS7);
    static assert( hasElaborateAssign!SS8);
    static assert( hasElaborateAssign!SS9);
}

/**
   True if $(D S) or any type directly embedded in the representation
   of $(D S) defines an elaborate destructor. Elaborate destructors
   are introduced by defining $(D ~this()) for a $(D
   struct).

   Classes and unions never have elaborate destructors, even
   though classes may define $(D ~this()).
 */
template hasElaborateDestructor(S)
{
    static if(isStaticArray!S && S.length)
    {
        enum bool hasElaborateDestructor = hasElaborateDestructor!(typeof(S.init[0]));
    }
    else static if(is(S == struct))
    {
        enum hasElaborateDestructor = hasMember!(S, "__dtor")
            || anySatisfy!(.hasElaborateDestructor, FieldTypeTuple!S);
    }
    else
    {
        enum bool hasElaborateDestructor = false;
    }
}

///
unittest
{
    static assert(!hasElaborateDestructor!int);

    static struct S1 { }
    static struct S2 { ~this() {} }
    static struct S3 { S2 field; }
    static struct S4 { S3[1] field; }
    static struct S5 { S3[] field; }
    static struct S6 { S3[0] field; }
    static struct S7 { @disable this(); S3 field; }
    static assert(!hasElaborateDestructor!S1);
    static assert( hasElaborateDestructor!S2);
    static assert( hasElaborateDestructor!(immutable S2));
    static assert( hasElaborateDestructor!S3);
    static assert( hasElaborateDestructor!(S3[1]));
    static assert(!hasElaborateDestructor!(S3[0]));
    static assert( hasElaborateDestructor!S4);
    static assert(!hasElaborateDestructor!S5);
    static assert(!hasElaborateDestructor!S6);
    static assert( hasElaborateDestructor!S7);
}

alias Identity(alias A) = A;

/**
   Yields $(D true) if and only if $(D T) is an aggregate that defines
   a symbol called $(D name).
 */
template hasMember(T, string name)
{
    static if (is(T == struct) || is(T == class) || is(T == union) || is(T == interface))
    {
        enum bool hasMember =
            staticIndexOf!(name, __traits(allMembers, T)) != -1 ||
            __traits(compiles, { mixin("alias Sym = Identity!(T."~name~");"); });
    }
    else
    {
        enum bool hasMember = false;
    }
}

///
unittest
{
    static assert(!hasMember!(int, "blah"));
    struct S1 { int blah; }
    struct S2 { int blah(){ return 0; } }
    class C1 { int blah; }
    class C2 { int blah(){ return 0; } }
    static assert(hasMember!(S1, "blah"));
    static assert(hasMember!(S2, "blah"));
    static assert(hasMember!(C1, "blah"));
    static assert(hasMember!(C2, "blah"));
}

unittest
{
    // 8321
    struct S {
        int x;
        void f(){}
        void t()(){}
        template T(){}
    }
    struct R1(T) {
        T t;
        alias t this;
    }
    struct R2(T) {
        T t;
        @property ref inout(T) payload() inout { return t; }
        alias t this;
    }
    static assert(hasMember!(S, "x"));
    static assert(hasMember!(S, "f"));
    static assert(hasMember!(S, "t"));
    static assert(hasMember!(S, "T"));
    static assert(hasMember!(R1!S, "x"));
    static assert(hasMember!(R1!S, "f"));
    static assert(hasMember!(R1!S, "t"));
    static assert(hasMember!(R1!S, "T"));
    static assert(hasMember!(R2!S, "x"));
    static assert(hasMember!(R2!S, "f"));
    static assert(hasMember!(R2!S, "t"));
    static assert(hasMember!(R2!S, "T"));
}

/**
Retrieves the members of an enumerated type $(D enum E).

Params:
 E = An enumerated type. $(D E) may have duplicated values.

Returns:
 Static tuple composed of the members of the enumerated type $(D E).
 The members are arranged in the same order as declared in $(D E).

Note:
 An enum can have multiple members which have the same value. If you want
 to use EnumMembers to e.g. generate switch cases at compile-time,
 you should use the $(XREF typetuple, NoDuplicates) template to avoid
 generating duplicate switch cases.

Note:
 Returned values are strictly typed with $(D E). Thus, the following code
 does not work without the explicit cast:
--------------------
enum E : int { a, b, c }
int[] abc = cast(int[]) [ EnumMembers!E ];
--------------------
 Cast is not necessary if the type of the variable is inferred. See the
 example below.

Examples:
 Creating an array of enumerated values:
--------------------
enum Sqrts : real
{
    one   = 1,
    two   = 1.41421,
    three = 1.73205,
}
auto sqrts = [ EnumMembers!Sqrts ];
assert(sqrts == [ Sqrts.one, Sqrts.two, Sqrts.three ]);
--------------------

 A generic function $(D rank(v)) in the following example uses this
 template for finding a member $(D e) in an enumerated type $(D E).
--------------------
// Returns i if e is the i-th enumerator of E.
size_t rank(E)(E e)
    if (is(E == enum))
{
    foreach (i, member; EnumMembers!E)
    {
        if (e == member)
            return i;
    }
    assert(0, "Not an enum member");
}

enum Mode
{
    read  = 1,
    write = 2,
    map   = 4,
}
assert(rank(Mode.read ) == 0);
assert(rank(Mode.write) == 1);
assert(rank(Mode.map  ) == 2);
--------------------
 */
template EnumMembers(E)
    if (is(E == enum))
{
    // Supply the specified identifier to an constant value.
    template WithIdentifier(string ident)
    {
        static if (ident == "Symbolize")
        {
            template Symbolize(alias value)
            {
                enum Symbolize = value;
            }
        }
        else
        {
            mixin("template Symbolize(alias "~ ident ~")"
                 ~"{"
                     ~"alias Symbolize = "~ ident ~";"
                 ~"}");
        }
    }

    template EnumSpecificMembers(names...)
    {
        static if (names.length > 0)
        {
            alias EnumSpecificMembers =
                TypeTuple!(
                    WithIdentifier!(names[0])
                        .Symbolize!(__traits(getMember, E, names[0])),
                    EnumSpecificMembers!(names[1 .. $])
                );
        }
        else
        {
            alias EnumSpecificMembers = TypeTuple!();
        }
    }

    alias EnumMembers = EnumSpecificMembers!(__traits(allMembers, E));
}

unittest
{
    enum A { a }
    static assert([ EnumMembers!A ] == [ A.a ]);
    enum B { a, b, c, d, e }
    static assert([ EnumMembers!B ] == [ B.a, B.b, B.c, B.d, B.e ]);
}

unittest    // typed enums
{
    enum A : string { a = "alpha", b = "beta" }
    static assert([ EnumMembers!A ] == [ A.a, A.b ]);

    static struct S
    {
        int value;
        int opCmp(S rhs) const nothrow { return value - rhs.value; }
    }
    enum B : S { a = S(1), b = S(2), c = S(3) }
    static assert([ EnumMembers!B ] == [ B.a, B.b, B.c ]);
}

unittest    // duplicated values
{
    enum A
    {
        a = 0, b = 0,
        c = 1, d = 1, e
    }
    static assert([ EnumMembers!A ] == [ A.a, A.b, A.c, A.d, A.e ]);
}

unittest
{
    enum E { member, a = 0, b = 0 }
    static assert(__traits(identifier, EnumMembers!E[0]) == "member");
    static assert(__traits(identifier, EnumMembers!E[1]) == "a");
    static assert(__traits(identifier, EnumMembers!E[2]) == "b");
}


//::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::://
// Classes and Interfaces
//::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::://

/***
 * Get a $(D_PARAM TypeTuple) of the base class and base interfaces of
 * this class or interface. $(D_PARAM BaseTypeTuple!Object) returns
 * the empty type tuple.
 */
template BaseTypeTuple(A)
{
    static if (is(A P == super))
        alias BaseTypeTuple = P;
    else
        static assert(0, "argument is not a class or interface");
}

///
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

    alias TL = BaseTypeTuple!C;
    assert(TL.length == 3);
    assert(is (TL[0] == A));
    assert(is (TL[1] == I1));
    assert(is (TL[2] == I2));

    assert(BaseTypeTuple!Object.length == 0);
}

/**
 * Get a $(D_PARAM TypeTuple) of $(I all) base classes of this class,
 * in decreasing order. Interfaces are not included. $(D_PARAM
 * BaseClassesTuple!Object) yields the empty type tuple.
 */
template BaseClassesTuple(T)
    if (is(T == class))
{
    static if (is(T == Object))
    {
        alias BaseClassesTuple = TypeTuple!();
    }
    else static if (is(BaseTypeTuple!T[0] == Object))
    {
        alias BaseClassesTuple = TypeTuple!Object;
    }
    else
    {
        alias BaseClassesTuple =
            TypeTuple!(BaseTypeTuple!T[0],
                       BaseClassesTuple!(BaseTypeTuple!T[0]));
    }
}

///
unittest
{
    class C1 { }
    class C2 : C1 { }
    class C3 : C2 { }
    static assert(!BaseClassesTuple!Object.length);
    static assert(is(BaseClassesTuple!C1 == TypeTuple!(Object)));
    static assert(is(BaseClassesTuple!C2 == TypeTuple!(C1, Object)));
    static assert(is(BaseClassesTuple!C3 == TypeTuple!(C2, C1, Object)));
    static assert(!BaseClassesTuple!Object.length);
}

unittest
{
    struct S { }
    static assert(!__traits(compiles, BaseClassesTuple!S));
    interface I { }
    static assert(!__traits(compiles, BaseClassesTuple!I));
    class C4 : I { }
    class C5 : C4, I { }
    static assert(is(BaseClassesTuple!C5 == TypeTuple!(C4, Object)));
}

/**
 * Get a $(D_PARAM TypeTuple) of $(I all) interfaces directly or
 * indirectly inherited by this class or interface. Interfaces do not
 * repeat if multiply implemented. $(D_PARAM InterfacesTuple!Object)
 * yields the empty type tuple.
 */
template InterfacesTuple(T)
{
    template Flatten(H, T...)
    {
        static if (T.length)
        {
            alias Flatten = TypeTuple!(Flatten!H, Flatten!T);
        }
        else
        {
            static if (is(H == interface))
                alias Flatten = TypeTuple!(H, InterfacesTuple!H);
            else
                alias Flatten = InterfacesTuple!H;
        }
    }

    static if (is(T S == super) && S.length)
        alias InterfacesTuple = NoDuplicates!(Flatten!S);
    else
        alias InterfacesTuple = TypeTuple!();
}

unittest
{
    // doc example
    interface I1 {}
    interface I2 {}
    class A : I1, I2 { }
    class B : A, I1 { }
    class C : B { }
    alias TL = InterfacesTuple!C;
    static assert(is(TL[0] == I1) && is(TL[1] == I2));
}

unittest
{
    interface Iaa {}
    interface Iab {}
    interface Iba {}
    interface Ibb {}
    interface Ia : Iaa, Iab {}
    interface Ib : Iba, Ibb {}
    interface I : Ia, Ib {}
    interface J {}
    class B2 : J {}
    class C2 : B2, Ia, Ib {}
    static assert(is(InterfacesTuple!I ==
                    TypeTuple!(Ia, Iaa, Iab, Ib, Iba, Ibb)));
    static assert(is(InterfacesTuple!C2 ==
                    TypeTuple!(J, Ia, Iaa, Iab, Ib, Iba, Ibb)));

}

/**
 * Get a $(D_PARAM TypeTuple) of $(I all) base classes of $(D_PARAM
 * T), in decreasing order, followed by $(D_PARAM T)'s
 * interfaces. $(D_PARAM TransitiveBaseTypeTuple!Object) yields the
 * empty type tuple.
 */
template TransitiveBaseTypeTuple(T)
{
    static if (is(T == Object))
        alias TransitiveBaseTypeTuple = TypeTuple!();
    else
        alias TransitiveBaseTypeTuple =
            TypeTuple!(BaseClassesTuple!T, InterfacesTuple!T);
}

///
unittest
{
    interface J1 {}
    interface J2 {}
    class B1 {}
    class B2 : B1, J1, J2 {}
    class B3 : B2, J1 {}
    alias TL = TransitiveBaseTypeTuple!B3;
    assert(TL.length == 5);
    assert(is (TL[0] == B2));
    assert(is (TL[1] == B1));
    assert(is (TL[2] == Object));
    assert(is (TL[3] == J1));
    assert(is (TL[4] == J2));

    assert(TransitiveBaseTypeTuple!Object.length == 0);
}


/**
Returns a tuple of non-static functions with the name $(D name) declared in the
class or interface $(D C).  Covariant duplicates are shrunk into the most
derived one.
 */
template MemberFunctionsTuple(C, string name)
    if (is(C == class) || is(C == interface))
{
    static if (__traits(hasMember, C, name))
    {
        /*
         * First, collect all overloads in the class hierarchy.
         */
        template CollectOverloads(Node)
        {
            static if (__traits(hasMember, Node, name) && __traits(compiles, __traits(getMember, Node, name)))
            {
                // Get all overloads in sight (not hidden).
                alias TypeTuple!(__traits(getVirtualFunctions, Node, name)) inSight;

                // And collect all overloads in ancestor classes to reveal hidden
                // methods.  The result may contain duplicates.
                template walkThru(Parents...)
                {
                    static if (Parents.length > 0)
                        alias TypeTuple!(
                                    CollectOverloads!(Parents[0]),
                                    walkThru!(Parents[1 .. $])
                                ) walkThru;
                    else
                        alias TypeTuple!() walkThru;
                }

                static if (is(Node Parents == super))
                    alias TypeTuple!(inSight, walkThru!Parents) CollectOverloads;
                else
                    alias TypeTuple!inSight CollectOverloads;
            }
            else
                alias TypeTuple!() CollectOverloads; // no overloads in this hierarchy
        }

        // duplicates in this tuple will be removed by shrink()
        alias CollectOverloads!C overloads;

        // shrinkOne!args[0]    = the most derived one in the covariant siblings of target
        // shrinkOne!args[1..$] = non-covariant others
        template shrinkOne(/+ alias target, rest... +/ args...)
        {
            alias args[0 .. 1] target; // prevent property functions from being evaluated
            alias args[1 .. $] rest;

            static if (rest.length > 0)
            {
                alias FunctionTypeOf!target Target;
                alias FunctionTypeOf!(rest[0]) Rest0;

                static if (isCovariantWith!(Target, Rest0))
                    // target overrides rest[0] -- erase rest[0].
                    alias shrinkOne!(target, rest[1 .. $]) shrinkOne;
                else static if (isCovariantWith!(Rest0, Target))
                    // rest[0] overrides target -- erase target.
                    alias shrinkOne!(rest[0], rest[1 .. $]) shrinkOne;
                else
                    // target and rest[0] are distinct.
                    alias TypeTuple!(
                                shrinkOne!(target, rest[1 .. $]),
                                rest[0] // keep
                            ) shrinkOne;
            }
            else
                alias TypeTuple!target shrinkOne; // done
        }

        /*
         * Now shrink covariant overloads into one.
         */
        template shrink(overloads...)
        {
            static if (overloads.length > 0)
            {
                alias shrinkOne!overloads temp;
                alias TypeTuple!(temp[0], shrink!(temp[1 .. $])) shrink;
            }
            else
                alias TypeTuple!() shrink; // done
        }

        // done.
        alias shrink!overloads MemberFunctionsTuple;
    }
    else
        alias TypeTuple!() MemberFunctionsTuple;
}

///
unittest
{
    interface I { I foo(); }
    class B
    {
        real foo(real v) { return v; }
    }
    class C : B, I
    {
        override C foo() { return this; } // covariant overriding of I.foo()
    }
    alias MemberFunctionsTuple!(C, "foo") foos;
    static assert(foos.length == 2);
    static assert(__traits(isSame, foos[0], C.foo));
    static assert(__traits(isSame, foos[1], B.foo));
}

unittest
{
    interface I     { I test(); }
    interface J : I { J test(); }
    interface K     { K test(int); }
    class B : I, K
    {
        K test(int) { return this; }
        B test() { return this; }
        static void test(string) { }
    }
    class C : B, J
    {
        override C test() { return this; }
    }
    alias test =MemberFunctionsTuple!(C, "test");
    static assert(test.length == 2);
    static assert(is(FunctionTypeOf!(test[0]) == FunctionTypeOf!(C.test)));
    static assert(is(FunctionTypeOf!(test[1]) == FunctionTypeOf!(K.test)));
    alias noexist = MemberFunctionsTuple!(C, "noexist");
    static assert(noexist.length == 0);

    interface L { int prop() @property; }
    alias prop = MemberFunctionsTuple!(L, "prop");
    static assert(prop.length == 1);

    interface Test_I
    {
        void foo();
        void foo(int);
        void foo(int, int);
    }
    interface Test : Test_I {}
    alias Test_foo = MemberFunctionsTuple!(Test, "foo");
    static assert(Test_foo.length == 3);
    static assert(is(typeof(&Test_foo[0]) == void function()));
    static assert(is(typeof(&Test_foo[2]) == void function(int)));
    static assert(is(typeof(&Test_foo[1]) == void function(int, int)));
}


/**
Returns an alias to the template that $(D T) is an instance of.
 */
template TemplateOf(alias T : Base!Args, alias Base, Args...)
{
    alias TemplateOf = Base;
}

template TemplateOf(T : Base!Args, alias Base, Args...)
{
    alias TemplateOf = Base;
}

///
unittest
{
    struct Foo(T, U) {}
    static assert(__traits(isSame, TemplateOf!(Foo!(int, real)), Foo));
}

unittest
{
    template Foo1(A) {}
    template Foo2(A, B) {}
    template Foo3(alias A) {}
    template Foo4(string A) {}
    struct Foo5(A) {}
    struct Foo6(A, B) {}
    struct Foo7(alias A) {}
    template Foo8(A) { template Foo9(B) {} }
    template Foo10() {}

    static assert(__traits(isSame, TemplateOf!(Foo1!(int)), Foo1));
    static assert(__traits(isSame, TemplateOf!(Foo2!(int, int)), Foo2));
    static assert(__traits(isSame, TemplateOf!(Foo3!(123)), Foo3));
    static assert(__traits(isSame, TemplateOf!(Foo4!("123")), Foo4));
    static assert(__traits(isSame, TemplateOf!(Foo5!(int)), Foo5));
    static assert(__traits(isSame, TemplateOf!(Foo6!(int, int)), Foo6));
    static assert(__traits(isSame, TemplateOf!(Foo7!(123)), Foo7));
    static assert(__traits(isSame, TemplateOf!(Foo8!(int).Foo9!(real)), Foo8!(int).Foo9));
    static assert(__traits(isSame, TemplateOf!(Foo10!()), Foo10));
}


/**
Returns a $(D TypeTuple) of the template arguments used to instantiate $(D T).
 */
template TemplateArgsOf(alias T : Base!Args, alias Base, Args...)
{
    alias TemplateArgsOf = Args;
}

/// ditto
template TemplateArgsOf(T : Base!Args, alias Base, Args...)
{
    alias TemplateArgsOf = Args;
}

///
unittest
{
    struct Foo(T, U) {}
    static assert(is(TemplateArgsOf!(Foo!(int, real)) == TypeTuple!(int, real)));
}

unittest
{
    template Foo1(A) {}
    template Foo2(A, B) {}
    template Foo3(alias A) {}
    template Foo4(string A) {}
    struct Foo5(A) {}
    struct Foo6(A, B) {}
    struct Foo7(alias A) {}
    template Foo8(A) { template Foo9(B) {} }
    template Foo10() {}

    enum x = 123;
    enum y = "123";
    static assert(is(TemplateArgsOf!(Foo1!(int)) == TypeTuple!(int)));
    static assert(is(TemplateArgsOf!(Foo2!(int, int)) == TypeTuple!(int, int)));
    static assert(__traits(isSame, TemplateArgsOf!(Foo3!(x)), TypeTuple!(x)));
    static assert(TemplateArgsOf!(Foo4!(y)) == TypeTuple!(y));
    static assert(is(TemplateArgsOf!(Foo5!(int)) == TypeTuple!(int)));
    static assert(is(TemplateArgsOf!(Foo6!(int, int)) == TypeTuple!(int, int)));
    static assert(__traits(isSame, TemplateArgsOf!(Foo7!(x)), TypeTuple!(x)));
    static assert(is(TemplateArgsOf!(Foo8!(int).Foo9!(real)) == TypeTuple!(real)));
    static assert(is(TemplateArgsOf!(Foo10!()) == TypeTuple!()));
}


private template maxAlignment(U...) if (isTypeTuple!U)
{
    static if (U.length == 0)
        static assert(0);
    else static if (U.length == 1)
        enum maxAlignment = U[0].alignof;
    else
    {
        import std.algorithm : max;
        enum maxAlignment = max(staticMap!(.maxAlignment, U));
    }
}


/**
Returns class instance alignment.
 */
template classInstanceAlignment(T) if(is(T == class))
{
    alias classInstanceAlignment = maxAlignment!(void*, typeof(T.tupleof));
}

///
unittest
{
    class A { byte b; }
    class B { long l; }

    // As class instance always has a hidden pointer
    static assert(classInstanceAlignment!A == (void*).alignof);
    static assert(classInstanceAlignment!B == long.alignof);
}


//::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::://
// Type Conversion
//::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::://

/**
Get the type that all types can be implicitly converted to. Useful
e.g. in figuring out an array type from a bunch of initializing
values. Returns $(D_PARAM void) if passed an empty list, or if the
types have no common type.
 */
template CommonType(T...)
{
    static if (!T.length)
    {
        alias CommonType = void;
    }
    else static if (T.length == 1)
    {
        static if(is(typeof(T[0])))
        {
            alias CommonType = typeof(T[0]);
        }
        else
        {
            alias CommonType = T[0];
        }
    }
    else static if (is(typeof(true ? T[0].init : T[1].init) U))
    {
        alias CommonType = CommonType!(U, T[2 .. $]);
    }
    else
        alias CommonType = void;
}

///
unittest
{
    alias X = CommonType!(int, long, short);
    assert(is(X == long));
    alias Y = CommonType!(int, char[], short);
    assert(is(Y == void));
}
unittest
{
    static assert(is(CommonType!(3) == int));
    static assert(is(CommonType!(double, 4, float) == double));
    static assert(is(CommonType!(string, char[]) == const(char)[]));
    static assert(is(CommonType!(3, 3U) == uint));
}


/**
 * Returns a tuple with all possible target types of an implicit
 * conversion of a value of type $(D_PARAM T).
 *
 * Important note:
 *
 * The possible targets are computed more conservatively than the D
 * 2.005 compiler does, eliminating all dangerous conversions. For
 * example, $(D_PARAM ImplicitConversionTargets!double) does not
 * include $(D_PARAM float).
 */
template ImplicitConversionTargets(T)
{
    static if (is(T == bool))
        alias ImplicitConversionTargets =
            TypeTuple!(byte, ubyte, short, ushort, int, uint, long, ulong,
                       float, double, real, char, wchar, dchar);
    else static if (is(T == byte))
        alias ImplicitConversionTargets =
            TypeTuple!(short, ushort, int, uint, long, ulong,
                       float, double, real, char, wchar, dchar);
    else static if (is(T == ubyte))
        alias ImplicitConversionTargets =
            TypeTuple!(short, ushort, int, uint, long, ulong,
                       float, double, real, char, wchar, dchar);
    else static if (is(T == short))
        alias ImplicitConversionTargets =
            TypeTuple!(int, uint, long, ulong, float, double, real);
    else static if (is(T == ushort))
        alias ImplicitConversionTargets =
            TypeTuple!(int, uint, long, ulong, float, double, real);
    else static if (is(T == int))
        alias ImplicitConversionTargets =
            TypeTuple!(long, ulong, float, double, real);
    else static if (is(T == uint))
        alias ImplicitConversionTargets =
            TypeTuple!(long, ulong, float, double, real);
    else static if (is(T == long))
        alias ImplicitConversionTargets = TypeTuple!(float, double, real);
    else static if (is(T == ulong))
        alias ImplicitConversionTargets = TypeTuple!(float, double, real);
    else static if (is(T == float))
        alias ImplicitConversionTargets = TypeTuple!(double, real);
    else static if (is(T == double))
        alias ImplicitConversionTargets = TypeTuple!real;
    else static if (is(T == char))
        alias ImplicitConversionTargets =
            TypeTuple!(wchar, dchar, byte, ubyte, short, ushort,
                       int, uint, long, ulong, float, double, real);
    else static if (is(T == wchar))
        alias ImplicitConversionTargets =
            TypeTuple!(dchar, short, ushort, int, uint, long, ulong,
                       float, double, real);
    else static if (is(T == dchar))
        alias ImplicitConversionTargets =
            TypeTuple!(int, uint, long, ulong, float, double, real);
    else static if (is(T : typeof(null)))
        alias ImplicitConversionTargets = TypeTuple!(typeof(null));
    else static if(is(T : Object))
        alias ImplicitConversionTargets = TransitiveBaseTypeTuple!(T);
    else static if (isDynamicArray!T && !is(typeof(T.init[0]) == const))
        alias ImplicitConversionTargets =
            TypeTuple!(const(Unqual!(typeof(T.init[0])))[]);
    else static if (is(T : void*))
        alias ImplicitConversionTargets = TypeTuple!(void*);
    else
        alias ImplicitConversionTargets = TypeTuple!();
}

unittest
{
    static assert(is(ImplicitConversionTargets!(double)[0] == real));
    static assert(is(ImplicitConversionTargets!(string)[0] == const(char)[]));
}

/**
Is $(D From) implicitly convertible to $(D To)?
 */
template isImplicitlyConvertible(From, To)
{
    enum bool isImplicitlyConvertible = is(typeof({
        void fun(ref From v)
        {
            void gun(To) {}
            gun(v);
        }
    }));
}

unittest
{
    static assert( isImplicitlyConvertible!(immutable(char), char));
    static assert( isImplicitlyConvertible!(const(char), char));
    static assert( isImplicitlyConvertible!(char, wchar));

    static assert(!isImplicitlyConvertible!(wchar, char));

    // bug6197
    static assert(!isImplicitlyConvertible!(const(ushort), ubyte));
    static assert(!isImplicitlyConvertible!(const(uint), ubyte));
    static assert(!isImplicitlyConvertible!(const(ulong), ubyte));

    // from std.conv.implicitlyConverts
    assert(!isImplicitlyConvertible!(const(char)[], string));
    assert( isImplicitlyConvertible!(string, const(char)[]));
}

/**
Returns $(D true) iff a value of type $(D Rhs) can be assigned to a variable of
type $(D Lhs).

$(D isAssignable) returns whether both an lvalue and rvalue can be assigned.

If you omit $(D Rhs), $(D isAssignable) will check identity assignable of $(D Lhs).
*/
enum isAssignable(Lhs, Rhs = Lhs) = isRvalueAssignable!(Lhs, Rhs) && isLvalueAssignable!(Lhs, Rhs);

///
unittest
{
    static assert( isAssignable!(long, int));
    static assert(!isAssignable!(int, long));
    static assert( isAssignable!(const(char)[], string));
    static assert(!isAssignable!(string, char[]));

    // int is assignable to int
    static assert( isAssignable!int);

    // immutable int is not assignable to immutable int
    static assert(!isAssignable!(immutable int));
}

// ditto
private enum isRvalueAssignable(Lhs, Rhs = Lhs) = __traits(compiles, lvalueOf!Lhs = rvalueOf!Rhs);

// ditto
private enum isLvalueAssignable(Lhs, Rhs = Lhs) = __traits(compiles, lvalueOf!Lhs = lvalueOf!Rhs);

unittest
{
    static assert(!isAssignable!(immutable int, int));
    static assert( isAssignable!(int, immutable int));

    static assert(!isAssignable!(inout int, int));
    static assert( isAssignable!(int, inout int));
    static assert(!isAssignable!(inout int));

    static assert( isAssignable!(shared int, int));
    static assert( isAssignable!(int, shared int));
    static assert( isAssignable!(shared int));

    static assert( isAssignable!(void[1], void[1]));

    struct S { @disable this(); this(int n){} }
    static assert( isAssignable!(S, S));

    struct S2 { this(int n){} }
    static assert( isAssignable!(S2, S2));
    static assert(!isAssignable!(S2, int));

    struct S3 { @disable void opAssign(); }
    static assert( isAssignable!(S3, S3));

    struct S3X { @disable void opAssign(S3X); }
    static assert(!isAssignable!(S3X, S3X));

    struct S4 { void opAssign(int); }
    static assert( isAssignable!(S4, S4));
    static assert( isAssignable!(S4, int));
    static assert( isAssignable!(S4, immutable int));

    struct S5 { @disable this(); @disable this(this); }
    struct S6 { void opAssign(in ref S5); }
    static assert(!isAssignable!(S6, S5));
    static assert(!isRvalueAssignable!(S6, S5));
    static assert( isLvalueAssignable!(S6, S5));
    static assert( isLvalueAssignable!(S6, immutable S5));
}


// Equivalent with TypeStruct::isAssignable in compiler code.
package template isBlitAssignable(T)
{
    static if (is(OriginalType!T U) && !is(T == U))
    {
        enum isBlitAssignable = isBlitAssignable!U;
    }
    else static if (isStaticArray!T && is(T == E[n], E, size_t n))
    // Workaround for issue 11499 : isStaticArray!T should not be necessary.
    {
        enum isBlitAssignable = isBlitAssignable!E;
    }
    else static if (is(T == struct) || is(T == union))
    {
        enum isBlitAssignable = isMutable!T &&
        {
            size_t offset = 0;
            bool assignable = true;
            foreach (i, F; FieldTypeTuple!T)
            {
                static if (i == 0)
                {
                }
                else if (T.tupleof[i].offsetof == offset)
                {
                    if (assignable)
                        continue;
                }
                else
                {
                    if (!assignable)
                        return false;
                }
                assignable = isBlitAssignable!(typeof(T.tupleof[i]));
                offset = T.tupleof[i].offsetof;
            }
            return assignable;
        }();
    }
    else
        enum isBlitAssignable = isMutable!T;
}

unittest
{
    static assert( isBlitAssignable!int);
    static assert(!isBlitAssignable!(const int));

    class C{ const int i; }
    static assert( isBlitAssignable!C);

    struct S1{ int i; }
    struct S2{ const int i; }
    static assert( isBlitAssignable!S1);
    static assert(!isBlitAssignable!S2);

    struct S3X { union {       int x;       int y; } }
    struct S3Y { union {       int x; const int y; } }
    struct S3Z { union { const int x; const int y; } }
    static assert( isBlitAssignable!(S3X));
    static assert( isBlitAssignable!(S3Y));
    static assert(!isBlitAssignable!(S3Z));
    static assert(!isBlitAssignable!(const S3X));
    static assert(!isBlitAssignable!(inout S3Y));
    static assert(!isBlitAssignable!(immutable S3Z));
    static assert( isBlitAssignable!(S3X[3]));
    static assert( isBlitAssignable!(S3Y[3]));
    static assert(!isBlitAssignable!(S3Z[3]));
    enum ES3X : S3X { a = S3X() }
    enum ES3Y : S3Y { a = S3Y() }
    enum ES3Z : S3Z { a = S3Z() }
    static assert( isBlitAssignable!(ES3X));
    static assert( isBlitAssignable!(ES3Y));
    static assert(!isBlitAssignable!(ES3Z));
    static assert(!isBlitAssignable!(const ES3X));
    static assert(!isBlitAssignable!(inout ES3Y));
    static assert(!isBlitAssignable!(immutable ES3Z));
    static assert( isBlitAssignable!(ES3X[3]));
    static assert( isBlitAssignable!(ES3Y[3]));
    static assert(!isBlitAssignable!(ES3Z[3]));

    union U1X {       int x;       int y; }
    union U1Y {       int x; const int y; }
    union U1Z { const int x; const int y; }
    static assert( isBlitAssignable!(U1X));
    static assert( isBlitAssignable!(U1Y));
    static assert(!isBlitAssignable!(U1Z));
    static assert(!isBlitAssignable!(const U1X));
    static assert(!isBlitAssignable!(inout U1Y));
    static assert(!isBlitAssignable!(immutable U1Z));
    static assert( isBlitAssignable!(U1X[3]));
    static assert( isBlitAssignable!(U1Y[3]));
    static assert(!isBlitAssignable!(U1Z[3]));
    enum EU1X : U1X { a = U1X() }
    enum EU1Y : U1Y { a = U1Y() }
    enum EU1Z : U1Z { a = U1Z() }
    static assert( isBlitAssignable!(EU1X));
    static assert( isBlitAssignable!(EU1Y));
    static assert(!isBlitAssignable!(EU1Z));
    static assert(!isBlitAssignable!(const EU1X));
    static assert(!isBlitAssignable!(inout EU1Y));
    static assert(!isBlitAssignable!(immutable EU1Z));
    static assert( isBlitAssignable!(EU1X[3]));
    static assert( isBlitAssignable!(EU1Y[3]));
    static assert(!isBlitAssignable!(EU1Z[3]));

    struct SA
    {
        @property int[3] foo() { return [1,2,3]; }
        alias foo this;
        const int x;    // SA is not blit assignable
    }
    static assert(!isStaticArray!SA);
    static assert(!isBlitAssignable!(SA[3]));
}


/*
Works like $(D isImplicitlyConvertible), except this cares only about storage
classes of the arguments.
 */
private template isStorageClassImplicitlyConvertible(From, To)
{
    alias Pointify(T) = void*;

    enum isStorageClassImplicitlyConvertible = isImplicitlyConvertible!(
            ModifyTypePreservingSTC!(Pointify, From),
            ModifyTypePreservingSTC!(Pointify,   To) );
}

unittest
{
    static assert( isStorageClassImplicitlyConvertible!(          int, const int));
    static assert( isStorageClassImplicitlyConvertible!(immutable int, const int));

    static assert(!isStorageClassImplicitlyConvertible!(const int,           int));
    static assert(!isStorageClassImplicitlyConvertible!(const int, immutable int));
    static assert(!isStorageClassImplicitlyConvertible!(int, shared int));
    static assert(!isStorageClassImplicitlyConvertible!(shared int, int));
}


/**
Determines whether the function type $(D F) is covariant with $(D G), i.e.,
functions of the type $(D F) can override ones of the type $(D G).
 */
template isCovariantWith(F, G)
    if (is(F == function) && is(G == function))
{
    static if (is(F : G))
        enum isCovariantWith = true;
    else
    {
        alias Upr = F;
        alias Lwr = G;

        /*
         * Check for calling convention: require exact match.
         */
        template checkLinkage()
        {
            enum ok = functionLinkage!Upr == functionLinkage!Lwr;
        }
        /*
         * Check for variadic parameter: require exact match.
         */
        template checkVariadicity()
        {
            enum ok = variadicFunctionStyle!Upr == variadicFunctionStyle!Lwr;
        }
        /*
         * Check for function storage class:
         *  - overrider can have narrower storage class than base
         */
        template checkSTC()
        {
            // Note the order of arguments.  The convertion order Lwr -> Upr is
            // correct since Upr should be semantically 'narrower' than Lwr.
            enum ok = isStorageClassImplicitlyConvertible!(Lwr, Upr);
        }
        /*
         * Check for function attributes:
         *  - require exact match for ref and @property
         *  - overrider can add pure and nothrow, but can't remove them
         *  - @safe and @trusted are covariant with each other, unremovable
         */
        template checkAttributes()
        {
            alias FA = FunctionAttribute;
            enum uprAtts = functionAttributes!Upr;
            enum lwrAtts = functionAttributes!Lwr;
            //
            enum wantExact = FA.ref_ | FA.property;
            enum safety = FA.safe | FA.trusted;
            enum ok =
                (  (uprAtts & wantExact)   == (lwrAtts & wantExact)) &&
                (  (uprAtts & FA.pure_   ) >= (lwrAtts & FA.pure_   )) &&
                (  (uprAtts & FA.nothrow_) >= (lwrAtts & FA.nothrow_)) &&
                (!!(uprAtts & safety    )  >= !!(lwrAtts & safety    )) ;
        }
        /*
         * Check for return type: usual implicit convertion.
         */
        template checkReturnType()
        {
            enum ok = is(ReturnType!Upr : ReturnType!Lwr);
        }
        /*
         * Check for parameters:
         *  - require exact match for types (cf. bugzilla 3075)
         *  - require exact match for in, out, ref and lazy
         *  - overrider can add scope, but can't remove
         */
        template checkParameters()
        {
            alias STC = ParameterStorageClass;
            alias UprParams = ParameterTypeTuple!Upr;
            alias LwrParams = ParameterTypeTuple!Lwr;
            alias UprPSTCs  = ParameterStorageClassTuple!Upr;
            alias LwrPSTCs  = ParameterStorageClassTuple!Lwr;
            //
            template checkNext(size_t i)
            {
                static if (i < UprParams.length)
                {
                    enum uprStc = UprPSTCs[i];
                    enum lwrStc = LwrPSTCs[i];
                    //
                    enum wantExact = STC.out_ | STC.ref_ | STC.lazy_;
                    enum ok =
                        ((uprStc & wantExact )  == (lwrStc & wantExact )) &&
                        ((uprStc & STC.scope_)  >= (lwrStc & STC.scope_)) &&
                        checkNext!(i + 1).ok;
                }
                else
                    enum ok = true; // done
            }
            static if (UprParams.length == LwrParams.length)
                enum ok = is(UprParams == LwrParams) && checkNext!(0).ok;
            else
                enum ok = false;
        }

        /* run all the checks */
        enum isCovariantWith =
            checkLinkage    !().ok &&
            checkVariadicity!().ok &&
            checkSTC        !().ok &&
            checkAttributes !().ok &&
            checkReturnType !().ok &&
            checkParameters !().ok ;
    }
}

///
unittest
{
    interface I { I clone(); }
    interface J { J clone(); }
    class C : I
    {
        override C clone()   // covariant overriding of I.clone()
        {
            return new C;
        }
    }

    // C.clone() can override I.clone(), indeed.
    static assert(isCovariantWith!(typeof(C.clone), typeof(I.clone)));

    // C.clone() can't override J.clone(); the return type C is not implicitly
    // convertible to J.
    static assert(!isCovariantWith!(typeof(C.clone), typeof(J.clone)));
}

unittest
{
    enum bool isCovariantWith(alias f, alias g) = .isCovariantWith!(typeof(f), typeof(g));

    // covariant return type
    interface I     {}
    interface J : I {}
    interface BaseA            {          const(I) test(int); }
    interface DerivA_1 : BaseA { override const(J) test(int); }
    interface DerivA_2 : BaseA { override       J  test(int); }
    static assert( isCovariantWith!(DerivA_1.test, BaseA.test));
    static assert( isCovariantWith!(DerivA_2.test, BaseA.test));
    static assert(!isCovariantWith!(BaseA.test, DerivA_1.test));
    static assert(!isCovariantWith!(BaseA.test, DerivA_2.test));
    static assert( isCovariantWith!(BaseA.test, BaseA.test));
    static assert( isCovariantWith!(DerivA_1.test, DerivA_1.test));
    static assert( isCovariantWith!(DerivA_2.test, DerivA_2.test));

    // scope parameter
    interface BaseB            {          void test(      int,       int); }
    interface DerivB_1 : BaseB { override void test(scope int,       int); }
    interface DerivB_2 : BaseB { override void test(      int, scope int); }
    interface DerivB_3 : BaseB { override void test(scope int, scope int); }
    static assert( isCovariantWith!(DerivB_1.test, BaseB.test));
    static assert( isCovariantWith!(DerivB_2.test, BaseB.test));
    static assert( isCovariantWith!(DerivB_3.test, BaseB.test));
    static assert(!isCovariantWith!(BaseB.test, DerivB_1.test));
    static assert(!isCovariantWith!(BaseB.test, DerivB_2.test));
    static assert(!isCovariantWith!(BaseB.test, DerivB_3.test));

    // function storage class
    interface BaseC            {          void test()      ; }
    interface DerivC_1 : BaseC { override void test() const; }
    static assert( isCovariantWith!(DerivC_1.test, BaseC.test));
    static assert(!isCovariantWith!(BaseC.test, DerivC_1.test));

    // increasing safety
    interface BaseE            {          void test()         ; }
    interface DerivE_1 : BaseE { override void test() @safe   ; }
    interface DerivE_2 : BaseE { override void test() @trusted; }
    static assert( isCovariantWith!(DerivE_1.test, BaseE.test));
    static assert( isCovariantWith!(DerivE_2.test, BaseE.test));
    static assert(!isCovariantWith!(BaseE.test, DerivE_1.test));
    static assert(!isCovariantWith!(BaseE.test, DerivE_2.test));

    // @safe and @trusted
    interface BaseF
    {
        void test1() @safe;
        void test2() @trusted;
    }
    interface DerivF : BaseF
    {
        override void test1() @trusted;
        override void test2() @safe;
    }
    static assert( isCovariantWith!(DerivF.test1, BaseF.test1));
    static assert( isCovariantWith!(DerivF.test2, BaseF.test2));
}


// Needed for rvalueOf/lvalueOf because "inout on return means
// inout must be on a parameter as well"
private struct __InoutWorkaroundStruct{}

/**
Creates an lvalue or rvalue of type $(D T) for $(D typeof(...)) and
$(D __traits(compiles, ...)) purposes. No actual value is returned.

Note: Trying to use returned value will result in a
"Symbol Undefined" error at link time.

Examples:
---
// Note that `f` doesn't have to be implemented
// as is isn't called.
int f(int);
bool f(ref int);
static assert(is(typeof(f(rvalueOf!int)) == int));
static assert(is(typeof(f(lvalueOf!int)) == bool));

int i = rvalueOf!int; // error, no actual value is returned
---
*/
@property T rvalueOf(T)(inout __InoutWorkaroundStruct = __InoutWorkaroundStruct.init);

/// ditto
@property ref T lvalueOf(T)(inout __InoutWorkaroundStruct = __InoutWorkaroundStruct.init);

// Note: unittest can't be used as an example here as function overloads
// aren't allowed inside functions.

unittest
{
    void needLvalue(T)(ref T);
    static struct S { }
    int i;
    struct Nested { void f() { ++i; } }
    foreach(T; TypeTuple!(int, immutable int, inout int, string, S, Nested, Object))
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


//::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::://
// SomethingTypeOf
//::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::://

private template AliasThisTypeOf(T) if (isAggregateType!T)
{
    alias members = TypeTuple!(__traits(getAliasThis, T));

    static if (members.length == 1)
    {
        alias AliasThisTypeOf = typeof(__traits(getMember, T.init, members[0]));
    }
    else
        static assert(0, T.stringof~" does not have alias this type");
}

/*
 */
template BooleanTypeOf(T)
{
    static if (is(AliasThisTypeOf!T AT) && !is(AT[] == AT))
        alias X = BooleanTypeOf!AT;
    else
        alias X = OriginalType!T;

    static if (is(Unqual!X == bool))
    {
        alias BooleanTypeOf = X;
    }
    else
        static assert(0, T.stringof~" is not boolean type");
}

unittest
{
    // unexpected failure, maybe dmd type-merging bug
    foreach (T; TypeTuple!bool)
        foreach (Q; TypeQualifierList)
        {
            static assert( is(Q!T == BooleanTypeOf!(            Q!T  )));
            static assert( is(Q!T == BooleanTypeOf!( SubTypeOf!(Q!T) )));
        }

    foreach (T; TypeTuple!(void, NumericTypeList, ImaginaryTypeList, ComplexTypeList, CharTypeList))
        foreach (Q; TypeQualifierList)
        {
            static assert(!is(BooleanTypeOf!(            Q!T  )), Q!T.stringof);
            static assert(!is(BooleanTypeOf!( SubTypeOf!(Q!T) )));
        }
}

unittest
{
    struct B
    {
        bool val;
        alias val this;
    }
    struct S
    {
        B b;
        alias b this;
    }
    static assert(is(BooleanTypeOf!B == bool));
    static assert(is(BooleanTypeOf!S == bool));
}

/*
 */
template IntegralTypeOf(T)
{
    static if (is(AliasThisTypeOf!T AT) && !is(AT[] == AT))
        alias X = IntegralTypeOf!AT;
    else
        alias X = OriginalType!T;

    static if (staticIndexOf!(Unqual!X, IntegralTypeList) >= 0)
    {
        alias IntegralTypeOf = X;
    }
    else
        static assert(0, T.stringof~" is not an integral type");
}

unittest
{
    foreach (T; IntegralTypeList)
        foreach (Q; TypeQualifierList)
        {
            static assert( is(Q!T == IntegralTypeOf!(            Q!T  )));
            static assert( is(Q!T == IntegralTypeOf!( SubTypeOf!(Q!T) )));
        }

    foreach (T; TypeTuple!(void, bool, FloatingPointTypeList, ImaginaryTypeList, ComplexTypeList, CharTypeList))
        foreach (Q; TypeQualifierList)
        {
            static assert(!is(IntegralTypeOf!(            Q!T  )));
            static assert(!is(IntegralTypeOf!( SubTypeOf!(Q!T) )));
        }
}

/*
 */
template FloatingPointTypeOf(T)
{
    static if (is(AliasThisTypeOf!T AT) && !is(AT[] == AT))
        alias X = FloatingPointTypeOf!AT;
    else
        alias X = OriginalType!T;

    static if (staticIndexOf!(Unqual!X, FloatingPointTypeList) >= 0)
    {
        alias FloatingPointTypeOf = X;
    }
    else
        static assert(0, T.stringof~" is not a floating point type");
}

unittest
{
    foreach (T; FloatingPointTypeList)
        foreach (Q; TypeQualifierList)
        {
            static assert( is(Q!T == FloatingPointTypeOf!(            Q!T  )));
            static assert( is(Q!T == FloatingPointTypeOf!( SubTypeOf!(Q!T) )));
        }

    foreach (T; TypeTuple!(void, bool, IntegralTypeList, ImaginaryTypeList, ComplexTypeList, CharTypeList))
        foreach (Q; TypeQualifierList)
        {
            static assert(!is(FloatingPointTypeOf!(            Q!T  )));
            static assert(!is(FloatingPointTypeOf!( SubTypeOf!(Q!T) )));
        }
}

/*
 */
template NumericTypeOf(T)
{
    static if (is(IntegralTypeOf!T X) || is(FloatingPointTypeOf!T X))
    {
        alias NumericTypeOf = X;
    }
    else
        static assert(0, T.stringof~" is not a numeric type");
}

unittest
{
    foreach (T; NumericTypeList)
        foreach (Q; TypeQualifierList)
        {
            static assert( is(Q!T == NumericTypeOf!(            Q!T  )));
            static assert( is(Q!T == NumericTypeOf!( SubTypeOf!(Q!T) )));
        }

    foreach (T; TypeTuple!(void, bool, CharTypeList, ImaginaryTypeList, ComplexTypeList))
        foreach (Q; TypeQualifierList)
        {
            static assert(!is(NumericTypeOf!(            Q!T  )));
            static assert(!is(NumericTypeOf!( SubTypeOf!(Q!T) )));
        }
}

/*
 */
template UnsignedTypeOf(T)
{
    static if (is(IntegralTypeOf!T X) &&
               staticIndexOf!(Unqual!X, UnsignedIntTypeList) >= 0)
        alias UnsignedTypeOf = X;
    else
        static assert(0, T.stringof~" is not an unsigned type.");
}

/*
 */
template SignedTypeOf(T)
{
    static if (is(IntegralTypeOf!T X) &&
               staticIndexOf!(Unqual!X, SignedIntTypeList) >= 0)
        alias SignedTypeOf = X;
    else static if (is(FloatingPointTypeOf!T X))
        alias SignedTypeOf = X;
    else
        static assert(0, T.stringof~" is not an signed type.");
}

/*
 */
template CharTypeOf(T)
{
    static if (is(AliasThisTypeOf!T AT) && !is(AT[] == AT))
        alias X = CharTypeOf!AT;
    else
        alias X = OriginalType!T;

    static if (staticIndexOf!(Unqual!X, CharTypeList) >= 0)
    {
        alias CharTypeOf = X;
    }
    else
        static assert(0, T.stringof~" is not a character type");
}

unittest
{
    foreach (T; CharTypeList)
        foreach (Q; TypeQualifierList)
        {
            static assert( is(CharTypeOf!(            Q!T  )));
            static assert( is(CharTypeOf!( SubTypeOf!(Q!T) )));
        }

    foreach (T; TypeTuple!(void, bool, NumericTypeList, ImaginaryTypeList, ComplexTypeList))
        foreach (Q; TypeQualifierList)
        {
            static assert(!is(CharTypeOf!(            Q!T  )));
            static assert(!is(CharTypeOf!( SubTypeOf!(Q!T) )));
        }

    foreach (T; TypeTuple!(string, wstring, dstring, char[4]))
        foreach (Q; TypeQualifierList)
        {
            static assert(!is(CharTypeOf!(            Q!T  )));
            static assert(!is(CharTypeOf!( SubTypeOf!(Q!T) )));
        }
}

/*
 */
template StaticArrayTypeOf(T)
{
    static if (is(AliasThisTypeOf!T AT) && !is(AT[] == AT))
        alias X = StaticArrayTypeOf!AT;
    else
        alias X = OriginalType!T;

    static if (is(X : E[n], E, size_t n))
        alias StaticArrayTypeOf = X;
    else
        static assert(0, T.stringof~" is not a static array type");
}

unittest
{
    foreach (T; TypeTuple!(bool, NumericTypeList, ImaginaryTypeList, ComplexTypeList))
        foreach (Q; TypeTuple!(TypeQualifierList, InoutOf, SharedInoutOf))
        {
            static assert(is( Q!(   T[1] ) == StaticArrayTypeOf!( Q!(              T[1]  ) ) ));

            foreach (P; TypeQualifierList)
            { // SubTypeOf cannot have inout type
                static assert(is( Q!(P!(T[1])) == StaticArrayTypeOf!( Q!(SubTypeOf!(P!(T[1]))) ) ));
            }
        }

    foreach (T; TypeTuple!void)
        foreach (Q; TypeTuple!TypeQualifierList)
        {
            static assert(is( StaticArrayTypeOf!( Q!(void[1]) ) == Q!(void[1]) ));
        }
}

/*
 */
template DynamicArrayTypeOf(T)
{
    static if (is(AliasThisTypeOf!T AT) && !is(AT[] == AT))
        alias X = DynamicArrayTypeOf!AT;
    else
        alias X = OriginalType!T;

    static if (is(Unqual!X : E[], E) && !is(typeof({ enum n = X.length; })))
    {
        alias DynamicArrayTypeOf = X;
    }
    else
        static assert(0, T.stringof~" is not a dynamic array");
}

unittest
{
    foreach (T; TypeTuple!(/*void, */bool, NumericTypeList, ImaginaryTypeList, ComplexTypeList))
        foreach (Q; TypeTuple!(TypeQualifierList, InoutOf, SharedInoutOf))
        {
            static assert(is( Q!T[]  == DynamicArrayTypeOf!( Q!T[] ) ));
            static assert(is( Q!(T[])  == DynamicArrayTypeOf!( Q!(T[]) ) ));

            foreach (P; TypeTuple!(MutableOf, ConstOf, ImmutableOf))
            {
                static assert(is( Q!(P!T[]) == DynamicArrayTypeOf!( Q!(SubTypeOf!(P!T[])) ) ));
                static assert(is( Q!(P!(T[])) == DynamicArrayTypeOf!( Q!(SubTypeOf!(P!(T[]))) ) ));
            }
        }

    static assert(!is(DynamicArrayTypeOf!(int[3])));
    static assert(!is(DynamicArrayTypeOf!(void[3])));
    static assert(!is(DynamicArrayTypeOf!(typeof(null))));
}

/*
 */
template ArrayTypeOf(T)
{
    static if (is(StaticArrayTypeOf!T X) || is(DynamicArrayTypeOf!T X))
    {
        alias ArrayTypeOf = X;
    }
    else
        static assert(0, T.stringof~" is not an array type");
}

/*
Always returns the Dynamic Array version.
 */
template StringTypeOf(T)
{
    static if (is(T == typeof(null)))
    {
        // It is impossible to determine exact string type from typeof(null) -
        // it means that StringTypeOf!(typeof(null)) is undefined.
        // Then this behavior is convenient for template constraint.
        static assert(0, T.stringof~" is not a string type");
    }
    else static if (is(T : const char[]) || is(T : const wchar[]) || is(T : const dchar[]))
    {
        static if (is(T : U[], U))
            alias StringTypeOf = U[];
        else
            static assert(0);
    }
    else
        static assert(0, T.stringof~" is not a string type");
}

unittest
{
    foreach (T; CharTypeList)
        foreach (Q; TypeTuple!(MutableOf, ConstOf, ImmutableOf, InoutOf))
        {
            static assert(is(Q!T[] == StringTypeOf!( Q!T[] )));

            static if (!__traits(isSame, Q, InoutOf))
            {
                static assert(is(Q!T[] == StringTypeOf!( SubTypeOf!(Q!T[]) )));

                alias Str = Q!T[];
                class C(S) { S val;  alias val this; }
                static assert(is(StringTypeOf!(C!Str) == Str));
            }
        }

    foreach (T; CharTypeList)
        foreach (Q; TypeTuple!(SharedOf, SharedConstOf, SharedInoutOf))
        {
            static assert(!is(StringTypeOf!( Q!T[] )));
        }
}

unittest
{
    static assert(is(StringTypeOf!(char[4]) == char[]));
}

/*
 */
template AssocArrayTypeOf(T)
{
    static if (is(AliasThisTypeOf!T AT) && !is(AT[] == AT))
        alias X = AssocArrayTypeOf!AT;
    else
        alias X = OriginalType!T;

    static if (is(Unqual!X : V[K], K, V))
    {
        alias AssocArrayTypeOf = X;
    }
    else
        static assert(0, T.stringof~" is not an associative array type");
}

unittest
{
    foreach (T; TypeTuple!(int/*bool, CharTypeList, NumericTypeList, ImaginaryTypeList, ComplexTypeList*/))
        foreach (P; TypeTuple!(TypeQualifierList, InoutOf, SharedInoutOf))
            foreach (Q; TypeTuple!(TypeQualifierList, InoutOf, SharedInoutOf))
                foreach (R; TypeTuple!(TypeQualifierList, InoutOf, SharedInoutOf))
                {
                    static assert(is( P!(Q!T[R!T]) == AssocArrayTypeOf!(            P!(Q!T[R!T])  ) ));
                }

    foreach (T; TypeTuple!(int/*bool, CharTypeList, NumericTypeList, ImaginaryTypeList, ComplexTypeList*/))
        foreach (O; TypeTuple!(TypeQualifierList, InoutOf, SharedInoutOf))
            foreach (P; TypeTuple!TypeQualifierList)
                foreach (Q; TypeTuple!TypeQualifierList)
                    foreach (R; TypeTuple!TypeQualifierList)
                    {
                        static assert(is( O!(P!(Q!T[R!T])) == AssocArrayTypeOf!( O!(SubTypeOf!(P!(Q!T[R!T]))) ) ));
                    }
}

/*
 */
template BuiltinTypeOf(T)
{
         static if (is(T : void))               alias BuiltinTypeOf = void;
    else static if (is(BooleanTypeOf!T X))      alias BuiltinTypeOf = X;
    else static if (is(IntegralTypeOf!T X))     alias BuiltinTypeOf = X;
    else static if (is(FloatingPointTypeOf!T X))alias BuiltinTypeOf = X;
    else static if (is(T : const(ireal)))       alias BuiltinTypeOf = ireal;  //TODO
    else static if (is(T : const(creal)))       alias BuiltinTypeOf = creal;  //TODO
    else static if (is(CharTypeOf!T X))         alias BuiltinTypeOf = X;
    else static if (is(ArrayTypeOf!T X))        alias BuiltinTypeOf = X;
    else static if (is(AssocArrayTypeOf!T X))   alias BuiltinTypeOf = X;
    else                                        static assert(0);
}

//::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::://
// isSomething
//::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::://

/**
 * Detect whether $(D T) is a built-in boolean type.
 */
enum bool isBoolean(T) = is(BooleanTypeOf!T) && !isAggregateType!T;

///
unittest
{
    static assert( isBoolean!bool);
    enum EB : bool { a = true }
    static assert( isBoolean!EB);
    static assert(!isBoolean!(SubTypeOf!bool));
}

/**
 * Detect whether $(D T) is a built-in integral type. Types $(D bool),
 * $(D char), $(D wchar), and $(D dchar) are not considered integral.
 */
enum bool isIntegral(T) = is(IntegralTypeOf!T) && !isAggregateType!T;

unittest
{
    foreach (T; IntegralTypeList)
    {
        foreach (Q; TypeQualifierList)
        {
            static assert( isIntegral!(Q!T));
            static assert(!isIntegral!(SubTypeOf!(Q!T)));
        }
    }

    static assert(!isIntegral!float);

    enum EU : uint { a = 0, b = 1, c = 2 }  // base type is unsigned
    enum EI : int { a = -1, b = 0, c = 1 }  // base type is signed (bug 7909)
    static assert(isIntegral!EU &&  isUnsigned!EU && !isSigned!EU);
    static assert(isIntegral!EI && !isUnsigned!EI &&  isSigned!EI);
}

/**
 * Detect whether $(D T) is a built-in floating point type.
 */
enum bool isFloatingPoint(T) = is(FloatingPointTypeOf!T) && !isAggregateType!T;

unittest
{
    enum EF : real { a = 1.414, b = 1.732, c = 2.236 }

    foreach (T; TypeTuple!(FloatingPointTypeList, EF))
    {
        foreach (Q; TypeQualifierList)
        {
            static assert( isFloatingPoint!(Q!T));
            static assert(!isFloatingPoint!(SubTypeOf!(Q!T)));
        }
    }
    foreach (T; IntegralTypeList)
    {
        foreach (Q; TypeQualifierList)
        {
            static assert(!isFloatingPoint!(Q!T));
        }
    }
}

/**
Detect whether $(D T) is a built-in numeric type (integral or floating
point).
 */
enum bool isNumeric(T) = is(NumericTypeOf!T) && !isAggregateType!T;

unittest
{
    foreach (T; TypeTuple!(NumericTypeList))
    {
        foreach (Q; TypeQualifierList)
        {
            static assert( isNumeric!(Q!T));
            static assert(!isNumeric!(SubTypeOf!(Q!T)));
        }
    }
}

/**
Detect whether $(D T) is a scalar type (a built-in numeric, character or boolean type).
 */
enum bool isScalarType(T) = isNumeric!T || isSomeChar!T || isBoolean!T;

///
unittest
{
    static assert(!isScalarType!void);
    static assert( isScalarType!(immutable(int)));
    static assert( isScalarType!(shared(float)));
    static assert( isScalarType!(shared(const bool)));
    static assert( isScalarType!(const(dchar)));
}

/**
Detect whether $(D T) is a basic type (scalar type or void).
 */
enum bool isBasicType(T) = isScalarType!T || is(T == void);

///
unittest
{
    static assert(isBasicType!void);
    static assert(isBasicType!(immutable(int)));
    static assert(isBasicType!(shared(float)));
    static assert(isBasicType!(shared(const bool)));
    static assert(isBasicType!(const(dchar)));
}

/**
Detect whether $(D T) is a built-in unsigned numeric type.
 */
enum bool isUnsigned(T) = is(UnsignedTypeOf!T) && !isAggregateType!T;

unittest
{
    foreach (T; TypeTuple!(UnsignedIntTypeList))
    {
        foreach (Q; TypeQualifierList)
        {
            static assert( isUnsigned!(Q!T));
            static assert(!isUnsigned!(SubTypeOf!(Q!T)));
        }
    }
}

/**
Detect whether $(D T) is a built-in signed numeric type.
 */
enum bool isSigned(T) = is(SignedTypeOf!T) && !isAggregateType!T;

unittest
{
    foreach (T; TypeTuple!(SignedIntTypeList))
    {
        foreach (Q; TypeQualifierList)
        {
            static assert( isSigned!(Q!T));
            static assert(!isSigned!(SubTypeOf!(Q!T)));
        }
    }
}

/**
Detect whether $(D T) is one of the built-in character types.
 */
enum bool isSomeChar(T) = is(CharTypeOf!T) && !isAggregateType!T;

///
unittest
{
    static assert(!isSomeChar!int);
    static assert(!isSomeChar!byte);
    static assert(!isSomeChar!string);
    static assert(!isSomeChar!wstring);
    static assert(!isSomeChar!dstring);
    static assert(!isSomeChar!(char[4]));
}

unittest
{
    enum EC : char { a = 'x', b = 'y' }

    foreach (T; TypeTuple!(CharTypeList, EC))
    {
        foreach (Q; TypeQualifierList)
        {
            static assert( isSomeChar!(            Q!T  ));
            static assert(!isSomeChar!( SubTypeOf!(Q!T) ));
        }
    }
}

/**
Detect whether $(D T) is one of the built-in string types.

The built-in string types are $(D Char[]), where $(D Char) is any of $(D char),
$(D wchar) or $(D dchar), with or without qualifiers.

Static arrays of characters (like $(D char[80])) are not considered
built-in string types.
 */
enum bool isSomeString(T) = is(StringTypeOf!T) && !isAggregateType!T && !isStaticArray!T;

///
unittest
{
    static assert(!isSomeString!int);
    static assert(!isSomeString!(int[]));
    static assert(!isSomeString!(byte[]));
    static assert(!isSomeString!(typeof(null)));
    static assert(!isSomeString!(char[4]));

    enum ES : string { a = "aaa", b = "bbb" }
    static assert( isSomeString!ES);
}

unittest
{
    foreach (T; TypeTuple!(char[], dchar[], string, wstring, dstring))
    {
        static assert( isSomeString!(           T ));
        static assert(!isSomeString!(SubTypeOf!(T)));
    }
}

enum bool isNarrowString(T) = (is(T : const char[]) || is(T : const wchar[])) && !isAggregateType!T && !isStaticArray!T;

unittest
{
    foreach (T; TypeTuple!(char[], string, wstring))
    {
        foreach (Q; TypeTuple!(MutableOf, ConstOf, ImmutableOf)/*TypeQualifierList*/)
        {
            static assert( isNarrowString!(            Q!T  ));
            static assert(!isNarrowString!( SubTypeOf!(Q!T) ));
        }
    }

    foreach (T; TypeTuple!(int, int[], byte[], dchar[], dstring, char[4]))
    {
        foreach (Q; TypeQualifierList)
        {
            static assert(!isNarrowString!(            Q!T  ));
            static assert(!isNarrowString!( SubTypeOf!(Q!T) ));
        }
    }
}

/**
 * Detect whether type $(D T) is a static array.
 */
enum bool isStaticArray(T) = is(StaticArrayTypeOf!T) && !isAggregateType!T;

///
unittest
{
    static assert(!isStaticArray!(const(int)[]));
    static assert(!isStaticArray!(immutable(int)[]));
    static assert(!isStaticArray!(const(int)[4][]));
    static assert(!isStaticArray!(int[]));
    static assert(!isStaticArray!(int[char]));
    static assert(!isStaticArray!(int[1][]));
    static assert(!isStaticArray!(int[int]));
    static assert(!isStaticArray!int);
}

unittest
{
    foreach (T; TypeTuple!(int[51], int[][2],
                           char[][int][11], immutable char[13u],
                           const(real)[1], const(real)[1][1], void[0]))
    {
        foreach (Q; TypeQualifierList)
        {
            static assert( isStaticArray!(            Q!T  ));
            static assert(!isStaticArray!( SubTypeOf!(Q!T) ));
        }
    }

    //enum ESA : int[1] { a = [1], b = [2] }
    //static assert( isStaticArray!ESA);
}

/**
 * Detect whether type $(D T) is a dynamic array.
 */
enum bool isDynamicArray(T) = is(DynamicArrayTypeOf!T) && !isAggregateType!T;

unittest
{
    foreach (T; TypeTuple!(int[], char[], string, long[3][], double[string][]))
    {
        foreach (Q; TypeQualifierList)
        {
            static assert( isDynamicArray!(            Q!T  ));
            static assert(!isDynamicArray!( SubTypeOf!(Q!T) ));
        }
    }

    static assert(!isDynamicArray!(int[5]));
    static assert(!isDynamicArray!(typeof(null)));

    //enum EDA : int[] { a = [1], b = [2] }
    //static assert( isDynamicArray!EDA);
}

/**
 * Detect whether type $(D T) is an array (static or dynamic; for associative
 *  arrays see $(LREF isAssociativeArray)).
 */
enum bool isArray(T) = isStaticArray!T || isDynamicArray!T;

unittest
{
    foreach (T; TypeTuple!(int[], int[5], void[]))
    {
        foreach (Q; TypeQualifierList)
        {
            static assert( isArray!(Q!T));
            static assert(!isArray!(SubTypeOf!(Q!T)));
        }
    }

    static assert(!isArray!uint);
    static assert(!isArray!(uint[uint]));
    static assert(!isArray!(typeof(null)));
}

/**
 * Detect whether $(D T) is an associative array type
 */
enum bool isAssociativeArray(T) = is(AssocArrayTypeOf!T) && !isAggregateType!T;

unittest
{
    struct Foo
    {
        @property uint[] keys()   { return null; }
        @property uint[] values() { return null; }
    }

    foreach (T; TypeTuple!(int[int], int[string], immutable(char[5])[int]))
    {
        foreach (Q; TypeQualifierList)
        {
            static assert( isAssociativeArray!(Q!T));
            static assert(!isAssociativeArray!(SubTypeOf!(Q!T)));
        }
    }

    static assert(!isAssociativeArray!Foo);
    static assert(!isAssociativeArray!int);
    static assert(!isAssociativeArray!(int[]));
    static assert(!isAssociativeArray!(typeof(null)));

    //enum EAA : int[int] { a = [1:1], b = [2:2] }
    //static assert( isAssociativeArray!EAA);
}

/**
 * Detect whether type $(D T) is a builtin type.
 */
enum bool isBuiltinType(T) = is(BuiltinTypeOf!T) && !isAggregateType!T;

/**
 * Detect whether type $(D T) is a SIMD vector type.
 */
enum bool isSIMDVector(T) = is(T : __vector(V[N]), V, size_t N);

unittest
{
    static if (is(__vector(float[4])))
    {
        alias __vector(float[4]) SimdVec;
        static assert(isSIMDVector!(__vector(float[4])));
        static assert(isSIMDVector!SimdVec);
    }
    static assert(!isSIMDVector!uint);
    static assert(!isSIMDVector!(float[4]));
}

/**
 * Detect whether type $(D T) is a pointer.
 */
enum bool isPointer(T) = is(T == U*, U) && !isAggregateType!T;

unittest
{
    foreach (T; TypeTuple!(int*, void*, char[]*))
    {
        foreach (Q; TypeQualifierList)
        {
            static assert( isPointer!(Q!T));
            static assert(!isPointer!(SubTypeOf!(Q!T)));
        }
    }

    static assert(!isPointer!uint);
    static assert(!isPointer!(uint[uint]));
    static assert(!isPointer!(char[]));
    static assert(!isPointer!(typeof(null)));
}

/**
Returns the target type of a pointer.
*/
alias PointerTarget(T : T*) = T;

/**
  $(RED Deprecated. Please use $(LREF PointerTarget) instead. This will be
        removed in June 2015.)
 */
deprecated("Please use PointerTarget instead.")
alias pointerTarget = PointerTarget;

unittest
{
    static assert( is(PointerTarget!(int*) == int));
    static assert( is(PointerTarget!(long*) == long));

    static assert(!is(PointerTarget!int));
}

/**
 * Detect whether type $(D T) is an aggregate type.
 */
enum bool isAggregateType(T) = is(T == struct) || is(T == union) ||
                               is(T == class) || is(T == interface);

/**
 * Returns $(D true) if T can be iterated over using a $(D foreach) loop with
 * a single loop variable of automatically inferred type, regardless of how
 * the $(D foreach) loop is implemented.  This includes ranges, structs/classes
 * that define $(D opApply) with a single loop variable, and builtin dynamic,
 * static and associative arrays.
 */
enum bool isIterable(T) = is(typeof({ foreach(elem; T.init) {} }));

///
unittest
{
    struct OpApply
    {
        int opApply(int delegate(ref uint) dg) { assert(0); }
    }

    struct Range
    {
        @property uint front() { assert(0); }
        void popFront() { assert(0); }
        enum bool empty = false;
    }

    static assert( isIterable!(uint[]));
    static assert( isIterable!OpApply);
    static assert( isIterable!(uint[string]));
    static assert( isIterable!Range);

    static assert(!isIterable!uint);
}

/**
 * Returns true if T is not const or immutable.  Note that isMutable is true for
 * string, or immutable(char)[], because the 'head' is mutable.
 */
enum bool isMutable(T) = !is(T == const) && !is(T == immutable) && !is(T == inout);

///
unittest
{
    static assert( isMutable!int);
    static assert( isMutable!string);
    static assert( isMutable!(shared int));
    static assert( isMutable!(shared const(int)[]));

    static assert(!isMutable!(const int));
    static assert(!isMutable!(inout int));
    static assert(!isMutable!(shared(const int)));
    static assert(!isMutable!(shared(inout int)));
    static assert(!isMutable!(immutable string));
}

/**
 * Returns true if T is an instance of the template S.
 */
enum bool isInstanceOf(alias S, T) = is(T == S!Args, Args...);

///
unittest
{
    static struct Foo(T...) { }
    static struct Bar(T...) { }
    static struct Doo(T) { }
    static struct ABC(int x) { }
    static assert(isInstanceOf!(Foo, Foo!int));
    static assert(!isInstanceOf!(Foo, Bar!int));
    static assert(!isInstanceOf!(Foo, int));
    static assert(isInstanceOf!(Doo, Doo!int));
    static assert(isInstanceOf!(ABC, ABC!1));
    static assert(!__traits(compiles, isInstanceOf!(Foo, Foo)));
}

/**
 * Check whether the tuple T is an expression tuple.
 * An expression tuple only contains expressions.
 *
 * See_Also: $(LREF isTypeTuple).
 */
template isExpressionTuple(T ...)
{
    static if (T.length >= 2)
        enum bool isExpressionTuple =
            isExpressionTuple!(T[0 .. $/2]) &&
            isExpressionTuple!(T[$/2 .. $]);
    else static if (T.length == 1)
        enum bool isExpressionTuple =
            !is(T[0]) && __traits(compiles, { auto ex = T[0]; });
    else
        enum bool isExpressionTuple = true; // default
}

///
unittest
{
    static assert(isExpressionTuple!(1, 2.0, "a"));
    static assert(!isExpressionTuple!(int, double, string));
    static assert(!isExpressionTuple!(int, 2.0, "a"));
}

unittest
{
    void foo();
    static int bar() { return 42; }
    enum aa = [ 1: -1 ];
    alias myint = int;

    static assert( isExpressionTuple!(42));
    static assert( isExpressionTuple!aa);
    static assert( isExpressionTuple!("cattywampus", 2.7, aa));
    static assert( isExpressionTuple!(bar()));

    static assert(!isExpressionTuple!isExpressionTuple);
    static assert(!isExpressionTuple!foo);
    static assert(!isExpressionTuple!( (a) { } ));
    static assert(!isExpressionTuple!int);
    static assert(!isExpressionTuple!myint);
}


/**
 * Check whether the tuple $(D T) is a type tuple.
 * A type tuple only contains types.
 *
 * See_Also: $(LREF isExpressionTuple).
 */
template isTypeTuple(T...)
{
    static if (T.length >= 2)
        enum bool isTypeTuple = isTypeTuple!(T[0 .. $/2]) && isTypeTuple!(T[$/2 .. $]);
    else static if (T.length == 1)
        enum bool isTypeTuple = is(T[0]);
    else
        enum bool isTypeTuple = true; // default
}

///
unittest
{
    static assert(isTypeTuple!(int, float, string));
    static assert(!isTypeTuple!(1, 2.0, "a"));
    static assert(!isTypeTuple!(1, double, string));
}

unittest
{
    class C {}
    void func(int) {}
    auto c = new C;
    enum CONST = 42;

    static assert( isTypeTuple!int);
    static assert( isTypeTuple!string);
    static assert( isTypeTuple!C);
    static assert( isTypeTuple!(typeof(func)));
    static assert( isTypeTuple!(int, char, double));

    static assert(!isTypeTuple!c);
    static assert(!isTypeTuple!isTypeTuple);
    static assert(!isTypeTuple!CONST);
}


/**
Detect whether symbol or type $(D T) is a function pointer.
 */
template isFunctionPointer(T...)
    if (T.length == 1)
{
    static if (is(T[0] U) || is(typeof(T[0]) U))
    {
        static if (is(U F : F*) && is(F == function))
            enum bool isFunctionPointer = true;
        else
            enum bool isFunctionPointer = false;
    }
    else
        enum bool isFunctionPointer = false;
}

///
unittest
{
    static void foo() {}
    void bar() {}

    auto fpfoo = &foo;
    static assert( isFunctionPointer!fpfoo);
    static assert( isFunctionPointer!(void function()));

    auto dgbar = &bar;
    static assert(!isFunctionPointer!dgbar);
    static assert(!isFunctionPointer!(void delegate()));
    static assert(!isFunctionPointer!foo);
    static assert(!isFunctionPointer!bar);

    static assert( isFunctionPointer!((int a) {}));
}

/**
Detect whether symbol or type $(D T) is a delegate.
*/
template isDelegate(T...)
    if (T.length == 1)
{
    static if (is(typeof(& T[0]) U : U*) && is(typeof(& T[0]) U == delegate))
    {
        // T is a (nested) function symbol.
        enum bool isDelegate = true;
    }
    else static if (is(T[0] W) || is(typeof(T[0]) W))
    {
        // T is an expression or a type.  Take the type of it and examine.
        enum bool isDelegate = is(W == delegate);
    }
    else
        enum bool isDelegate = false;
}

///
unittest
{
    static void sfunc() { }
    int x;
    void func() { x++; }

    int delegate() dg;
    assert(isDelegate!dg);
    assert(isDelegate!(int delegate()));
    assert(isDelegate!(typeof(&func)));

    int function() fp;
    assert(!isDelegate!fp);
    assert(!isDelegate!(int function()));
    assert(!isDelegate!(typeof(&sfunc)));
}

/**
Detect whether symbol or type $(D T) is a function, a function pointer or a delegate.
 */
template isSomeFunction(T...)
    if (T.length == 1)
{
    static if (is(typeof(& T[0]) U : U*) && is(U == function) || is(typeof(& T[0]) U == delegate))
    {
        // T is a (nested) function symbol.
        enum bool isSomeFunction = true;
    }
    else static if (is(T[0] W) || is(typeof(T[0]) W))
    {
        // T is an expression or a type.  Take the type of it and examine.
        static if (is(W F : F*) && is(F == function))
            enum bool isSomeFunction = true; // function pointer
        else
            enum bool isSomeFunction = is(W == function) || is(W == delegate);
    }
    else
        enum bool isSomeFunction = false;
}

unittest
{
    static real func(ref int) { return 0; }
    static void prop() @property { }
    void nestedFunc() { }
    void nestedProp() @property { }
    class C
    {
        real method(ref int) { return 0; }
        real prop() @property { return 0; }
    }
    auto c = new C;
    auto fp = &func;
    auto dg = &c.method;
    real val;

    static assert( isSomeFunction!func);
    static assert( isSomeFunction!prop);
    static assert( isSomeFunction!nestedFunc);
    static assert( isSomeFunction!nestedProp);
    static assert( isSomeFunction!(C.method));
    static assert( isSomeFunction!(C.prop));
    static assert( isSomeFunction!(c.prop));
    static assert( isSomeFunction!(c.prop));
    static assert( isSomeFunction!fp);
    static assert( isSomeFunction!dg);
    static assert( isSomeFunction!(typeof(func)));
    static assert( isSomeFunction!(real function(ref int)));
    static assert( isSomeFunction!(real delegate(ref int)));
    static assert( isSomeFunction!((int a) { return a; }));

    static assert(!isSomeFunction!int);
    static assert(!isSomeFunction!val);
    static assert(!isSomeFunction!isSomeFunction);
}


/**
Detect whether $(D T) is a callable object, which can be called with the
function call operator $(D $(LPAREN)...$(RPAREN)).
 */
template isCallable(T...)
    if (T.length == 1)
{
    static if (is(typeof(& T[0].opCall) == delegate))
        // T is a object which has a member function opCall().
        enum bool isCallable = true;
    else static if (is(typeof(& T[0].opCall) V : V*) && is(V == function))
        // T is a type which has a static member function opCall().
        enum bool isCallable = true;
    else
        enum bool isCallable = isSomeFunction!T;
}

///
unittest
{
    interface I { real value() @property; }
    struct S { static int opCall(int) { return 0; } }
    class C { int opCall(int) { return 0; } }
    auto c = new C;

    static assert( isCallable!c);
    static assert( isCallable!S);
    static assert( isCallable!(c.opCall));
    static assert( isCallable!(I.value));
    static assert( isCallable!((int a) { return a; }));

    static assert(!isCallable!I);
}


/**
 * Detect whether $(D T) is a an abstract function.
 */
template isAbstractFunction(T...)
    if (T.length == 1)
{
    enum bool isAbstractFunction = __traits(isAbstractFunction, T[0]);
}

unittest
{
    struct S { void foo() { } }
    class C { void foo() { } }
    class AC { abstract void foo(); }
    static assert(!isAbstractFunction!(S.foo));
    static assert(!isAbstractFunction!(C.foo));
    static assert( isAbstractFunction!(AC.foo));
}

/**
 * Detect whether $(D T) is a a final function.
 */
template isFinalFunction(T...)
    if (T.length == 1)
{
    enum bool isFinalFunction = __traits(isFinalFunction, T[0]);
}

///
unittest
{
    struct S { void bar() { } }
    final class FC { void foo(); }
    class C
    {
        void bar() { }
        final void foo();
    }
    static assert(!isFinalFunction!(S.bar));
    static assert( isFinalFunction!(FC.foo));
    static assert(!isFinalFunction!(C.bar));
    static assert( isFinalFunction!(C.foo));
}

/**
Determines whether function $(D f) requires a context pointer.
*/
template isNestedFunction(alias f)
{
    enum isNestedFunction = __traits(isNested, f);
}

unittest
{
    static void f() { }
    void g() { }
    static assert(!isNestedFunction!f);
    static assert( isNestedFunction!g);
}

/**
 * Detect whether $(D T) is a an abstract class.
 */
template isAbstractClass(T...)
    if (T.length == 1)
{
    enum bool isAbstractClass = __traits(isAbstractClass, T[0]);
}

///
unittest
{
    struct S { }
    class C { }
    abstract class AC { }
    static assert(!isAbstractClass!S);
    static assert(!isAbstractClass!C);
    static assert( isAbstractClass!AC);
}

/**
 * Detect whether $(D T) is a a final class.
 */
template isFinalClass(T...)
    if (T.length == 1)
{
    enum bool isFinalClass = __traits(isFinalClass, T[0]);
}

///
unittest
{
    class C { }
    abstract class AC { }
    final class FC1 : C { }
    final class FC2 { }
    static assert(!isFinalClass!C);
    static assert(!isFinalClass!AC);
    static assert( isFinalClass!FC1);
    static assert( isFinalClass!FC2);
}

//::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::://
// General Types
//::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::://

/**
Removes all qualifiers, if any, from type $(D T).
 */
template Unqual(T)
{
    version (none) // Error: recursive alias declaration @@@BUG1308@@@
    {
             static if (is(T U ==     const U)) alias Unqual = Unqual!U;
        else static if (is(T U == immutable U)) alias Unqual = Unqual!U;
        else static if (is(T U ==     inout U)) alias Unqual = Unqual!U;
        else static if (is(T U ==    shared U)) alias Unqual = Unqual!U;
        else                                    alias Unqual =        T;
    }
    else // workaround
    {
             static if (is(T U ==          immutable U)) alias Unqual = U;
        else static if (is(T U == shared inout const U)) alias Unqual = U;
        else static if (is(T U == shared inout       U)) alias Unqual = U;
        else static if (is(T U == shared       const U)) alias Unqual = U;
        else static if (is(T U == shared             U)) alias Unqual = U;
        else static if (is(T U ==        inout const U)) alias Unqual = U;
        else static if (is(T U ==        inout       U)) alias Unqual = U;
        else static if (is(T U ==              const U)) alias Unqual = U;
        else                                             alias Unqual = T;
    }
}

///
unittest
{
    static assert(is(Unqual!int == int));
    static assert(is(Unqual!(const int) == int));
    static assert(is(Unqual!(immutable int) == int));
    static assert(is(Unqual!(shared int) == int));
    static assert(is(Unqual!(shared(const int)) == int));
}

unittest
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

    alias ImmIntArr = immutable(int[]);
    static assert(is(Unqual!ImmIntArr == immutable(int)[]));
}

// [For internal use]
package template ModifyTypePreservingSTC(alias Modifier, T)
{
         static if (is(T U ==          immutable U)) alias ModifyTypePreservingSTC =          immutable Modifier!U;
    else static if (is(T U == shared inout const U)) alias ModifyTypePreservingSTC = shared inout const Modifier!U;
    else static if (is(T U == shared inout       U)) alias ModifyTypePreservingSTC = shared inout       Modifier!U;
    else static if (is(T U == shared       const U)) alias ModifyTypePreservingSTC = shared       const Modifier!U;
    else static if (is(T U == shared             U)) alias ModifyTypePreservingSTC = shared             Modifier!U;
    else static if (is(T U ==        inout const U)) alias ModifyTypePreservingSTC =        inout const Modifier!U;
    else static if (is(T U ==        inout       U)) alias ModifyTypePreservingSTC =              inout Modifier!U;
    else static if (is(T U ==              const U)) alias ModifyTypePreservingSTC =              const Modifier!U;
    else                                             alias ModifyTypePreservingSTC =                    Modifier!T;
}

unittest
{
    alias Intify(T) = int;
    static assert(is(ModifyTypePreservingSTC!(Intify,                    real) ==                    int));
    static assert(is(ModifyTypePreservingSTC!(Intify,              const real) ==              const int));
    static assert(is(ModifyTypePreservingSTC!(Intify,        inout       real) ==        inout       int));
    static assert(is(ModifyTypePreservingSTC!(Intify,        inout const real) ==        inout const int));
    static assert(is(ModifyTypePreservingSTC!(Intify, shared             real) == shared             int));
    static assert(is(ModifyTypePreservingSTC!(Intify, shared       const real) == shared       const int));
    static assert(is(ModifyTypePreservingSTC!(Intify, shared inout       real) == shared inout       int));
    static assert(is(ModifyTypePreservingSTC!(Intify, shared inout const real) == shared inout const int));
    static assert(is(ModifyTypePreservingSTC!(Intify,          immutable real) ==          immutable int));
}

/**
Returns the inferred type of the loop variable when a variable of type T
is iterated over using a $(D foreach) loop with a single loop variable and
automatically inferred return type.  Note that this may not be the same as
$(D std.range.ElementType!Range) in the case of narrow strings, or if T
has both opApply and a range interface.
*/
template ForeachType(T)
{
    alias ForeachType = ReturnType!(typeof(
    (inout int x = 0)
    {
        foreach(elem; T.init)
        {
            return elem;
        }
        assert(0);
    }));
}

///
unittest
{
    static assert(is(ForeachType!(uint[]) == uint));
    static assert(is(ForeachType!string == immutable(char)));
    static assert(is(ForeachType!(string[string]) == string));
    static assert(is(ForeachType!(inout(int)[]) == inout(int)));
}


/**
 * Strips off all $(D enum)s from type $(D T).
 */
template OriginalType(T)
{
    template Impl(T)
    {
        static if (is(T U == enum)) alias Impl = OriginalType!U;
        else                        alias Impl =              T;
    }

    alias OriginalType = ModifyTypePreservingSTC!(Impl, T);
}

///
unittest
{
    enum E : real { a }
    enum F : E    { a = E.a }
    alias G = const(F);
    static assert(is(OriginalType!E == real));
    static assert(is(OriginalType!F == real));
    static assert(is(OriginalType!G == const real));
}

/**
 * Get the Key type of an Associative Array.
 */
alias KeyType(V : V[K], K) = K;

///
unittest
{
    import std.traits;
    alias Hash = int[string];
    static assert(is(KeyType!Hash == string));
    static assert(is(ValueType!Hash == int));
    KeyType!Hash str = "a"; // str is declared as string
    ValueType!Hash num = 1; // num is declared as int
}

/**
 * Get the Value type of an Associative Array.
 */
alias ValueType(V : V[K], K) = V;

///
unittest
{
    import std.traits;
    alias Hash = int[string];
    static assert(is(KeyType!Hash == string));
    static assert(is(ValueType!Hash == int));
    KeyType!Hash str = "a"; // str is declared as string
    ValueType!Hash num = 1; // num is declared as int
}

/**
 * Returns the corresponding unsigned type for T. T must be a numeric
 * integral type, otherwise a compile-time error occurs.
 */
template Unsigned(T)
{
    template Impl(T)
    {
        static if (is(T : __vector(V[N]), V, size_t N))
            alias Impl = __vector(Impl!V[N]);
        else static if (isUnsigned!T)
            alias Impl = T;
        else static if (isSigned!T && !isFloatingPoint!T)
        {
            static if (is(T == byte )) alias Impl = ubyte;
            static if (is(T == short)) alias Impl = ushort;
            static if (is(T == int  )) alias Impl = uint;
            static if (is(T == long )) alias Impl = ulong;
        }
        else
            static assert(false, "Type " ~ T.stringof ~
                                 " does not have an Unsigned counterpart");
    }

    alias Unsigned = ModifyTypePreservingSTC!(Impl, OriginalType!T);
}

unittest
{
    alias U1 = Unsigned!int;
    alias U2 = Unsigned!(const(int));
    alias U3 = Unsigned!(immutable(int));
    static assert(is(U1 == uint));
    static assert(is(U2 == const(uint)));
    static assert(is(U3 == immutable(uint)));
    static if (is(__vector(int[4])) && is(__vector(uint[4])))
    {
        alias Unsigned!(__vector(int[4])) UV1;
        alias Unsigned!(const(__vector(int[4]))) UV2;
        static assert(is(UV1 == __vector(uint[4])));
        static assert(is(UV2 == const(__vector(uint[4]))));
    }
    //struct S {}
    //alias U2 = Unsigned!S;
    //alias U3 = Unsigned!double;
}

/**
Returns the largest type, i.e. T such that T.sizeof is the largest.  If more
than one type is of the same size, the leftmost argument of these in will be
returned.
*/
template Largest(T...) if(T.length >= 1)
{
    static if (T.length == 1)
    {
        alias Largest = T[0];
    }
    else static if (T.length == 2)
    {
        static if(T[0].sizeof >= T[1].sizeof)
        {
            alias Largest = T[0];
        }
        else
        {
            alias Largest = T[1];
        }
    }
    else
    {
        alias Largest = Largest!(Largest!(T[0 .. $/2]), Largest!(T[$/2 .. $]));
    }
}

///
unittest
{
    static assert(is(Largest!(uint, ubyte, ushort, real) == real));
    static assert(is(Largest!(ulong, double) == ulong));
    static assert(is(Largest!(double, ulong) == double));
    static assert(is(Largest!(uint, byte, double, short) == double));
}

/**
Returns the corresponding signed type for T. T must be a numeric integral type,
otherwise a compile-time error occurs.
 */
template Signed(T)
{
    template Impl(T)
    {
        static if (is(T : __vector(V[N]), V, size_t N))
            alias Impl = __vector(Impl!V[N]);
        else static if (isSigned!T)
            alias Impl = T;
        else static if (isUnsigned!T)
        {
            static if (is(T == ubyte )) alias Impl = byte;
            static if (is(T == ushort)) alias Impl = short;
            static if (is(T == uint  )) alias Impl = int;
            static if (is(T == ulong )) alias Impl = long;
        }
        else
            static assert(false, "Type " ~ T.stringof ~
                                 " does not have an Signed counterpart");
    }

    alias Signed = ModifyTypePreservingSTC!(Impl, OriginalType!T);
}

///
unittest
{
    alias S1 = Signed!uint;
    static assert(is(S1 == int));
    alias S2 = Signed!(const(uint));
    static assert(is(S2 == const(int)));
    alias S3 = Signed!(immutable(uint));
    static assert(is(S3 == immutable(int)));
}

unittest
{
    static assert(is(Signed!float == float));
    static if (is(__vector(int[4])) && is(__vector(uint[4])))
    {
        alias Signed!(__vector(uint[4])) SV1;
        alias Signed!(const(__vector(uint[4]))) SV2;
        static assert(is(SV1 == __vector(int[4])));
        static assert(is(SV2 == const(__vector(int[4]))));
    }
}


/**
Returns the most negative value of the numeric type T.
*/
template mostNegative(T)
    if(isNumeric!T || isSomeChar!T || isBoolean!T)
{
    static if (is(typeof(T.min_normal)))
        enum mostNegative = -T.max;
    else static if (T.min == 0)
        enum byte mostNegative = 0;
    else
        enum mostNegative = T.min;
}

///
unittest
{
    static assert(mostNegative!float == -float.max);
    static assert(mostNegative!double == -double.max);
    static assert(mostNegative!real == -real.max);
    static assert(mostNegative!bool == false);
}

///
unittest
{
    foreach(T; TypeTuple!(bool, byte, short, int, long))
        static assert(mostNegative!T == T.min);

    foreach(T; TypeTuple!(ubyte, ushort, uint, ulong, char, wchar, dchar))
        static assert(mostNegative!T == 0);
}


//:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::://
// Misc.
//:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::://

/**
Returns the mangled name of symbol or type $(D sth).

$(D mangledName) is the same as builtin $(D .mangleof) property, except that
the correct names of property functions are obtained.
--------------------
module test;
import std.traits : mangledName;

class C
{
    int value() @property;
}
pragma(msg, C.value.mangleof);      // prints "i"
pragma(msg, mangledName!(C.value)); // prints "_D4test1C5valueMFNdZi"
--------------------
 */
template mangledName(sth...)
    if (sth.length == 1)
{
    static if (is(typeof(sth[0]) X) && is(X == void))
    {
        // sth[0] is a template symbol
        enum string mangledName = removeDummyEnvelope(Dummy!sth.Hook.mangleof);
    }
    else
    {
        enum string mangledName = sth[0].mangleof;
    }
}

private template Dummy(T...) { struct Hook {} }

private string removeDummyEnvelope(string s)
{
    // remove --> S3std6traits ... Z4Hook
    s = s[12 .. $ - 6];

    // remove --> DIGIT+ __T5Dummy
    foreach (i, c; s)
    {
        if (c < '0' || '9' < c)
        {
            s = s[i .. $];
            break;
        }
    }
    s = s[9 .. $]; // __T5Dummy

    // remove --> T | V | S
    immutable kind = s[0];
    s = s[1 .. $];

    if (kind == 'S') // it's a symbol
    {
        /*
         * The mangled symbol name is packed in LName --> Number Name.  Here
         * we are chopping off the useless preceding Number, which is the
         * length of Name in decimal notation.
         *
         * NOTE: n = m + Log(m) + 1;  n = LName.length, m = Name.length.
         */
        immutable n = s.length;
        size_t m_upb = 10;

        foreach (k; 1 .. 5) // k = Log(m_upb)
        {
            if (n < m_upb + k + 1)
            {
                // Now m_upb/10 <= m < m_upb; hence k = Log(m) + 1.
                s = s[k .. $];
                break;
            }
            m_upb *= 10;
        }
    }

    return s;
}

unittest
{
    class C { int value() @property { return 0; } }
    static assert(mangledName!int == int.mangleof);
    static assert(mangledName!C == C.mangleof);
    static assert(mangledName!(C.value)[$ - 12 .. $] == "5valueMFNdZi");
    static assert(mangledName!mangledName == "3std6traits11mangledName");
    static assert(mangledName!removeDummyEnvelope ==
            "_D3std6traits19removeDummyEnvelopeFAyaZAya");
    int x;
  static if (is(typeof({ return x; }) : int delegate() pure))   // issue 9148
    static assert(mangledName!((int a) { return a+x; }) == "DFNaNbNiNfiZi");  // pure nothrow @safe @nogc
  else
    static assert(mangledName!((int a) { return a+x; }) == "DFNbNiNfiZi");  // nothrow @safe @nnogc
}

unittest
{
    // Test for bug 5718
    import std.demangle;
    int foo;
    auto foo_demangled = demangle(mangledName!foo);
    assert(foo_demangled[0 .. 4] == "int " && foo_demangled[$-3 .. $] == "foo");

    void bar(){}
    auto bar_demangled = demangle(mangledName!bar);
    assert(bar_demangled[0 .. 5] == "void " && bar_demangled[$-5 .. $] == "bar()");
}



// XXX Select & select should go to another module. (functional or algorithm?)

/**
Aliases itself to $(D T[0]) if the boolean $(D condition) is $(D true)
and to $(D T[1]) otherwise.
 */
template Select(bool condition, T...) if (T.length == 2)
{
    alias Select = T[!condition];
}

///
unittest
{
    // can select types
    static assert(is(Select!(true, int, long) == int));
    static assert(is(Select!(false, int, long) == long));

    // can select symbols
    int a = 1;
    int b = 2;
    alias selA = Select!(true, a, b);
    alias selB = Select!(false, a, b);
    assert(selA == 1);
    assert(selB == 2);
}

/**
If $(D cond) is $(D true), returns $(D a) without evaluating $(D
b). Otherwise, returns $(D b) without evaluating $(D a).
 */
A select(bool cond : true, A, B)(A a, lazy B b) { return a; }
/// Ditto
B select(bool cond : false, A, B)(lazy A a, B b) { return b; }

unittest
{
    real pleasecallme() { return 0; }
    int dontcallme() { assert(0); }
    auto a = select!true(pleasecallme(), dontcallme());
    auto b = select!false(dontcallme(), pleasecallme());
    static assert(is(typeof(a) == real));
    static assert(is(typeof(b) == real));
}
