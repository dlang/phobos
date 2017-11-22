/**
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

/**
 * Calculates variance of a range of number-like elements. Finds either the
 * population variance or the sample variance based on the `population` argument.
 *
 * If the range has less than 3 elements, `T.init` will be returned.
 *
 * This function is $(BIGOH r.length).
 *
 * Params:
 *     r = An $(REF_ALTTEXT input range, isInputRange, std,range,primitives)
 *     of number-like elements
 *     population = If `true` gives the population variance and not the sample
 *     variance
 *     seed = For user defined types. Should be equivalent to `0`.
 * Returns:
 *     If `r` has three or more elements, the variance of `r`, as type `T`.
 *
 *     Otherwise, `T.init` is returned.
 */
T variance(R, T = double)(R r, bool population = false)
if (isInputRange!R &&
    isNumeric!(ElementType!R) &&
    isNumeric!(T) &&
    !isInfinite!R)
{
    Unqual!T mean = 0;
    Unqual!T var = 0;

    return varianceImpl(r, mean, var, population);
}

/// ditto
T variance(R, T)(R r, T seed, bool population = false)
if (isInputRange!R &&
    !isInfinite!R &&
    is(typeof(r.front + seed)) &&
    is(typeof(r.front / size_t(1))))
{
    Unqual!T mean = seed;
    Unqual!T var = seed;

    return varianceImpl(r, mean, var, population);
}

private T varianceImpl(R, T)(R r, ref T mean, ref T var, bool population)
{
    if (r.empty)
        return T.init;

    // giving the variance with one or two elements is incorrect
    static if (hasLength!R)
        if (r.length < 3)
            return T.init;

    size_t i = 1;

    // Welford’s single pass variance method
    foreach (e; r)
    {
        Unqual!T oldMean = mean;
        mean = mean + (e - mean) / i++;
        var = var + (e - mean) * (e - oldMean);
    }

    static if (!hasLength!R)
        if (i == 3)
            return T.init;

    if (population)
        return var / i;

    return var / (i - 1);
}

///
@safe pure nothrow unittest
{
    import std.math : approxEqual, isNaN;
    auto arr1 = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9];
    auto arr2 = [1, 10, 40, 15, 4, 5, 22];

    // sample variance
    assert(arr1.variance.approxEqual(8.25));
    assert(arr2.variance.approxEqual(158.12));

    // whole population variance
    assert(arr1.variance(true).approxEqual(7.5));
    assert(arr2.variance(true).approxEqual(138.357));

    // ranges with less than three elements return T.init
    assert(arr1[0 .. 0].variance.isNaN);
    assert(arr1[0 .. 2].variance.isNaN);
}

@system pure unittest
{
    import std.bigint : BigInt;

    auto bigint_arr = [BigInt("1"), BigInt("2"), BigInt("3"), BigInt("4"), BigInt("5")];
    assert(bigint_arr.variance(BigInt(0)) == 6);
    assert(bigint_arr.variance(BigInt(0), true) == 5);

    assert(bigint_arr[0 .. 0].variance(BigInt(0)) == BigInt.init);
    assert(bigint_arr[0 .. 2].variance(BigInt(0)) == BigInt.init);
}

@system pure unittest
{
    import std.bigint : BigInt;
    import std.internal.test.dummyrange : ReferenceInputRange;
    import std.math : approxEqual;
    import std.stdio;

    auto r1 = new ReferenceInputRange!int([0, 1, 2, 3, 4, 5, 6, 7, 8, 9]);
    auto r2 = new ReferenceInputRange!BigInt([
        BigInt("1"), BigInt("2"), BigInt("3"), BigInt("4"), BigInt("5")
    ]);

    assert(r1.variance.approxEqual(8.25));
    assert(r2.variance(BigInt(0)) == 6);
}

// test nogc
@safe @nogc pure nothrow unittest
{
    import std.math : approxEqual;
    static immutable arr1 = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9];
    assert(arr1.variance.approxEqual(8.25));
}
