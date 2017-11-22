/**
 * This is a submodule of $(MREF std, algorithm).
 *
 * --This doc is to-do until adding this module is approved--
 */
module std.algorithm.stats;

import std.traits;
import std.range.primitives;

/**
Finds the mean (colloquially known as the average) of a range.

For built-in numerical types, accurate Knuth & Welford mean calculation
is used. For user-defined types, element by element summation is used.
Additionally an extra parameter `seed` is needed in order to correctly
seed the summation with the equivalent to `0`.

The first overload of this function will return `T.init` if the range
is empty. However, the second overload will return `seed` on empty ranges.

This function is $(BIGOH r.length).

Params:
    r = An $(REF_ALTTEXT input range, isInputRange, std,range,primitives)
    seed = For user defined types. Should be equivalent to `0`.

Returns:
    The mean of `r` when `r` is non-empty.
*/
T mean(T = double, R)(R r)
if (isInputRange!R &&
    isNumeric!(ElementType!R) &&
    !isInfinite!R)
{
    if (r.empty)
        return T.init;

    Unqual!T meanRes = 0;
    size_t i = 1;

    // Knuth & Welford mean calculation
    // division per element is slower, but more accurate
    for (; !r.empty; r.popFront())
    {
        T delta = r.front - meanRes;
        meanRes += delta / i++;
    }

    return meanRes;
}

/// ditto
auto mean(R, T)(R r, T seed)
if (isInputRange!R &&
    !isNumeric!(ElementType!R) &&
    is(typeof(r.front + seed)) &&
    is(typeof(r.front / size_t(1))) &&
    !isInfinite!R)
{
    import std.algorithm.iteration : sum, reduce;

    // per item division vis-a-vis the previous overload is too
    // inaccurate for integer division, which the user defined
    // types might be representing
    static if (hasLength!R)
    {
        if (r.length == 0)
            return seed;

        return sum(r, seed) / r.length;
    }
    else
    {
        import std.typecons : tuple;

        if (r.empty)
            return seed;

        auto pair = reduce!((a, b) => tuple(a[0] + 1, a[1] + b))
            (tuple(size_t(0), seed), r);
        return pair[1] / pair[0];
    }
}

///
@safe @nogc pure nothrow unittest
{
    import std.math : approxEqual, isNaN;

    static immutable arr1 = [1, 2, 3];
    static immutable arr2 = [1.5, 2.5, 12.5];

    assert(arr1.mean.approxEqual(2));
    assert(arr2.mean.approxEqual(5.5));

    assert(arr1[0 .. 0].mean.isNaN);
}

@safe pure nothrow unittest
{
    import std.internal.test.dummyrange : ReferenceInputRange;
    import std.math : approxEqual;

    auto r1 = new ReferenceInputRange!int([1, 2, 3]);
    assert(r1.mean.approxEqual(2));

    auto r2 = new ReferenceInputRange!double([1.5, 2.5, 12.5]);
    assert(r2.mean.approxEqual(5.5));
}

// Test user defined types
@system pure unittest
{
    import std.bigint : BigInt;
    import std.internal.test.dummyrange : ReferenceInputRange;
    import std.math : approxEqual;

    auto bigint_arr = [BigInt("1"), BigInt("2"), BigInt("3"), BigInt("6")];
    auto bigint_arr2 = new ReferenceInputRange!BigInt([
        BigInt("1"), BigInt("2"), BigInt("3"), BigInt("6")
    ]);
    assert(bigint_arr.mean(BigInt(0)) == BigInt("3"));
    assert(bigint_arr2.mean(BigInt(0)) == BigInt("3"));

    BigInt[] bigint_arr3 = [];
    assert(bigint_arr3.mean(BigInt(0)) == BigInt(0));

    struct MyFancyDouble
    {
       double v;
       alias v this;
    }

    // both overloads
    auto d_arr = [MyFancyDouble(10), MyFancyDouble(15), MyFancyDouble(30)];
    assert(mean!(double)(cast(double[]) d_arr).approxEqual(18.333));
    assert(mean(d_arr, MyFancyDouble(0)).approxEqual(18.333));
}