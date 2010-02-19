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

private struct DelegateFaker(R, Args...) {
    R doIt(Args args) {
        // When this function gets called, the this pointer isn't really a
        // this pointer (no instance even really exists), but a function
        // pointer that points to the function
        // to be called.  Cast it to the correct type and call it.

        auto fp = cast(R function(Args)) &this;
        return fp(args);
    }
}

/**Convert a function pointer to a delegate with the same parameter list and
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
 * Bugs:  Doesn't work properly with ref return.  (See DMD bug 3756.)
 */
auto toDelegate(F)(F fp) {

    // Workaround for DMD Bug 1818.
    mixin("alias " ~ ReturnType!(F).stringof ~
        " delegate" ~ ParameterTypeTuple!(F).stringof ~ " DelType;");

    version(none) {
        // What the code would be if it weren't for bug 1818:
        alias ReturnType!(F) delegate(ParameterTypeTuple!(F)) DelType;
    }

    static struct DelegateFields {
        union {
            DelType del;
            pragma(msg, typeof(del));

            struct {
                void* contextPtr;
                void* funcPtr;
            }
        }
    }

    // fp is stored in the returned delegate's context pointer.  The returned
    // delegate's function pointer points to DelegateFaker.doIt.
    DelegateFields df;
    df.contextPtr = cast(void*) fp;

    DelegateFaker!(ReturnType!(F), ParameterTypeTuple!(F)) dummy;
    auto dummyDel = &(dummy.doIt);
    df.funcPtr = dummyDel.funcptr;

    return df.del;
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
}
