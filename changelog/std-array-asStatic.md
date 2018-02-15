Added `staticArray` to construct a static array from input array / range / CT range.

The type of elements can be specified implicitly (`[1,2].staticArray` of type int[2])
or explicitly (`[1,2].staticArray!float` of type float[2]).
When `a` is a range (not known at compile time), the number of elements has to be given as template argument
(eg `myrange.staticArray!2`).
Size and type can be combined (eg: `2.iota.staticArray!(byte[2])`).
When the range `a` is known at compile time, it can also be specified as a
template argument to avoid having to specify the number of elements
(eg: `staticArray!(2.iota)` or `staticArray!(double, 2.iota)`).

Note: `foo([1, 2, 3].staticArray)` may be inefficient because of the copies involved.

---
auto a1 = [0, 1].staticArray;
static assert(is(typeof(a1) == int[2]));
assert(a1 == [0, 1]);

auto a2 = [0, 1].staticArray!byte;
static assert(is(typeof(a2) == byte[2]));

import std.range : iota;
auto input = 2.iota;
auto a3 = input.staticArray!2;
auto a4 = input.staticArray!(byte[2]);

auto a5 = staticArray!(2.iota);
auto a6 = staticArray!(double, 2.iota);
---
