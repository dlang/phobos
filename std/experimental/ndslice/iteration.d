/**
$(SCRIPT inhibitQuickIndex = 1;)

This is a submodule of $(LINK2 std_experimental_ndslice.html, std.experimental.ndslice).

Operators only change strides and lengths of a slice.
The range of a slice remains unmodified.
All operators return slice of the same type as the type of the argument.

$(BOOKTABLE $(H2 Transpose operators),

$(TR $(TH Function Name) $(TH Descriprottion))
$(T2 transposed, `100000.iota.sliced(3, 4, 5, 6, 7).transposed!(4, 0, 1).shape` returns `[7, 3, 4, 5, 6]`.)
$(T2 swapped, `1000.iota.sliced(3, 4, 5).swapped!(1, 2).shape` returns `[3, 5, 4]`.)
$(T2 everted, `1000.iota.sliced(3, 4, 5).everted.shape` returns `[5, 4, 3]`.)
)
See also $(SUBREF selection, evertPack).

$(BOOKTABLE $(H2 Iteration operators),

$(TR $(TH Function Name) $(TH Description))
$(T2 strided, `1000.iota.sliced(13, 40).strided!(0, 1)(2, 5).shape` equals to `[7, 8]`.)
$(T2 reversed, `slice.reversed!0` returns the slice with reversed direction of iteration for top level dimension.)
$(T2 allReversed, `20.iota.sliced(4, 5).allReversed` equals to `20.iota.retro.sliced(4, 5)`.)
)

$(BOOKTABLE $(H2 Other operators),
$(TR $(TH Function Name) $(TH Description))
$(T2 rotated, `10.iota.sliced(2, 3).rotated` equals to `[[2, 5], [1, 4], [0, 3]]`.)
)

$(H4 Drop operators)

$(LREF dropToHypercube)
$(LREF drop) $(LREF dropBack)
$(LREF dropOne) $(LREF dropBackOne)
$(LREF dropExactly) $(LREF dropBackExactly)
$(LREF allDrop) $(LREF allDropBack)
$(LREF allDropOne) $(LREF allDropBackOne)
$(LREF allDropExactly) $(LREF allDropBackExactly)

$(GRAMMAR
$(GNAME DropOperatorName):
    $(D dropToHypercube)
    $(GLINK DropRoot)
    $(GLINK DropRoot) $(GLINK DropSuffix)
    $(GLINK DropRoot) $(D Back)
    $(GLINK DropRoot) $(D Back) $(GLINK DropSuffix)
$(GNAME DropRoot):
    $(D drop)
    $(D allDrop)
$(GNAME DropSuffix):
    $(D One)
    $(D Exactly)
)

$(H2 Bifacial operators)

Some operators are bifacial,
i.e. they have two versions: one with template parameters, and another one
with function parameters. Versions with template parameters are preferable
because they allow compile time checks and can be optimized better.

$(BOOKTABLE ,

$(TR $(TH Function Name) $(TH Variadic) $(TH Template) $(TH Function))
$(T4 swapped, No, `slice.swapped!(2, 3)`, `slice.swapped(2, 3)`)
$(T4 rotated, No, `slice.rotated!(2, 3)(-1)`, `slice.rotated(2, 3, -1)`)
$(T4 strided, Yes/No, `slice.strided!(1, 2)(20, 40)`, `slice.strided(1, 20).strided(2, 40)`)
$(T4 transposed, Yes, `slice.transposed!(1, 4, 3)`, `slice.transposed(1, 4, 3)`)
$(T4 reversed, Yes, `slice.reversed!(0, 2)`, `slice.reversed(0, 2)`)
)

Bifacial interface of $(LREF drop), $(LREF dropBack)
$(LREF dropExactly), and $(LREF dropBackExactly)
is identical to that of $(LREF strided).

Bifacial interface of $(LREF dropOne) and $(LREF dropBackOne)
is identical to that of $(LREF reversed).

License:   $(WEB www.boost.org/LICENSE_1_0.txt, Boost License 1.0).

Authors:   Ilya Yaroshenko

Source:    $(PHOBOSSRC std/_experimental/_ndslice/_iteration.d)

Macros:
SUBMODULE = $(LINK2 std_experimental_ndslice_$1.html, std.experimental.ndslice.$1)
SUBREF = $(LINK2 std_experimental_ndslice_$1.html#.$2, $(TT $2))$(NBSP)
T2=$(TR $(TDNW $(LREF $1)) $(TD $+))
T4=$(TR $(TDNW $(LREF $1)) $(TD $2) $(TD $3) $(TD $4))
*/
module std.experimental.ndslice.iteration;

import std.traits;

import std.experimental.ndslice.internal;
import std.experimental.ndslice.slice; //: Slice;

private enum _swappedCode = q{
    with (slice)
    {
        auto tl = _lengths[dimensionA];
        auto ts = _strides[dimensionA];
        _lengths[dimensionA] = _lengths[dimensionB];
        _strides[dimensionA] = _strides[dimensionB];
        _lengths[dimensionB] = tl;
        _strides[dimensionB] = ts;
    }
    return slice;
};

/++
Swaps two dimensions.

Params:
    slice = input slice
    dimensionA = first dimension
    dimensionB = second dimension
Returns:
    n-dimensional slice of the same type
See_also: $(LREF everted), $(LREF transposed)
+/
template swapped(size_t dimensionA, size_t dimensionB)
{
    auto swapped(size_t N, Range)(Slice!(N, Range) slice)
    {
        {
            enum i = 0;
            alias dimension = dimensionA;
            mixin DimensionCTError;
        }
        {
            enum i = 1;
            alias dimension = dimensionB;
            mixin DimensionCTError;
        }
        mixin (_swappedCode);
    }
}

/// ditto
Slice!(N, Range) swapped(size_t N, Range)(Slice!(N, Range) slice, size_t dimensionA, size_t dimensionB)
in{
    {
        alias dimension = dimensionA;
        mixin (DimensionRTError);
    }
    {
        alias dimension = dimensionB;
        mixin (DimensionRTError);
    }
}
body
{
    mixin (_swappedCode);
}

/// ditto
Slice!(2, Range) swapped(Range)(Slice!(2, Range) slice)
body
{
    return slice.swapped!(0, 1);
}

/// Template
@safe @nogc pure nothrow unittest
{
    import std.experimental.ndslice.slice;
    import std.range: iota;
    assert((3 * 4 * 5 * 6).iota
        .sliced(3, 4, 5, 6)
        .swapped!(3, 1)
        .shape == cast(size_t[4])[3, 6, 5, 4]);
}

/// Function
@safe @nogc pure nothrow unittest
{
    import std.experimental.ndslice.slice;
    import std.range: iota;
    assert((3 * 4 * 5 * 6).iota
        .sliced(3, 4, 5, 6)
        .swapped(1, 3)
        .shape == cast(size_t[4])[3, 6, 5, 4]);
}

/// 2D
@safe @nogc pure nothrow unittest
{
    import std.experimental.ndslice.slice;
    import std.range: iota;
    assert(12.iota
        .sliced(3, 4)
        .swapped
        .shape == cast(size_t[2])[4, 3]);
}

private enum _rotatedCode = q{
    k &= 0b11;
    if (k == 0)
        return slice;
    if (k == 2)
        return slice.allReversed;
    static if (__traits(compiles, { enum _enum = dimensionA + dimensionB; }))
    {
        slice = slice.swapped!(dimensionA, dimensionB);
        if (k == 1)
            return slice.reversed!dimensionA;
        else
            return slice.reversed!dimensionB;
    }
    else
    {
        slice = slice.swapped (dimensionA, dimensionB);
        if (k == 1)
            return slice.reversed(dimensionA);
        else
            return slice.reversed(dimensionB);
    }
};

/++
Rotates two selected dimensions by `k*90` degrees.
The order of dimensions is important.
If the slice has two dimensions, the default direction is counterclockwise.

Params:
    slice = input slice
    dimensionA = first dimension
    dimensionB = second dimension
    k = rotation counter, can be negative
Returns:
    n-dimensional slice of the same type
+/
template rotated(size_t dimensionA, size_t dimensionB)
{
    auto rotated(size_t N, Range)(Slice!(N, Range) slice, sizediff_t k = 1)
    {
        {
            enum i = 0;
            alias dimension = dimensionA;
            mixin DimensionCTError;
        }
        {
            enum i = 1;
            alias dimension = dimensionB;
            mixin DimensionCTError;
        }
        mixin (_rotatedCode);
    }
}

/// ditto
Slice!(N, Range) rotated(size_t N, Range)(Slice!(N, Range) slice, size_t dimensionA, size_t dimensionB, sizediff_t k = 1)
in{
    {
        alias dimension = dimensionA;
        mixin (DimensionRTError);
    }
    {
        alias dimension = dimensionB;
        mixin (DimensionRTError);
    }
}
body
{
    mixin (_rotatedCode);
}

/// ditto
Slice!(2, Range) rotated(Range)(Slice!(2, Range) slice, sizediff_t k = 1)
body
{
    return slice.rotated!(0, 1)(k);
}

/// Template
@safe pure nothrow unittest
{
    import std.experimental.ndslice.slice;
    import std.range: iota;
    auto slice = 6.iota.sliced(2, 3);

    auto a = [[0, 1, 2],
              [3, 4, 5]];

    auto b = [[2, 5],
              [1, 4],
              [0, 3]];

    auto c = [[5, 4, 3],
              [2, 1, 0]];

    auto d = [[3, 0],
              [4, 1],
              [5, 2]];

    assert(slice.rotated       ( 4) == a);
    assert(slice.rotated!(0, 1)(-4) == a);
    assert(slice.rotated (1, 0,  8) == a);

    assert(slice.rotated            == b);
    assert(slice.rotated!(0, 1)(-3) == b);
    assert(slice.rotated (1, 0,  3) == b);

    assert(slice.rotated       ( 6) == c);
    assert(slice.rotated!(0, 1)( 2) == c);
    assert(slice.rotated (0, 1, -2) == c);

    assert(slice.rotated       ( 7) == d);
    assert(slice.rotated!(0, 1)( 3) == d);
    assert(slice.rotated (1, 0,   ) == d);
}

/++
Reverses the order of dimensions.

Params:
    slice = input slice
Returns:
    n-dimensional slice of the same type
See_also: $(LREF swapped), $(LREF transposed)
+/
Slice!(N, Range) everted(size_t N, Range)(auto ref Slice!(N, Range) slice)
{
    mixin _DefineRet;
    with (slice)
    {
         foreach (i; Iota!(0, N))
        {
            ret._lengths[N - 1 - i] = _lengths[i];
            ret._strides[N - 1 - i] = _strides[i];
        }
        foreach (i; Iota!(N, PureN))
        {
            ret._lengths[i] = _lengths[i];
            ret._strides[i] = _strides[i];
        }
        ret._ptr = _ptr;
        return ret;
    }
}

///
@safe @nogc pure nothrow unittest
{
    import std.experimental.ndslice.slice;
    import std.range: iota;
    assert(60.iota
        .sliced(3, 4, 5)
        .everted
        .shape == cast(size_t[3])[5, 4, 3]);
}

private enum _transposedCode = q{
    mixin _DefineRet;
    with (slice)
    {
        foreach (i; Iota!(0, N))
        {
            ret._lengths[i] = _lengths[perm[i]];
            ret._strides[i] = _strides[perm[i]];
        }
        foreach (i; Iota!(N, PureN))
        {
            ret._lengths[i] = _lengths[i];
            ret._strides[i] = _strides[i];
        }
        ret._ptr = _ptr;
        return ret;
    }
};

private size_t[N] completeTranspose(size_t N)(in size_t[] dimensions)
{
    assert(dimensions.length <= N);
    size_t[N] ctr;
    uint[N] mask;
    foreach (i, ref dimension; dimensions)
    {
        mask[dimension] = true;
        ctr[i] = dimension;
    }
    size_t j = dimensions.length;
    foreach (i, e; mask)
        if (e == false)
            ctr[j++] = i;
    return ctr;
}

/++
N-dimensional transpose operator.
Brings selected dimensions to the first position.
Params:
    slice = input slice
    Dimensions = indexes of dimensions to be brought to the first position
    dimensions = indexes of dimensions to be brought to the first position
    dimension = index of dimension to be brought to the first position
Returns:
    n-dimensional slice of the same type
See_also: $(LREF swapped), $(LREF everted)
+/
template transposed(Dimensions...)
    if (Dimensions.length)
{
    Slice!(N, Range) transposed(size_t N, Range)(auto ref Slice!(N, Range) slice)
    {
        mixin DimensionsCountCTError;
        foreach (i, dimension; Dimensions)
            mixin DimensionCTError;
        static assert(isValidPartialPermutation!N([Dimensions]),
            "Failed to complete permutation of dimensions " ~ Dimensions.stringof
            ~ tailErrorMessage!());
        enum perm = completeTranspose!N([Dimensions]);
        static assert(perm.isPermutation, __PRETTY_FUNCTION__ ~ ": internal error.");
        mixin (_transposedCode);
    }
}

///ditto
Slice!(N, Range) transposed(size_t N, Range)(auto ref Slice!(N, Range) slice, size_t dimension)
in
{
    mixin (DimensionRTError);
}
body
{
    size_t[1] permutation = void;
    permutation[0] = dimension;
    immutable perm = completeTranspose!N(permutation);
    assert(perm.isPermutation, __PRETTY_FUNCTION__  ~ ": internal error.");
    mixin (_transposedCode);
}

///ditto
Slice!(N, Range) transposed(size_t N, Range)(auto ref Slice!(N, Range) slice, in size_t[] dimensions...)
in
{
    mixin (DimensionsCountRTError);
    foreach (dimension; dimensions)
        mixin (DimensionRTError);
}
body
{
    assert(dimensions.isValidPartialPermutation!N,
        "Failed to complete permutation of dimensions."
        ~ tailErrorMessage!());
    immutable perm = completeTranspose!N(dimensions);
    assert(perm.isPermutation, __PRETTY_FUNCTION__ ~ ": internal error.");
    mixin (_transposedCode);
}

///ditto
Slice!(2, Range) transposed(Range)(auto ref Slice!(2, Range) slice)
{
    return .transposed!(1, 0)(slice);
}

/// Template
@safe @nogc pure nothrow unittest
{
    import std.experimental.ndslice.slice;
    import std.range: iota;
    assert((3 * 4 * 5 * 6 * 7).iota
        .sliced(3, 4, 5, 6, 7)
        .transposed!(4, 1, 0)
        .shape == cast(size_t[5])[7, 4, 3, 5, 6]);
}

/// Function
@safe @nogc pure nothrow unittest
{
    import std.experimental.ndslice.slice;
    import std.range: iota;
    assert((3 * 4 * 5 * 6 * 7).iota
        .sliced(3, 4, 5, 6, 7)
        .transposed(4, 1, 0)
        .shape == cast(size_t[5])[7, 4, 3, 5, 6]);
}

/// Single-argument function
@safe @nogc pure nothrow unittest
{
    import std.experimental.ndslice.slice;
    import std.range: iota;
    assert((3 * 4 * 5 * 6 * 7).iota
        .sliced(3, 4, 5, 6, 7)
        .transposed(4)
        .shape == cast(size_t[5])[7, 3, 4, 5, 6]);
}

/// `2`-dimensional transpose
@safe @nogc pure nothrow unittest
{
    import std.experimental.ndslice.slice;
    import std.range: iota;
    assert(12.iota
        .sliced(3, 4)
        .transposed
        .shape == cast(size_t[2])[4, 3]);
}

private enum _reversedCode = q{
    with (slice)
    {
        if (_lengths[dimension])
            _ptr += _strides[dimension] * (_lengths[dimension] - 1);
        _strides[dimension] = -_strides[dimension];
    }
};

/++
Reverses the direction of iteration for all dimensions.
Params:
    slice = input slice
Returns:
    n-dimensional slice of the same type
+/
Slice!(N, Range) allReversed(size_t N, Range)(Slice!(N, Range) slice)
{
    foreach (dimension; Iota!(0, N))
    {
        mixin (_reversedCode);
    }
    return slice;
}

///
@safe @nogc pure nothrow unittest
{
    import std.experimental.ndslice.slice;
    import std.range: iota, retro;
    auto a = 20.iota.sliced(4, 5).allReversed;
    auto b = 20.iota.retro.sliced(4, 5);
    assert(a == b);
}

/++
Reverses the direction of iteration for selected dimensions.

Params:
    slice = input slice
    Dimensions = indexes of dimensions to reverse order of iteration
    dimensions = indexes of dimensions to reverse order of iteration
    dimension = index of dimension to reverse order of iteration
Returns:
    n-dimensional slice of the same type
+/
template reversed(Dimensions...)
    if (Dimensions.length)
{
    auto reversed(size_t N, Range)(Slice!(N, Range) slice)
    {
        foreach (i, dimension; Dimensions)
        {
            mixin DimensionCTError;
            mixin (_reversedCode);
        }
        return slice;
    }
}

///ditto
Slice!(N, Range) reversed(size_t N, Range)(Slice!(N, Range) slice, size_t dimension)
in
{
    mixin (DimensionRTError);
}
body
{
    mixin (_reversedCode);
    return slice;
}

///ditto
Slice!(N, Range) reversed(size_t N, Range)(Slice!(N, Range) slice, in size_t[] dimensions...)
in
{
    foreach (dimension; dimensions)
        mixin (DimensionRTError);
}
body
{
    foreach (dimension; dimensions)
        mixin (_reversedCode);
    return slice;
}

///
pure nothrow unittest
{
    import std.experimental.ndslice.slice;
    auto slice = [1, 2, 3, 4].sliced(2, 2);
    assert(slice                    == [[1, 2], [3, 4]]);

    // Template
    assert(slice.reversed! 0        == [[3, 4], [1, 2]]);
    assert(slice.reversed! 1        == [[2, 1], [4, 3]]);
    assert(slice.reversed!(0, 1)    == [[4, 3], [2, 1]]);
    assert(slice.reversed!(1, 0)    == [[4, 3], [2, 1]]);
    assert(slice.reversed!(1, 1)    == [[1, 2], [3, 4]]);
    assert(slice.reversed!(0, 0, 0) == [[3, 4], [1, 2]]);

    // Function
    assert(slice.reversed (0)       == [[3, 4], [1, 2]]);
    assert(slice.reversed (1)       == [[2, 1], [4, 3]]);
    assert(slice.reversed (0, 1)    == [[4, 3], [2, 1]]);
    assert(slice.reversed (1, 0)    == [[4, 3], [2, 1]]);
    assert(slice.reversed (1, 1)    == [[1, 2], [3, 4]]);
    assert(slice.reversed (0, 0, 0) == [[3, 4], [1, 2]]);
}

@safe @nogc pure nothrow unittest
{
    import std.experimental.ndslice.slice;
    import std.experimental.ndslice.selection;
    import std.algorithm.comparison: equal;
    import std.range: iota, retro, chain;
    auto i0 = iota(0,  4); auto r0 = i0.retro;
    auto i1 = iota(4,  8); auto r1 = i1.retro;
    auto i2 = iota(8, 12); auto r2 = i2.retro;
    auto slice = 12.iota.sliced(3, 4);
    assert(slice                   .byElement.equal(chain(i0, i1, i2)));
    // Template
    assert(slice.reversed!(0)      .byElement.equal(chain(i2, i1, i0)));
    assert(slice.reversed!(1)      .byElement.equal(chain(r0, r1, r2)));
    assert(slice.reversed!(0, 1)   .byElement.equal(chain(r2, r1, r0)));
    assert(slice.reversed!(1, 0)   .byElement.equal(chain(r2, r1, r0)));
    assert(slice.reversed!(1, 1)   .byElement.equal(chain(i0, i1, i2)));
    assert(slice.reversed!(0, 0, 0).byElement.equal(chain(i2, i1, i0)));
    // Function
    assert(slice.reversed (0)      .byElement.equal(chain(i2, i1, i0)));
    assert(slice.reversed (1)      .byElement.equal(chain(r0, r1, r2)));
    assert(slice.reversed (0, 1)   .byElement.equal(chain(r2, r1, r0)));
    assert(slice.reversed (1, 0)   .byElement.equal(chain(r2, r1, r0)));
    assert(slice.reversed (1, 1)   .byElement.equal(chain(i0, i1, i2)));
    assert(slice.reversed (0, 0, 0).byElement.equal(chain(i2, i1, i0)));
}

private enum _stridedCode = q{
    assert(factor > 0, "factor must be positive"
        ~ tailErrorMessage!());
    immutable rem = slice._lengths[dimension] % factor;
    slice._lengths[dimension] /= factor;
    if (slice._lengths[dimension]) //do not remove `if (...)`
        slice._strides[dimension] *= factor;
    if (rem)
        slice._lengths[dimension]++;
};

/++
Multiplies the stride of the selected dimension by the factor.

Params:
    slice = input slice
    Dimensions = indexes of dimensions to be strided
    dimensions = indexes of dimensions to be strided
    factors = list of step extension factors
    factor = step extension factors
Returns:
    n-dimensional slice of the same type
+/
template strided(Dimensions...)
    if (Dimensions.length)
{
    auto strided(size_t N, Range)(Slice!(N, Range) slice, Repeat!(size_t, Dimensions.length) factors)
    body
    {
        foreach (i, dimension; Dimensions)
        {
            mixin DimensionCTError;
            immutable factor = factors[i];
            mixin (_stridedCode);
        }
        return slice;
    }
}

///ditto
Slice!(N, Range) strided(size_t N, Range)(Slice!(N, Range) slice, size_t dimension, size_t factor)
in
{
    mixin (DimensionRTError);
}
body
{
    mixin (_stridedCode);
    return slice;
}

///
pure nothrow unittest
{
    import std.experimental.ndslice.slice;
    auto slice
         = [0,1,2,3,    4,5,6,7,   8,9,10,11].sliced(3, 4);

    assert(slice
        == [[0,1,2,3], [4,5,6,7], [8,9,10,11]]);

    // Template
    assert(slice.strided!0(2)
        == [[0,1,2,3],            [8,9,10,11]]);

    assert(slice.strided!1(3)
        == [[0,    3], [4,    7], [8,     11]]);

    assert(slice.strided!(0, 1)(2, 3)
        == [[0,    3],            [8,     11]]);

    // Function
    assert(slice.strided(0, 2)
        == [[0,1,2,3],            [8,9,10,11]]);

    assert(slice.strided(1, 3)
        == [[0,    3], [4,    7], [8,     11]]);

    assert(slice.strided(0, 2).strided(1, 3)
        == [[0,    3],            [8,     11]]);
}

///
@safe @nogc pure nothrow unittest
{
    import std.range: iota;
    static assert(iota(13 * 40).sliced(13, 40).strided!(0, 1)(2, 5).shape == [7, 8]);
    static assert(93.iota.sliced(93).strided!(0, 0)(7, 3).shape == [5]);
}

@safe @nogc pure nothrow unittest
{
    import std.experimental.ndslice.slice;
    import std.experimental.ndslice.selection;
    import std.algorithm.comparison: equal;
    import std.range: iota, stride, chain;
    auto i0 = iota(0,  4); auto s0 = i0.stride(3);
    auto i1 = iota(4,  8); auto s1 = i1.stride(3);
    auto i2 = iota(8, 12); auto s2 = i2.stride(3);
    auto slice = 12.iota.sliced(3, 4);
    assert(slice              .byElement.equal(chain(i0, i1, i2)));
    // Template
    assert(slice.strided!0(2) .byElement.equal(chain(i0, i2)));
    assert(slice.strided!1(3) .byElement.equal(chain(s0, s1, s2)));
    assert(slice.strided!(0, 1)(2, 3).byElement.equal(chain(s0, s2)));
    // Function
    assert(slice.strided(0, 2).byElement.equal(chain(i0, i2)));
    assert(slice.strided(1, 3).byElement.equal(chain(s0, s1, s2)));
    assert(slice.strided(0, 2).strided(1, 3).byElement.equal(chain(s0, s2)));
}

/++
Convenience function which calls `slice.popFront!dimension()` for each dimension and returns the slice.

`allDropBackOne` provides the same functionality but calls `slice.popBack!dimension()` instead.

Params:
    slice = input slice
Returns:
    n-dimensional slice of the same type
+/
Slice!(N, Range) allDropOne(size_t N, Range)(Slice!(N, Range) slice)
{
    foreach (dimension; Iota!(0, N))
        slice.popFront!dimension;
    return slice;
}

///ditto
Slice!(N, Range) allDropBackOne(size_t N, Range)(Slice!(N, Range) slice)
{
    foreach (dimension; Iota!(0, N))
        slice.popBack!dimension;
    return slice;
}

///
@safe @nogc pure nothrow unittest
{
    import std.experimental.ndslice.slice;
    import std.range: iota, retro;
    auto a = 20.iota.sliced(4, 5);

    assert(a.allDropOne[0, 0] == 6);
    assert(a.allDropOne.shape == cast(size_t[2])[3, 4]);
    assert(a.allDropBackOne[$ - 1, $ - 1] == 13);
    assert(a.allDropBackOne.shape == cast(size_t[2])[3, 4]);
}

/++
These functions are similar to `allDrop` and `allDropBack` but they call
`slice.popFrontExactly!dimension(n)` and `slice.popBackExactly!dimension(n)` instead.

Note:
Unlike `allDrop`, `allDropExactly(n)` assume that the slice holds
a multi-dimensional cube with a size of at least n.
This makes `allDropExactly` faster than `allDrop`.
Only use `allDropExactly` when it is guaranteed that the slice holds
a multi-dimensional cube with a size of at least n.

Params:
    slice = input slice
    n = number of elements to drop
Returns:
    n-dimensional slice of the same type
+/
Slice!(N, Range) allDropExactly(size_t N, Range)(Slice!(N, Range) slice, size_t n)
{
    foreach (dimension; Iota!(0, N))
        slice.popFrontExactly!dimension(n);
    return slice;
}

///ditto
Slice!(N, Range) allDropBackExactly(size_t N, Range)(Slice!(N, Range) slice, size_t n)
{
    foreach (dimension; Iota!(0, N))
        slice.popBackExactly!dimension(n);
    return slice;
}

///
@safe @nogc pure nothrow unittest
{
    import std.experimental.ndslice.slice;
    import std.range: iota, retro;
    auto a = 20.iota.sliced(4, 5);

    assert(a.allDropExactly(2)[0, 0] == 12);
    assert(a.allDropExactly(2).shape == cast(size_t[2])[2, 3]);
    assert(a.allDropBackExactly(2)[$ - 1, $ - 1] == 7);
    assert(a.allDropBackExactly(2).shape == cast(size_t[2])[2, 3]);
}

/++
Convenience function which calls `slice.popFrontN!dimension(n)` for each dimension and returns the slice.

`allDropBack` provides the same functionality but calls `slice.popBackN!dimension(n)` instead.

Note:
`allDrop` and `allDropBack` remove up to n elements and stop when the slice is empty.

Params:
    slice = input slice
    n = number of elements to drop
Returns:
    n-dimensional slice of the same type
+/
Slice!(N, Range) allDrop(size_t N, Range)(Slice!(N, Range) slice, size_t n)
{
    foreach (dimension; Iota!(0, N))
        slice.popFrontN!dimension(n);
    return slice;
}

///ditto
Slice!(N, Range) allDropBack(size_t N, Range)(Slice!(N, Range) slice, size_t n)
{
    foreach (dimension; Iota!(0, N))
        slice.popBackN!dimension(n);
    return slice;
}

///
@safe @nogc pure nothrow unittest
{
    import std.experimental.ndslice.slice;
    import std.range: iota, retro;
    auto a = 20.iota.sliced(4, 5);

    assert(a.allDrop(2)[0, 0] == 12);
    assert(a.allDrop(2).shape == cast(size_t[2])[2, 3]);
    assert(a.allDropBack(2)[$ - 1, $ - 1] == 7);
    assert(a.allDropBack(2).shape == cast(size_t[2])[2, 3]);

    assert(a.allDrop    (5).shape == cast(size_t[2])[0, 0]);
    assert(a.allDropBack(5).shape == cast(size_t[2])[0, 0]);
}

/++
Convenience function which calls `slice.popFront!dimension()` for selected dimensions and returns the slice.

`dropBackOne` provides the same functionality but calls `slice.popBack!dimension()` instead.

Params:
    slice = input slice
Returns:
    n-dimensional slice of the same type
+/
template dropOne(Dimensions...)
    if (Dimensions.length)
{
    Slice!(N, Range) dropOne(size_t N, Range)(Slice!(N, Range) slice)
    {
        foreach (i, dimension; Dimensions)
        {
            mixin DimensionCTError;
            slice.popFront!dimension;
        }
        return slice;
    }
}

///ditto
Slice!(N, Range) dropOne(size_t N, Range)(Slice!(N, Range) slice, size_t dimension)
in
{
    mixin (DimensionRTError);
}
body
{
    slice.popFront(dimension);
    return slice;
}

///ditto
Slice!(N, Range) dropOne(size_t N, Range)(Slice!(N, Range) slice, in size_t[] dimensions...)
in
{
    foreach (dimension; dimensions)
        mixin (DimensionRTError);
}
body
{
    foreach (dimension; dimensions)
        slice.popFront(dimension);
    return slice;
}

///ditto
template dropBackOne(Dimensions...)
    if (Dimensions.length)
{
    Slice!(N, Range) dropBackOne(size_t N, Range)(Slice!(N, Range) slice)
    {
        foreach (i, dimension; Dimensions)
        {
            mixin DimensionCTError;
            slice.popBack!dimension;
        }
        return slice;
    }
}

///ditto
Slice!(N, Range) dropBackOne(size_t N, Range)(Slice!(N, Range) slice, size_t dimension)
in
{
    mixin (DimensionRTError);
}
body
{
    slice.popBack(dimension);
    return slice;
}

///ditto
Slice!(N, Range) dropBackOne(size_t N, Range)(Slice!(N, Range) slice, in size_t[] dimensions...)
in
{
    foreach (dimension; dimensions)
        mixin (DimensionRTError);
}
body
{
    foreach (dimension; dimensions)
        slice.popBack(dimension);
    return slice;
}


///
@safe @nogc pure nothrow unittest
{
    import std.experimental.ndslice.slice;
    import std.range: iota, retro;
    auto a = 20.iota.sliced(4, 5);

    assert(a.dropOne!(1, 0)[0, 0] == 6);
    assert(a.dropOne (1, 0)[0, 0] == 6);
    assert(a.dropOne!(1, 0).shape == cast(size_t[2])[3, 4]);
    assert(a.dropOne (1, 0).shape == cast(size_t[2])[3, 4]);
    assert(a.dropBackOne!(1, 0)[$ - 1, $ - 1] == 13);
    assert(a.dropBackOne (1, 0)[$ - 1, $ - 1] == 13);
    assert(a.dropBackOne!(1, 0).shape == cast(size_t[2])[3, 4]);
    assert(a.dropBackOne (1, 0).shape == cast(size_t[2])[3, 4]);

    assert(a.dropOne!(0, 0)[0, 0] == 10);
    assert(a.dropOne (0, 0)[0, 0] == 10);
    assert(a.dropOne!(0, 0).shape == cast(size_t[2])[2, 5]);
    assert(a.dropOne (0, 0).shape == cast(size_t[2])[2, 5]);
    assert(a.dropBackOne!(1, 1)[$ - 1, $ - 1] == 17);
    assert(a.dropBackOne (1, 1)[$ - 1, $ - 1] == 17);
    assert(a.dropBackOne!(1, 1).shape == cast(size_t[2])[4, 3]);
    assert(a.dropBackOne (1, 1).shape == cast(size_t[2])[4, 3]);
}

@safe @nogc pure nothrow unittest
{
    import std.experimental.ndslice.slice;
    import std.range: iota, retro;
    auto a = 20.iota.sliced(4, 5);

    assert(a.dropOne(0).dropOne(0)[0, 0] == 10);
    assert(a.dropOne(0).dropOne(0).shape == cast(size_t[2])[2, 5]);
    assert(a.dropBackOne(1).dropBackOne(1)[$ - 1, $ - 1] == 17);
    assert(a.dropBackOne(1).dropBackOne(1).shape == cast(size_t[2])[4, 3]);
}


/++
These functions are similar to `drop` and `dropBack` but they call
`slice.popFrontExactly!dimension(n)` and `slice.popBackExactly!dimension(n)` instead.

Note:
Unlike `drop`, `dropExactly` assumes that the slice holds enough elements in
the selected dimension.
This makes `dropExactly` faster than `drop`.

Params:
    slice = input slice
    ns = list of numbers of elements to drop
    n = number of elements to drop
Returns:
    n-dimensional slice of the same type
+/
template dropExactly(Dimensions...)
    if (Dimensions.length)
{
    Slice!(N, Range) dropExactly(size_t N, Range)(Slice!(N, Range) slice, Repeat!(size_t, Dimensions.length) ns)
    body
    {
        foreach (i, dimension; Dimensions)
        {
            mixin DimensionCTError;
            slice.popFrontExactly!dimension(ns[i]);
        }
        return slice;
    }
}

///ditto
Slice!(N, Range) dropExactly(size_t N, Range)(Slice!(N, Range) slice, size_t dimension, size_t n)
in
{
    mixin (DimensionRTError);
}
body
{
    slice.popFrontExactly(dimension, n);
    return slice;
}

///ditto
template dropBackExactly(Dimensions...)
    if (Dimensions.length)
{
    Slice!(N, Range) dropBackExactly(size_t N, Range)(Slice!(N, Range) slice, Repeat!(size_t, Dimensions.length) ns)
    body
    {
        foreach (i, dimension; Dimensions)
        {
            mixin DimensionCTError;
            slice.popBackExactly!dimension(ns[i]);
        }
        return slice;
    }
}

///ditto
Slice!(N, Range) dropBackExactly(size_t N, Range)(Slice!(N, Range) slice, size_t dimension, size_t n)
in
{
    mixin (DimensionRTError);
}
body
{
    slice.popBackExactly(dimension, n);
    return slice;
}

///
@safe @nogc pure nothrow unittest
{
    import std.experimental.ndslice.slice;
    import std.range: iota, retro;
    auto a = 20.iota.sliced(4, 5);

    assert(a.dropExactly    !(1, 0)(2, 3)[0, 0] == 17);
    assert(a.dropExactly    !(1, 0)(2, 3).shape == cast(size_t[2])[1, 3]);
    assert(a.dropBackExactly!(0, 1)(2, 3)[$ - 1, $ - 1] == 6);
    assert(a.dropBackExactly!(0, 1)(2, 3).shape == cast(size_t[2])[2, 2]);

    assert(a.dropExactly(1, 2).dropExactly(0, 3)[0, 0] == 17);
    assert(a.dropExactly(1, 2).dropExactly(0, 3).shape == cast(size_t[2])[1, 3]);
    assert(a.dropBackExactly(0, 2).dropBackExactly(1, 3)[$ - 1, $ - 1] == 6);
    assert(a.dropBackExactly(0, 2).dropBackExactly(1, 3).shape == cast(size_t[2])[2, 2]);
}

/++
Convenience function which calls `slice.popFrontN!dimension(n)` for the selected
dimension and returns the slice.

`dropBack` provides the same functionality but calls `slice.popBackN!dimension(n)` instead.

Note:
`drop` and `dropBack` remove up to n elements and stop when the slice is empty.

Params:
    slice = input slice
    ns = list of numbers of elements to drop
    n = number of elements to drop
Returns:
    n-dimensional slice of the same type
+/
template drop(Dimensions...)
    if (Dimensions.length)
{
    Slice!(N, Range) drop(size_t N, Range)(Slice!(N, Range) slice, Repeat!(size_t, Dimensions.length) ns)
    body
    {
        foreach (i, dimension; Dimensions)
        {
            mixin DimensionCTError;
            slice.popFrontN!dimension(ns[i]);
        }
        return slice;
    }
}

///ditto
Slice!(N, Range) drop(size_t N, Range)(Slice!(N, Range) slice, size_t dimension, size_t n)
in
{
    mixin (DimensionRTError);
}
body
{
    slice.popFrontN(dimension, n);
    return slice;
}

///ditto
template dropBack(Dimensions...)
    if (Dimensions.length)
{
    Slice!(N, Range) dropBack(size_t N, Range)(Slice!(N, Range) slice, Repeat!(size_t, Dimensions.length) ns)
    body
    {
        foreach (i, dimension; Dimensions)
        {
            mixin DimensionCTError;
            slice.popBackN!dimension(ns[i]);
        }
        return slice;
    }
}

///ditto
Slice!(N, Range) dropBack(size_t N, Range)(Slice!(N, Range) slice, size_t dimension, size_t n)
in
{
    mixin (DimensionRTError);
}
body
{
    slice.popBackN(dimension, n);
    return slice;
}


///
@safe @nogc pure nothrow unittest
{
    import std.experimental.ndslice.slice;
    import std.range: iota, retro;
    auto a = 20.iota.sliced(4, 5);

    assert(a.drop    !(1, 0)(2, 3)[0, 0] == 17);
    assert(a.drop    !(1, 0)(2, 3).shape == cast(size_t[2])[1, 3]);
    assert(a.dropBack!(0, 1)(2, 3)[$ - 1, $ - 1] == 6);
    assert(a.dropBack!(0, 1)(2, 3).shape == cast(size_t[2])[2, 2]);
    assert(a.dropBack!(0, 1)(5, 5).shape == cast(size_t[2])[0, 0]);


    assert(a.drop(1, 2).drop(0, 3)[0, 0] == 17);
    assert(a.drop(1, 2).drop(0, 3).shape == cast(size_t[2])[1, 3]);
    assert(a.dropBack(0, 2).dropBack(1, 3)[$ - 1, $ - 1] == 6);
    assert(a.dropBack(0, 2).dropBack(1, 3).shape == cast(size_t[2])[2, 2]);
    assert(a.dropBack(0, 5).dropBack(1, 5).shape == cast(size_t[2])[0, 0]);
}

/++
Returns maximal multidimensional cube.

Params:
    slice = input slice
Returns:
    n-dimensional slice of the same type
+/
Slice!(N, Range) dropToHypercube(size_t N, Range)(Slice!(N, Range) slice)
body
{
    size_t length = slice._lengths[0];
    foreach (i; Iota!(1, N))
        if (length > slice._lengths[i])
            length = slice._lengths[i];
    foreach (i; Iota!(0, N))
        slice._lengths[i] = length;
    return slice;
}

///
@safe @nogc pure nothrow unittest
{
    import std.experimental.ndslice.slice;
    import std.range: iota, retro;
    assert((5 * 3 * 6 * 7).iota
        .sliced(5, 3, 6, 7)
        .dropToHypercube
        .shape == cast(size_t[4])[3, 3, 3, 3]);
}
