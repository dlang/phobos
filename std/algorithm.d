// Written in the D programming language.

/**
Implements algorithms oriented mainly towards processing of
sequences. Some functions are semantic equivalents or supersets of
those found in the $(D algorithm) header in $(WEB sgi.com/tech/stl/,
Alexander Stepanov's Standard Template Library) for C++.

Author:
$(WEB erdani.org, Andrei Alexandrescu)

Note:

Many functions in this module are parameterized with a function or a
$(GLOSSARY predicate). The predicate may be passed either as a
function name, a delegate name, a $(GLOSSARY functor) name, or a
compile-time string. The string may consist of $(B any) legal D
expression that uses the symbol $(D a) (for unary functions) or the
symbols $(D a) and $(D b) (for binary functions). These names will NOT
interfere with other homonym symbols in user code because they are
evaluated in a different context. The default for all binary
comparison predicates is $(D "a == b") for unordered operations and
$(D "a < b") for ordered operations.

Example:

----
int[] a = ...;
static bool greater(int a, int b)
{
    return a > b;
}
sort!(greater)(a);  // predicate as alias
sort!("a > b")(a);  // predicate as string
                    // (no ambiguity with array name)
sort(a);            // no predicate, "a < b" is implicit
----

Some functions are additionally parameterized with primitives such as
$(D move) (defaulting to $(XREF _algorithm,move)) or $(D iterSwap)
primitive (defaulting to $(XREF _algorithm,iterSwap)). These
parameters distill the way in which data is manipulated, and the
algorithms guarantee they only use them to touch values. There is
sometimes a need to override that default behavior. Possible uses
include notifying observers, counting the number of operations, or
manipulating multiple collections in lockstep.

Macros:
WIKI = Phobos/StdAlgorithm
*/

/*
 *  Copyright (C) 2004-2006 by Digital Mars, www.digitalmars.com
 *  Written by Andrei Alexandrescu, www.erdani.org
 *
 *  This software is provided 'as-is', without any express or implied
 *  warranty. In no event will the authors be held liable for any damages
 *  arising from the use of this software.
 *
 *  Permission is granted to anyone to use this software for any purpose,
 *  including commercial applications, and to alter it and redistribute it
 *  freely, subject to the following restrictions:
 *
 *  o  The origin of this software must not be misrepresented; you must not
 *     claim that you wrote the original software. If you use this software
 *     in a product, an acknowledgment in the product documentation would be
 *     appreciated but is not required.
 *  o  Altered source versions must be plainly marked as such, and must not
 *     be misrepresented as being the original software.
 *  o  This notice may not be removed or altered from any source
 *     distribution.
 */

module std.algorithm;
private import std.math;
private import std.date;
private import std.functional;
private import std.iterator;
private import std.conv;
private import std.typecons;
private import std.typetuple;
private import std.metastrings;
private import std.contracts;
private import std.traits;
private import std.c.string;

version(Unittest)
{
    private import std.stdio;
    private import std.random;
}

/**
Implements the homonym function (also known as $(D transform)) present
in many languages of functional flavor. The call $(D map!(fun)(range1,
range2, ..., rangeN)) returns a new range of which elements are
obtained by applying $(D fun(x)) left to right for all $(D x) in $(D
range1), then all $(D x) in $(D range2), ..., all $(D x) in $(D
rangeN). The original ranges are not changed.

Example:
----
int[] arr1 = [ 1, 2, 3, 4 ];
int[] arr2 = [ 5, 6 ];
auto squares = map!("a * a")(arr1, arr2);
assert(squares == [ 1, 4, 9, 16, 25, 36 ]);
----

In all cases, the type of the result is the same as of the type of the
first range passed in. If a different type of range is needed, just
supply an empty range of the needed type as the first argument.

Example:
----
short[] arr = [ 1, 2 ];
auto squares = map!("a * a")(cast(int[]) null, arr);
assert(is(typeof(squares) == int[]));
----
*/
Ranges[0] map(string fun, Ranges...)(Ranges rs)
{
    return .map!(unaryFun!(fun), Ranges)(rs);
}

/// Ditto
Ranges[0] map(alias fun, Ranges...)(Ranges rs)
{
    typeof(return) result;
    foreach (r, R; Ranges)
    {
        foreach (i; begin(rs[r]) .. end(rs[r]))
        {
            result ~= fun(*i);
        }
    }
    return result;
}

unittest
{
    int[] arr1 = [ 1, 2, 3, 4 ];
    int[] arr2 = [ 5, 6 ];
    auto squares = map!("a * a")(arr1, arr2);
    assert(squares == [ 1, 4, 9, 16, 25, 36 ]);

    short[] arr = [ 1, 2 ];
    auto squares2 = map!("a * a")(cast(int[])null, arr);
    assert(is(typeof(squares2) == int[]));
}

// reduce
private template NxNHelper(F...)
{
    private template For(Args...)
    {
        enum uint fs = TypeTuple!(F).length;
        static assert(
            fs,
            "reduce: too few arguments. You must pass at least a function");
        static assert(
            Args.length > fs,
            "reduce: too few arguments. You must pass one seed for"
            " each function (total "~ToString!(fs)~")"
            ", followed by the ranges to operate on.");
        // Result type
        static if (F.length > 1)
            alias Tuple!(Args[0 .. F.length]) Result;
        else
            alias Args[0] Result;

        // Element type
        enum functions = F.length;
        //alias typeof(*Args[functions]) Element;

        // Apply predicate
        R apply(uint n, R, E)(R a, E b)
        {
            alias typeof(F[n]) thisFun;
            static if (is(typeof(thisFun~""))) // (!is(typeof(F[n](a, b))))
            {
                return binaryFun!(""~F[n])(a, b);
            }
            else
            {
                return F[n](a, b);
            }
        }
    }
}

/**
Implements the homonym function (also known as $(D accumulate), $(D
compress), $(D inject), or $(D foldl)) present in various programming
languages of functional flavor. The call $(D reduce!(fun)(seed,
range)) first assigns $(D seed) to an internal variable $(D result),
also called the accumulator. Then, for each element $(D x) in $(D
range), $(D result = fun(result, x)) gets evaluated. Finally, $(D
result) is returned. Many aggregate range operations turn out to be
solved with $(D reduce) quickly and easily. The example below
illustrates $(D reduce)'s remarkable power and flexibility.

Example:
----
int[] arr = [ 1, 2, 3, 4, 5 ];
// Sum all elements
auto sum = reduce!("a + b")(0, arr);
assert(sum == 15);

// Compute the maximum of all elements
auto largest = reduce!(max)(arr[0], arr[1 .. $]);
assert(largest == 5);

// Compute the number of odd elements
auto odds = reduce!("a + (b & 1)")(0, arr);
assert(odds == 3);

// Compute the sum of squares
auto ssquares = reduce!("a + b * b")(0, arr);
assert(ssquares == 55);
----

$(DDOC_SECTION_H Multiple ranges:) It is possible to pass any number
of ranges to $(D reduce), as in $(D reduce!(fun)(seed, range1, range2,
range3)). Then $(D reduce) will simply apply its algorithm in
succession to each range, from left to right.

Example:
----
int[] a = [ 3, 4 ];
int[] b = [ 100 ];
auto r = reduce!("a + b")(0, a, b);
assert(r == 107);

// Mixing convertible types is fair game, too
double[] c = [ 2.5, 3.0 ];
auto r1 = reduce!("a + b")(0.0, a, b, c);
assert(r1 == 112.5);
----

$(DDOC_SECTION_H Multiple functions:) Sometimes it is very useful to
compute multiple aggregates in one pass. One advantage is that the
computation is faster because the looping overhead is shared. That's
why $(D reduce) accepts multiple functions. If two or more functions
are passed, $(D reduce) returns a $(XREF typecons, Tuple) object with
one member per passed-in function. The number of seeds must be
correspondingly increased.

Example:
----
double[] a = [ 3.0, 4, 7, 11, 3, 2, 5 ];
// Compute minimum and maximum in one pass
auto r = reduce!(min, max)(double.max, -double.max, a);
// The type of r is Tuple!(double, double)
assert(r._0 == 2);  // minimum
assert(r._1 == 11); // maximum

// Compute sum and sum of squares in one pass
r = reduce!("a + b", "a + b * b")(0.0, 0.0, a);
assert(r._0 == 35);  // sum
assert(r._1 == 233); // sum of squares
// Compute average and standard deviation from the above
auto avg = r._0 / a.length;
auto stdev = sqrt(r._1 / a.length - avg * avg);
----

$(DDOC_SECTION_H Multiple ranges and functions:) The most general form
of $(D reduce) accepts multiple functions and multiple ranges
simultaneously. The call $(D reduce!(fun1, ..., funN)(seed1, ...,
seedN, range1, ..., rangeM)) applies the reduction algorithm for all
functions and all ranges.

Example:
----
int[] a = [ 3, 4, 7, 11, 3, 2, 5 ];
double[] b = [ 2.5, 4, -4.5, 2, 10.9 ];
// Compute minimum and maximum in one pass over a and b
auto r = reduce!(min, max)(double.max, -double.max, a, b);
assert(r._0 == -4.5);  // minimum
assert(r._1 == 11);    // maximum
----
*/

template reduce(F...)
{
    NxNHelper!(F).For!(Args).Result reduce(Args...)(Args args)
    {
        alias NxNHelper!(F).For!(Args) Aux;
        typeof(return) result;
        // Prime the result
        static if (F.length > 1)
        {
            foreach (j, f; F) // for all functions
            {
                // @@@BUG@@@
                auto p = mixin("&result.field!("~ToString!(j)~")");
                *p = args[j];
            }
        }
        else
        {
            result = args[0];
        }
        // Accumulate
        foreach (i, range; args[F.length .. $]) // all inputs
        {
            foreach (it; begin(range) .. end(range)) // current input
            {
                // @@@BUG@@@
                //foreach (j, f; F) // for all functions
                foreach (j, unused; Args[0 .. F.length]) // for all functions
                {
                    static if (F.length > 1)
                    {
                        // @@@BUG@@@
                        auto p = mixin("&result.field!("~ToString!(j)~")");
                    }
                    else
                    {
                        auto p = &result;
                    }
                    *p = Aux.apply!(j, typeof(*p), typeof(*it))(*p, *it);
                }
            }
        }
        return result;
    }
}

unittest
{
    int[] a = [ 3, 4 ];
    auto r = reduce!("a + b")(0, a);
    assert(r == 7);
    r = reduce!(min)(int.max, a);
    assert(r == 3);
    double[] b = [ 100 ];
    auto r1 = reduce!("a + b")(0.0, a, b);
    assert(r1 == 107);    

    a = [ 1, 2, 3, 4, 5 ];
    // Stringize with commas
    string rep = reduce!("a ~ `, ` ~ to!(string)(b)")(cast(string) null, a);
    assert(rep[2 .. $] == "1, 2, 3, 4, 5");
}

// filter
/**
Implements the homonym function present in various programming
languages of functional flavor. The call $(D filter!(fun)(range))
returns a new range only containing elements $(D x) in $(D r) for
which $(D pred(x)) is $(D true).

Example:
----
int[] arr = [ 1, 2, 3, 4, 5 ];
// Sum all elements
auto small = filter!("a < 3")(arr);
assert(small == [ 1, 2 ]);
----

$(DDOC_SECTION_H Multiple ranges:) It is possible to pass any number
of ranges to $(D filter), as in $(D filter!(fun)(range1, range2,
range3)). Then $(D filter) will simply apply its algorithm in
succession to each range, from left to right. The type returned is
that of the first range.

Example:
----
int[] a = [ 3, -2, 400 ];
int[] b = [ 100, -101, 102 ];
auto r = filter!("a > 0")(a, b);
assert(r == [ 3, 400, 100, 102 ]);

// Mixing convertible types is fair game, too
double[] c = [ 2.5, 3.0 ];
auto r1 = filter!("cast(int) a != a")(c, a, b);
assert(r1 == [ 2.5 ]);
----
*/

Ranges[0] filter(alias pred, Ranges...)(Ranges rs)
{
    typeof(return) result;
    // Accumulate
    foreach (i, range; rs[0 .. $]) // all inputs
    {
        foreach (it; begin(range) .. end(range)) // current input
        {
            if (pred(*it)) result ~= *it;
        }
    }
    return result;
}

Ranges[0] filter(string pred, Ranges...)(Ranges rs)
{
    return .filter!(unaryFun!(pred), Ranges)(rs);
}

unittest
{
    int[] a = [ 3, 4 ];
    auto r = filter!("a > 3")(a);
    assert(r == [ 4 ]);

    a = [ 1, 22, 3, 42, 5 ];
    auto under10 = filter!("a < 10")(a);
    assert(under10 == [1, 3, 5]);
}

// inPlace
/**
Similar to $(D map), but it manipulates the passed-in ranges in place
and returns $(D void). The call $(D inPlace!(fun)(range1, range2, ...,
rangeN)) applies $(D fun(x)) left to right for all $(D ref x) in $(D
range1), then all $(D ref x) in $(D range2), ..., all $(D ref x) in
$(D rangeN).

Example:
----
int[] arr1 = [ 1, 2, 3 ];
inPlace!(writeln)(arr1); // print the array
double[] arr2 = [ 4.0, 8.5, 13 ];
inPlace!("++a")(arr1, arr2);
assert(arr1 == [ 2, 3, 4 ]);
assert(arr2 == [ 5.0, 9.5, 14 ]);
----
*/
void inPlace(alias fun, Range, Ranges...)(Range r, Ranges rs)
// @@@BUG@@ This should work:
// void inPlace(alias fun, Ranges...)(Ranges rs)
{
    foreach (j; begin(r) .. end(r)) fun(*j);
    foreach (i, x; rs)
    {
        foreach (j; begin(x) .. end(x)) fun(*j);
    }
}

/// Ditto
void inPlace(string fun, Ranges...)(Ranges rs)
{
    return .inPlace!(unaryFun!(fun, true), Ranges)(rs);
}

unittest
{
    // fill with 42
    int[] a = [ 1, 2 ];
    double[] b =  [ 2, 4 ];
    inPlace!("a = 42")(a);
    assert(a[0] == 42 && a[1] == 42);
    //assert(b[0] == 42 && b[1] == 42);
    
    int[] arr1 = [ 1, 2, 3 ];
    double[] arr2 = [ 4.0, 8.5, 13 ];
    inPlace!("++a")(arr1, arr2);
    assert(arr1 == [ 2, 3, 4 ]);
    assert(arr2 == [ 5.0, 9.5, 14 ]);
}

// move
/**
Moves $(D source) into $(D target) via a destructive
copy. Specifically: $(UL $(LI If $(D hasAliasing!(T)) is true (see
$(XREF traits, hasAliasing)), then the representation of $(D source)
is bitwise copied into $(D target) and then $(D source = T.init) is
evaluated.)  $(LI Otherwise, $(D target = source) is evaluated.)) See
also $(XREF contracts, pointsTo).

Preconditions:
$(D !pointsTo(source, source))
*/
void move(T)(ref T source, ref T target)
{
    assert(!pointsTo(source, source));
    static if (hasAliasing!(T))
    {
        static if (is(T == class))
        {
            target = source;
        }
        else
        {
            memcpy(&target, &source, target.sizeof);
        }
        source = T.init;
    }
    else
    {
        target = source;
    }
}

unittest
{
    Object obj1 = new Object;
    Object obj2 = obj1;
    Object obj3;
    move(obj2, obj3);
    assert(obj2 is null && obj3 is obj1);

    struct S1 { int a = 1, b = 2; }
    S1 s11 = { 10, 11 };
    S1 s12;
    move(s11, s12);
    assert(s11.a == 10 && s11.b == 11 && s12.a == 10 && s12.b == 11);

    struct S2 { int a = 1; int * b; }
    S2 s21 = { 10, new int };
    S2 s22;
    move(s21, s22);
    assert(s21.a == 1 && s21.b == null && s22.a == 10 && s22.b != null);
}

// swap
/**
Swaps $(D lhs) and $(D rhs). See also $(XREF contracts, pointsTo).

Preconditions:

$(D !pointsTo(lhs, lhs) && !pointsTo(lhs, rhs) && !pointsTo(rhs, lhs)
&& !pointsTo(rhs, rhs))
*/
void swap(T)(ref T lhs, ref T rhs)
{
    assert(!pointsTo(lhs, lhs) && !pointsTo(lhs, rhs)
           && !pointsTo(rhs, lhs) && !pointsTo(rhs, rhs));
    auto t = lhs;
    lhs = rhs;
    rhs = t;
}

// overwriteAdjacent
/**
Reduces $(D r) by shifting it to the left until no adjacent elements
$(D a), $(D b) remain in $(D r) such that $(D pred(a, b)). Shifting is
performed by evaluating $(D move(source, target)) as a primitive. The
algorithm is stable and runs in $(BIGOH r.length) time. Returns the
reduced range.

The default $(XREF _algorithm, move) performs a potentially
destructive assignment of $(D source) to $(D target), so the objects
beyond the returned range should be considered "empty". By default $(D
pred) compares for equality, in which case $(D overwriteAdjacent)
collapses adjacent duplicate elements to one (functionality akin to
the $(WEB wikipedia.org/wiki/Uniq, uniq) system utility).

Example:
----
int[] arr = [ 1, 2, 2, 2, 2, 3, 4, 4, 4, 5 ];
auto r = overwriteAdjacent(arr);
assert(r == [ 1, 2, 3, 4, 5 ]);
----
*/
Range overwriteAdjacent(alias pred, alias move, Range)(Range r)
{
    if (isEmpty(r)) return r;
    auto target = begin(r), e = end(r);
    foreach (source; target + 1 .. e)
    {
        if (!pred(*target, *source))
        {
            ++target;
            continue;
        }
        // found an equal *source and *target
        for (;;)
        {
            move(*source, *target);
            ++source;
            if (source == e) break;
            if (!pred(*target, *source)) ++target;
        }
        break;
    }
    return range(begin(r), target + 1);
}

/// Ditto
Range overwriteAdjacent(
    string fun = "a == b",
    alias move = .move,
    Range)(Range r)
{
    return .overwriteAdjacent!(binaryFun!(fun), move, Range)(r);
}

unittest
{
    int[] arr = [ 1, 2, 2, 2, 2, 3, 4, 4, 4, 5 ];
    auto r = overwriteAdjacent(arr);
    assert(r == [ 1, 2, 3, 4, 5 ]);
    assert(arr == [ 1, 2, 3, 4, 5, 3, 4, 4, 4, 5 ]);
    
}

// find
/**
Finds the first occurrence of $(D needle) in $(D haystack) by linear
search and returns an iterator to it.  An optional binary predicate
$(D pred) instructs $(D find) on how to perform the comparison (with
the current collection element in the first position and $(D needle)
in the second position). By default, comparison is for
equality. Performs $(BIGOH haystack.length) evaluations of $(D
pred). See also $(WEB sgi.com/tech/stl/_find.html, STL's _find).

To find the last occurence of $(D needle) in $(D haystack), call $(D
find(retro(haystack), needle)) and compare the result against $(D
rEnd(haystack)). See also $(XREF iterator, retro).

Example:
----
auto a = [ 1, 2, 3 ];
assert(find(a, 5) == end(a));       // not found
assert(find(a, 2) == begin(a) + 1); // found

// Case-insensitive find of a string
string[] s = [ "Hello", "world", "!" ];
assert(find!("toupper(a) == toupper(b)")(s, "hello") == begin(s));
----
*/
Iterator!(Range) find(alias pred, Range, E)(Range haystack, E needle)
{
    //foreach (i; begin(haystack) .. end(haystack))
    for (auto i = begin(haystack); i != end(haystack); ++i)
    {
        if (pred(*i, needle)) return i;
    }
    return end(haystack);
}

/// Ditto
Iterator!(Range) find(string pred = "a == b", Range, E)(
    Range haystack, E needle)
{
    return .find!(binaryFun!(pred), Range, E)(haystack, needle);
}

unittest
{
    int[] a = [ 1, 2, 3 ];
    assert(find(a, 5) == end(a));
    assert(find(a, 2) == begin(a) + 1);

    foreach (T; TypeTuple!(int, double))
    {
        auto b = rndstuff!(T)();
        if (!b.length) continue;
        b[$ / 2] = 200;
        b[$ / 4] = 200;
        assert(find(b, 200) == begin(b) + b.length / 4);
    }

// Case-insensitive find of a string
    string[] s = [ "Hello", "world", "!" ];
    assert(find!("toupper(a) == toupper(b)")(s, "hello") == begin(s));
}

unittest
{
    int[] a = [ 1, 2, 3, 2, 6 ];
    assert(find(retro(a), 5) == rEnd(a));
    assert(find(retro(a), 2) == rBegin(a) + 1);

    foreach (T; TypeTuple!(int, double))
    {
        auto b = rndstuff!(T)();
        if (!b.length) continue;
        b[$ / 2] = 200;
        b[$ / 4] = 200;
        assert(find(retro(b), 200) == rBegin(b) + (b.length - 1) / 2);
    }
}

/**
Finds the first element in a range satisfying the unary predicate $(D
pred). Performs $(BIGOH haystack.length) evaluations of $(D pred). See
also $(WEB sgi.com/tech/stl/find_if.html, STL's find_if).

To find the last element of $(D haystack) satisfying $(D pred), call
$(D find!(pred)(retro(haystack))) and compare the result against $(D
rEnd(haystack)). See also $(XREF iterator, retro).

Example:
----
auto arr = [ 1, 2, 3 ];
assert(find!("a > 2")(arr) == end(arr) - 1);

// with predicate alias
bool pred(int x) { return x + 1 > 1.5; }
assert(find!(pred)(arr) == begin(arr));
----
*/
Iterator!(Range) find(alias pred, Range)(Range haystack)
{
    foreach (i; begin(haystack) .. end(haystack))
    {
        if (pred(*i)) return i;
    }
    return end(haystack);
}

/// Ditto
Iterator!(Range) find(string pred, Range)(Range haystack)
{
    return find!(unaryFun!(pred), Range)(haystack);
}

unittest
{
    auto a = [ 1, 2, 3 ];
    assert(find!("a > 2")(a) == end(a) - 1);
    bool pred(int x) { return x + 1 > 1.5; }
    assert(find!(pred)(a) == begin(a));
}

// findRange
/**
Finds the first occurrence of $(D subseq) in $(D seq) by repeated
linear searches.  Performs $(BIGOH seq.length * subseq.length)
evaluations of $(D pred), which makes it unrecommended for very large
ranges, for which $(XREF algorithm, findBoyerMoore) may be more
appropriate. See also $(WEB sgi.com/tech/stl/search.html, STL's
search).

Example:
----
int[] a = [ -1, 0, 1, 2, 3, 4, 5 ];
int[] b = [ 1, 2, 3 ];
assert(findRange(a, b) == begin(a) + 2);
assert(findRange(b, a) == end(b));
----
*/
Iterator!(Range1) findRange(alias pred, Range1, Range2)(
    Range1 seq, Range2 subseq)
{
    auto e1 = end(seq);
    if (seq.length < subseq.length) return e1;
    auto e11 = e1 - subseq.length + 1;
    auto e2 = end(subseq);
    foreach (i; begin(seq) .. e11)
    {
        auto m = mismatch!(pred)(range(i, e1), subseq);
        if (m._1 == e2) return i;
    }
    return e1;
}

/// Ditto
Iterator!(Range1) findRange(
    string pred = q{a == b}, Range1, Range2)(Range1 seq, Range2 subseq)
{
    return .findRange!(binaryFun!(pred), Range1, Range2)(seq, subseq);
}

unittest
{
    int[] a = [ -1, 0, 1, 2, 3, 4, 5 ];
    int[] b = [ 1, 2, 3 ];
    assert(findRange(a, b) == begin(a) + 2);
    assert(findRange(b, a) == end(b));
}

// findBoyerMoore
private struct BoyerMooreFinder(alias pred, Range)
{
private:
    size_t skip[];
    int[typeof(Range[0])] occ;
    Range needle;
  
    int occurrence(char c)
    {
        auto p = c in occ;
        return p ? *p : -1;
    }

/* This helper function checks, whether the last "portion" bytes
 * of "needle" (which is "nlen" bytes long) exist within the "needle"
 * at offset "offset" (counted from the end of the string),
 * and whether the character preceding "offset" is not a match.
 * Notice that the range being checked may reach beyond the
 * beginning of the string. Such range is ignored.
 */
    static bool needlematch(R)(R needle,
                              size_t portion, size_t offset)
    {
        int virtual_begin = needle.length - offset - portion;
        int ignore = 0;
        if (virtual_begin < 0) { 
            ignore = -virtual_begin;
            virtual_begin = 0; 
        }
        if (virtual_begin > 0 
            && needle[virtual_begin - 1] == needle[$ - portion - 1])
            return 0;
        
        invariant delta = portion - ignore;
        return equal(range(end(needle) - delta, end(needle)),
                     range(begin(needle) + virtual_begin,
                           begin(needle) + virtual_begin + delta));
    }

public:
    static BoyerMooreFinder opCall(Range needle)
    {
        BoyerMooreFinder result;
        if (!needle.length) return result;
        result.needle = needle;
        /* Populate table with the analysis of the needle */
        /* But ignoring the last letter */
        foreach (i, n ; needle[0 .. $ - 1])
        {
            result.occ[n] = i;
        }
        /* Preprocess #2: init skip[] */  
        /* Note: This step could be made a lot faster.
         * A simple implementation is shown here. */
        result.skip = new size_t[needle.length];
        foreach (a; 0 .. needle.length)
        {
            size_t value = 0;
            while (value < needle.length 
                   && !needlematch(needle, a, value))
            {
                ++value;
            }
            result.skip[needle.length - a - 1] = value;
        }
        return result;
    }

    Iterator!(Range) inspect(Range haystack)
    {
        if (!needle.length) return begin(haystack);
        if (needle.length > haystack.length) return end(haystack);
        /* Search: */
        auto limit = haystack.length - needle.length;
        for (size_t hpos = 0; hpos <= limit; )
        {
            size_t npos = needle.length - 1;
            while (pred(needle[npos], haystack[npos+hpos]))
            {
                if (npos == 0) return begin(haystack) + hpos;
                --npos;
            }
            hpos += max(skip[npos], npos - occurrence(haystack[npos+hpos]));
        }
        return end(haystack);
    }

    size_t length()
    {
        return needle.length;
    }
}

/**
Finds the first occurrence of $(D subseq) in $(D seq) by using the
$(WEB www-igm.univ-mlv.fr/~lecroq/string/node14.html, Boyer-Moore
algorithm).  The algorithm has an upfront cost but scales sublinearly,
so it is most suitable for large sequences. Performs $(BIGOH
seq.length) evaluations of $(D pred) in the worst case and $(BIGOH
seq.length / subseq.length) evaluations in the best case.

Example:
----
int[] a = [ -1, 0, 1, 2, 3, 4, 5 ];
int[] b = [ 1, 2, 3 ];
assert(findBoyerMoore(a, b) == begin(a) + 2);
assert(findBoyerMoore(b, a) == end(b));
----

BUGS:

Should cache the scaffolding built for the last $(D subseq) in
thread-safe storage so it is not rebuilt repeatedly.
*/
Iterator!(Range) findBoyerMoore(alias pred, Range)(Range seq,
                                                   Range subseq)
{
    return BoyerMooreFinder!(pred, Range)(subseq).inspect(seq);
}

/// Ditto
Iterator!(Range) findBoyerMoore(string pred = q{a == b}, Range)(
    Range seq, Range subseq)
{
    return .findBoyerMoore!(binaryFun!(pred), Range)(seq, subseq);
}

unittest
{
    debug(string) writefln("Boyer-Moore implementation unittest\n");
    string h = "/homes/aalexand/d/dmd/bin/../lib/libphobos.a(dmain2.o)"
        "(.gnu.linkonce.tmain+0x74): In function `main' undefined reference"
        " to `_Dmain':";
    string[] ns = ["libphobos", "function", " undefined", "`", ":"];
    foreach (n ; ns) {
        auto p = findBoyerMoore(h, n);
        assert(p != end(h) && range(p, p + n.length) == n);
    }

    int[] a = [ -1, 0, 1, 2, 3, 4, 5 ];
    int[] b = [ 1, 2, 3 ];
    assert(findBoyerMoore(a, b) == begin(a) + 2);
    assert(findBoyerMoore(b, a) == end(b));
}

// findAdjacent
/**
Finds the first two adjacent elements $(D a), $(D b) in the range $(D
r) that satisfy $(D pred(a, b)). Performs $(BIGOH r.length)
evaluations of $(D pred). See also $(WEB
sgi.com/tech/stl/adjacent_find.html, STL's adjacent_find).

Example:
----
int[] a = [ 11, 10, 10, 9, 8, 8, 7, 8, 9 ];
auto p = findAdjacent(a);
assert(p == begin(a) + 1);
p = findAdjacent!("a < b")(a);
assert(p == begin(a) + 6);
----
*/
Iterator!(Range) findAdjacent(alias pred, Range)(Range r)
{
    auto first = begin(r), last = end(r);
    auto next = first;
    if (first != last)
    {
        for (++next; next != last; ++first, ++next)
            if (pred(*first, *next)) return first;
    }
    return last;
}

/// Ditto
Iterator!(Range) findAdjacent(string pred = q{a == b}, Range)(Range r)
{
    return .findAdjacent!(binaryFun!(pred), Range)(r);
}

unittest
{
    int[] a = [ 11, 10, 10, 9, 8, 8, 7, 8, 9 ];
    auto p = findAdjacent(a);
    assert(p == begin(a) + 1);
    p = findAdjacent!("a < b")(a);
    assert(p == begin(a) + 6);
}

// findAmong
/**
Finds the first element in $(D seq) that compares equal (according to
$(D pred)) with some element in $(D choices). Choices are sought by
linear search. Performs $(BIGOH seq.length * choices.length)
evaluations of $(D pred). See also $(WEB
sgi.com/tech/stl/find_first_of.html, STL's find_first_of).

Example:
----
int[] a = [ -1, 0, 1, 2, 3, 4, 5 ];
int[] b = [ 3, 1, 2 ];
assert(findAmong(a, b) == begin(a) + 2);
assert(findAmong(b, a) == begin(b));
----
*/
Iterator!(Range1) findAmong(alias pred, Range1, Range2)(
    Range1 seq, Range2 choices)
{
    foreach (i, e; seq)
    {
        if (find!(pred)(choices, e) != end(choices)) return begin(seq) + i;
    }
    return end(seq);
}

/// Ditto
Iterator!(Range1) findAmong(
    string pred = q{a == b}, Range1, Range2)(Range1 seq, Range2 choices)
{
    return .findAmong!(binaryFun!(pred), Range1, Range2)(seq, choices);
}

unittest
{
    int[] a = [ -1, 0, 2, 1, 2, 3, 4, 5 ];
    int[] b = [ 1, 2, 3 ];
    assert(findAmong(a, b) == begin(a) + 2);
    assert(findAmong(b, [ 4, 6, 7 ]) == end(b));
}

// findAmongSorted
/**
Finds the first element $(D x) in $(D seq) that compares equal with
some element $(D y) in $(D choices) (meaning $(D !less(x, y) &&
!less(y, x))). The $(D choices) range is sought by binary
search. Consequently $(D choices) is assumed to be sorted according to
$(D pred), which by default is $(D "a < b"). Performs $(BIGOH
seq.length * log(choices.length)) evaluations of $(D less).

To find the last element of $(D seq) instead of the first, call $(D
findAmongSorted(retro(seq), choices)) and compare the result against
$(D rEnd(seq)). See also $(XREF iterator, retro).

Example:
----
int[] a = [ -1, 0, 1, 2, 3, 4, 5 ];
int[] b = [ 1, 2, 3 ];
assert(findAmongSorted(a, b) == begin(a) + 2);
assert(findAmongSorted(b, a) == end(b));
----
*/
Iterator!(Range1) findAmongSorted(alias less, Range1, Range2)(
    Range1 seq, in Range2 choices)
{
    assert(isSorted!(less)(choices));
    foreach (i, e; seq)
    {
        if (canFindSorted!(less)(choices, e)) return begin(seq) + i;
    }
    return end(seq);
}

/// Ditto
Iterator!(Range1) findAmongSorted(
    string less = q{a < b}, Range1, Range2)(Range1 seq, in Range2 subseq)
{
    return .findAmongSorted!(binaryFun!(less), Range1, Range2)(seq, subseq);
}

unittest
{
    int[] a = [ -1, 0, 2, 1, 2, 3, 4, 5 ];
    int[] b = [ 1, 2, 3 ];
    assert(findAmongSorted(a, b) == begin(a) + 2);
    assert(findAmongSorted(b, [ 4, 6, 7 ]) == end(b));
}

// canFind
/**
Convenience functions returning $(D true) if and only if the
corresponding $(D find*) functions return an iterator different from
$(D end(r)). They are handy in the numerous situations when the
success of the $(D find*) functions is queried but the actual position
found is unimportant.

Example:
----
int[] a = [ -1, 0, 1, 2, 3, 4, 5 ];
assert(canFind(a, 4));
assert(!canFind(a, 10));
assert(canFind!("a - 1 < b")(a, 4));
assert(!canFind!("a > 5")(a));
----
*/
bool canFind(alias pred, Range, E)(Range haystack, E needle)
{
    return find!(pred)(haystack, needle) != end(haystack);
}

/// Ditto
bool canFind(string pred = q{a == b}, Range, E)(Range haystack, E needle)
{
    return find!(pred)(haystack, needle) != end(haystack);
}

/// Ditto
bool canFind(alias pred, Range, E)(Range haystack)
{
    return find!(pred)(haystack) != end(haystack);
}

/// Ditto
bool canFind(string pred, Range, E)(Range haystack)
{
    return find!(pred)(haystack) != end(haystack);
}

/// Ditto
bool canFindAmong(alias pred, Range1, Range2)(Range seq, Range2 choices)
{
    return findAmong!(pred)(seq, choices) != end(seq);
}

/// Ditto
bool canFindAmong(string pred, Range1, Range2)(Range seq, Range2 choices)
{
    return findAmong!(pred)(seq, choices) != end(seq);
}

/// Ditto
bool canFindAmongSorted(alias pred, Range1, Range2)(Range seq, Range2 choices)
{
    return canFindAmongSorted!(pred)(seq, choices) != end(seq);
}

/// Ditto
bool canFindAmongSorted(string pred, Range1, Range2)(
    Range seq, Range2 choices)
{
    return canFindAmongSorted!(pred)(seq, choices) != end(seq);
}

// count
/**
Counts the number of elements $(D x) in $(D r) for which $(D pred(x,
value)) is $(D true). $(D pred) defaults to equality. Performs $(BIGOH
r.length) evaluations of $(D pred).

Example:
----
int[] a = [ 1, 2, 4, 3, 2, 5, 3, 2, 4 ];
assert(count(a, 2) == 3);
assert(count!("a > b")(a, 2) == 5);
----
*/

size_t count(alias pred, Range, E)(Range r, E value)
{
    bool pred2(typeof(*begin(r)) a) { return pred(a, value); }
    return count!(pred2)(r);
}

/// Ditto
size_t count(string pred = "a == b", Range, E)(
    Range r, E value)
{
    return count!(binaryFun!(pred), Range, E)(r, value);
}

unittest
{
    int[] a = [ 1, 2, 4, 3, 2, 5, 3, 2, 4 ];
    assert(count(a, 2) == 3);
    assert(count!("a > b")(a, 2) == 5);
}

/**
Counts the number of elements $(D x) in $(D r) for which $(D pred(x))
is $(D true). Performs $(BIGOH r.length) evaluations of $(D pred).

Example:
----
int[] a = [ 1, 2, 4, 3, 2, 5, 3, 2, 4 ];
assert(count!("a > 1")(a) == 8);
----
*/
size_t count(alias pred, Range)(Range r)
{
    size_t result;
    foreach (i; begin(r) .. end(r))
    {
        if (pred(*i)) ++result;
    }
    return result;
}

/// Ditto
size_t count(string pred, Range)(Range r)
{
    return count!(unaryFun!(pred), Range)(r);
}

unittest
{
    int[] a = [ 1, 2, 4, 3, 2, 5, 3, 2, 4 ];
    assert(count!("a == 3")(a) == 2);
}

// equal
/**
Returns $(D true) if and only if the two ranges compare equal element
for element, according to binary predicate $(D pred). The ranges may
have different element types, as long as $(D pred(a, b)) evaluates to
$(D bool) for $(D a) in $(D r1) and $(D b) in $(D r2). Performs
$(BIGOH min(r1.length, r2.length)) evaluations of $(D pred). See also
$(WEB sgi.com/tech/stl/_equal.html, STL's equal).

Example:
----
int[] a = [ 1, 2, 4, 3 ];
assert(!equal(a, a[1..$]));
assert(equal(a, a));

// different types
double[] b = [ 1., 2, 4, 3];
assert(!equal(a, b[1..$]));
assert(equal(a, b));

// predicated: ensure that two vectors are approximately equal
double[] c = [ 1.005, 2, 4, 3];
assert(equal!(approxEqual)(b, c));
----
*/
bool equal(alias pred, Range1, Range2)(Range1 r1, Range2 r2)
{
    if (r1.length != r2.length) return false;
    auto result = mismatch!(pred)(r1, r2);
    return result._0 == end(r1) && result._1 == end(r2);
}

/// Ditto
bool equal(string pred = q{a == b}, Range1, Range2)(Range1 r1, Range2 r2)
{
    return equal!(binaryFun!(pred), Range1, Range2)(r1, r2);
}

unittest
{
    int[] a = [ 1, 2, 4, 3];
    assert(!equal(a, a[1..$]));
    assert(equal(a, a));
    // test with different types
    double[] b = [ 1., 2, 4, 3];
    assert(!equal(a, b[1..$]));
    assert(equal(a, b));

    // predicated
    double[] c = [ 1.005, 2, 4, 3];
    assert(equal!(approxEqual)(b, c));
}

// overlap
/**
Returns the overlapping range, if any, of two ranges. Unlike $(D
equal), $(D overlap) only compares the iterators in the ranges, not
the values referred by them. If $(D r1) and $(D r2) have an
overlapping range, returns that range. Otherwise, returns an empty
range. Performs $(BIGOH min(r1.length, r2.length)) iterator increment
operations and comparisons if the ranges are forward, and $(BIGOH 1)
operations if the ranges have random access.

Example:
----
int[] a = [ 10, 11, 12, 13, 14 ];
int[] b = a[1 .. 3];
assert(overlap(a, b) == [ 11, 12 ]);
b = b.dup;
// overlap disappears even though the content is the same
assert(isEmpty(overlap(a, b)));
----
*/
Range overlap(Range)(Range r1, Range r2)
{
    auto b = max(begin(r1), begin(r2));
    auto e = min(end(r1), end(r2));
    return range(b, max(b, e));
}

unittest
{
    int[] a = [ 10, 11, 12, 13, 14 ];
    int[] b = a[1 .. 3];
    a[1] = 100;
    assert(overlap(a, b) == [ 100, 12 ]);
}

// MinType
template MinType(T...)
{
    static assert(T.length >= 2);
    static if (T.length == 2)
    {
        static if (!is(typeof(T[0].min)))
            alias CommonType!(T[0 .. 2]) MinType;
        else static if (mostNegative!(T[1]) < mostNegative!(T[0]))
            alias T[1] MinType;
        else static if (mostNegative!(T[1]) > mostNegative!(T[0]))
            alias T[0] MinType;
        else static if (T[1].max < T[0].max)
            alias T[1] MinType;
        else
            alias T[0] MinType;
    }
    else
    {
        alias MinType!(MinType!(T[0 .. 2]), T[2 .. $]) MinType;
    }
}

// min
/**
Returns the minimum of the passed-in values. The type of the result is
computed by using $(XREF traits, CommonType).
*/
MinType!(T1, T2, T) min(T1, T2, T...)(T1 a, T2 b, T xs)
{
    static if (T.length == 0)
    {
        static if (isIntegral!(T1) && isIntegral!(T2)
                   && (mostNegative!(T1) < 0) != (mostNegative!(T2) < 0))
            static if (mostNegative!(T1) < 0)
                invariant chooseB = b < a && a > 0;
            else
                invariant chooseB = b < a || b < 0;
        else
                invariant chooseB = b < a;
        return cast(typeof(return)) (chooseB ? b : a);
    }
    else
    {
        return min(min(a, b), xs);
    }
}

unittest
{
    int a = 5;
    short b = 6;
    double c = 2;
    auto d = min(a, b);
    assert(is(typeof(d) == int));
    assert(d == 5);
    auto e = min(a, b, c);
    assert(is(typeof(e) == double));
    assert(e == 2);
    // mixed signedness test
    a = -10;
    uint f = 10;
    static assert(is(typeof(min(a, f)) == int));
    assert(min(a, f) == -10);
}

// MaxType
template MaxType(T...)
{
    static assert(T.length >= 2);
    static if (T.length == 2)
    {
        static if (!is(typeof(T[0].min)))
            alias CommonType!(T[0 .. 2]) MaxType;
        else static if (T[1].max > T[0].max)
            alias T[1] MaxType;
        else 
            alias T[0] MaxType;
    }
    else
    {
        alias MaxType!(MaxType!(T[0], T[1]), T[2 .. $]) MaxType;
    }
}

// max
/**
Returns the maximum of the passed-in values. The type of the result is
computed by using $(XREF traits, CommonType).

Example:
----
int a = 5;
short b = 6;
double c = 2;
auto d = max(a, b);
assert(is(typeof(d) == int));
assert(d == 6);
auto e = min(a, b, c);
assert(is(typeof(e) == double));
assert(e == 2);
----
*/
MaxType!(T1, T2, T) max(T1, T2, T...)(T1 a, T2 b, T xs)
{
    static if (T.length == 0)
    {
        static if (isIntegral!(T1) && isIntegral!(T2)
                   && (mostNegative!(T1) < 0) != (mostNegative!(T2) < 0))
            static if (mostNegative!(T1) < 0)
                invariant chooseB = b > a || a < 0;
            else
                invariant chooseB = b > a && b > 0;
        else
            invariant chooseB = b > a;
        return cast(typeof(return)) (chooseB ? b : a);
    }
    else
    {
        return max(max(a, b), xs);
    }
}

unittest
{
    int a = 5;
    short b = 6;
    double c = 2;
    auto d = max(a, b);
    assert(is(typeof(d) == int));
    assert(d == 6);
    auto e = max(a, b, c);
    assert(is(typeof(e) == double));
    assert(e == 6);
    // mixed sign
    a = -5;
    uint f = 5;
    static assert(is(typeof(max(a, f)) == uint));
    assert(max(a, f) == 5);
}

// mismatch
/**
Sequentially compares elements in $(D r1) and $(D r2) in lockstep, and
stops at the first mismatch (according to $(D pred), by default
equality). Returns a tuple with the iterators that refer to the two
mismatched values. Performs $(BIGOH min(r1.length, r2.length))
evaluations of $(D pred). See also $(WEB
sgi.com/tech/stl/_mismatch.html, STL's mismatch).

Example:
----
int[]    x = [ 1,  5, 2, 7,   4, 3 ];
double[] y = [ 1., 5, 2, 7.3, 4, 8 ];
auto m = mismatch(x, y);
assert(m._0 == begin(x) + 3);
assert(m._1 == begin(y) + 3);
----
*/

Tuple!(Iterator!(Range1), Iterator!(Range2))
mismatch(alias pred, Range1, Range2)(Range1 r1, Range2 r2)
{
    auto i1 = begin(r1), i2 = begin(r2), e1 = end(r1), e2 = end(r2);
    for (; i1 != e1 && i2 != e2; ++i1, ++i2)
    {
        if (!pred(*i1, *i2)) break;
    }
    return tuple(i1, i2);
}

/// Ditto
Tuple!(Iterator!(Range1), Iterator!(Range2))
mismatch(string pred = q{a == b}, Range1, Range2)(Range1 r1, Range2 r2)
{
    return .mismatch!(binaryFun!(pred), Range1, Range2)(r1, r2);
}

unittest
{
    // doc example
    int[]    x = [ 1,  5, 2, 7,   4, 3 ];
    double[] y = [ 1., 5, 2, 7.3, 4, 8 ];
    auto m = mismatch(x, y);
    assert(m._0 == begin(x) + 3);
    assert(m._1 == begin(y) + 3);

    int[] a = [ 1, 2, 3 ];
    int[] b = [ 1, 2, 4, 5 ];    
    auto mm = mismatch(a, b);
    assert(mm._0 == begin(a) + 2);
    assert(mm._1 == begin(b) + 2);
}

// levenshteinDistance
/**
Encodes $(WEB realityinteractive.com/rgrzywinski/archives/000249.html,
edit operations) necessary to transform one sequence into
another. Given sequences $(D s) (source) and $(D t) (target), a
sequence of $(D EditOp) encodes the steps that need to be taken to
convert $(D s) into $(D t). For example, if $(D s = "cat") and $(D
"cars"), the minimal sequence that transforms $(D s) into $(D t) is:
skip two characters, replace 't' with 'r', and insert an 's'. Working
with edit operations is useful in applications such as spell-checkers
(to find the closest word to a given misspelled word), approximate
searches, diff-style programs that compute the difference between
files, efficient encoding of patches, DNA sequence analysis, and
plagiarism detection.
*/

enum EditOp : char
{
    /** Current items are equal; no editing is necessary. */
    none = 'n',
    /** Substitute current item in target with current item in source. */
    substitute = 's',
    /** Insert current item from the source into the target. */
    insert = 'i',
    /** Remove current item from the target. */
    remove = 'r'
}

struct Levenshtein(Range, alias equals, CostType = size_t)
{
    void deletionIncrement(CostType n)
    {
        _deletionIncrement = n;
        InitMatrix();
    }
    
    void insertionIncrement(CostType n)
    {
        _insertionIncrement = n;
        InitMatrix();
    }
    
    CostType distance(Range s, Range t)
    {
        AllocMatrix(s.length + 1, t.length + 1);
        foreach (i; 1 .. rows)
        {
            foreach (j; 1 .. cols)
            {
                auto cSub = _matrix[i - 1][j - 1] 
                    + (equals(s[i - 1], t[j - 1]) ? 0 : _substitutionIncrement);
                auto cIns = _matrix[i][j - 1] + _insertionIncrement;
                auto cDel = _matrix[i - 1][j] + _deletionIncrement;
                switch (min_index(cSub, cIns, cDel)) {
                case 0:
                    _matrix[i][j] = cSub;
                    break;
                case 1:
                    _matrix[i][j] = cIns;
                    break;
                default:
                    _matrix[i][j] = cDel;
                    break;
                }
            }
        }
        return _matrix[s.length][t.length];
    }
  
    EditOp[] path(Range s, Range t)
    {
        distance(s, t);
        return path();
    }

    EditOp[] path()
    {
        EditOp[] result;
        uint i = rows - 1, j = cols - 1;
        // restore the path
        while (i || j) {
            auto cIns = j == 0 ? CostType.max : _matrix[i][j - 1];
            auto cDel = i == 0 ? CostType.max : _matrix[i - 1][j];
            auto cSub = i == 0 || j == 0 
                ? CostType.max 
                : _matrix[i - 1][j - 1];
            switch (min_index(cSub, cIns, cDel)) {
            case 0:
                result ~= _matrix[i - 1][j - 1] == _matrix[i][j]
                    ? EditOp.none
                    : EditOp.substitute;
                --i;
                --j;
                break;
            case 1:
                result ~= EditOp.insert;
                --j;
                break;
            default:
                result ~= EditOp.remove;
                --i;
                break;
            }
        }
        reverse(result);
        return result;
    }
    
private:
    CostType _deletionIncrement = 1,
        _insertionIncrement = 1,
        _substitutionIncrement = 1;
    CostType[][] _matrix;
    uint rows, cols;

    void AllocMatrix(uint r, uint c) {
        rows = r;
        cols = c;
        if (!_matrix || _matrix.length < r || _matrix[0].length < c) {
            delete _matrix;
            _matrix = new CostType[][](r, c);
            InitMatrix();
        }
    }

    void InitMatrix() {
        foreach (i, row; _matrix) {
            row[0] = i * _deletionIncrement;
        }
        if (!_matrix) return;
        for (auto i = 0u; i != _matrix[0].length; ++i) {
            _matrix[0][i] = i * _insertionIncrement;
        }
    }

    static uint min_index(CostType i0, CostType i1, CostType i2)
    {
        if (i0 <= i1)
        {
            return i0 <= i2 ? 0 : 2;
        }
        else
        {
            return i1 <= i2 ? 1 : 2;
        }
    }
}

/**
Returns the $(WEB wikipedia.org/wiki/Levenshtein_distance, Levenshtein
distance) between $(D s) and $(D t). The Levenshtein distance computes
the minimal amount of edit operations necessary to transform $(D s)
into $(D t).  Performs $(BIGOH s.length * t.length) evaluations of $(D
equals) and occupies $(BIGOH s.length * t.length) storage.

Example:
----
assert(levenshteinDistance("cat", "rat") == 1);
assert(levenshteinDistance("parks", "spark") == 2);
assert(levenshteinDistance("kitten", "sitting") == 3);
// ignore case
assert(levenshteinDistance!("toupper(a) == toupper(b)")
    ("parks", "SPARK") == 2);
----
*/
size_t levenshteinDistance(alias equals, Range1, Range2)(Range1 s, Range2 t)
{
    Levenshtein!(typeof(range(begin(s), end(s))), equals, uint) lev;
    return lev.distance(s, t);
}

/// Ditto
size_t levenshteinDistance(string equals = "a == b", Range1, Range2)(
    Range1 s, Range2 t)
{
    return levenshteinDistance!(binaryFun!(equals), Range1, Range2)(s, t);
}

/**
Returns the Levenshtein distance and the edit path between $(D s) and
$(D t).

Example:
---
string a = "Saturday", b = "Sunday";
auto p = levenshteinDistanceAndPath(a, b);
assert(p._0, 3);
assert(equals(p._1, "nrrnsnnn"));
---
*/
Tuple!(size_t, EditOp[])
levenshteinDistanceAndPath(alias equals, Range1, Range2)(Range1 s, Range2 t)
{
    Levenshtein!(Range, equals) lev;
    auto d = lev.distance(s, t);
    return tuple(d, lev.path);
}

/// Ditto
Tuple!(size_t, EditOp[])
levenshteinDistanceAndPath(string equals = "a == b",
                           Range1, Range2)(Range1 s, Range2 t)
{
    return levenshteinDistanceAndPath!(binaryFun!(equals), Range1, Range2)(
        s, t);
}

unittest
{
    assert(levenshteinDistance("a", "a") == 0);
    assert(levenshteinDistance("a", "b") == 1);
    assert(levenshteinDistance("aa", "ab") == 1);
    assert(levenshteinDistance("aa", "abc") == 2);
    assert(levenshteinDistance("Saturday", "Sunday") == 3);
    assert(levenshteinDistance("kitten", "sitting") == 3);
    //lev.deletionIncrement = 2;
    //lev.insertionIncrement = 100;
    string a = "Saturday", b = "Sunday";
    // @@@BUG@@@
    //auto p = levenshteinDistanceAndPath(a, b);
    //writefln(p);
    //assert(cast(string) p._1 == "nrrnsnnn", cast(string) p);
}

// copy
/**
Copies the content of $(D source) into $(D target) and returns the
remaining (unfilled) part of $(D target). See also $(WEB
sgi.com/tech/stl/_copy.html, STL's copy). If a behavior similar to
$(WEB sgi.com/tech/stl/copy_backward.html, STL's copy_backward) is
needed, use $(D copy(retro(source), retro(target))). See also $(XREF
iterator, retro).

Example:
----
int[] a = [ 1, 5 ];
int[] b = [ 9, 8 ];
int[] c = new int[a.length + b.length + 10];
auto d = copy(b, copy(a, c));
assert(c[0 .. a.length + b.length] == a ~ b);
assert(d.length == 10);
----

As long as the target range elements support assignment from source
range elements, different types of ranges are accepted.

Example:
----
float[] a = [ 1.0f, 5 ];
double[] b = new double[a.length];
auto d = copy(a, b);
----
*/

Range2 copy(Range1, Range2)(Range1 source, Range2 target)
{
    auto t = begin(target), te = end(target);
    foreach (s; begin(source) .. end(source))
    {
        if (t == te) enforce(false,
                             "copy: insufficient space in target range");
        *t = *s;
        ++t;
    }
    return range(t, te);
}

unittest
{
    int[] a = [ 1, 5 ];
    int[] b = [ 9, 8 ];
    int[] c = new int[a.length + b.length + 10];
    auto d = copy(b, copy(a, c));
    assert(c[0 .. a.length + b.length] == a ~ b);
    assert(d.length == 10);
}

// copyIf
/**
Copies in increasing order the elements $(D x) of $(D source)
satisfying $(D pred(x)) into $(D target) and returns the remaining
(unfilled) part of $(D target). See also $(WEB
sgi.com/tech/stl/copy_if.html, STL's copy_if).

Example:
----
int[] a = [ 1, 5, 8, 9, 10, 1, 2, 0 ];
auto b = new int[a.length];
auto c = copyIf!("(a & 1) == 1")(a, b);
assert(b[0 .. $ - c.length] == [ 1, 5, 9, 1 ]);
----

As long as the target range elements support assignment from source
range elements, different types of ranges are accepted.

Example:
----
float[] a = [ 1.0f, 5, -3, -5, 0, 4, -3 ];
double[] b = new double[a.length];
auto d = copyIf!("a > 0")(a, b);
assert(a == [ 1.0f, 5, 0, 4 ]);
----
*/

Range2 copyIf(alias pred, Range1, Range2)(Range1 source, Range2 target)
{
    //static assert(false, "Not yet implemented due to bugs in the compiler");
    auto t = begin(target), te = end(target);
    foreach (s; begin(source) .. end(source))
    {
        if (!pred(*s)) continue;
        if (t == te) enforce(false,
                             "copyIf: insufficient space in target range");
        *t = *s;
        ++t;
    }
    return range(t, te);
}

Range2 copyIf(string pred, Range1, Range2)(Range1 source, Range2 target)
{
    return .copyIf!(unaryFun!(pred), Range1, Range2)(source, target);
}

unittest
{
    int[] a = [ 1, 5 ];
    int[] b = [ 9, 8 ];
    auto e = copyIf!("a > 1")(a, b);
    assert(b[0] == 5 && e.length == 1);
}

// iterSwap
/**
Swaps $(D *lhs) and $(D *rhs).

Preconditions:
Same as for $(D swap(*lhs, *rhs)).
*/
void iterSwap(It)(It lhs, It rhs)
{
    assert(!pointsTo(*lhs, *lhs), It.stringof);
    swap(*lhs, *rhs);
}

// swapRanges
/**
Swaps all elements of $(D r1) with successive elements in $(D r2)
using $(D iterSwap) as a primitive. $(D r1) must contain less or the
same number of elements as $(D r2); an exception will be thrown
otherwise. Returns the tail portion of $(D r2) that was not swapped.

Example:
----
int[] a = [ 100, 101, 102, 103 ];
int[] b = [ 0, 1, 2, 3 ];
auto c = swapRanges(a[1 .. 2], b[2 .. 3]);
assert(!c.length);
assert(a == [ 100, 2, 3, 103 ]);
assert(b == [ 0, 1, 101, 102 ]);
----
*/
Range2 swapRanges(alias iterSwap = .iterSwap, Range1, Range2)(T r1, T r2)
{
    enforce(r1.length <= r2.length,
        "swapRanges: too short range in the second position");
    auto t = begin(r2);
    foreach (s; begin(r1) .. end(r1))
    {
        iterSwap(t, s);
        ++t;
    }
    return range(t, end(r2));
}

// reverse
/**
Reverses $(D r) in-place.  Performs $(D r.length) evaluations of $(D
iterSwap). See also $(WEB sgi.com/tech/stl/_reverse.html, STL's
reverse).

Example:
----
int[] arr = [ 1, 2, 3 ];
reverse(arr);
assert(arr == [ 3, 2, 1 ]);
----
*/
void reverse(alias iterSwap = .iterSwap, Range)(Range r)
{
    auto b = begin(r), e = end(r);
    assert(b <= e);
    for (; b != e; ++b)
    {
        --e;
        if (b == e) break;
        iterSwap(b, e);
    }
}

unittest
{
    int[] range = null;
    reverse(range);
    range = [ 1 ];
    reverse(range);
    assert(range == [1]);
    range = [1, 2];
    reverse(range);
    assert(range == [2, 1]);
    range = [1, 2, 3];
    reverse(range);
    assert(range == [3, 2, 1]);
}

// rotate
/**
Rotates the range $(D r = [first, last$(RPAREN)) such that the slice
$(D [middle, last$(RPAREN)) gets moved in front of the slice $(D
[first, middle$(RPAREN)). Performs $(BIGOH r.length) evaluations of
$(D iterSwap). See also $(WEB sgi.com/tech/stl/_rotate.html, STL's
rotate).

Preconditions:

$(D first <= middle && middle <= last);

Returns:

The position in which $(D first) has been rotated.

Example:

----
auto arr = [4, 5, 6, 7, 1, 2, 3];
auto p = rotate(arr, begin(arr) + 4);
assert(p - begin(arr) == 3);
assert(arr == [ 1, 2, 3, 4, 5, 6, 7 ]);
----
*/
It rotate(alias iterSwap = .iterSwap, Range, It)(Range r, It middle)
{
    auto first = begin(r), last = end(r);
    if (first == middle) return last;
    if (last == middle) return first;

    auto first2 = middle;
    do
    {
        iterSwap(first, first2);
        ++first;
        ++first2;
        if (first == middle)
            middle = first2;
    }
    while (first2 != last);

    auto newMiddle = first;
    first2 = middle;

    while (first2 != last) {
        iterSwap(first, first2);
        ++first;
        ++first2;
        if (first == middle)
            middle = first2;
        else if (first2 == last)
            first2 = middle;
    }

    return newMiddle;
}

unittest
{
    // doc example
    auto arr = [4, 5, 6, 7, 1, 2, 3];
    auto p = rotate(arr, arr.ptr + 4);
    assert(p - arr.ptr == 3);
    assert(arr == [ 1, 2, 3, 4, 5, 6, 7 ]);

    // The signature taking range and mid
    arr[] = [4, 5, 6, 7, 1, 2, 3];
    p = rotate(arr, arr.ptr + 4);
    assert(p - arr.ptr == 3);
    assert(arr == [ 1, 2, 3, 4, 5, 6, 7 ]);

    // a more elaborate test
    auto rnd = Random(unpredictableSeed);
    int[] a = new int[uniform!(int)(rnd, 100, 200)];
    int[] b = new int[uniform!(int)(rnd, 100, 200)];
    foreach (ref e; a) e = uniform!(int)(rnd, -100, 100);
    foreach (ref e; b) e = uniform!(int)(rnd, -100, 100);
    int[] c = a ~ b;
    auto n = rotate(c, c.ptr + a.length);
    assert(n == c.ptr + b.length);
    assert(c == b ~ a);

    // test with custom iterSwap
    bool called;
    void mySwap(int* a, int* b) { iterSwap(a, b); called = true; }
    rotate!(mySwap)(c, c.ptr + a.length);
    assert(called);
}

// SwapStrategy
/**
Defines the swapping strategy for algorithms that need to swap
elements in a range (such as partition and sort). The strategy
concerns the swapping of elements that are not the core concern of the
algorithm. For example, consider an algorithm that sorts $(D [ "abc",
"b", "aBc" ]) according to $(D toupper(a) < toupper(b)). That
algorithm might choose to swap the two equivalent strings $(D "abc")
and $(D "aBc"). That does not affect the sorting since both $(D [
"abc", "aBc", "b" ]) and $(D [ "aBc", "abc", "b" ]) are valid
outcomes.

Some situations require that the algorithm must NOT ever change the
relative ordering of equivalent elements (in the example above, only
$(D [ "abc", "aBc", "b" ]) would be the correct result). Such
algorithms are called $(B stable). If the ordering algorithm may swap
equivalent elements discretionarily, the ordering is called $(B
unstable).

Yet another class of algorithms may choose an intermediate tradeoff by
being stable only on a well-defined subrange of the range. There is no
established terminology for such behavior; this library calls it $(B
semistable).

Generally, the $(D stable) ordering strategy may be more costly in
time and/or space than the other two because it imposes additional
constraints. Similarly, $(D semistable) may be costlier than $(D
unstable). As (semi-)stability is not needed very often, the ordering
algorithms in this module parameterized by $(D SwapStrategy) all
choose $(D SwapStrategy.unstable) as the default.
*/

enum SwapStrategy
{
    /**
       Allows freely swapping of elements as long as the output
       satisfies the algorithm's requirements.
    */
    unstable,
    /**
       In algorithms partitioning ranges in two, preserve relative
       ordering of elements only to the left of the partition point.
    */
    semistable,
    /**
       Preserve the relative ordering of elements to the largest
       extent allowed by the algorithm's requirements.
    */
    stable,     
}

// eliminate
/**
Reduces $(D r) by overwriting all elements $(D x) that satisfy $(D
pred(x)). Returns the reduced range.

Example:
----
int[] arr = [ 1, 2, 3, 4, 5 ];
// eliminate even elements
auto r = eliminate!("(a & 1) == 0")(arr);
assert(r == [ 1, 3, 5 ]);
assert(arr == [ 1, 3, 5, 4, 5 ]);
----
*/
Range eliminate(alias pred,
                SwapStrategy ss = SwapStrategy.unstable,
                alias move = .move,
                Range)(Range r)
{
    alias Iterator!(Range) It;
    static void assignIter(It a, It b) { move(*b, *a); }
    return range(begin(r), partition!(not!(pred), ss, assignIter, Range)(r));
}

/// Ditto
Range eliminate(string fun, SwapStrategy ss = SwapStrategy.unstable,
                  alias move = .move, Range)(Range r)
{
    return .eliminate!(unaryFun!(fun), ss, move, Range)(r);
}

unittest
{
    int[] arr = [ 1, 2, 3, 4, 5 ];
// eliminate even elements
    auto r = eliminate!("(a & 1) == 0")(arr);
    assert(find!("(a & 1) == 0")(r) == end(r));
}

/**
Reduces $(D r) by overwriting all elements $(D x) that satisfy $(D
pred(x, v)). Returns the reduced range.

Example:
----
int[] arr = [ 1, 2, 3, 2, 4, 5, 2 ];
// keep elements different from 2
auto r = eliminate(arr, 2);
assert(r == [ 1, 3, 4, 5 ]);
assert(arr == [ 1, 3, 4, 5, 4, 5, 2  ]);
----
*/
Range eliminate(alias pred,
                SwapStrategy ss = SwapStrategy.semistable,
                Range, Value)(Range r, Value v)
{
    alias Iterator!(Range) It;
    bool comp(typeof(*It) a) { return !pred(a, v); }
    static void assignIterB(It a, It b) { *a = *b; }
    return range(begin(r), 
                 partition!(comp,
                            ss, assignIterB, Range)(r));
}

/// Ditto
Range eliminate(string pred = "a == b",
                SwapStrategy ss = SwapStrategy.semistable,
                Range, Value)(Range r, Value v)
{
    return .eliminate!(binaryFun!(pred), ss, Range, Value)(r, v);
}

unittest
{
    int[] arr = [ 1, 2, 3, 2, 4, 5, 2 ];
// keep elements different from 2
    auto r = eliminate(arr, 2);
    assert(r == [ 1, 3, 4, 5 ]);
    assert(arr == [ 1, 3, 4, 5, 4, 5, 2  ]);
}

// partition
/**
Partitions a range in two using $(D pred) as a predicate and $(D
iterSwap) as a primitive to swap two elements. Specifically, reorders
the range $(D r = [left, right$(RPAREN)) using $(D iterSwap) such that
all elements $(D i) for which $(D pred(i)) is $(D true) come before
all elements $(D j) for which $(D pred(j)) returns $(D false).

Performs $(BIGOH r.length) (if unstable or semistable) or $(BIGOH
r.length * log(r.length)) (if stable) evaluations of $(D less) and $(D
iterSwap). The unstable version computes the minimum possible
evaluations of $(D iterSwap) (roughly half of those performed by the
semistable version).

$(D partition) always calls $(D iterSwap(i, j)) for iterators
satisfying $(D i < j && !pred(*i) && pred(*j)). After the call to $(D
iterSwap(i, j)), $(D partition) makes no assumption on the values of
$(D *i) and $(D *j). Therefore, $(D partition) can be used to actually
copy partitioned data to a different container or overwrite part of
the array (in fact $(D eliminate) uses $(D partition) with a custom
$(D iterSwap)).

See also STL's $(WEB sgi.com/tech/stl/_partition.html, partition) and
$(WEB sgi.com/tech/stl/stable_partition.html, stable_partition).

Returns:

An iterator $(D p) such that the following conditions are
simultaneously true:
$(OL
$(LI $(D pred(*p1)) for all $(D p1) in [$(D left),
$(D p)$(RPAREN), if any)
$(LI $(D !pred(*p2)) for all $(D p2) in [$(D p),
$(D right)$(RPAREN), if any))
If $(D ss == SwapStrategy.stable), $(D partition) preserves the
relative ordering of all elements $(D a), $(D b) in $(D r) for which
$(D pred(a) == pred(b)). If $(D ss == SwapStrategy.semistable), $(D
partition) preserves the relative ordering of all elements $(D a), $(D
b) in $(D begin(r) .. p) for which $(D pred(a) == pred(b)).

Example:

----
auto Arr = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10];
auto arr = Arr.dup;
static bool even(int a) { return (a & 1) == 0; }
// Partition a such that even numbers come first
auto p = partition!(even)(arr);
// Now arr is separated in evens and odds.
// Numbers may have become shuffled due to instability
assert(p == arr.ptr + 5);
assert(count!(even)(range(begin(arr), p)) == p - begin(arr));
assert(find!(even)(range(p, end(arr))) == end(arr));

// Can also specify the predicate as a string.
// Use 'a' as the predicate argument name
arr[] = Arr[];
p = partition!(q{(a & 1) == 0})(arr);
assert(p == arr.ptr + 5);

// Now for a stable partition:
arr[] = Arr[];
p = partition!(q{(a & 1) == 0}, SwapStrategy.stable)(arr);
// Now arr is [2 4 6 8 10 1 3 5 7 9], and p points to 1
assert(arr == [2, 4, 6, 8, 10, 1, 3, 5, 7, 9] && p == arr.ptr + 5);

// In case the predicate needs to hold its own state, use a delegate:
arr[] = Arr[];
int x = 3;
// Put stuff greater than 3 on the left
bool fun(int a) { return a > x; }
p = partition!(fun, SwapStrategy.semistable)(arr);
// Now arr is [4 5 6 7 8 9 10 2 3 1] and p points to 2
assert(arr == [4, 5, 6, 7, 8, 9, 10, 2, 3, 1] && p == arr.ptr + 7);
----
*/
Iterator!(Range) partition(alias pred,
                           SwapStrategy ss = SwapStrategy.unstable,
                           alias iterSwap = .iterSwap, Range)(Range r)
{
    typeof(return) result = void;
    auto left = begin(r), right = end(r);
    if (left == right) return left;
    static if (ss == SwapStrategy.stable)
    {
        if (right - left == 1)
        {
            result = pred(*left) ? right : left;
            return result;
        }
        auto middle = left + (right - left) / 2;
        alias .partition!(pred, ss, iterSwap, Range) recurse;
        auto lower = recurse(range(left, middle));
        auto upper = recurse(range(middle, right));
        result = rotate!(iterSwap, Range, Iterator!(Range))(
            range(lower, upper), middle);
    }
    else static if (ss == SwapStrategy.semistable)
    {
        result = right;
        auto i = left;
        for (; i != right; ++i)
        {
            // skip the initial portion of "correct" elements
            if (pred(*i)) continue;
            // hit the first "bad" element
            result = i;
            for (++i; i != right; ++i)
            {
                if (!pred(*i)) continue;
                iterSwap(result, i);
                ++result;
            }
            break;
        }
    }
    else // ss == SwapStrategy.unstable
    {
        // Inspired from www.stepanovpapers.com/PAM3-partition_notes.pdf,
        // section "Bidirectional Partition Algorithm (Hoare)"
        for (;;)
        {
            for (;;)
            {
                if (left == right) return left;
                if (!pred(*left)) break;
                ++left;
            }
            // found the left bound
            assert(left != right);
            for (;;)
            {
                --right;
                if (left == right) return left;
                if (pred(*right)) break;
            }
            // found the right bound, swap & make progress
            iterSwap(left, right);
            ++left;
        }
        result = left;
    }
    return result;
}

/// Ditto
Iterator!(Range) partition(
    string pred,
    SwapStrategy ss = SwapStrategy.unstable,
    alias iterSwap = .iterSwap,
    Range)(Range r)
{
    return .partition!(unaryFun!(pred), ss, iterSwap, Range)(r);
}

unittest // partition
{
    auto Arr = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10];
    auto arr = Arr.dup;
    static bool even(int a) { return (a & 1) == 0; }
// Partition a such that even numbers come first
    auto p = partition!(even)(arr);
// Now arr is separated in evens and odds.
    assert(p == arr.ptr + 5);
    assert(count!(even)(range(begin(arr), p)) == p - begin(arr));
    assert(find!(even)(range(p, end(arr))) == end(arr));
// Notice that numbers have become shuffled due to instability
    arr[] = Arr[];
// Can also specify the predicate as a string.
// Use 'a' as the predicate argument name
    p = partition!(q{(a & 1) == 0})(arr);
    assert(p == arr.ptr + 5);
// Same result as above. Now for a stable partition:
    arr[] = Arr[];
    p = partition!(q{(a & 1) == 0}, SwapStrategy.stable)(arr);
// Now arr is [2 4 6 8 10 1 3 5 7 9], and p points to 1
    assert(arr == [2, 4, 6, 8, 10, 1, 3, 5, 7, 9] && p == arr.ptr + 5);
// In case the predicate needs to hold its own state, use a delegate:
    arr[] = Arr[];
    int x = 3;
// Put stuff greater than 3 on the left
    bool fun(int a) { return a > x; }
    p = partition!(fun, SwapStrategy.semistable)(arr);
// Now arr is [4 5 6 7 8 9 10 2 3 1] and p points to 2
    assert(arr == [4, 5, 6, 7, 8, 9, 10, 2, 3, 1] && p == arr.ptr + 7);

    // test with random data
    auto a = rndstuff!(int)();
    partition!(even)(a);
    assert(isPartitioned!(even)(a));
    auto b = rndstuff!(string);
    partition!(`a.length < 5`)(b);
    assert(isPartitioned!(`a.length < 5`)(b));
}

// // partitionPivot
// /**
// Partitions $(D r) algorithm around a pivot
// $(D m). Specifically, reorders the range $(D r = left ..  right) such
// that elements less than $(D *m) are on the left and elements greater
// than or equal to $(D *m) are on the right, then returns an iterator
// pointing to the first element in the second partition. Performs
// $(BIGOH r.length) (if unstable or semistable) or $(BIGOH r.length *
// log(r.length)) (if stable) evaluations of $(D less) and $(D iterSwap).

// Precondition:

// $(D left <= pivot && pivot < right).

// Returns:

// Let $(D pivotVal) be $(D *pivot) before the
// call. The result of $(D partitionPivot) is a value $(D
// mid) such that:
// $(OL
// $(LI $(D less(*p1, pivotVal)) for all $(D p1) in
// [$(D left), $(D mid)$(RPAREN))
// $(LI $(D !less(*p2, pivotVal)) for all $(D p2) in [$(D mid), $(D right)$(RPAREN)))
// For the unstable and semistable partitions, the following condition
// also holds: $(D *mid == pivotVal).
// */
// It partitionPivot(alias less,
//                  SwapStrategy ss = SwapStrategy.unstable,
//                  alias iterSwap = .iterSwap, Range, It)(Range r, It m)
// {
//     auto b = begin(r), e = end(r);
//     if (b == e) return b;
//     assert(b <= m && m < e);
//     alias typeof(*b) E;
//     static if (ss == SwapStrategy.unstable)
//     {
//         --e;
//         // swap the pivot to end
//         iterSwap(m, e);
//         // partition on predicate
//         auto pivotCached = *e;
//         bool pred(E a) { return less(a, pivotCached); }
//         auto result = partition!(pred, ss, iterSwap)(range(b, e));
//         // swap back
//         iterSwap(result, e);
//     }
//     else
//     {
//         // copy the pivot so it's not messed up
//         auto pivot = *m;
//         bool pred(E a) { return less(a, pivot); }
//         auto result = partition!(pred, ss, iterSwap)(r);
//     }
//     return result;
// }

// /// Ditto
// It partitionPivot(string less = q{a < b},
//                  SwapStrategy ss = SwapStrategy.unstable,
//                  alias iterSwap = .iterSwap, Range, It)(Range r, It m)
// {
//     return .partitionPivot!(binaryFun!(less), ss, iterSwap, Range, It)(r, m);
// }

// unittest
// {
//     auto a = [3, 3, 2];
//     bool less(int a, int b) { return a < b; }
//     auto p = partitionPivot!(less)(a, a.ptr);
//     assert(p == a.ptr + 1 && a == [2, 3, 3]);
//     // Use default less
//     a[] = [3, 3, 2];
//     p = partitionPivot(a, a.ptr);
//     assert(p == a.ptr + 1 && a == [2, 3, 3]);

//     // test with random data
//     // @@@BUG@@@ The whole type tuple should work
//     foreach (T; TypeTuple!(int/*, double, string*/))
//     {{
//         auto i = rndstuff!(T)();
//         if (!i.length) continue;
//         auto pivot = i[0];
//         partitionPivot!(`a > b`)(i, begin(i));
//         bool pred2(int a) { return a > pivot; }
//         assert(isPartitioned!(pred2)(i));
//     }}
// }

template isPartitioned(alias pred)
{
    bool isPartitioned(T)(T range)
    {
        auto left = begin(range), right = end(range);
        if (left == right) return true;
        for (; left != right; ++left)
        {
            if (!pred(*left)) break;
        }
        for (; left != right; ++left)
        {
            if (pred(*left)) return false;
        }
        return true;
    }
}

template isPartitioned(string pred)
{
    alias .isPartitioned!(unaryFun!(pred)) isPartitioned;
}

// topN
/**
Reorders the range $(D r = [first, last$(RPAREN)) using $(D iterSwap)
as a swapping primitive such that $(D nth) points to the element that
would fall there if the range were fully sorted. Effectively, it finds
the nth smallest (according to $(D less)) element in $(D r). In
addition, it also partitions $(D r) such that all elements $(D p1) in
$(D [first, nth$(RPAREN)) satisfy $(D less(*p1, *nth)), and all
elements $(D p2) in $(D [nth, last$(RPAREN)) satisfy $(D !less(*p2,
nth)). Performs $(BIGOH r.length) (if unstable) or $(BIGOH r.length *
log(r.length)) (if stable) evaluations of $(D less) and $(D
iterSwap). See also $(WEB sgi.com/tech/stl/nth_element.html, STL's
nth_element).

Example:

----
int[] v = [ 25, 7, 9, 2, 0, 5, 21 ];
auto n = 4;
topN!(less)(v, begin(v) + n);
assert(v[n] == 9);
// Equivalent form:
topN!("a < b")(v, begin(v) + n);
assert(v[n] == 9);
----

BUGS:

stable topN has not been implemented yet.
*/
void topN(alias less,
                SwapStrategy ss = SwapStrategy.unstable,
                alias iterSwap = .iterSwap, Range, It)(Range r, It nth)
{
    static assert(ss == SwapStrategy.unstable,
                  "stable topN not yet implemented");
    auto b = begin(r), e = end(r);
    assert(b < e);
    assert(b <= nth && nth < e);
    for (;;)
    {
        auto pivot = b + (e - b) / 2;
        auto pivotVal = *pivot;
        bool pred(ElementType!(Range) a) { return a < pivotVal; }
        iterSwap(pivot, e - 1);
        pivot = partition!(pred, ss, iterSwap)(range(b, e));
        iterSwap(pivot, e - 1);
        if (pivot == nth) return;
        if (pivot < nth) b = pivot + 1;
        else e = pivot;
    }
}

/// Ditto
void topN(string less = q{a < b},
                SwapStrategy ss = SwapStrategy.unstable,
                alias iterSwap = .iterSwap, Range, It)(Range r, It nth)
{
    return .topN!(binaryFun!(less), ss, iterSwap, Range, It)(r, nth);
}

unittest
{
    scope(failure) writeln(stderr, "Failure testing algorithm");
    //auto v = ([ 25, 7, 9, 2, 0, 5, 21 ]).dup;
    int[] v = [ 7, 6, 5, 4, 3, 2, 1, 0 ];
    auto n = 3;
    topN!("a < b")(v, v.ptr + n);
    assert(v[n] == n);
    //
    v = ([3, 4, 5, 6, 7, 2, 3, 4, 5, 6, 1, 2, 3, 4, 5]).dup;
    n = 3;
    topN(v, v.ptr + n);
    assert(v[n] == 3);
    //
    v = ([3, 4, 5, 6, 7, 2, 3, 4, 5, 6, 1, 2, 3, 4, 5]).dup;
    n = 1;
    topN(v, v.ptr + n);
    assert(v[n] == 2);
    //
    v = ([3, 4, 5, 6, 7, 2, 3, 4, 5, 6, 1, 2, 3, 4, 5]).dup;
    n = v.length - 1;
    topN(v, v.ptr + n);
    assert(v[n] == 7);
    //
    v = ([3, 4, 5, 6, 7, 2, 3, 4, 5, 6, 1, 2, 3, 4, 5]).dup;
    n = 0;
    topN(v, v.ptr + n);
    assert(v[n] == 1);
}

// sort
/**
Sorts a random-access range according to predicate $(D less). Performs
$(BIGOH r.length * log(r.length)) (if unstable) or $(BIGOH r.length *
log(r.length) * log(r.length)) (if stable) evaluations of $(D less)
and $(D iterSwap). See also STL's $(WEB sgi.com/tech/stl/_sort.html,
sort) and $(WEB sgi.com/tech/stl/stable_sort.html, stable_sort).

Example:

----
int[] array = [ 1, 2, 3, 4 ];
// sort in descending order
sort!("a > b")(array);
assert(array == [ 4, 3, 2, 1 ]);
// sort in ascending order
sort(array);
assert(array == [ 1, 2, 3, 4 ]);
// sort with a delegate 
bool myComp(int x, int y) { return x > y; }
sort!(myComp)(array);
assert(array == [ 4, 3, 2, 1 ]);
// Showcase stable sorting
string[] words = [ "aBc", "a", "abc", "b", "ABC", "c" ];
sort!("toupper(a) < toupper(b)", SwapStrategy.stable)(words);
assert(words == [ "a", "aBc", "abc", "ABC", "b", "c" ]);
----
*/

void sort(alias less, SwapStrategy ss = SwapStrategy.unstable,
          alias iterSwap = .iterSwap, Range)(Range r)
{
    static if (is(typeof(less(*begin(r), *end(r))) == bool))
    {
        sortImpl!(less, ss, iterSwap)(r);
        assert(isSorted!(less)(r));
    }
    else
    {
        static assert(false, typeof(&less).stringof);
    }
}

/// Ditto
void sort(string less = q{a < b}, SwapStrategy ss = SwapStrategy.unstable,
          alias iterSwap = .iterSwap, Range)(Range r)
{
    return .sort!(binaryFun!(less), ss, iterSwap, Range)(r);
}

import std.string;

unittest
{
    // sort using delegate
    int a[] = new int[100];
    auto rnd = Random(unpredictableSeed);
    foreach (ref e; a) {
        e = uniform!(int)(rnd, -100, 100);
    }
    
    int i = 0;
    bool greater2(int a, int b) { return a + i > b + i; }
    bool delegate(int, int) greater = &greater2;
    sort!(greater)(a);
    assert(isSorted!(greater)(a));

    // sort using string
    sort!("a < b")(a);
    assert(isSorted!("a < b")(a));

    // sort using function; all elements equal
    foreach (ref e; a) {
        e = 5;
    }
    static bool less(int a, int b) { return a < b; }
    sort!(less)(a);
    assert(isSorted!(less)(a));

    string[] words = [ "aBc", "a", "abc", "b", "ABC", "c" ];
    bool lessi(string a, string b) { return toupper(a) < toupper(b); }
    sort!(lessi, SwapStrategy.stable)(words);
    assert(words == [ "a", "aBc", "abc", "ABC", "b", "c" ]);

    // sort using ternary predicate
    //sort!("b - a")(a);
    //assert(isSorted!(less)(a));

    a = rndstuff!(int);
    sort(a);
    assert(isSorted(a));
    auto b = rndstuff!(string);
    sort!("tolower(a) < tolower(b)")(b);
    assert(isSorted!("toupper(a) < toupper(b)")(b));
}

/*private*/
Iter getPivot(alias less, Iter)(Iter b, Iter e)
{
    auto r = b + (e - b) / 2;
    return r;
}

/*private*/
void optimisticInsertionSort(alias less, alias iterSwap, Range)(Range r)
{
    auto b = begin(r), e = end(r);
    if (e - b <= 1) return;
    for (auto i = 1 + b; i != e; )
    {
        // move down to find the insertion point
        auto p = i - 1;
        for (;;)
        {
            if (!less(*i, *p))
            {
                ++p;
                break;
            }
            if (p == b) break;
            --p;
        }
        // move up to see how many we can insert
        auto iOld = i, iPrev = i;
        ++i;
        while (i != e && less(*i, *p) && !less(*i, *iPrev)) ++i, ++iPrev;
        // do the insertion
        rotate!(iterSwap)(range(p, i), iOld);
    }
}

/*private*/
void sortImpl(alias less, SwapStrategy ss, alias iterSwap, Range)(Range r)
{
    alias ElementType!(Range) Elem;
    enum uint optimisticInsertionSortGetsBetter = 1;
    static assert(optimisticInsertionSortGetsBetter >= 1);
    auto b = begin(r), e = end(r);
    while (e - b > optimisticInsertionSortGetsBetter)
    {
        auto pivotPtr = getPivot!(less)(b, e);
        auto pivot = *pivotPtr;
        // partition
        static if (ss == SwapStrategy.unstable)
        {
            // partition
            iterSwap(pivotPtr, e - 1);
            bool pred(Elem a) { return less(a, pivot); }
            auto mid = partition!(pred, ss, iterSwap)(range(b, e));
            iterSwap(mid, e - 1);
            // done with partitioning
            assert(!less(pivot, *mid) && !less(*mid, pivot));
            if (b == mid)
            {
                // worst case: *b <= everything (also pivot <= everything)
                // avoid quadratic behavior
                do ++b; while (b != e && !less(pivot, *b));
            }
            else
            {
                .sortImpl!(less, ss, iterSwap, Range)(range(b, mid));
                b = mid + 1;
            }
        }
        else // handle semistable and stable the same
        {
            static assert(ss != SwapStrategy.semistable);
            bool pred(Elem a) { return less(a, pivot); }
            auto mid = partition!(pred, ss, iterSwap)(range(b, e));
            if (b == mid)
            {
                // bad, bad pivot. pivot <= everything
                // find the first occurrence of the pivot                
                bool pred1(Elem a) { return !less(pivot, a); }
                auto firstPivotPos = find!(pred1)(range(b, e));
                assert(firstPivotPos != e);
                assert(!less(*firstPivotPos, pivot)
                       && !less(pivot, *firstPivotPos));
                // find the last occurrence of the pivot
                bool pred2(Elem a) { return less(pivot, a); }
                auto lastPivotPos = find!(pred2)(range(firstPivotPos + 1, e));
                // now rotate firstPivotPos..lastPivotPos to the front
                b = rotate!(iterSwap)(range(b, lastPivotPos), firstPivotPos);
            }
            else
            {
                .sortImpl!(less, ss, iterSwap, Range)(range(b, mid));
                b = mid;
            }
        }
    }
    // residual sort
    static if (optimisticInsertionSortGetsBetter > 1)
    {
        optimisticInsertionSort!(less, iterSwap, Range)(r);
    }
}
    
// schwartzSort
/**
Sorts a range using an algorithm akin to the $(WEB
wikipedia.org/wiki/Schwartzian_transform, Schwartzian transform), also
known as the decorate-sort-undecorate pattern in Python and Lisp. (Not
to be confused with $(WEB youtube.com/watch?v=S25Zf8svHZQ, the other
Schwartz).) This function is helpful when the sort comparison includes
an expensive computation. The complexity is the same as that of the
corresponding $(D sort), but $(D schwartzSort) evaluates $(D
transform) only $(D r.length) times (less than half when compared to
regular sorting). The usage can be best illustrated with an example.

Example:

----
uint hashFun(string) { ... expensive computation ... }
string[] array = ...;
// Sort strings by hash, slow
sort!("hashFun(a) < hashFun(b)")(array);
// Sort strings by hash, fast (only computes arr.length hashes):
schwartzSort!(hashFun, "a < b")(array);
----

The $(D schwartzSort) function might require less temporary data and
be faster than the Perl idiom or the decorate-sort-undecorate idiom
present in Python and Lisp. This is because sorting is done in-place
and only minimal extra data (one array of transformed elements) is
created.
*/
void schwartzSort(alias transform, alias less,
                  SwapStrategy ss = SwapStrategy.unstable, Range)(Range r)
{
    alias typeof(transform(*begin(r))) XformType;
    auto xform = new XformType[r.length];
    alias Iterator!(XformType[]) InnerIter;
    foreach (i, e; r)
    {
        xform[i] = transform(e);
    }
    // primitive to swap the two collections in lockstep
    void mySwap(InnerIter a, InnerIter b)
    {
        iterSwap(a, b);
        invariant i = a - begin(xform), j = b - begin(xform);
        assert(i >= 0 && i < xform.length && j >= 0 && j < xform.length);
        swap(r[i], r[j]);
    }
    sort!(less, ss, mySwap)(xform);
}

/// Ditto
void schwartzSort(alias transform, string less = q{a < b},
                  SwapStrategy ss = SwapStrategy.unstable, Range)(Range r)
{
    return .schwartzSort!(transform, binaryFun!(less), ss, Range)(r);
}

unittest
{
    static double entropy(double[] probs) {
        double result = 0;
        foreach (p; probs) {
            if (!p) continue;
            //enforce(p > 0 && p <= 1, "Wrong probability passed to entropy");
            result -= p * log(p);
        }
        return result;
    }

    auto lowEnt = ([ 1.0, 0, 0 ]).dup,
        midEnt = ([ 0.1, 0.1, 0.8 ]).dup,
        highEnt = ([ 0.31, 0.29, 0.4 ]).dup;
    double arr[][] = new double[][3];
    arr[0] = midEnt;
    arr[1] = lowEnt;
    arr[2] = highEnt;
    schwartzSort!(entropy, q{a < b})(arr);
    assert(arr[0] == lowEnt);
    assert(arr[1] == midEnt);
    assert(arr[2] == highEnt);

    schwartzSort!(entropy, q{a > b})(arr);
    assert(arr[0] == highEnt);
    assert(arr[1] == midEnt);
    assert(arr[2] == lowEnt);

    // random data
    auto b = rndstuff!(string);
    schwartzSort!(tolower)(b);
    assert(isSorted!("toupper(a) < toupper(b)")(b));
}

// partialSort
/**
Reorders $(D r) such that the range $(D begin(r) .. mid) is the same
as if $(D r) were sorted, and leaves the range $(D mid .. end(r)) in
no particular order. Performs $(BIGOH r.length * log(mid - begin(r)))
evaluations of $(D pred).

Example:
----
int[] a = [ 9, 8, 7, 6, 5, 4, 3, 2, 1, 0 ];
partialSort(a, begin(a) + 5);
assert(a[0 .. 5] == [ 0, 1, 2, 3, 4 ]);
----
*/
void partialSort(alias less, SwapStrategy ss = SwapStrategy.unstable,
    alias iterSwap = .iterSwap, Range, It)(Range r, It mid)
{
    topN!(less, ss, iterSwap)(r, mid);
    sort!(less, ss, iterSwap, Range)(range(begin(r), mid));
}

/// Ditto
void partialSort(string less = "a < b",
    SwapStrategy ss = SwapStrategy.unstable,
    alias iterSwap = .iterSwap, Range, It)(Range r, It mid)
{
    return .partialSort!(binaryFun!(less), ss, iterSwap, Range, It)(r, mid);
}

unittest
{
    int[] a = [ 9, 8, 7, 6, 5, 4, 3, 2, 1, 0 ];
    partialSort(a, begin(a) + 5);
    assert(a[0 .. 5] == [ 0, 1, 2, 3, 4 ]);
}

// isSorted
/**
Checks whether a random-access range is sorted according to the
comparison operation $(D less). Performs $(BIGOH r.length) evaluations
of $(D less).

   Example:

----
int[] arr = [4, 3, 2, 1];
assert(!isSorted(arr));
sort(arr);
assert(isSorted(arr));
sort!("a > b")(arr);
assert(isSorted!("a > b")(arr));
----
*/

bool isSorted(alias less, Range)(Range r)
{
    bool pred(typeof(*begin(r)) a, typeof(*begin(r)) b) { return less(b, a); }
    return findAdjacent!(pred)(r) == end(r);
}

/// Ditto
bool isSorted(string less = "a < b", Range)(Range r)
{
    return .isSorted!(binaryFun!(less), Range)(r);
}

// // makeIndex
// /**
// Computes an index for $(D r) based on the comparison $(D less). The
// returned index is a sorted array of iterators into the original
// range. This technique is similar to sorting, but it is more flexible
// because (1) it allows "sorting" of invariant collections, (2) allows
// binary search even if the original collection does not offer random
// access, (3) allows multiple indexes, each on a different predicate,
// and (4) may be faster when dealing with large objects. However, using
// an index may also be slower under certain circumstances due to the
// extra indirection, and is always larger than a sorting-based solution
// because it needs space for the index in addition to the original
// collection. The complexity is the same as $(D sort)'s.

// Example:

// ----
// invariant arr = [ 2, 3, 1 ];
// auto index = makeIndex!(less)(arr);
// assert(*index[0] == 1 && *index[1] == 2 && *index[2] == 3);
// assert(isSorted!("*a < *b")(index));
// ----
// */
// Iterator!(Range)[] makeIndex(
//     alias less,
//     SwapStrategy ss = SwapStrategy.unstable,
//     alias iterSwap = .iterSwap,
//     Range)(Range r)
// {
//     alias Iterator!(Range) Iter;
//     auto result = new Iter[r.length];
//     // assume collection already ordered
//     size_t i = 0;
//     foreach (it; begin(r) .. end(r))
//     {
//         result[i++] = it;
//     }
//     // sort the index
//     static bool indirectLess(Iter a, Iter b)
//     {
//         return less(*a, *b);
//     }
//     sort!(indirectLess, ss, iterSwap)(result);
//     return result;
// }


// /// Ditto
// Iterator!(Range)[] makeIndex(
//     string less = q{a < b},
//     SwapStrategy ss = SwapStrategy.unstable,
//     alias iterSwap = .iterSwap,
//     Range)(Range r)
// {
//     return .makeIndex!(binaryFun!(less), ss, iterSwap, Range)(r);
// }

// topNIndexImpl
private void topNIndexImpl(
    alias less,
    bool sortAfter,
    SwapStrategy ss,
    alias iterSwap,
    SRange, TRange)(SRange source, TRange target)
{
    static assert(ss == SwapStrategy.unstable,
                  "Stable indexing not yet implemented");
    alias Iterator!(SRange) SIter;
    alias ElementType!(TRange) TElem;
    enum usingInt = isIntegral!(TElem);

    static if (usingInt)
    {
        enforce(source.length <= TElem.max,
                "Numeric overflow at risk in computing topNIndexImpl");
    }

    // types and functions used within
    SIter index2iter(TElem a)
    {
        static if (!usingInt)
            return a;
        else
            return begin(source) + a;
    }
    bool indirectLess(TElem a, TElem b)
    {
        return less(*index2iter(a), *index2iter(b));
    }
    void indirectCopy(SIter from, ref TElem to)
    {
        static if (!usingInt)
            to = from;
        else
            to = cast(TElem)(from - begin(source));
    }

    // copy beginning of collection into the target
    auto sb = begin(source), se = end(source),
        tb = begin(target), te = end(target);
    for (; sb != se; ++sb, ++tb)
    {
        if (tb == te) break;
        indirectCopy(sb, *tb);
    }

    // if the index's size is same as the source size, just quicksort it
    // otherwise, heap-insert stuff in it.
    if (sb == se)
    {
        // everything in source is now in target... just sort the thing
        static if (sortAfter) sort!(indirectLess, ss, iterSwap)(target);
    }
    else
    {
        // heap-insert
        te = tb;
        tb = begin(target);
        target = range(tb, te);
        makeHeap!(indirectLess, iterSwap)(target);
        // add stuff to heap
        for (; sb != se; ++sb)
        {
            if (!less(*sb, *index2iter(*tb))) continue;
            // copy the source over the smallest
            indirectCopy(sb, *tb);
            heapify!(indirectLess, iterSwap)(target, tb);
        }
        static if (sortAfter) sortHeap!(indirectLess, iterSwap)(target);
    }
}

/**
topNIndex
*/
void topNIndex(
    alias less,
    SwapStrategy ss = SwapStrategy.unstable,
    alias iterSwap = .iterSwap,
    SRange, TRange)(SRange source, TRange target)
{
    return .topNIndexImpl!(less, false, ss, iterSwap)(source, target);
}

/// Ditto
void topNIndex(
    string less,
    SwapStrategy ss = SwapStrategy.unstable,
    alias iterSwap = .iterSwap,
    SRange, TRange)(SRange source, TRange target)
{
    return .topNIndexImpl!(binaryFun!(less), false, ss, iterSwap)(source, target);
}

// partialIndex
/**
Computes an index for $(D source) based on the comparison $(D less)
and deposits the result in $(D target). It is acceptable that $(D
target.length < source.length), in which case only the smallest $(D
target.length) elements in $(D source) get indexed. The target
provides a sorted "view" into $(D source). This technique is similar
to sorting and partial sorting, but it is more flexible because (1) it
allows "sorting" of invariant collections, (2) allows binary search
even if the original collection does not offer random access, (3)
allows multiple indexes, each on a different comparison criterion, (4)
may be faster when dealing with large objects. However, using an index
may also be slower under certain circumstances due to the extra
indirection, and is always larger than a sorting-based solution
because it needs space for the index in addition to the original
collection. The complexity is $(BIGOH source.length *
log(target.length)).

Two types of indexes are accepted. They are selected by simply passing
the appropriate $(D target) argument: $(OL $(LI Indexes of type $(D
Iterator!(Source)), in which case the index will be sorted with the
predicate $(D less(*a, *b));) $(LI Indexes of an integral type
(e.g. $(D size_t)), in which case the index will be sorted with the
predicate $(D less(source[a], source[b])).))

Example:

----
invariant arr = [ 2, 3, 1 ];
int* index[3];
partialIndex(arr, index);
assert(*index[0] == 1 && *index[1] == 2 && *index[2] == 3);
assert(isSorted!("*a < *b")(index));
----
*/
void partialIndex(
    alias less,
    SwapStrategy ss = SwapStrategy.unstable,
    alias iterSwap = .iterSwap,
    SRange, TRange)(SRange source, TRange target)
{
    return .topNIndexImpl!(less, true, ss, iterSwap)(source, target);
}

/// Ditto
void partialIndex(
    string less,
    SwapStrategy ss = SwapStrategy.unstable,
    alias iterSwap = .iterSwap,
    SRange, TRange)(SRange source, TRange target)
{
    return .topNIndexImpl!(binaryFun!(less), true, ss, iterSwap)(source, target);
}

unittest
{
    invariant arr = [ 2, 3, 1 ];
    auto index = new invariant(int)*[3];
    partialIndex!(binaryFun!("a < b"))(arr, index);
    assert(*index[0] == 1 && *index[1] == 2 && *index[2] == 3);
    assert(isSorted!("*a < *b")(index));
}

unittest
{
    static bool less(int a, int b) { return a < b; }
    {
        string[] x = ([ "c", "a", "b", "d" ]).dup;
        // test with integrals
        auto index1 = new size_t[x.length];
        partialIndex!(q{a < b})(x, index1);
        assert(index1[0] == 1 && index1[1] == 2 && index1[2] == 0
               && index1[3] == 3);
        // half-sized
        index1 = new size_t[x.length / 2];
        partialIndex!(q{a < b})(x, index1);
        assert(index1[0] == 1 && index1[1] == 2);

        // and with iterators
        auto index = new string*[x.length];
        partialIndex!(q{a < b})(x, index);
        assert(isSorted!(q{*a < *b})(index));
        assert(*index[0] == "a" && *index[1] == "b" && *index[2] == "c"
               && *index[3] == "d");
    }

    {
        invariant arr = [ 2, 3, 1 ];
        auto index = new invariant(int)*[arr.length];
        partialIndex!(less)(arr, index);
        assert(*index[0] == 1 && *index[1] == 2 && *index[2] == 3);
        assert(isSorted!(q{*a < *b})(index));
    }

    // random data
    auto b = rndstuff!(string);
    auto index = new string*[b.length];
    partialIndex!("toupper(a) < toupper(b)")(b, index);
    assert(isSorted!("toupper(*a) < toupper(*b)")(index));

    // random data with indexes
    auto index1 = new size_t[b.length];
    bool cmp(string x, string y) { return toupper(x) < toupper(y); }
    partialIndex!(cmp)(b, index1);
    bool check(size_t x, size_t y) { return toupper(b[x]) < toupper(b[y]); }
    assert(isSorted!(check)(index1));
}

// Commented out for now, needs reimplementation
 
// // schwartzMakeIndex
// /**
// Similar to $(D makeIndex) but using $(D schwartzSort) to sort the
// index.

// Example:

// ----
// string[] arr = [ "ab", "c", "Ab", "C" ];
// auto index = schwartzMakeIndex!(toupper, less, SwapStrategy.stable)(arr);
// assert(*index[0] == "ab" && *index[1] == "Ab"
//     && *index[2] == "c" && *index[2] == "C");
// assert(isSorted!("toupper(*a) < toupper(*b)")(index));
// ----
// */
// Iterator!(Range)[] schwartzMakeIndex(
//     alias transform,
//     alias less,
//     SwapStrategy ss = SwapStrategy.unstable,
//     alias iterSwap = .iterSwap,
//     Range)(Range r)
// {
//     alias Iterator!(Range) Iter;
//     auto result = new Iter[r.length];
//     // assume collection already ordered
//     size_t i = 0;
//     foreach (it; begin(r) .. end(r))
//     {
//         result[i++] = it;
//     }
//     // sort the index
//     alias typeof(transform(*result[0])) Transformed;
//     static bool indirectLess(Transformed a, Transformed b)
//     {
//         return less(a, b);
//     }
//     static Transformed indirectTransform(Iter a)
//     {
//         return transform(*a);
//     }
//     schwartzSort!(indirectTransform, less, ss)(result);
//     return result;
// }

// /// Ditto
// Iterator!(Range)[] schwartzMakeIndex(
//     alias transform,
//     string less = q{a < b},
//     SwapStrategy ss = SwapStrategy.unstable,
//     alias iterSwap = .iterSwap,
//     Range)(Range r)
// {
//     return .schwartzMakeIndex!(
//         transform, binaryFun!(less), ss, iterSwap, Range)(r);
// }

// unittest
// {
//     string[] arr = [ "D", "ab", "c", "Ab", "C" ];
//     auto index = schwartzMakeIndex!(toupper, "a < b",
//                                     SwapStrategy.stable)(arr);
//     assert(isSorted!(q{toupper(*a) < toupper(*b)})(index));
//     assert(*index[0] == "ab" && *index[1] == "Ab"
//            && *index[2] == "c" && *index[3] == "C");

//     // random data
//     auto b = rndstuff!(string);
//     auto index1 = schwartzMakeIndex!(toupper)(b);
//     assert(isSorted!("toupper(*a) < toupper(*b)")(index1));
// }

// schwartzIsSorted
/**
Checks whether a random-access range is sorted according to the
comparison operation $(D less(transform(a), transform(b))). Performs
$(BIGOH r.length) evaluations of $(D less) and $(D transform). The
advantage over $(D isSorted) is that it evaluates $(D transform) only
half as many times.

   Example:

----
int[] arr = [ "ab", "Ab", "aB", "bc", "Bc" ];
assert(!schwartzIsSorted!(toupper, "a < b")(arr));
----
*/

bool schwartzIsSorted(alias transform, alias less, Range)(Range r)
{
    if (isEmpty(r)) return true;
    auto i = begin(r), e = end(r);
    auto last = transform(*i);
    for (++i; i != e; ++i)
    {
        auto next = transform(*i);
        if (less(next, last)) return false;
        move(next, last);
    }
    return true;
}

/// Ditto
bool schwartzIsSorted(alias transform, string less = "a < b", Range)(Range r)
{
    return .schwartzIsSorted!(transform, binaryFun!(less), Range)(r);
}
      
// lowerBound
/**
Returns the leftmost position in $(D range) such that all other values
$(D x) to the left of that position satisfy $(D less(x,
value)). Performs $(BIGOH log(r.length)) evaluations of $(D less). See
also STL's $(WEB sgi.com/tech/stl/lower_bound.html, lower_bound).

Precondition:
$(D isSorted!(less)(r))

Returns:
$(D i) such that $(D less(*p, i)) for all p in $(D [begin(r), i$(RPAREN)).

Example:
----
int[] a = [ 0, 1, 2, 3, 4, 5, 6, 7, 8, 9 ];
auto p = lowerBound!(less)(a, 4);
assert(*p == 4);
p = lowerBound(a, 4); // uses less by default
assert(*p == 4);
p = lowerBound!("a < b")(a, 4); // predicate as string
assert(*p == 4);
----
*/
Iterator!(Range) lowerBound(alias less, Range, V)(Range r, V value)
{
    //assert(isSorted!(less)(r));
    auto first = begin(r);
    auto count = end(r) - first;
    while (count > 0)
    {
        invariant step = count / 2;
        auto it = first + step;
        if (less(*it, value))
        {
            first = it + 1;
            count -= step + 1;
        }
        else
        {
            count = step;
        }
    }
    return first;
}

/// Ditto
Iterator!(Range) lowerBound(string less = q{a < b}, Range, V)(Range r, V value)
{
    return .lowerBound!(binaryFun!(less), Range, V)(r, value);
}

unittest
{
    int[] a = [ 0, 1, 2, 3, 4, 5, 6, 7, 8, 9 ];
    auto p = lowerBound!("a < b")(a, 4);
    assert(*p == 4);
    p = lowerBound(a, 5);
    assert(*p == 5);
    p = lowerBound!(q{a < b})(a, 6);
    assert(*p == 6);
}

// upperBound
/**
Returns the rightmost position in $(D r) such that all other elements
$(D x) to the left of that position satisfy $(D !less(value, x)).
Performs $(BIGOH log(r.length)) evaluations of $(D less). See also
STL's $(WEB sgi.com/tech/stl/upper_bound.html, upper_bound).

Precondition:
$(D isSorted!(less)(r))

Returns: $(D i) such that $(D less(*p, value)) for all p in $(D
[begin(r), i$(RPAREN)).

Example:
----
auto a = [ 1, 2, 3, 3, 3, 4, 4, 5, 6 ];
auto p = upperBound(a, 3);
assert(p == begin(a) + 5);
----
*/
Iterator!(Range) upperBound(alias less, Range, V)(Range r, V value)
{
    //assert(isSorted!(less)(r));
    auto first = begin(r);
    size_t count = end(r) - first;
    while (count > 0)
    {
        auto step = count / 2;
        auto it = first + step;
        if (!less(value,*it))
        {
            first = it + 1;
            count -= step + 1;
        }
        else count = step;
  }
  return first;
}

/// Ditto
Iterator!(Range) upperBound(string less = q{a < b}, Range, V)(Range r, V value)
{
    return .upperBound!(binaryFun!(less), Range, V)(r, value);
}

unittest
{
    auto a = [ 1, 2, 3, 3, 3, 4, 4, 5, 6 ];
    auto p = upperBound(a, 3);
    assert(p == begin(a) + 5);
}

// equalRange
/**
The call $(D equalRange!(less)(r, v)) returns $(D range($(D
lowerBound!(less)(r, v), $(D upperBound!(less)(r, v))))) but a bit
more efficiently than calling both functions.  Performs $(BIGOH
log(r.length)) evaluations of $(D less). See also STL's $(WEB
sgi.com/tech/stl/equal_range.html, equal_range).

Precondition:
$(D isSorted!(less)(range))

Returns:

The largest subrange of $(D r) such that for all $(D p) in that range,
$(D !less(*p, value) && !less(value, *p)).

Example:
----
auto a = [ 1, 2, 3, 3, 3, 4, 4, 5, 6 ];
auto r = equalRange(a, 3);
assert(r == [ 3, 3, 3 ]);
----
*/
Range equalRange(alias less, Range, V)(Range r, V value)
{
    //assert(isSorted!(less)(r));
    auto first = begin(r), last = end(r);
    for (size_t count = last - first; count > 0; )
    {
        auto step = count / 2;
        auto middle = first + step;
        if (less(*middle, value))
        {
            first = middle + 1;
            count -= step + 1;
        }
        else if (less(value, *middle))
        {
            count = step;
        }
        else
        {
            // we're straight in the range!
            auto left = lowerBound!(less)(range(first, middle), value);
            first += count;
            auto right = upperBound!(less)(range(++middle, first), value);
            return range(left, right);
        }
    }
    return range(first, first);
}

/// Ditto
Range equalRange(string less = q{a < b}, Range, V)(Range r, V value)
{
    return .equalRange!(binaryFun!(less), Range, V)(r, value);
}

unittest
{
    int[] a = [ 1, 2, 3, 3, 3, 4, 4, 5, 6 ];
    auto p = equalRange(a, 3);
    assert(p == [ 3, 3, 3 ]);
    p = equalRange(a, 4);
    assert(p == [ 4, 4 ]);
    p = equalRange(a, 2);
    assert(p == [ 2 ]);
}

// canFindSorted
/**
Returns $(D true) if and only if $(D value) can be found in $(D
range), which is assumed to be sorted. Performs $(BIGOH log(r.length))
evaluations of $(D less). See also STL's $(WEB
sgi.com/tech/stl/binary_search.html, binary_search).
*/

bool canFindSorted(alias less, T, V)(T range, V value)
{
    auto p = lowerBound!(less)(range, value);
    return p != end(range) && !less(value, *p);
}

bool canFindSorted(string less = q{a < b}, T, V)(T range, V value)
{
    return .canFindSorted!(binaryFun!(less), T, V)(range, value);
}

unittest
{
    auto a = rndstuff!(int);
    if (a.length)
    {
        auto b = a[a.length / 2];
        sort(a);
        assert(canFindSorted(a, b));
    }
}

/**
Converts the range $(D r) into a heap. Performs $(BIGOH r.length)
evaluations of $(D less).
*/

void makeHeap(alias less, alias iterSwap = .iterSwap, Range)(Range r)
{
    if (r.length < 2) return;
    auto i = begin(r) + (r.length - 2) / 2;
    for (;; --i)
    {
        heapify!(less, iterSwap)(r, i);
        if (i == begin(r)) return;
    }
}

unittest
{
    // example from "Introduction to Algorithms" Cormen et al., p 146
    int[] a = [ 4, 1, 3, 2, 16, 9, 10, 14, 8, 7 ];
    makeHeap!(binaryFun!("a < b"))(a);
    assert(a == [ 16, 14, 10, 8, 7, 9, 3, 2, 4, 1 ]);
}

private void heapify(alias less, alias iterSwap, Range, It)(Range r, It i)
{
    auto b = begin(r);
    for (;;)
    {
        auto left = b + (i - b) * 2 + 1, right = left + 1;
        if (right == end(r))
        {
            if (less(*i, *left)) iterSwap(i, left);
            return;
        }
        if (right > end(r)) return;
        assert(left < end(r) && right < end(r));
        auto largest = less(*i, *left)
            ? (less(*left, *right) ? right : left)
            : (less(*i, *right) ? right : i);
        if (largest == i) return;
        iterSwap(i, largest);
        i = largest;
    }
}

unittest
{
    // example from "Introduction to Algorithms" Cormen et al., p 143
    int[] a = [ 16, 4, 10, 14, 7, 9, 3, 2, 8, 1 ];
    heapify!(binaryFun!("a < b"), iterSwap)(a, begin(a) + 1);
    assert(a == [ 16, 14, 10, 8, 7, 9, 3, 2, 4, 1 ]);
}

/**
popHeap 
*/
void popHeap(alias less, alias iterSwap = .iterSwap, Range)(Range r)
{
    if (r.length <= 1) return;
    auto newEnd = end(r) - 1;
    iterSwap(begin(r), newEnd);
    heapify!(less, iterSwap)(range(begin(r), newEnd), begin(r));
}

/**
sortHeap
*/
void sortHeap(alias less, alias iterSwap = .iterSwap, Range)(Range r)
{
    auto b = begin(r), e = end(r);
    for (; e - b > 1; --e)
    {
        popHeap!(less, iterSwap)(range(b, e));
    }
}

/**
topNCopy 
*/
void topNCopy(alias less, alias iterSwap = .iterSwap, SRange, TRange)(
    SRange source, TRange target)
{
    // make an initial heap in the target
    auto tb = begin(target), te = tb;
    auto sb = begin(source), se = end(source);
    for (; sb != se; ++sb)
    {
        if (te == end(target)) break;
        *te = *sb;
        ++te;
    }
    if (te < end(target)) target = range(tb, te);
    makeHeap!(less, iterSwap)(target);

    // now copy stuff into the target if it's smaller
    for (; sb != se; ++sb)
    {
        if (!less(*sb, *tb)) continue;
        *tb = *sb;
        heapify!(less, iterSwap)(target, tb);
    }
}

/**
partialSortCopy
*/
void partialSortCopy(alias less, alias iterSwap = .iterSwap, SRange, TRange)(
    SRange source, TRange target)
{
    topNCopy!(less, iterSwap)(source, target);
    sortHeap!(less, iterSwap)(target);
}

unittest
{
    auto r = Random(unpredictableSeed);
    int[] a = new int[uniform(r, 0, 1000)];
    foreach (i, ref e; a) e = i;
    randomShuffle(a, r);
    int[] b = new int[uniform(r, 0, a.length)];
    partialSortCopy!(binaryFun!("a < b"))(a, b);
    assert(isSorted!(binaryFun!("a < b"))(b));
}

// Internal random array generators

version(Unittest)
{
    private enum size_t maxArraySize = 50;
    private enum size_t minArraySize = maxArraySize - 1;

    private string[] rndstuff(T : string)()
    {
        static Random rnd;
        static bool first = true;
        if (first)
        {
            rnd = Random(unpredictableSeed);
            first = false;
        }
        string[] result =
            new string[uniform(rnd, minArraySize, maxArraySize)];
        string alpha = "abcdefghijABCDEFGHIJ";
        foreach (ref s; result)
        {
            foreach (i; 0 .. uniform!(uint)(rnd, 0u, 20u))
            {
                auto j = uniform(rnd, 0, alpha.length - 1);
                s ~= alpha[j];
            }
        }
        return result;
    }

    private int[] rndstuff(T : int)()
    {
        static Random rnd;
        static bool first = true;
        if (first)
        {
            rnd = Random(unpredictableSeed);
            first = false;
        }
        int[] result = new int[uniform(rnd, minArraySize, maxArraySize)];
        foreach (ref i; result)
        {
            i = uniform(rnd, -100, 100);
        }
        return result;
    }

    private double[] rndstuff(T : double)()
    {
        double[] result;
        foreach (i; rndstuff!(int)())
        {
            result ~= i / 50.;
        }
        return result;
    }
}
