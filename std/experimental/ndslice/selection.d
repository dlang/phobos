/**
$(SCRIPT inhibitQuickIndex = 1;)

This is a submodule of $(MREF std, experimental, ndslice).

Selectors create new views and iteration patterns over the same data, without copying.

$(H2 Subspace selectors)

Subspace selectors serve to generalize and combine other selectors easily.
For a slice of `Slice!(N, Range)` type `slice.pack!K` creates a slice of
slices of `Slice!(N-K, Slice!(K+1, Range))` type by packing
the last `K` dimensions of the top dimension pack,
and the type of element of `slice.byElement` is `Slice!(K, Range)`.
Another way to use $(LREF pack) is transposition of dimension packs using
$(LREF evertPack). Examples of use of subspace selectors are available for selectors,
$(SUBREF slice, Slice.shape), and $(SUBREF slice, Slice.elementsCount).

$(BOOKTABLE ,

$(TR $(TH Function Name) $(TH Description))
$(T2 pack     , returns slice of slices)
$(T2 unpack   , merges all dimension packs)
$(T2 evertPack, reverses dimension packs)
)

$(BOOKTABLE $(H2 Selectors),

$(TR $(TH Function Name) $(TH Description))
$(T2 blocks, n-dimensional slice composed of n-dimensional non-overlapping blocks.
    If the slice has two dimensions, it is a block matrix.)
$(T2 byElement, flat, random access range of all elements with `index` property)
$(T2 byElementInStandardSimplex, an input range of all elements in standard simplex of hypercube with `index` property.
    If the slice has two dimensions, it is a range of all elements of upper left triangular matrix.)
$(T2 diagonal, 1-dimensional slice composed of diagonal elements)
$(T2 indexSlice, lazy slice with initial multidimensional index)
$(T2 iotaSlice, lazy slice with initial flattened (continuous) index)
$(T2 mapSlice, lazy multidimensional functional map)
$(T2 repeatSlice, slice with identical values)
$(T2 reshape, new slice with changed dimensions for the same data)
$(T2 windows, n-dimensional slice of n-dimensional overlapping windows.
    If the slice has two dimensions, it is a sliding window.)
)

License:   $(HTTP www.boost.org/LICENSE_1_0.txt, Boost License 1.0).

Authors:   Ilya Yaroshenko

Source:    $(PHOBOSSRC std/_experimental/_ndslice/_selection.d)

Macros:
SUBREF = $(REF_ALTTEXT $(TT $2), $2, std,experimental, ndslice, $1)$(NBSP)
T2=$(TR $(TDNW $(LREF $1)) $(TD $+))
T4=$(TR $(TDNW $(LREF $1)) $(TD $2) $(TD $3) $(TD $4))
*/
/// @@@DEPRECATED_2017-04@@@
deprecated("Please use mir-algorithm DUB package: http://github.com/libmir/mir-algorithm")
module std.experimental.ndslice.selection;

import std.traits;
import std.meta; //: allSatisfy;

import std.experimental.ndslice.internal;
import std.experimental.ndslice.slice; //: Slice;

@fmb:

/++
Creates a packed slice, i.e. slice of slices.
The function does not carry out any calculations, it simply returns the same
binary data presented differently.

Params:
    K = sizes of dimension packs
Returns:
    `pack!K` returns `Slice!(N-K, Slice!(K+1, Range))`;
    `slice.pack!(K1, K2, ..., Kn)` is the same as `slice.pack!K1.pack!K2. ... pack!Kn`.
+/
template pack(K...)
{
    static if (!allSatisfy!(isSize_t, K))
        alias pack = .pack!(staticMap!(toSize_t, K));
    else
    @fmb auto pack(size_t N, Range)(Slice!(N, Range) slice)
    {
        template Template(size_t NInner, Range, R...)
        {
            static if (R.length > 0)
            {
                static if (NInner > R[0])
                    alias Template = Template!(NInner - R[0], Slice!(R[0] + 1, Range), R[1 .. $]);
                else
                static assert(0,
                    "Sum of all lengths of packs " ~ K.stringof
                    ~ " should be less than N = "~ N.stringof
                    ~ tailErrorMessage!());
            }
            else
            {
                alias Template = Slice!(NInner, Range);
            }
        }
        with (slice) return Template!(N, Range, K)(_lengths, _strides, _ptr);
    }
}

///
@safe @nogc pure nothrow unittest
{
    import std.experimental.ndslice : sliced, Slice, pack;
    import std.range : iota;

    auto r = (3 * 4 * 5 * 6).iota;
    auto a = r.sliced(3, 4, 5, 6);
    auto b = a.pack!2;

    static immutable res1 = [3, 4];
    static immutable res2 = [5, 6];
    assert(b.shape == res1);
    assert(b[0, 0].shape == res2);
    assert(a == b);
    static assert(is(typeof(b) == typeof(a.pack!2)));
    static assert(is(typeof(b) == Slice!(2, Slice!(3, typeof(r)))));
}

@safe @nogc pure nothrow unittest
{
    import std.experimental.ndslice.slice;
    import std.range.primitives : ElementType;
    import std.range : iota;
    auto r = (3 * 4 * 5 * 6 * 7 * 8 * 9 * 10 * 11).iota;
    auto a = r.sliced(3, 4, 5, 6, 7, 8, 9, 10, 11);
    auto b = a.pack!(2, 3); // same as `a.pack!2.pack!3`
    auto c = b[1, 2, 3, 4];
    auto d = c[5, 6, 7];
    auto e = d[8, 9];
    auto g = a[1, 2, 3, 4, 5, 6, 7, 8, 9];
    assert(e == g);
    assert(a == b);
    assert(c == a[1, 2, 3, 4]);
    alias R = typeof(r);
    static assert(is(typeof(b) == typeof(a.pack!2.pack!3)));
    static assert(is(typeof(b) == Slice!(4, Slice!(4, Slice!(3, R)))));
    static assert(is(typeof(c) == Slice!(3, Slice!(3, R))));
    static assert(is(typeof(d) == Slice!(2, R)));
    static assert(is(typeof(e) == ElementType!R));
}

@safe @nogc pure nothrow unittest
{
    auto a = iotaSlice(3, 4, 5, 6, 7, 8, 9, 10, 11);
    auto b = a.pack!(2, 3);
    static assert(b.shape.length == 4);
    static assert(b.structure.lengths.length == 4);
    static assert(b.structure.strides.length == 4);
    static assert(b
        .byElement.front
        .shape.length == 3);
    static assert(b
        .byElement.front
        .byElement.front
        .shape.length == 2);
    // test save
    b.byElement.save.popFront;
    static assert(b
        .byElement.front
        .shape.length == 3);
}

/++
Unpacks a packed slice.

The function does not carry out any calculations, it simply returns the same
binary data presented differently.

Params:
    slice = packed slice
Returns:
    unpacked slice

See_also: $(LREF pack), $(LREF evertPack)
+/
Slice!(N, Range).PureThis unpack(size_t N, Range)(Slice!(N, Range) slice)
{
    with (slice) return PureThis(_lengths, _strides, _ptr);
}

///
pure nothrow unittest
{
    auto a = iotaSlice(3, 4, 5, 6, 7, 8, 9, 10, 11);
    auto b = a.pack!(2, 3).unpack();
    static assert(is(typeof(a) == typeof(b)));
    assert(a == b);
}

/++
Reverses the order of dimension packs.
This function is used in a functional pipeline with other selectors.

Params:
    slice = packed slice
Returns:
    packed slice

See_also: $(LREF pack), $(LREF unpack)
+/
SliceFromSeq!(Slice!(N, Range).PureRange, NSeqEvert!(Slice!(N, Range).NSeq))
evertPack(size_t N, Range)(Slice!(N, Range) slice)
{
    mixin _DefineRet;
    static assert(Ret.NSeq.length > 0);
    with (slice)
    {
        alias C = Snowball!(Parts!NSeq);
        alias D = Reverse!(Snowball!(Reverse!(Parts!NSeq)));
        foreach (i, _; NSeq)
        {
            foreach (j; Iota!(0, C[i + 1] - C[i]))
            {
                ret._lengths[j + D[i + 1]] = _lengths[j + C[i]];
                ret._strides[j + D[i + 1]] = _strides[j + C[i]];
            }
        }
        ret._ptr = _ptr;
        return ret;
    }
}

///
@safe @nogc pure nothrow unittest
{
    import std.experimental.ndslice.iteration : transposed;
    auto slice = iotaSlice(3, 4, 5, 6, 7, 8, 9, 10, 11);
    assert(slice
        .pack!2
        .evertPack
        .unpack
             == slice.transposed!(
                slice.shape.length-2,
                slice.shape.length-1));
}

///
pure nothrow unittest
{
    import std.experimental.ndslice.slice;
    import std.experimental.ndslice.iteration : transposed;
    import std.range.primitives : ElementType;
    import std.range : iota;
    import std.algorithm.comparison : equal;
    auto r = (3 * 4 * 5 * 6 * 7 * 8 * 9 * 10 * 11).iota;
    auto a = r.sliced(3, 4, 5, 6, 7, 8, 9, 10, 11);
    auto b = a
        .pack!(2, 3)
        .evertPack;
    auto c = b[8, 9];
    auto d = c[5, 6, 7];
    auto e = d[1, 2, 3, 4];
    auto g = a[1, 2, 3, 4, 5, 6, 7, 8, 9];
    assert(e == g);
    assert(a == b.evertPack);
    assert(c == a.transposed!(7, 8, 4, 5, 6)[8, 9]);
    alias R = typeof(r);
    static assert(is(typeof(b) == Slice!(2, Slice!(4, Slice!(5, R)))));
    static assert(is(typeof(c) == Slice!(3, Slice!(5, R))));
    static assert(is(typeof(d) == Slice!(4, R)));
    static assert(is(typeof(e) == ElementType!R));
}

@safe @nogc pure nothrow unittest
{
    import std.experimental.ndslice.slice;
    static assert(is(typeof(slice!int(20)
        .evertPack)
         == Slice!(1LU, int*)));
    static assert(is(typeof(slice!int(20)
        .sliced(3)
        .evertPack)
         == Slice!(2LU, int*)));
    static assert(is(typeof(slice!int(20)
        .sliced(1,2,3)
        .sliced(3)
        .evertPack)
         == Slice!(3LU, Slice!(2LU, int*))));
    static assert(is(typeof(slice!int(20)
        .sliced(1,2,3)
        .evertPack)
         == Slice!(4LU, int*)));
}

/++
Returns a 1-dimensional slice over the main diagonal of an n-dimensional slice.
`diagonal` can be generalized with other selectors such as
$(LREF blocks) (diagonal blocks) and $(LREF windows) (multi-diagonal slice).

Params:
    N = dimension count
    slice = input slice
Returns:
    1-dimensional slice composed of diagonal elements
+/
Slice!(1, Range) diagonal(size_t N, Range)(Slice!(N, Range) slice)
{
    auto NewN = slice.PureN - N + 1;
    mixin _DefineRet;
    ret._lengths[0] = slice._lengths[0];
    ret._strides[0] = slice._strides[0];
    foreach (i; Iota!(1, N))
    {
        if (ret._lengths[0] > slice._lengths[i])
            ret._lengths[0] = slice._lengths[i];
        ret._strides[0] += slice._strides[i];
    }
    foreach (i; Iota!(1, ret.PureN))
    {
        ret._lengths[i] = slice._lengths[i + N - 1];
        ret._strides[i] = slice._strides[i + N - 1];
    }
    ret._ptr = slice._ptr;
    return ret;
}

/// Matrix, main diagonal
@safe @nogc pure nothrow unittest
{
    //  -------
    // | 0 1 2 |
    // | 3 4 5 |
    //  -------
    //->
    // | 0 4 |
    static immutable d = [0, 4];
    assert(iotaSlice(2, 3).diagonal == d);
}

/// Non-square matrix
@safe @nogc pure nothrow unittest
{
    import std.algorithm.comparison : equal;
    import std.range : only;

    //  -------
    // | 0 1 |
    // | 2 3 |
    // | 4 5 |
    //  -------
    //->
    // | 0 3 |

    assert(iotaSlice(3, 2)
        .diagonal
        .equal(only(0, 3)));
}

/// Loop through diagonal
pure nothrow unittest
{
    import std.experimental.ndslice.slice;

    auto slice = slice!int(3, 3);
    int i;
    foreach (ref e; slice.diagonal)
        e = ++i;
    assert(slice == [
        [1, 0, 0],
        [0, 2, 0],
        [0, 0, 3]]);
}

/// Matrix, subdiagonal
@safe @nogc pure nothrow unittest
{
    import std.experimental.ndslice.iteration : dropOne;
    //  -------
    // | 0 1 2 |
    // | 3 4 5 |
    //  -------
    //->
    // | 1 5 |
    static immutable d = [1, 5];
    assert(iotaSlice(2, 3).dropOne!1.diagonal == d);
}

/// Matrix, antidiagonal
@safe @nogc pure nothrow unittest
{
    import std.experimental.ndslice.iteration : dropToHypercube, reversed;
    //  -------
    // | 0 1 2 |
    // | 3 4 5 |
    //  -------
    //->
    // | 1 3 |
    static immutable d = [1, 3];
    assert(iotaSlice(2, 3).dropToHypercube.reversed!1.diagonal == d);
}

/// 3D, main diagonal
@safe @nogc pure nothrow unittest
{
    //  -----------
    // |  0   1  2 |
    // |  3   4  5 |
    //  - - - - - -
    // |  6   7  8 |
    // |  9  10 11 |
    //  -----------
    //->
    // | 0 10 |
    static immutable d = [0, 10];
    assert(iotaSlice(2, 2, 3).diagonal == d);
}

/// 3D, subdiagonal
@safe @nogc pure nothrow unittest
{
    import std.experimental.ndslice.iteration : dropOne;
    //  -----------
    // |  0   1  2 |
    // |  3   4  5 |
    //  - - - - - -
    // |  6   7  8 |
    // |  9  10 11 |
    //  -----------
    //->
    // | 1 11 |
    static immutable d = [1, 11];
    assert(iotaSlice(2, 2, 3).dropOne!2.diagonal == d);
}

/// 3D, diagonal plain
@nogc @safe pure nothrow unittest
{
    //  -----------
    // |  0   1  2 |
    // |  3   4  5 |
    // |  6   7  8 |
    //  - - - - - -
    // |  9  10 11 |
    // | 12  13 14 |
    // | 15  16 17 |
    //  - - - - - -
    // | 18  20 21 |
    // | 22  23 24 |
    // | 24  25 26 |
    //  -----------
    //->
    //  -----------
    // |  0   4  8 |
    // |  9  13 17 |
    // | 18  23 26 |
    //  -----------

    static immutable d =
        [[ 0,  4,  8],
         [ 9, 13, 17],
         [18, 22, 26]];

    auto slice = iotaSlice(3, 3, 3)
        .pack!2
        .evertPack
        .diagonal
        .evertPack;

    assert(slice == d);
}

/++
Returns an n-dimensional slice of n-dimensional non-overlapping blocks.
`blocks` can be generalized with other selectors.
For example, `blocks` in combination with $(LREF diagonal) can be used to get a slice of diagonal blocks.
For overlapped blocks, combine $(LREF windows) with $(SUBREF iteration, strided).

Params:
    N = dimension count
    slice = slice to be split into blocks
    lengths = dimensions of block, residual blocks are ignored
Returns:
    packed `N`-dimensional slice composed of `N`-dimensional slices
+/
Slice!(N, Slice!(N+1, Range)) blocks(size_t N, Range)(Slice!(N, Range) slice, size_t[N] lengths...)
in
{
    foreach (i, length; lengths)
        assert(length > 0, "length of dimension = " ~ i.stringof ~ " must be positive"
            ~ tailErrorMessage!());
}
body
{
    mixin _DefineRet;
    foreach (dimension; Iota!(0, N))
    {
        ret._lengths[dimension] = slice._lengths[dimension] / lengths[dimension];
        ret._strides[dimension] = slice._strides[dimension];
        if (ret._lengths[dimension]) //do not remove `if (...)`
            ret._strides[dimension] *= lengths[dimension];
        ret._lengths[dimension + N] = lengths[dimension];
        ret._strides[dimension + N] = slice._strides[dimension];
    }
    foreach (dimension; Iota!(N, slice.PureN))
    {
        ret._lengths[dimension + N] = slice._lengths[dimension];
        ret._strides[dimension + N] = slice._strides[dimension];
    }
    ret._ptr = slice._ptr;
    return ret;
}

///
pure nothrow unittest
{
    import std.experimental.ndslice.slice;
    auto slice = slice!int(5, 8);
    auto blocks = slice.blocks(2, 3);
    int i;
    foreach (block; blocks.byElement)
        block[] = ++i;

    assert(blocks ==
        [[[[1, 1, 1], [1, 1, 1]],
          [[2, 2, 2], [2, 2, 2]]],
         [[[3, 3, 3], [3, 3, 3]],
          [[4, 4, 4], [4, 4, 4]]]]);

    assert(    slice ==
        [[1, 1, 1,  2, 2, 2,  0, 0],
         [1, 1, 1,  2, 2, 2,  0, 0],

         [3, 3, 3,  4, 4, 4,  0, 0],
         [3, 3, 3,  4, 4, 4,  0, 0],

         [0, 0, 0,  0, 0, 0,  0, 0]]);
}

/// Diagonal blocks
pure nothrow unittest
{
    import std.experimental.ndslice.slice;
    auto slice = slice!int(5, 8);
    auto blocks = slice.blocks(2, 3);
    auto diagonalBlocks = blocks.diagonal.unpack;

    diagonalBlocks[0][] = 1;
    diagonalBlocks[1][] = 2;

    assert(diagonalBlocks ==
        [[[1, 1, 1], [1, 1, 1]],
         [[2, 2, 2], [2, 2, 2]]]);

    assert(blocks ==
        [[[[1, 1, 1], [1, 1, 1]],
          [[0, 0, 0], [0, 0, 0]]],
         [[[0, 0, 0], [0, 0, 0]],
          [[2, 2, 2], [2, 2, 2]]]]);

    assert(slice ==
        [[1, 1, 1,  0, 0, 0,  0, 0],
         [1, 1, 1,  0, 0, 0,  0, 0],

         [0, 0, 0,  2, 2, 2,  0, 0],
         [0, 0, 0,  2, 2, 2,  0, 0],

         [0, 0, 0, 0, 0, 0, 0, 0]]);
}

/// Matrix divided into vertical blocks
pure nothrow unittest
{
    import std.experimental.ndslice.slice;
    auto slice = slice!int(5, 13);
    auto blocks = slice
        .pack!1
        .evertPack
        .blocks(3)
        .unpack
        .pack!2;

    int i;
    foreach (block; blocks.byElement)
        block[] = ++i;

    assert(slice ==
        [[1, 1, 1,  2, 2, 2,  3, 3, 3,  4, 4, 4,  0],
         [1, 1, 1,  2, 2, 2,  3, 3, 3,  4, 4, 4,  0],
         [1, 1, 1,  2, 2, 2,  3, 3, 3,  4, 4, 4,  0],
         [1, 1, 1,  2, 2, 2,  3, 3, 3,  4, 4, 4,  0],
         [1, 1, 1,  2, 2, 2,  3, 3, 3,  4, 4, 4,  0]]);
}

/++
Returns an n-dimensional slice of n-dimensional overlapping windows.
`windows` can be generalized with other selectors.
For example, `windows` in combination with $(LREF diagonal) can be used to get a multi-diagonal slice.

Params:
    N = dimension count
    slice = slice to be iterated
    lengths = dimensions of windows
Returns:
    packed `N`-dimensional slice composed of `N`-dimensional slices
+/
Slice!(N, Slice!(N+1, Range)) windows(size_t N, Range)(Slice!(N, Range) slice, size_t[N] lengths...)
in
{
    foreach (i, length; lengths)
        assert(length > 0, "length of dimension = " ~ i.stringof ~ " must be positive"
            ~ tailErrorMessage!());
}
body
{
    mixin _DefineRet;
    foreach (dimension; Iota!(0, N))
    {
        ret._lengths[dimension] = slice._lengths[dimension] >= lengths[dimension] ?
                                  slice._lengths[dimension] - lengths[dimension] + 1: 0;
        ret._strides[dimension] = slice._strides[dimension];
        ret._lengths[dimension + N] = lengths[dimension];
        ret._strides[dimension + N] = slice._strides[dimension];
    }
    foreach (dimension; Iota!(N, slice.PureN))
    {
        ret._lengths[dimension + N] = slice._lengths[dimension];
        ret._strides[dimension +  N] = slice._strides[dimension];
    }
    ret._ptr = slice._ptr;
    return ret;
}

///
pure nothrow unittest
{
    import std.experimental.ndslice.slice;
    auto slice = slice!int(5, 8);
    auto windows = slice.windows(2, 3);
    foreach (window; windows.byElement)
        window[] += 1;

    assert(slice ==
        [[1,  2,  3, 3, 3, 3,  2,  1],

         [2,  4,  6, 6, 6, 6,  4,  2],
         [2,  4,  6, 6, 6, 6,  4,  2],
         [2,  4,  6, 6, 6, 6,  4,  2],

         [1,  2,  3, 3, 3, 3,  2,  1]]);
}

///
pure nothrow unittest
{
    import std.experimental.ndslice.slice;
    auto slice = slice!int(5, 8);
    auto windows = slice.windows(2, 3);
    windows[1, 2][] = 1;
    windows[1, 2][0, 1] += 1;
    windows.unpack[1, 2, 0, 1] += 1;

    assert(slice ==
        [[0, 0,  0, 0, 0,  0, 0, 0],

         [0, 0,  1, 3, 1,  0, 0, 0],
         [0, 0,  1, 1, 1,  0, 0, 0],

         [0, 0,  0, 0, 0,  0, 0, 0],
         [0, 0,  0, 0, 0,  0, 0, 0]]);
}

/// Multi-diagonal matrix
pure nothrow unittest
{
    import std.experimental.ndslice.slice;
    auto slice = slice!int(8, 8);
    auto windows = slice.windows(3, 3);

    auto multidiagonal = windows
        .diagonal
        .unpack;
    foreach (window; multidiagonal)
        window[] += 1;

    assert(slice ==
        [[ 1, 1, 1,  0, 0, 0, 0, 0],
         [ 1, 2, 2, 1,  0, 0, 0, 0],
         [ 1, 2, 3, 2, 1,  0, 0, 0],
         [0,  1, 2, 3, 2, 1,  0, 0],
         [0, 0,  1, 2, 3, 2, 1,  0],
         [0, 0, 0,  1, 2, 3, 2, 1],
         [0, 0, 0, 0,  1, 2, 2, 1],
         [0, 0, 0, 0, 0,  1, 1, 1]]);
}

/// Sliding window over matrix columns
pure nothrow unittest
{
    import std.experimental.ndslice.slice;
    auto slice = slice!int(5, 8);
    auto windows = slice
        .pack!1
        .evertPack
        .windows(3)
        .unpack
        .pack!2;


    foreach (window; windows.byElement)
        window[] += 1;

    assert(slice ==
        [[1,  2,  3, 3, 3, 3,  2,  1],
         [1,  2,  3, 3, 3, 3,  2,  1],
         [1,  2,  3, 3, 3, 3,  2,  1],
         [1,  2,  3, 3, 3, 3,  2,  1],
         [1,  2,  3, 3, 3, 3,  2,  1]]);
}

/// Overlapping blocks using windows
pure nothrow unittest
{
    //  ----------------
    // |  0  1  2  3  4 |
    // |  5  6  7  8  9 |
    // | 10 11 12 13 14 |
    // | 15 16 17 18 19 |
    // | 20 21 22 23 24 |
    //  ----------------
    //->
    //  ---------------------
    // |  0  1  2 |  2  3  4 |
    // |  5  6  7 |  7  8  9 |
    // | 10 11 12 | 12 13 14 |
    // | - - - - - - - - - - |
    // | 10 11 13 | 12 13 14 |
    // | 15 16 17 | 17 18 19 |
    // | 20 21 22 | 22 23 24 |
    //  ---------------------

    import std.experimental.ndslice.slice;
    import std.experimental.ndslice.iteration : strided;

    auto overlappingBlocks = iotaSlice(5, 5)
        .windows(3, 3)
        .strided!(0, 1)(2, 2);

    assert(overlappingBlocks ==
            [[[[ 0,  1,  2], [ 5,  6,  7], [10, 11, 12]],
              [[ 2,  3,  4], [ 7,  8,  9], [12, 13, 14]]],
             [[[10, 11, 12], [15, 16, 17], [20, 21, 22]],
              [[12, 13, 14], [17, 18, 19], [22, 23, 24]]]]);
}

deprecated("use:
    Slice!(M, Range) reshape
        (size_t N, Range, size_t M)
        (Slice!(N, Range) slice, size_t[M] lengths, ref int err)")
Slice!(M, Range) reshape
        (size_t N, Range, size_t M)
        (Slice!(N, Range) slice, size_t[M] lengths...)
{
    int err;
    auto ret = slice.reshape(lengths, err);
    if (!err)
        return ret;
    string msg;
    with (ReshapeError) switch (err)
    {
        case empty:
            msg = "slice should be not empty";
            break;
        case total:
            msg = "total element count should be the same";
            break;
        case incompatible:
            msg = "structure is incompatible with new shape";
            break;
        default:
    }
    throw new ReshapeException(
        slice._lengths.dup,
        slice._strides.dup,
        ret.  _lengths.dup,
        msg);
}

@safe pure unittest
{
    import std.experimental.ndslice.iteration : allReversed;
    auto slice = iotaSlice(3, 4)
        .allReversed
        .reshape(-1, 3);
    assert(slice ==
        [[11, 10, 9],
         [ 8,  7, 6],
         [ 5,  4, 3],
         [ 2,  1, 0]]);
}

pure unittest
{
    import std.experimental.ndslice.slice;
    import std.experimental.ndslice.iteration : reversed;
    import std.array : array;

    auto reshape2(S, size_t M)(S slice, size_t[M] lengths...)
    {
        // Tries to reshape without allocation
        try return slice.reshape(lengths);
        catch (ReshapeException e)
            // Allocates
            return slice.slice.reshape(lengths);
    }

    auto slice =
        [0, 1,  2,  3,
         4, 5,  6,  7,
         8, 9, 10, 11]
        .sliced(3, 4)
        .reversed!0;

    assert(reshape2(slice, 4, 3) ==
        [[ 8, 9, 10],
         [11, 4,  5],
         [ 6, 7,  0],
         [ 1, 2,  3]]);
}

@safe pure unittest
{
    import std.experimental.ndslice.iteration : allReversed;
    auto slice = iotaSlice(1, 1, 3, 2, 1, 2, 1).allReversed;
    assert(slice.reshape(1, -1, 1, 1, 3, 1) ==
        [[[[[[11], [10], [9]]]],
          [[[[ 8], [ 7], [6]]]],
          [[[[ 5], [ 4], [3]]]],
          [[[[ 2], [ 1], [0]]]]]]);
}

// Issue 15919
unittest
{
    assert(iotaSlice(3, 4, 5, 6, 7).pack!2.reshape(4, 3, 5)[0, 0, 0].shape == cast(size_t[2])[6, 7]);
}

@safe pure unittest
{
    import std.experimental.ndslice.slice;
    import std.range : iota;
    import std.exception : assertThrown;

    auto e = 1.iotaSlice(1);
    // resize to the wrong dimension
    assertThrown!ReshapeException(e.reshape(2));
    e.popFront;
    // test with an empty slice
    assertThrown!ReshapeException(e.reshape(1));
}

unittest
{
    auto pElements = iotaSlice(3, 4, 5, 6, 7)
        .pack!2
        .byElement();
    assert(pElements[0][0] == iotaSlice(7));
    assert(pElements[$-1][$-1] == iotaSlice([7], 2513));
}

/++
Error codes for $(LREF reshape).
+/
enum ReshapeError
{
    /// No error
    none,
    /// Slice should be not empty
    empty,
    /// Total element count should be the same
    total,
    /// Structure is incompatible with new shape
    incompatible,
}

/++
Returns a new slice for the same data with different dimensions.

Params:
    slice = slice to be reshaped
    lengths = list of new dimensions. One of the lengths can be set to `-1`.
        In this case, the corresponding dimension is inferable.
    err = $(LREF ReshapeError) code
Returns:
    reshaped slice
+/
Slice!(M, Range) reshape
        (size_t N, Range, size_t M)
        (Slice!(N, Range) slice, size_t[M] lengths, ref int err)
{
    mixin _DefineRet;
    foreach (i; Iota!(0, ret.N))
        ret._lengths[i] = lengths[i];

    /// Code size optimization
    goto B;
R:
        return ret;
B:
    immutable size_t eco = slice.elementsCount;
    if (eco == 0)
    {
        err = ReshapeError.empty;
        goto R;
    }
    size_t ecn = ret  .elementsCount;


    foreach (i; Iota!(0, ret.N))
        if (ret._lengths[i] == -1)
        {
            ecn = -ecn;
            ret._lengths[i] = eco / ecn;
            ecn *= ret._lengths[i];
            break;
        }

    if (eco != ecn)
    {
        err = ReshapeError.total;
        goto R;
    }

    for (size_t oi, ni, oj, nj; oi < slice.N && ni < ret.N; oi = oj, ni = nj)
    {
        size_t op = slice._lengths[oj++];
        size_t np = ret  ._lengths[nj++];

        for (;;)
        {
            if (op < np)
                op *= slice._lengths[oj++];
            if (op > np)
                np *= ret  ._lengths[nj++];
            if (op == np)
                break;
        }
        while (oj < slice.N && slice._lengths[oj] == 1) oj++;
        while (nj < ret  .N && ret  ._lengths[nj] == 1) nj++;

        for (size_t l = oi, r = oi + 1; r < oj; r++)
            if (slice._lengths[r] != 1)
            {
                if (slice._strides[l] != slice._lengths[r] * slice._strides[r])
                {
                    err = ReshapeError.incompatible;
                    goto R;
                }
                l = r;
            }

        ret._strides[nj - 1] = slice._strides[oj - 1];
        foreach_reverse (i; ni .. nj - 1)
            ret._strides[i] = ret._lengths[i + 1] * ret._strides[i + 1];
    assert((oi == slice.N) == (ni == ret.N));
    }
    foreach (i; Iota!(ret.N, ret.PureN))
    {
        ret._lengths[i] = slice._lengths[i + slice.N - ret.N];
        ret._strides[i] = slice._strides[i + slice.N - ret.N];
    }
    ret._ptr = slice._ptr;
    err = 0;
    goto R;
}

///
nothrow @safe pure unittest
{
    import std.experimental.ndslice.iteration : allReversed;
    int err;
    auto slice = iotaSlice(3, 4)
        .allReversed
        .reshape([-1, 3], err);
    assert(err == 0);
    assert(slice ==
        [[11, 10, 9],
         [ 8,  7, 6],
         [ 5,  4, 3],
         [ 2,  1, 0]]);
}

/// Reshaping with memory allocation
pure unittest
{
    import std.experimental.ndslice.slice;
    import std.experimental.ndslice.iteration : reversed;
    import std.array : array;

    auto reshape2(S, size_t M)(S slice, size_t[M] lengths...)
    {
        int err;
        // Tries to reshape without allocation
        auto ret = slice.reshape(lengths, err);
        if (!err)
            return ret;
        if (err == ReshapeError.incompatible)
            return slice.slice.reshape(lengths, err);
        throw new Exception("total elements count is different or equals to zero");
    }

    auto slice =
        [0, 1,  2,  3,
         4, 5,  6,  7,
         8, 9, 10, 11]
        .sliced(3, 4)
        .reversed!0;

    assert(reshape2(slice, 4, 3) ==
        [[ 8, 9, 10],
         [11, 4,  5],
         [ 6, 7,  0],
         [ 1, 2,  3]]);
}

nothrow @safe pure unittest
{
    import std.experimental.ndslice.iteration : allReversed;
    auto slice = iotaSlice(1, 1, 3, 2, 1, 2, 1).allReversed;
    int err;
    assert(slice.reshape([1, -1, 1, 1, 3, 1], err) ==
        [[[[[[11], [10], [9]]]],
          [[[[ 8], [ 7], [6]]]],
          [[[[ 5], [ 4], [3]]]],
          [[[[ 2], [ 1], [0]]]]]]);
    assert(err == 0);
}

// Issue 15919
nothrow @nogc @safe pure unittest
{
    int err;
    assert(iotaSlice(3, 4, 5, 6, 7).pack!2.reshape([4, 3, 5], err)[0, 0, 0].shape == cast(size_t[2])[6, 7]);
    assert(err == 0);
}

nothrow @nogc @safe pure unittest
{
    import std.experimental.ndslice.slice;
    import std.range : iota;
    import std.exception : assertThrown;

    int err;
    auto e = 1.iotaSlice(1);
    // resize to the wrong dimension
    e.reshape([2], err);
    assert(err == ReshapeError.total);
    e.popFront;
    // test with an empty slice
    e.reshape([1], err);
    assert(err == ReshapeError.empty);
}

unittest
{
    auto pElements = iotaSlice(3, 4, 5, 6, 7)
        .pack!2
        .byElement();
    assert(pElements[0][0] == iotaSlice(7));
    assert(pElements[$-1][$-1] == iotaSlice([7], 2513));
}

/// See_also: $(LREF reshape)
deprecated("Not nothrow or @nogc ndslice API is deprecated.")
class ReshapeException: SliceException
{
    /// Old lengths
    size_t[] lengths;
    /// Old strides
    sizediff_t[] strides;
    /// New lengths
    size_t[] newLengths;
    ///
    this(
        size_t[] lengths,
        sizediff_t[] strides,
        size_t[] newLengths,
        string msg,
        string file = __FILE__,
        uint line = cast(uint)__LINE__,
        Throwable next = null
        ) pure nothrow @nogc @safe
    {
        super(msg, file, line, next);
        this.lengths = lengths;
        this.strides = strides;
        this.newLengths = newLengths;
    }
}

/++
Returns a random access range of all elements of a slice.
The order of elements is preserved.
`byElement` can be generalized with other selectors.

Params:
    N = dimension count
    slice = slice to be iterated
Returns:
    random access range composed of elements of the `slice`
+/
auto byElement(size_t N, Range)(Slice!(N, Range) slice)
{
    with (Slice!(N, Range))
    {
        /++
        ByElement shifts the range's `_ptr` without modifying its strides and lengths.
        +/
        static struct ByElement
        {
            @fmb:
            This _slice;
            size_t _length;
            size_t[N] _indexes;

            auto save() @property
            {
                return this;
            }

            bool empty() const @property
            {
                return _length == 0;
            }

            size_t length() const @property
            {
                return _length;
            }

            auto ref front() @property
            {
                assert(!this.empty);
                static if (N == PureN)
                {
                    return _slice._ptr[0];
                }
                else with (_slice)
                {
                    alias M = DeepElemType.PureN;
                    return DeepElemType(_lengths[$ - M .. $], _strides[$ - M .. $], _ptr);
                }
            }

            static if (PureN == 1 && isMutable!DeepElemType && !hasAccessByRef)
            auto front(E)(E elem) @property
            {
                assert(!this.empty);
                return _slice._ptr[0] = elem;
            }

            void popFront()
            {
                assert(_length != 0);
                _length--;
                popFrontImpl;
            }

            private void popFrontImpl()
            {
                foreach_reverse (i; Iota!(0, N)) with (_slice)
                {
                    _ptr += _strides[i];
                    _indexes[i]++;
                    if (_indexes[i] < _lengths[i])
                        return;
                    debug (ndslice) assert(_indexes[i] == _lengths[i]);
                    _ptr -= _lengths[i] * _strides[i];
                    _indexes[i] = 0;
                }
            }

            auto ref back() @property
            {
                assert(!this.empty);
                return opIndex(_length - 1);
            }

            static if (PureN == 1 && isMutable!DeepElemType && !hasAccessByRef)
            auto back(E)(E elem) @property
            {
                assert(!this.empty);
                return opIndexAssign(elem, _length - 1);
            }

            void popBack()
            {
                assert(_length != 0);
                _length--;
            }

            void popFrontExactly(size_t n)
            in
            {
                assert(n <= _length);
            }
            body
            {
                _length -= n;
                //calculates shift and new indexes
                sizediff_t _shift;
                n += _indexes[N-1];
                foreach_reverse (i; Iota!(1, N)) with (_slice)
                {
                    immutable v = n / _lengths[i];
                    n %= _lengths[i];
                    _shift += (n - _indexes[i]) * _strides[i];
                    _indexes[i] = n;
                    n = _indexes[i - 1] + v;
                }
                assert(n <= _slice._lengths[0]);
                with (_slice)
                {
                    _shift += (n - _indexes[0]) * _strides[0];
                    _indexes[0] = n;
                }
                _slice._ptr += _shift;
            }

            void popBackExactly(size_t n)
            in
            {
                assert(n <= _length);
            }
            body
            {
                _length -= n;
            }

            //calculates shift for index n
            private sizediff_t getShift(size_t n)
            in
            {
                assert(n < _length);
            }
            body
            {
                sizediff_t _shift;
                n += _indexes[N-1];
                foreach_reverse (i; Iota!(1, N)) with (_slice)
                {
                    immutable v = n / _lengths[i];
                    n %= _lengths[i];
                    _shift += (n - _indexes[i]) * _strides[i];
                    n = _indexes[i - 1] + v;
                }
                debug (ndslice) assert(n < _slice._lengths[0]);
                with (_slice)
                    _shift += (n - _indexes[0]) * _strides[0];
                return _shift;
            }

            auto ref opIndex(size_t index)
            {
                static if (N == PureN)
                {
                    return _slice._ptr[getShift(index)];
                }
                else with (_slice)
                {
                    alias M = DeepElemType.PureN;
                    return DeepElemType(_lengths[$ - M .. $], _strides[$ - M .. $], _ptr + getShift(index));
                }
            }

            static if (PureN == 1 && isMutable!DeepElemType && !hasAccessByRef)
            auto opIndexAssign(E)(E elem, size_t index)
            {
                static if (N == PureN)
                {
                    return _slice._ptr[getShift(index)] = elem;
                }
                else
                {
                    static assert(0,
                        "ByElement.opIndexAssign is not implemented for packed slices."
                        ~ "Use additional empty slicing `elemsOfSlice[index][] = value`"
                        ~ tailErrorMessage());
                }
            }

            static if (isMutable!DeepElemType && N == PureN)
            {
                auto opIndexAssign(V)(V val, _Slice slice)
                {
                    return this[slice][] = val;
                }

                auto opIndexAssign(V)(V val)
                {
                    foreach (ref e; this)
                        e = val;
                    return this;
                }

                auto opIndexAssign(V : T[], T)(V val)
                    if (__traits(compiles, front = val[0]))
                {
                    assert(_length == val.length, "lengths should be equal" ~ tailErrorMessage!());
                    foreach (ref e; this)
                    {
                        e = val[0];
                        val = val[1 .. $];
                    }
                    return this;
                }

                auto opIndexAssign(V : Slice!(1, _Range), _Range)(V val)
                    if (__traits(compiles, front = val.front))
                {
                    assert(_length == val.length, "lengths should be equal" ~ tailErrorMessage!());
                    foreach (ref e; this)
                    {
                        e = val.front;
                        val.popFront;
                    }
                    return this;
                }
            }

            auto opIndex(_Slice sl)
            {
                auto ret = this;
                ret.popFrontExactly(sl.i);
                ret.popBackExactly(_length - sl.j);
                return ret;
            }

            alias opDollar = length;

            _Slice opSlice(size_t pos : 0)(size_t i, size_t j)
            in
            {
                assert(i <= j,
                    "the left bound must be less than or equal to the right bound"
                    ~ tailErrorMessage!());
                assert(j - i <= _length,
                    "the difference between the right and the left bound must be less than or equal to range length"
                    ~ tailErrorMessage!());
            }
            body
            {
                return typeof(return)(i, j);
            }

            size_t[N] index() @property
            {
                return _indexes;
            }
        }
        return ByElement(slice, slice.elementsCount);
    }
}

/// Regular slice
@safe @nogc pure nothrow unittest
{
    import std.algorithm.comparison : equal;
    import std.range : iota;
    assert(iotaSlice(4, 5)
        .byElement
        .equal(20.iota));
}

/// Packed slice
@safe @nogc pure nothrow unittest
{
    import std.experimental.ndslice.slice;
    import std.experimental.ndslice.iteration;
    import std.range : drop;
    assert(iotaSlice(3, 4, 5, 6, 7)
        .pack!2
        .byElement()
        .drop(1)
        .front
         == iotaSlice([6, 7], 6 * 7));
}

/// Properties
pure nothrow unittest
{
    auto elems = iotaSlice(3, 4).byElement;

    elems.popFrontExactly(2);
    assert(elems.front == 2);
    assert(elems.index == [0, 2]);

    elems.popBackExactly(2);
    assert(elems.back == 9);
    assert(elems.length == 8);
}

/// Index property
pure nothrow unittest
{
    import std.experimental.ndslice.slice;
    auto slice = new long[20].sliced(5, 4);

    for (auto elems = slice.byElement; !elems.empty; elems.popFront)
    {
        size_t[2] index = elems.index;
        elems.front = index[0] * 10 + index[1] * 3;
    }
    assert(slice ==
        [[ 0,  3,  6,  9],
         [10, 13, 16, 19],
         [20, 23, 26, 29],
         [30, 33, 36, 39],
         [40, 43, 46, 49]]);
}

pure nothrow unittest
{
    // test save
    import std.range : dropOne;
    import std.range : iota;

    auto elems = 12.iota.sliced(3, 4).byElement;
    assert(elems.front == 0);
    assert(elems.save.dropOne.front == 1);
    assert(elems.front == 0);
}

/++
Random access and slicing
+/
@nogc nothrow unittest
{
    import std.experimental.ndslice.slice;
    import std.algorithm.comparison : equal;
    import std.array : array;
    import std.range : iota, repeat;
    static data = 20.iota.array;
    auto elems = data.sliced(4, 5).byElement;

    elems = elems[11 .. $ - 2];

    assert(elems.length == 7);
    assert(elems.front == 11);
    assert(elems.back == 17);

    foreach (i; 0 .. 7)
        assert(elems[i] == i + 11);

    // assign an element
    elems[2 .. 6] = -1;
    assert(elems[2 .. 6].equal(repeat(-1, 4)));

    // assign an array
    static ar = [-1, -2, -3, -4];
    elems[2 .. 6] = ar;
    assert(elems[2 .. 6].equal(ar));

    // assign a slice
    ar[] *= 2;
    auto sl = ar.sliced(ar.length);
    elems[2 .. 6] = sl;
    assert(elems[2 .. 6].equal(sl));
}

/++
Forward access works faster than random access or backward access.
Use $(SUBREF iteration, allReversed) in pipeline before
`byElement` to achieve fast backward access.
+/
@safe @nogc pure nothrow unittest
{
    import std.range : retro;
    import std.experimental.ndslice.iteration : allReversed;

    auto slice = iotaSlice(3, 4, 5);

    /// Slow backward iteration #1
    foreach (ref e; slice.byElement.retro)
    {
        //...
    }

    /// Slow backward iteration #2
    foreach_reverse (ref e; slice.byElement)
    {
        //...
    }

    /// Fast backward iteration
    foreach (ref e; slice.allReversed.byElement)
    {
        //...
    }
}

@safe @nogc pure nothrow unittest
{
    import std.range.primitives : isRandomAccessRange, hasSlicing;
    auto elems = iotaSlice(4, 5).byElement;
    static assert(isRandomAccessRange!(typeof(elems)));
    static assert(hasSlicing!(typeof(elems)));
}

// Checks strides
@safe @nogc pure nothrow unittest
{
    import std.experimental.ndslice.iteration;
    import std.range : isRandomAccessRange;
    auto elems = iotaSlice(4, 5).everted.byElement;
    static assert(isRandomAccessRange!(typeof(elems)));

    elems = elems[11 .. $ - 2];
    auto elems2 = elems;
    foreach (i; 0 .. 7)
    {
        assert(elems[i] == elems2.front);
        elems2.popFront;
    }
}

@safe @nogc pure nothrow unittest
{
    import std.experimental.ndslice.slice;
    import std.experimental.ndslice.iteration;
    import std.range : iota, isForwardRange, hasLength;
    import std.algorithm.comparison : equal;

    auto range = (3 * 4 * 5 * 6 * 7).iota;
    auto slice0 = range.sliced(3, 4, 5, 6, 7);
    auto slice1 = slice0.transposed!(2, 1).pack!2;
    auto elems0 = slice0.byElement;
    auto elems1 = slice1.byElement;

    import std.meta;
    foreach (S; AliasSeq!(typeof(elems0), typeof(elems1)))
    {
        static assert(isForwardRange!S);
        static assert(hasLength!S);
    }

    assert(elems0.length == slice0.elementsCount);
    assert(elems1.length == 5 * 4 * 3);

    auto elems2 = elems1;
    foreach (q; slice1)
        foreach (w; q)
            foreach (e; w)
            {
                assert(!elems2.empty);
                assert(e == elems2.front);
                elems2.popFront;
            }
    assert(elems2.empty);

    elems0.popFront();
    elems0.popFrontExactly(slice0.elementsCount - 14);
    assert(elems0.length == 13);
    assert(elems0.equal(range[slice0.elementsCount - 13 .. slice0.elementsCount]));

    foreach (elem; elems0) {}
}

// Issue 15549
unittest
{
    import std.range.primitives;
    alias A = typeof(iotaSlice(2, 5).sliced(1, 1, 1, 1));
    static assert(isRandomAccessRange!A);
    static assert(hasLength!A);
    static assert(hasSlicing!A);
    alias B = typeof(slice!double(2, 5).sliced(1, 1, 1, 1));
    static assert(isRandomAccessRange!B);
    static assert(hasLength!B);
    static assert(hasSlicing!B);
}

// Issue 16010
unittest
{
    auto s = iotaSlice(3, 4).byElement;
    foreach (_; 0 .. s.length)
        s = s[1 .. $];
}

/++
Returns an forward range of all elements of standard simplex of a slice.
In case the slice has two dimensions, it is composed of elements of upper left triangular matrix.
The order of elements is preserved.
`byElementInStandardSimplex` can be generalized with other selectors.

Params:
    N = dimension count
    slice = slice to be iterated
    maxHypercubeLength = maximal length of simplex hypercube.
Returns:
    forward range composed of all elements of standard simplex of the `slice`
+/
auto byElementInStandardSimplex(size_t N, Range)(Slice!(N, Range) slice, size_t maxHypercubeLength = size_t.max)
{
    with (Slice!(N, Range))
    {
        /++
        ByElementInTopSimplex shifts the range's `_ptr` without modifying its strides and lengths.
        +/
        static struct ByElementInTopSimplex
        {
            @fmb:
            This _slice;
            size_t _length;
            size_t maxHypercubeLength;
            size_t sum;
            size_t[N] _indexes;

            auto save() @property
            {
                return this;
            }

            bool empty() const @property
            {
                return _length == 0;
            }

            size_t length() const @property
            {
                return _length;
            }

            auto ref front() @property
            {
                assert(!this.empty);
                static if (N == PureN)
                    return _slice._ptr[0];
                else with (_slice)
                {
                    alias M = DeepElemType.PureN;
                    return DeepElemType(_lengths[$ - M .. $], _strides[$ - M .. $], _ptr);
                }
            }

            static if (PureN == 1 && isMutable!DeepElemType && !hasAccessByRef)
            auto front(E)(E elem) @property
            {
                assert(!this.empty);
                return _slice._ptr[0] = elem;
            }

            void popFront()
            {
                assert(_length != 0);
                _length--;
                popFrontImpl;
            }

            private void popFrontImpl()
            {
                foreach_reverse (i; Iota!(0, N)) with (_slice)
                {
                    _ptr += _strides[i];
                    _indexes[i]++;
                    debug (ndslice) assert(_indexes[i] <= _lengths[i]);
                    sum++;
                    if (sum < maxHypercubeLength)
                        return;
                    debug (ndslice) assert(sum == maxHypercubeLength);
                    _ptr -= _indexes[i] * _strides[i];
                    sum -= _indexes[i];
                    _indexes[i] = 0;
                }
            }

            size_t[N] index() @property
            {
                return _indexes;
            }
        }
        foreach (i; Iota!(0, N))
            if (maxHypercubeLength > slice._lengths[i])
                maxHypercubeLength = slice._lengths[i];
        immutable size_t elementsCount = ((maxHypercubeLength + 1) * maxHypercubeLength ^^ (N - 1)) / 2;
        return ByElementInTopSimplex(slice, elementsCount, maxHypercubeLength);
    }
}

///
pure nothrow unittest
{
    import std.experimental.ndslice.slice;
    auto slice = slice!int(4, 5);
    auto elems = slice
        .byElementInStandardSimplex;
    int i;
    foreach (ref e; elems)
        e = ++i;
    assert(slice ==
        [[ 1, 2, 3, 4, 0],
         [ 5, 6, 7, 0, 0],
         [ 8, 9, 0, 0, 0],
         [10, 0, 0, 0, 0]]);
}

///
pure nothrow unittest
{
    import std.experimental.ndslice.slice;
    import std.experimental.ndslice.iteration;
    auto slice = slice!int(4, 5);
    auto elems = slice
        .transposed
        .allReversed
        .byElementInStandardSimplex;
    int i;
    foreach (ref e; elems)
        e = ++i;
    assert(slice ==
        [[0,  0, 0, 0, 4],
         [0,  0, 0, 7, 3],
         [0,  0, 9, 6, 2],
         [0, 10, 8, 5, 1]]);
}

/// Properties
@safe @nogc pure nothrow unittest
{
    import std.range.primitives : popFrontN;

    auto elems = iotaSlice(3, 4).byElementInStandardSimplex;

    elems.popFront;
    assert(elems.front == 1);
    assert(elems.index == cast(size_t[2])[0, 1]);

    elems.popFrontN(3);
    assert(elems.front == 5);
}

/// Save
@safe @nogc pure nothrow unittest
{
    auto elems = iotaSlice(3, 4).byElementInStandardSimplex;
    import std.range : dropOne, popFrontN;
    elems.popFrontN(4);

    assert(elems.save.dropOne.front == 8);
    assert(elems.front == 5);
    assert(elems.index == cast(size_t[2])[1, 1]);
    assert(elems.length == 2);
}

/++
Returns a slice, the elements of which are equal to the initial multidimensional index value.
This is multidimensional analog of $(REF iota, std, range).
For a flattened (continuous) index, see $(LREF iotaSlice).

Params:
    N = dimension count
    lengths = list of dimension lengths
Returns:
    `N`-dimensional slice composed of indexes
See_also: $(LREF IndexSlice), $(LREF iotaSlice)
+/
IndexSlice!N indexSlice(size_t N)(size_t[N] lengths...)
{
    import std.experimental.ndslice.slice : sliced;
    with (typeof(return)) return Range(lengths[1 .. $]).sliced(lengths);
}

///
@safe pure nothrow @nogc unittest
{
    auto slice = indexSlice(2, 3);
    static immutable array =
        [[[0, 0], [0, 1], [0, 2]],
         [[1, 0], [1, 1], [1, 2]]];

    assert(slice == array);


    static assert(is(IndexSlice!2 : Slice!(2, Range), Range));
    static assert(is(DeepElementType!(IndexSlice!2) == size_t[2]));
}

///
@safe pure nothrow unittest
{
    auto im = indexSlice(7, 9);

    assert(im[2, 1] == [2, 1]);

    //slicing works correctly
    auto cm = im[1 .. $, 4 .. $];
    assert(cm[2, 1] == [3, 5]);
}

@safe pure nothrow unittest
{
    // test save
    import std.range : dropOne;

    auto im = indexSlice(7, 9);
    auto imByElement = im.byElement;
    assert(imByElement.front == [0, 0]);
    assert(imByElement.save.dropOne.front == [0, 1]);
    assert(imByElement.front == [0, 0]);
}

/++
Slice composed of indexes.
See_also: $(LREF indexSlice)
+/
template IndexSlice(size_t N)
    if (N)
{
    struct IndexMap
    {
        private size_t[N-1] _lengths;

        @fmb size_t[N] opIndex(size_t index) const
        {
            size_t[N] indexes = void;
            foreach_reverse (i; Iota!(0, N - 1))
            {
                indexes[i + 1] = index % _lengths[i];
                index /= _lengths[i];
            }
            indexes[0] = index;
            return indexes;
        }
    }
    alias IndexSlice = Slice!(N, IndexMap);
}

unittest
{
    auto r = indexSlice(1);
    import std.range.primitives : isRandomAccessRange;
    static assert(isRandomAccessRange!(typeof(r)));
}

/++
Returns a slice, the elements of which are equal to the initial flattened index value.
For a multidimensional index, see $(LREF indexSlice).

Params:
    N = dimension count
    lengths = list of dimension lengths
    shift = value of the first element in a slice (optional)
    step = value of the step between elements (optional)
Returns:
    `N`-dimensional slice composed of indexes
See_also: $(LREF IotaSlice), $(LREF indexSlice)
+/
IotaSlice!N iotaSlice(size_t N)(size_t[N] lengths...)
{
    return .iotaSlice(lengths, 0);
}

///ditto
IotaSlice!N iotaSlice(size_t N)(size_t[N] lengths, size_t shift)
{
    import std.experimental.ndslice.slice : sliced;
    return IotaMap!().init.sliced(lengths, shift);
}

///ditto
IotaSlice!N iotaSlice(size_t N)(size_t[N] lengths, size_t shift, size_t step)
{
    auto iota = iotaSlice(lengths, shift);
    foreach (i; Iota!(0, N))
        iota._strides[i] *= step;
    return iota;
}

///
@safe pure nothrow @nogc unittest
{
    auto slice = iotaSlice(2, 3);
    static immutable array =
        [[0, 1, 2],
         [3, 4, 5]];

    assert(slice == array);

    import std.range.primitives : isRandomAccessRange;
    static assert(isRandomAccessRange!(IotaSlice!2));
    static assert(is(IotaSlice!2 : Slice!(2, Range), Range));
    static assert(is(DeepElementType!(IotaSlice!2) == size_t));
}

///
@safe pure nothrow @nogc unittest
{
    auto im = iotaSlice([10, 5], 100);

    assert(im[2, 1] == 111); // 100 + 2 * 5 + 1

    //slicing works correctly
    auto cm = im[1 .. $, 3 .. $];
    assert(cm[2, 1] == 119); // 119 = 100 + (1 + 2) * 5 + (3 + 1)
}

/// `iotaSlice` with step
@safe pure nothrow unittest
{
    auto sl = iotaSlice([2, 3], 10, 10);

    assert(sl == [[10, 20, 30],
                  [40, 50, 60]]);
}

/++
Slice composed of flattened indexes.
See_also: $(LREF iotaSlice)
+/
template IotaSlice(size_t N)
    if (N)
{
    alias IotaSlice = Slice!(N, IotaMap!());
}

// undocumented
// zero cost variant of `std.range.iota`
struct IotaMap()
{
    enum bool empty = false;

    @fmb static size_t opIndex()(size_t index) @safe pure nothrow @nogc @property
    {
        pragma(inline, true);
        return index;
    }
}

/++
Returns a slice with identical elements.
`RepeatSlice` stores only single value.
Params:
    lengths = list of dimension lengths
Returns:
    `n`-dimensional slice composed of identical values, where `n` is dimension count.
See_also: $(REF repeat, std,range)
+/
RepeatSlice!(M, T) repeatSlice(T, size_t M)(T value, size_t[M] lengths...)
    if (!is(T : Slice!(N, Range), size_t N, Range))
{
    typeof(return) ret;
    foreach (i; Iota!(0, ret.N))
        ret._lengths[i] = lengths[i];
    ret._ptr = RepeatPtr!T(value);
    return ret;
}

/// ditto
Slice!(M, Slice!(N + 1, Range)) repeatSlice(size_t N, Range, size_t M)(Slice!(N, Range) slice, size_t[M] lengths...)
{
    typeof(return) ret;
    ret._ptr = slice._ptr;
    foreach (i; Iota!(0, M))
        ret._lengths[i] = lengths[i];
    foreach (i; Iota!(0, N))
    {
        ret._lengths[M + i] = slice._lengths[i];
        ret._strides[M + i] = slice._strides[i];
    }
    return ret;
}

///
@safe pure nothrow unittest
{
    auto sl = iotaSlice(3)
        .repeatSlice(4);
    assert(sl == [[0, 1, 2],
                  [0, 1, 2],
                  [0, 1, 2],
                  [0, 1, 2]]);
}

///
@safe pure nothrow unittest
{
    import std.experimental.ndslice.iteration : transposed;

    auto sl = iotaSlice(3)
        .repeatSlice(4)
        .unpack
        .transposed;

    assert(sl == [[0, 0, 0, 0],
                  [1, 1, 1, 1],
                  [2, 2, 2, 2]]);
}

///
pure nothrow unittest
{
    import std.experimental.ndslice.slice : slice;

    auto sl = iotaSlice([3], 6).slice;
    auto slC = sl.repeatSlice(2, 3);
    sl[1] = 4;
    assert(slC == [[[6, 4, 8],
                    [6, 4, 8],
                    [6, 4, 8]],
                   [[6, 4, 8],
                    [6, 4, 8],
                    [6, 4, 8]]]);
}

///
@safe pure nothrow unittest
{
    auto sl = repeatSlice(4.0, 2, 3);
    assert(sl == [[4.0, 4.0, 4.0],
                  [4.0, 4.0, 4.0]]);

    static assert(is(DeepElementType!(typeof(sl)) == double));

    sl[1, 1] = 3;
    assert(sl == [[3.0, 3.0, 3.0],
                  [3.0, 3.0, 3.0]]);
}

/++
Slice composed of identical values.
+/
template  RepeatSlice(size_t N, T)
    if (N)
{
    alias RepeatSlice = Slice!(N, RepeatPtr!T);
}

// undocumented
// zero cost variant of `std.range.repeat`
// in addition, the internal value is mutable
@LikePtr struct RepeatPtr(T)
{
    // UT definition is from std.range
    // Store a non-qualified T when possible: This is to make RepeatPtr assignable
    static if ((is(T == class) || is(T == interface)) && (is(T == const) || is(T == immutable)))
    {
        import std.typecons : Rebindable;
        private alias UT = Rebindable!T;
    }
    else static if (is(T : Unqual!T) && is(Unqual!T : T))
        private alias UT = Unqual!T;
    else
        private alias UT = T;
    private UT _value;

    @fmb:

    ref T opIndex(sizediff_t)
    {
        return _value;
    }

    void opOpAssign(string op)(sizediff_t)
        if (op == `+` || op == `-`)
    {
    }

    auto opBinary(string op)(sizediff_t)
        if (op == `+` || op == `-`)
    {
        return this;
    }

    auto ref opUnary(string op)()
        if (op == `++` || op == `--`)
    {
        return this;
    }
}

@safe pure nothrow @nogc unittest
{
    RepeatPtr!double val;
    val._value = 3;
    assert((++val)._value == 3);
    val += 2;
    assert((val + 3)._value == 3);
}

/++
Implements the homonym function (also known as `transform`) present
in many languages of functional flavor. The call `mapSlice!(fun)(tensor)`
returns a tensor of which elements are obtained by applying `fun`
for all elements in `tensor`. The original tensors are
not changed. Evaluation is done lazily.

Note:
    $(SUBREF iteration, transposed) and
    $(SUBREF selection, pack) can be used to specify dimensions.
Params:
    fun = One or more functions.
    tensor = An input tensor.
Returns:
    a tensor with each fun applied to all the elements. If there is more than one
    fun, the element type will be `Tuple` containing one element for each fun.
See_Also:
    $(REF map, std,algorithm,iteration)
    $(HTTP en.wikipedia.org/wiki/Map_(higher-order_function), Map (higher-order function))
+/
template mapSlice(fun...)
    if (fun.length)
{
    ///
    @fmb auto mapSlice(size_t N, Range)
        (Slice!(N, Range) tensor)
    {
        // this static if-else block
        // may be unified with std.algorithms.iteration.map
        // after ndslice be removed from the Mir library.
        static if (fun.length > 1)
        {
            import std.functional : adjoin, unaryFun;

            alias _funs = staticMap!(unaryFun, fun);
            alias _fun = adjoin!_funs;

            // Once DMD issue #5710 is fixed, this validation loop can be moved into a template.
            foreach (f; _funs)
            {
                static assert(!is(typeof(f(RE.init)) == void),
                    "Mapping function(s) must not return void: " ~ _funs.stringof);
            }
        }
        else
        {
            import std.functional : unaryFun;

            alias _fun = unaryFun!fun;
            alias _funs = AliasSeq!(_fun);

            // Do the validation separately for single parameters due to DMD issue #15777.
            static assert(!is(typeof(_fun(RE.init)) == void),
                "Mapping function(s) must not return void: " ~ _funs.stringof);
        }

        // Specialization for packed tensors (tensors composed of tensors).
        static if (is(Range : Slice!(NI, RangeI), size_t NI, RangeI))
        {
            alias Ptr = Pack!(NI - 1, RangeI);
            alias M = Map!(Ptr, _fun);
            alias R = Slice!(N, M);
            return R(tensor._lengths[0 .. N], tensor._strides[0 .. N],
                M(Ptr(tensor._lengths[N .. $], tensor._strides[N .. $], tensor._ptr)));
        }
        else
        {
            alias M = Map!(SlicePtr!Range, _fun);
            alias R = Slice!(N, M);
            with(tensor) return R(_lengths, _strides, M(_ptr));
        }
    }
}

///
pure nothrow unittest
{
    import std.experimental.ndslice.selection : iotaSlice;

    auto s = iotaSlice(2, 3).mapSlice!(a => a * 3);
    assert(s == [[ 0,  3,  6],
                 [ 9, 12, 15]]);
}

pure nothrow unittest
{
    import std.experimental.ndslice.selection : iotaSlice;

    assert(iotaSlice(2, 3).slice.mapSlice!"a * 2" == [[0, 2, 4], [6, 8, 10]]);
}

/// Packed tensors.
pure nothrow unittest
{
    import std.experimental.ndslice.selection : iotaSlice, windows;

    //  iotaSlice        windows     mapSlice  sums ( ndFold!"a + b" )
    //                --------------
    //  -------      |  ---    ---  |      ------
    // | 0 1 2 |  => || 0 1 || 1 2 ||  => | 8 12 |
    // | 3 4 5 |     || 3 4 || 4 5 ||      ------
    //  -------      |  ---    ---  |
    //                --------------
    auto s = iotaSlice(2, 3)
        .windows(2, 2)
        .mapSlice!((a) {
            size_t s;
            foreach (r; a)
                foreach (e; r)
                    s += e;
            return s;
            });

    assert(s == [[8, 12]]);
}

pure nothrow unittest
{
    import std.experimental.ndslice.selection : iotaSlice, windows;

    auto s = iotaSlice(2, 3)
        .slice
        .windows(2, 2)
        .mapSlice!((a) {
            size_t s;
            foreach (r; a)
                foreach (e; r)
                    s += e;
            return s;
            });

    assert(s == [[8, 12]]);
}

/// Zipped tensors
pure nothrow unittest
{
    import std.experimental.ndslice.slice : assumeSameStructure;
    import std.experimental.ndslice.selection : iotaSlice;

    // 0 1 2
    // 3 4 5
    auto sl1 = iotaSlice(2, 3);
    // 1 2 3
    // 4 5 6
    auto sl2 = iotaSlice([2, 3], 1);

    // tensors must have the same strides
    assert(sl1.structure == sl2.structure);

    auto zip = assumeSameStructure!("a", "b")(sl1, sl2);

    auto lazySum = zip.mapSlice!(z => z.a + z.b);

    assert(lazySum == [[ 1,  3,  5],
                       [ 7,  9, 11]]);
}

/++
Multiple functions can be passed to `mapSlice`.
In that case, the element type of `mapSlice` is a tuple containing
one element for each function.
+/
pure nothrow unittest
{
    import std.experimental.ndslice.selection : iotaSlice;

    auto s = iotaSlice(2, 3).mapSlice!("a + a", "a * a");

    auto sums     = [[0, 2, 4], [6,  8, 10]];
    auto products = [[0, 1, 4], [9, 16, 25]];

    foreach (i; 0..s.length!0)
    foreach (j; 0..s.length!1)
    {
        auto values = s[i, j];
        assert(values[0] == sums[i][j]);
        assert(values[1] == products[i][j]);
    }
}

/++
You may alias `mapSlice` with some function(s) to a symbol and use it separately:
+/
pure nothrow unittest
{
    import std.conv : to;
    import std.experimental.ndslice.selection : iotaSlice;

    alias stringize = mapSlice!(to!string);
    assert(stringize(iotaSlice(2, 3)) == [["0", "1", "2"], ["3", "4", "5"]]);
}
