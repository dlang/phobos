/**
This is a submodule of $(LINK2 std_experimental_ndslice.html, std.experimental.ndslice).

License:   $(WEB www.boost.org/LICENSE_1_0.txt, Boost License 1.0).

Authors:   Ilya Yaroshenko

Source:    $(PHOBOSSRC std/_experimental/_ndslice/_slice.d)

Macros:
SUBMODULE = $(LINK2 std_experimental_ndslice_$1.html, std.experimental.ndslice.$1)
SUBREF = $(LINK2 std_experimental_ndslice_$1.html#.$2, $(TT $2))$(NBSP)
T2=$(TR $(TDNW $(LREF $1)) $(TD $+))
T4=$(TR $(TDNW $(LREF $1)) $(TD $2) $(TD $3) $(TD $4))
STD = $(TD $(SMALL $0))
*/
module std.experimental.ndslice.slice;

import std.traits;
import std.meta;
import std.typecons; //: Flag;

import std.experimental.ndslice.internal;

/++
Creates an n-dimensional slice-shell over a `range`.
Params:
    range = a random access range or an array; only index operator
        `auto opIndex(size_t index)` is required for ranges. The length of the
        range must be greater than or equal to the sum of shift and the product of
        lengths.
    lengths = list of lengths for each dimension
    shift = index of the first element of a `range`.
        The first `shift` elements of range are ignored.
    Names = names of elements in a slice tuple.
        Slice tuple is a slice, which holds single set of lengths and strides
        for a number of ranges.
Returns:
    n-dimensional slice
+/
auto sliced(ReplaceArrayWithPointer mod = ReplaceArrayWithPointer.yes, Range, Lengths...)(Range range, Lengths lengths)
    if (!isStaticArray!Range && !isNarrowString!Range
        && allSatisfy!(isIndex, Lengths) && Lengths.length)
{
    return .sliced!(mod, Lengths.length, Range)(range, [lengths]);
}

///ditto
auto sliced(ReplaceArrayWithPointer mod = ReplaceArrayWithPointer.yes, size_t N, Range)(Range range, auto ref in size_t[N] lengths, size_t shift = 0)
    if (!isStaticArray!Range && !isNarrowString!Range && N)
in
{
    import std.range.primitives: hasLength;
    foreach (len; lengths)
        assert(len > 0,
            "All lengths must be positive."
            ~ tailErrorMessage!());
    static if (hasLength!Range)
        assert(lengthsProduct!N(lengths) + shift <= range.length,
            "Range length must be greater than or equal to the sum of shift and the product of lengths."
            ~ tailErrorMessage!());
}
body
{
    static if (isDynamicArray!Range && mod)
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
    foreach_reverse(i; Iota!(0, N - 1))
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
            ReplaceArrayWithPointer mod = ReplaceArrayWithPointer.yes,
            " ~ _Range_Types!Names ~ "
            Lengths...)
            (" ~ _Range_DeclarationList!Names ~
            "Lengths lengths)
    if (allSatisfy!(isIndex, Lengths))
    {
        return .sliced!Names(" ~ _Range_Values!Names ~ "[lengths]);
    }

    auto sliced(
            ReplaceArrayWithPointer mod = ReplaceArrayWithPointer.yes,
            size_t N, " ~ _Range_Types!Names ~ ")
            (" ~ _Range_DeclarationList!Names ~"
            auto ref in size_t[N] lengths,
            size_t shift = 0)
    {
        alias RS = AliasSeq!(" ~ _Range_Types!Names ~ ");"
        ~ q{
            import std.range.primitives: hasLength;
            import std.meta: staticMap;
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
                    assert(minLength <= r.length,
                        `length of range '` ~ name ~`' must be greater than or equal `
                        ~ `to the sum of shift and the product of lengths.`
                        ~ tailErrorMessage!());
                static if (isDynamicArray!T && mod)
                    range.ptrs[i] = r.ptr;
                else
                    range.ptrs[i] = T(0, r);
            }
            return .sliced!(mod, N, SPT)(range, lengths, shift);
        }
    ~ "}");
}

/// Creates a slice from an array.
pure nothrow unittest
{
    auto slice = new int [1000].sliced(5, 6, 7);
    assert(slice.length == 5);
    assert(slice.elementsCount == 5 * 6 * 7);
    static assert(is(typeof(slice) == Slice!(3, int*)));
}

/// Creates a slice using shift parameter.
@safe @nogc pure nothrow unittest
{
    import std.range: iota;
    auto slice = 1000.iota.sliced([5, 6, 7], 9);
    assert(slice.length == 5);
    assert(slice.elementsCount == 5 * 6 * 7);
    assert(slice[0, 0, 0] == 9);
}

/// $(LINK2 https://en.wikipedia.org/wiki/Vandermonde_matrix, Vandermonde matrix)
pure nothrow unittest
{
    pure nothrow
    Slice!(2, double*) vandermondeMatrix(Slice!(1, double*) x)
    {
        auto ret = new double[x.length ^^ 2]
            .sliced(x.length, x.length);
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
    import std.algorithm.comparison: equal;
    import std.experimental.ndslice.selection: byElement;
    import std.range: iota;

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

/++
Creates an array and an n-dimensional slice over it.
+/
pure nothrow unittest
{
    auto createSlice(T, Lengths...)(Lengths lengths)
    {
        return createSlice2!(T, Lengths.length)(cast(size_t[Lengths.length])[lengths]);
    }

    ///ditto
    auto createSlice2(T, size_t N)(auto ref size_t[N] lengths)
    {
        size_t length = lengths[0];
        foreach (len; lengths[1 .. N])
                length *= len;
        return new T[length].sliced(lengths);
    }

    auto slice = createSlice!int(5, 6, 7);
    assert(slice.length == 5);
    assert(slice.elementsCount == 5 * 6 * 7);
    static assert(is(typeof(slice) == Slice!(3, int*)));

    auto duplicate = createSlice2!int(slice.shape);
    duplicate[] = slice;
}

/++
Creates a common n-dimensional array.
+/
pure nothrow unittest
{
    auto ndarray(size_t N, Range)(auto ref Slice!(N, Range) slice)
    {
        import std.array: array;
        static if (N == 1)
        {
            return slice.array;
        }
        else
        {
            import std.algorithm.iteration: map;
            return slice.map!(a => ndarray(a)).array;
        }
    }

    import std.range: iota;
    auto ar = ndarray(100.iota.sliced(3, 4));
    static assert(is(typeof(ar) == int[][]));
    assert(ar == [[0, 1, 2, 3], [4, 5, 6, 7], [8, 9, 10, 11]]);
}

/++
Allocates an array through a specified allocator and creates an n-dimensional slice over it.
See also $(LINK2 std_experimental_allocator.html, std.experimental.allocator).
+/
unittest
{
    import std.experimental.allocator;


    // `theAllocator.makeSlice(3, 4)` allocates an array with length equal to `12`
    // and returns this array and a `2`-dimensional slice-shell over it.
    auto makeSlice(T, Allocator, Lengths...)(auto ref Allocator alloc, Lengths lengths)
    {
        enum N = Lengths.length;
        struct Result { T[] array; Slice!(N, T*) slice; }
        size_t length = lengths[0];
        foreach (len; lengths[1 .. N])
                length *= len;
        T[] a = alloc.makeArray!T(length);
        return Result(a, a.sliced(lengths));
    }

    auto tup = makeSlice!int(theAllocator, 2, 3, 4);

    static assert(is(typeof(tup.array) == int[]));
    static assert(is(typeof(tup.slice) == Slice!(3, int*)));

    assert(tup.array.length           == 24);
    assert(tup.slice.elementsCount    == 24);
    assert(tup.array.ptr == &tup.slice[0, 0, 0]);

    theAllocator.dispose(tup.array);
}

/// Input range primitives for slices over user defined types
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
    auto slice = MyIota().sliced(20, 10);

    import std.range.primitives;
    static assert(hasLength!S);
    static assert(isInputRange!S);
    static assert(isForwardRange!S == false);
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
        // `save` property to allow a slice to be a forward range
        auto save() @property
        {
            return this;
        }
    }

    alias S = Slice!(3, MyIota);
    auto slice = MyIota().sliced(20, 10);

    import std.range.primitives;
    static assert(hasLength!S);
    static assert(hasSlicing!S);
    static assert(isForwardRange!S);
    static assert(isBidirectionalRange!S);
    static assert(isRandomAccessRange!S);
}

// sliced slice
pure nothrow unittest
{
    import std.range: iota;
    auto data = new int[24];
    foreach (int i,ref e; data)
        e = i;
    auto a =    data.sliced(10).sliced(2, 3);
    auto b = 24.iota.sliced(10).sliced(2, 3);
    assert(a == b);
    a[] += b;
    foreach (int i, e; data[0..6])
        assert(e == 2*i);
    foreach (int i, e; data[6..$])
        assert(e == i+6);
    auto c  =    data.sliced(12, 2).sliced(2, 3);
    auto d  = 24.iota.sliced(12, 2).sliced(2, 3);
    auto cc =    data.sliced(2, 3, 2);
    auto dc = 24.iota.sliced(2, 3, 2);
    assert(c._lengths == cc._lengths);
    assert(c._strides == cc._strides);
    assert(d._lengths == dc._lengths);
    assert(d._strides == dc._strides);
    assert(cc == c);
    assert(dc == d);
    auto e  =    data.sliced(8, 3).sliced(5);
    auto f  = 24.iota.sliced(8, 3).sliced(5);
    assert(e ==    data.sliced(5, 3));
    assert(f == 24.iota.sliced(5, 3));
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
        enum string _Range_DeclarationList = "Range_" ~ Names[0] ~ " range_" ~ Names[0] ~ ", " ~ _Range_DeclarationList!(Names[1..$]);
    else
        enum string _Range_DeclarationList = "";
}

private template _Slice_DeclarationList(Names...)
{
    static if (Names.length)
        enum string _Slice_DeclarationList = "Slice!(N, Range_" ~ Names[0] ~ ") slice_" ~ Names[0] ~ ", " ~ _Slice_DeclarationList!(Names[1..$]);
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
            ReplaceArrayWithPointer mod = ReplaceArrayWithPointer.yes,
            size_t N, " ~ _Range_Types!Names ~ ")
            (" ~ _Slice_DeclarationList!Names ~ ")
    {
        alias RS = AliasSeq!("  ~_Range_Types!Names ~ ");"
        ~ q{
            import std.meta: staticMap;
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
    import std.algorithm.comparison: equal;
    import std.experimental.ndslice.selection: byElement;
    import std.range: iota;

    auto alpha = 12.iota   .sliced(4, 3);
    auto beta = new int[12].sliced(4, 3);

    auto m = assumeSameStructure!("a", "b")(alpha, beta);
    foreach (r; m)
        foreach (e; r)
            e.b = e.a;
    assert(alpha == beta);

    beta[] = 0;
    foreach (e; m.byElement)
        e.b = e.a;
    assert(alpha == beta);
}

/++
If `yes`, the array will be replaced with its pointer to improve performance.
Use `no` for compile time function evaluation.
+/
alias ReplaceArrayWithPointer = Flag!"replaceArrayWithPointer";

///
@safe pure nothrow unittest
{
    import std.algorithm.iteration: map, sum, reduce;
    import std.algorithm.comparison: max;
    import std.experimental.ndslice.iteration: transposed;
    /// Returns maximal column average.
    auto maxAvg(S)(S matrix) {
        return matrix.transposed.map!sum.reduce!max
             / matrix.length;
    }
    enum matrix = [1, 2,
                   3, 4].sliced!(ReplaceArrayWithPointer.no)(2, 2);
    ///Сompile time function evaluation
    static assert(maxAvg(matrix) == 3);
}


/++
Returns the element type of the `Slice` type.
+/
alias DeepElementType(S : Slice!(N, Range), size_t N, Range) = S.DeepElemType;

///
unittest
{
    import std.range: iota;
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
$(TR $(TD An $(BLUE interval) is a part of a sequence of type `i .. j`.)
    $(STD `2..$-3`, `0..4`))
$(TR $(TD An $(BLUE index) is a part of a sequence of type `i`.)
    $(STD `3`, `$-1`))
$(TR $(TD A $(BLUE partially defined slice) is a sequence composed of
    $(BLUE intervals) and $(BLUE indexes) with an overall length strictly less than `N`.)
    $(STD `[3]`, `[0..$]`, `[3, 3]`, `[0..$,0..3]`, `[0..$,2]`))
$(TR $(TD A $(BLUE fully defined index) is a sequence
    composed only of $(BLUE indexes) with an overall length equal to `N`.)
    $(STD `[2,3,1]`))
$(TR $(TD A $(BLUE fully defined slice) is an empty sequence
    or a sequence composed of $(BLUE indexes) and at least one
    $(BLUE interval) with an overall length equal to `N`.)
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
Slice!(3, double*) r = r.reversed!1;
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
import std.range: iota;
auto a = iota(24);
alias A = typeof(a);
Slice!(3, A) s = a.sliced(2, 3, 4);
Slice!(3, A) t = s.transposed!(1, 2, 0);
Slice!(3, A) r = r.reversed!1;
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
        __traits(compiles, { auto a = &(_ptr[0]); } );

    enum PureIndexLength(Slices...) = Filter!(isIndex, Slices).length;
    template isFullPureIndex(Indexes...)
    {
        static if (allSatisfy!(isIndex, Indexes))
            enum isFullPureIndex  = Indexes.length == N;
        else
        static if (Indexes.length == 1 && isStaticArray!(Indexes[0]))
            enum isFullPureIndex = Indexes[0].length == N && isIndex!(ForeachType!(Indexes[0]));
        else
            enum isFullPureIndex = false;
    }
    enum isPureSlice(Slices...) =
           Slices.length <= N
        && PureIndexLength!Slices < N
        && Filter!(isStaticArray, Slices).length == 0;

    enum isFullPureSlice(Slices...) =
           Slices.length == 0
        || Slices.length == N
        && PureIndexLength!Slices < N
        && Filter!(isStaticArray, Slices).length == 0;

    size_t[PureN] _lengths;
    sizediff_t[PureN] _strides;
    static if (hasPtrBehavior!PureRange)
        PureRange _ptr;
    else
        PtrShell!PureRange _ptr;

    sizediff_t backIndex(size_t dimension = 0)() @property const
        if (dimension < N)
    {
        return _strides[dimension] * (_lengths[dimension] - 1);
    }

    size_t indexStride(Indexes...)(Indexes _indexes)
        if (isFullPureIndex!Indexes)
    {
        static if (isStaticArray!(Indexes[0]))
        {
            size_t stride;
            foreach (i; Iota!(0, N)) //static
            {
                assert(_indexes[0][i] < _lengths[i], "indexStride: index must be less than lengths");
                stride += _strides[i] * _indexes[0][i];
            }
            return stride;
        }
        else
        {
            size_t stride;
            foreach (i, index; _indexes) //static
            {
                assert(index < _lengths[i], "indexStride: index must be less than lengths");
                stride += _strides[i] * index;
            }
            return stride;
        }
    }

    this(ref in size_t[PureN] lengths, ref in sizediff_t[PureN] strides, PureRange range)
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

    static if (!hasPtrBehavior!PureRange)
    this(ref in size_t[PureN] lengths, ref in sizediff_t[PureN] strides, PtrShell!PureRange shell)
    {
        foreach (i; Iota!(0, PureN))
            _lengths[i] = lengths[i];
        foreach (i; Iota!(0, PureN))
            _strides[i] = strides[i];
        _ptr = shell;
    }

    public:

    /++
    Returns: static array of lengths
    See_also: $(LREF .Slice.structure)
    +/
    size_t[N] shape() @property const
    {
        pragma(inline, true);
        return _lengths[0 .. N];
    }

    static if (doUnittest)
    /// Regular slice
    @safe @nogc pure nothrow unittest
    {
        import std.range: iota;
        assert(100.iota
            .sliced(3, 4, 5)
            .shape == cast(size_t[3])[3, 4, 5]);
    }

    static if (doUnittest)
    /// Packed slice
    @safe @nogc pure nothrow unittest
    {
        import std.experimental.ndslice.selection: pack;
        import std.range: iota;
        assert(10000.iota
            .sliced(3, 4, 5, 6, 7)
            .pack!2
            .shape == cast(size_t[3])[3, 4, 5]);
    }

    /++
    Returns: static array of lengths and static array of strides
    See_also: $(LREF .Slice.shape)
   +/
    Structure!N structure() @property const
    {
        pragma(inline, true);
        return typeof(return)(_lengths[0 .. N], _strides[0 .. N]);
    }

    static if (doUnittest)
    /// Regular slice
    @safe @nogc pure nothrow unittest
    {
        import std.range: iota;
        assert(100.iota
            .sliced(3, 4, 5)
            .structure == Structure!3([3, 4, 5], [20, 5, 1]));
    }

    static if (doUnittest)
    /// Modified regular slice
    @safe @nogc pure nothrow unittest
    {
        import std.experimental.ndslice.selection: pack;
        import std.experimental.ndslice.iteration: reversed, strided, transposed;
        import std.range: iota;
        assert(1000.iota
            .sliced(3, 4, 50)
            .reversed!2      //makes stride negative
            .strided!2(6)    //multiplies stride by 6 and changes corresponding length
            .transposed!2    //brings dimension `2` to the first position
            .structure == Structure!3([9, 3, 4], [-6, 200, 50]));
    }

    static if (doUnittest)
    /// Packed slice
    @safe @nogc pure nothrow unittest
    {
        import std.experimental.ndslice.selection: pack;
        import std.range: iota;
        assert(10000.iota
            .sliced(3, 4, 5, 6, 7)
            .pack!2
            .structure == Structure!3([3, 4, 5], [20 * 42, 5 * 42, 1 * 42]));
    }

    /++
    Range primitive.
    Defined only if `Range` is a forward range or a pointer type.
    +/
    static if (canSave!PureRange)
    auto save() @property
    {
        static if (isPointer!PureRange)
            return typeof(this)(_lengths, _strides, _ptr);
        else
            return typeof(this)(_lengths, _strides, _ptr.save);
    }

    static if (doUnittest)
    /// Forward range
    @safe @nogc pure nothrow unittest
    {
        import std.range: iota;
        auto slice = 100.iota.sliced(2, 3).save;
    }

    static if (doUnittest)
    /// Pointer type.
    pure nothrow unittest
    {
         //slice type is `Slice!(2, int*)`
         auto slice = new int[6].sliced(2, 3).save;
    }


    /++
    Multidimensional `length` property.
    Returns: length of the corresponding dimension
    See_also: $(LREF .Slice.shape), $(LREF .Slice.structure)
    +/
    size_t length(size_t dimension = 0)() @property const
        if (dimension < N)
    {
        pragma(inline, true);
        return _lengths[dimension];
    }

    static if (doUnittest)
    ///
    @safe @nogc pure nothrow unittest
    {
        import std.range: iota;
        auto slice = 100.iota.sliced(3, 4, 5);
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
    size_t stride(size_t dimension = 0)() @property const
        if (dimension < N)
    {
        return _strides[dimension];
    }

    static if (doUnittest)
    /// Regular slice
    @safe @nogc pure nothrow unittest
    {
        import std.range: iota;
        auto slice = 100.iota.sliced(3, 4, 5);
        assert(slice.stride   == 20);
        assert(slice.stride!0 == 20);
        assert(slice.stride!1 == 5);
        assert(slice.stride!2 == 1);
    }

    static if (doUnittest)
    /// Modified regular slice
    @safe @nogc pure nothrow unittest
    {
        import std.experimental.ndslice.iteration: reversed, strided, swapped;
        import std.range: iota;
        assert(1000.iota
            .sliced(3, 4, 50)
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
        pragma(inline, true);
        return _lengths[dimension] == 0;
    }

    ///ditto
    auto ref front(size_t dimension = 0)() @property
        if (dimension < N)
    {
        assert(!empty!dimension);
        static if (PureN == 1)
        {
            static if (__traits(compiles,{ auto _f = _ptr.front; }))
                return _ptr.front;
            else
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
            static if (__traits(compiles, { _ptr.front = value; }))
                return _ptr.front = value;
            else
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
        pragma(inline, true);
        assert(_lengths[dimension], __FUNCTION__ ~ ": length!" ~ dimension.stringof ~ " should be greater than 0.");
        _lengths[dimension]--;
        _ptr += _strides[dimension];
    }

    ///ditto
    void popBack(size_t dimension = 0)()
        if (dimension < N)
    {
        pragma(inline, true);
        assert(_lengths[dimension], __FUNCTION__ ~ ": length!" ~ dimension.stringof ~ " should be greater than 0.");
        _lengths[dimension]--;
    }

    ///ditto
    void popFrontExactly(size_t dimension = 0)(size_t n)
        if (dimension < N)
    {
        pragma(inline, true);
        assert(n <= _lengths[dimension], __FUNCTION__ ~ ": n should be less than or equal to length!" ~ dimension.stringof);
        _lengths[dimension] -= n;
        _ptr += _strides[dimension] * n;
    }

    ///ditto
    void popBackExactly(size_t dimension = 0)(size_t n)
        if (dimension < N)
    {
        pragma(inline, true);
        assert(n <= _lengths[dimension], __FUNCTION__ ~ ": n should be less than or equal to length!" ~ dimension.stringof);
        _lengths[dimension] -= n;
    }

    ///ditto
    void popFrontN(size_t dimension = 0)(size_t n)
        if (dimension < N)
    {
        pragma(inline, true);
        import std.algorithm.comparison: min;
        popFrontExactly!dimension(min(n, _lengths[dimension]));
    }

    ///ditto
    void popBackN(size_t dimension = 0)(size_t n)
        if (dimension < N)
    {
        pragma(inline, true);
        import std.algorithm.comparison: min;
        popBackExactly!dimension(min(n, _lengths[dimension]));
    }

    static if (doUnittest)
    ///
    @safe @nogc pure nothrow unittest
    {
        import std.range: iota;
        import std.range.primitives;
        auto slice = 10000.iota.sliced(10, 20, 30);

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
        import std.algorithm.comparison: min;
        popFrontExactly(dimension, min(n, _lengths[dimension]));
    }

    package void popBackN(size_t dimension, size_t n)
    {
        assert(dimension < N, __FUNCTION__ ~ ": dimension should be less than N = " ~ N.stringof);
        import std.algorithm.comparison: min;
        popBackExactly(dimension, min(n, _lengths[dimension]));
    }

    /++
    Returns: total number of elements in a slice
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
        import std.range: iota;
        assert(100.iota.sliced(3, 4, 5).elementsCount == 60);
    }


    static if (doUnittest)
    /// Packed slice
    @safe @nogc pure nothrow unittest
    {
        import std.experimental.ndslice.selection: pack, evertPack;
        import std.range: iota;
        auto slice = 50000.iota.sliced(3, 4, 5, 6, 7, 8);
        auto p = slice.pack!2;
        assert(p.elementsCount == 360);
        assert(p[0, 0, 0, 0].elementsCount == 56);
        assert(p.evertPack.elementsCount == 56);
    }

    /++
    Overloading `==` and `!=`
    +/
    bool opEquals(size_t NR, RangeR)(auto ref Slice!(NR, RangeR) rslice)
        if (Slice!(NR, RangeR).PureN == PureN)
    {
        if (this._lengths != rslice._lengths)
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
        return opEqualsImpl(this, rslice);
    }

    ///ditto
    bool opEquals(T)(T[] rarrary)
    {
        if (this.length != rarrary.length)
            return false;
        foreach(i, ref e; rarrary)
            if(e != this[i])
                return false;
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

    _Slice opSlice(size_t dimension)(size_t i, size_t j)
        if (dimension < N)
    in   {
        assert(i <= j,
            "Slice.opSlice!" ~ dimension.stringof ~ ": the left bound must be less than or equal to the right bound.");
        assert(j - i <= _lengths[dimension],
            "Slice.opSlice!" ~ dimension.stringof ~
            ": difference between the right and the left bounds must be less than or equal to the length of the given dimension.");
    }
    body
    {
        pragma(inline, true);
        return typeof(return)(i, j);
    }

    /++
    $(BLUE Fully defined index).
    +/
    auto ref opIndex(Indexes...)(Indexes _indexes)
        if (isFullPureIndex!Indexes)
    {
        static if (PureN == N)
            return _ptr[indexStride(_indexes)];
        else
            return DeepElemType(_lengths[N .. $], _strides[N .. $], _ptr + indexStride(_indexes));
    }

    static if(doUnittest)
    ///
    pure nothrow unittest
    {
        auto slice = new int[10].sliced(5, 2);

        auto p = &slice[1, 1];
        *p = 3;
        assert(slice[1, 1] == 3);

        size_t[2] index = [1, 1];
        assert(slice[index] == 3);
    }

    /++
    $(BLUE Partially or fully defined slice).
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

    static if(doUnittest)
    ///
    pure nothrow unittest
    {
        auto slice = new int[15].sliced(5, 3);

        /// Fully defined slice
        assert(slice[] == slice);
        auto sublice = slice[0..$-2, 1..$];

        /// Partially defined slice
        auto row = slice[3];
        auto col = slice[0..$, 1];
    }

    static if(doUnittest)
    pure nothrow unittest
    {
        auto slice = new int[15].sliced!(ReplaceArrayWithPointer.no)(5, 3);

        /// Fully defined slice
        assert(slice[] == slice);
        auto sublice = slice[0..$-2, 1..$];

        /// Partially defined slice
        auto row = slice[3];
        auto col = slice[0..$, 1];
    }

    static if (isMutable!DeepElemType && PureN == N)
    {
        private void opIndexAssignImpl(string op, size_t RN, RRange, Slices...)(Slice!(RN, RRange) value, Slices slices)
            if (isFullPureSlice!Slices
                && RN <= ReturnType!(opIndex!Slices).N)
        {
            auto slice = this[slices];
            assert(slice._lengths[$ - RN .. $] == value._lengths, __FUNCTION__ ~ ": argument must have the corresponding shape.");
            version(none) //future optimization
            static if((isPointer!Range || isDynamicArray!Range) && (isPointer!RRange || isDynamicArray!RRange))
            {
                enum d = slice.N - value.N;
                foreach_reverse (i; Iota!(0, value.N))
                    if (slice._lengths[i + d] == 1)
                    {
                        if (value._lengths[i] == 1)
                        {
                            static if (i != value.N - 1)
                            {
                                import std.experimental.ndslice.iteration: swapped;
                                slice = slice.swapped(i + d, slice.N - 1);
                                value = value.swapped(i    , value.N - 1);
                            }
                            goto L1;
                        }
                        else
                        {
                            goto L2;
                        }
                    }
                L1:
                _indexAssign!(true, op)(slice, value);
                return;
            }
            L2:
            _indexAssign!(false, op)(slice, value);
        }

        private void opIndexAssignImpl(string op, T, Slices...)(T[] value, Slices slices)
            if (isFullPureSlice!Slices
                && !isDynamicArray!DeepElemType
                && DynamicArrayDimensionsCount!(T[]) <= ReturnType!(opIndex!Slices).N)
        {
            auto slice = this[slices];
            version(none) //future optimization
            static if (isPointer!Range || isDynamicArray!Range)
            {
                if (slice._lengths[$-1] == 1)
                {
                    _indexAssign!(true, op)(slice, value);
                    return;
                }
            }
            _indexAssign!(false, op)(slice, value);
        }

        private void opIndexAssignImpl(string op, T, Slices...)(T value, Slices slices)
            if (isFullPureSlice!Slices
                && (!isDynamicArray!T || isDynamicArray!DeepElemType)
                && !is(T : Slice!(RN, RRange), size_t RN, RRange))
        {
            auto slice = this[slices];
            version(none) //future optimization
            static if (isPointer!Range || isDynamicArray!Range)
            {
                if (slice._lengths[$-1] == 1)
                {
                    _indexAssign!(true, op)(slice, value);
                    return;
                }
            }
            _indexAssign!(false, op)(slice, value);
        }

        /++
        Assignment of a value of `Slice` type to a $(BLUE fully defined slice).
        +/
        void opIndexAssign(size_t RN, RRange, Slices...)(Slice!(RN, RRange) value, Slices slices)
            if (isFullPureSlice!Slices
                && RN <= ReturnType!(opIndex!Slices).N)
        {
            opIndexAssignImpl!""(value, slices);
        }

        static if(doUnittest)
        ///
        pure nothrow unittest
        {
            auto a = new int[6].sliced(2, 3);
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

        static if(doUnittest)
        pure nothrow unittest
        {
            auto a = new int[6].sliced!(ReplaceArrayWithPointer.no)(2, 3);
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
        Assignment of a regular multidimensional array to a $(BLUE fully defined slice).
        +/
        void opIndexAssign(T, Slices...)(T[] value, Slices slices)
            if (isFullPureSlice!Slices
                && !isDynamicArray!DeepElemType
                && DynamicArrayDimensionsCount!(T[]) <= ReturnType!(opIndex!Slices).N)
        {
            opIndexAssignImpl!""(value, slices);
        }

        static if(doUnittest)
        ///
        pure nothrow unittest
        {
            auto a = new int[6].sliced(2, 3);
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

        static if(doUnittest)
        pure nothrow unittest
        {
            auto a = new int[6].sliced!(ReplaceArrayWithPointer.no)(2, 3);
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
        Assignment of a value (e.g. a number) to a $(BLUE fully defined slice).
        +/
        void opIndexAssign(T, Slices...)(T value, Slices slices)
            if (isFullPureSlice!Slices
                && (!isDynamicArray!T || isDynamicArray!DeepElemType)
                && !is(T : Slice!(RN, RRange), size_t RN, RRange))
        {
            opIndexAssignImpl!""(value, slices);
        }

        static if(doUnittest)
        ///
        pure nothrow unittest
        {
            auto a = new int[6].sliced(2, 3);

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

        static if(doUnittest)
        pure nothrow unittest
        {
            auto a = new int[6].sliced!(ReplaceArrayWithPointer.no)(2, 3);

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

        /++
        Assignment of a value (e.g. a number) to a $(BLUE fully defined index).
        +/
        auto ref opIndexAssign(T, Indexes...)(T value, Indexes _indexes)
            if (isFullPureIndex!Indexes)
        {
            return _ptr[indexStride(_indexes)] = value;
        }

        static if(doUnittest)
        ///
        pure nothrow unittest
        {
            auto a = new int[6].sliced(2, 3);

            a[1, 2] = 3;
            assert(a[1, 2] == 3);
        }

        static if(doUnittest)
        pure nothrow unittest
        {
            auto a = new int[6].sliced!(ReplaceArrayWithPointer.no)(2, 3);

            a[1, 2] = 3;
            assert(a[1, 2] == 3);
        }

        /++
        Op Assignment `op=` of a value (e.g. a number) to a $(BLUE fully defined index).
        +/
        auto ref opIndexOpAssign(string op, T, Indexes...)(T value, Indexes _indexes)
            if (isFullPureIndex!Indexes)
        {
            mixin (`return _ptr[indexStride(_indexes)] ` ~ op ~ `= value;`);
        }

        static if(doUnittest)
        ///
        pure nothrow unittest
        {
            auto a = new int[6].sliced(2, 3);

            a[1, 2] += 3;
            assert(a[1, 2] == 3);
        }

        static if(doUnittest)
        pure nothrow unittest
        {
            auto a = new int[6].sliced!(ReplaceArrayWithPointer.no)(2, 3);

            a[1, 2] += 3;
            assert(a[1, 2] == 3);
        }

        /++
        Op Assignment `op=` of a value of `Slice` type to a $(BLUE fully defined slice).
        +/
        void opIndexOpAssign(string op, size_t RN, RRange, Slices...)(Slice!(RN, RRange) value, Slices slices)
            if (isFullPureSlice!Slices
                && RN <= ReturnType!(opIndex!Slices).N)
        {
            opIndexAssignImpl!op(value, slices);
        }

        static if(doUnittest)
        ///
        pure nothrow unittest
        {
            auto a = new int[6].sliced(2, 3);
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

        static if(doUnittest)
        pure nothrow unittest
        {
            auto a = new int[6].sliced!(ReplaceArrayWithPointer.no)(2, 3);
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
        Op Assignment `op=` of a regular multidimensional array to a $(BLUE fully defined slice).
        +/
        void opIndexOpAssign(string op, T, Slices...)(T[] value, Slices slices)
            if (isFullPureSlice!Slices
                && !isDynamicArray!DeepElemType
                && DynamicArrayDimensionsCount!(T[]) <= ReturnType!(opIndex!Slices).N)
        {
            opIndexAssignImpl!op(value, slices);
        }

        static if(doUnittest)
        ///
        pure nothrow unittest
        {
            auto a = new int[6].sliced(2, 3);

            a[0..$, 0..$-1] += [[1, 2], [3, 4]];
            assert(a == [[1, 2, 0], [3, 4, 0]]);

            a[0..$, 0..$-1] += [1, 2];
            assert(a == [[2, 4, 0], [4, 6, 0]]);

            a[1, 0..$-1] += [3, 4];
            assert(a[1] == [7, 10, 0]);

            a[1, 0..$-1][] += [1, 2];
            assert(a[1] == [8, 12, 0]);
        }

        static if(doUnittest)
        pure nothrow unittest
        {
            auto a = new int[6].sliced!(ReplaceArrayWithPointer.no)(2, 3);

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
        Op Assignment `op=` of a value (e.g. a number) to a $(BLUE fully defined slice).
        +/
        void opIndexOpAssign(string op, T, Slices...)(T value, Slices slices)
            if (isFullPureSlice!Slices
                && (!isDynamicArray!T || isDynamicArray!DeepElemType)
                && !is(T : Slice!(RN, RRange), size_t RN, RRange))
        {
            opIndexAssignImpl!op(value, slices);
        }

        static if(doUnittest)
        ///
        pure nothrow unittest
        {
            auto a = new int[6].sliced(2, 3);

            a[] += 1;
            assert(a == [[1, 1, 1], [1, 1, 1]]);

            a[0..$, 0..$-1] += 2;
            assert(a == [[3, 3, 1], [3, 3, 1]]);

            a[1, 0..$-1] += 3;
            assert(a[1] == [6, 6, 1]);
        }

        static if(doUnittest)
        pure nothrow unittest
        {
            auto a = new int[6].sliced!(ReplaceArrayWithPointer.no)(2, 3);

            a[] += 1;
            assert(a == [[1, 1, 1], [1, 1, 1]]);

            a[0..$, 0..$-1] += 2;
            assert(a == [[3, 3, 1], [3, 3, 1]]);

            a[1, 0..$-1] += 3;
            assert(a[1] == [6, 6, 1]);
        }

        /++
        Increment `++` and Decrement `--` operators for a $(BLUE fully defined index).
        +/
        auto ref opIndexUnary(string op, Indexes...)(Indexes _indexes)
            if (isFullPureIndex!Indexes && (op == `++` || op == `--`))
        {
            mixin (`return ` ~ op ~ `_ptr[indexStride(_indexes)];`);
        }

        static if(doUnittest)
        ///
        pure nothrow unittest
        {
            auto a = new int[6].sliced(2, 3);

            ++a[1, 2];
            assert(a[1, 2] == 1);
        }

        static if(doUnittest)
        pure nothrow unittest
        {
            auto a = new int[6].sliced!(ReplaceArrayWithPointer.no)(2, 3);

            ++a[1, 2];
            assert(a[1, 2] == 1);
        }

        /++
        Increment `++` and Decrement `--` operators for a $(BLUE fully defined slice).
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

        static if(doUnittest)
        ///
        pure nothrow unittest
        {
            auto a = new int[6].sliced(2, 3);

            ++a[];
            assert(a == [[1, 1, 1], [1, 1, 1]]);

            --a[1, 0..$-1];
            assert(a[1] == [0, 0, 1]);
        }

        static if(doUnittest)
        pure nothrow unittest
        {
            auto a = new int[6].sliced!(ReplaceArrayWithPointer.no)(2, 3);

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
    import std.array: array;
    import std.range: iota;
    import std.experimental.ndslice.iteration: transposed;

    auto tensor = 60.iota.array.sliced(3, 4, 5);

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
    static assert(!__traits(compiles), tensor[0 .. 2] *= 2);

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
    import std.experimental.ndslice.iteration: transposed, everted;

    auto tensor = new int[60].sliced(3, 4, 5);
    auto matrix = new int[12].sliced(3, 4);
    auto vector = new int[ 3].sliced(3);

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
See also $(LINK2 std_format.html, std.format).
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

        auto slice = new int[rows * columns].sliced(rows, columns);
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
    import std.range: iota;
    auto a = 1000000.iota.sliced(10, 20, 30, 40);
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
    import std.range: iota;
    import std.array: array;
    auto fun(ref int x) { x *= 3; }

    auto tensor = 1000
        .iota
        .array
        .sliced(8, 9, 10);

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
    import std.algorithm.iteration: map;
    import std.array: array;
    import std.bigint;
    import std.range: iota;

    auto matrix = 100
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
    import std.algorithm.iteration: map;
    import std.array: array;
    import std.range: iota;

    auto matrix = 100
        .iota
        .array
        .sliced(8, 9);

    matrix[] = matrix;
    matrix[] += matrix;
    assert(matrix[2, 3] == (2 * 9 + 3) * 2);

    auto vec = iota(100, 200).sliced(9);
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
    static assert(is(typeof(ar[].sliced(3, 4)) == Slice!(2, typeof(ar[]))));

    // Implicit conversion of a range to its unqualified type.
    import std.range: iota;
    auto      i0 = 100.iota;
    const     i1 = 100.iota;
    immutable i2 = 100.iota;
    alias S = Slice!(3, typeof(iota(0)));
    foreach (i; AliasSeq!(i0, i1, i2))
        static assert(is(typeof(i.sliced(3, 4, 5)) == S));
}

// Test for map #1
unittest
{
    import std.algorithm.iteration: map;
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
    import std.algorithm.iteration: map;
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
    (size_t NL, RangeL, size_t NR, RangeR)(
    auto ref Slice!(NL, RangeL) ls,
    auto ref Slice!(NR, RangeR) rs)
in
{
    assert(ls._lengths == rs._lengths);
}
body
{
    foreach (i; 0 .. ls.length)
    {
        static if (Slice!(NL, RangeL).PureN == 1)
        {
            if (ls[i] != rs[i])
                return false;
        }
        else
        {
            if (!opEqualsImpl(ls[i], rs[i]))
                return false;
        }
    }
    return true;
}

private struct PtrShell(Range)
{
    sizediff_t _shift;
    Range _range;

    enum hasAccessByRef = isPointer!Range ||
        __traits(compiles, { auto a = &(_range[0]); } );

    void opOpAssign(string op)(sizediff_t shift)
        if (op == `+` || op == `-`)
    {
        pragma(inline, true);
        mixin (`_shift ` ~ op ~ `= shift;`);
    }

    auto opBinary(string op)(sizediff_t shift)
        if (op == `+` || op == `-`)
    {
        mixin (`return typeof(this)(_shift ` ~ op ~ ` shift, _range);`);
    }

    auto ref opIndex(sizediff_t index)
    in
    {
        import std.range.primitives: hasLength;
        assert(_shift + index >= 0);
        static if (hasLength!Range)
            assert(_shift + index <= _range.length);
    }
    body
    {
        return _range[_shift + index];
    }

    static if (!hasAccessByRef)
    {
        auto ref opIndexAssign(T)(T value, sizediff_t index)
        in
        {
            import std.range.primitives: hasLength;
            assert(_shift + index >= 0);
            static if (hasLength!Range)
                assert(_shift + index <= _range.length);
        }
        body
        {
            return _range[_shift + index] = value;
        }

        auto ref opIndexOpAssign(string op, T)(T value, sizediff_t index)
        in
        {
            import std.range.primitives: hasLength;
            assert(_shift + index >= 0);
            static if (hasLength!Range)
                assert(_shift + index <= _range.length);
        }
        body
        {
            mixin (`return _range[_shift + index] ` ~ op ~ `= value;`);
        }

        auto ref opIndexUnary(string op)(sizediff_t index)
        in
        {
            import std.range.primitives: hasLength;
            assert(_shift + index >= 0);
            static if (hasLength!Range)
                assert(_shift + index <= _range.length);
        }
        body
        {
            mixin (`return ` ~ op ~ `_range[_shift + index];`);
        }
    }

    static if (canSave!Range)
    auto save() @property
    {
        static if (isDynamicArray!Range)
            return typeof(this)(_shift, _range);
        else
            return typeof(this)(_shift, _range.save);
    }
}

private auto ptrShell(Range)(Range range, sizediff_t shift = 0)
{
    return PtrShell!Range(shift, range);
}

@safe pure nothrow unittest
{
    import std.internal.test.dummyrange;
    foreach (RB; AliasSeq!(ReturnBy.Reference, ReturnBy.Value))
    {
        DummyRange!(RB, Length.Yes, RangeType.Random) range;
        range.reinit;
        assert(range.length >= 10);
        auto ptr = range.ptrShell;
        assert(ptr[0] == range[0]);
        auto save0 = range[0];
        ptr[0] += 10;
        ++ptr[0];
        assert(ptr[0] == save0 + 11);
        (ptr + 5)[2] = 333;
        assert(range[7] == 333);
    }
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

private enum isSlicePointer(T) = isPointer!T || is(T : PtrShell!R, R);

private struct LikePtr {}

package template hasPtrBehavior(T)
{
    static if (isPointer!T)
        enum hasPtrBehavior = true;
    else
    static if (!isAggregateType!T)
        enum hasPtrBehavior = false;
    else
        enum hasPtrBehavior = hasUDA!(T, LikePtr);
}

private template PtrTuple(Names...)
{
    @LikePtr struct PtrTuple(Ptrs...)
        if (allSatisfy!(isSlicePointer, Ptrs) && Ptrs.length == Names.length)
    {
        Ptrs ptrs;

        static if (allSatisfy!(canSave, Ptrs))
        auto save() @property
        {
            static if (anySatisfy!(hasElaborateAssign, Ptrs))
                PtrTuple p;
            else
                PtrTuple p = void;
            foreach (i, ref ptr; ptrs)
                static if (isPointer!(Ptrs[i]))
                    p.ptrs[i] = ptr;
                else
                    p.ptrs[i] = ptr.save;

            return p;
        }

        void opOpAssign(string op)(sizediff_t shift)
            if (op == `+` || op == `-`)
        {
            foreach (ref ptr; ptrs)
                mixin (`ptr ` ~ op ~ `= shift;`);
        }

        auto opBinary(string op)(sizediff_t shift)
            if (op == `+` || op == `-`)
        {
            auto ret = this.ptrs;
            ret.opOpAssign!op(shift);
            return ret;
        }

        public struct Index
        {
            Ptrs _ptrs__;
            mixin (PtrTupleFrontMembers!Names);
        }

        auto opIndex(sizediff_t index)
        {
            auto p = ptrs;
            foreach (ref ptr; p)
                ptr += index;
            return Index(p);
        }

        auto front() @property
        {
            return Index(ptrs);
        }
    }
}

pure nothrow unittest
{
    auto a = new int[20], b = new int[20];
    import std.stdio;
    alias T = PtrTuple!("a", "b");
    alias S = T!(int*, int*);
    auto t = S(a.ptr, b.ptr);
    t[4].a++;
    auto r = t[4];
    r.b = r.a * 2;
    assert(b[4] == 2);
    t.front.a++;
    r = t.front;
    r.b = r.a * 2;
    assert(b[0] == 2);
}

private template PtrTupleFrontMembers(Names...)
    if (Names.length <= 32)
{
    static if (Names.length)
    {
        alias Top = Names[0..$-1];
        enum int m = Top.length;
        enum PtrTupleFrontMembers = PtrTupleFrontMembers!Top
        ~ "
        @property auto ref " ~ Names[$-1] ~ "() {
            static if (__traits(compiles,{ auto _f = _ptrs__[" ~ m.stringof ~ "].front; }))
                return _ptrs__[" ~ m.stringof ~ "].front;
            else
                return _ptrs__[" ~ m.stringof ~ "][0];
        }
        ";
    }
    else
    {
        enum PtrTupleFrontMembers = "";
    }
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

private void _indexAssign(bool lastStrideEquals1, string op, size_t N, size_t RN, Range, RRange)(Slice!(N, Range) slice, Slice!(RN, RRange) value)
    if (N >= RN)
{
    static if (N == 1)
    {
        static if (lastStrideEquals1 && (isPointer!Range || isDynamicArray!Range) && (isPointer!RRange || isDynamicArray!RRange))
        {
            static if (isPointer!Range)
                auto l = slice._ptr;
            else
                auto l = slice._ptr._range[slice._ptr._shift .. slice._ptr._shift + slice._lengths[0]];
            static if (isPointer!RRange)
                auto r = value._ptr;
            else
                auto r = value._ptr._range[value._ptr._shift .. value._ptr._shift + value._lengths[0]];
            auto len = slice._lengths[0];
            for (size_t i; i < len; i++)
            {
                mixin("l[i]" ~ op ~ "= r[i];");
            }
        }
        else
        {
            while (slice._lengths[0])
            {
                mixin("slice.front " ~ op ~ "= value.front;");
                slice.popFront;
                value.popFront;
            }
        }
    }
    else
    static if (N == RN)
    {
        while (slice._lengths[0])
        {
            _indexAssign!(lastStrideEquals1, op)(slice.front, value.front);
            slice.popFront;
            value.popFront;
        }
    }
    else
    {
        while (slice._lengths[0])
        {
            _indexAssign!(lastStrideEquals1, op)(slice.front, value);
            slice.popFront;
        }
    }
}

private void _indexAssign(bool lastStrideEquals1, string op, size_t N, Range, T)(Slice!(N, Range) slice, T[] value)
    if (DynamicArrayDimensionsCount!(T[]) <= N)
{
    assert(slice.length == value.length, __FUNCTION__ ~ ": argument must have the same length.");
    static if (N == 1)
    {
        static if (lastStrideEquals1 && (isPointer!Range || isDynamicArray!Range))
        {
            static if (isPointer!Range)
                auto l = slice._ptr;
            else
                auto l = slice._ptr._range[slice._ptr._shift .. slice._ptr._shift + slice._lengths[0]];
            auto r = value;
            auto len = slice._lengths[0];
            for (size_t i; i < len; i++)
            {
                mixin("l[i]" ~ op ~ "= r[i];");
            }
        }
        else
        {
            while (slice._lengths[0])
            {
                mixin("slice.front " ~ op ~ "= value[0];");
                slice.popFront;
                value = value[1..$];
            }
        }
    }
    else
    static if (N == DynamicArrayDimensionsCount!(T[]))
    {
        while (slice._lengths[0])
        {
            _indexAssign!(lastStrideEquals1, op)(slice.front, value[0]);
            slice.popFront;
            value = value[1 .. $];
        }
    }
    else
    {
        while (slice._lengths[0])
        {
            _indexAssign!(lastStrideEquals1, op)(slice.front, value);
            slice.popFront;
        }
    }
}

private void _indexAssign(bool lastStrideEquals1, string op, size_t N, Range, T)(Slice!(N, Range) slice, T value)
    if ((!isDynamicArray!T || isDynamicArray!(Slice!(N, Range).DeepElemType))
                && !is(T : Slice!(RN, RRange), size_t RN, RRange))
{
    static if (N == 1)
    {
        static if (lastStrideEquals1 && (isPointer!Range || isDynamicArray!Range))
        {
            static if (isPointer!Range)
                auto l = slice._ptr;
            else
                auto l = slice._ptr._range[slice._ptr._shift .. $];
            auto len = slice._lengths[0];
            for (size_t i; i < len; i++)
            {
                mixin("l[i]" ~ op ~ "= value;");
            }
        }
        else
        {
            while (slice._lengths[0])
            {
                mixin("slice.front " ~ op ~ "= value;");
                slice.popFront;
            }
        }
    }
    else
    {
        while (slice._lengths[0])
        {
            _indexAssign!(lastStrideEquals1, op)(slice.front, value);
            slice.popFront;
        }
    }
}
