/**
$(SCRIPT inhibitQuickIndex = 1;)

This is a submodule of $(MREF std,experimental,ndslice).
It contains basic multidimensional iteration algorithms.

$(BOOKTABLE Iteration operators,
$(TR $(TH Operator Name) $(TH Type) $(TH Functions / Seeds #)  $(TH Vectorization) $(TH Tensors #) $(TH Returns) $(TH First Argument)  $(TH Triangular and Half Selection))
$(T8 ndMap, Lazy, `>=1`/`0`, N/A, 1, Tensor, Tensor, N/A)
$(T8 ndFold, Eagerly, `>=1`, No, `1`, Scalar, Tensor, No)
$(T8 ndReduce, Eagerly, `1`, Optional, `>=1`, Scalar, Seed, Yes)
$(T8 ndEach, Eagerly, `1`/`0`, Optional, `>=1`, `void`, Tensor, Yes)
)

$(BOOKTABLE Eagerly iteration operators with stop condition,
$(TR $(TH Operator Name) $(TH Has Needle) $(TH Finds Index) $(TH Tensors #) $(TH Returns) $(TH Requires Equal Shapes) $(TH Triangular and Half Selection))
$(T7 ndFind, No, Yes, `>=1`, `void`, Yes, Yes)
$(T7 ndAny, No, No, `>=1`, `bool`, Yes, Yes)
$(T7 ndAll, No, No, `>=1`, `bool`, Yes, Yes)
$(T7 ndEqual, No, No, `>=2`, `bool`, No, Yes)
$(T7 ndCmp, No, No, `2`, `int`, No, No)
)

All operators are suitable to change tensors using `ref` argument qualification in a function declaration.

$(H3 Lockstep Iteration)

$(REF_ALTTEXT assumeSameStructure, assumeSameStructure, std,experimental,ndslice,slice)
can be used as multidimensional `zip` analog if tensors have the same structure (shape and strides).
`assumeSameStructure` allows to mutate elements of zipped tensors, which is not possible with common
$(REF zip, std,range).

Also tensors zipped with `assumeSameStructure` uses single set of lengths and strides.
Thus, `assumeSameStructure` may significantly optimize iteration.

If tensors have different strides, then most of existing operators in this module still
can be used as they accept a set of tensors instead of single one.

$(H3 Selection)
$(LREF Select) allows to specify subset of elements to iterate.
$(LREF Select) is useful in combination with $(SUBREF iteration, transposed) and $(SUBREF iteration, reversed).

Note:
    $(SUBREF iteration, transposed) and
    $(SUBREF selection, pack) can be used to specify dimensions.

License:   $(HTTP www.boost.org/LICENSE_1_0.txt, Boost License 1.0).

Authors:   Ilya Yaroshenko

Source:    $(PHOBOSSRC std/_experimental/_ndslice/_algorithm.d)

Macros:
SUBREF = $(REF_ALTTEXT $(TT $2), $2, std,experimental, ndslice, $1)$(NBSP)
T2=$(TR $(TDNW $(LREF $1)) $(TD $+))
T7=$(TR $(TDNW $(LREF $1)) $(TD $2) $(TD $3) $(TD $4) $(TD $5) $(TD $6) $(TD $7))
T8=$(TR $(TDNW $(LREF $1)) $(TD $2) $(TD $3) $(TD $4) $(TD $5) $(TD $6) $(TD $7) $(TD $8))
*/
module std.experimental.ndslice.algorithm;

import std.traits;
import std.meta;
import std.typecons : Flag, Yes, No;

import std.experimental.ndslice.internal;
import std.experimental.ndslice.slice;

private template TensorFronts(size_t length)
{
    static if (length)
    {
        enum i = length - 1;
        enum TensorFronts = TensorFronts!(length - 1) ~ "tensors[" ~ i.stringof ~ "].front, ";
    }
    else
    {
        enum TensorFronts = "";
    }
}

private void checkShapesMatch(bool seed, Select select, Args...)(auto ref Args tensors)
{
    enum msg = seed ?
        "all arguments except the first (seed) must be tensors" :
        "all arguments must be tensors"
        ~ tailErrorMessage!();
    enum msgShape = "all tensors must have the same shape"  ~ tailErrorMessage!();
    foreach (i, Arg; Args)
    {
        static assert (is(Arg == Slice!(N, Range), size_t N, Range), msg);
        static if (select == Select.halfPacked || select == Select.triangularPacked)
        {
            static assert (tensors[i].NSeq.length > 1, "halfPacked and triangularPacked selections require packed slices");
            static if (i)
            {
                static assert (tensors[i].NSeq[0 .. 2] == tensors[0].NSeq[0 .. 2], msgShape);
                enum M = tensors[0].NSeq[0] + tensors[0].NSeq[1] - 1;
                assert(tensors[i]._lengths[0 .. M] == tensors[0]._lengths[0 .. M], msgShape);
            }
        }
        else
        {
            static if (i)
            {
                static assert (tensors[i].N == tensors[0].N, msgShape);
                assert(tensors[i].shape == tensors[0].shape, msgShape);
            }
        }
    }
}

private bool anyEmpty(Select select, size_t N, Range)(ref Slice!(N, Range) slice)
{
    static if (select == Select.halfPacked || select == Select.triangularPacked)
        static if (is(Range : Slice!(M, IRange), size_t M, IRange))
            return Slice!(N + M - 1, IRange)(slice._lengths, slice._strides, slice._ptr).anyEmpty;
        else static assert(0);
    else
        return slice.anyEmpty;
}

private template naryFun(bool hasSeed, size_t argCount, alias fun)
{
    static if (argCount + hasSeed == 1)
    {
        import std.functional : unaryFun;
        alias naryFun = unaryFun!fun;
    }
    else
    static if (argCount + hasSeed == 2)
    {
        import std.functional : binaryFun;
        alias naryFun = binaryFun!fun;
    }
    else
    {
        alias naryFun = fun;
    }
}

/++
Implements the homonym function (also known as `transform`) present
in many languages of functional flavor. The call `ndMap!(fun)(tensor)`
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
template ndMap(fun...)
    if (fun.length)
{
    ///
    auto ndMap(size_t N, Range)
        (auto ref Slice!(N, Range) tensor)
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

    auto s = iotaSlice(2, 3).ndMap!(a => a * 3);
    assert(s == [[ 0,  3,  6],
                 [ 9, 12, 15]]);
}

pure nothrow unittest
{
    import std.experimental.ndslice.selection : iotaSlice;

    assert(iotaSlice(2, 3).slice.ndMap!"a * 2" == [[0, 2, 4], [6, 8, 10]]);
}

/// Packed tensors.
pure nothrow unittest
{
    import std.experimental.ndslice.selection : iotaSlice, windows;

    //  iotaSlice        windows     ndMap  sums ( ndFold!"a + b" )
    //                --------------
    //  -------      |  ---    ---  |      ------
    // | 0 1 2 |  => || 0 1 || 1 2 ||  => | 8 12 |
    // | 3 4 5 |     || 3 4 || 4 5 ||      ------
    //  -------      |  ---    ---  |
    //                --------------
    auto s = iotaSlice(2, 3)
        .windows(2, 2)
        .ndMap!(a => a.ndFold!"a + b"(size_t(0)));

    assert(s == [[8, 12]]);
}

pure nothrow unittest
{
    import std.experimental.ndslice.selection : iotaSlice, windows;

    auto s = iotaSlice(2, 3)
        .slice
        .windows(2, 2)
        .ndMap!(a => a.ndFold!"a + b"(size_t(0)));

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

    auto lazySum = zip.ndMap!(z => z.a + z.b);

    assert(lazySum == [[ 1,  3,  5],
                       [ 7,  9, 11]]);
}

/++
Multiple functions can be passed to `ndMap`.
In that case, the element type of `ndMap` is a tuple containing
one element for each function.
+/
pure nothrow unittest
{
    import std.experimental.ndslice.selection : iotaSlice;

    auto s = iotaSlice(2, 3).ndMap!("a + a", "a * a");

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
You may alias `ndMap` with some function(s) to a symbol and use it separately:
+/
pure nothrow unittest
{
    import std.conv : to;
    import std.experimental.ndslice.selection : iotaSlice;

    alias stringize = ndMap!(to!string);
    assert(stringize(iotaSlice(2, 3)) == [["0", "1", "2"], ["3", "4", "5"]]);
}

private @LikePtr struct Pack(size_t N, Range)
{
    alias Elem = Slice!(N, Range);
    alias PureN = Elem.PureN;
    alias PureRange = Elem.PureRange;

    size_t[PureN] _lengths;
    sizediff_t[PureN] _strides;

    SlicePtr!PureRange _ptr;
    mixin PropagatePtr;

    Elem opIndex(size_t index)
    {
        return Elem(_lengths, _strides, _ptr + index);
    }
}

package @LikePtr struct Map(Range, alias fun)
{
    Range _ptr;
    mixin PropagatePtr;

    auto ref opIndex(size_t index)
    {
        return fun(_ptr[index]);
    }
}

private mixin template PropagatePtr()
{
    void opOpAssign(string op)(sizediff_t shift)
        if (op == `+` || op == `-`)
    {
        mixin (`_ptr ` ~ op ~ `= shift;`);
    }

    auto opBinary(string op)(sizediff_t shift)
        if (op == `+` || op == `-`)
    {
        auto ret = this;
        ret.opOpAssign!op(shift);
        return ret;
    }

    auto opUnary(string op)()
        if (op == `++` || op == `--`)
    {
        mixin(op ~ `_ptr;`);
        return this;
    }
}

private enum Iteration
{
    reduce,
    each,
    find,
    all,
}

void prepareTensors(Select select, Args...)(ref Args tensors)
{
    static if (select == Select.triangular || select == Select.triangularPacked)
    {
        static if (select == Select.triangularPacked)
            enum I = Iota!(tensors[0].N, tensors[0].N + tensors[0].front.N - 1);
        else
            enum I = Iota!(0, tensors[0].N - 1);
        foreach_reverse (i; I)
            if (tensors[0]._lengths[i] > tensors[0]._lengths[i + 1])
                foreach (ref tensor; tensors)
                    tensor._lengths[i] = tensors[0]._lengths[i + 1];
    }
}

// one ring to rule them all
private template implement(Iteration iteration, alias fun, Flag!"vectorized" vec, Flag!"fastmath" fm)
{
    static if (fm)
        alias attr = fastmath;
    else
        alias attr = fastmathDummy;

    static if (iteration == Iteration.reduce)
        enum argStr = "S, Tensors...)(S seed, Tensors tensors)";
    else
    static if (iteration == Iteration.find)
        enum argStr = "size_t M, Tensors...)(ref size_t[M] backwardIndex, Tensors tensors)";
    else
        enum argStr = "Tensors...)(Tensors tensors)";

    mixin("@attr auto implement(size_t N, Select select, " ~ argStr ~ "{" ~ bodyStr ~ "}");
    enum bodyStr = q{
        static if (iteration == Iteration.find)
        {
            static if (select == Select.halfPacked || select == Select.triangularPacked)
                enum S = N + tensors[0].front.N;
            else
                enum S = N;
            static assert (M == S, "backwardIndex length should be equal to " ~ S.stringof);
        }
        static if (select == Select.half)
        {
            immutable lengthSave = tensors[0]._lengths[0];
            tensors[0]._lengths[0] >>= 1;
            if (tensors[0]._lengths[0] == 0)
                goto End;
        }
        static if (select == Select.halfPacked)
            static if (N == 1)
                enum nextSelect = Select.half;
            else
                enum nextSelect = Select.halfPacked;
        else
        static if (select == Select.triangularPacked)
            static if (N == 1)
                enum nextSelect = Select.triangular;
            else
                enum nextSelect = Select.triangularPacked;
        else
        static if (N == 1)
            enum nextSelect = -1;
        else
        static if (select == Select.half)
            enum nextSelect = Select.full;
        else
            enum nextSelect = select;
        static if (select == Select.triangular)
            alias popSeq = Iota!(0, N);
        else
            alias popSeq = AliasSeq!(size_t(0));
        static if (N == 1 && (select == Select.halfPacked || select == Select.triangularPacked))
            enum M = tensors[0].front.N;
        else
            enum M = N - 1;
        static if (iteration == Iteration.reduce)
            static if (nextSelect == -1)
                enum compute = `seed = naryFun!(true, Tensors.length, fun)(seed, ` ~ TensorFronts!(Tensors.length) ~ `);`;
            else
                enum compute = `seed = implement!(M, nextSelect)(seed, ` ~ TensorFronts!(Tensors.length) ~ `);`;
        else
        static if (iteration == Iteration.each)
            static if (nextSelect == -1)
                enum compute = `naryFun!(false, Tensors.length, fun)(` ~ TensorFronts!(Tensors.length) ~ `);`;
            else
                enum compute = `implement!(M, nextSelect)(` ~ TensorFronts!(Tensors.length) ~ `);`;
        else
        static if (iteration == Iteration.find)
            static if (nextSelect == -1)
                enum compute = `auto val = naryFun!(false, Tensors.length, fun)(` ~ TensorFronts!(Tensors.length) ~ `);`;
            else
                enum compute = `implement!(M, nextSelect)(backwardIndex[1 .. $] , ` ~ TensorFronts!(Tensors.length) ~ `);`;
        else
        static if (iteration == Iteration.all)
            static if (nextSelect == -1)
                enum compute = `auto val = naryFun!(false, Tensors.length, fun)(` ~ TensorFronts!(Tensors.length) ~ `);`;
            else
                enum compute = `auto val = implement!(M, nextSelect)(` ~ TensorFronts!(Tensors.length) ~ `);`;
        else
        static assert(0);
        enum breakStr = q{
            static if (iteration == Iteration.find)
            {
                static if (nextSelect != -1)
                    auto val = backwardIndex[$ - 1];
                if (val)
                {
                    backwardIndex[0] = tensors[0]._lengths[0];
                    static if (select == Select.half)
                        backwardIndex[0] += lengthSave - (lengthSave >> 1);
                    return;
                }
            }
            else
            static if (iteration == Iteration.all)
            {
                if (!val)
                    return false;
            }
        };
        do
        {
            mixin(compute);
            mixin(breakStr);
            foreach_reverse (t, ref tensor; tensors)
            {
                foreach (d; popSeq)
                {
                    static if (d == M && vec)
                    {
                        ++tensor._ptr;
                        static if (t == 0)
                            --tensors[0]._lengths[0];
                    }
                    else
                    {
                        tensor.popFront!d;
                    }
                }
            }
        }
        while (tensors[0]._lengths[0]);
        End:
        static if (select == Select.half && N > 1)
        {
            static if (iteration == Iteration.reduce)
                enum computeHalf = `seed = implement!(N - 1, Select.half)(seed, ` ~ TensorFronts!(Tensors.length) ~ `);`;
            else
            static if (iteration == Iteration.each)
                enum computeHalf = `implement!(N - 1, Select.half)(` ~ TensorFronts!(Tensors.length) ~ `);`;
            else
            static if (iteration == Iteration.find)
                enum computeHalf = `implement!(N - 1, Select.half)(backwardIndex[1 .. $] , ` ~ TensorFronts!(Tensors.length) ~ `);`;
            else
            static if (iteration == Iteration.all)
                enum computeHalf = `auto val = implement!(N - 1, Select.half)(` ~ TensorFronts!(Tensors.length) ~ `);`;
            else
            static assert(0);
            if (lengthSave & 1)
            {
                tensors[0]._lengths[0] = 1;
                mixin(computeHalf);
                mixin(breakStr);
            }
        }
        static if (iteration == Iteration.reduce)
            return seed;
        else
        static if (iteration == Iteration.all)
            return true;
    };
}

/++
Selection type.
`Select` can be used with
$(LREF ndReduce),
$(LREF ndEach),
$(LREF ndFind),
$(LREF ndAny),
$(LREF ndAll),
$(LREF ndEqual),
$(LREF ndCmp).

Any dimension count is supported.
Types has examples for 1D, 2D, and 3D cases.
+/
enum Select
{
    /++
    `full` is the default selection type.

    1D Example:
    -----
    1 2 3
    -----
    2D Example:
    -----
    | 1 2 3 |
    | 4 5 6 |
    | 7 8 9 |
    -----
    3D Example:
    -----
    | 1  2  3 | | 10 11 12 | | 19 20 21 |
    | 4  5  6 | | 13 14 15 | | 22 23 24 |
    | 7  8  9 | | 16 17 18 | | 25 26 27 |
    -----
    +/
    full,
    /++
    `half` can be used to reverse elements in a tensor.

    1D Example:
    -----
    1 x x
    -----
    2D Example:
    -----
    | 1 2 3 |
    | 4 x x |
    | x x x |
    -----
    3D Example:
    -----
    | 1  2  3 | | 10 11 12 | |  x  x  x |
    | 4  5  6 | | 13  x  x | |  x  x  x |
    | 7  8  9 | |  x  x  x | |  x  x  x |
    -----
    +/
    half,
    /++
    `halfPacked` requires packed tensors.
    For the first pack of dimensions elements are selected using `full` selection.
    For the second pack of dimensions elements are selected using `half` selection.
    +/
    halfPacked,
    /++
    `upper` can be used to iterate on upper or lower triangular matrix.

    1D Example:
    -----
    1 2 3
    -----
    2D Example #1:
    -----
    | 1 2 3 |
    | x 4 5 |
    | x x 6 |
    -----
    2D Example #2:
    -----
    | 1 2 3 4 |
    | x 5 6 7 |
    | x x 8 9 |
    -----
    2D Example #3:
    -----
    | 1 2 3 |
    | x 4 5 |
    | x x 6 |
    | x x x |
    -----
    3D Example:
    -----
    |  1  2  3 | |  x  7  8 | |  x  x 10 |
    |  x  4  5 | |  x  x  9 | |  x  x  x |
    |  x  x  6 | |  x  x  x | |  x  x  x |
    -----
    +/
    triangular,
    /++
    `triangularPacked` requires packed tensors.
    For the first pack of dimensions elements are selected using `full` selection.
    For the second pack of dimensions elements are selected using `triangular` selection.
    +/
    triangularPacked,
}

/++
Implements the homonym function (also known as `accumulate`,
`compress`, `inject`, or `foldl`) present in various programming
languages of functional flavor. The call `fold!(fun)(tensor, seed)`
first assigns `seed` to an internal variable `result`,
also called the accumulator. Then, for each element `x` in
`tensor`, `result = fun(result, x)` gets evaluated. Finally,
`result` is returned.

$(LREF ndFold) allows to compute values for multiple functions.

Note:
    $(SUBREF iteration, transposed) and
    $(SUBREF selection, pack) can be used to specify dimensions.
Params:
    fun = One or more functions.
    tensor = An input tensor.
    seed = One or more initial accumulation values (seeds count equals to `fun` count).
Returns:
    the accumulated `result`
See_Also:
    This is functionally similar to $(LREF ndReduce) with the argument order reversed.
    $(LREF ndReduce) allows to iterate multiple tensors in the lockstep.

    $(REF fold, std,algorithm,iteration)

    $(HTTP en.wikipedia.org/wiki/Fold_(higher-order_function), Fold (higher-order function))
+/
template ndFold(fun...)
    if (fun.length)
{
    import std.functional : binaryFun;
    private alias binfuns = staticMap!(binaryFun, fun);
    static if (fun.length > 1)
        import std.typecons : Tuple;

    ///
    auto ndFold(size_t N, Range, S...)(auto ref Slice!(N, Range) tensor, S seed)
        if (S.length == fun.length)
    {
        alias US = staticMap!(Unqual, S);
        if (tensor.anyEmpty)
        {
            static if (S.length == 1)
                return cast(US[0]) seed[0];
            else
                return Tuple!US(seed);
        }
        return ndFoldImpl!(N, Range, staticMap!(Unqual, S))(tensor, seed);
    }

    private auto ndFoldImpl(size_t N, Range, S...)(Slice!(N, Range) tensor, S seed)
    {
        do
        {
            static if (N == 1)
                static if (S.length == 1 || __traits(compiles, &(tensor.front)))
                    foreach (i, f; binfuns)
                        seed[i] = f(seed[i], tensor.front);
                else
                {
                    auto elem = tensor.front;
                    foreach (i, f; binfuns)
                        seed[i] = f(seed[i], elem);
                }
            else
            static if (S.length == 1)
                seed[0] = ndFoldImpl!(N - 1, Range, S)(tensor.front, seed);
            else
                seed = ndFoldImpl!(N - 1, Range, S)(tensor.front, seed).expand;
            tensor.popFront;
        }
        while (tensor._lengths[0]);

        static if (S.length == 1)
            return seed[0];
        else
            return Tuple!S(seed);
    }
}

/// Single seed
unittest
{
    import std.experimental.ndslice.selection : iotaSlice;

    //| 0 1 2 | => 3  |
    //| 3 4 5 | => 12 | => 15
    auto sl = iotaSlice(2, 3);

    // sum of all element in the tensor
    auto res = sl.ndFold!"a + b"(size_t(0));

    assert(res == 15);
}

/// Multiple seeds
unittest
{
    import std.experimental.ndslice.selection : iotaSlice;

    //| 1 2 3 |
    //| 4 5 6 |
    auto sl = iotaSlice([2, 3], 1);

    alias sumAndProduct = ndFold!("a + b", "a * b");
    auto res = sumAndProduct(sl, size_t(0), size_t(1));

    assert(res[0] == 21);
    assert(res[1] == 720); // 6!
}

/// Zipped tensors, dot product
pure unittest
{
    import std.conv : to;
    import std.range : iota;
    import std.numeric : dotProduct;
    import std.experimental.ndslice.slice : assumeSameStructure;
    import std.experimental.ndslice.selection : iotaSlice;

    // 0 1 2
    // 3 4 5
    auto sl1 = iotaSlice(2, 3).ndMap!(to!double).slice;
    // 1 2 3
    // 4 5 6
    auto sl2 = iotaSlice([2, 3], 1).ndMap!(to!double).slice;

    // tensors must have the same strides
    assert(sl1.structure == sl2.structure);

    auto zip = assumeSameStructure!("a", "b")(sl1, sl2);

    auto dot = zip.ndFold!((seed, z) => seed + z.a * z.b)(0.0);

    assert(dot == dotProduct(iota(0, 6), iota(1, 7)));
}

/// Tensor mutation on-the-fly
unittest
{
    import std.conv : to;
    import std.experimental.ndslice.slice : slice;
    import std.experimental.ndslice.selection : iotaSlice;

    //| 0 1 2 |
    //| 3 4 5 |
    auto sl = iotaSlice(2, 3).ndMap!(to!double).slice;

    alias fun = (seed, ref elem) => seed + elem++;

    auto res = sl.ndFold!fun(0.0);

    assert(res == 15);

    //| 1 2 3 |
    //| 4 5 6 |
    assert(sl == iotaSlice([2, 3], 1));
}

/++
Packed tensors.

Computes minimum value for maximum values for each row.
+/
unittest
{
    import std.algorithm.comparison : min, max;
    import std.experimental.ndslice.iteration : transposed;
    import std.experimental.ndslice.selection : iotaSlice, pack;

    alias maxVal = (a) => a.ndFold!max(size_t.min);
    alias minVal = (a) => a.ndFold!min(size_t.max);
    alias minimaxVal = (a) => minVal(a.pack!1.ndMap!maxVal);

    auto sl = iotaSlice(2, 3);

    //| 0 1 2 | => | 2 |
    //| 3 4 5 | => | 5 | => 2
    auto res = minimaxVal(sl);
    assert(res == 2);

    //| 0 1 2 |    | 0 3 | => | 3 |
    //| 3 4 5 | => | 1 4 | => | 4 |
    //             | 2 5 | => | 5 | => 3
    auto resT = minimaxVal(sl.transposed);
    assert(resT == 3);
}

@safe pure nothrow @nogc unittest
{
    import std.experimental.ndslice.iteration : dropOne;
    import std.experimental.ndslice.selection : iotaSlice;
    auto a = iotaSlice(1, 1).dropOne!0.ndFold!"a + b"(size_t(7));
    auto b = iotaSlice(1, 1).dropOne!1.ndFold!("a + b", "a * b")(size_t(7), size_t(8));
    assert(a == 7);
    assert(b[0] == 7);
    assert(b[1] == 8);
}

/++
Implements the homonym function (also known as `accumulate`,
`compress`, `inject`, or `foldl`) present in various programming
languages of functional flavor. The call `fold!(fun)(seed, tensors1, ..., tesnsorN)`
first assigns `seed` to an internal variable `result`,
also called the accumulator. Then, for each set of element `x1, ..., xN` in
`tensors1, ..., tensorN`, `result = fun(result, x1, ..., xN)` gets evaluated. Finally,
`result` is returned.

`ndReduce` allows to iterate multiple tensors in the lockstep.

Note:
    $(SUBREF iteration, transposed) and
    $(SUBREF selection, pack) can be used to specify dimensions.
Params:
    fun = A function.
    select = Selection type.
    vec = Use vectorization friendly iteration without manual unrolling
        in case of all tensors has the last (row) stride equal to 1.
    fm = Allow a compiler to use unsafe floating-point mathematic transformations,
        such as commutative transformation. `fm` is enabled by default if `vec` is enabled.
    seed = An initial accumulation value.
    tensors = One or more tensors.
Returns:
    the accumulated `result`
See_Also:
    $(HTTP llvm.org/docs/LangRef.html#fast-math-flags, LLVM IR: Fast Math Flags)

    This is functionally similar to $(LREF ndReduce) with the argument order reversed.
    $(LREF ndFold) allows to compute values for multiple functions.

    $(REF reduce, std,algorithm,iteration)

    $(HTTP en.wikipedia.org/wiki/Fold_(higher-order_function), Fold (higher-order function))
+/
alias ndReduce(alias fun, Flag!"vectorized" vec = No.vectorized, Flag!"fastmath" fm = cast(Flag!"fastmath")vec) =
    .ndReduce!(fun, Select.full, vec, fm);

/// ditto
template ndReduce(alias fun, Select select, Flag!"vectorized" vec = No.vectorized, Flag!"fastmath" fm = cast(Flag!"fastmath")vec)
{
    ///
    auto ndReduce(S, Args...)(S seed, Args tensors)
        if (Args.length)
    {
        tensors.checkShapesMatch!(true, select);
        if (anyEmpty!select(tensors[0]))
            return cast(Unqual!S) seed;
        prepareTensors!select(tensors);
        alias impl = implement!(Iteration.reduce, fun, No.vectorized, fm);
        static if (vec && allSatisfy!(isMemory, staticMap!(RangeOf, Args)))
        {
            foreach (ref tensor; tensors)
                if (tensor._strides[$-1] != 1)
                    goto CommonL;
            alias implVec = implement!(Iteration.reduce, fun, Yes.vectorized, fm);
            return implVec!(Args[0].N, select, staticMap!(Unqual, S))(seed, tensors);
            CommonL:
        }
        return impl!(Args[0].N, select, staticMap!(Unqual, S))(seed, tensors);
    }
}

/// Single tensor
unittest
{
    import std.experimental.ndslice.selection : iotaSlice;

    //| 0 1 2 | => 3  |
    //| 3 4 5 | => 12 | => 15
    auto sl = iotaSlice(2, 3);

    // sum of all element in the tensor
    auto res = size_t(0).ndReduce!"a + b"(sl);

    assert(res == 15);
}

/// Multiple tensors, dot product
unittest
{
    import std.typecons : Yes;
    import std.conv : to;
    import std.experimental.ndslice.selection : iotaSlice;
    import std.experimental.ndslice.internal : fastmath;

    static @fastmath T fmuladd(T)(const T a, const T b, const T c)
    {
        return a + b * c;
    }

    //| 0 1 2 |
    //| 3 4 5 |
    auto a = iotaSlice([2, 3], 0).ndMap!(to!double).slice;
    //| 1 2 3 |
    //| 4 5 6 |
    auto b = iotaSlice([2, 3], 1).ndMap!(to!double).slice;

    alias dot = ndReduce!(fmuladd, Yes.vectorized);
    auto res = dot(0.0, a, b);

    // check the result:
    import std.experimental.ndslice.selection : byElement;
    import std.numeric : dotProduct;
    assert(res == dotProduct(a.byElement, b.byElement));
}

/// Zipped tensors, dot product
pure unittest
{
    import std.typecons : Yes;
    import std.conv : to;
    import std.range : iota;
    import std.numeric : dotProduct;
    import std.experimental.ndslice.slice : assumeSameStructure;
    import std.experimental.ndslice.selection : iotaSlice;
    import std.experimental.ndslice.internal : fastmath;

    static @fastmath T fmuladd(T, Z)(const T a, Z z)
    {
        return a + z.a * z.b;
    }

    // 0 1 2
    // 3 4 5
    auto sl1 = iotaSlice(2, 3).ndMap!(to!double).slice;
    // 1 2 3
    // 4 5 6
    auto sl2 = iotaSlice([2, 3], 1).ndMap!(to!double).slice;

    // tensors must have the same strides
    assert(sl1.structure == sl2.structure);

    auto zip = assumeSameStructure!("a", "b")(sl1, sl2);

    auto dot = ndReduce!(fmuladd, Yes.vectorized)(0.0, zip);

    assert(dot == dotProduct(iota(0, 6), iota(1, 7)));
}

/// Tensor mutation on-the-fly
unittest
{
    import std.typecons : Yes;
    import std.conv : to;
    import std.experimental.ndslice.slice : slice;
    import std.experimental.ndslice.selection : iotaSlice;
    import std.experimental.ndslice.internal : fastmath;

    static @fastmath T fun(T)(const T a, ref T b)
    {
        return a + b++;
    }

    //| 0 1 2 |
    //| 3 4 5 |
    auto sl = iotaSlice(2, 3).ndMap!(to!double).slice;

    auto res = ndReduce!(fun, Yes.vectorized)(double(0), sl);

    assert(res == 15);

    //| 1 2 3 |
    //| 4 5 6 |
    assert(sl == iotaSlice([2, 3], 1));
}

/++
Packed tensors.

Computes minimum value of maximum values for each row.
+/
unittest
{
    // LDC is LLVM D Compiler
    version(LDC)
        import ldc.intrinsics : fmax = llvm_maxnum, fmin = llvm_minnum;
    // std.math prevents vectorization for now
    else
        import std.math : fmax, fmin;
    import std.typecons : Yes;
    import std.conv : to;
    import std.experimental.ndslice.slice : slice;
    import std.experimental.ndslice.iteration : transposed;
    import std.experimental.ndslice.selection : iotaSlice, pack;

    alias maxVal = (a) => ndReduce!(fmax, Yes.vectorized)(-double.infinity, a);
    alias minVal = (a) => ndReduce!fmin(double.infinity, a);
    alias minimaxVal = (a) => minVal(a.pack!1.ndMap!maxVal);

    auto sl = iotaSlice(2, 3).ndMap!(to!double).slice;

    // Vectorized execution path: row stride equals 1.
    //| 0 1 2 | => | 2 |
    //| 3 4 5 | => | 5 | => 2
    auto res = minimaxVal(sl);
    assert(res == 2);

    // Common execution path: row stride does not equal 1.
    //| 0 1 2 |    | 0 3 | => | 3 |
    //| 3 4 5 | => | 1 4 | => | 4 |
    //             | 2 5 | => | 5 | => 3
    auto resT = minimaxVal(sl.transposed);
    assert(resT == 3);
}

@safe pure nothrow @nogc unittest
{
    import std.experimental.ndslice.iteration : dropOne;
    import std.experimental.ndslice.selection : iotaSlice;
    auto a = ndReduce!"a + b"(size_t(7), iotaSlice(1, 1).dropOne!0);
    assert(a == 7);
}

/++
The call `ndEach!(fun)(tensors1, ..., tesnsorN)`
evaluates `fun` for each set of elements `x1, ..., xN` in
`tensors1, ..., tensorN` respectively.

`ndEach` allows to iterate multiple tensors in the lockstep.

Note:
    $(SUBREF iteration, transposed) and
    $(SUBREF selection, pack) can be used to specify dimensions.
Params:
    fun = A function.
    select = Selection type.
    vec = Use vectorization friendly iteration without manual unrolling
        in case of all tensors has the last (row) stride equal to 1.
    fm = Allow a compiler to use unsafe floating-point mathematic transformations,
        such as commutative transformation. `fm` is enabled by default if `vec` is enabled.
    tensors = One or more tensors.
See_Also:
    $(HTTP llvm.org/docs/LangRef.html#fast-math-flags, LLVM IR: Fast Math Flags)

    This is functionally similar to $(LREF ndReduce) but has not seed.

    $(REF each, std,algorithm,iteration)
+/
alias ndEach(alias fun, Flag!"vectorized" vec = No.vectorized, Flag!"fastmath" fm = cast(Flag!"fastmath")vec) =
    .ndEach!(fun, Select.full, vec, fm);

/// ditto
template ndEach(alias fun, Select select, Flag!"vectorized" vec = No.vectorized, Flag!"fastmath" fm = cast(Flag!"fastmath")vec)
{
    ///
    void ndEach(Args...)(Args tensors)
        if (Args.length)
    {
        tensors.checkShapesMatch!(false, select);
        if (anyEmpty!select(tensors[0]))
            return;
        prepareTensors!select(tensors);
        alias impl = implement!(Iteration.each, fun, No.vectorized, fm);
        static if (vec && allSatisfy!(isMemory, staticMap!(RangeOf, Args)))
        {
            foreach (ref tensor; tensors)
                if (tensor._strides[$-1] != 1)
                    goto CommonL;
            alias implVec = implement!(Iteration.each, fun, Yes.vectorized, fm);
            implVec!(Args[0].N, select)(tensors);
            return;

            CommonL:
        }
        impl!(Args[0].N, select)(tensors);
    }
}

/// Single tensor, multiply-add
unittest
{
    import std.typecons : Yes;
    import std.conv : to;
    import std.experimental.ndslice.selection : iotaSlice;

    //| 0 1 2 |
    //| 3 4 5 |
    auto sl = iotaSlice(2, 3).ndMap!(to!double).slice;

    sl.ndEach!((ref a) { a = a * 10 + 5; }, Yes.vectorized);

    import std.stdio;
    assert(sl ==
        [[ 5, 15, 25],
         [35, 45, 55]]);
}

/// Swap two tensors
unittest
{
    import std.typecons : Yes;
    import std.conv : to;
    import std.algorithm.mutation : swap;
    import std.experimental.ndslice.selection : iotaSlice;

    //| 0 1 2 |
    //| 3 4 5 |
    auto a = iotaSlice([2, 3], 0).ndMap!(to!double).slice;
    //| 10 11 12 |
    //| 13 14 15 |
    auto b = iotaSlice([2, 3], 10).ndMap!(to!double).slice;

    ndEach!(swap, Yes.vectorized)(a, b);

    assert(a == iotaSlice([2, 3], 10));
    assert(b == iotaSlice([2, 3], 0));
}

/// Swap two zipped tensors
unittest
{
    import std.typecons : Yes;
    import std.conv : to;
    import std.algorithm.mutation : swap;
    import std.experimental.ndslice.slice : assumeSameStructure;
    import std.experimental.ndslice.selection : iotaSlice;

    //| 0 1 2 |
    //| 3 4 5 |
    auto a = iotaSlice([2, 3], 0).ndMap!(to!double).slice;
    //| 10 11 12 |
    //| 13 14 15 |
    auto b = iotaSlice([2, 3], 10).ndMap!(to!double).slice;

    auto zip = assumeSameStructure!("a", "b")(a, b);

    zip.ndEach!(z => swap(z.a, z.b), Yes.vectorized);

    assert(a == iotaSlice([2, 3], 10));
    assert(b == iotaSlice([2, 3], 0));
}

/// Reverse rows and columns
pure nothrow unittest
{
    import std.typecons : Yes;
    import std.conv : to;
    import std.algorithm.mutation : swap;
    import std.experimental.ndslice.slice : assumeSameStructure;
    import std.experimental.ndslice.selection : iotaSlice;
    import std.experimental.ndslice.iteration : allReversed;

    //| 0 1 2 |
    //| 3 4 5 |
    auto a = iotaSlice(2, 3).ndMap!(to!double).slice;

    ndEach!(swap, Select.half)(a, a.allReversed);

    assert(a == iotaSlice(2, 3).allReversed);
}

/// Reverse rows or columns
pure nothrow unittest
{
    import std.conv : to;
    import std.algorithm.mutation : swap;
    import std.experimental.ndslice.selection : iotaSlice, pack;
    import std.experimental.ndslice.iteration : reversed, transposed;

    //| 0 1 2 |
    //| 3 4 5 |
    auto a = iotaSlice(2, 3).ndMap!(to!double).slice;
    auto b = a.slice;

    alias reverseRows = a => ndEach!(swap, Select.halfPacked)(a.pack!1, a.reversed!1.pack!1);

    // reverse rows
    reverseRows(a);
    assert(a == iotaSlice(2, 3).reversed!1);

    // reverse columns
    reverseRows(b.transposed);
    assert(b == iotaSlice(2, 3).reversed!0);
}

/// Transpose matrix
pure nothrow unittest
{
    import std.conv : to;
    import std.algorithm.mutation : swap;
    import std.experimental.ndslice.selection : iotaSlice;
    import std.experimental.ndslice.iteration : dropOne, transposed;

    // | 0 1 2 |
    // | 3 4 5 |
    // | 6 7 8 |
    auto a = iotaSlice(3, 3).ndMap!(to!double).slice;

    // matrix should be square
    assert(a.length!0 == a.length!1);

    if (a.length)
        // dropOne is used because we do not need to transpose the diagonal
        ndEach!(swap, Select.triangular)(a.dropOne, a.transposed.dropOne);

    assert(a == iotaSlice(3, 3).transposed);
}

@safe pure nothrow unittest
{
    import std.experimental.ndslice.iteration : dropOne;
    import std.experimental.ndslice.selection : iotaSlice;
    size_t i;
    iotaSlice(1, 2).dropOne!0.ndEach!((a){i++;});
    assert(i == 0);
}

/++
Finds a backward index for which
`pred(tensors[0].backward(index), ..., tensors[$-1].backward(index))` equals `true`.

Params:
    pred = The predicate.
    select = Selection type.
    backwardIndex = The variable passing by reference to be filled with the multidimensional backward index for which the predicate is true.
        `backwardIndex` equals zeros, if the predicate evaluates `false` for all indexes.
    tensors = One or more tensors.

Optimization:
To check if any element was found
use the last dimension (row index).
This will slightly optimize the code.
--------
// $-1 instead of 0
if (backwardIndex[$-1])
{
    auto elem1 = slice1.backward(backwardIndex);
    //...
    auto elemK = sliceK.backward(backwardIndex);
}
else
{
    // not found
}
--------

Constraints:
    All tensors must have the same shape.

See_also:
    $(LREF ndAny)

    $(REF Slice.backward, std,experimental,ndslice,slice)
+/
template ndFind(alias pred, Select select = Select.full)
{
    ///
    void ndFind(size_t N, Args...)(out size_t[N] backwardIndex, Args tensors)
        if (Args.length)
    {
        tensors.checkShapesMatch!(false, select);
        if (!anyEmpty!select(tensors[0]))
        {
            prepareTensors!select(tensors);
            alias impl = implement!(Iteration.find, pred, No.vectorized, No.fastmath);
            impl!(Args[0].N, select)(backwardIndex, tensors);
        }
    }
}

///
@safe pure nothrow @nogc unittest
{
    import std.experimental.ndslice.selection : iotaSlice;
    // 0 1 2
    // 3 4 5
    auto sl = iotaSlice(2, 3);
    size_t[2] bi;

    ndFind!"a == 3"(bi, sl);
    assert(sl.backward(bi) == 3);

    ndFind!"a == 6"(bi, sl);
    assert(bi[0] == 0);
    assert(bi[1] == 0);
}

/// Multiple tensors
@safe pure nothrow @nogc unittest
{
    import std.experimental.ndslice.selection : iotaSlice;

    // 0 1 2
    // 3 4 5
    auto a = iotaSlice(2, 3);
    // 10 11 12
    // 13 14 15
    auto b = iotaSlice([2, 3], 10);

    size_t[2] bi;

    ndFind!((a, b) => a * b == 39)(bi, a, b);
    assert(a.backward(bi) == 3);
    assert(b.backward(bi) == 13);
}

/// Zipped tensors
@safe pure nothrow unittest
{
    import std.experimental.ndslice.selection : iotaSlice;

    // 0 1 2
    // 3 4 5
    auto a = iotaSlice(2, 3);
    // 10 11 12
    // 13 14 15
    auto b = iotaSlice([2, 3], 10);

    // tensors must have the same strides
    auto zip = assumeSameStructure!("a", "b")(a, b);
    size_t[2] bi;

    ndFind!((z) => z.a * z.b == 39)(bi, zip);

    assert(a.backward(bi) == 3);
    assert(b.backward(bi) == 13);
}

/// Mutation on-the-fly
pure nothrow unittest
{
    import std.conv : to;
    import std.experimental.ndslice.slice : slice;
    import std.experimental.ndslice.selection : iotaSlice;

    // 0 1 2
    // 3 4 5
    auto sl = iotaSlice(2, 3).ndMap!(to!double).slice;

    static bool pred(T)(ref T a)
    {
        if (a == 5)
            return true;
        a = 8;
        return false;
    }

    size_t[2] bi;
    ndFind!pred(bi, sl);

    assert(bi == [1, 1]);
    assert(sl.backward(bi) == 5);

    // sl was changed
    assert(sl == [[8, 8, 8],
                  [8, 8, 5]]);
}

/// Search in triangular matrix
pure nothrow unittest
{
    import std.conv : to;
    import std.experimental.ndslice.slice : slice;
    import std.experimental.ndslice.selection : iotaSlice;

    // |_0 1 2
    // 3 |_4 5
    // 6 7 |_8
    auto sl = iotaSlice(3, 3).ndMap!(to!double).slice;
    size_t[2] bi;
    ndFind!("a > 5", Select.triangular)(bi, sl);
    assert(sl.backward(bi) == 8);
}

/// Search of first non-palindrome row
pure nothrow unittest
{
    import std.experimental.ndslice.slice : slice;
    import std.experimental.ndslice.iteration : reversed;
    import std.experimental.ndslice.selection : iotaSlice, pack;

    auto sl = slice!double(4, 5);
    sl[] =
        [[0, 1, 2, 1, 0],
         [2, 3, 4, 3, 2],
         [6, 9, 8, 5, 6],
         [6, 5, 8, 5, 6]];

    size_t[2] bi;
    ndFind!("a != b", Select.halfPacked)(bi, sl.pack!1, sl.reversed!1.pack!1);
    assert(sl.backward(bi) == 9);
}

@safe pure nothrow unittest
{
    import std.experimental.ndslice.iteration : dropOne;
    import std.experimental.ndslice.selection : iotaSlice;
    size_t i;
    size_t[2] bi;
    ndFind!((elem){i++; return true;})
        (bi, iotaSlice(2, 1).dropOne!1);
    assert(i == 0);
    assert(bi == [0, 0]);
}


/++
Like $(LREF ndFind), but only returns whether or not the search was successful.

Params:
    pred = The predicate.
    select = Selection type.
    tensors = One or more tensors.

Returns:
    `true` if the search was successful and `false` otherwise.

Constraints:
    All tensors must have the same shape.
+/
template ndAny(alias pred, Select select = Select.full)
{
    ///
    bool ndAny(Args...)(Args tensors)
        if (Args.length)
    {
        tensors.checkShapesMatch!(false, select);
        if (anyEmpty!select(tensors[0]))
            return false;
        size_t[Args[0].N] backwardIndex = void;
        backwardIndex[$-1] = 0;
        prepareTensors!select(tensors);
        alias impl = implement!(Iteration.find, pred, No.vectorized, No.fastmath);
        impl!(Args[0].N, select)(backwardIndex, tensors);
        return cast(bool) backwardIndex[$-1];
    }
}

///
@safe pure nothrow @nogc unittest
{
    import std.experimental.ndslice.selection : iotaSlice;
    // 0 1 2
    // 3 4 5
    auto sl = iotaSlice(2, 3);

    assert(sl.ndAny!"a == 3");
    assert(!sl.ndAny!"a == 6");
}

/// Multiple tensors
@safe pure nothrow @nogc unittest
{
    import std.experimental.ndslice.selection : iotaSlice;

    // 0 1 2
    // 3 4 5
    auto a = iotaSlice(2, 3);
    // 10 11 12
    // 13 14 15
    auto b = iotaSlice([2, 3], 10);

    assert(ndAny!((a, b) => a * b == 39)(a, b));
}

/// Zipped tensors
@safe pure nothrow unittest
{
    import std.experimental.ndslice.selection : iotaSlice;

    // 0 1 2
    // 3 4 5
    auto a = iotaSlice(2, 3);
    // 10 11 12
    // 13 14 15
    auto b = iotaSlice([2, 3], 10);

    // tensors must have the same strides
    auto zip = assumeSameStructure!("a", "b")(a, b);

    assert(zip.ndAny!((z) => z.a * z.b == 39));
}

/// Mutation on-the-fly
pure nothrow unittest
{
    import std.conv : to;
    import std.experimental.ndslice.slice : slice;
    import std.experimental.ndslice.selection : iotaSlice;

    // 0 1 2
    // 3 4 5
    auto sl = iotaSlice(2, 3).ndMap!(to!double).slice;

    static bool pred(T)(ref T a)
    {
        if (a == 5)
            return true;
        a = 8;
        return false;
    }

    assert(sl.ndAny!pred);

    // sl was changed
    assert(sl == [[8, 8, 8],
                  [8, 8, 5]]);
}

/++
Checks if all of the elements verify `pred`.
Params:
    pred = The predicate.
    select = Selection type.
    tensors = One or more tensors.
Returns:
    `true` all of the elements verify `pred` and `false` otherwise.
Constraints:
    All tensors must have the same shape.
+/
template ndAll(alias pred, Select select = Select.full)
{
    ///
    bool ndAll(Args...)(Args tensors)
        if (Args.length)
    {
        tensors.checkShapesMatch!(false, select);
        prepareTensors!select(tensors);
        alias impl = implement!(Iteration.all, pred, No.vectorized, No.fastmath);
        return anyEmpty!select(tensors[0]) || impl!(Args[0].N, select)(tensors);
    }
}

///
@safe pure nothrow unittest
{
    import std.experimental.ndslice.selection : iotaSlice;

    // 0 1 2
    // 3 4 5
    auto sl = iotaSlice(2, 3);

    assert(sl.ndAll!"a < 6");
    assert(!sl.ndAll!"a < 5");
}

/// Multiple tensors
@safe pure nothrow unittest
{
    import std.experimental.ndslice.selection : iotaSlice;

    // 0 1 2
    // 3 4 5
    auto sl = iotaSlice(2, 3);

    assert(ndAll!"a - b == 0"(sl, sl));
}

/// Zipped tensors
@safe pure nothrow unittest
{
    import std.experimental.ndslice.selection : iotaSlice;

    // 0 1 2
    // 3 4 5
    auto sl = iotaSlice(2, 3);

    // tensors must have the same strides
    auto zip = assumeSameStructure!("a", "b")(sl, sl);

    assert(zip.ndAll!"a.a - a.b == 0");
}

/// Mutation on-the-fly
pure nothrow unittest
{
    import std.conv : to;
    import std.experimental.ndslice.slice : slice;
    import std.experimental.ndslice.selection : iotaSlice;

    // 0 1 2
    // 3 4 5
    auto sl = iotaSlice(2, 3).ndMap!(to!double).slice;

    static bool pred(T)(ref T a)
    {
        if (a < 4)
        {
            a = 8;
            return true;
        }
        return false;
    }

    assert(!sl.ndAll!pred);

    // sl was changed
    assert(sl == [[8, 8, 8],
                  [8, 4, 5]]);
}

@safe pure nothrow unittest
{
    import std.experimental.ndslice.iteration : dropOne;
    import std.experimental.ndslice.selection : iotaSlice;
    size_t i;
    assert(ndAll!((elem){i++; return true;})
        (iotaSlice(2, 1).dropOne!1));
    assert(i == 0);
}

/++
Compares two or more tensors for equality, as defined by predicate `pred`.

Params:
    pred = The predicate.
    select = Selection type.
    tensors = Two or more tensors.

Returns:
    `true` any of the elements verify `pred` and `false` otherwise.
+/
template ndEqual(alias pred, Select select = Select.full)
{
    ///
    bool ndEqual(Args...)(Args tensors)
        if (Args.length >= 2)
    {
        enum msg = "all arguments must be tensors" ~ tailErrorMessage!();
        enum msgShape = "all tensors must have the same dimension count"  ~ tailErrorMessage!();
        prepareTensors!select(tensors);
        foreach (i, Arg; Args)
        {
            static assert (is(Arg == Slice!(N, Range), size_t N, Range), msg);
            static if (i)
            {
                static assert (tensors[i].N == tensors[0].N, msgShape);
                foreach (j; Iota!(0, tensors[0].N))
                    if (tensors[i]._lengths[j] != tensors[0]._lengths[j])
                        goto False;
            }
        }
        return ndAll!(pred, select)(tensors);
        False: return false;
    }
}

///
@safe pure nothrow @nogc unittest
{
    import std.experimental.ndslice.slice : slice;
    import std.experimental.ndslice.iteration : dropBackOne;
    import std.experimental.ndslice.selection : iotaSlice;

    // 0 1 2
    // 3 4 5
    auto sl1 = iotaSlice(2, 3);
    // 1 2 3
    // 4 5 6
    auto sl2 = iotaSlice([2, 3], 1);

    assert(ndEqual!"a == b"(sl1, sl1));
    assert(ndEqual!"a < b"(sl1, sl2));

    assert(!ndEqual!"a == b"(sl1.dropBackOne!0, sl1));
    assert(!ndEqual!"a == b"(sl1.dropBackOne!1, sl1));
}

/// check if matrix is symmetric
pure nothrow unittest
{
    import std.experimental.ndslice.slice : slice;
    import std.experimental.ndslice.iteration : transposed;

    auto a = slice!double(3, 3);
    a[] = [[1, 3, 4],
           [3, 5, 8],
           [4, 8, 2]];

    alias isSymmetric = matrix => ndEqual!("a == b", Select.triangular)(matrix, matrix.transposed);

    assert(isSymmetric(a));

    a[0, 0] = double.nan;
    assert(!isSymmetric(a)); // nan != nan
    a[0, 0] = 1;

    a[1, 0] = 2;
    assert(!isSymmetric(a)); // 2 != 3
    a[1, 0] = 3;

    a.popFront;
    assert(!isSymmetric(a)); // a is not square
}

/++
Performs three-way recursive lexicographical comparison on two tensors according to predicate `pred`.
Iterating `sl1` and `sl2` in lockstep, `cmp` compares each `N-1` dimensional element `e1` of `sl1`
with the corresponding element `e2` in `sl2` recursively.
If one of the tensors has been finished,`cmp` returns a negative value if `sl1` has fewer elements than `sl2`,
a positive value if `sl1` has more elements than `sl2`,
and `0` if the ranges have the same number of elements.

Params:
    pred = The predicate.
    sl1 = First tensor.
    sl2 = Second tensor.

Returns:
    `0` if both ranges compare equal.
    Negative value if the first differing element of `sl1` is less than the corresponding
    element of `sl2` according to `pred`.
    Positive value if the first differing element of `sl2` is less than the corresponding
    element of `sl1` according to `pred`.
+/
template ndCmp(alias pred = "a < b")
{
    ///
    int ndCmp(size_t N, RangeA, RangeB)(Slice!(N, RangeA) sl1, Slice!(N, RangeB) sl2)
    {
        auto b = sl2.anyEmpty;
        if (sl1.anyEmpty)
        {
            if (!b)
                return -1;
            foreach (i; Iota!(0, N))
                if (sl1._lengths[i] < sl2._lengths[i])
                    return -1;
                else
                if (sl1._lengths[i] > sl2._lengths[i])
                    return 1;
            return 0;
        }
        if (b)
            return 1;
        return ndCmpImpl(sl1, sl2);
    }

    private int ndCmpImpl(size_t N, RangeA, RangeB)(Slice!(N, RangeA) sl1, Slice!(N, RangeB) sl2)
    {
        for (;;)
        {
            auto a = sl1.front;
            auto b = sl2.front;
            static if (N == 1)
            {
                import std.functional : binaryFun;
                if (binaryFun!pred(a, b))
                    return -1;
                if (binaryFun!pred(b, a))
                    return 1;
            }
            else
            {
                if (auto res = ndCmpImpl(a, b))
                    return res;
            }
            sl1.popFront;
            if (sl1.empty)
                return -cast(int)(sl2.length > 1);
            sl2.popFront;
            if (sl2.empty)
                return 1;
        }
    }
}

///
@safe pure nothrow @nogc unittest
{
    import std.experimental.ndslice.iteration : dropBackOne;
    import std.experimental.ndslice.selection : iotaSlice;

    // 0 1 2
    // 3 4 5
    auto sl1 = iotaSlice(2, 3);
    // 1 2 3
    // 4 5 6
    auto sl2 = iotaSlice([2, 3], 1);

    assert(ndCmp(sl1, sl1) == 0);
    assert(ndCmp(sl1, sl2) < 0);
    assert(ndCmp!"a >= b"(sl1, sl2) > 0);
}

@safe pure nothrow @nogc unittest
{
    import std.experimental.ndslice.iteration : dropBackOne, dropExactly;
    import std.experimental.ndslice.selection : iotaSlice;

    auto sl1 = iotaSlice(2, 3);
    auto sl2 = iotaSlice([2, 3], 1);

    assert(ndCmp(sl1.dropBackOne!0, sl1) < 0);
    assert(ndCmp(sl1, sl1.dropBackOne!1) > 0);

    assert(ndCmp(sl1.dropExactly!0(2), sl1) < 0);
    assert(ndCmp(sl1, sl1.dropExactly!1(3)) > 0);
    assert(ndCmp(sl1.dropExactly!1(3), sl1.dropExactly!1(3)) == 0);
    assert(ndCmp(sl1.dropExactly!1(3), sl1.dropExactly!(0, 1)(1, 3)) > 0);
    assert(ndCmp(sl1.dropExactly!(0, 1)(1, 3), sl1.dropExactly!1(3)) < 0);
}
