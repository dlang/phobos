// Written in the D programming language.

/**
 * Templates with which to extract information about types and symbols at
 * compile time.
 *
 * Macros:
 *  WIKI = Phobos/StdTraits
 *
 * Copyright: Copyright Digital Mars 2005 - 2009.
 * License:   <a href="http://www.boost.org/LICENSE_1_0.txt">Boost License 1.0</a>.
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
import std.algorithm;
import std.typetuple;
import std.typecons;
import core.vararg;

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
            'f': FunctionAttribute.safe
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

    alias TypeTuple!(byte, ubyte, short, ushort, int, uint, long, ulong) IntegralTypeList;
    alias TypeTuple!(byte, short, int, long) SignedIntTypeList;
    alias TypeTuple!(ubyte, ushort, uint, ulong) UnsignedIntTypeList;
    alias TypeTuple!(float, double, real) FloatingPointTypeList;
    alias TypeTuple!(ifloat, idouble, ireal) ImaginaryTypeList;
    alias TypeTuple!(cfloat, cdouble, creal) ComplexTypeList;
    alias TypeTuple!(IntegralTypeList, FloatingPointTypeList) NumericTypeList;
    alias TypeTuple!(char, wchar, dchar) CharTypeList;
}
package
{
    /* Get an expression typed as T, like T.init */
    template defaultInit(T)
    {
        static if (!is(typeof({ T v = void; })))    // inout(U)
            @property T defaultInit(T v = T.init);
        else
            @property T defaultInit();
    }
}

version(unittest)
{
    template MutableOf(T)     { alias              T   MutableOf;     }
    template ConstOf(T)       { alias        const(T)  ConstOf;       }
    template SharedOf(T)      { alias       shared(T)  SharedOf;      }
    template SharedConstOf(T) { alias shared(const(T)) SharedConstOf; }
    template ImmutableOf(T)   { alias    immutable(T)  ImmutableOf;   }
    template WildOf(T)        { alias        inout(T)  WildOf;        }
    template SharedWildOf(T)  { alias shared(inout(T)) SharedWildOf;  }

    alias TypeTuple!(MutableOf, ConstOf, SharedOf, SharedConstOf, ImmutableOf) TypeQualifierList;

    struct SubTypeOf(T)
    {
        T val;
        alias val this;
    }
}


/**
 * Get the full package name for the given symbol.
 * Example:
 * ---
 * import std.traits;
 * static assert(packageName!packageName == "std");
 * ---
 */
template packageName(alias T)
{
    static if (is(typeof(__traits(parent, T))))
        enum parent = packageName!(__traits(parent, T));
    else
        enum string parent = null;

    static if (T.stringof.startsWith("package "))
        enum packageName = (parent ? parent ~ '.' : "") ~ T.stringof[8 .. $];
    else static if (parent)
        enum packageName = parent;
    else
        static assert(false, T.stringof ~ " has no parent");
}

unittest
{
    // Commented out because of dmd @@@BUG8922@@@
    // static assert(packageName!std == "std");  // this package (currently: "std.std")
    static assert(packageName!(std.traits) == "std");     // this module
    static assert(packageName!packageName == "std");      // symbol in this module
    static assert(packageName!(std.algorithm) == "std");  // other module from same package

    import core.sync.barrier;  // local import
    static assert(packageName!core == "core");
    static assert(packageName!(core.sync) == "core.sync");
    static assert(packageName!Barrier == "core.sync");
}

version(unittest)
{
    import core.sync.barrier;  // global import
    static assert(packageName!core == "core");
    static assert(packageName!(core.sync) == "core.sync");
    static assert(packageName!Barrier == "core.sync");
}

/**
 * Get the module name (including package) for the given symbol.
 * Example:
 * ---
 * import std.traits;
 * static assert(moduleName!moduleName == "std.traits");
 * ---
 */
template moduleName(alias T)
{
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
        alias moduleName!(__traits(parent, T)) moduleName;
}

unittest
{
    static assert(!__traits(compiles, moduleName!std));
    static assert(moduleName!(std.traits) == "std.traits");            // this module
    static assert(moduleName!moduleName == "std.traits");              // symbol in this module
    static assert(moduleName!(std.algorithm) == "std.algorithm");      // other module
    static assert(moduleName!(std.algorithm.map) == "std.algorithm");  // symbol in other module

    import core.sync.barrier;  // local import
    static assert(!__traits(compiles, moduleName!(core.sync)));
    static assert(moduleName!(core.sync.barrier) == "core.sync.barrier");
    static assert(moduleName!Barrier == "core.sync.barrier");
}

version(unittest)
{
    import core.sync.barrier;  // global import
    static assert(!__traits(compiles, moduleName!(core.sync)));
    static assert(moduleName!(core.sync.barrier) == "core.sync.barrier");
    static assert(moduleName!Barrier == "core.sync.barrier");
}

/***
 * Get the fully qualified name of a type or a symbol. Can act as an intelligent type/symbol to string  converter.
 * Example:
 * ---
 * module mymodule;
 * import std.traits;
 * struct MyStruct {}
 * static assert(fullyQualifiedName!(const MyStruct[]) == "const(mymodule.MyStruct[])");
 * static assert(fullyQualifiedName!fullyQualifiedName == "std.traits.fullyQualifiedName");
 * ---
 */
template fullyQualifiedName(T...)
    if (T.length == 1)
{

    static if (is(T))
        enum fullyQualifiedName = fullyQualifiedNameImplForTypes!(T[0], false, false, false, false);
    else
        enum fullyQualifiedName = fullyQualifiedNameImplForSymbols!(T[0]);
}

version(unittest)
{
    // Used for both fullyQualifiedNameImplForTypes and fullyQualifiedNameImplForSymbols unittests
    private struct QualifiedNameTests
    {
        struct Inner
        {
        }

        ref const(Inner[string]) func( ref Inner var1, lazy scope string var2 );
        inout Inner inoutFunc(inout Inner);
        shared(const(Inner[string])[]) data;
        const Inner delegate(double, string) @safe nothrow deleg;
        inout int delegate(inout int) inout inoutDeleg;
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
    }
}

private template fullyQualifiedNameImplForSymbols(alias T)
{
    static if (__traits(compiles, __traits(parent, T)))
        enum parentPrefix = fullyQualifiedNameImplForSymbols!(__traits(parent, T)) ~ '.';
    else
        enum parentPrefix = null;

    enum fullyQualifiedNameImplForSymbols = parentPrefix ~ (s)
    {
        if(s.skipOver("package ") || s.skipOver("module "))
            return s;
        return s.findSplit("(")[0];
    }(__traits(identifier, T));
}

unittest
{
    // Make sure those 2 are the same
    static assert(fullyQualifiedNameImplForSymbols!fullyQualifiedName
        == fullyQualifiedName!fullyQualifiedName);

    // Main tests
    alias fqn = fullyQualifiedName;
    static assert(fqn!fqn == "std.traits.fullyQualifiedName");
    static assert(fqn!(QualifiedNameTests.Inner) == "std.traits.QualifiedNameTests.Inner");
    static assert(fqn!(QualifiedNameTests.func) == "std.traits.QualifiedNameTests.func");
    import core.sync.barrier;
    static assert(fullyQualifiedName!Barrier == "core.sync.barrier.Barrier");
}

private template fullyQualifiedNameImplForTypes(T,
    bool alreadyConst, bool alreadyImmutable, bool alreadyShared, bool alreadyInout)
{
    import std.string;

    // Convenience tags
    enum {
        _const = 0,
        _immutable = 1,
        _shared = 2,
        _inout = 3
    }

    alias TypeTuple!(is(T == const), is(T == immutable), is(T == shared), is(T == inout)) qualifiers;
    alias TypeTuple!(false, false, false, false) noQualifiers;

    string storageClassesString(uint psc)() @property
    {
        alias ParameterStorageClass PSC;

        return format("%s%s%s%s",
            psc & PSC.scope_ ? "scope " : "",
            psc & PSC.out_ ? "out " : "",
            psc & PSC.ref_ ? "ref " : "",
            psc & PSC.lazy_ ? "lazy " : ""
        );
    }

    string parametersTypeString(T)() @property
    {
        import std.array, std.algorithm, std.range;

        alias ParameterTypeTuple!(T) parameters;
        alias ParameterStorageClassTuple!(T) parameterStC;

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
        alias FunctionAttribute FA;
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
        enum fullyQualifiedNameImplForTypes = "string";
    }
    else static if (is(T == wstring))
    {
        enum fullyQualifiedNameImplForTypes = "wstring";
    }
    else static if (is(T == dstring))
    {
        enum fullyQualifiedNameImplForTypes = "dstring";
    }
    else static if (isBasicType!T || is(T == enum))
    {
        enum fullyQualifiedNameImplForTypes = chain!((Unqual!T).stringof);
    }
    else static if (isAggregateType!T)
    {
        enum fullyQualifiedNameImplForTypes = chain!(fullyQualifiedNameImplForSymbols!T);
    }
    else static if (isStaticArray!T)
    {
        import std.conv;

        enum fullyQualifiedNameImplForTypes = chain!(
            format("%s[%s]", fullyQualifiedNameImplForTypes!(typeof(T.init[0]), qualifiers), T.length)
        );
    }
    else static if (isArray!T)
    {
        enum fullyQualifiedNameImplForTypes = chain!(
            format("%s[]", fullyQualifiedNameImplForTypes!(typeof(T.init[0]), qualifiers))
        );
    }
    else static if (isAssociativeArray!T)
    {
        enum fullyQualifiedNameImplForTypes = chain!(
            format("%s[%s]", fullyQualifiedNameImplForTypes!(ValueType!T, qualifiers), fullyQualifiedNameImplForTypes!(KeyType!T, noQualifiers))
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
            enum fullyQualifiedNameImplForTypes = chain!(
                format(formatStr, linkageString!T, fullyQualifiedNameImplForTypes!(ReturnType!T, noQualifiers),
                    parametersTypeString!(T), functionAttributeString!T, qualifierString)
            );
        }
        else
        {
            static if (isFunctionPointer!T)
                enum formatStr = "%s%s function(%s)%s";
            else
                enum formatStr = "%s%s(%s)%s";

            enum fullyQualifiedNameImplForTypes = chain!(
                format(formatStr, linkageString!T, fullyQualifiedNameImplForTypes!(ReturnType!T, noQualifiers),
                    parametersTypeString!(T), functionAttributeString!T)
            );
        }
    }
    else static if (isPointer!T)
    {
        enum fullyQualifiedNameImplForTypes = chain!(
            format("%s*", fullyQualifiedNameImplForTypes!(PointerTarget!T, qualifiers))
        );
    }
    else
        // In case something is forgotten
        static assert(0, "Unrecognized type " ~ T.stringof ~ ", can't convert to fully qualified string");
}

unittest
{
    import std.string;

    // Verify those 2 are the same for simple case
    alias Ambiguous = const(QualifiedNameTests.Inner);
    static assert(fullyQualifiedName!Ambiguous == fullyQualifiedNameImplForTypes!(Ambiguous, false, false, false, false));

    // Main tests
    alias fullyQualifiedName fqn;
    enum inner_name = "std.traits.QualifiedNameTests.Inner";
    with (QualifiedNameTests)
    {
        // Special cases
        static assert(fqn!(string) == "string");
        static assert(fqn!(wstring) == "wstring");
        static assert(fqn!(dstring) == "dstring");

        // Basic qualified name
        static assert(fqn!(Inner) == inner_name);

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
        static assert(fqn!(typeof(inoutDeleg)) == "inout(int delegate(inout(int)) inout)");
        static assert(fqn!(typeof(funcPtr)) == format("%s function(out double, string)", inner_name));
        static assert(fqn!(typeof(cFuncPtr)) == format("extern(C) %s function(double, string)", inner_name));

        // Delegate type with qualified function type
        static assert(fqn!(typeof(attrDeleg)) == format("shared(immutable(%s) "
            "delegate(ref double, scope string) nothrow @trusted shared const)", inner_name));

        // Variable argument function types
        static assert(fqn!(typeof(cVarArg)) == "extern(C) void(int, ...)");
        static assert(fqn!(typeof(dVarArg)) == "void(...)");
        static assert(fqn!(typeof(dVarArg2)) == "void(int, ...)");
        static assert(fqn!(typeof(typesafeVarArg)) == "void(int[] ...)");
    }
}

/***
 * Get the type of the return value from a function,
 * a pointer to function, a delegate, a struct
 * with an opCall, a pointer to a struct with an opCall,
 * or a class with an $(D opCall). Please note that $(D_KEYWORD ref)
 * is not part of a type, but the attribute of the function
 * (see template $(LREF functionAttributes)).
 * Example:
 * ---
 * import std.traits;
 * int foo();
 * ReturnType!foo x;   // x is declared as int
 * ---
 */
template ReturnType(func...)
    if (func.length == 1 && isCallable!func)
{
    static if (is(FunctionTypeOf!func R == return))
        alias R ReturnType;
    else
        static assert(0, "argument has no return type");
}

unittest
{
    struct G
    {
        int opCall (int i) { return 1;}
    }

    alias ReturnType!G ShouldBeInt;
    static assert(is(ShouldBeInt == int));

    G g;
    static assert(is(ReturnType!g == int));

    G* p;
    alias ReturnType!p pg;
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
    alias ReturnType!(Test.prop) R_Test_prop;
    static assert(is(R_Test_prop == int));

    alias ReturnType!((int a) { return a; }) R_dglit;
    static assert(is(R_dglit == int));
}

/***
Get, as a tuple, the types of the parameters to a function, a pointer
to function, a delegate, a struct with an $(D opCall), a pointer to a
struct with an $(D opCall), or a class with an $(D opCall).

Example:
---
import std.traits;
int foo(int, long);
void bar(ParameterTypeTuple!foo);      // declares void bar(int, long);
void abc(ParameterTypeTuple!foo[1]);   // declares void abc(long);
---
*/
template ParameterTypeTuple(func...)
    if (func.length == 1 && isCallable!func)
{
    static if (is(FunctionTypeOf!func P == function))
        alias P ParameterTypeTuple;
    else
        static assert(0, "argument has no parameters");
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
    alias ParameterTypeTuple!(Test.prop) P_Test_prop;
    static assert(P_Test_prop.length == 0);

    alias ParameterTypeTuple!((int a){}) P_dglit;
    static assert(P_dglit.length == 1);
    static assert(is(P_dglit[0] == int));
}

/**
Returns the number of arguments of function $(D func).
arity is undefined for variadic functions.

Example:
---
void foo(){}
static assert(arity!foo==0);
void bar(uint){}
static assert(arity!bar==1);
---
 */
template arity(alias func)
    if ( isCallable!func && variadicFunctionStyle!func == Variadic.no )
{
    enum size_t arity = ParameterTypeTuple!func.length;
}

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

Example:
--------------------
alias ParameterStorageClass STC; // shorten the enum name

void func(ref int ctx, out real result, real param)
{
}
alias ParameterStorageClassTuple!func pstc;
static assert(pstc.length == 3); // three parameters
static assert(pstc[0] == STC.ref_);
static assert(pstc[1] == STC.out_);
static assert(pstc[2] == STC.none);
--------------------
 */
enum ParameterStorageClass : uint
{
    /**
     * These flags can be bitwise OR-ed together to represent complex storage
     * class.
     */
    none   = 0,        /// ditto
    scope_ = 0b000_1,  /// ditto
    out_   = 0b001_0,  /// ditto
    ref_   = 0b010_0,  /// ditto
    lazy_  = 0b100_0,  /// ditto
}

/// ditto
template ParameterStorageClassTuple(func...)
    if (func.length == 1 && isCallable!func)
{
    alias Unqual!(FunctionTypeOf!func) Func;

    /*
     * TypeFuncion:
     *     CallConvention FuncAttrs Arguments ArgClose Type
     */
    alias ParameterTypeTuple!Func Params;

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

            alias TypeTuple!(
                    demang.value + 0, // workaround: "not evaluatable at ..."
                    demangleNextParameter!(rest[skip .. $], i + 1)
                ) demangleNextParameter;
        }
        else // went thru all the parameters
        {
            alias TypeTuple!() demangleNextParameter;
        }
    }

    alias demangleNextParameter!margs ParameterStorageClassTuple;
}

unittest
{
    alias ParameterStorageClass STC;

    void noparam() {}
    static assert(ParameterStorageClassTuple!noparam.length == 0);

    void test(scope int, ref int, out int, lazy int, int) { }
    alias ParameterStorageClassTuple!test test_pstc;
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

    alias ParameterStorageClassTuple!(Test.test_const) test_const_pstc;
    static assert(test_const_pstc.length == 1);
    static assert(test_const_pstc[0] == STC.none);

    alias ParameterStorageClassTuple!(testi.test_sharedconst) test_sharedconst_pstc;
    static assert(test_sharedconst_pstc.length == 1);
    static assert(test_sharedconst_pstc[0] == STC.none);

    alias ParameterStorageClassTuple!((ref int a) {}) dglit_pstc;
    static assert(dglit_pstc.length == 1);
    static assert(dglit_pstc[0] == STC.ref_);

    // Bugzilla 9317
    static inout(int) func(inout int param) { return param; }
    static assert(ParameterStorageClassTuple!(typeof(func))[0] == STC.none);
}


/**
Get, as a tuple, the identifiers of the parameters to a function symbol.

Example:
---
import std.traits;
int foo(int num, string name);
static assert([ParameterIdentifierTuple!foo] == ["num", "name"]);
---
 */
template ParameterIdentifierTuple(func...)
    if (func.length == 1 && isCallable!func)
{
    static if (is(typeof(func[0]) PT == __parameters))
    {
        template Get(size_t i)
        {
            enum Get = __traits(identifier, PT[i..i+1]);
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
        alias TypeTuple!() PT;
    }

    template Impl(size_t i = 0)
    {
        static if (i == PT.length)
            alias TypeTuple!() Impl;
        else
            alias TypeTuple!(Get!i, Impl!(i+1)) Impl;
    }

    alias Impl!() ParameterIdentifierTuple;
}

unittest
{
    // Test for ddoc example
    import std.traits;
    int foo(int num, string name);
    static assert([ParameterIdentifierTuple!foo] == ["num", "name"]);
}
unittest
{
    alias ParameterIdentifierTuple PIT;

    void bar(int num, string name, int[] array){}
    static assert([PIT!bar] == ["num", "name", "array"]);

    // might be changed in the future?
    void function(int num, string name) fp;
    static assert([PIT!fp] == ["", ""]);

    // might be changed in the future?
    void delegate(int num, string name, int[long] aa) dg;
    static assert([PIT!dg] == ["", "", ""]);
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

Example:
---
import std.traits;
int foo(int num, string name = "hello", int[] arr = [1,2,3]);
static assert(is(ParameterDefaultValueTuple!foo[0] == void));
static assert(   ParameterDefaultValueTuple!foo[1] == "hello");
static assert(   ParameterDefaultValueTuple!foo[2] == [1,2,3]);
---
 */
template ParameterDefaultValueTuple(func...)
    if (func.length == 1 && isCallable!func)
{
    static if (is(typeof(func[0]) PT == __parameters))
    {
        template Get(size_t i)
        {
            enum get = (PT[i..i+1] args) => args[0];
            static if (is(typeof(get())))
                enum Get = get();
            else
                alias void Get;
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
        alias TypeTuple!() PT;
    }

    template Impl(size_t i = 0)
    {
        static if (i == PT.length)
            alias TypeTuple!() Impl;
        else
            alias TypeTuple!(Get!i, Impl!(i+1)) Impl;
    }

    alias Impl!() ParameterDefaultValueTuple;
}

unittest
{
    // Test for ddoc example
    int foo(int num, string name = "hello", int[] arr = [1,2,3]);
    static assert(is(ParameterDefaultValueTuple!foo[0] == void));
    static assert(   ParameterDefaultValueTuple!foo[1] == "hello");
    static assert(   ParameterDefaultValueTuple!foo[2] == [1,2,3]);
}
unittest
{
    alias ParameterDefaultValueTuple PDVT;

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

Example:
--------------------
alias FunctionAttribute FA; // shorten the enum name

real func(real x) pure nothrow @safe
{
    return x;
}
static assert(functionAttributes!func & FA.pure_);
static assert(functionAttributes!func & FA.safe);
static assert(!(functionAttributes!func & FA.trusted)); // not @trusted
--------------------
 */
enum FunctionAttribute : uint
{
    /**
     * These flags can be bitwise OR-ed together to represent complex attribute.
     */
    none     = 0,          /// ditto
    pure_    = 0b00000001, /// ditto
    nothrow_ = 0b00000010, /// ditto
    ref_     = 0b00000100, /// ditto
    property = 0b00001000, /// ditto
    trusted  = 0b00010000, /// ditto
    safe     = 0b00100000, /// ditto
}

/// ditto
template functionAttributes(func...)
    if (func.length == 1 && isCallable!func)
{
    alias Unqual!(FunctionTypeOf!func) Func;

    enum uint functionAttributes =
            demangleFunctionAttributes(mangledName!Func[1 .. $]).value;
}

unittest
{
    alias FunctionAttribute FA;
    interface Set
    {
        int pureF() pure;
        int nothrowF() nothrow;
        ref int refF();
        int propertyF() @property;
        int trustedF() @trusted;
        int safeF() @safe;
    }
    static assert(functionAttributes!(Set.pureF) == FA.pure_);
    static assert(functionAttributes!(Set.nothrowF) == FA.nothrow_);
    static assert(functionAttributes!(Set.refF) == FA.ref_);
    static assert(functionAttributes!(Set.propertyF) == FA.property);
    static assert(functionAttributes!(Set.trustedF) == FA.trusted);
    static assert(functionAttributes!(Set.safeF) == FA.safe);
    static assert(!(functionAttributes!(Set.safeF) & FA.trusted));

    int pure_nothrow() pure nothrow { return 0; }
    static ref int  static_ref_property() @property { return *(new int); }
    ref int ref_property() @property { return *(new int); }
    void safe_nothrow() @safe nothrow { }
    static assert(functionAttributes!pure_nothrow == (FA.pure_ | FA.nothrow_));
    static assert(functionAttributes!static_ref_property == (FA.ref_ | FA.property));
    static assert(functionAttributes!ref_property == (FA.ref_ | FA.property));
    static assert(functionAttributes!safe_nothrow == (FA.safe | FA.nothrow_));

    interface Test2
    {
        int pure_const() pure const;
        int pure_sharedconst() pure shared const;
    }
    static assert(functionAttributes!(Test2.pure_const) == FA.pure_);
    static assert(functionAttributes!(Test2.pure_sharedconst) == FA.pure_);

    static assert(functionAttributes!((int a) {}) == (FA.safe | FA.pure_ | FA.nothrow_));

    auto safeDel = delegate() @safe {};
    static assert(functionAttributes!safeDel == (FA.safe | FA.pure_ | FA.nothrow_));

    auto trustedDel = delegate() @trusted {};
    static assert(functionAttributes!trustedDel == (FA.trusted | FA.pure_ | FA.nothrow_));

    auto systemDel = delegate() @system {};
    static assert(functionAttributes!systemDel == (FA.pure_ | FA.nothrow_));
}


/**
$(D true) if $(D func) is $(D @safe) or $(D @trusted).

Example:
--------------------
@safe    int add(int a, int b) {return a+b;}
@trusted int sub(int a, int b) {return a-b;}
@system  int mul(int a, int b) {return a*b;}

static assert( isSafe!add);
static assert( isSafe!sub);
static assert(!isSafe!mul);
--------------------
 */
template isSafe(alias func)
    if(isCallable!func)
{
    enum isSafe = (functionAttributes!func & FunctionAttribute.safe) != 0 ||
                  (functionAttributes!func & FunctionAttribute.trusted) != 0;
}

//Verify Examples.
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

Example:
--------------------
@safe    int add(int a, int b) {return a+b;}
@trusted int sub(int a, int b) {return a-b;}
@system  int mul(int a, int b) {return a*b;}

static assert(!isUnsafe!add);
static assert(!isUnsafe!sub);
static assert( isUnsafe!mul);
--------------------
 */
template isUnsafe(alias func)
{
    enum isUnsafe = !isSafe!func;
}

//Verify Examples.
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
$(RED Scheduled for deprecation in January 2013. It's badly named and provides
redundant functionality. It was also badly broken prior to 2.060 (bug# 8362), so
any code which uses it probably needs to be changed anyway. Please use
$(D allSatisfy(isSafe, ...)) instead.)

$(D true) all functions are $(D isSafe).

Example:
--------------------
@safe    int add(int a, int b) {return a+b;}
@trusted int sub(int a, int b) {return a-b;}
@system  int mul(int a, int b) {return a*b;}

static assert( areAllSafe!(add, add));
static assert( areAllSafe!(add, sub));
static assert(!areAllSafe!(sub, mul));
--------------------
 */
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

//Verify Example
unittest
{
    @safe    int add(int a, int b) {return a+b;}
    @trusted int sub(int a, int b) {return a-b;}
    @system  int mul(int a, int b) {return a*b;}

    static assert( areAllSafe!(add, add));
    static assert( areAllSafe!(add, sub));
    static assert(!areAllSafe!(sub, mul));
}

unittest
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

Example:
--------------------
string a = functionLinkage!(writeln!(string, int));
assert(a == "D"); // extern(D)

auto fp = &printf;
string b = functionLinkage!fp;
assert(b == "C"); // extern(C)
--------------------
 */
template functionLinkage(func...)
    if (func.length == 1 && isCallable!func)
{
    alias Unqual!(FunctionTypeOf!func) Func;

    enum string functionLinkage =
        [
            'F': "D",
            'U': "C",
            'W': "Windows",
            'V': "Pascal",
            'R': "C++"
        ][ mangledName!Func[0] ];
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

Example:
--------------------
void func() {}
static assert(variadicFunctionStyle!func == Variadic.no);

extern(C) int printf(in char*, ...);
static assert(variadicFunctionStyle!printf == Variadic.c);
--------------------
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
    alias Unqual!(FunctionTypeOf!func) Func;

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

unittest
{
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
--------------------
class C
{
    int value() @property;
}
static assert(is( typeof(C.value) == int ));
static assert(is( FunctionTypeOf!(C.value) == function ));
--------------------

Note:
Do not confuse function types with function pointer types; function types are
usually used for compile-time reflection purposes.
 */
template FunctionTypeOf(func...)
    if (func.length == 1 && isCallable!func)
{
    static if (is(typeof(& func[0]) Fsym : Fsym*) && is(Fsym == function) || is(typeof(& func[0]) Fsym == delegate))
    {
        alias Fsym FunctionTypeOf; // HIT: (nested) function symbol
    }
    else static if (is(typeof(& func[0].opCall) Fobj == delegate))
    {
        alias Fobj FunctionTypeOf; // HIT: callable object
    }
    else static if (is(typeof(& func[0].opCall) Ftyp : Ftyp*) && is(Ftyp == function))
    {
        alias Ftyp FunctionTypeOf; // HIT: callable type
    }
    else static if (is(func[0] T) || is(typeof(func[0]) T))
    {
        static if (is(T == function))
            alias T    FunctionTypeOf; // HIT: function
        else static if (is(T Fptr : Fptr*) && is(Fptr == function))
            alias Fptr FunctionTypeOf; // HIT: function pointer
        else static if (is(T Fdlg == delegate))
            alias Fdlg FunctionTypeOf; // HIT: delegate
        else static assert(0);
    }
    else static assert(0);
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
    alias TypeTuple!(__traits(getVirtualFunctions, Overloads, "test")) ov;
    alias FunctionTypeOf!(ov[0]) F_ov0;
    alias FunctionTypeOf!(ov[1]) F_ov1;
    alias FunctionTypeOf!(ov[2]) F_ov2;
    alias FunctionTypeOf!(ov[3]) F_ov3;
    static assert(is(F_ov0* == void function(string)));
    static assert(is(F_ov1* == real function(real)));
    static assert(is(F_ov2* == int function()));
    static assert(is(F_ov3* == int function() @property));

    alias FunctionTypeOf!((int a){ return a; }) F_dglit;
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
 *
 * Examples:
 * ---
 * template ExternC(T)
 *     if (isFunctionPointer!T || isDelegate!T || is(T == function))
 * {
 *     alias SetFunctionAttributes!(T, "C", functionAttributes!T) ExternC;
 * }
 * ---
 *
 * ---
 * auto assumePure(T)(T t)
 *     if (isFunctionPointer!T || isDelegate!T)
 * {
 *     enum attrs = functionAttributes!T | FunctionAttribute.pure_;
 *     return cast(SetFunctionAttributes!(T, functionLinkage!T, attrs)) t;
 * }
 * ---
 */
template SetFunctionAttributes(T, string linkage, uint attrs)
    if (isFunctionPointer!T || isDelegate!T)
{
    mixin({
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
    alias FunctionTypeOf!(SetFunctionAttributes!(T*, linkage, attrs))
        SetFunctionAttributes;
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
    alias FunctionAttribute FA;
    foreach (BaseT; TypeTuple!(typeof(&sc), typeof(&novar), typeof(&cstyle),
        typeof(&dstyle), typeof(&typesafe)))
    {
        foreach (T; TypeTuple!(BaseT, FunctionTypeOf!BaseT))
        {
            enum linkage = functionLinkage!T;
            enum attrs = functionAttributes!T;

            static assert(is(SetFunctionAttributes!(T, linkage, attrs) == T),
                "Identity check failed for: " ~ T.stringof);

            // Check that all linkage types work (D-style variadics require D linkage).
            static if (variadicFunctionStyle!T != Variadic.d)
            {
                foreach (newLinkage; TypeTuple!("D", "C", "Windows", "Pascal", "C++"))
                {
                    alias SetFunctionAttributes!(T, newLinkage, attrs) New;
                    static assert(functionLinkage!New == newLinkage,
                        "Linkage test failed for: " ~ T.stringof ~ ", " ~ newLinkage ~
                        " (got " ~ New.stringof ~ ")");
                }
            }

            // Add @safe.
            alias SetFunctionAttributes!(T, functionLinkage!T, FA.safe) T1;
            static assert(functionAttributes!T1 == FA.safe);

            // Add all known attributes, excluding conflicting ones.
            enum allAttrs = reduce!"a | b"([EnumMembers!FA]) & ~FA.safe & ~FA.property;
            alias SetFunctionAttributes!(T1, functionLinkage!T, allAttrs) T2;
            static assert(functionAttributes!T2 == allAttrs);

            // Strip all attributes again.
            alias SetFunctionAttributes!(T2, functionLinkage!T, FA.none) T3;
            static assert(is(T3 == T));
        }
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
        alias typeof(T.tupleof[0 .. $ - isNested!T]) FieldTypeTuple;
    else static if (is(T == class))
        alias typeof(T.tupleof) FieldTypeTuple;
    else
        alias TypeTuple!T FieldTypeTuple;
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
//             alias TypeTuple!myOffset Head;
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
//     alias FieldOffsetsTuple!int T1;
//     assert(T1.length == 1 && T1[0] == 0);
//     //
//     struct S2 { char a; int b; char c; double d; char e, f; }
//     alias FieldOffsetsTuple!S2 T2;
//     //pragma(msg, T2);
//     static assert(T2.length == 6
//            && T2[0] == 0 && T2[1] == 4 && T2[2] == 8 && T2[3] == 16
//                   && T2[4] == 24&& T2[5] == 25);
//     //
//     class C { int a, b, c, d; }
//     struct S3 { char a; C b; char c; }
//     alias FieldOffsetsTuple!S3 T3;
//     //pragma(msg, T2);
//     static assert(T3.length == 3
//            && T3[0] == 0 && T3[1] == 4 && T3[2] == 8);
//     //
//     struct S4 { char a; union { int b; char c; } int d; }
//     alias FieldOffsetsTuple!S4 T4;
//     //pragma(msg, FieldTypeTuple!S4);
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
alias RepresentationTypeTuple!S2 R;
assert(R.length == 4
    && is(R[0] == char[]) && is(R[1] == int)
    && is(R[2] == float) && is(R[3] == S1*));
----
*/

template RepresentationTypeTuple(T)
{
    template Impl(T...)
    {
        static if (T.length == 0)
        {
            alias TypeTuple!() Impl;
        }
        else
        {
            static if (is(T[0] R: Rebindable!R))
            {
                alias Impl!(Impl!R, T[1 .. $]) Impl;
            }
            else  static if (is(T[0] == struct) || is(T[0] == union))
            {
    // @@@BUG@@@ this should work
    //             alias .RepresentationTypes!(T[0].tupleof)
    //                 RepresentationTypes;
                alias Impl!(FieldTypeTuple!(T[0]), T[1 .. $]) Impl;
            }
            else static if (is(T[0] U == typedef))
            {
                alias Impl!(FieldTypeTuple!U, T[1 .. $]) Impl;
            }
            else
            {
                alias TypeTuple!(T[0], Impl!(T[1 .. $])) Impl;
            }
        }
    }

    static if (is(T == struct) || is(T == union) || is(T == class))
    {
        alias Impl!(FieldTypeTuple!T) RepresentationTypeTuple;
    }
    else static if (is(T U == typedef))
    {
        alias RepresentationTypeTuple!U RepresentationTypeTuple;
    }
    else
    {
        alias Impl!T RepresentationTypeTuple;
    }
}

unittest
{
    alias RepresentationTypeTuple!int S1;
    static assert(is(S1 == TypeTuple!int));

    struct S2 { int a; }
    struct S3 { int a; char b; }
    struct S4 { S1 a; int b; S3 c; }
    static assert(is(RepresentationTypeTuple!S2 == TypeTuple!int));
    static assert(is(RepresentationTypeTuple!S3 == TypeTuple!(int, char)));
    static assert(is(RepresentationTypeTuple!S4 == TypeTuple!(int, int, int, char)));

    struct S11 { int a; float b; }
    struct S21 { char[] a; union { S11 b; S11 * c; } }
    alias RepresentationTypeTuple!S21 R;
    assert(R.length == 4
           && is(R[0] == char[]) && is(R[1] == int)
           && is(R[2] == float) && is(R[3] == S11*));

    class C { int a; float b; }
    alias RepresentationTypeTuple!C R1;
    static assert(R1.length == 2 && is(R1[0] == int) && is(R1[1] == float));

    /* Issue 6642 */
    struct S5 { int a; Rebindable!(immutable Object) b; }
    alias RepresentationTypeTuple!S5 R2;
    static assert(R2.length == 2 && is(R2[0] == int) && is(R2[1] == immutable(Object)));
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
//             alias TypeTuple!myOffset Head;
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
//     alias RepresentationOffsets!S1 Offsets;
//     static assert(Offsets[0] == 0);
//     //pragma(msg, Offsets[1]);
//     static assert(Offsets[1] == 4);
// }

/*
Statically evaluates to $(D true) if and only if $(D T)'s
representation contains at least one field of pointer or array type.
Members of class types are not considered raw pointers. Pointers to
immutable objects are not considered raw aliasing.

Example:
---
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
// struct with a pointer member
struct S3 { int a; double * b; }
static assert( hasRawAliasing!S3);
// struct with an indirect pointer member
struct S4 { S3 a; double b; }
static assert( hasRawAliasing!S4);
----
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

unittest
{
    // simple types
    static assert(!hasRawAliasing!int);
    static assert( hasRawAliasing!(char*));

    // references aren't raw pointers
    static assert(!hasRawAliasing!Object);
    static assert(!hasRawAliasing!int);

    struct S1 { int  z; }
    struct S2 { int* z; }
    static assert(!hasRawAliasing!S1);
    static assert( hasRawAliasing!S2);

    struct S3 { int a; int*   z; int c; }
    struct S4 { int a; int    z; int c; }
    struct S5 { int a; Object z; int c; }
    static assert( hasRawAliasing!S3);
    static assert(!hasRawAliasing!S4);
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

    //typedef int* S8;
    //static assert(hasRawAliasing!S8);

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

Example:
---
// simple types
static assert(!hasRawLocalAliasing!int);
static assert( hasRawLocalAliasing!(char*));
static assert(!hasRawLocalAliasing!(shared char*));
// references aren't raw pointers
static assert(!hasRawLocalAliasing!Object);
// built-in arrays do contain raw pointers
static assert( hasRawLocalAliasing!(int[]));
static assert(!hasRawLocalAliasing!(shared int[]));
// aggregate of simple types
struct S1 { int a; double b; }
static assert(!hasRawLocalAliasing!S1);
// indirect aggregation
struct S2 { S1 a; double b; }
static assert(!hasRawLocalAliasing!S2);
// struct with a pointer member
struct S3 { int a; double * b; }
static assert( hasRawLocalAliasing!S3);
struct S4 { int a; shared double * b; }
static assert( hasRawLocalAliasing!S4);
// struct with an indirect pointer member
struct S5 { S3 a; double b; }
static assert( hasRawLocalAliasing!S5);
struct S6 { S4 a; double b; }
static assert(!hasRawLocalAliasing!S6);
----
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

unittest
{
    // simple types
    static assert(!hasRawUnsharedAliasing!int);
    static assert( hasRawUnsharedAliasing!(char*));
    static assert(!hasRawUnsharedAliasing!(shared char*));

    // references aren't raw pointers
    static assert(!hasRawUnsharedAliasing!Object);
    static assert(!hasRawUnsharedAliasing!int);

    struct S1 { int z; }
    struct S2 { int* z; }
    static assert(!hasRawUnsharedAliasing!S1);
    static assert( hasRawUnsharedAliasing!S2);

    struct S3 { shared int* z; }
    struct S4 { int a; int* z; int c; }
    static assert(!hasRawUnsharedAliasing!S3);
    static assert( hasRawUnsharedAliasing!S4);

    struct S5 { int a; shared int* z; int c; }
    struct S6 { int a; int z;         int c; }
    struct S7 { int a; Object z;      int c; }
    static assert(!hasRawUnsharedAliasing!S5);
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

    //typedef int* S11;
    //typedef shared int* S12;
    //static assert( hasRawUnsharedAliasing!S11);
    //static assert( hasRawUnsharedAliasing!S12);

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
    else static if (is(T[0] U == typedef))
    {
        enum hasUnsharedObjects = hasUnsharedObjects!(U, T[1 .. $]);
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
    template isAliasingDelegate(T)
    {
        enum isAliasingDelegate = isDelegate!T
                              && !is(T == immutable)
                              && !is(FunctionTypeOf!T == immutable);
    }
    enum hasAliasing = hasRawAliasing!T || hasObjects!T ||
        anySatisfy!(isAliasingDelegate, T, RepresentationTypeTuple!T);
}

// Specialization to special-case std.typecons.Rebindable.
template hasAliasing(R : Rebindable!R)
{
    enum hasAliasing = hasAliasing!R;
}

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
    template Impl(T...)
    {
        static if (!T.length)
        {
            enum Impl = false;
        }
        else static if(isFunctionPointer!(T[0]))
        {
            enum Impl = Impl!(T[1 .. $]);
        }
        else static if(isStaticArray!(T[0]))
        {
            static if (is(T[0] _ : void[N], size_t N))
                enum Impl = true;
            else
                enum Impl = Impl!(T[1 .. $]) ||
                    Impl!(RepresentationTypeTuple!(typeof(T[0].init[0])));
        }
        else
        {
            enum Impl = isPointer!(T[0]) || isDynamicArray!(T[0]) ||
                is (T[0] : const(Object)) || isAssociativeArray!(T[0]) ||
                isDelegate!(T[0]) || is(T[0] == interface)
                || Impl!(T[1 .. $]);
        }
    }

    enum hasIndirections = Impl!(T, RepresentationTypeTuple!T);
}

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

// These are for backwards compatibility, are intentionally lacking ddoc,
// and should eventually be deprecated.
alias hasUnsharedAliasing hasLocalAliasing;
alias hasRawUnsharedAliasing hasRawLocalAliasing;
alias hasUnsharedObjects hasLocalObjects;

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

    /* Issue 6642 */
    struct S8 { int a; Rebindable!(immutable Object) b; }
    static assert(!hasUnsharedAliasing!S8);

    static assert( hasUnsharedAliasing!(uint[uint]));

    static assert( hasUnsharedAliasing!(void delegate()));
    static assert( hasUnsharedAliasing!(void delegate() const));
    static assert(!hasUnsharedAliasing!(void delegate() immutable));
    static assert(!hasUnsharedAliasing!(void delegate() shared));
    static assert(!hasUnsharedAliasing!(void delegate() shared const));
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
 introduced by defining $(D this(this)) for a $(D struct). (Non-struct types
 never have elaborate copy constructors.)
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
            || anySatisfy!(.hasElaborateCopyConstructor, typeof(S.tupleof));
    }
    else
    {
        enum bool hasElaborateCopyConstructor = false;
    }
}

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
   for a $(D struct). (Non-struct types never have elaborate assignments.)

   Note: Structs with (possibly nested) postblit operator(s) will have a
   hidden yet elaborate compiler generated assignement operator (unless
   explicitly disabled).
 */
template hasElaborateAssign(S)
{
    static if(!is(S == struct))
    {
        enum bool hasElaborateAssign = false;
    }
    else
    {
        @property auto ref lvalueOf() { static S s = void; return s; }

        enum hasElaborateAssign = is(typeof(S.init.opAssign(S.init))) ||
                                  is(typeof(S.init.opAssign(lvalueOf))) ||
            anySatisfy!(.hasElaborateAssign, typeof(S.tupleof));
    }
}

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

    static struct S4
    {
        void opAssign(U)(U u) {}
        @disable void opAssign(U)(ref U u);
    }
    static assert( hasElaborateAssign!S4);

    static struct S5 { @disable this(); this(int n){ s = S(); } S s; }
    static assert( hasElaborateAssign!S5);

    static struct S6 { this(this) {} }
    static struct S7 { this(this) {} @disable void opAssign(S7); }
    static struct S8 { this(this) {} @disable void opAssign(S8); void opAssign(int) {} }
    static struct S9 { this(this) {}                             void opAssign(int) {} }
    static assert( hasElaborateAssign!S6);
    static assert(!hasElaborateAssign!S7);
    static assert(!hasElaborateAssign!S8);
    static assert( hasElaborateAssign!S9);
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
   struct). (Non-struct types never have elaborate destructors, even
   though classes may define $(D ~this()).)
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
            || anySatisfy!(.hasElaborateDestructor, typeof(S.tupleof));
    }
    else
    {
        enum bool hasElaborateDestructor = false;
    }
}

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

template Identity(alias A) { alias A Identity; }

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
            __traits(compiles, { mixin("alias Identity!(T."~name~") Sym;"); });
    }
    else
    {
        enum bool hasMember = false;
    }
}

unittest
{
    //pragma(msg, __traits(allMembers, void delegate()));
    static assert(!hasMember!(int, "blah"));
    struct S1 { int blah; }
    struct S2 { int blah(){ return 0; } }
    class C1 { int blah; }
    class C2 { int blah(){ return 0; } }
    static assert(hasMember!(S1, "blah"));
    static assert(hasMember!(S2, "blah"));
    static assert(hasMember!(C1, "blah"));
    static assert(hasMember!(C2, "blah"));

    // 6973
    import std.range;
    static assert(isOutputRange!(OutputRange!int, int));
}

// Temporarily disabled until bug4617 is fixed.
version(none) unittest
{
    // 8231
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
                     ~"alias "~ ident ~" Symbolize;"
                 ~"}");
        }
    }

    template EnumSpecificMembers(names...)
    {
        static if (names.length > 0)
        {
            alias TypeTuple!(
                    WithIdentifier!(names[0])
                        .Symbolize!(__traits(getMember, E, names[0])),
                    EnumSpecificMembers!(names[1 .. $])
                ) EnumSpecificMembers;
        }
        else
        {
            alias TypeTuple!() EnumSpecificMembers;
        }
    }

    alias EnumSpecificMembers!(__traits(allMembers, E)) EnumMembers;
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
 *     alias BaseTypeTuple!B TL;
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

    alias BaseTypeTuple!C TL;
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
 *     alias BaseClassesTuple!C TL;
 *     writeln(typeid(TL));        // prints: (B,A,Object)
 * }
 * ---
 */

template BaseClassesTuple(T)
    if (is(T == class))
{
    static if (is(T == Object))
    {
        alias TypeTuple!() BaseClassesTuple;
    }
    else static if (is(BaseTypeTuple!T[0] == Object))
    {
        alias TypeTuple!Object BaseClassesTuple;
    }
    else
    {
        alias TypeTuple!(BaseTypeTuple!T[0],
                         BaseClassesTuple!(BaseTypeTuple!T[0]))
            BaseClassesTuple;
    }
}

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
 *     alias InterfacesTuple!C TL;
 *     writeln(typeid(TL));        // prints: (I1, I2)
 * }
 * ---
 */

template InterfacesTuple(T)
{
    template Flatten(H, T...)
    {
        static if (T.length)
        {
            alias TypeTuple!(Flatten!H, Flatten!T) Flatten;
        }
        else
        {
            static if (is(H == interface))
                alias TypeTuple!(H, InterfacesTuple!H) Flatten;
            else
                alias InterfacesTuple!H Flatten;
        }
    }

    static if (is(T S == super) && S.length)
        alias NoDuplicates!(Flatten!S) InterfacesTuple;
    else
        alias TypeTuple!() InterfacesTuple;
}

unittest
{
    {
        // doc example
        interface I1 {}
        interface I2 {}
        class A : I1, I2 { }
        class B : A, I1 { }
        class C : B { }
        alias InterfacesTuple!C TL;
        static assert(is(TL[0] == I1) && is(TL[1] == I2));
    }
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
}

/**
 * Get a $(D_PARAM TypeTuple) of $(I all) base classes of $(D_PARAM
 * T), in decreasing order, followed by $(D_PARAM T)'s
 * interfaces. $(D_PARAM TransitiveBaseTypeTuple!Object) yields the
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
 *     alias TransitiveBaseTypeTuple!C TL;
 *     writeln(typeid(TL));        // prints: (B,A,Object,I)
 * }
 * ---
 */

template TransitiveBaseTypeTuple(T)
{
    static if (is(T == Object))
        alias TypeTuple!() TransitiveBaseTypeTuple;
    else
        alias TypeTuple!(BaseClassesTuple!T, InterfacesTuple!T)
            TransitiveBaseTypeTuple;
}

unittest
{
    interface J1 {}
    interface J2 {}
    class B1 {}
    class B2 : B1, J1, J2 {}
    class B3 : B2, J1 {}
    alias TransitiveBaseTypeTuple!B3 TL;
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

Example:
--------------------
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
--------------------
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
    alias MemberFunctionsTuple!(C, "test") test;
    static assert(test.length == 2);
    static assert(is(FunctionTypeOf!(test[0]) == FunctionTypeOf!(C.test)));
    static assert(is(FunctionTypeOf!(test[1]) == FunctionTypeOf!(K.test)));
    alias MemberFunctionsTuple!(C, "noexist") noexist;
    static assert(noexist.length == 0);

    interface L { int prop() @property; }
    alias MemberFunctionsTuple!(L, "prop") prop;
    static assert(prop.length == 1);

    interface Test_I
    {
        void foo();
        void foo(int);
        void foo(int, int);
    }
    interface Test : Test_I {}
    alias MemberFunctionsTuple!(Test, "foo") Test_foo;
    static assert(Test_foo.length == 3);
    static assert(is(typeof(&Test_foo[0]) == void function()));
    static assert(is(typeof(&Test_foo[2]) == void function(int)));
    static assert(is(typeof(&Test_foo[1]) == void function(int, int)));
}


private template maxAlignment(U...) if(isTypeTuple!U)
{
    static if(U.length == 1)
        enum maxAlignment = U[0].alignof;
    else
        enum maxAlignment = max(U[0].alignof, .maxAlignment!(U[1 .. $]));
}


/**
Returns class instance alignment.

Example:
---
class A { byte b; }
class B { long l; }

// As class instance always has a hidden pointer
static assert(classInstanceAlignment!A == (void*).alignof);
static assert(classInstanceAlignment!B == long.alignof);
---
 */
template classInstanceAlignment(T) if(is(T == class))
{
    alias maxAlignment!(void*, typeof(T.tupleof)) classInstanceAlignment;
}

unittest
{
    class A { byte b; }
    class B { long l; }

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
    {
        alias void CommonType;
    }
    else static if (T.length == 1)
    {
        static if(is(typeof(T[0])))
        {
            alias typeof(T[0]) CommonType;
        }
        else
        {
            alias T[0] CommonType;
        }
    }
    else static if (is(typeof(true ? T[0].init : T[1].init) U))
    {
        alias CommonType!(U, T[2 .. $]) CommonType;
    }
    else
        alias void CommonType;
}

unittest
{
    alias CommonType!(int, long, short) X;
    static assert(is(X == long));
    alias CommonType!(char[], int, long, short) Y;
    static assert(is(Y == void), Y.stringof);
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
        alias TypeTuple!real
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
    else static if (is(T : typeof(null)))
        alias TypeTuple!(typeof(null)) ImplicitConversionTargets;
    else static if(is(T : Object))
        alias TransitiveBaseTypeTuple!T ImplicitConversionTargets;
    // @@@BUG@@@ this should work
    // else static if (isDynamicArray!T && !is(typeof(T.init[0]) == const))
    //     alias TypeTuple!(const(typeof(T.init[0]))[]) ImplicitConversionTargets;
    else static if (is(T == char[]))
        alias TypeTuple!(const(char)[]) ImplicitConversionTargets;
    else static if (isDynamicArray!T && !is(typeof(T.init[0]) == const))
        alias TypeTuple!(const(typeof(T.init[0]))[]) ImplicitConversionTargets;
    else static if (is(T : void*))
        alias TypeTuple!(void*) ImplicitConversionTargets;
    else
        alias TypeTuple!() ImplicitConversionTargets;
}

unittest
{
    assert(is(ImplicitConversionTargets!double[0] == real));
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

If you omit $(D Rhs), $(D isAssignable) will check identity assignable of $(D Lhs).

Examples:
---
static assert(isAssignable!(long, int));
static assert(!isAssignable!(int, long));
static assert( isAssignable!(const(char)[], string));
static assert(!isAssignable!(string, char[]));

// int is assignable to int
static assert( isAssignable!int);

// immutable int is not assinable to immutable int
static assert(!isAssignable!(immutable int));
---
*/
template isAssignable(Lhs, Rhs = Lhs)
{
    enum bool isAssignable = is(typeof({
        Lhs l = void;
        void f(Rhs r) { l = r; }
        return l;
    }));
}

unittest
{
    static assert( isAssignable!(long, int));
    static assert( isAssignable!(const(char)[], string));

    static assert(!isAssignable!(int, long));
    static assert(!isAssignable!(string, char[]));

    static assert(!isAssignable!(immutable(int), int));
    static assert( isAssignable!(int, immutable(int)));

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
    static assert( isAssignable!(S4, immutable(int)));

    struct S5 { @disable this(); @disable this(this); }
    struct S6 { void opAssign(in ref S5); }
    static assert( isAssignable!(S6, S5));
    static assert( isAssignable!(S6, immutable(S5)));
}
unittest
{
    static assert( isAssignable!int);
    static assert(!isAssignable!(immutable int));
}


/*
Works like $(D isImplicitlyConvertible), except this cares only about storage
classes of the arguments.
 */
private template isStorageClassImplicitlyConvertible(From, To)
{
    enum isStorageClassImplicitlyConvertible = isImplicitlyConvertible!(
            ModifyTypePreservingSTC!(Pointify, From),
            ModifyTypePreservingSTC!(Pointify,   To) );
}
private template Pointify(T) { alias void* Pointify; }

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

Example:
--------------------
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
static assert(isCovariantWith!(typeof(C.clone), typeof(J.clone)));
--------------------
 */
template isCovariantWith(F, G)
    if (is(F == function) && is(G == function))
{
    static if (is(F : G))
        enum isCovariantWith = true;
    else
    {
        alias F Upr;
        alias G Lwr;

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
            alias FunctionAttribute FA;
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
            alias ParameterStorageClass STC;
            alias ParameterTypeTuple!Upr UprParams;
            alias ParameterTypeTuple!Lwr LwrParams;
            alias ParameterStorageClassTuple!Upr UprPSTCs;
            alias ParameterStorageClassTuple!Lwr LwrPSTCs;
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

version (unittest) private template isCovariantWith(alias f, alias g)
{
    enum bool isCovariantWith = isCovariantWith!(typeof(f), typeof(g));
}
unittest
{
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
    static assert(isCovariantWith!(BaseA.test, BaseA.test));
    static assert(isCovariantWith!(DerivA_1.test, DerivA_1.test));
    static assert(isCovariantWith!(DerivA_2.test, DerivA_2.test));

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


//::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::://
// SomethingTypeOf
//::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::://

/*
 */
template BooleanTypeOf(T)
{
           inout(bool) idx(        inout(bool) );
    shared(inout bool) idx( shared(inout bool) );

       immutable(bool) idy(    immutable(bool) );

    static if (is(T == enum))
        alias .BooleanTypeOf!(OriginalType!T) BooleanTypeOf;
    else static if (is(typeof(idx(T.init)) X) && !is(IntegralTypeOf!T))
        alias X BooleanTypeOf;
    else static if (is(typeof(idy(T.init)) X) && is(Unqual!X == bool) && !is(IntegralTypeOf!T))
        alias X BooleanTypeOf;
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

/*
 */
template IntegralTypeOf(T)
{
           inout(  byte) idx(        inout(  byte) );
           inout( ubyte) idx(        inout( ubyte) );
           inout( short) idx(        inout( short) );
           inout(ushort) idx(        inout(ushort) );
           inout(   int) idx(        inout(   int) );
           inout(  uint) idx(        inout(  uint) );
           inout(  long) idx(        inout(  long) );
           inout( ulong) idx(        inout( ulong) );
    shared(inout   byte) idx( shared(inout   byte) );
    shared(inout  ubyte) idx( shared(inout  ubyte) );
    shared(inout  short) idx( shared(inout  short) );
    shared(inout ushort) idx( shared(inout ushort) );
    shared(inout    int) idx( shared(inout    int) );
    shared(inout   uint) idx( shared(inout   uint) );
    shared(inout   long) idx( shared(inout   long) );
    shared(inout  ulong) idx( shared(inout  ulong) );

       immutable(  char) idy(    immutable(  char) );
       immutable( wchar) idy(    immutable( wchar) );
       immutable( dchar) idy(    immutable( dchar) );
    // Integrals and characers are impilcit convertible each other with value copy.
    // Then adding exact overloads to detect it.
       immutable(  byte) idy(    immutable(  byte) );
       immutable( ubyte) idy(    immutable( ubyte) );
       immutable( short) idy(    immutable( short) );
       immutable(ushort) idy(    immutable(ushort) );
       immutable(   int) idy(    immutable(   int) );
       immutable(  uint) idy(    immutable(  uint) );
       immutable(  long) idy(    immutable(  long) );
       immutable( ulong) idy(    immutable( ulong) );

    static if (is(T == enum))
        alias .IntegralTypeOf!(OriginalType!T) IntegralTypeOf;
    else static if (is(typeof(idx(T.init)) X))
        alias X IntegralTypeOf;
    else static if (is(typeof(idy(T.init)) X) && staticIndexOf!(Unqual!X, IntegralTypeList) >= 0)
        alias X IntegralTypeOf;
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
           inout( float) idx(        inout( float) );
           inout(double) idx(        inout(double) );
           inout(  real) idx(        inout(  real) );
    shared(inout  float) idx( shared(inout  float) );
    shared(inout double) idx( shared(inout double) );
    shared(inout   real) idx( shared(inout   real) );

       immutable( float) idy(   immutable( float) );
       immutable(double) idy(   immutable(double) );
       immutable(  real) idy(   immutable(  real) );

    static if (is(T == enum))
        alias .FloatingPointTypeOf!(OriginalType!T) FloatingPointTypeOf;
    else static if (is(typeof(idx(T.init)) X))
        alias X FloatingPointTypeOf;
    else static if (is(typeof(idy(T.init)) X))
        alias X FloatingPointTypeOf;
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
    static if (is(IntegralTypeOf!T X))
        alias X NumericTypeOf;
    else static if (is(FloatingPointTypeOf!T X))
        alias X NumericTypeOf;
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
        alias X UnsignedTypeOf;
    else
        static assert(0, T.stringof~" is not an unsigned type.");
}

/*
 */
template SignedTypeOf(T)
{
    static if (is(IntegralTypeOf!T X) &&
               staticIndexOf!(Unqual!X, SignedIntTypeList) >= 0)
        alias X SignedTypeOf;
    else static if (is(FloatingPointTypeOf!T X))
        alias X SignedTypeOf;
    else
        static assert(0, T.stringof~" is not an signed type.");
}

/*
 */
template CharTypeOf(T)
{
           inout( char) idx(        inout( char) );
           inout(wchar) idx(        inout(wchar) );
           inout(dchar) idx(        inout(dchar) );
    shared(inout  char) idx( shared(inout  char) );
    shared(inout wchar) idx( shared(inout wchar) );
    shared(inout dchar) idx( shared(inout dchar) );

      immutable(  char) idy(   immutable(  char) );
      immutable( wchar) idy(   immutable( wchar) );
      immutable( dchar) idy(   immutable( dchar) );
    // Integrals and characers are impilcit convertible each other with value copy.
    // Then adding exact overloads to detect it.
      immutable(  byte) idy(   immutable(  byte) );
      immutable( ubyte) idy(   immutable( ubyte) );
      immutable( short) idy(   immutable( short) );
      immutable(ushort) idy(   immutable(ushort) );
      immutable(   int) idy(   immutable(   int) );
      immutable(  uint) idy(   immutable(  uint) );
      immutable(  long) idy(   immutable(  long) );
      immutable( ulong) idy(   immutable( ulong) );

    static if (is(T == enum))
        alias .CharTypeOf!(OriginalType!T) CharTypeOf;
    else static if (is(typeof(idx(T.init)) X))
        alias X CharTypeOf;
    else static if (is(typeof(idy(T.init)) X) && staticIndexOf!(Unqual!X, CharTypeList) >= 0)
        alias X CharTypeOf;
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
    inout(U[n]) idx(U, size_t n)( inout(U[n]) );

    static if (is(T == enum))
        alias .StaticArrayTypeOf!(OriginalType!T) StaticArrayTypeOf;
    else static if (is(typeof(idx(defaultInit!T)) X))
        alias X StaticArrayTypeOf;
    else
        static assert(0, T.stringof~" is not a static array type");
}

unittest
{
    foreach (T; TypeTuple!(bool, NumericTypeList, ImaginaryTypeList, ComplexTypeList))
    foreach (Q; TypeTuple!(TypeQualifierList, WildOf, SharedWildOf))
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
    inout(U[]) idx(U)( inout(U[]) );

    static if (is(T == enum))
        alias .DynamicArrayTypeOf!(OriginalType!T) DynamicArrayTypeOf;
    else static if (!is(StaticArrayTypeOf!T) &&
                     is(typeof(idx(defaultInit!T)) X))
    {
        alias typeof(defaultInit!T[0]) E;

                     E[]  idy(              E[]  );
               const(E[]) idy(        const(E[]) );
               inout(E[]) idy(        inout(E[]) );
        shared(      E[]) idy( shared(      E[]) );
        shared(const E[]) idy( shared(const E[]) );
        shared(inout E[]) idy( shared(inout E[]) );
           immutable(E[]) idy(    immutable(E[]) );

        alias typeof(idy(defaultInit!T)) DynamicArrayTypeOf;
    }
    else
        static assert(0, T.stringof~" is not a dynamic array");
}

unittest
{
    foreach (T; TypeTuple!(/*void, */bool, NumericTypeList, ImaginaryTypeList, ComplexTypeList))
    foreach (Q; TypeTuple!(TypeQualifierList, WildOf, SharedWildOf))
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
    static if (is(StaticArrayTypeOf!T X))
        alias X ArrayTypeOf;
    else static if (is(DynamicArrayTypeOf!T X))
        alias X ArrayTypeOf;
    else
        static assert(0, T.stringof~" is not an array type");
}

unittest
{
}

/*
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
        alias ArrayTypeOf!T StringTypeOf;
    }
    else
        static assert(0, T.stringof~" is not a string type");
}

unittest
{
    foreach (T; CharTypeList)
    foreach (Q; TypeTuple!(MutableOf, ConstOf, ImmutableOf, WildOf))
    {
        static assert(is(Q!T[] == StringTypeOf!( Q!T[] )));

        static if (!__traits(isSame, Q, WildOf))
        {
            static assert(is(Q!T[] == StringTypeOf!( SubTypeOf!(Q!T[]) )));

            alias Q!T[] Str;
            class  C(Str) { Str val;  alias val this; }
            static assert(is(StringTypeOf!(C!Str) == Str));
        }
    }
    foreach (T; CharTypeList)
    foreach (Q; TypeTuple!(SharedOf, SharedConstOf, SharedWildOf))
    {
        static assert(!is(StringTypeOf!( Q!T[] )));
    }
}

/*
 */
template AssocArrayTypeOf(T)
{
       immutable(V [K]) idx(K, V)(    immutable(V [K]) );

           inout(V)[K]  idy(K, V)(        inout(V)[K]  );
    shared(      V [K]) idy(K, V)( shared(      V [K]) );

           inout(V [K]) idz(K, V)(        inout(V [K]) );
    shared(inout V [K]) idz(K, V)( shared(inout V [K]) );

           inout(immutable(V)[K])  idw(K, V)(        inout(immutable(V)[K])  );
    shared(inout(immutable(V)[K])) idw(K, V)( shared(inout(immutable(V)[K])) );

    static if (is(typeof(idx(defaultInit!T)) X))
    {
        alias X AssocArrayTypeOf;
    }
    else static if (is(typeof(idy(defaultInit!T)) X))
    {
        alias X AssocArrayTypeOf;
    }
    else static if (is(typeof(idz(defaultInit!T)) X))
    {
               inout(             V  [K]) idzp(K, V)(        inout(             V  [K]) );
               inout(       const(V) [K]) idzp(K, V)(        inout(       const(V) [K]) );
               inout(shared(const V) [K]) idzp(K, V)(        inout(shared(const V) [K]) );
               inout(   immutable(V) [K]) idzp(K, V)(        inout(   immutable(V) [K]) );
        shared(inout              V  [K]) idzp(K, V)( shared(inout              V  [K]) );
        shared(inout        const(V) [K]) idzp(K, V)( shared(inout        const(V) [K]) );
        shared(inout    immutable(V) [K]) idzp(K, V)( shared(inout    immutable(V) [K]) );

        alias typeof(idzp(defaultInit!T)) AssocArrayTypeOf;
    }
    else static if (is(typeof(idw(defaultInit!T)) X))
        alias X AssocArrayTypeOf;
    else
        static assert(0, T.stringof~" is not an associative array type");
}

unittest
{
    foreach (T; TypeTuple!(int/*bool, CharTypeList, NumericTypeList, ImaginaryTypeList, ComplexTypeList*/))
    foreach (P; TypeTuple!(TypeQualifierList, WildOf, SharedWildOf))
    foreach (Q; TypeTuple!(TypeQualifierList, WildOf, SharedWildOf))
    foreach (R; TypeTuple!(TypeQualifierList, WildOf, SharedWildOf))
    {
        static assert(is( P!(Q!T[R!T]) == AssocArrayTypeOf!(            P!(Q!T[R!T])  ) ));
    }
    foreach (T; TypeTuple!(int/*bool, CharTypeList, NumericTypeList, ImaginaryTypeList, ComplexTypeList*/))
    foreach (O; TypeTuple!(TypeQualifierList, WildOf, SharedWildOf))
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
template isBoolean(T)
{
    enum bool isBoolean = is(BooleanTypeOf!T) && !isAggregateType!T;
}

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
template isIntegral(T)
{
    enum bool isIntegral = is(IntegralTypeOf!T) && !isAggregateType!T;
}

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
template isFloatingPoint(T)
{
    enum bool isFloatingPoint = is(FloatingPointTypeOf!T) && !isAggregateType!T;
}

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
template isNumeric(T)
{
    enum bool isNumeric = is(NumericTypeOf!T) && !isAggregateType!T;
}

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
Detect whether $(D T) is a scalar type.
 */
template isScalarType(T)
{
    enum bool isScalarType = isNumeric!T || isSomeChar!T || isBoolean!T;
}

unittest
{
    static assert(!isScalarType!void);
    static assert( isScalarType!(immutable(int)));
    static assert( isScalarType!(shared(float)));
    static assert( isScalarType!(shared(const bool)));
    static assert( isScalarType!(const(dchar)));
}

/**
Detect whether $(D T) is a basic type.
 */
template isBasicType(T)
{
    enum bool isBasicType = isScalarType!T || is(T == void);
}

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
template isUnsigned(T)
{
    enum bool isUnsigned = is(UnsignedTypeOf!T) && !isAggregateType!T;
}

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
template isSigned(T)
{
    enum bool isSigned = is(SignedTypeOf!T) && !isAggregateType!T;
}

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
template isSomeChar(T)
{
    enum isSomeChar = is(CharTypeOf!T) && !isAggregateType!T;
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

    static assert(!isSomeChar!int);
    static assert(!isSomeChar!byte);
    static assert(!isSomeChar!string);
    static assert(!isSomeChar!wstring);
    static assert(!isSomeChar!dstring);
    static assert(!isSomeChar!(char[4]));
}

/**
Detect whether $(D T) is one of the built-in string types.
 */
template isSomeString(T)
{
    enum isSomeString = is(StringTypeOf!T) && !isAggregateType!T;
}

unittest
{
    foreach (T; TypeTuple!(char[], dchar[], string, wstring, dstring, char[4]))
    {
        static assert( isSomeString!(           T ));
        static assert(!isSomeString!(SubTypeOf!(T)));
    }

    static assert(!isSomeString!int);
    static assert(!isSomeString!(int[]));
    static assert(!isSomeString!(byte[]));
    static assert(!isSomeString!(typeof(null)));

    enum ES : string { a = "aaa", b = "bbb" }
    static assert( isSomeString!ES);
}

template isNarrowString(T)
{
    enum isNarrowString = (is(T : const char[]) || is(T : const wchar[])) && !isAggregateType!T;
}

unittest
{
    foreach (T; TypeTuple!(char[], string, wstring, char[4]))
    {
        foreach (Q; TypeTuple!(MutableOf, ConstOf, ImmutableOf)/*TypeQualifierList*/)
        {
            static assert( isNarrowString!(            Q!T  ));
            static assert(!isNarrowString!( SubTypeOf!(Q!T) ));
        }
    }

    foreach (T; TypeTuple!(int, int[], byte[], dchar[], dstring))
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
template isStaticArray(T)
{
    enum isStaticArray = is(StaticArrayTypeOf!T) && !isAggregateType!T;
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

    static assert(!isStaticArray!(const(int)[]));
    static assert(!isStaticArray!(immutable(int)[]));
    static assert(!isStaticArray!(const(int)[4][]));
    static assert(!isStaticArray!(int[]));
    static assert(!isStaticArray!(int[char]));
    static assert(!isStaticArray!(int[1][]));
    static assert(!isStaticArray!(int[int]));
    static assert(!isStaticArray!int);

    //enum ESA : int[1] { a = [1], b = [2] }
    //static assert( isStaticArray!ESA);
}

/**
 * Detect whether type $(D T) is a dynamic array.
 */
template isDynamicArray(T)
{
    enum isDynamicArray = is(DynamicArrayTypeOf!T) && !isAggregateType!T;
}

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
 * Detect whether type $(D T) is an array.
 */
template isArray(T)
{
    enum bool isArray = isStaticArray!T || isDynamicArray!T;
}

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
template isAssociativeArray(T)
{
    enum bool isAssociativeArray = is(AssocArrayTypeOf!T) && !isAggregateType!T;
}

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

template isBuiltinType(T)
{
    enum isBuiltinType = is(BuiltinTypeOf!T) && !isAggregateType!T;
}

/**
 * Detect whether type $(D T) is a pointer.
 */
template isPointer(T)
{
    static if (is(T P == U*, U) && !isAggregateType!T)
        enum isPointer = true;
    else
        enum isPointer = false;
}

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
template PointerTarget(T : T*)
{
    alias T PointerTarget;
}

/// $(RED Scheduled for deprecation. Please use $(LREF PointerTarget) instead.)
alias PointerTarget pointerTarget;

unittest
{
    static assert( is(PointerTarget!(int*) == int));
    static assert( is(PointerTarget!(long*) == long));

    static assert(!is(PointerTarget!int));
}

/**
 * Detect whether type $(D T) is an aggregate type.
 */
template isAggregateType(T)
{
    enum isAggregateType = is(T == struct) || is(T == union) ||
                           is(T == class) || is(T == interface);
}

/**
 * Returns $(D true) if T can be iterated over using a $(D foreach) loop with
 * a single loop variable of automatically inferred type, regardless of how
 * the $(D foreach) loop is implemented.  This includes ranges, structs/classes
 * that define $(D opApply) with a single loop variable, and builtin dynamic,
 * static and associative arrays.
 */
template isIterable(T)
{
    enum isIterable = is(typeof({ foreach(elem; T.init) {} }));
}

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
template isMutable(T)
{
    enum isMutable = !is(T == const) && !is(T == immutable) && !is(T == inout);
}

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
template isInstanceOf(alias S, T)
{
    static if (is(T x == S!Args, Args...))
        enum bool isInstanceOf = true;
    else
        enum bool isInstanceOf = false;
}

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
 * Tells whether the tuple T is an expression tuple.
 */
template isExpressionTuple(T ...)
{
    static if (T.length > 0)
        enum bool isExpressionTuple =
            !is(T[0]) && __traits(compiles, { auto ex = T[0]; }) &&
            isExpressionTuple!(T[1 .. $]);
    else
        enum bool isExpressionTuple = true; // default
}

unittest
{
    void foo();
    static int bar() { return 42; }
    enum aa = [ 1: -1 ];
    alias int myint;

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
Detect whether tuple $(D T) is a type tuple.
 */
template isTypeTuple(T...)
{
    static if (T.length > 0)
        enum bool isTypeTuple = is(T[0]) && isTypeTuple!(T[1 .. $]);
    else
        enum bool isTypeTuple = true; // default
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
    static assert(isAbstractFunction!(AC.foo));
}

/**
 * Detect whether $(D T) is a a final function.
 */
template isFinalFunction(T...)
    if (T.length == 1)
{
    enum bool isFinalFunction = __traits(isFinalFunction, T[0]);
}

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
    static assert(isFinalFunction!(FC.foo));
    static assert(!isFinalFunction!(C.bar));
    static assert(isFinalFunction!(C.foo));
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

unittest
{
    struct S { }
    class C { }
    abstract class AC { }
    static assert(!isAbstractClass!S);
    static assert(!isAbstractClass!C);
    static assert(isAbstractClass!AC);
}

/**
 * Detect whether $(D T) is a a final class.
 */
template isFinalClass(T...)
    if (T.length == 1)
{
    enum bool isFinalClass = __traits(isFinalClass, T[0]);
}

unittest
{
    class C { }
    abstract class AC { }
    final class FC1 : C { }
    final class FC2 { }
    static assert(!isFinalClass!C);
    static assert(!isFinalClass!AC);
    static assert(isFinalClass!FC1);
    static assert(isFinalClass!FC2);
}

//::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::://
// General Types
//::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::://

/**
Removes all qualifiers, if any, from type $(D T).

Example:
----
static assert(is(Unqual!int == int));
static assert(is(Unqual!(const int) == int));
static assert(is(Unqual!(immutable int) == int));
static assert(is(Unqual!(shared int) == int));
static assert(is(Unqual!(shared(const int)) == int));
----
 */
template Unqual(T)
{
    version (none) // Error: recursive alias declaration @@@BUG1308@@@
    {
             static if (is(T U ==     const U)) alias Unqual!U Unqual;
        else static if (is(T U == immutable U)) alias Unqual!U Unqual;
        else static if (is(T U ==     inout U)) alias Unqual!U Unqual;
        else static if (is(T U ==    shared U)) alias Unqual!U Unqual;
        else                                    alias        T Unqual;
    }
    else // workaround
    {
             static if (is(T U == shared(const U))) alias U Unqual;
        else static if (is(T U ==        const U )) alias U Unqual;
        else static if (is(T U ==    immutable U )) alias U Unqual;
        else static if (is(T U ==        inout U )) alias U Unqual;
        else static if (is(T U ==       shared U )) alias U Unqual;
        else                                        alias T Unqual;
    }
}

unittest
{
    static assert(is(Unqual!int == int));
    static assert(is(Unqual!(const int) == int));
    static assert(is(Unqual!(immutable int) == int));
    static assert(is(Unqual!(inout int) == int));
    static assert(is(Unqual!(shared int) == int));
    static assert(is(Unqual!(shared(const int)) == int));
    alias immutable(int[]) ImmIntArr;
    static assert(is(Unqual!ImmIntArr == immutable(int)[]));
}

// [For internal use]
private template ModifyTypePreservingSTC(alias Modifier, T)
{
         static if (is(T U == shared(const U))) alias shared(const Modifier!U) ModifyTypePreservingSTC;
    else static if (is(T U ==        const U )) alias        const(Modifier!U) ModifyTypePreservingSTC;
    else static if (is(T U ==    immutable U )) alias    immutable(Modifier!U) ModifyTypePreservingSTC;
    else static if (is(T U ==       shared U )) alias       shared(Modifier!U) ModifyTypePreservingSTC;
    else                                        alias              Modifier!T  ModifyTypePreservingSTC;
}

unittest
{
    static assert(is(ModifyTypePreservingSTC!(Intify, const real) == const int));
    static assert(is(ModifyTypePreservingSTC!(Intify, immutable real) == immutable int));
    static assert(is(ModifyTypePreservingSTC!(Intify, shared real) == shared int));
    static assert(is(ModifyTypePreservingSTC!(Intify, shared(const real)) == shared(const int)));
}
version (unittest) private template Intify(T) { alias int Intify; }

/**
Returns the inferred type of the loop variable when a variable of type T
is iterated over using a $(D foreach) loop with a single loop variable and
automatically inferred return type.  Note that this may not be the same as
$(D std.range.ElementType!Range) in the case of narrow strings, or if T
has both opApply and a range interface.
*/
template ForeachType(T)
{
    alias ReturnType!(typeof(
    (inout int x = 0)
    {
        foreach(elem; T.init)
        {
            return elem;
        }
        assert(0);
    })) ForeachType;
}

unittest
{
    static assert(is(ForeachType!(uint[]) == uint));
    static assert(is(ForeachType!string == immutable(char)));
    static assert(is(ForeachType!(string[string]) == string));
    static assert(is(ForeachType!(inout(int)[]) == inout(int)));
}


/**
Strips off all $(D typedef)s (including $(D enum) ones) from type $(D T).

Example:
--------------------
enum E : int { a }
typedef E F;
typedef const F G;
static assert(is(OriginalType!G == const int));
--------------------
 */
template OriginalType(T)
{
    template Impl(T)
    {
             static if (is(T U == typedef)) alias OriginalType!U Impl;
        else static if (is(T U ==    enum)) alias OriginalType!U Impl;
        else                                alias              T Impl;
    }

    alias ModifyTypePreservingSTC!(Impl, T) OriginalType;
}

unittest
{
    //typedef real T;
    //typedef T    U;
    //enum V : U { a }
    //static assert(is(OriginalType!T == real));
    //static assert(is(OriginalType!U == real));
    //static assert(is(OriginalType!V == real));
    enum E : real { a }
    enum F : E    { a = E.a }
    //typedef const F G;
    static assert(is(OriginalType!E == real));
    static assert(is(OriginalType!F == real));
    //static assert(is(OriginalType!G == const real));
}

/**
 * Get the Key type of an Associative Array.
 * Example:
 * ---
 * import std.traits;
 * alias int[string] Hash;
 * static assert(is(KeyType!Hash == string));
 * KeyType!Hash str = "string";   // str is declared as string
 * ---
 */
template KeyType(V : V[K], K)
{
    alias K KeyType;
}

/**
 * Get the Value type of an Associative Array.
 * Example:
 * ---
 * import std.traits;
 * alias int[string] Hash;
 * static assert(is(ValueType!Hash == int));
 * ValueType!Hash num = 1;   // num is declared as int
 * ---
 */
template ValueType(V : V[K], K)
{
    alias V ValueType;
}

unittest
{
    alias int[string] Hash;
    static assert(is(KeyType!Hash == string));
    static assert(is(ValueType!Hash == int));
    KeyType!Hash str = "a";
    ValueType!Hash num = 1;
}

/**
 * Returns the corresponding unsigned type for T. T must be a numeric
 * integral type, otherwise a compile-time error occurs.
 */
template Unsigned(T)
{
    template Impl(T)
    {
        static if (isUnsigned!T)
            alias Impl = T;
        else static if (isSigned!T)
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

    alias ModifyTypePreservingSTC!(Impl, OriginalType!T) Unsigned;
}

unittest
{
    alias Unsigned!int U1;
    alias Unsigned!(const(int)) U2;
    alias Unsigned!(immutable(int)) U3;
    static assert(is(U1 == uint));
    static assert(is(U2 == const(uint)));
    static assert(is(U3 == immutable(uint)));
    //struct S {}
    //alias Unsigned!S U2;
    //alias Unsigned!double U3;
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
        alias T[0] Largest;
    }
    else static if (T.length == 2)
    {
        static if(T[0].sizeof >= T[1].sizeof)
        {
            alias T[0] Largest;
        }
        else
        {
            alias T[1] Largest;
        }
    }
    else
    {
        alias Largest!(Largest!(T[0], T[1]), T[2..$]) Largest;
    }
}

unittest
{
    static assert(is(Largest!(uint, ubyte, ulong, real) == real));
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
        static if (isSigned!T)
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

    alias ModifyTypePreservingSTC!(Impl, OriginalType!T) Signed;
}

unittest
{
    alias Signed!uint S1;
    alias Signed!(const(uint)) S2;
    alias Signed!(immutable(uint)) S3;
    static assert(is(S1 == int));
    static assert(is(S2 == const(int)));
    static assert(is(S3 == immutable(int)));
}

/**
 * Returns the corresponding unsigned value for $(D x), e.g. if $(D x)
 * has type $(D int), returns $(D cast(uint) x). The advantage
 * compared to the cast is that you do not need to rewrite the cast if
 * $(D x) later changes type to e.g. $(D long).
 */
auto unsigned(T)(T x) if (isIntegral!T)
{
         static if (is(Unqual!T == byte )) return cast(ubyte ) x;
    else static if (is(Unqual!T == short)) return cast(ushort) x;
    else static if (is(Unqual!T == int  )) return cast(uint  ) x;
    else static if (is(Unqual!T == long )) return cast(ulong ) x;
    else
    {
        static assert(T.min == 0, "Bug in either unsigned or isIntegral");
        return cast(Unqual!T) x;
    }
}

unittest
{
    foreach(T; TypeTuple!(byte, ubyte))
    {
        static assert(is(typeof(unsigned(cast(T)1)) == ubyte));
        static assert(is(typeof(unsigned(cast(const T)1)) == ubyte));
        static assert(is(typeof(unsigned(cast(immutable T)1)) == ubyte));
    }

    foreach(T; TypeTuple!(short, ushort))
    {
        static assert(is(typeof(unsigned(cast(T)1)) == ushort));
        static assert(is(typeof(unsigned(cast(const T)1)) == ushort));
        static assert(is(typeof(unsigned(cast(immutable T)1)) == ushort));
    }

    foreach(T; TypeTuple!(int, uint))
    {
        static assert(is(typeof(unsigned(cast(T)1)) == uint));
        static assert(is(typeof(unsigned(cast(const T)1)) == uint));
        static assert(is(typeof(unsigned(cast(immutable T)1)) == uint));
    }

    foreach(T; TypeTuple!(long, ulong))
    {
        static assert(is(typeof(unsigned(cast(T)1)) == ulong));
        static assert(is(typeof(unsigned(cast(const T)1)) == ulong));
        static assert(is(typeof(unsigned(cast(immutable T)1)) == ulong));
    }
}

auto unsigned(T)(T x) if (isSomeChar!T)
{
    // All characters are unsigned
    static assert(T.min == 0);
    return cast(Unqual!T) x;
}

unittest
{
    foreach(T; TypeTuple!(char, wchar, dchar))
    {
        static assert(is(typeof(unsigned(cast(T)'A')) == T));
        static assert(is(typeof(unsigned(cast(const T)'A')) == T));
        static assert(is(typeof(unsigned(cast(immutable T)'A')) == T));
    }
}

/**
Returns the most negative value of the numeric type T.
*/
template mostNegative(T)
    if(isNumeric!T || isSomeChar!T)
{
    static if (is(typeof(T.min_normal)))
        enum mostNegative = -T.max;
    else static if (T.min == 0)
        enum byte mostNegative = 0;
    else
        enum mostNegative = T.min;
}

unittest
{
    static assert(mostNegative!float == -float.max);
    static assert(mostNegative!double == -double.max);
    static assert(mostNegative!real == -real.max);

    foreach(T; TypeTuple!(byte, short, int, long))
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
    //typedef int MyInt;
    //MyInt test() { return 0; }
    //static assert(mangledName!MyInt[$ - 7 .. $] == "T5MyInt"); // XXX depends on bug 4237
    //static assert(mangledName!test[$ - 7 .. $] == "T5MyInt");

    class C { int value() @property { return 0; } }
    static assert(mangledName!int == int.mangleof);
    static assert(mangledName!C == C.mangleof);
    static assert(mangledName!(C.value)[$ - 12 .. $] == "5valueMFNdZi");
    static assert(mangledName!mangledName == "3std6traits11mangledName");
    static assert(mangledName!removeDummyEnvelope ==
            "_D3std6traits19removeDummyEnvelopeFAyaZAya");
    int x;
    static assert(mangledName!((int a) { return a+x; }) == "DFNbNfiZi");    // nothrow safe
}

unittest
{
    // Test for bug 5718
    import std.demangle;
    int foo;
    assert(demangle(mangledName!foo)[$-7 .. $] == "int foo");

    void bar(){}
    assert(demangle(mangledName!bar)[$-10 .. $] == "void bar()");
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
