/**
This is a submodule of $(MREF std, experimental, ndslice).

License:   $(HTTP www.boost.org/LICENSE_1_0.txt, Boost License 1.0).

Authors:   Ilya Yaroshenko

Source:    $(PHOBOSSRC std/_experimental/_ndslice/_slice.d)

Macros:
SUBREF = $(REF_ALTTEXT $(TT $2), $2, std,experimental, ndslice, $1)$(NBSP)
T2=$(TR $(TDNW $(LREF $1)) $(TD $+))
T4=$(TR $(TDNW $(LREF $1)) $(TD $2) $(TD $3) $(TD $4))
STD = $(TD $(SMALL $0))
*/
module std.experimental.ndslice.slice;

import std.traits;
import std.meta;
import std.typecons; //: Flag, Yes, No;
import std.range.primitives; //: hasLength;


import std.experimental.ndslice.internal;

/++
Creates an n-dimensional slice-shell over a `range`.
Params:
    range = a random access range or an array; only index operator
        `auto opIndex(size_t index)` is required for ranges. The length of the
        range should be equal to the sum of shift and the product of
        lengths. If `ad`, the length of the
        range should be greater than or equal to the sum of shift and the product of
        lengths.
    lengths = list of lengths for each dimension
    shift = index of the first element of a `range`.
        The first `shift` elements of range are ignored.
    Names = names of elements in a slice tuple.
        Slice tuple is a slice, which holds single set of lengths and strides
        for a number of ranges.
    ra = If `yes`, the array will be replaced with
        its pointer to improve performance.
        Use `no` for compile time function evaluation.
    ad = If `yes`, no assert error will be thrown for range, which
        has a length and its length is greater then the sum of shift and the product of
        lengths.
Returns:
    n-dimensional slice
+/
auto sliced(
    Flag!"replaceArrayWithPointer" ra = Yes.replaceArrayWithPointer,
    Flag!"allowDownsize" ad = No.allowDownsize,
    Range, size_t N)(Range range, size_t[N] lengths...)
    if (!isStaticArray!Range && !isNarrowString!Range && N)
{
    return .sliced!(ra, ad)(range, lengths, 0);
}

///ditto
auto sliced(
    Flag!"replaceArrayWithPointer" ra = Yes.replaceArrayWithPointer,
    Flag!"allowDownsize" ad = No.allowDownsize,
    size_t N, Range)(Range range, size_t[N] lengths, size_t shift = 0)
    if (!isStaticArray!Range && !isNarrowString!Range && N)
in
{
    static if (hasLength!Range)
    {
        static if (ad)
        {
            assert(lengthsProduct!N(lengths) + shift <= range.length,
                "Range length must be greater than or equal to the sum of shift and the product of lengths."
                ~ tailErrorMessage!());
        }
        else
        {
            assert(lengthsProduct!N(lengths) + shift == range.length,
                "Range length must be equal to the sum of shift and the product of lengths."
                ~ tailErrorMessage!());
        }
    }
}
body
{
    static if (isDynamicArray!Range && ra)
    {
        Slice!(N, typeof(range.ptr)) ret = void;
        ret._ptr = range.ptr + shift;
    }
    else
    {
        alias S = Slice!(N, ImplicitlyUnqual!(typeof(range)));
        static if (hasElaborateAssign!(S.PureRange))
            S ret;
        else
            S ret = void;
        static if (hasPtrBehavior!(S.PureRange))
        {
            static if (S.NSeq.length == 1)
                ret._ptr = range;
            else
                ret._ptr = range._ptr;
            ret._ptr += shift;
        }
        else
        {
            static if (S.NSeq.length == 1)
            {
                ret._ptr._range = range;
                ret._ptr._shift = shift;
            }
            else
            {
                ret._ptr = range._ptr;
                ret._ptr._shift += range._strides[0] * shift;
            }
        }
    }
    ret._lengths[N - 1] = lengths[N - 1];
    static if (ret.NSeq.length == 1)
        ret._strides[N - 1] = 1;
    else
        ret._strides[N - 1] = range._strides[0];
    foreach_reverse (i; Iota!(0, N - 1))
    {
        ret._lengths[i] = lengths[i];
        ret._strides[i] = ret._strides[i + 1] * ret._lengths[i + 1];
    }
    foreach (i; Iota!(N, ret.PureN))
    {
        ret._lengths[i] = range._lengths[i - N + 1];
        ret._strides[i] = range._strides[i - N + 1];
    }
    return ret;
}

private enum bool _isSlice(T) = is(T : Slice!(N, Range), size_t N, Range);

///ditto
template sliced(Names...)
 if (Names.length && !anySatisfy!(isType, Names) && allSatisfy!(isStringValue, Names))
{
    mixin (
    "
    auto sliced(
            Flag!`replaceArrayWithPointer` ra = Yes.replaceArrayWithPointer,
            Flag!`allowDownsize` ad = No.allowDownsize,
            " ~ _Range_Types!Names ~ "
            size_t N)
            (" ~ _Range_DeclarationList!Names ~
            "size_t[N] lengths...)
    {
        alias sl = .sliced!Names;
        return sl!(ra, ad)(" ~ _Range_Values!Names ~ "lengths, 0);
    }

    auto sliced(
            Flag!`replaceArrayWithPointer` ra = Yes.replaceArrayWithPointer,
            Flag!`allowDownsize` ad = No.allowDownsize,
            size_t N, " ~ _Range_Types!Names ~ ")
            (" ~ _Range_DeclarationList!Names ~"
            size_t[N] lengths,
            size_t shift = 0)
    {
        alias RS = AliasSeq!(" ~ _Range_Types!Names ~ ");"
        ~ q{
            import std.meta : staticMap;
            static assert(!anySatisfy!(_isSlice, RS),
                `Packed slices are not allowed in slice tuples`
                ~ tailErrorMessage!());
            alias PT = PtrTuple!Names;
            alias SPT = PT!(staticMap!(PrepareRangeType, RS));
            static if (hasElaborateAssign!SPT)
                SPT range;
            else
                SPT range = void;
            version(assert) immutable minLength = lengthsProduct!N(lengths) + shift;
            foreach (i, name; Names)
            {
                alias T = typeof(range.ptrs[i]);
                alias R = RS[i];
                static assert(!isStaticArray!R);
                static assert(!isNarrowString!R);
                mixin (`alias r = range_` ~ name ~`;`);
                static if (hasLength!R)
                {
                    static if (ad)
                    {
                        assert(minLength <= r.length,
                            `length of range '` ~ name ~`' must be greater than or equal `
                            ~ `to the sum of shift and the product of lengths.`
                            ~ tailErrorMessage!());
                    }
                    else
                    {
                        assert(minLength == r.length,
                            `length of range '` ~ name ~`' must be equal `
                            ~ `to the sum of shift and the product of lengths.`
                            ~ tailErrorMessage!());
                    }
                }
                static if (isDynamicArray!T && ra)
                    range.ptrs[i] = r.ptr;
                else
                    range.ptrs[i] = T(0, r);
            }
            return .sliced!(ra, ad, N, SPT)(range, lengths, shift);
        }
    ~ "}");
}

/// ditto
auto sliced(
    Flag!"replaceArrayWithPointer" ra = Yes.replaceArrayWithPointer,
    Flag!"allowDownsize" ad = No.allowDownsize,
    Range)(Range range)
    if (!isStaticArray!Range && !isNarrowString!Range && hasLength!Range)
{
    return .sliced!(ra, ad, 1, Range)(range, [range.length]);
}

/// Creates a slice from an array.
pure nothrow unittest
{
    auto slice = slice!int(5, 6, 7);
    assert(slice.length == 5);
    assert(slice.elementsCount == 5 * 6 * 7);
    static assert(is(typeof(slice) == Slice!(3, int*)));
}

/// Creates a slice using shift parameter.
@safe @nogc pure nothrow unittest
{
    import std.range : iota;
    auto slice = (5 * 6 * 7 + 9).iota.sliced([5, 6, 7], 9);
    assert(slice.length == 5);
    assert(slice.elementsCount == 5 * 6 * 7);
    assert(slice[0, 0, 0] == 9);
}

/// Creates an 1-dimensional slice over a range.
@safe @nogc pure nothrow unittest
{
    import std.range : iota;
    auto slice = 10.iota.sliced;
    assert(slice.length == 10);
}

/// $(LINK2 https://en.wikipedia.org/wiki/Vandermonde_matrix, Vandermonde matrix)
pure nothrow unittest
{
    auto vandermondeMatrix(Slice!(1, double*) x)
    {
        auto ret = slice!double(x.length, x.length);
        foreach (i; 0 .. x.length)
        foreach (j; 0 .. x.length)
            ret[i, j] = x[i] ^^ j;
        return ret;
    }

    auto x = [1.0, 2, 3, 4, 5].sliced(5);
    auto v = vandermondeMatrix(x);
    assert(v ==
        [[  1.0,   1,   1,   1,   1],
         [  1.0,   2,   4,   8,  16],
         [  1.0,   3,   9,  27,  81],
         [  1.0,   4,  16,  64, 256],
         [  1.0,   5,  25, 125, 625]]);
}

/++
Creates a slice composed of named elements, each one of which corresponds
to a given argument. See also $(LREF assumeSameStructure).
+/
pure nothrow unittest
{
    import std.algorithm.comparison : equal;
    import std.experimental.ndslice.selection : byElement;
    import std.range : iota;

    auto alpha = 12.iota;
    auto beta = new int[12];

    auto m = sliced!("a", "b")(alpha, beta, 4, 3);
    foreach (r; m)
        foreach (e; r)
            e.b = e.a;
    assert(equal(alpha, beta));

    beta[] = 0;
    foreach (e; m.byElement)
        e.b = e.a;
    assert(equal(alpha, beta));
}

/// Random access range primitives for slices over user defined types
pure nothrow @nogc unittest
{
    struct MyIota
    {
        //`[index]` operator overloading
        auto opIndex(size_t index)
        {
            return index;
        }
    }

    alias S = Slice!(3, MyIota);
    import std.range.primitives;
    static assert(hasLength!S);
    static assert(hasSlicing!S);
    static assert(isRandomAccessRange!S);

    auto slice = MyIota().sliced(20, 10);
    assert(slice[1, 2] == 12);
    auto sCopy = slice.save;
    assert(slice[1, 2] == 12);
}

/// Slice tuple and flags
pure nothrow @nogc unittest
{
    import std.typecons : Yes, No;
    static immutable a = [1, 2, 3, 4, 5, 6];
    static immutable b = [1.0, 2, 3, 4, 5, 6];
    alias namedSliced = sliced!("a", "b");
    auto slice = namedSliced!(No.replaceArrayWithPointer, Yes.allowDownsize)
        (a, b, 2, 3);
    assert(slice[1, 2].a == slice[1, 2].b);
}

// sliced slice
pure nothrow unittest
{
    import std.experimental.ndslice.selection : iotaSlice;
    auto data = new int[24];
    foreach (int i,ref e; data)
        e = i;
    auto a = data[0..10].sliced(10)[0..6].sliced(2, 3);
    auto b = iotaSlice(10)[0..6].sliced(2, 3);
    assert(a == b);
    a[] += b;
    foreach (int i, e; data[0..6])
        assert(e == 2*i);
    foreach (int i, e; data[6..$])
        assert(e == i+6);
    auto c  = data.sliced(12, 2)[0..6].sliced(2, 3);
    auto d  = iotaSlice(12, 2)[0..6].sliced(2, 3);
    auto cc = data[0..12].sliced(2, 3, 2);
    auto dc = iotaSlice(2, 3, 2);
    assert(c._lengths == cc._lengths);
    assert(c._strides == cc._strides);
    assert(d._lengths == dc._lengths);
    assert(d._strides == dc._strides);
    assert(cc == c);
    assert(dc == d);
    auto e = data.sliced(8, 3)[0..5].sliced(5);
    auto f = iotaSlice(8, 3)[0..5].sliced(5);
    assert(e == data[0..15].sliced(5, 3));
    assert(f == iotaSlice(5, 3));
}

nothrow unittest
{
    import std.experimental.ndslice.selection : iotaSlice;

    auto sl = iotaSlice([0, 0], 1);

    assert(sl.empty!0);
    assert(sl.empty!1);

    auto gcsl1 = sl.slice;
    auto gcsl2 = slice!double(0, 0);

    import std.experimental.allocator;
    import std.experimental.allocator.mallocator;

    auto tup2 = makeSlice!size_t(Mallocator.instance, sl);
    auto tup1 = makeSlice!double(Mallocator.instance, 0, 0);

    Mallocator.instance.dispose(tup1.array);
    Mallocator.instance.dispose(tup2.array);
}

private template _Range_Types(Names...)
{
    static if (Names.length)
        enum string _Range_Types = "Range_" ~ Names[0] ~ ", " ~ _Range_Types!(Names[1..$]);
    else
        enum string _Range_Types = "";
}

private template _Range_Values(Names...)
{
    static if (Names.length)
        enum string _Range_Values = "range_" ~ Names[0] ~ ", " ~ _Range_Values!(Names[1..$]);
    else
        enum string _Range_Values = "";
}

private template _Range_DeclarationList(Names...)
{
    static if (Names.length)
    {
        enum string _Range_DeclarationList = "Range_" ~ Names[0] ~ " range_"
             ~ Names[0] ~ ", " ~ _Range_DeclarationList!(Names[1..$]);
    }
    else
        enum string _Range_DeclarationList = "";
}

private template _Slice_DeclarationList(Names...)
{
    static if (Names.length)
    {
        enum string _Slice_DeclarationList = "Slice!(N, Range_" ~ Names[0] ~ ") slice_"
             ~ Names[0] ~ ", " ~ _Slice_DeclarationList!(Names[1..$]);
    }
    else
        enum string _Slice_DeclarationList = "";
}

/++
Groups slices into a slice tuple. The slices must have identical structure.
Slice tuple is a slice, which holds single set of lengths and strides
for a number of ranges.
Params:
    Names = names of elements in a slice tuple
Returns:
    n-dimensional slice
See_also: $(LREF .Slice.structure).
+/
template assumeSameStructure(Names...)
 if (Names.length && !anySatisfy!(isType, Names) && allSatisfy!(isStringValue, Names))
{
    mixin (
    "
    auto assumeSameStructure(
            size_t N, " ~ _Range_Types!Names ~ ")
            (" ~ _Slice_DeclarationList!Names ~ ")
    {
        alias RS = AliasSeq!("  ~_Range_Types!Names ~ ");"
        ~ q{
            import std.meta : staticMap;
            static assert(!anySatisfy!(_isSlice, RS),
                `Packed slices not allowed in slice tuples`
                ~ tailErrorMessage!());
            alias PT = PtrTuple!Names;
            alias SPT = PT!(staticMap!(PrepareRangeType, RS));
            static if (hasElaborateAssign!SPT)
                Slice!(N, SPT) ret;
            else
                Slice!(N, SPT) ret = void;
            mixin (`alias slice0 = slice_` ~ Names[0] ~`;`);
            ret._lengths = slice0._lengths;
            ret._strides = slice0._strides;
            ret._ptr.ptrs[0] = slice0._ptr;
            foreach (i, name; Names[1..$])
            {
                mixin (`alias slice = slice_` ~ name ~`;`);
                assert(ret._lengths == slice._lengths,
                    `Shapes must be identical`
                    ~ tailErrorMessage!());
                assert(ret._strides == slice._strides,
                    `Strides must be identical`
                    ~ tailErrorMessage!());
                ret._ptr.ptrs[i+1] = slice._ptr;
            }
            return ret;
        }
    ~ "}");
}

///
pure nothrow unittest
{
    import std.algorithm.comparison : equal;
    import std.experimental.ndslice.selection : byElement, iotaSlice;

    auto alpha = iotaSlice(4, 3);
    auto beta = slice!int(4, 3);

    auto m = assumeSameStructure!("a", "b")(alpha, beta);
    foreach (r; m)
        foreach (e; r)
            e.b = cast(int)e.a;
    assert(alpha == beta);

    beta[] = 0;
    foreach (e; m.byElement)
        e.b = cast(int)e.a;
    assert(alpha == beta);
}

///
@safe @nogc pure nothrow unittest
{
    import std.algorithm.iteration : map, sum, reduce;
    import std.algorithm.comparison : max;
    import std.experimental.ndslice.iteration : transposed;
    /// Returns maximal column average.
    auto maxAvg(S)(S matrix) {
        return matrix.transposed.map!sum.reduce!max
             / matrix.length;
    }
    enum matrix = [1, 2,
                   3, 4].sliced!(No.replaceArrayWithPointer)(2, 2);
    ///Сompile time function evaluation
    static assert(maxAvg(matrix) == 3);
}

///
@safe @nogc pure nothrow unittest
{
    import std.algorithm.iteration : map, sum, reduce;
    import std.algorithm.comparison : max;
    import std.experimental.ndslice.iteration : transposed;
    /// Returns maximal column average.
    auto maxAvg(S)(S matrix) {
        return matrix.transposed.map!sum.reduce!max
             / matrix.length;
    }
    enum matrix = [1, 2,
                   3, 4].sliced!(No.replaceArrayWithPointer)(2, 2);
    ///Сompile time function evaluation
    static assert(maxAvg(matrix) == 3);
}

/++
Creates an array and an n-dimensional slice over it.
Params:
    lengths = list of lengths for each dimension
    slice = slice to copy shape and data from
Returns:
    n-dimensional slice
+/
Slice!(N, Select!(ra, T*, T[]))
slice(T,
    Flag!`replaceArrayWithPointer` ra = Yes.replaceArrayWithPointer,
    size_t N)(size_t[N] lengths...)
{
    immutable len = lengthsProduct(lengths);
    return new T[len].sliced!ra(lengths);
}

/// ditto
auto slice(T,
    Flag!`replaceArrayWithPointer` ra = Yes.replaceArrayWithPointer,
    size_t N)(size_t[N] lengths, T init)
{
    immutable len = lengthsProduct(lengths);
    static if (ra && !hasElaborateAssign!T)
    {
        import std.array : uninitializedArray;
        auto arr = uninitializedArray!(Unqual!T[])(len);
    }
    else
    {
        auto arr = new Unqual!T[len];
    }
    arr[] = init;
    auto ret = .sliced!ra(cast(T[])arr, lengths);
    return ret;
}

/// ditto
auto slice(
    Flag!`replaceArrayWithPointer` ra = Yes.replaceArrayWithPointer,
    size_t N, Range)(Slice!(N, Range) slice)
{
    auto ret = .slice!(Unqual!(slice.DeepElemType), ra)(slice.shape);
    ret[] = slice;
    return ret;
}

///
pure nothrow unittest
{
    auto tensor = slice!int(5, 6, 7);
    assert(tensor.length == 5);
    assert(tensor.elementsCount == 5 * 6 * 7);
    static assert(is(typeof(tensor) == Slice!(3, int*)));

    // creates duplicate using `slice`
    auto dup = tensor.slice;
    assert(dup == tensor);
}

///
pure nothrow unittest
{
    auto tensor = slice([2, 3], 5);
    assert(tensor.elementsCount == 2 * 3);
    assert(tensor[1, 1] == 5);
}

pure nothrow unittest
{
    import std.experimental.ndslice.selection : iotaSlice;
    auto tensor = iotaSlice(2, 3).slice;
    assert(tensor == [[0, 1, 2], [3, 4, 5]]);
}

/++
Creates an uninitialized array and an n-dimensional slice over it.
Params:
    lengths = list of lengths for each dimension
    slice = slice to copy shape and data from
Returns:
    uninitialized n-dimensional slice
+/
auto uninitializedSlice(T,
    Flag!`replaceArrayWithPointer` ra = Yes.replaceArrayWithPointer,
    size_t N)(size_t[N] lengths...)
{
    immutable len = lengthsProduct(lengths);
    import std.array : uninitializedArray;
    auto arr = uninitializedArray!(T[])(len);
    return arr.sliced!ra(lengths);
}

///
pure nothrow unittest
{
    auto tensor = uninitializedSlice!int(5, 6, 7);
    assert(tensor.length == 5);
    assert(tensor.elementsCount == 5 * 6 * 7);
    static assert(is(typeof(tensor) == Slice!(3, int*)));
}

/++
Allocates an array through a specified allocator and creates an n-dimensional slice over it.
See also $(MREF std, experimental, allocator).
Params:
    alloc = allocator
    lengths = list of lengths for each dimension
    init = default value for array initialization
    slice = slice to copy shape and data from
Returns:
    a structure with fields `array` and `slice`
Note:
    `makeSlice` always returns slice with mutable elements
+/
auto makeSlice(
    Flag!`replaceArrayWithPointer` ra = Yes.replaceArrayWithPointer,
    Allocator,
    size_t N, Range)(auto ref Allocator alloc, Slice!(N, Range) slice)
{
    alias T = Unqual!(slice.DeepElemType);
    return makeSlice!(T, ra)(alloc, slice);
}

/// ditto
SliceAllocationResult!(N, T, ra)
makeSlice(T,
    Flag!`replaceArrayWithPointer` ra = Yes.replaceArrayWithPointer,
    Allocator,
    size_t N)(auto ref Allocator alloc, size_t[N] lengths...)
{
    import std.experimental.allocator : makeArray;
    immutable len = lengthsProduct(lengths);
    auto array = alloc.makeArray!T(len);
    auto slice = array.sliced!ra(lengths);
    return typeof(return)(array, slice);
}

/// ditto
SliceAllocationResult!(N, T, ra)
makeSlice(T,
    Flag!`replaceArrayWithPointer` ra = Yes.replaceArrayWithPointer,
    Allocator,
    size_t N)(auto ref Allocator alloc, size_t[N] lengths, T init)
{
    import std.experimental.allocator : makeArray;
    immutable len = lengthsProduct(lengths);
    auto array = alloc.makeArray!T(len, init);
    auto slice = array.sliced!ra(lengths);
    return typeof(return)(array, slice);
}

/// ditto
SliceAllocationResult!(N, T, ra)
makeSlice(T,
    Flag!`replaceArrayWithPointer` ra = Yes.replaceArrayWithPointer,
    Allocator,
    size_t N, Range)(auto ref Allocator alloc, Slice!(N, Range) slice)
{
    import std.experimental.allocator : makeArray;
    import std.experimental.ndslice.selection : byElement;
    auto array = alloc.makeArray!T(slice.byElement);
    auto _slice = array.sliced!ra(slice.shape);
    return typeof(return)(array, _slice);
}

///
@nogc unittest
{
    import std.experimental.allocator;
    import std.experimental.allocator.mallocator;

    auto tup = makeSlice!int(Mallocator.instance, 2, 3, 4);

    assert(tup.array.length           == 24);
    assert(tup.slice.elementsCount    == 24);
    assert(tup.array.ptr == &tup.slice[0, 0, 0]);

    // makes duplicate using `makeSlice`
    tup.slice[0, 0, 0] = 3;
    auto dup = makeSlice(Mallocator.instance, tup.slice);
    assert(dup.slice == tup.slice);

    Mallocator.instance.dispose(tup.array);
    Mallocator.instance.dispose(dup.array);
}

/// Initialization with default value
@nogc unittest
{
    import std.experimental.allocator;
    import std.experimental.allocator.mallocator;

    auto tup = makeSlice(Mallocator.instance, [2, 3, 4], 10);
    auto slice = tup.slice;
    assert(slice[1, 1, 1] == 10);
    Mallocator.instance.dispose(tup.array);
}

@nogc unittest
{
    import std.experimental.allocator;
    import std.experimental.allocator.mallocator;

    // cast to your own type
    auto tup = makeSlice!double(Mallocator.instance, [2, 3, 4], 10);
    auto slice = tup.slice;
    assert(slice[1, 1, 1] == 10.0);
    Mallocator.instance.dispose(tup.array);
}

/++
Allocates an uninitialized array through a specified allocator and creates an n-dimensional slice over it.
See also $(MREF std, experimental, allocator).
Params:
    alloc = allocator
    lengths = list of lengths for each dimension
    init = default value for array initialization
    slice = slice to copy shape and data from
Returns:
    a structure with fields `array` and `slice`
+/
SliceAllocationResult!(N, T, ra)
makeUninitializedSlice(T,
    Flag!`replaceArrayWithPointer` ra = Yes.replaceArrayWithPointer,
    Allocator,
    size_t N)(auto ref Allocator alloc, size_t[N] lengths...)
{
    immutable len = lengthsProduct(lengths);
    auto array = cast(T[]) alloc.allocate(len * T.sizeof);
    auto slice = array.sliced!ra(lengths);
    return typeof(return)(array, slice);
}

///
@nogc unittest
{
    import std.experimental.allocator;
    import std.experimental.allocator.mallocator;

    auto tup = makeUninitializedSlice!int(Mallocator.instance, 2, 3, 4);

    assert(tup.array.length           == 24);
    assert(tup.slice.elementsCount    == 24);
    assert(tup.array.ptr == &tup.slice[0, 0, 0]);

    Mallocator.instance.dispose(tup.array);
}

/++
Structure used by $(LREF makeSlice) and $(LREF makeUninitializedSlice).
+/
struct SliceAllocationResult(size_t N, T, Flag!`replaceArrayWithPointer` ra)
{
    ///
    T[] array;
    ///
    Slice!(N, Select!(ra, T*, T[])) slice;
}

/++
Creates a common n-dimensional array from a slice.
Params:
    slice = slice
Returns:
    multidimensional D array
+/
auto ndarray(size_t N, Range)(Slice!(N, Range) slice)
{
    import std.array : array;
    static if (N == 1)
    {
        return array(slice);
    }
    else
    {
        import std.algorithm.iteration : map;
        return array(slice.map!(a => .ndarray(a)));
    }
}

///
pure nothrow unittest
{
    import std.experimental.ndslice.selection : iotaSlice;
    auto slice = iotaSlice(3, 4);
    auto m = slice.ndarray;
    static assert(is(typeof(m) == size_t[][]));
    assert(m == [[0, 1, 2, 3], [4, 5, 6, 7], [8, 9, 10, 11]]);
}

/++
Allocates a common n-dimensional array using data from a slice.
Params:
    alloc = allocator (optional)
    slice = slice
Returns:
    multidimensional D array
+/
auto makeNdarray(T, Allocator, size_t N, Range)(auto ref Allocator alloc,  Slice!(N, Range) slice)
{
    import std.experimental.allocator : makeArray;
    static if (N == 1)
    {
        return makeArray!T(alloc, slice);
    }
    else
    {
        alias E = typeof(makeNdarray!T(alloc, slice[0]));
        auto ret = makeArray!E(alloc, slice.length);
        foreach (i, ref e; ret)
            e = .makeNdarray!T(alloc, slice[i]);
        return ret;
    }
}

///
@nogc unittest
{
    import std.experimental.allocator;
    import std.experimental.allocator.mallocator;
    import std.experimental.ndslice.selection : iotaSlice;

    auto slice = iotaSlice(3, 4);
    auto m = Mallocator.instance.makeNdarray!long(slice);

    static assert(is(typeof(m) == long[][]));

    static immutable ar = [[0L, 1, 2, 3], [4L, 5, 6, 7], [8L, 9, 10, 11]];
    assert(m == ar);

    foreach (ref row; m)
        Mallocator.instance.dispose(row);
    Mallocator.instance.dispose(m);
}

/++
Shape of a common n-dimensional array.
Params:
    array = common n-dimensional array
Returns:
    static array of dimensions type of `size_t[n]`
Throws:
    $(LREF SliceException) if the array is not an n-dimensional parallelotope.
+/
auto shape(T)(T[] array) @property
{
    static if (isDynamicArray!T)
    {
        size_t[1 + typeof(shape(T.init)).length] ret;
        if (array.length)
        {
            ret[0] = array.length;
            ret[1..$] = shape(array[0]);
            foreach (ar; array)
                if (shape(ar) != ret[1..$])
                    throw new SliceException("ndarray should be an n-dimensional parallelotope.");
        }
        return ret;
    }
    else
    {
        size_t[1] ret = void;
        ret[0] = array.length;
        return ret;
    }
}

///
@safe pure unittest
{
    size_t[2] shape = [[1, 2, 3], [4, 5, 6]].shape;
    assert(shape == [2, 3]);

    import std.exception : assertThrown;
    assertThrown([[1, 2], [4, 5, 6]].shape);
}

/// Slice from ndarray
unittest
{
    auto array = [[1, 2, 3], [4, 5, 6]];
    auto slice = array.shape.slice!int;
    slice[] = [[1, 2, 3], [4, 5, 6]];
    assert(slice == array);
}

@safe pure unittest
{
    size_t[2] shape = (int[][]).init.shape;
    assert(shape[0] == 0);
    assert(shape[1] == 0);
}

/++
Convenience function that creates a lazy view,
where each element of the original slice is converted to the type `T`.
It uses $(SUBREF selection, mapSlice) and $(REF_ALTTEXT $(TT to), to, std,conv)$(NBSP)
composition under the hood.
Params:
    slice = a slice to create a view on.
Returns:
    A lazy slice with elements converted to the type `T`.
+/
template as(T)
{
    ///
    auto as(size_t N, Range)(Slice!(N, Range) slice)
    {
        static if (is(slice.DeepElemType == T))
        {
            return slice;
        }
        else
        {
            import std.conv : to;
            import std.experimental.ndslice.selection : mapSlice;
            return mapSlice!(to!T)(slice);
        }
    }
}

///
unittest
{
    import std.experimental.ndslice.slice : as;
    import std.experimental.ndslice.selection : diagonal;

    auto matrix = slice!double([2, 2], 0);
    auto stringMatrixView = matrix.as!string;
    assert(stringMatrixView ==
            [["0", "0"],
             ["0", "0"]]);

    matrix.diagonal[] = 1;
    assert(stringMatrixView ==
            [["1", "0"],
             ["0", "1"]]);

    /// allocate new slice composed of strings
    Slice!(2, string*) stringMatrix = stringMatrixView.slice;
}

/++
Base Exception class for $(MREF std, experimental, ndslice).
+/
class SliceException: Exception
{
    ///
    this(
        string msg,
        string file = __FILE__,
        uint line = cast(uint)__LINE__,
        Throwable next = null
        ) pure nothrow @nogc @safe
    {
        super(msg, file, line, next);
    }
}

/++
Returns the element type of the `Slice` type.
+/
alias DeepElementType(S : Slice!(N, Range), size_t N, Range) = S.DeepElemType;

///
unittest
{
    import std.range : iota;
    static assert(is(DeepElementType!(Slice!(4, const(int)[]))     == const(int)));
    static assert(is(DeepElementType!(Slice!(4, immutable(int)*))  == immutable(int)));
    static assert(is(DeepElementType!(Slice!(4, typeof(100.iota))) == int));
    //packed slice
    static assert(is(DeepElementType!(Slice!(2, Slice!(5, int*)))  == Slice!(4, int*)));
}

/++
Presents $(LREF .Slice.structure).
+/
struct Structure(size_t N)
{
    ///
    size_t[N] lengths;
    ///
    sizediff_t[N] strides;
}

/++
Presents an n-dimensional view over a range.

$(H3 Definitions)

In order to change data in a slice using
overloaded operators such as `=`, `+=`, `++`,
a syntactic structure of type
`<slice to change>[<index and interval sequence...>]` must be used.
It is worth noting that just like for regular arrays, operations `a = b`
and `a[] = b` have different meanings.
In the first case, after the operation is carried out, `a` simply points at the same data as `b`
does, and the data which `a` previously pointed at remains unmodified.
Here, `а` and `b` must be of the same type.
In the second case, `a` points at the same data as before,
but the data itself will be changed. In this instance, the number of dimensions of `b`
may be less than the number of dimensions of `а`; and `b` can be a Slice,
a regular multidimensional array, or simply a value (e.g. a number).

In the following table you will find the definitions you might come across
in comments on operator overloading.

$(BOOKTABLE
$(TR $(TH Definition) $(TH Examples at `N == 3`))
$(TR $(TD An $(B interval) is a part of a sequence of type `i .. j`.)
    $(STD `2..$-3`, `0..4`))
$(TR $(TD An $(B index) is a part of a sequence of type `i`.)
    $(STD `3`, `$-1`))
$(TR $(TD A $(B partially defined slice) is a sequence composed of
    $(B intervals) and $(B indexes) with an overall length strictly less than `N`.)
    $(STD `[3]`, `[0..$]`, `[3, 3]`, `[0..$,0..3]`, `[0..$,2]`))
$(TR $(TD A $(B fully defined index) is a sequence
    composed only of $(B indexes) with an overall length equal to `N`.)
    $(STD `[2,3,1]`))
$(TR $(TD A $(B fully defined slice) is an empty sequence
    or a sequence composed of $(B indexes) and at least one
    $(B interval) with an overall length equal to `N`.)
    $(STD `[]`, `[3..$,0..3,0..$-1]`, `[2,0..$,1]`))
)

$(H3 Internal Binary Representation)

Multidimensional Slice is a structure that consists of lengths, strides, and a pointer.
For ranges, a shell is used instead of a pointer.
This shell contains a shift of the current initial element of a multidimensional slice
and the range itself. With the exception of overloaded operators, no functions in this
package change or copy data. The operations are only carried out on lengths, strides,
and pointers. If a slice is defined over a range, only the shift of the initial element
changes instead of the pointer.

$(H4 Internal Representation for Pointers)

Type definition

-------
Slice!(N, T*)
-------

Schema

-------
Slice!(N, T*)
    size_t[N]     lengths
    sizediff_t[N] strides
    T*            ptr
-------

Example:

Definitions

-------
import std.experimental.ndslice;
auto a = new double[24];
Slice!(3, double*) s = a.sliced(2, 3, 4);
Slice!(3, double*) t = s.transposed!(1, 2, 0);
Slice!(3, double*) r = t.reversed!1;
-------

Representation

-------
s________________________
    lengths[0] ::=  2
    lengths[1] ::=  3
    lengths[2] ::=  4

    strides[0] ::= 12
    strides[1] ::=  4
    strides[2] ::=  1

    ptr        ::= &a[0]

t____transposed!(1, 2, 0)
    lengths[0] ::=  3
    lengths[1] ::=  4
    lengths[2] ::=  2

    strides[0] ::=  4
    strides[1] ::=  1
    strides[2] ::= 12

    ptr        ::= &a[0]

r______________reversed!1
    lengths[0] ::=  2
    lengths[1] ::=  3
    lengths[2] ::=  4

    strides[0] ::= 12
    strides[1] ::= -4
    strides[2] ::=  1

    ptr        ::= &a[8] // (old_strides[1] * (lengths[1] - 1)) = 8
-------

$(H4 Internal Representation for Ranges)

Type definition

-------
Slice!(N, Range)
-------

Representation

-------
Slice!(N, Range)
    size_t[N]     lengths
    sizediff_t[N] strides
    PtrShell!T    ptr
        sizediff_t shift
        Range      range
-------


Example:

Definitions

-------
import std.experimental.ndslice;
import std.range : iota;
auto a = iota(24);
alias A = typeof(a);
Slice!(3, A) s = a.sliced(2, 3, 4);
Slice!(3, A) t = s.transposed!(1, 2, 0);
Slice!(3, A) r = t.reversed!1;
-------

Representation

-------
s________________________
    lengths[0] ::=  2
    lengths[1] ::=  3
    lengths[2] ::=  4

    strides[0] ::= 12
    strides[1] ::=  4
    strides[2] ::=  1

        shift  ::=  0
        range  ::=  a

t____transposed!(1, 2, 0)
    lengths[0] ::=  3
    lengths[1] ::=  4
    lengths[2] ::=  2

    strides[0] ::=  4
    strides[1] ::=  1
    strides[2] ::= 12

        shift  ::=  0
        range  ::=  a

r______________reversed!1
    lengths[0] ::=  2
    lengths[1] ::=  3
    lengths[2] ::=  4

    strides[0] ::= 12
    strides[1] ::= -4
    strides[2] ::=  1

        shift  ::=  8 // (old_strides[1] * (lengths[1] - 1)) = 8
        range  ::=  a
-------
+/
struct Slice(size_t _N, _Range)
    if (_N && _N < 256LU && ((!is(Unqual!_Range : Slice!(N0, Range0), size_t N0, Range0)
                     && (isPointer!_Range || is(typeof(_Range.init[size_t.init]))))
                    || is(_Range == Slice!(N1, Range1), size_t N1, Range1)))
{
    @fmb:

    package:

    enum doUnittest = is(_Range == int*) && _N == 1;

    alias N = _N;
    alias Range = _Range;

    alias This = Slice!(N, Range);
    static if (is(Range == Slice!(N_, Range_), size_t N_, Range_))
    {
        enum size_t PureN = N + Range.PureN - 1;
        alias PureRange = Range.PureRange;
        alias NSeq = AliasSeq!(N, Range.NSeq);
    }
    else
    {
        alias PureN = N;
        alias PureRange = Range;
        alias NSeq = AliasSeq!(N);
    }
    alias PureThis = Slice!(PureN, PureRange);

    static assert(PureN < 256, "Slice: Pure N should be less than 256");

    static if (N == 1)
        alias ElemType = typeof(Range.init[size_t.init]);
    else
        alias ElemType = Slice!(N-1, Range);

    static if (NSeq.length == 1)
        alias DeepElemType = typeof(Range.init[size_t.init]);
    else
    static if (Range.N == 1)
        alias DeepElemType = Range.ElemType;
    else
        alias DeepElemType = Slice!(Range.N - 1, Range.Range);

    enum hasAccessByRef = isPointer!PureRange ||
        __traits(compiles, &_ptr[0]);

    enum PureIndexLength(Slices...) = Filter!(isIndex, Slices).length;

    enum isPureSlice(Slices...) =
           Slices.length <= N
        && PureIndexLength!Slices < N
        && allSatisfy!(templateOr!(isIndex, is_Slice), Slices);

    enum isFullPureSlice(Slices...) =
           Slices.length == 0
        || Slices.length == N
        && PureIndexLength!Slices < N
        && allSatisfy!(templateOr!(isIndex, is_Slice), Slices);

    size_t[PureN] _lengths;
    sizediff_t[PureN] _strides;
    SlicePtr!PureRange _ptr;

    sizediff_t backIndex(size_t dimension = 0)() @property const
        if (dimension < N)
    {
        return _strides[dimension] * (_lengths[dimension] - 1);
    }

    size_t indexStride(size_t I)(size_t[I] _indexes...) const
    {
        static if (_indexes.length)
        {
            size_t stride = _strides[0] * _indexes[0];
            assert(_indexes[0] < _lengths[0], indexError!(0, N));
            foreach (i; Iota!(1, I)) //static
            {
                assert(_indexes[i] < _lengths[i], indexError!(i, N));
                stride += _strides[i] * _indexes[i];
            }
            return stride;
        }
        else
        {
            return 0;
        }
    }

    size_t mathIndexStride(size_t I)(size_t[I] _indexes...) const
    {
        static if (_indexes.length)
        {
            size_t stride = _strides[0] * _indexes[N - 1];
            assert(_indexes[N - 1] < _lengths[0], indexError!(N - 1, N));
            foreach_reverse (i; Iota!(0, I - 1)) //static
            {
                assert(_indexes[i] < _lengths[N - 1 - i], indexError!(i, N));
                stride += _strides[N - 1 - i] * _indexes[i];
            }
            return stride;
        }
        else
        {
            return 0;
        }
    }

    static if (!hasPtrBehavior!PureRange)
    this(in size_t[PureN] lengths, in sizediff_t[PureN] strides, PtrShell!PureRange shell)
    {
        foreach (i; Iota!(0, PureN))
            _lengths[i] = lengths[i];
        foreach (i; Iota!(0, PureN))
            _strides[i] = strides[i];
        _ptr = shell;
    }

    public:

    /++
    This constructor should be used only for integration with other languages or libraries such as Julia and numpy.
    Params:
        lengths = lengths
        strides = strides
        range = range or pointer to iterate on
    +/
    this(in size_t[PureN] lengths, in sizediff_t[PureN] strides, PureRange range)
    {
        foreach (i; Iota!(0, PureN))
            _lengths[i] = lengths[i];
        foreach (i; Iota!(0, PureN))
            _strides[i] = strides[i];
        static if (hasPtrBehavior!PureRange)
            _ptr = range;
        else
            _ptr._range = range;
    }

    static if (doUnittest)
    /// Creates a 2-dimentional slice with custom strides.
    @nogc nothrow pure
    unittest
    {
        import std.experimental.ndslice.selection : byElement;
        import std.algorithm.comparison : equal;
        import std.range : only;

        uint[8] array = [1, 2, 3, 4, 5, 6, 7, 8];
        auto slice = Slice!(2, uint*)([2, 2], [4, 1], array.ptr);

        assert(&slice[0, 0] == &array[0]);
        assert(&slice[0, 1] == &array[1]);
        assert(&slice[1, 0] == &array[4]);
        assert(&slice[1, 1] == &array[5]);
        assert(slice.byElement.equal(only(1, 2, 5, 6)));

        array[2] = 42;
        assert(slice.byElement.equal(only(1, 2, 5, 6)));

        array[1] = 99;
        assert(slice.byElement.equal(only(1, 99, 5, 6)));
    }

    static if (isPointer!PureRange)
    {
        static if (NSeq.length == 1)
            private alias ConstThis = Slice!(N, const(Unqual!DeepElemType)*);
        else
            private alias ConstThis = Slice!(N, Range.ConstThis);

        static if (!is(ConstThis == This))
        {
            /++
            Implicit cast to const slices in case of underlaying range is a pointer.
            +/
            ref ConstThis toConst() const @trusted pure nothrow @nogc
            {
                pragma(inline, true);
                return *cast(ConstThis*) &this;
            }

            /// ditto
            alias toConst this;
        }
    }

    static if (doUnittest)
    ///
    unittest
    {
        Slice!(2, double*) nn;
        Slice!(2, immutable(double)*) ni;
        Slice!(2, const(double)*) nc;

        const Slice!(2, double*) cn;
        const Slice!(2, immutable(double)*) ci;
        const Slice!(2, const(double)*) cc;

        immutable Slice!(2, double*) in_;
        immutable Slice!(2, immutable(double)*) ii;
        immutable Slice!(2, const(double)*) ic;

        nc = nc; nc = cn; nc = in_;
        nc = nc; nc = cc; nc = ic;
        nc = ni; nc = ci; nc = ii;

        void fun(size_t N, T)(Slice!(N, const(T)*) sl)
        {
            //...
        }

        fun(nn); fun(cn); fun(in_);
        fun(nc); fun(cc); fun(ic);
        fun(ni); fun(ci); fun(ii);
    }

    static if (doUnittest)
    unittest
    {
        Slice!(2, Slice!(2, double*)) nn;
        Slice!(2, Slice!(2, immutable(double)*)) ni;
        Slice!(2, Slice!(2, const(double)*)) nc;

        const Slice!(2, Slice!(2, double*)) cn;
        const Slice!(2, Slice!(2, immutable(double)*)) ci;
        const Slice!(2, Slice!(2, const(double)*)) cc;

        immutable Slice!(2, Slice!(2, double*) )in_;
        immutable Slice!(2, Slice!(2, immutable(double)*)) ii;
        immutable Slice!(2, Slice!(2, const(double)*)) ic;

        nc = nn; nc = cn; nc = in_;
        nc = nc; nc = cc; nc = ic;
        nc = ni; nc = ci; nc = ii;

        void fun(size_t N, size_t M, T)(Slice!(N, Slice!(M, const(T)*)) sl)
        {
            //...
        }

        fun(nn); fun(cn); fun(in_);
        fun(nc); fun(cc); fun(ic);
        fun(ni); fun(ci); fun(ii);
    }

    /++
    Returns:
        Pointer to the first element of a slice if slice is defined as `Slice!(N, T*)`
        or plain structure with two fields `shift` and `range` otherwise.
        In second case the expression `range[shift]` refers to the first element.
        For slices with named elements the type of a return value
        has the same behavior like a pointer.
    Note:
        `ptr` is defined only for non-packed slices.
    Attention:
        `ptr` refers to the first element in the memory representation
        if and only if all strides are positive.
    +/
    static if (is(PureRange == Range))
    auto ptr() @property
    {
        static if (hasPtrBehavior!PureRange)
        {
            return _ptr;
        }
        else
        {
            static struct Ptr { size_t shift; Range range; }
            return Ptr(_ptr._shift, _ptr._range);
        }
    }

    /++
    Returns: static array of lengths
    See_also: $(LREF .Slice.structure)
    +/
    size_t[N] shape() @property const
    {
        return _lengths[0 .. N];
    }

    static if (doUnittest)
    /// Regular slice
    @safe @nogc pure nothrow unittest
    {
        import std.experimental.ndslice.selection : iotaSlice;
        assert(iotaSlice(3, 4, 5)
            .shape == cast(size_t[3])[3, 4, 5]);
    }

    static if (doUnittest)
    /// Packed slice
    @safe @nogc pure nothrow unittest
    {
        import std.experimental.ndslice.selection : pack, iotaSlice;
        assert(iotaSlice(3, 4, 5, 6, 7)
            .pack!2
            .shape == cast(size_t[3])[3, 4, 5]);
    }

    /++
    Returns: static array of lengths and static array of strides
    See_also: $(LREF .Slice.shape)
   +/
    Structure!N structure() @property const
    {
        return typeof(return)(_lengths[0 .. N], _strides[0 .. N]);
    }

    static if (doUnittest)
    /// Regular slice
    @safe @nogc pure nothrow unittest
    {
        import std.experimental.ndslice.selection : iotaSlice;
        assert(iotaSlice(3, 4, 5)
            .structure == Structure!3([3, 4, 5], [20, 5, 1]));
    }

    static if (doUnittest)
    /// Modified regular slice
    @safe @nogc pure nothrow unittest
    {
        import std.experimental.ndslice.selection : pack, iotaSlice;
        import std.experimental.ndslice.iteration : reversed, strided, transposed;
        assert(iotaSlice(3, 4, 50)
            .reversed!2      //makes stride negative
            .strided!2(6)    //multiplies stride by 6 and changes corresponding length
            .transposed!2    //brings dimension `2` to the first position
            .structure == Structure!3([9, 3, 4], [-6, 200, 50]));
    }

    static if (doUnittest)
    /// Packed slice
    @safe @nogc pure nothrow unittest
    {
        import std.experimental.ndslice.selection : pack, iotaSlice;
        assert(iotaSlice(3, 4, 5, 6, 7)
            .pack!2
            .structure == Structure!3([3, 4, 5], [20 * 42, 5 * 42, 1 * 42]));
    }

    /++
    Forward range primitive.
    +/
    auto save() @property
    {
        return this;
    }

    static if (doUnittest)
    /// Forward range
    @safe @nogc pure nothrow unittest
    {
        import std.experimental.ndslice.selection : iotaSlice;
        auto slice = iotaSlice(2, 3).save;
    }

    static if (doUnittest)
    /// Pointer type.
    pure nothrow unittest
    {
         //slice type is `Slice!(2, int*)`
         auto slice = slice!int(2, 3).save;
    }


    /++
    Multidimensional `length` property.
    Returns: length of the corresponding dimension
    See_also: $(LREF .Slice.shape), $(LREF .Slice.structure)
    +/
    size_t length(size_t dimension = 0)() @property const
        if (dimension < N)
    {
        return _lengths[dimension];
    }

    static if (doUnittest)
    ///
    @safe @nogc pure nothrow unittest
    {
        import std.experimental.ndslice.selection : iotaSlice;
        auto slice = iotaSlice(3, 4, 5);
        assert(slice.length   == 3);
        assert(slice.length!0 == 3);
        assert(slice.length!1 == 4);
        assert(slice.length!2 == 5);
    }

    alias opDollar = length;

    /++
        Multidimensional `stride` property.
        Returns: stride of the corresponding dimension
        See_also: $(LREF .Slice.structure)
    +/
    sizediff_t stride(size_t dimension = 0)() @property const
        if (dimension < N)
    {
        return _strides[dimension];
    }

    static if (doUnittest)
    /// Regular slice
    @safe @nogc pure nothrow unittest
    {
        import std.experimental.ndslice.selection : iotaSlice;
        auto slice = iotaSlice(3, 4, 5);
        assert(slice.stride   == 20);
        assert(slice.stride!0 == 20);
        assert(slice.stride!1 == 5);
        assert(slice.stride!2 == 1);
    }

    static if (doUnittest)
    /// Modified regular slice
    @safe @nogc pure nothrow unittest
    {
        import std.experimental.ndslice.iteration : reversed, strided, swapped;
        import std.experimental.ndslice.selection : iotaSlice;
        assert(iotaSlice(3, 4, 50)
            .reversed!2      //makes stride negative
            .strided!2(6)    //multiplies stride by 6 and changes the corresponding length
            .swapped!(1, 2)  //swaps dimensions `1` and `2`
            .stride!1 == -6);
    }

    /++
    Multidimensional input range primitive.
    +/
    bool empty(size_t dimension = 0)()
    @property const
        if (dimension < N)
    {
        return _lengths[dimension] == 0;
    }

    ///ditto
    auto ref front(size_t dimension = 0)() @property
        if (dimension < N)
    {
        assert(!empty!dimension);
        static if (PureN == 1)
        {
            return _ptr[0];
        }
        else
        {
            static if (hasElaborateAssign!PureRange)
                ElemType ret;
            else
                ElemType ret = void;
            foreach (i; Iota!(0, dimension))
            {
                ret._lengths[i] = _lengths[i];
                ret._strides[i] = _strides[i];
            }
            foreach (i; Iota!(dimension, PureN-1))
            {
                ret._lengths[i] = _lengths[i + 1];
                ret._strides[i] = _strides[i + 1];
            }
            ret._ptr = _ptr;
            return ret;
        }
    }

    static if (PureN == 1 && isMutable!DeepElemType && !hasAccessByRef)
    {
        ///ditto
        auto front(size_t dimension = 0, T)(T value) @property
            if (dimension == 0)
        {
            assert(!empty!dimension);
            return _ptr[0] = value;
        }
    }

    ///ditto
    auto ref back(size_t dimension = 0)() @property
        if (dimension < N)
    {
        assert(!empty!dimension);
        static if (PureN == 1)
        {
            return _ptr[backIndex];
        }
        else
        {
            static if (hasElaborateAssign!PureRange)
                ElemType ret;
            else
                ElemType ret = void;
            foreach (i; Iota!(0, dimension))
            {
                ret._lengths[i] = _lengths[i];
                ret._strides[i] = _strides[i];
            }
            foreach (i; Iota!(dimension, PureN-1))
            {
                ret._lengths[i] = _lengths[i + 1];
                ret._strides[i] = _strides[i + 1];
            }
            ret._ptr = _ptr + backIndex!dimension;
            return ret;
        }
    }

    static if (PureN == 1 && isMutable!DeepElemType && !hasAccessByRef)
    {
        ///ditto
        auto back(size_t dimension = 0, T)(T value) @property
            if (dimension == 0)
        {
            assert(!empty!dimension);
            return _ptr[backIndex] = value;
        }
    }

    ///ditto
    void popFront(size_t dimension = 0)()
        if (dimension < N)
    {
        assert(_lengths[dimension], __FUNCTION__ ~ ": length!" ~ dimension.stringof ~ " should be greater than 0.");
        _lengths[dimension]--;
        _ptr += _strides[dimension];
    }

    ///ditto
    void popBack(size_t dimension = 0)()
        if (dimension < N)
    {
        assert(_lengths[dimension], __FUNCTION__ ~ ": length!" ~ dimension.stringof ~ " should be greater than 0.");
        _lengths[dimension]--;
    }

    ///ditto
    void popFrontExactly(size_t dimension = 0)(size_t n)
        if (dimension < N)
    {
        assert(n <= _lengths[dimension],
            __FUNCTION__ ~ ": n should be less than or equal to length!" ~ dimension.stringof);
        _lengths[dimension] -= n;
        _ptr += _strides[dimension] * n;
    }

    ///ditto
    void popBackExactly(size_t dimension = 0)(size_t n)
        if (dimension < N)
    {
        assert(n <= _lengths[dimension],
            __FUNCTION__ ~ ": n should be less than or equal to length!" ~ dimension.stringof);
        _lengths[dimension] -= n;
    }

    ///ditto
    void popFrontN(size_t dimension = 0)(size_t n)
        if (dimension < N)
    {
        import std.algorithm.comparison : min;
        popFrontExactly!dimension(min(n, _lengths[dimension]));
    }

    ///ditto
    void popBackN(size_t dimension = 0)(size_t n)
        if (dimension < N)
    {
        import std.algorithm.comparison : min;
        popBackExactly!dimension(min(n, _lengths[dimension]));
    }

    static if (doUnittest)
    ///
    @safe @nogc pure nothrow unittest
    {
        import std.range.primitives;
        import std.experimental.ndslice.selection : iotaSlice;
        auto slice = iotaSlice(10, 20, 30);

        static assert(isRandomAccessRange!(typeof(slice)));
        static assert(hasSlicing!(typeof(slice)));
        static assert(hasLength!(typeof(slice)));

        assert(slice.shape == cast(size_t[3])[10, 20, 30]);
        slice.popFront;
        slice.popFront!1;
        slice.popBackExactly!2(4);
        assert(slice.shape == cast(size_t[3])[9, 19, 26]);

        auto matrix = slice.front!1;
        assert(matrix.shape == cast(size_t[2])[9, 26]);

        auto column = matrix.back!1;
        assert(column.shape == cast(size_t[1])[9]);

        slice.popFrontExactly!1(slice.length!1);
        assert(slice.empty   == false);
        assert(slice.empty!1 == true);
        assert(slice.empty!2 == false);
        assert(slice.shape == cast(size_t[3])[9, 0, 26]);

        assert(slice.back.front!1.empty);

        slice.popFrontN!0(40);
        slice.popFrontN!2(40);
        assert(slice.shape == cast(size_t[3])[0, 0, 0]);
    }

    package void popFront(size_t dimension)
    {
        assert(dimension < N, __FUNCTION__ ~ ": dimension should be less than N = " ~ N.stringof);
        assert(_lengths[dimension], ": length!dim should be greater than 0.");
        _lengths[dimension]--;
        _ptr += _strides[dimension];
    }


    package void popBack(size_t dimension)
    {
        assert(dimension < N, __FUNCTION__ ~ ": dimension should be less than N = " ~ N.stringof);
        assert(_lengths[dimension], ": length!dim should be greater than 0.");
        _lengths[dimension]--;
    }

    package void popFrontExactly(size_t dimension, size_t n)
    {
        assert(dimension < N, __FUNCTION__ ~ ": dimension should be less than N = " ~ N.stringof);
        assert(n <= _lengths[dimension], __FUNCTION__ ~ ": n should be less than or equal to length!dim");
        _lengths[dimension] -= n;
        _ptr += _strides[dimension] * n;
    }

    package void popBackExactly(size_t dimension, size_t n)
    {
        assert(dimension < N, __FUNCTION__ ~ ": dimension should be less than N = " ~ N.stringof);
        assert(n <= _lengths[dimension], __FUNCTION__ ~ ": n should be less than or equal to length!dim");
        _lengths[dimension] -= n;
    }

    package void popFrontN(size_t dimension, size_t n)
    {
        assert(dimension < N, __FUNCTION__ ~ ": dimension should be less than N = " ~ N.stringof);
        import std.algorithm.comparison : min;
        popFrontExactly(dimension, min(n, _lengths[dimension]));
    }

    package void popBackN(size_t dimension, size_t n)
    {
        assert(dimension < N, __FUNCTION__ ~ ": dimension should be less than N = " ~ N.stringof);
        import std.algorithm.comparison : min;
        popBackExactly(dimension, min(n, _lengths[dimension]));
    }

    /++
    Returns: `true` if for any dimension the length equals to `0`, and `false` otherwise.
    +/
    bool anyEmpty() const
    {
        foreach (i; Iota!(0, N))
            if (_lengths[i] == 0)
                return true;
        return false;
    }

    static if (doUnittest)
    ///
    unittest
    {
        import std.experimental.ndslice.selection : iotaSlice;
        auto s = iotaSlice(2, 3);
        assert(!s.anyEmpty);
        s.popFrontExactly!1(3);
        assert(s.anyEmpty);
    }

    /++
    Convenience function for backward indexing.

    Returns: `this[$-index[0], $-index[1], ..., $-index[N-1]]`
    +/
    auto ref backward(size_t[N] index)
    {
        foreach (i; Iota!(0, N))
            index[i] = _lengths[i] - index[i];
        return this[index];
    }

    static if (doUnittest)
    ///
    @safe @nogc pure nothrow unittest
    {
        import std.experimental.ndslice.selection : iotaSlice;
        auto s = iotaSlice(2, 3);
        assert(s[$ - 1, $ - 2] == s.backward([1, 2]));
    }

    /++
    Returns: Total number of elements in a slice
    +/
    size_t elementsCount() const
    {
        size_t len = 1;
        foreach (i; Iota!(0, N))
            len *= _lengths[i];
        return len;
    }

    static if (doUnittest)
    /// Regular slice
    @safe @nogc pure nothrow unittest
    {
        import std.experimental.ndslice.selection : iotaSlice;
        assert(iotaSlice(3, 4, 5).elementsCount == 60);
    }


    static if (doUnittest)
    /// Packed slice
    @safe @nogc pure nothrow unittest
    {
        import std.experimental.ndslice.selection : pack, evertPack, iotaSlice;
        auto slice = iotaSlice(3, 4, 5, 6, 7, 8);
        auto p = slice.pack!2;
        assert(p.elementsCount == 360);
        assert(p[0, 0, 0, 0].elementsCount == 56);
        assert(p.evertPack.elementsCount == 56);
    }

    /++
    Overloading `==` and `!=`
    +/
    bool opEquals(size_t NR, RangeR)(Slice!(NR, RangeR) rslice)
        if (Slice!(NR, RangeR).PureN == PureN)
    {
        foreach (i; Iota!(0, PureN))
            if (this._lengths[i] != rslice._lengths[i])
                return false;
        static if (
               !hasReference!(typeof(this))
            && !hasReference!(typeof(rslice))
            && __traits(compiles, this._ptr == rslice._ptr)
            )
        {
            if (this._strides == rslice._strides && this._ptr == rslice._ptr)
                return true;
        }
        foreach (i; Iota!(0, PureN))
            if (this._lengths[i] == 0)
                return true;
        import std.experimental.ndslice.selection : unpack;
        return opEqualsImpl(this.unpack, rslice.unpack);
    }

    ///ditto
    bool opEquals(T)(T[] rarrary)
    {
        auto slice = this;
        if (slice.length != rarrary.length)
            return false;
        if (rarrary.length) do
        {
            if (slice.front != rarrary.front)
                return false;
            slice.popFront;
            rarrary.popFront;
        }
        while (rarrary.length);
        return true;
    }

    static if (doUnittest)
    ///
    pure nothrow unittest
    {
        auto a = [1, 2, 3, 4].sliced(2, 2);

        assert(a != [1, 2, 3, 4, 5, 6].sliced(2, 3));
        assert(a != [[1, 2, 3], [4, 5, 6]]);

        assert(a == [1, 2, 3, 4].sliced(2, 2));
        assert(a == [[1, 2], [3, 4]]);

        assert(a != [9, 2, 3, 4].sliced(2, 2));
        assert(a != [[9, 2], [3, 4]]);
    }

    static if (doUnittest)
    pure nothrow unittest
    {
        import std.experimental.ndslice.iteration : dropExactly;
        import std.experimental.ndslice.selection : iotaSlice;
        assert(iotaSlice(2, 3).slice.dropExactly!0(2) == iotaSlice([4, 3], 2).dropExactly!0(4));
    }

    /++
    Computes hash value using MurmurHash3 algorithms without the finalization step.
    Built-in associative arrays have the finalization step.

    Returns: Hash value type of `size_t`.

    See_also: $(LREF Slice.toMurmurHash3), $(MREF std, _digest, murmurhash).
    +/
    size_t toHash() const
    {
        static if (size_t.sizeof == 8)
        {
            auto ret = toMurmurHash3!128;
            return ret[0] ^ ret[1];
        }
        else
        {
            return toMurmurHash3!32;
        }
    }

    static if (doUnittest)
    ///
    pure nothrow @nogc @safe
    unittest
    {
        import std.experimental.ndslice.selection : iotaSlice;
        const sl = iotaSlice(3, 7);
        size_t hash = sl.toHash;
    }

    static if (doUnittest)
    ///
    pure nothrow
    unittest
    {
        import std.experimental.ndslice.iteration : allReversed;
        import std.experimental.ndslice.selection : iotaSlice;

        // hash is the same for allocated data and for generated data
        auto a = iotaSlice(3, 7);
        auto b = iotaSlice(3, 7).slice;

        assert(a.toHash == b.toHash);
        assert(typeid(typeof(a)).getHash(&a) == typeid(typeof(b)).getHash(&b));

        // hash does not depend on strides
        a = iotaSlice(3, 7).allReversed;
        b = iotaSlice(3, 7).allReversed.slice;

        assert(a.toHash == b.toHash);
        assert(typeid(typeof(a)).getHash(&a) == typeid(typeof(b)).getHash(&b));
    }

    /++
    Computes hash value using MurmurHash3 algorithms without the finalization step.

    Returns:
        Hash value type of `MurmurHash3!(size, opt).get()`.

    See_also: $(LREF Slice.toHash), $(MREF std, _digest, murmurhash)
    +/
    auto toMurmurHash3(uint size /* 32 or 128 */ , uint opt = size_t.sizeof == 8 ? 64 : 32)() const
    {
        import std.digest.murmurhash : MurmurHash3;
        enum msg = "unable to compute hash value for type " ~ DeepElemType.stringof;
        static if (size_t.sizeof == 8)
            auto hasher = MurmurHash3!(size, opt)(length);
        else
            auto hasher = MurmurHash3!(size, opt)(cast(uint) length);
        enum hasMMH3 = __traits(compiles, {
            MurmurHash3!(size, opt) hasher;
            foreach (elem; (Unqual!This).init)
                hasher.putElement(elem.toMurmurHash3!(size, opt));
            });
        static if (PureN == 1 && !hasMMH3)
        {
            static if (ElemType.sizeof <= 8 * hasher.Element.sizeof && __traits(isPOD, ElemType))
            {
                alias E = Unqual!ElemType;
            }
            else
            {
                alias E = size_t;
            }
            enum K = hasher.Element.sizeof / E.sizeof + bool(hasher.Element.sizeof % E.sizeof != 0);
            enum B = E.sizeof / hasher.Element.sizeof + bool(E.sizeof % hasher.Element.sizeof != 0);
            static assert (K == 1 || B == 1);
            static union U
            {
                hasher.Element[B] blocks;
                E[K] elems;
            }
            U u;
            auto r = cast(Unqual!This) this;
            // if element is smaller then blocks
            static if (K > 1)
            {
                // cut tail composed of elements from the front
                if (auto rem = r.length % K)
                {
                    do
                    {
                        static if (is(E == Unqual!ElemType))
                            u.elems[rem] = cast() r.front;
                        else
                        static if (__traits(compiles, r.front.toHash))
                            u.elems[rem] = r.front.toHash;
                        else
                        static if (__traits(compiles, typeid(ElemType).getHash(&r.front)))
                            u.elems[rem] = typeid(ElemType).getHash(&r.front);
                        else
                        {
                            auto f = r.front;
                            u.elems[rem] = typeid(ElemType).getHash(&f);
                        }

                        r.popFront;
                    }
                    while (--rem);
                    hasher.putElement(u.blocks[0]);
                }
            }
            // if hashing elements in memory
            static if (is(E == ElemType) && (isPointer!Range || isDynamicArray!Range))
            {
                import std.math : isPowerOf2;
                // .. and elements can fill entire block
                static if (ElemType.sizeof.isPowerOf2)
                {
                    // then try to optimize blocking
                    if (stride == 1)
                    {
                        static if (isPointer!Range)
                        {
                            hasher.putElements(cast(hasher.Element[]) r._ptr[0 .. r.length]);
                        }
                        else
                        {
                            hasher.putElements(cast(hasher.Element[]) r._ptr._range[r._ptr._shift .. r.length + r._ptr._shift]);
                        }
                        return hasher.get;
                    }
                }
            }
            while (r.length)
            {
                foreach (k; Iota!(0, K))
                {
                    static if (is(E == Unqual!ElemType))
                        u.elems[k] = cast() r.front;
                    else
                    static if (__traits(compiles, r.front.toHash))
                        u.elems[k] = r.front.toHash;
                    else
                    static if (__traits(compiles, typeid(ElemType).getHash(&r.front)))
                        u.elems[k] = typeid(ElemType).getHash(&r.front);
                    else
                    {
                        auto f = r.front;
                        u.elems[k] = typeid(ElemType).getHash(&f);
                    }
                    r.popFront;
                }
                foreach (b; Iota!(0, B))
                {
                    hasher.putElement(u.blocks[b]);
                }
            }
        }
        else
        {
            foreach (elem; cast(Unqual!This) this)
                hasher.putElement(elem.toMurmurHash3!(size, opt));
        }
        return hasher.get;
    }

    _Slice opSlice(size_t dimension)(size_t i, size_t j)
        if (dimension < N)
    in   {
        assert(i <= j,
            "Slice.opSlice!" ~ dimension.stringof ~ ": the left bound must be less than or equal to the right bound.");
        enum errorMsg = ": difference between the right and the left bounds"
                        ~ " must be less than or equal to the length of the given dimension.";
        assert(j - i <= _lengths[dimension],
              "Slice.opSlice!" ~ dimension.stringof ~ errorMsg);
    }
    body
    {
        return typeof(return)(i, j);
    }

    /++
    $(BOLD Fully defined index)
    +/
    auto ref opIndex(size_t I)(size_t[I] _indexes...)
        if(I && I <= N)
    {
        static if (I == PureN)
            return _ptr[indexStride(_indexes)];
        else
        static if (N == I)
            return DeepElemType(_lengths[N .. $], _strides[N .. $], _ptr + indexStride(_indexes));
        else
            return Slice!(N - I, Range)(_lengths[I .. $], _strides[I .. $], _ptr + indexStride(_indexes));
    }

    ///ditto
    auto ref opCall()(size_t[N] _indexes...)
    {
        static if (PureN == N)
            return _ptr[mathIndexStride(_indexes)];
        else
            return DeepElemType(_lengths[N .. $], _strides[N .. $], _ptr + mathIndexStride(_indexes));
    }

    static if (doUnittest)
    ///
    pure nothrow unittest
    {
        auto slice = slice!int(5, 2);

        auto q = &slice[3, 1];      // D & C order
        auto p = &slice(1, 3);      // Math & Fortran order
        assert(p is q);
        *q = 4;
        assert(slice[3, 1] == 4);   // D & C order
        assert(slice(1, 3) == 4);   // Math & Fortran order

        size_t[2] indexP = [1, 3];
        size_t[2] indexQ = [3, 1];
        assert(slice[indexQ] == 4);  // D & C order
        assert(slice(indexP) == 4);  // Math & Fortran order
    }

    static if (doUnittest)
    pure nothrow unittest
    {
        // check with different PureN
        import std.experimental.ndslice.selection : pack, iotaSlice;
        auto pElements = iotaSlice(2, 3, 4, 5).pack!2;
        import std.range : iota;
        import std.algorithm.comparison : equal;

        // D & C order
        assert(pElements[$-1, $-1][$-1].equal([5].iotaSlice(115)));
        assert(pElements[[1, 2]][$-1].equal([5].iotaSlice(115)));

        // Math & Fortran
        assert(pElements(2, 1)[$-1].equal([5].iotaSlice(115)));
        assert(pElements([2, 1])[$-1].equal([5].iotaSlice(115)));
    }

    /++
    $(BOLD Partially or fully defined slice.)
    +/
    auto opIndex(Slices...)(Slices slices)
        if (isPureSlice!Slices)
    {
        static if (Slices.length)
        {

            enum size_t j(size_t n) = n - Filter!(isIndex, Slices[0 .. n+1]).length;
            enum size_t F = PureIndexLength!Slices;
            enum size_t S = Slices.length;
            static assert(N-F > 0);
            size_t stride;
            static if (hasElaborateAssign!PureRange)
                Slice!(N-F, Range) ret;
            else
                Slice!(N-F, Range) ret = void;
            foreach (i, slice; slices) //static
            {
                static if (isIndex!(Slices[i]))
                {
                    assert(slice < _lengths[i], "Slice.opIndex: index must be less than length");
                    stride += _strides[i] * slice;
                }
                else
                {
                    stride += _strides[i] * slice.i;
                    ret._lengths[j!i] = slice.j - slice.i;
                    ret._strides[j!i] = _strides[i];
                }
            }
            foreach (i; Iota!(S, PureN))
            {
                ret._lengths[i - F] = _lengths[i];
                ret._strides[i - F] = _strides[i];
            }
            ret._ptr = _ptr + stride;
            return ret;
        }
        else
        {
            return this;
        }
    }

    static if (doUnittest)
    ///
    pure nothrow unittest
    {
        auto slice = slice!int(5, 3);

        /// Fully defined slice
        assert(slice[] == slice);
        auto sublice = slice[0..$-2, 1..$];

        /// Partially defined slice
        auto row = slice[3];
        auto col = slice[0..$, 1];
    }

    static if (doUnittest)
    pure nothrow unittest
    {
        auto slice = slice!(int, No.replaceArrayWithPointer)(5, 3);

        /// Fully defined slice
        assert(slice[] == slice);
        auto sublice = slice[0..$-2, 1..$];

        /// Partially defined slice
        auto row = slice[3];
        auto col = slice[0..$, 1];
    }

    static if (isMutable!DeepElemType)
    {
        /++
        Assignment of a value of `Slice` type to a $(B fully defined slice).

        Optimization:
            SIMD instructions may be used if both slices have the last stride equals to 1.
        +/
        void opIndexAssign(size_t RN, RRange, Slices...)(Slice!(RN, RRange) value, Slices slices)
            if (isFullPureSlice!Slices && RN <= ReturnType!(opIndex!Slices).N)
        {
            opIndexAssignImpl!""(this[slices], value);
        }

        static if (doUnittest)
        ///
        pure nothrow unittest
        {
            auto a = slice!int(2, 3);
            auto b = [1, 2, 3, 4].sliced(2, 2);

            a[0..$, 0..$-1] = b;
            assert(a == [[1, 2, 0], [3, 4, 0]]);

            // fills both rows with b[0]
            a[0..$, 0..$-1] = b[0];
            assert(a == [[1, 2, 0], [1, 2, 0]]);

            a[1, 0..$-1] = b[1];
            assert(a[1] == [3, 4, 0]);

            a[1, 0..$-1][] = b[0];
            assert(a[1] == [1, 2, 0]);
        }

        static if (doUnittest)
        /// Left slice is packed
        pure nothrow unittest
        {
            import std.experimental.ndslice.selection : blocks, iotaSlice;
            auto a = slice!size_t(4, 4);
            a.blocks(2, 2)[] = iotaSlice(2, 2);

            assert(a ==
                    [[0, 0, 1, 1],
                     [0, 0, 1, 1],
                     [2, 2, 3, 3],
                     [2, 2, 3, 3]]);
        }

        static if (doUnittest)
        /// Both slices are packed
        pure nothrow unittest
        {
            import std.experimental.ndslice.selection : blocks, iotaSlice, pack;
            auto a = slice!size_t(4, 4);
            a.blocks(2, 2)[] = iotaSlice(2, 2, 2).pack!1;

            assert(a ==
                    [[0, 1, 2, 3],
                     [0, 1, 2, 3],
                     [4, 5, 6, 7],
                     [4, 5, 6, 7]]);
        }

        static if (doUnittest)
        pure nothrow unittest
        {
            auto a = slice!(int, No.replaceArrayWithPointer)(2, 3);
            auto b = [1, 2, 3, 4].sliced(2, 2);

            a[0..$, 0..$-1] = b;
            assert(a == [[1, 2, 0], [3, 4, 0]]);

            a[0..$, 0..$-1] = b[0];
            assert(a == [[1, 2, 0], [1, 2, 0]]);

            a[1, 0..$-1] = b[1];
            assert(a[1] == [3, 4, 0]);

            a[1, 0..$-1][] = b[0];
            assert(a[1] == [1, 2, 0]);
        }

        /++
        Assignment of a regular multidimensional array to a $(B fully defined slice).

        Optimization:
            SIMD instructions may be used if the slice has the last stride equals to 1.
        +/
        void opIndexAssign(T, Slices...)(T[] value, Slices slices)
            if (isFullPureSlice!Slices
                && !isDynamicArray!DeepElemType
                && DynamicArrayDimensionsCount!(T[]) <= ReturnType!(opIndex!Slices).N)
        {
            opIndexAssignImpl!""(this[slices], value);
        }

        static if (doUnittest)
        ///
        pure nothrow unittest
        {
            auto a = slice!int(2, 3);
            auto b = [[1, 2], [3, 4]];

            a[] = [[1, 2, 3], [4, 5, 6]];
            assert(a == [[1, 2, 3], [4, 5, 6]]);

            a[0..$, 0..$-1] = [[1, 2], [3, 4]];
            assert(a == [[1, 2, 3], [3, 4, 6]]);

            a[0..$, 0..$-1] = [1, 2];
            assert(a == [[1, 2, 3], [1, 2, 6]]);

            a[1, 0..$-1] = [3, 4];
            assert(a[1] == [3, 4, 6]);

            a[1, 0..$-1][] = [3, 4];
            assert(a[1] == [3, 4, 6]);
        }

        static if (doUnittest)
        /// Packed slices
        pure nothrow unittest
        {
            import std.experimental.ndslice.selection : blocks;
            auto a = slice!int(4, 4);
            a.blocks(2, 2)[] = [[0, 1], [2, 3]];

            assert(a ==
                    [[0, 0, 1, 1],
                     [0, 0, 1, 1],
                     [2, 2, 3, 3],
                     [2, 2, 3, 3]]);
        }

        static if (doUnittest)
        pure nothrow unittest
        {
            auto a = slice!(int, No.replaceArrayWithPointer)(2, 3);
            auto b = [[1, 2], [3, 4]];

            a[] = [[1, 2, 3], [4, 5, 6]];
            assert(a == [[1, 2, 3], [4, 5, 6]]);

            a[0..$, 0..$-1] = [[1, 2], [3, 4]];
            assert(a == [[1, 2, 3], [3, 4, 6]]);

            a[0..$, 0..$-1] = [1, 2];
            assert(a == [[1, 2, 3], [1, 2, 6]]);

            a[1, 0..$-1] = [3, 4];
            assert(a[1] == [3, 4, 6]);

            a[1, 0..$-1][] = [3, 4];
            assert(a[1] == [3, 4, 6]);
        }

        /++
        Assignment of a value (e.g. a number) to a $(B fully defined slice).

        Optimization:
            SIMD instructions may be used if the slice has the last stride equals to 1.
        +/
        void opIndexAssign(T, Slices...)(T value, Slices slices)
            if (isFullPureSlice!Slices
                && (!isDynamicArray!T || isDynamicArray!DeepElemType)
                && !is(T : Slice!(RN, RRange), size_t RN, RRange))
        {
            opIndexAssignImpl!""(this[slices], value);
        }

        static if (doUnittest)
        ///
        pure nothrow unittest
        {
            auto a = slice!int(2, 3);

            a[] = 9;
            assert(a == [[9, 9, 9], [9, 9, 9]]);

            a[0..$, 0..$-1] = 1;
            assert(a == [[1, 1, 9], [1, 1, 9]]);

            a[0..$, 0..$-1] = 2;
            assert(a == [[2, 2, 9], [2, 2, 9]]);

            a[1, 0..$-1] = 3;
            assert(a[1] == [3, 3, 9]);

            a[1, 0..$-1] = 4;
            assert(a[1] == [4, 4, 9]);

            a[1, 0..$-1][] = 5;
            assert(a[1] == [5, 5, 9]);
        }

        static if (doUnittest)
        /// Packed slices have the same behavior.
        pure nothrow unittest
        {
            import std.experimental.ndslice.selection : pack;
            auto a = slice!int(2, 3).pack!1;

            a[] = 9;
            assert(a == [[9, 9, 9], [9, 9, 9]]);
        }

        static if (doUnittest)
        pure nothrow unittest
        {
            auto a = slice!(int, No.replaceArrayWithPointer)(2, 3);

            a[] = 9;
            assert(a == [[9, 9, 9], [9, 9, 9]]);

            a[0..$, 0..$-1] = 1;
            assert(a == [[1, 1, 9], [1, 1, 9]]);

            a[0..$, 0..$-1] = 2;
            assert(a == [[2, 2, 9], [2, 2, 9]]);

            a[1, 0..$-1] = 3;
            assert(a[1] == [3, 3, 9]);

            a[1, 0..$-1] = 4;
            assert(a[1] == [4, 4, 9]);

            a[1, 0..$-1][] = 5;
            assert(a[1] == [5, 5, 9]);
        }

        static if (PureN == N)
        /++
        Assignment of a value (e.g. a number) to a $(B fully defined index).
        +/
        auto ref opIndexAssign(T)(T value, size_t[N] _indexes...)
        {
            return _ptr[indexStride(_indexes)] = value;
        }

        static if (doUnittest)
        ///
        pure nothrow unittest
        {
            auto a = slice!int(2, 3);

            a[1, 2] = 3;
            assert(a[1, 2] == 3);
        }

        static if (doUnittest)
        pure nothrow unittest
        {
            auto a = slice!(int, No.replaceArrayWithPointer)(2, 3);

            a[1, 2] = 3;
            assert(a[1, 2] == 3);
        }

        static if (doUnittest)
        pure nothrow unittest
        {
            auto a = new int[6].sliced(2, 3);

            a[[1, 2]] = 3;
            assert(a[[1, 2]] == 3);
        }

        static if (doUnittest)
        pure nothrow unittest
        {
            auto a = new int[6].sliced!(No.replaceArrayWithPointer)(2, 3);

            a[[1, 2]] = 3;
            assert(a[[1, 2]] == 3);
        }

        static if (PureN == N)
        /++
        Op Assignment `op=` of a value (e.g. a number) to a $(B fully defined index).
        +/
        auto ref opIndexOpAssign(string op, T)(T value, size_t[N] _indexes...)
        {
            return mixin (`_ptr[indexStride(_indexes)] ` ~ op ~ `= value`);
        }

        static if (doUnittest)
        ///
        pure nothrow unittest
        {
            auto a = slice!int(2, 3);

            a[1, 2] += 3;
            assert(a[1, 2] == 3);
        }

        static if (doUnittest)
        pure nothrow unittest
        {
            auto a = new int[6].sliced(2, 3);

            a[[1, 2]] += 3;
            assert(a[[1, 2]] == 3);
        }

        static if (doUnittest)
        pure nothrow unittest
        {
            auto a = slice!(int, No.replaceArrayWithPointer)(2, 3);

            a[1, 2] += 3;
            assert(a[1, 2] == 3);
        }

        static if (doUnittest)
        pure nothrow unittest
        {
            auto a = new int[6].sliced!(No.replaceArrayWithPointer)(2, 3);

            a[[1, 2]] += 3;
            assert(a[[1, 2]] == 3);
        }

        /++
        Op Assignment `op=` of a value of `Slice` type to a $(B fully defined slice).

        Optimization:
            SIMD instructions may be used if both slices have the last stride equals to 1.
        +/
        void opIndexOpAssign(string op, size_t RN, RRange, Slices...)(Slice!(RN, RRange) value, Slices slices)
            if (isFullPureSlice!Slices
                && RN <= ReturnType!(opIndex!Slices).N)
        {
            opIndexAssignImpl!op(this[slices], value);
        }

        static if (doUnittest)
        ///
        pure nothrow unittest
        {
            auto a = slice!int(2, 3);
            auto b = [1, 2, 3, 4].sliced(2, 2);

            a[0..$, 0..$-1] += b;
            assert(a == [[1, 2, 0], [3, 4, 0]]);

            a[0..$, 0..$-1] += b[0];
            assert(a == [[2, 4, 0], [4, 6, 0]]);

            a[1, 0..$-1] += b[1];
            assert(a[1] == [7, 10, 0]);

            a[1, 0..$-1][] += b[0];
            assert(a[1] == [8, 12, 0]);
        }

        static if (doUnittest)
        /// Left slice is packed
        pure nothrow unittest
        {
            import std.experimental.ndslice.selection : blocks, iotaSlice;
            auto a = slice!size_t(4, 4);
            a.blocks(2, 2)[] += iotaSlice(2, 2);

            assert(a ==
                    [[0, 0, 1, 1],
                     [0, 0, 1, 1],
                     [2, 2, 3, 3],
                     [2, 2, 3, 3]]);
        }

        static if (doUnittest)
        /// Both slices are packed
        pure nothrow unittest
        {
            import std.experimental.ndslice.selection : blocks, iotaSlice, pack;
            auto a = slice!size_t(4, 4);
            a.blocks(2, 2)[] += iotaSlice(2, 2, 2).pack!1;

            assert(a ==
                    [[0, 1, 2, 3],
                     [0, 1, 2, 3],
                     [4, 5, 6, 7],
                     [4, 5, 6, 7]]);
        }

        static if (doUnittest)
        pure nothrow unittest
        {
            auto a = slice!(int, No.replaceArrayWithPointer)(2, 3);
            auto b = [1, 2, 3, 4].sliced(2, 2);

            a[0..$, 0..$-1] += b;
            assert(a == [[1, 2, 0], [3, 4, 0]]);

            a[0..$, 0..$-1] += b[0];
            assert(a == [[2, 4, 0], [4, 6, 0]]);

            a[1, 0..$-1] += b[1];
            assert(a[1] == [7, 10, 0]);

            a[1, 0..$-1][] += b[0];
            assert(a[1] == [8, 12, 0]);
        }

        /++
        Op Assignment `op=` of a regular multidimensional array to a $(B fully defined slice).

        Optimization:
            SIMD instructions may be used if the slice has the last stride equals to 1.
        +/
        void opIndexOpAssign(string op, T, Slices...)(T[] value, Slices slices)
            if (isFullPureSlice!Slices
                && !isDynamicArray!DeepElemType
                && DynamicArrayDimensionsCount!(T[]) <= ReturnType!(opIndex!Slices).N)
        {
            opIndexAssignImpl!op(this[slices], value);
        }

        static if (doUnittest)
        ///
        pure nothrow unittest
        {
            auto a = slice!int(2, 3);

            a[0..$, 0..$-1] += [[1, 2], [3, 4]];
            assert(a == [[1, 2, 0], [3, 4, 0]]);

            a[0..$, 0..$-1] += [1, 2];
            assert(a == [[2, 4, 0], [4, 6, 0]]);

            a[1, 0..$-1] += [3, 4];
            assert(a[1] == [7, 10, 0]);

            a[1, 0..$-1][] += [1, 2];
            assert(a[1] == [8, 12, 0]);
        }

        static if (doUnittest)
        /// Packed slices
        pure nothrow unittest
        {
            import std.experimental.ndslice.selection : blocks;
            auto a = slice!int(4, 4);
            a.blocks(2, 2)[] += [[0, 1], [2, 3]];

            assert(a ==
                    [[0, 0, 1, 1],
                     [0, 0, 1, 1],
                     [2, 2, 3, 3],
                     [2, 2, 3, 3]]);
        }

        static if (doUnittest)
        /// Packed slices have the same behavior.
        pure nothrow unittest
        {
            import std.experimental.ndslice.selection : pack;
            auto a = slice!int(2, 3).pack!1;

            a[] += 9;
            assert(a == [[9, 9, 9], [9, 9, 9]]);
        }

        static if (doUnittest)
        pure nothrow unittest
        {
            auto a = slice!(int, No.replaceArrayWithPointer)(2, 3);

            a[0..$, 0..$-1] += [[1, 2], [3, 4]];
            assert(a == [[1, 2, 0], [3, 4, 0]]);

            a[0..$, 0..$-1] += [1, 2];
            assert(a == [[2, 4, 0], [4, 6, 0]]);

            a[1, 0..$-1] += [3, 4];
            assert(a[1] == [7, 10, 0]);

            a[1, 0..$-1][] += [1, 2];
            assert(a[1] == [8, 12, 0]);
        }

        /++
        Op Assignment `op=` of a value (e.g. a number) to a $(B fully defined slice).

        Optimization:
            SIMD instructions may be used if the slice has the last stride equals to 1.
       +/
        void opIndexOpAssign(string op, T, Slices...)(T value, Slices slices)
            if (isFullPureSlice!Slices
                && (!isDynamicArray!T || isDynamicArray!DeepElemType)
                && !is(T : Slice!(RN, RRange), size_t RN, RRange))
        {
            opIndexAssignImpl!op(this[slices], value);
        }

        static if (doUnittest)
        ///
        pure nothrow unittest
        {
            auto a = slice!int(2, 3);

            a[] += 1;
            assert(a == [[1, 1, 1], [1, 1, 1]]);

            a[0..$, 0..$-1] += 2;
            assert(a == [[3, 3, 1], [3, 3, 1]]);

            a[1, 0..$-1] += 3;
            assert(a[1] == [6, 6, 1]);
        }

        static if (doUnittest)
        pure nothrow unittest
        {
            auto a = slice!(int, No.replaceArrayWithPointer)(2, 3);

            a[] += 1;
            assert(a == [[1, 1, 1], [1, 1, 1]]);

            a[0..$, 0..$-1] += 2;
            assert(a == [[3, 3, 1], [3, 3, 1]]);

            a[1, 0..$-1] += 3;
            assert(a[1] == [6, 6, 1]);
        }

        static if (PureN == N)
        /++
        Increment `++` and Decrement `--` operators for a $(B fully defined index).
        +/
        auto ref opIndexUnary(string op)(size_t[N] _indexes...)
            // @@@workaround@@@ for Issue 16473
            //if (op == `++` || op == `--`)
        {
            return mixin (`` ~ op ~ `_ptr[indexStride(_indexes)]`);
        }

        static if (doUnittest)
        ///
        pure nothrow unittest
        {
            auto a = slice!int(2, 3);

            ++a[1, 2];
            assert(a[1, 2] == 1);
        }

        // Issue 16473
        static if (doUnittest)
        unittest
        {
            auto sl = slice!double(2, 5);
            auto d = -sl[0, 1];
        }

        static if (doUnittest)
        pure nothrow unittest
        {
            auto a = slice!(int, No.replaceArrayWithPointer)(2, 3);

            ++a[1, 2];
            assert(a[1, 2] == 1);
        }

        static if (doUnittest)
        pure nothrow unittest
        {
            auto a = new int[6].sliced(2, 3);

            ++a[[1, 2]];
            assert(a[[1, 2]] == 1);
        }

        static if (doUnittest)
        pure nothrow unittest
        {
            auto a = new int[6].sliced!(No.replaceArrayWithPointer)(2, 3);

            ++a[[1, 2]];
            assert(a[[1, 2]] == 1);
        }

        static if (PureN == N)
        /++
        Increment `++` and Decrement `--` operators for a $(B fully defined slice).
        +/
        void opIndexUnary(string op, Slices...)(Slices slices)
            if (isFullPureSlice!Slices && (op == `++` || op == `--`))
        {
            auto sl = this[slices];
            static if (sl.N == 1)
            {
                for (; sl.length; sl.popFront)
                {
                    mixin (op ~ `sl.front;`);
                }
            }
            else
            {
                foreach (v; sl)
                {
                    mixin (op ~ `v[];`);
                }
            }
        }

        static if (doUnittest)
        ///
        pure nothrow unittest
        {
            auto a = slice!int(2, 3);

            ++a[];
            assert(a == [[1, 1, 1], [1, 1, 1]]);

            --a[1, 0..$-1];
            assert(a[1] == [0, 0, 1]);
        }

        static if (doUnittest)
        pure nothrow unittest
        {
            auto a = slice!(int, No.replaceArrayWithPointer)(2, 3);

            ++a[];
            assert(a == [[1, 1, 1], [1, 1, 1]]);

            --a[1, 0..$-1];
            assert(a[1] == [0, 0, 1]);
        }
    }
}

/++
Slicing, indexing, and arithmetic operations.
+/
pure nothrow unittest
{
    import std.experimental.ndslice.iteration : transposed;
    import std.experimental.ndslice.selection : iotaSlice;
    auto tensor = iotaSlice(3, 4, 5).slice;

    assert(tensor[1, 2] == tensor[1][2]);
    assert(tensor[1, 2, 3] == tensor[1][2][3]);

    assert( tensor[0..$, 0..$, 4] == tensor.transposed!2[4]);
    assert(&tensor[0..$, 0..$, 4][1, 2] is &tensor[1, 2, 4]);

    tensor[1, 2, 3]++; //`opIndex` returns value by reference.
    --tensor[1, 2, 3]; //`opUnary`

    ++tensor[];
    tensor[] -= 1;

    // `opIndexAssing` accepts only fully defined indexes and slices.
    // Use an additional empty slice `[]`.
    static assert(!__traits(compiles, tensor[0 .. 2] *= 2));

    tensor[0 .. 2][] *= 2;          //OK, empty slice
    tensor[0 .. 2, 3, 0..$] /= 2; //OK, 3 index or slice positions are defined.

    //fully defined index may be replaced by a static array
    size_t[3] index = [1, 2, 3];
    assert(tensor[index] == tensor[1, 2, 3]);
}

/++
Operations with rvalue slices.
+/
pure nothrow unittest
{
    import std.experimental.ndslice.iteration : transposed, everted;

    auto tensor = slice!int(3, 4, 5);
    auto matrix = slice!int(3, 4);
    auto vector = slice!int(3);

    foreach (i; 0..3)
        vector[i] = i;

    // fills matrix columns
    matrix.transposed[] = vector;

    // fills tensor with vector
    // transposed tensor shape is (4, 5, 3)
    //            vector shape is (      3)
    tensor.transposed!(1, 2)[] = vector;


    // transposed tensor shape is (5, 3, 4)
    //            matrix shape is (   3, 4)
    tensor.transposed!2[] += matrix;

    // transposed tensor shape is (5, 4, 3)
    // transposed matrix shape is (   4, 3)
    tensor.everted[] ^= matrix.transposed; // XOR
}

/++
Creating a slice from text.
See also $(MREF std, format).
+/
unittest
{
    import std.algorithm,  std.conv, std.exception, std.format,
        std.functional, std.string, std.range;

    Slice!(2, int*) toMatrix(string str)
    {
        string[][] data = str.lineSplitter.filter!(not!empty).map!split.array;

        size_t rows    = data   .length.enforce("empty input");
        size_t columns = data[0].length.enforce("empty first row");

        data.each!(a => enforce(a.length == columns, "rows have different lengths"));

        auto slice = slice!int(rows, columns);
        foreach (i, line; data)
            foreach (j, num; line)
                slice[i, j] = num.to!int;
        return slice;
    }

    auto input = "\r1 2  3\r\n 4 5 6\n";

    auto matrix = toMatrix(input);
    assert(matrix == [[1, 2, 3], [4, 5, 6]]);

    // back to text
    auto text2 = format("%(%(%s %)\n%)\n", matrix);
    assert(text2 == "1 2 3\n4 5 6\n");
}

// Slicing
@safe @nogc pure nothrow unittest
{
    import std.experimental.ndslice.selection : iotaSlice;
    auto a = iotaSlice(10, 20, 30, 40);
    auto b = a[0..$, 10, 4 .. 27, 4];
    auto c = b[2 .. 9, 5 .. 10];
    auto d = b[3..$, $-2];
    assert(b[4, 17] == a[4, 10, 21, 4]);
    assert(c[1, 2] == a[3, 10, 11, 4]);
    assert(d[3] == a[6, 10, 25, 4]);
}

// Operator overloading. # 1
pure nothrow unittest
{
    import std.experimental.ndslice.selection : iotaSlice;

    auto fun(ref size_t x) { x *= 3; }

    auto tensor = iotaSlice(8, 9, 10).slice;

    ++tensor[];
    fun(tensor[0, 0, 0]);

    assert(tensor[0, 0, 0] == 3);

    tensor[0, 0, 0] *= 4;
    tensor[0, 0, 0]--;
    assert(tensor[0, 0, 0] == 11);
}

// Operator overloading. # 2
pure nothrow unittest
{
    import std.algorithm.iteration : map;
    import std.array : array;
    import std.bigint;
    import std.range : iota;

    auto matrix = 72
        .iota
        .map!(i => BigInt(i))
        .array
        .sliced(8, 9);

    matrix[3 .. 6, 2] += 100;
    foreach (i; 0 .. 8)
        foreach (j; 0 .. 9)
            if (i >= 3 && i < 6 && j == 2)
                assert(matrix[i, j] >= 100);
            else
                assert(matrix[i, j] < 100);
}

// Operator overloading. # 3
pure nothrow unittest
{
    import std.experimental.ndslice.selection : iotaSlice;

    auto matrix = iotaSlice(8, 9).slice;
    matrix[] = matrix;
    matrix[] += matrix;
    assert(matrix[2, 3] == (2 * 9 + 3) * 2);

    auto vec = iotaSlice([9], 100);
    matrix[] = vec;
    foreach (v; matrix)
        assert(v == vec);

    matrix[] += vec;
    foreach (vector; matrix)
        foreach (elem; vector)
            assert(elem >= 200);
}

// Type deduction
unittest
{
    // Arrays
    foreach (T; AliasSeq!(int, const int, immutable int))
        static assert(is(typeof((T[]).init.sliced(3, 4)) == Slice!(2, T*)));

    // Container Array
    import std.container.array;
    Array!int ar;
    ar.length = 12;
    Slice!(2, typeof(ar[])) arSl = ar[].sliced(3, 4);

    // Implicit conversion of a range to its unqualified type.
    import std.range : iota;
    auto      i0 = 60.iota;
    const     i1 = 60.iota;
    immutable i2 = 60.iota;
    alias S = Slice!(3, typeof(iota(0)));
    foreach (i; AliasSeq!(i0, i1, i2))
        static assert(is(typeof(i.sliced(3, 4, 5)) == S));
}

// Test for map #1
unittest
{
    import std.algorithm.iteration : map;
    import std.range.primitives;
    auto slice = [1, 2, 3, 4].sliced(2, 2);

    auto r = slice.map!(a => a.map!(a => a * 6));
    assert(r.front.front == 6);
    assert(r.front.back == 12);
    assert(r.back.front == 18);
    assert(r.back.back == 24);
    assert(r[0][0] ==  6);
    assert(r[0][1] == 12);
    assert(r[1][0] == 18);
    assert(r[1][1] == 24);
    static assert(hasSlicing!(typeof(r)));
    static assert(isForwardRange!(typeof(r)));
    static assert(isRandomAccessRange!(typeof(r)));

}

// Test for map #2
unittest
{
    import std.algorithm.iteration : map;
    import std.range.primitives;
    auto data = [1, 2, 3, 4].map!(a => a * 2);
    static assert(hasSlicing!(typeof(data)));
    static assert(isForwardRange!(typeof(data)));
    static assert(isRandomAccessRange!(typeof(data)));
    auto slice = data.sliced(2, 2);
    static assert(hasSlicing!(typeof(slice)));
    static assert(isForwardRange!(typeof(slice)));
    static assert(isRandomAccessRange!(typeof(slice)));
    auto r = slice.map!(a => a.map!(a => a * 3));
    static assert(hasSlicing!(typeof(r)));
    static assert(isForwardRange!(typeof(r)));
    static assert(isRandomAccessRange!(typeof(r)));
    assert(r.front.front == 6);
    assert(r.front.back == 12);
    assert(r.back.front == 18);
    assert(r.back.back == 24);
    assert(r[0][0] ==  6);
    assert(r[0][1] == 12);
    assert(r[1][0] == 18);
    assert(r[1][1] == 24);
}

private bool opEqualsImpl
    (size_t N, RangeL, RangeR)(
    Slice!(N, RangeL) ls,
    Slice!(N, RangeR) rs)
{
    do
    {
        static if (Slice!(N, RangeL).PureN == 1)
        {
            if (ls.front != rs.front)
                return false;
        }
        else
        {
            if (!opEqualsImpl(ls.front, rs.front))
                return false;
        }
        rs.popFront;
        ls.popFront;
    }
    while (ls.length);
    return true;
}

private void opIndexAssignImpl(
    string op,
    size_t NL, RangeL,
    size_t NR, RangeR)(
    Slice!(NL, RangeL) ls,
    Slice!(NR, RangeR) rs)
    if (NL >= NR)
{
    assert(_checkAssignLengths(ls, rs),
        __FUNCTION__ ~ ": arguments must have the corresponding shape.");

    foreach (i; Iota!(0, ls.PureN))
        if (ls._lengths[i] == 0)
            return;

    static if (isMemory!RangeL && isMemory!RangeR && ls.NSeq.length == rs.NSeq.length)
    {
        if (ls._strides[$ - 1] == 1 && rs._strides[$ - 1] == 1)
        {
            _indexAssign!(true, op)(ls, rs);
            return;
        }
    }
    else
    static if (isMemory!RangeL && ls.NSeq.length > rs.NSeq.length)
    {
        if (ls._strides[$ - 1] == 1)
        {
            _indexAssign!(true, op)(ls, rs);
            return;
        }
    }

    _indexAssign!(false, op)(ls, rs);
}

pure nothrow unittest
{
    import std.experimental.ndslice.iteration : dropExactly;
    import std.experimental.ndslice.selection : byElement;
    auto sl1 = slice!double([2, 3], 2);
    auto sl2 = slice!double([2, 3], 3);
    sl1.dropExactly!0(2)[] = sl2.dropExactly!0(2);
    foreach (e; sl1.byElement)
        assert(e == 2);
    sl1.dropExactly!0(2)[] = sl2.dropExactly!0(2).ndarray;
    foreach (e; sl1.byElement)
        assert(e == 2);
}

private void opIndexAssignImpl
    (string op, size_t NL, RangeL, T)(
        Slice!(NL, RangeL) ls, T rs)
    if (!is(T : Slice!(NR, RangeR), size_t NR, RangeR))
{
    foreach (i; Iota!(0, ls.PureN))
        if (ls._lengths[i] == 0)
            return;

    static if (isMemory!RangeL)
    {
        if (ls._strides[$ - 1] == 1)
        {
            _indexAssign!(true, op)(ls, rs);
            return;
        }
    }

    _indexAssign!(false, op)(ls, rs);
}

pure nothrow unittest
{
    import std.internal.test.dummyrange;
    foreach (RB; AliasSeq!(ReturnBy.Reference, ReturnBy.Value))
    {
        DummyRange!(RB, Length.Yes, RangeType.Random) range;
        range.reinit;
        assert(range.length >= 10);
        auto slice = range.sliced(10);
        assert(slice[0] == range[0]);
        auto save0 = range[0];
        slice[0] += 10;
        ++slice[0];
        assert(slice[0] == save0 + 11);
        slice[5 .. $][2] = 333;
        assert(range[7] == 333);
    }
}

// toHash test
unittest
{
    import std.conv : to;
    import std.complex;
    import std.experimental.ndslice.iteration : allReversed;

    static assert(__traits(isPOD, uint[2]));
    static assert(__traits(isPOD, double));
    static assert(__traits(isPOD, Complex!double));

    foreach (T; AliasSeq!(
        byte, short, int, long,
        float, double, real,
        Complex!float, Complex!double, Complex!real))
    {
        auto a = slice!(T, No.replaceArrayWithPointer)(3, 7);
        auto b = slice!T(3, 7).allReversed;
        size_t i;
        foreach (row; a)
            foreach (ref e; row)
                e = to!T(i++);
        b[] = a;
        assert(typeid(a.This).getHash(&a) == typeid(b.This).getHash(&b), T.stringof);
    }
}

unittest
{
    int[] arr = [1, 2, 3];
    auto ptr = arr.ptrShell;
    assert(ptr[0] == 1);
    auto ptrCopy = ptr.save;
    ptrCopy._range.popFront;
    assert(ptr[0] == 1);
    assert(ptrCopy[0] == 2);
}

pure nothrow unittest
{
    auto a = new int[20], b = new int[20];
    alias T = PtrTuple!("a", "b");
    alias S = T!(int*, int*);
    static assert (hasUDA!(S, LikePtr));
    auto t = S(a.ptr, b.ptr);
    t[4].a++;
    auto r = t[4];
    r.b = r.a * 2;
    assert(b[4] == 2);
    t[0].a++;
    r = t[0];
    r.b = r.a * 2;
    assert(b[0] == 2);
}

private template PrepareRangeType(Range)
{
    static if (isPointer!Range)
        alias PrepareRangeType = Range;
    else
        alias PrepareRangeType = PtrShell!Range;
}

private enum bool isType(alias T) = false;

private enum bool isType(T) = true;

private enum isStringValue(alias T) = is(typeof(T) : string);

private void _indexAssignKernel(string op, TL, TR)(size_t c, TL l, TR r)
{
    do
    {
        mixin("l[0] " ~ op ~ "= r[0];");
        ++r;
        ++l;
    }
    while (--c);
}

private void _indexAssignValKernel(string op, TL, TR)(size_t c, TL l, TR r)
{
    do
    {
        mixin("l[0] " ~ op ~ "= r;");
        ++l;
    }
    while (--c);
}

private void _indexAssign(bool lastStrideEquals1, string op, size_t NL, RangeL, size_t NR, RangeR)
                         (Slice!(NL, RangeL) ls, Slice!(NR, RangeR) rs)
    if (NL >= NR)
{
    static if (NL == 1)
    {
        static if (lastStrideEquals1 && ls.PureN == 1)
        {
            _indexAssignKernel!op(ls._lengths[0], ls._ptr, rs._ptr);
        }
        else
        {
            do
            {
                static if (ls.PureN == 1)
                    mixin("ls.front " ~ op ~ "= rs.front;");
                else
                    _indexAssign!(lastStrideEquals1, op)(ls.front, rs.front);
                rs.popFront;
                ls.popFront;
            }
            while (ls.length);
        }
    }
    else
    static if (NL == NR)
    {
        do
        {
            _indexAssign!(lastStrideEquals1, op)(ls.front, rs.front);
            rs.popFront;
            ls.popFront;
        }
        while (ls.length);
    }
    else
    {
        do
        {
            _indexAssign!(lastStrideEquals1, op)(ls.front, rs);
            ls.popFront;
        }
        while (ls.length);
    }
}

private void _indexAssign(bool lastStrideEquals1, string op, size_t NL, RangeL, T)(Slice!(NL, RangeL) ls, T[] rs)
    if (DynamicArrayDimensionsCount!(T[]) <= NL)
{
    assert(ls.length == rs.length, __FUNCTION__ ~ ": argument must have the same length.");
    static if (NL == 1)
    {
        static if (lastStrideEquals1 && ls.PureN == 1)
        {
            _indexAssignKernel!op(ls._lengths[0], ls._ptr, rs.ptr);
        }
        else
        {
            do
            {
                static if (ls.PureN == 1)
                    mixin("ls.front " ~ op ~ "= rs[0];");
                else
                    _indexAssign!(lastStrideEquals1, op)(ls.front, rs[0]);
                rs.popFront;
                ls.popFront;
            }
            while (ls.length);
        }
    }
    else
    static if (NL == DynamicArrayDimensionsCount!(T[]))
    {
        do
        {
            _indexAssign!(lastStrideEquals1, op)(ls.front, rs[0]);
            rs.popFront;
            ls.popFront;
        }
        while (ls.length);
    }
    else
    {
        do
        {
            _indexAssign!(lastStrideEquals1, op)(ls.front, rs);
            ls.popFront;
        }
        while (ls.length);
    }
}

private void _indexAssign(bool lastStrideEquals1, string op, size_t NL, RangeL, T)(Slice!(NL, RangeL) ls, T rs)
    if ((!isDynamicArray!T || isDynamicArray!(Slice!(NL, RangeL).DeepElemType))
                && !is(T : Slice!(NR, RangeR), size_t NR, RangeR))
{
    static if (NL == 1)
    {
        static if (lastStrideEquals1 && ls.PureN == 1)
        {
            _indexAssignValKernel!op(ls._lengths[0], ls._ptr, rs);
        }
        else
        {
            do
            {
                static if (ls.PureN == 1)
                    mixin("ls.front " ~ op ~ "= rs;");
                else
                    _indexAssign!(lastStrideEquals1, op)(ls.front, rs);
                ls.popFront;
            }
            while (ls.length);
        }
    }
    else
    {
        do
        {
            _indexAssign!(lastStrideEquals1, op)(ls.front, rs);
            ls.popFront;
        }
        while (ls.length);
    }
}

private bool _checkAssignLengths(size_t NL, RangeL, size_t NR, RangeR)(Slice!(NL, RangeL) ls, Slice!(NR, RangeR) rs)
    if (NL >= NR)
{
    foreach (i; Iota!(0, NR))
        if (ls._lengths[i + NL - NR] != rs._lengths[i])
            return false;

    static if (ls.PureN > NL && rs.PureN > NR)
    {
        ls.DeepElemType a;
        rs.DeepElemType b;
        a._lengths = ls._lengths[NL .. $];
        b._lengths = rs._lengths[NR .. $];
        return _checkAssignLengths(a, b);
    }
    else
    {
        return true;
    }
}

@safe pure nothrow @nogc unittest
{
    import std.experimental.ndslice.selection : iotaSlice;

    assert(_checkAssignLengths(iotaSlice(2, 2), iotaSlice(2, 2)));
    assert(!_checkAssignLengths(iotaSlice(2, 2), iotaSlice(2, 3)));
    assert(!_checkAssignLengths(iotaSlice(2, 2), iotaSlice(3, 2)));
    assert(!_checkAssignLengths(iotaSlice(2, 2), iotaSlice(3, 3)));
}
