// Written in the D programming language.

/++
    This module defines functions related to exceptions and general error
    handling. It also defines functions intended to aid in unit testing.

    Synopsis of some of std.exception's functions:
--------------------
string synopsis()
{
   FILE* f = enforce(fopen("some/file"));
   // f is not null from here on
   FILE* g = enforceEx!WriteException(fopen("some/other/file", "w"));
   // g is not null from here on

   Exception e = collectException(write(g, readln(f)));
   if (e)
   {
       ... an exception occurred...
       ... We have the exception to play around with...
   }

   string msg = collectExceptionMsg(write(g, readln(f)));
   if (msg)
   {
       ... an exception occurred...
       ... We have the message from the exception but not the exception...
   }

   char[] line;
   enforce(readln(f, line));
   return assumeUnique(line);
}
--------------------

    Macros:
        WIKI = Phobos/StdException

    Copyright: Copyright Andrei Alexandrescu 2008-, Jonathan M Davis 2011-.
    License:   $(WEB boost.org/LICENSE_1_0.txt, Boost License 1.0)
    Authors:   $(WEB erdani.org, Andrei Alexandrescu) and Jonathan M Davis
    Source:    $(PHOBOSSRC std/_exception.d)

 +/
module std.exception;

import std.array, std.c.string, std.conv, std.range, std.string, std.traits;
import core.exception, core.stdc.errno;
version(unittest)
{
    import std.datetime;
    import std.stdio;
}

/++
    Asserts that the given expression does $(I not) throw the given type
    of $(D Throwable). If a $(D Throwable) of the given type is thrown,
    it is caught and does not escape assertNotThrown. Rather, an
    $(D AssertError) is thrown. However, any other $(D Throwable)s will escape.

    Params:
        T          = The $(D Throwable) to test for.
        expression = The expression to test.
        msg        = Optional message to output on test failure.

    Throws:
        $(D AssertError) if the given $(D Throwable) is thrown.

    Examples:
--------------------
assertNotThrown!TimeException(std.datetime.TimeOfDay(0, 0, 0));
assertNotThrown(std.datetime.TimeOfDay(23, 59, 59));  //Exception is default.

assert(collectExceptionMsg!AssertError(assertNotThrown!TimeException(
                            std.datetime.TimeOfDay(12, 0, 60))) ==
       `assertNotThrown failed: TimeException was thrown.`);
--------------------
  +/
void assertNotThrown(T : Throwable = Exception, E)
                    (lazy E expression,
                     string msg = null,
                     string file = __FILE__,
                     size_t line = __LINE__)
{
    try
        expression();
    catch(T t)
    {
        immutable tail = msg.empty ? "." : ": " ~ msg;

        throw new AssertError(format("assertNotThrown failed: %s was thrown%s",
                                     T.stringof,
                                     tail),
                              file,
                              line,
                              t);
    }
}

//Verify Examples
unittest
{
    assertNotThrown!TimeException(std.datetime.TimeOfDay(0, 0, 0));
    assertNotThrown(std.datetime.TimeOfDay(23, 59, 59));  //Exception is default.

    assert(collectExceptionMsg!AssertError(assertNotThrown!TimeException(
                                std.datetime.TimeOfDay(12, 0, 60))) ==
           `assertNotThrown failed: TimeException was thrown.`);
}

unittest
{
    void throwEx(Throwable t) { throw t; }
    void nothrowEx() { }

    try
        assertNotThrown!Exception(nothrowEx());
    catch(AssertError)
        assert(0);

    try
        assertNotThrown!Exception(nothrowEx(), "It's a message");
    catch(AssertError)
        assert(0);

    try
        assertNotThrown!AssertError(nothrowEx());
    catch(AssertError)
        assert(0);

    try
        assertNotThrown!AssertError(nothrowEx(), "It's a message");
    catch(AssertError)
        assert(0);

    {
        bool thrown = false;
        try
        {
            assertNotThrown!Exception(
                throwEx(new Exception("It's an Exception")));
        }
        catch(AssertError)
            thrown = true;

        assert(thrown);
    }

    {
        bool thrown = false;
        try
        {
            assertNotThrown!Exception(
                throwEx(new Exception("It's an Exception")), "It's a message");
        }
        catch(AssertError)
            thrown = true;

        assert(thrown);
    }

    {
        bool thrown = false;
        try
        {
            assertNotThrown!AssertError(
                throwEx(new AssertError("It's an AssertError",
                                        __FILE__,
                                        __LINE__)));
        }
        catch(AssertError)
            thrown = true;

        assert(thrown);
    }

    {
        bool thrown = false;
        try
        {
            assertNotThrown!AssertError(
                throwEx(new AssertError("It's an AssertError",
                                        __FILE__,
                                        __LINE__)),
                        "It's a message");
        }
        catch(AssertError)
            thrown = true;

        assert(thrown);
    }
}

/++
    Asserts that the given expression throws the given type of $(D Throwable).
    The $(D Throwable) is caught and does not escape assertThrown. However,
    any other $(D Throwable)s $(I will) escape, and if no $(D Throwable)
    of the given type is thrown, then an $(D AssertError) is thrown.

    Params:
        T          = The $(D Throwable) to test for.
        expression = The expression to test.
        msg        = Optional message to output on test failure.

    Throws:
        $(D AssertError) if the given $(D Throwable) is not thrown.

    Examples:
--------------------
assertThrown!TimeException(std.datetime.TimeOfDay(-1, 15, 30));
assertThrown(std.datetime.TimeOfDay(12, 15, 60));  //Exception is default.

assert(collectExceptionMsg!AssertError(assertThrown!AssertError(
                            std.datetime.TimeOfDay(12, 0, 0))) ==
       `assertThrown failed: No AssertError was thrown.`);
--------------------
  +/
void assertThrown(T : Throwable = Exception, E)
                 (lazy E expression,
                  string msg = null,
                  string file = __FILE__,
                  size_t line = __LINE__)
{
    bool thrown = false;

    try
        expression();
    catch(T t)
        thrown = true;

    if(!thrown)
    {
        immutable tail = msg.empty ? "." : ": " ~ msg;

        throw new AssertError(format("assertThrown failed: No %s was thrown%s",
                                     T.stringof,
                                     tail),
                              file,
                              line);
    }
}

//Verify Examples
unittest
{
    assertThrown!TimeException(std.datetime.TimeOfDay(-1, 15, 30));
    assertThrown(std.datetime.TimeOfDay(12, 15, 60));  //Exception is default.

    assert(collectExceptionMsg!AssertError(assertThrown!AssertError(
                                std.datetime.TimeOfDay(12, 0, 0))) ==
           `assertThrown failed: No AssertError was thrown.`);
}

unittest
{
    void throwEx(Throwable t) { throw t; }
    void nothrowEx() { }

    try
        assertThrown!Exception(throwEx(new Exception("It's an Exception")));
    catch(AssertError)
        assert(0);

    try
    {
        assertThrown!Exception(throwEx(new Exception("It's an Exception")),
                               "It's a message");
    }
    catch(AssertError)
        assert(0);

    try
    {
        assertThrown!AssertError(throwEx(new AssertError("It's an AssertError",
                                                         __FILE__,
                                                         __LINE__)));
    }
    catch(AssertError)
        assert(0);

    try
    {
        assertThrown!AssertError(throwEx(new AssertError("It's an AssertError",
                                                         __FILE__,
                                                         __LINE__)),
                                 "It's a message");
    }
    catch(AssertError)
        assert(0);


    {
        bool thrown = false;
        try
            assertThrown!Exception(nothrowEx());
        catch(AssertError)
            thrown = true;

        assert(thrown);
    }

    {
        bool thrown = false;
        try
            assertThrown!Exception(nothrowEx(), "It's a message");
        catch(AssertError)
            thrown = true;

        assert(thrown);
    }

    {
        bool thrown = false;
        try
            assertThrown!AssertError(nothrowEx());
        catch(AssertError)
            thrown = true;

        assert(thrown);
    }

    {
        bool thrown = false;
        try
            assertThrown!AssertError(nothrowEx(), "It's a message");
        catch(AssertError)
            thrown = true;

        assert(thrown);
    }
}

/++
    If $(D !!value) is true, $(D value) is returned. Otherwise,
    $(D new Exception(msg)) is thrown.

    Note:
        $(D enforce) is used to throw exceptions and is therefore intended to
        aid in error handling. It is $(I not) intended for verifying the logic
        of your program. That is what $(D assert) is for. Also, do not use
        $(D enforce) inside of contracts (i.e. inside of $(D in) and $(D out)
        blocks and $(D invariant)s), because they will be compiled out when
        compiling with $(I -release). Use $(D assert) in contracts.

   Example:
--------------------
auto f = enforce(fopen("data.txt"));
auto line = readln(f);
enforce(line.length, "Expected a non-empty line."));
--------------------
 +/
T enforce(T, string file = __FILE__, int line = __LINE__)
    (T value, lazy const(char)[] msg = null) @safe
{
    if (!value) bailOut(file, line, msg);
    return value;
}

/++
    If $(D !!value) is true, $(D value) is returned. Otherwise, the given
    delegate is called.
 +/
T enforce(T, string file = __FILE__, int line = __LINE__)
(T value, scope void delegate() dg)
{
    if (!value) dg();
    return value;
}

private void bailOut(string file, int line, in char[] msg) @safe
{
    throw new Exception(msg ? msg.idup : "Enforcement failed", file, line);
}

unittest
{
    assert (enforce(123) == 123);

    try
    {
        enforce(false, "error");
        assert (false);
    }
    catch (Exception e)
    {
        assert (e.msg == "error");
        assert (e.file == __FILE__);
        assert (e.line == __LINE__-7);
    }
}

/++
    If $(D !!value) is true, $(D value) is returned. Otherwise, $(D ex) is thrown.

   Example:
--------------------
auto f = enforce(fopen("data.txt"));
auto line = readln(f);
enforce(line.length, new IOException); // expect a non-empty line
--------------------
 +/
T enforce(T)(T value, lazy Throwable ex) @safe
{
    if (!value) throw ex();
    return value;
}

unittest
{
    assertNotThrown(enforce(true, new Exception("this should not be thrown")));
    assertThrown(enforce(false, new Exception("this should be thrown")));
}

/++
    If $(D !!value) is true, $(D value) is returned. Otherwise,
    $(D new ErrnoException(msg)) is thrown. $(D ErrnoException) assumes that the
    last operation set $(D errno) to an error code.

   Example:
--------------------
auto f = errnoEnforce(fopen("data.txt"));
auto line = readln(f);
enforce(line.length); // expect a non-empty line
--------------------
 +/
T errnoEnforce(T, string file = __FILE__, int line = __LINE__)
    (T value, lazy string msg = null) @safe
{
    if (!value) throw new ErrnoException(msg, file, line);
    return value;
}


/++
    If $(D !!value) is $(D true), $(D value) is returned. Otherwise,
    $(D new E(msg, file, line)) is thrown.

   Example:
--------------------
 auto f = enforceEx!FileMissingException(fopen("data.txt"));
 auto line = readln(f);
 enforceEx!DataCorruptionException(line.length);
--------------------
 +/
T enforceEx(E, T)(T value, lazy string msg = "", string file = __FILE__, size_t line = __LINE__)
    if(is(typeof(new E(msg, file, line))))
{
    if (!value) throw new E(msg, file, line);
    return value;
}

/++
    $(RED Scheduled for deprecation in February 2012. Please use the version of
          $(D enforceEx) which takes an exception that constructs with
          $(D new E(msg, file, line)).)

    If $(D !!value) is $(D true), $(D value) is returned. Otherwise,
    $(D new E(msg)) is thrown.
  +/
T enforceEx(E, T)(T value, lazy string msg = "")
    if(is(typeof(new E(msg))) && !is(typeof(new E(msg, __FILE__, __LINE__))))
{
    import std.metastrings;

    pragma(msg, Format!("Notice: As of Phobos 2.055, the version of enforceEx which " ~
                        "constructs its exception with new E(msg) instead of " ~
                        "new E(msg, file, line) has been scheduled for " ~
                        "deprecation in February 2012. Please update %s's " ~
                        "constructor so that it can be constructed with " ~
                        "new %s(msg, file, line).", E.stringof, E.stringof));

    if (!value) throw new E(msg);
    return value;
}

unittest
{
    assertNotThrown(enforceEx!Exception(true));
    assertNotThrown(enforceEx!Exception(true, "blah"));

    {
        auto e = collectException(enforceEx!Exception(false));
        assert(e !is null);
        assert(e.msg.empty);
        assert(e.file == __FILE__);
        assert(e.line == __LINE__ - 4);
    }

    {
        auto e = collectException(enforceEx!Exception(false, "hello", "file", 42));
        assert(e !is null);
        assert(e.msg == "hello");
        assert(e.file == "file");
        assert(e.line == 42);
    }
}


/++
    Catches and returns the exception thrown from the given expression.
    If no exception is thrown, then null is returned and $(D result) is
    set to the result of the expression.

    Note that while $(D collectException) $(I can) be used to collect any
    $(D Throwable) and not just $(D Exception)s, it is generally ill-advised to
    catch anything that is neither an $(D Exception) nor a type derived from
    $(D Exception). So, do not use $(D collectException) to collect
    non-$(D Exception)s unless you're sure that that's what you really want to
    do.

    Params:
        T          = The type of exception to catch.
        expression = The expression which may throw an exception.
        result     = The result of the expression if no exception is thrown.

    Example:
--------------------
int[] a = new int[3];
int b;
assert(collectException(a[4], b));
--------------------
+/
T collectException(T = Exception, E)(lazy E expression, ref E result)
{
    try
    {
        result = expression();
    }
    catch (T e)
    {
        return e;
    }
    return null;
}

unittest
{
    int[] a = new int[3];
    int b;
    int foo() { throw new Exception("blah"); }
    assert(collectException(foo(), b));
}

/++
    Catches and returns the exception thrown from the given expression.
    If no exception is thrown, then null is returned. $(D E) can be
    $(D void).

    Note that while $(D collectException) $(I can) be used to collect any
    $(D Throwable) and not just $(D Exception)s, it is generally ill-advised to
    catch anything that is neither an $(D Exception) nor a type derived from
    $(D Exception). So, do not use $(D collectException) to collect
    non-$(D Exception)s unless you're sure that that's what you really want to
    do.

    Params:
        T          = The type of exception to catch.
        expression = The expression which may throw an exception.
+/
T collectException(T : Throwable = Exception, E)(lazy E expression)
{
    try
    {
        expression();
    }
    catch (T t)
    {
        return t;
    }
    return null;
}

unittest
{
    int foo() { throw new Exception("blah"); }
    assert(collectException(foo()));
}

/++
    Catches the exception thrown from the given expression and returns the
    msg property of that exception. If no exception is thrown, then null is
    returned. $(D E) can be $(D void).

    If an exception is thrown but it has an empty message, then
    $(D emptyExceptionMsg) is returned.

    Note that while $(D collectExceptionMsg) $(I can) be used to collect any
    $(D Throwable) and not just $(D Exception)s, it is generally ill-advised to
    catch anything that is neither an $(D Exception) nor a type derived from
    $(D Exception). So, do not use $(D collectExceptionMsg) to collect
    non-$(D Exception)s unless you're sure that that's what you really want to
    do.

    Params:
        T          = The type of exception to catch.
        expression = The expression which may throw an exception.

    Examples:
--------------------
void throwFunc() {throw new Exception("My Message.");}
assert(collectExceptionMsg(throwFunc()) == "My Message.");

void nothrowFunc() {}
assert(collectExceptionMsg(nothrowFunc()) is null);

void throwEmptyFunc() {throw new Exception("");}
assert(collectExceptionMsg(throwEmptyFunc()) == emptyExceptionMsg);
--------------------
+/
string collectExceptionMsg(T = Exception, E)(lazy E expression)
{
    try
    {
        expression();

        return cast(string)null;
    }
    catch(T e)
        return e.msg.empty ? emptyExceptionMsg : e.msg;
}

//Verify Examples.
unittest
{
    void throwFunc() {throw new Exception("My Message.");}
    assert(collectExceptionMsg(throwFunc()) == "My Message.");

    void nothrowFunc() {}
    assert(collectExceptionMsg(nothrowFunc()) is null);

    void throwEmptyFunc() {throw new Exception("");}
    assert(collectExceptionMsg(throwEmptyFunc()) == emptyExceptionMsg);
}

/++
    Value that collectExceptionMsg returns when it catches an exception
    with an empty exception message.
 +/
enum emptyExceptionMsg = "<Empty Exception Message>";

/**
 * Casts a mutable array to an immutable array in an idiomatic
 * manner. Technically, $(D assumeUnique) just inserts a cast,
 * but its name documents assumptions on the part of the
 * caller. $(D assumeUnique(arr)) should only be called when
 * there are no more active mutable aliases to elements of $(D
 * arr). To strenghten this assumption, $(D assumeUnique(arr))
 * also clears $(D arr) before returning. Essentially $(D
 * assumeUnique(arr)) indicates commitment from the caller that there
 * is no more mutable access to any of $(D arr)'s elements
 * (transitively), and that all future accesses will be done through
 * the immutable array returned by $(D assumeUnique).
 *
 * Typically, $(D assumeUnique) is used to return arrays from
 * functions that have allocated and built them.
 *
 * Example:
 *
 * ----
 * string letters()
 * {
 *   char[] result = new char['z' - 'a' + 1];
 *   foreach (i, ref e; result)
 *   {
 *     e = 'a' + i;
 *   }
 *   return assumeUnique(result);
 * }
 * ----
 *
 * The use in the example above is correct because $(D result)
 * was private to $(D letters) and is unaccessible in writing
 * after the function returns. The following example shows an
 * incorrect use of $(D assumeUnique).
 *
 * Bad:
 *
 * ----
 * private char[] buffer;
 * string letters(char first, char last)
 * {
 *   if (first >= last) return null; // fine
 *   auto sneaky = buffer;
 *   sneaky.length = last - first + 1;
 *   foreach (i, ref e; sneaky)
 *   {
 *     e = 'a' + i;
 *   }
 *   return assumeUnique(sneaky); // BAD
 * }
 * ----
 *
 * The example above wreaks havoc on client code because it is
 * modifying arrays that callers considered immutable. To obtain an
 * immutable array from the writable array $(D buffer), replace
 * the last line with:
 * ----
 * return to!(string)(sneaky); // not that sneaky anymore
 * ----
 *
 * The call will duplicate the array appropriately.
 *
 * Checking for uniqueness during compilation is possible in certain
 * cases (see the $(D unique) and $(D lent) keywords in
 * the $(WEB archjava.fluid.cs.cmu.edu/papers/oopsla02.pdf, ArchJava)
 * language), but complicates the language considerably. The downside
 * of $(D assumeUnique)'s convention-based usage is that at this
 * time there is no formal checking of the correctness of the
 * assumption; on the upside, the idiomatic use of $(D
 * assumeUnique) is simple and rare enough to be tolerable.
 *
 */

immutable(T)[] assumeUnique(T)(ref T[] array) pure nothrow
{
    auto result = cast(immutable(T)[]) array;
    array = null;
    return result;
}

unittest
{
    int[] arr = new int[1];
    auto arr1 = assumeUnique(arr);
    assert(is(typeof(arr1) == immutable(int)[]) && arr == null);
}

immutable(T[U]) assumeUnique(T, U)(ref T[U] array) pure nothrow
{
    auto result = cast(immutable(T[U])) array;
    array = null;
    return result;
}

// @@@BUG@@@
version(none) unittest
{
    int[string] arr = ["a":1];
    auto arr1 = assumeUnique(arr);
    assert(is(typeof(arr1) == immutable(int[string])) && arr == null);
}

/**
Returns $(D true) if $(D source)'s representation embeds a pointer
that points to $(D target)'s representation or somewhere inside
it. Note that evaluating $(D pointsTo(x, x)) checks whether $(D x) has
internal pointers.
*/
bool pointsTo(S, T)(ref const S source, ref const T target) @trusted pure nothrow
{
    static if (is(S P : U*, U))
    {
        const m = cast(void*) source,
              b = cast(void*) &target, e = b + target.sizeof;
        return b <= m && m < e;
    }
    else static if (is(S == struct))
    {
        foreach (i, Subobj; typeof(source.tupleof))
        {
            static if (!isStaticArray!(Subobj))
                if (pointsTo(source.tupleof[i], target)) return true;
        }
        return false;
    }
    else static if (isArray!(S))
    {
        return overlap(cast(void[])source, cast(void[])(&target)[0 .. 1]).length != 0;
    }
    else
    {
        return false;
    }
}

unittest
{
    struct S1 { int a; S1 * b; }
    S1 a1;
    S1 * p = &a1;
    assert(pointsTo(p, a1));

    S1 a2;
    a2.b = &a1;
    assert(pointsTo(a2, a1));

    struct S3 { int[10] a; }
    S3 a3;
    auto a4 = a3.a[2 .. 3];
    assert(pointsTo(a4, a3));

    auto a5 = new double[4];
    auto a6 = a5[1 .. 2];
    assert(!pointsTo(a5, a6));

    auto a7 = new double[3];
    auto a8 = new double[][1];
    a8[0] = a7;
    assert(!pointsTo(a8[0], a8[0]));

    // don't invoke postblit on subobjects
    {
        static struct NoCopy { this(this) { assert(0); } }
        static struct Holder { NoCopy a, b, c; }
        Holder h;
        pointsTo(h, h);
    }

    shared S3 sh3;
    shared sh3sub = sh3.a[];
    assert(pointsTo(sh3sub, sh3));
    
    int[] darr = [1, 2, 3, 4];
    foreach(i; 0 .. 4)
        assert(pointsTo(darr, darr[i]));
    assert(pointsTo(darr[0..3], darr[2]));
    assert(!pointsTo(darr[0..3], darr[3]));
    
    int[4] sarr = [1, 2, 3, 4];
    foreach(i; 0 .. 4)
        assert(pointsTo(sarr, sarr[i]));
    assert(pointsTo(sarr[0..3], sarr[2]));
    assert(!pointsTo(sarr[0..3], sarr[3]));
}

/*********************
 * Thrown if errors that set $(D errno) occur.
 */
class ErrnoException : Exception
{
    uint errno;                 // operating system error code
    this(string msg, string file = null, uint line = 0)
    {
        errno = getErrno;
        version (linux)
        {
            char[1024] buf = void;
            auto s = std.c.string.strerror_r(errno, buf.ptr, buf.length);
        }
        else
        {
            auto s = std.c.string.strerror(errno);
        }
        super(msg~" ("~to!string(s)~")", file, line);
    }
}

// structuralCast
// class-to-class structural cast
Target structuralCast(Target, Source)(Source obj)
    if (is(Source == class) || is(Target == class))
{
    // For the structural cast to work, the source and the target must
    // have the same base class, and the target must add no data or
    // methods
    static assert(0, "Not implemented");
}

// interface-to-interface structural cast
Target structuralCast(Target, Source)(Source obj)
    if (is(Source == interface) || is(Target == interface))
{
}

unittest
{
    interface I1 { void f1(); }
    interface I2 { void f2(); }
    interface I12 : I1, I2 { }
    //pragma(msg, TransitiveBaseTypeTuple!I12.stringof);
    //static assert(is(TransitiveBaseTypeTuple!I12 == TypeTuple!(I2, I1)));
}

// Target structuralCast(Target, Source)(Source obj)
//     if (is(Source == interface) || is(Target == interface))
// {
//     static assert(is(BaseTypeTuple!(Source)[0] ==
//                     BaseTypeTuple!(Target)[0]));
//     alias BaseTypeTuple!(Source)[1 .. $] SBases;
//     alias BaseTypeTuple!(Target)[1 .. $] TBases;
//         else
//         {
//             // interface-to-class
//             static assert(0);
//         }
//     }
//     else
//     {
//         static if (is(Source == class))
//         {
//             // class-to-interface structural cast
//             alias BaseTypeTuple!(Source)[1 .. $] SBases;
//             alias BaseTypeTuple!(Target) TBases;
//         }
//         else
//         {
//             // interface-to-interface structural cast
//             alias BaseTypeTuple!(Source) SBases;
//             alias BaseTypeTuple!(Target) TBases;
//         }
//     }
//     static assert(SBases.length >= TBases.length,
//             "Cannot structurally cast to a target with"
//             " more interfaces implemented");
//     static assert(
//         is(typeof(Target.tupleof) == typeof(Source.tupleof)),
//             "Cannot structurally cast to a target with more fields");
//     // Target bases must be a prefix of the source bases
//     foreach (i, B; TBases)
//     {
//         static assert(is(SBases[i] == B)
//                 || is(SBases[i] == interface) && is(SBases[i] : B),
//                 SBases[i].stringof ~ " does not inherit "
//                 ~ B.stringof);
//     }
//     union Result
//     {
//         Source src;
//         Target tgt;
//     }
//     Result result = { obj };
//     return result.tgt;
// }

template structurallyCompatible(S, T) if (!isArray!S || !isArray!T)
{
    enum structurallyCompatible =
        FieldTypeTuple!S.length >= FieldTypeTuple!T.length
        && is(FieldTypeTuple!S[0 .. FieldTypeTuple!T.length]
                == FieldTypeTuple!T);
}

template structurallyCompatible(S, T) if (isArray!S && isArray!T)
{
    enum structurallyCompatible =
        .structurallyCompatible!(ElementType!S, ElementType!T) &&
        .structurallyCompatible!(ElementType!T, ElementType!S);
}

unittest
{
    // struct X { uint a; }
    // static assert(structurallyCompatible!(uint[], X[]));
    // struct Y { uint a, b; }
    // static assert(!structurallyCompatible!(uint[], Y[]));
    // static assert(!structurallyCompatible!(Y[], uint[]));
    // static assert(!structurallyCompatible!(Y[], X[]));
}

/*
Structural cast. Allows casting among class types that logically have
a common base, but that base is not made explicit.

Example:
----
interface Document { ... }
interface Storable { ... }
interface StorableDocument : Storable, Document { ... }
class Doc : Storable, Document { ... }
void process(StorableDocument d);
...

auto c = new Doc;
process(c); // does not work
process(structuralCast!StorableDocument(c)); // works
 */

// template structuralCast(Target)
// {
//     Target structuralCast(Source)(Source obj)
//     {
//         static if (is(Source : Object) || is(Source == interface))
//         {
//             return .structuralCastImpl!(Target)(obj);
//         }
//         else
//         {
//             static if (structurallyCompatible!(Source, Target))
//                 return *(cast(Target*) &obj);
//             else
//                 static assert(false);
//         }
//     }
// }

unittest
{
    // interface I1 {}
    // interface I2 {}
    // class Base : I1 { int x; }
    // class A : I1 {}
    // class B : I1, I2 {}

    // auto b = new B;
    // auto a = structuralCast!(A)(b);
    // assert(a);

    // struct X { int a; }
    // int[] arr = [ 1 ];
    // auto x = structuralCast!(X[])(arr);
    // assert(x[0].a == 1);
}

unittest
{
    // interface Document { int fun(); }
    // interface Storable { int gun(); }
    // interface StorableDocument : Storable, Document {  }
    // class Doc : Storable, Document {
    //     int fun() { return 42; }
    //     int gun() { return 43; }
    // }
    // void process(StorableDocument d) {
    //     assert(d.fun + d.gun == 85, text(d.fun + d.gun));
    // }

    // auto c = new Doc;
    // Document d = c;
    // //process(c); // does not work
    // union A
    // {
    //     Storable s;
    //     StorableDocument sd;
    // }
    // A a = { c };
    //process(a.sd); // works
    //process(structuralCast!StorableDocument(d)); // works
}
