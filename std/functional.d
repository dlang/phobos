// Written in the D programming language.

/**
Functions that manipulate other functions.

Macros:

WIKI = Phobos/StdFunctional

Copyright: Copyright Andrei Alexandrescu 2008 - 2009.
License:   <a href="http://www.boost.org/LICENSE_1_0.txt">Boost License 1.0</a>.
Authors:   $(WEB erdani.org, Andrei Alexandrescu)

         Copyright Andrei Alexandrescu 2008 - 2009.
Distributed under the Boost Software License, Version 1.0.
   (See accompanying file LICENSE_1_0.txt or copy at
         http://www.boost.org/LICENSE_1_0.txt)
*/
module std.functional;

import std.metastrings, std.stdio, std.traits, std.typecons, std.typetuple;
// for making various functions visible in *naryFun
import std.algorithm, std.contracts, std.conv, std.math, std.range, std.string; 

/**
Transforms a string representing an expression into a unary
function. The string must use symbol name $(D a) as the parameter.

Example:

----
alias unaryFun!("(a & 1) == 0") isEven;
assert(isEven(2) && !isEven(1));
----
*/

template unaryFun(alias funbody, bool byRef = false, string parmName = "a")
{
    alias unaryFunImpl!(funbody, byRef, parmName).result unaryFun;
}

template unaryFunImpl(alias fun, bool byRef, string parmName = "a")
{
    static if (is(typeof(fun) : string))
    {
        template Body(ElementType)
        {
            // enum testAsExpression = "{"~ElementType.stringof
            //     ~" "~parmName~"; return ("~fun~");}()";
            enum testAsExpression = "{ ElementType "~parmName
                ~"; return ("~fun~");}()"; 
            enum testAsStmts = "{"~ElementType.stringof
                ~" "~parmName~"; "~fun~"}()";
            // pragma(msg, "Expr: "~testAsExpression);
            // pragma(msg, "Stmts: "~testAsStmts);
            static if (__traits(compiles, mixin(testAsExpression)))
            {
                enum string code = "return (" ~ fun ~ ");";
                alias typeof(mixin(testAsExpression)) ReturnType;
            }
            // else static if (__traits(compiles, mixin(testAsStmts)))
            // {
            //     enum string code = fun;
            //     alias typeof(mixin(testAsStmts)) ReturnType;
            // }
            else
            {
                // Credit for this idea goes to Don Clugston
                // static assert is a bit broken,
                // better to do it this way to provide a backtrace.
                // pragma(msg, "Bad unary function: " ~ fun ~ " for type "
                //         ~ ElementType.stringof);
                static assert(false, "Bad unary function: " ~ fun ~
                        " for type " ~ ElementType.stringof);
            }
        }
        static if (byRef)
        {
            Body!(ElementType).ReturnType result(ElementType)(ref ElementType a)
            {
                mixin(Body!(ElementType).code);
            }
        }
        else
        {
            Body!(ElementType).ReturnType result(ElementType)(ElementType __a)
            {
                mixin("alias __a "~parmName~";");
                mixin(Body!(ElementType).code);
            }
            // string mixme = "Body!(ElementType).ReturnType"
            //     " result(ElementType)(ElementType a)
            // { " ~ Body!(ElementType).code ~ " }";
            // mixin(mixme);
        }
    }
    else
    {
        alias fun result;
    }
}

unittest
{
    static int f1(int a) { return a + 1; }
    static assert(is(typeof(unaryFun!(f1)(1)) == int));
    assert(unaryFun!(f1)(41) == 42);
    int f2(int a) { return a + 1; }
    static assert(is(typeof(unaryFun!(f2)(1)) == int));
    assert(unaryFun!(f2)(41) == 42);
    assert(unaryFun!("a + 1")(41) == 42);
    //assert(unaryFun!("return a + 1;")(41) == 42);
}

/**
Transforms a string representing an expression into a Boolean binary
predicate. The string must use symbol names $(D a) and $(D b) as the
compared elements.

   Example:

----
alias binaryFun!("a < b") less;
assert(less(1, 2) && !less(2, 1));
alias binaryFun!("a > b") greater;
assert(!greater("1", "2") && greater("2", "1"));
----
*/

template binaryFun(alias funbody, string parm1Name = "a",
        string parm2Name = "b")
{
    alias binaryFunImpl!(funbody, parm1Name, parm2Name).result binaryFun;
}

template binaryFunImpl(alias fun,
        string parm1Name, string parm2Name)
{
    static if (is(typeof(fun) : string))
    {
        template Body(ElementType1, ElementType2)
        {
            enum testAsExpression = "{ ElementType1 "
                ~parm1Name~"; ElementType2 "
                ~parm2Name~"; return ("~fun~");}()";
            // enum testAsExpression = "{"~ElementType1.stringof
            //     ~" "~parm1Name~"; "~ElementType2.stringof
            //     ~" "~parm2Name~"; return ("~fun~");}()";
            // enum testAsStmts = "{"~ElementType1.stringof
            //     ~" "~parm1Name~"; "~ElementType2.stringof
            //     ~" "~parm2Name~"; "~fun~"}()";
            static if (__traits(compiles, mixin(testAsExpression)))
            {
                enum string code = "return (" ~ fun ~ ");";
                alias typeof(mixin(testAsExpression)) ReturnType;
            }
            // else static if (__traits(compiles, mixin(testAsStmts)))
            // {
            //     enum string code = fun;
            //     alias typeof(mixin(testAsStmts)) ReturnType;
            // }
            else
            {
                // Credit for this idea goes to Don Clugston
                enum string msg = 
                    "Bad binary function q{" ~ fun ~ "}."
                    ~" You need to use a valid D expression using symbols "
                    ~parm1Name~" of type "~ElementType1.stringof~" and "
                    ~parm2Name~" of type "~ElementType2.stringof~"."
                    ~(fun.length && fun[$ - 1] == ';'
                            ? " The trailing semicolon is _not_ needed."
                            : "")
                    ~(fun.length && fun[$ - 1] == '}'
                            ? " The trailing bracket is mistaken."
                            : "");
                static assert(false, msg);
            }
        }
        Body!(ElementType1, ElementType2).ReturnType
            result(ElementType1, ElementType2)
            (ElementType1 __a, ElementType2 __b)
        {
            mixin("alias __a "~parm1Name~";");
            mixin("alias __b "~parm2Name~";");
            mixin(Body!(ElementType1, ElementType2).code);
        }
    }
    else
    {
        alias fun result;
    }
    // static if (is(typeof(comp) : string))
    // {
    //     // @@@BUG1816@@@: typeof(mixin(comp)) should work
    //     typeof({
    //                 static ElementType1 a;
    //                 static ElementType2 b;
    //                 return mixin(comp);
    //             }())
    //         binaryFun(ElementType1, ElementType2)
    //         (ElementType1 a, ElementType2 b)
    //     {
    //         return mixin(comp);
    //     }
    // }
    // else
    // {
    //     alias comp binaryFun;
    // }
}

unittest
{
    alias binaryFun!(q{a < b}) less;
    assert(less(1, 2) && !less(2, 1));
    assert(less("1", "2") && !less("2", "1"));

    static int f1(int a, string b) { return a + 1; }
    static assert(is(typeof(binaryFun!(f1)(1, "2")) == int));
    assert(binaryFun!(f1)(41, "a") == 42);
    string f2(int a, string b) { return b ~ "2"; }
    static assert(is(typeof(binaryFun!(f2)(1, "1")) == string));
    assert(binaryFun!(f2)(1, "4") == "42");
    assert(binaryFun!("a + b")(41, 1) == 42);
    //@@BUG
    //assert(binaryFun!("return a + b;")(41, 1) == 42);
}

/*
   Predicate that returns $(D_PARAM a < b).
*/
//bool less(T)(T a, T b) { return a < b; }
//alias binaryFun!(q{a < b}) less;

/*
   Predicate that returns $(D_PARAM a > b).
*/
//alias binaryFun!(q{a > b}) greater;

/*
   Predicate that returns $(D_PARAM a == b).
*/
//alias binaryFun!(q{a == b}) equalTo;

/*
   Binary predicate that reverses the order of arguments, e.g., given
   $(D pred(a, b)), returns $(D pred(b, a)).
*/
template binaryRevertArgs(alias pred)
{
    typeof({ ElementType1 a; ElementType2 b; return pred(b, a);}())
    binaryRevertArgs(ElementType1, ElementType2)(ElementType1 a, ElementType2 b)
    {
        return pred(b, a);
    }
}

unittest
{
    alias binaryRevertArgs!(binaryFun!("a < b")) gt;
    assert(gt(2, 1) && !gt(1, 1));
    int x = 42;
    bool xyz(int a, int b) { return a * x < b / x; }
    auto foo = &xyz;
    foo(4, 5);
    alias binaryRevertArgs!(foo) zyx;
    assert(zyx(5, 4) == foo(4, 5));
}

/**
Negates predicate $(D pred).

Example:
----
string a = "   Hello, world!";
assert(find!(not!isspace)(a) == "Hello, world!");
----
 */
template not(alias pred)
{
    bool not(T...)(T args) { return !pred(args); }
}

/**
Curries $(D fun) by tying its first argument to a particular value.

Example:

----
int fun(int a, int b) { return a + b; }
alias curry!(fun, 5) fun5;
assert(fun5(6) == 11);
----

Note that in most cases you'd use an alias instead of a value
assignment. Using an alias allows you to curry template functions
without committing to a particular type of the function.
 */
template curry(alias fun, alias arg)
{
    static if (is(typeof(fun) == delegate) || is(typeof(fun) == function))
    {
        ReturnType!fun curry(ParameterTypeTuple!fun[1] arg2)
        {
            return fun(arg, arg2);
        }
    }
    else
    {
        auto curry(T)(T arg2) if (is(typeof(fun(arg, T.init))))
        {
            return fun(arg, arg2);
        }
    }
}

unittest
{
    // static int f1(int a, int b) { return a + b; }
    // assert(curry!(f1, 5)(6) == 11);
    int x = 5;
    int f2(int a, int b) { return a + b; }
    assert(curry!(f2, x)(6) == 11);
    auto dg = &f2;
    auto f3 = &curry!(dg, x);
    assert(f3(6) == 11);
}

/*private*/ template Adjoin(F...)
{
    template For(V...)
    {
        static if (F.length == 0)
        {
            alias TypeTuple!() Result;
        }
        else
        {
            alias F[0] headFun;
            alias typeof({ V values; return headFun(values); }()) Head;
            alias TypeTuple!(Head, Adjoin!(F[1 .. $]).For!(V).Result) Result;
        }

        // Tuple!(Result) fun(V...)(V a)
        // {
        //     typeof(return) result;
        //     foreach (i, Unused; Result)
        //     {
        //         result.field[i] = F[i](a);
        //     }
        //     return result;
        // }
    }
}

/**
Takes multiple functions and adjoins them together. The result is a
$(XREF typecons, Tuple) with one element per passed-in function. Upon
invocation, the returned tuple is the adjoined results of all
functions.

Example:

----
static bool f1(int a) { return a != 0; }
static int f2(int a) { return a / 2; }
auto x = adjoin!(f1, f2)(5);
assert(is(typeof(x) == Tuple!(bool, int)));
assert(x._0 == true && x.field[1] == 2);
----
*/
template adjoin(F...)
{
    Tuple!(Adjoin!(F).For!(V).Result) adjoin(V...)(V a)
    {
        typeof(return) result;
        foreach (i, Unused; Adjoin!(F).For!(V).Result)
        {
            result.field[i] = F[i](a);
        }
        return result;
    }
}

unittest
{
    static bool F1(int a) { return a != 0; }
    static int F2(int a) { return a / 2; }
    auto x = adjoin!(F1, F2)(5);
    alias Adjoin!(F1, F2).For!(int).Result R;
    assert(is(typeof(x) == Tuple!(bool, int)));
    assert(x.field[0] && x.field[1] == 2);
}

// /*private*/ template NaryFun(string fun, string letter, V...)
// {
//     static if (V.length == 0)
//     {
//         enum args = "";
//     }
//     else
//     {
//         enum args = V[0].stringof~" "~letter~"; "
//             ~NaryFun!(fun, [letter[0] + 1], V[1..$]).args;
//         enum code = args ~ "return "~fun~";";
//     }
//     alias void Result;
// }

// unittest
// {
//     writeln(NaryFun!("a * b * 2", "a", int, double).code);
// }

// /**
// naryFun 
//  */
// template naryFun(string fun)
// {
//     //NaryFun!(fun, "a", V).Result
//     int naryFun(V...)(V values)
//     {
//         enum string code = NaryFun!(fun, "a", V).code;
//         mixin(code);
//     }
// }

// unittest
// {
//     alias naryFun!("a + b") test;
//     test(1, 2);
// }

/**
   Composes passed-in functions $(D fun[0], fun[1], ...) returning a
   function $(D f(x)) that in turn returns $(D
   fun[0](fun[1](...(x)))...). Each function can be a regular
   functions, a delegate, or a string.

   Example:

----
// First split a string in whitespace-separated tokens and then
// convert each token into an integer
assert(compose!(map!(to!(int)), split)("1 2 3") == [1, 2, 3]);
----
*/

template compose(fun...) { alias composeImpl!(fun).doIt compose; }

// Implementation of compose
template composeImpl(fun...)
{
    static if (fun.length == 2)
    {
        // starch
        static if (is(typeof(fun[0]) : string))
            alias unaryFun!(fun[0]) fun0;
        else
            alias fun[0] fun0;
        static if (is(typeof(fun[1]) : string))
            alias unaryFun!(fun[1]) fun1;
        else
            alias fun[1] fun1;
        // protein: the core composition operation
        typeof({ E a; return fun0(fun1(a)); }()) doIt(E)(E a)
        {
            return fun0(fun1(a));
        }
    }
    else
    {
        // protein: assembling operations
        alias composeImpl!(fun[0], composeImpl!(fun[1 .. $]).doIt).doIt doIt;
    }
}

/**
   Pipes functions in sequence. Offers the same functionality as $(D
   compose), but with functions specified in reverse order. This may
   lead to more readable code in some situation because the order of
   execution is the same as lexical order.

   Example:
   
----
// Read an entire text file, split the resulting string in
// whitespace-separated tokens, and then convert each token into an
// integer
int[] a = pipe!(readText, split, map!(to!(int)))("file.txt");
----
 */

template pipe(fun...)
{
    alias compose!(Reverse!(fun)) pipe;
}

unittest
{
    // string foo(int a) { return to!(string)(a); }
    // int bar(string a) { return to!(int)(a) + 1; }
    // double baz(int a) { return a + 0.5; }
    // assert(compose!(baz, bar, foo)(1) == 2.5);
    // assert(pipe!(foo, bar, baz)(1) == 2.5);
    
    // assert(compose!(baz, `to!(int)(a) + 1`, foo)(1) == 2.5);
    // assert(compose!(baz, bar)("1"[]) == 2.5);
    
    // @@@BUG@@@
    //assert(compose!(baz, bar)("1") == 2.5);

    // @@@BUG@@@
    //assert(compose!(`a + 0.5`, `to!(int)(a) + 1`, foo)(1) == 2.5);
}

private struct DelegateFaker(F) {
    /*
     * What all the stuff below does is this:
     *--------------------
     * struct DelegateFaker(F) {
     *     extern(linkage)
     *     [ref] ReturnType!F doIt(ParameterTypeTuple!F args) [@attributes]
     *     {
     *         auto fp = cast(F) &this;
     *         return fp(args);
     *     }
     * }
     *--------------------
     */

    // We will use MemberFunctionGenerator in std.typecons.  This is a policy
    // configuration for generating the doIt().
    template GeneratingPolicy()
    {
        // Inform the genereator that we only have type information.
        enum WITHOUT_SYMBOL = true;

        // Generate the function body of doIt().
        template generateFunctionBody(unused...)
        {
            enum generateFunctionBody =
            // [ref] ReturnType doIt(ParameterTypeTuple args) @attributes
            q{
                // When this function gets called, the this pointer isn't
                // really a this pointer (no instance even really exists), but
                // a function pointer that points to the function to be called.
                // Cast it to the correct type and call it.

                auto fp = cast(F) &this; // XXX doesn't work with @safe
                return fp(args);
            };
        }
    }
    // Type information used by the generated code.
    alias FuncInfo!(F) FuncInfo_doIt;

    // Generate the member function doIt().
    mixin( std.typecons.MemberFunctionGenerator!(GeneratingPolicy!())
            .generateFunction!("FuncInfo_doIt", "doIt", F) );
}

/**Convert a callable to a delegate with the same parameter list and
 * return type, avoiding heap allocations and use of auxiliary storage.
 *
 * Examples:
 * ---
 * void doStuff() {
 *     writeln("Hello, world.");
 * }
 *
 * void runDelegate(void delegate() myDelegate) {
 *     myDelegate();
 * }
 *
 * auto delegateToPass = toDelegate(&doStuff);
 * runDelegate(delegateToPass);  // Calls doStuff, prints "Hello, world."
 * ---
 *
 * BUGS:
 * $(UL
 *   $(LI Does not work with $(D @safe) functions.)
 *   $(LI Ignores C-style / D-style variadic arguments.)
 * )
 */
auto toDelegate(F)(auto ref F fp) if (isCallable!(F)) {

    static if (is(F == delegate))
    {
        return fp;
    }
    else static if (is(typeof(&F.opCall) == delegate)
                || (is(typeof(&F.opCall) V : V*) && is(V == function)))
    {
        return toDelegate(&fp.opCall);
    }
    else
    {
        alias typeof(&(new DelegateFaker!(F)).doIt) DelType;

        static struct DelegateFields {
            union {
                DelType del;
                //pragma(msg, typeof(del));

                struct {
                    void* contextPtr;
                    void* funcPtr;
                }
            }
        }

        // fp is stored in the returned delegate's context pointer.
        // The returned delegate's function pointer points to
        // DelegateFaker.doIt.
        DelegateFields df;

        df.contextPtr = cast(void*) fp;

        DelegateFaker!(F) dummy;
        auto dummyDel = &(dummy.doIt);
        df.funcPtr = dummyDel.funcptr;

        return df.del;
    }
}

unittest {
    static int inc(ref uint num) {
        num++;
        return 8675309;
    }

    uint myNum = 0;
    auto incMyNumDel = toDelegate(&inc);
    static assert(is(typeof(incMyNumDel) == int delegate(ref uint)));
    auto returnVal = incMyNumDel(myNum);
    assert(myNum == 1);
    
    interface I { int opCall(); }
    class C: I { int opCall() { inc(myNum); return myNum;} }
    auto c = new C;
    auto i = cast(I) c;
    
    auto getvalc = toDelegate(c);
    assert(getvalc() == 2);
    
    auto getvali = toDelegate(i);
    assert(getvali() == 3);
    
    struct S1 { int opCall() { inc(myNum); return myNum; } }
    static assert(!is(typeof(&s1.opCall) == delegate));
    S1 s1;
    auto getvals1 = toDelegate(s1);
    assert(getvals1() == 4);
    
    struct S2 { static int opCall() { return 123456; } }
    static assert(!is(typeof(&S2.opCall) == delegate));
    S2 s2;
    auto getvals2 =&S2.opCall;
    assert(getvals2() == 123456);

    /* test for attributes */
    {
        static int refvar = 0xDeadFace;

        static ref int func_ref() { return refvar; }
        static int func_pure() pure { return 1; }
        static int func_nothrow() nothrow { return 2; }
        static int func_property() @property { return 3; }
        static int func_safe() @safe { return 4; }
        static int func_trusted() @trusted { return 5; }
        static int func_system() @system { return 6; }
        static int func_pure_nothrow() pure nothrow { return 7; }
        static int func_pure_nothrow_safe() pure @safe { return 8; }

        auto dg_ref = toDelegate(&func_ref);
        auto dg_pure = toDelegate(&func_pure);
        auto dg_nothrow = toDelegate(&func_nothrow);
        auto dg_property = toDelegate(&func_property);
        //auto dg_safe = toDelegate(&func_safe);
        auto dg_trusted = toDelegate(&func_trusted);
        auto dg_system = toDelegate(&func_system);
        auto dg_pure_nothrow = toDelegate(&func_pure_nothrow);
        //auto dg_pure_nothrow_safe = toDelegate(&func_pure_nothrow_safe);

        //static assert(is(typeof(dg_ref) == ref int delegate())); // [BUG@DMD]
        static assert(is(typeof(dg_pure) == int delegate() pure));
        static assert(is(typeof(dg_nothrow) == int delegate() nothrow));
        static assert(is(typeof(dg_property) == int delegate() @property));
        //static assert(is(typeof(dg_safe) == int delegate() @safe));
        static assert(is(typeof(dg_trusted) == int delegate() @trusted));
        static assert(is(typeof(dg_system) == int delegate() @system));
        static assert(is(typeof(dg_pure_nothrow) == int delegate() pure nothrow));
        //static assert(is(typeof(dg_pure_nothrow_safe) == int delegate() pure nothrow @safe));

        assert(dg_ref() == refvar);
        assert(dg_pure() == 1);
        assert(dg_nothrow() == 2);
        assert(dg_property() == 3);
        //assert(dg_safe() == 4);
        assert(dg_trusted() == 5);
        assert(dg_system() == 6);
        assert(dg_pure_nothrow() == 7);
        //assert(dg_pure_nothrow_safe() == 8);
    }
    /* test for linkage */
    {
        struct S
        {
            extern(C) static void xtrnC() {}
            extern(D) static void xtrnD() {}
        }
        auto dg_xtrnC = toDelegate(&S.xtrnC);
        auto dg_xtrnD = toDelegate(&S.xtrnD);
        static assert(! is(typeof(dg_xtrnC) == typeof(dg_xtrnD)));
    }
}
